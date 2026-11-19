import SwiftUI
import UIKit

/// Text attributes that sit every line exactly on the printed rule.
enum PaperTypography {
    static let fontSize: CGFloat = 17

    static func paragraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = PageMetrics.line
        p.maximumLineHeight = PageMetrics.line
        p.alignment = .natural            // each paragraph aligns by its own language
        p.baseWritingDirection = .natural // Arabic paragraphs run right-to-left, English left-to-right
        return p
    }

    static var attributes: [NSAttributedString.Key: Any] {
        [.font: AppFont.paperUIFont(fontSize),
         .foregroundColor: Palette.uiInk,
         .paragraphStyle: paragraph()]
    }

    /// RTF can't store "natural" direction; restore it (and the rule-aligned line height) on load.
    static func normalize(_ text: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: text)
        let all = NSRange(location: 0, length: m.length)
        m.addAttribute(.paragraphStyle, value: paragraph(), range: all)
        m.enumerateAttribute(.font, in: all) { value, range, _ in
            if value == nil { m.addAttribute(.font, value: AppFont.paperUIFont(fontSize), range: range) }
        }
        m.enumerateAttribute(.foregroundColor, in: all) { value, range, _ in
            if value == nil { m.addAttribute(.foregroundColor, value: Palette.uiInk, range: range) }
        }
        return m
    }
}

/// UITextView on paper: transparent, no scrolling (a page is a page), with a quiet placeholder.
final class PaperTextView: UITextView {
    let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        backgroundColor = .clear
        isScrollEnabled = false
        textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
        allowsEditingTextAttributes = true     // bold / italic / underline from the edit menu
        autocorrectionType = .default
        smartInsertDeleteType = .default
        keyboardDismissMode = .interactive
        tintColor = UIColor(hex: 0x4F7C7A)
        placeholderLabel.font = AppFont.paperUIFont(PaperTypography.fontSize)
        placeholderLabel.textColor = UIColor(hex: 0x77726A, alpha: 0.45)
        placeholderLabel.isUserInteractionEnabled = false
        addSubview(placeholderLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func updatePlaceholder() {
        placeholderLabel.isHidden = !(text.isEmpty && !isFirstResponder)
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        updatePlaceholder()
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        updatePlaceholder()
        return ok
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: PageMetrics.line)
    }
}

struct FreeTextView: UIViewRepresentable {
    let session: NotebookSession
    let pageID: UUID
    let editable: Bool
    let lang: AppLanguage

    func makeCoordinator() -> Coordinator { Coordinator(session: session, pageID: pageID) }

    func makeUIView(context: Context) -> PaperTextView {
        let tv = PaperTextView(frame: .zero, textContainer: nil)
        tv.attributedText = PaperTypography.normalize(session.text(for: pageID))
        tv.typingAttributes = PaperTypography.attributes
        tv.delegate = context.coordinator
        tv.isEditable = editable
        tv.isSelectable = editable
        tv.placeholderLabel.text = lang.t("Tap to write…", "اضغط لتكتب…")
        tv.placeholderLabel.textAlignment = lang.isRTL ? .right : .left
        tv.accessibilityLabel = lang.t("Page text", "نص الصفحة")
        tv.accessibilityIdentifier = "page.text"
        tv.updatePlaceholder()
        return tv
    }

    func updateUIView(_ tv: PaperTextView, context: Context) {
        if tv.isEditable != editable {
            if !editable { tv.resignFirstResponder() }
            tv.isEditable = editable
            tv.isSelectable = editable
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let session: NotebookSession
        let pageID: UUID

        init(session: NotebookSession, pageID: UUID) {
            self.session = session
            self.pageID = pageID
        }

        func textViewDidChange(_ textView: UITextView) {
            session.setText(textView.attributedText, for: pageID)
            (textView as? PaperTextView)?.updatePlaceholder()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            textView.typingAttributes.merge(PaperTypography.attributes) { current, _ in current }
        }

        /// Paper has an end: when the page is full, typing stops and the page says so.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !text.isEmpty, textView.bounds.height > 0 else { return true }
            let candidate = NSMutableAttributedString(attributedString: textView.attributedText)
            candidate.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: textView.typingAttributes))
            var height = candidate.boundingRect(with: CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                context: nil).height
            if candidate.string.hasSuffix("\n") { height += PageMetrics.line }
            if height > textView.bounds.height + 1 {
                Haptics.pageFull()
                session.pageFullPulse += 1
                return false
            }
            return true
        }
    }
}
