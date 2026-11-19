import UIKit
import SwiftUI
import PencilKit

/// The open notebook. Three live page views (previous, current, next) sit in a stack;
/// a page turn hands the moving sheet to `PageCurlView`, which bends a snapshot of it
/// under the finger while the page beneath stays live.
///
/// Physics: while dragging, the grabbed edge point follows the finger exactly (constrained so
/// the sheet stays attached at the spine); the cylinder radius grows with speed. On release a
/// damped spring — seeded with the finger's velocity — carries the sheet over or back.
final class ReaderViewController: UIViewController, UIGestureRecognizerDelegate {
    enum Mode { case forward, backward }

    private struct Turn {
        let mode: Mode
        let destination: Int
        let grab: CGPoint        // the edge point taken hold of (logical space)
        let fullTurn: CGPoint    // where it lies once the sheet has gone over the spine
        var finger: CGPoint
        var fingerTarget: CGPoint
        var fingerAtStart: CGPoint
        var touchStart: CGPoint = .zero
        var velocity: CGVector = .zero
        var dragging: Bool
        var target: CGPoint?
        var damping: CGFloat = 1
        var commit = false
        var radius: CGFloat = 0
        var lastTime: CFTimeInterval = 0
        var isPeek = false
    }

    let session: NotebookSession
    private weak var bridge: ReaderBridge?
    var wantsTurnHint = false

    private let pageContainer = UIView()
    private let decor = PageStackDecorView()
    private var hosts: [UIHostingController<PageSurface>] = []
    private var prevSlot = 0
    private var currentSlot = 1
    private var nextSlot = 2
    private var curlView: PageCurlView!
    private var pan: UIPanGestureRecognizer!
    private var link: CADisplayLink?
    private var turn: Turn?
    private var pendingMode: Mode = .forward
    private var pageFrame: CGRect = .zero
    private var keyboardFrame: CGRect = .null
    private let debugLabel = UILabel()

    private var rtl: Bool { session.lang.isRTL }
    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    init(session: NotebookSession, bridge: ReaderBridge) {
        self.session = session
        self.bridge = bridge
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        pageContainer.frame = view.bounds
        pageContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pageContainer)

        let style = session.meta.style
        decor.frame = pageContainer.bounds
        decor.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        decor.spineOnLeft = !rtl
        decor.coverColor = style.coverColor.uiColor
        decor.paperColor = style.paperTone.uiColor
        decor.pageRadius = style.corner.pageRadius
        decor.binding = style.binding
        pageContainer.addSubview(decor)

        for _ in 0..<3 {
            let host = UIHostingController(rootView: PageSurface(session: session, pageID: nil, number: 1, interactive: false))
            host.view.backgroundColor = .clear
            host.safeAreaRegions = []
            addChild(host)
            pageContainer.addSubview(host.view)
            host.didMove(toParent: self)
            hosts.append(host)
        }

        let curl = PageCurlView(frame: view.bounds)
        curl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        curl.isHidden = true
        view.addSubview(curl)
        curlView = curl

        pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        session.navigator = { [weak self] index in self?.turn(to: index) }
        configureSlots()

        #if DEBUG
        // invisible status line read by the UI screenshot tests
        debugLabel.frame = CGRect(x: 0, y: 0, width: 4, height: 4)
        debugLabel.alpha = 0.02
        debugLabel.isAccessibilityElement = true
        debugLabel.accessibilityIdentifier = "debug.reader"
        view.addSubview(debugLabel)
        note("loaded curlReady=\(curl.isReady)")
        #endif

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        nc.addObserver(self, selector: #selector(followCaret), name: UITextView.textDidChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(followCaret), name: UITextView.textDidBeginEditingNotification, object: nil)
        nc.addObserver(self, selector: #selector(followCaret), name: UITextField.textDidBeginEditingNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let f = PageLayout.pageFrame(in: view.bounds.size, safe: view.safeAreaInsets,
                                     aspect: session.meta.style.proportion.aspect)
        guard !f.isEmpty, f != pageFrame, turn == nil else { return }
        pageFrame = f
        for h in hosts { h.view.frame = f }
        decor.pageRect = f
        bridge?.pageFrame = view.convert(f, to: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if wantsTurnHint {
            wantsTurnHint = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.playTurnHint() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopLink()
        session.rememberCurrentPage()
    }

    // MARK: Slots

    private func configure(_ slot: Int, page index: Int?, interactive: Bool) {
        let host = hosts[slot]
        guard let index, index >= 0 else {
            host.view.isHidden = true
            host.view.isUserInteractionEnabled = false
            return
        }
        let pages = session.meta.pages
        let id: UUID? = index < pages.count ? pages[index].id : nil   // nil: the blank sheet after the last page
        host.rootView = PageSurface(session: session, pageID: id, number: index + 1, interactive: interactive)
        host.view.isHidden = false
        host.view.isUserInteractionEnabled = interactive
        // only the page you're looking at is read by VoiceOver (the neighbours sit hidden beneath it)
        host.view.accessibilityElementsHidden = !interactive
    }

    private func configureSlots() {
        let c = session.currentIndex
        configure(prevSlot, page: c > 0 ? c - 1 : nil, interactive: false)
        configure(currentSlot, page: c, interactive: true)
        configure(nextSlot, page: c + 1, interactive: false)
        for h in hosts { h.view.alpha = 1 }
        orderSlots()
        decor.sheetsBelow = max(1, session.meta.pages.count - 1 - c)
    }

    private func orderSlots() {
        pageContainer.bringSubviewToFront(hosts[prevSlot].view)
        pageContainer.bringSubviewToFront(hosts[nextSlot].view)
        pageContainer.bringSubviewToFront(hosts[currentSlot].view)
    }

    // MARK: Coordinates (logical: spine at x = 0, free edge at x = width)

    private func logical(_ p: CGPoint) -> CGPoint {
        let x = p.x - pageFrame.minX
        return CGPoint(x: rtl ? pageFrame.width - x : x, y: p.y - pageFrame.minY)
    }

    private func logicalVelocity(_ v: CGPoint) -> CGVector {
        CGVector(dx: rtl ? -v.x : v.x, dy: v.y)
    }

    // MARK: Gesture

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard g === pan else { return true }
        guard turn == nil, !pageFrame.isEmpty, curlView.isReady else { return false }
        let v = logicalVelocity(pan.velocity(in: view))
        guard abs(v.dx) > abs(v.dy) * 1.1 else { return false }
        let loc = pan.location(in: view)
        let tr = pan.translation(in: view)
        let start = logical(CGPoint(x: loc.x - tr.x, y: loc.y - tr.y))
        let W = pageFrame.width, H = pageFrame.height
        guard start.y > -24, start.y < H + 24 else { return false }

        var band: CGFloat = session.drawingMode ? 28 : 46
        if let tv = hosts[currentSlot].view.findFirstResponder() as? UITextView, tv.selectedRange.length > 0 {
            band = 20   // don't steal a text-selection drag
        }
        if v.dx < 0, start.x > W - band, start.x < W + 30 {
            pendingMode = .forward
            return true
        }
        if v.dx > 0, start.x < band, start.x > -30, session.currentIndex > 0 {
            pendingMode = .backward
            return true
        }
        note("pan rejected start=\(Int(start.x)),\(Int(start.y)) v=\(Int(v.dx)) width=\(Int(W))")
        return false
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let loc = g.location(in: view)
        switch g.state {
        case .began:
            let tr = g.translation(in: view)
            let start = logical(CGPoint(x: loc.x - tr.x, y: loc.y - tr.y))
            let dest = pendingMode == .forward ? session.currentIndex + 1 : session.currentIndex - 1
            guard beginTurn(mode: pendingMode, destination: dest, grabY: start.y, interactive: true) else {
                g.isEnabled = false
                g.isEnabled = true
                return
            }
            turn?.touchStart = start
            updateDrag(to: logical(loc))
        case .changed:
            updateDrag(to: logical(loc))
        case .ended:
            release(velocity: logicalVelocity(g.velocity(in: view)), cancelled: false)
        case .cancelled, .failed:
            release(velocity: .zero, cancelled: true)
        default:
            break
        }
    }

    private func updateDrag(to p: CGPoint) {
        guard var t = turn, t.dragging else { return }
        let dx = p.x - t.touchStart.x
        let dy = p.y - t.touchStart.y
        // Turning back, the previous sheet comes from beyond the spine; the finger travels half as far.
        let gain: CGFloat = t.mode == .forward ? 1 : 2
        t.fingerTarget = CGPoint(x: t.fingerAtStart.x + dx * gain, y: t.fingerAtStart.y + dy)
        turn = t
    }

    private func release(velocity v: CGVector, cancelled: Bool) {
        guard var t = turn, t.dragging else { return }
        t.dragging = false
        #if DEBUG
        // Screenshot tests: hold the sheet exactly where the finger let go, mid-curl.
        if ProcessInfo.processInfo.environment["WARAQ_FREEZE_CURL"] == "1", !cancelled {
            t.target = nil
            turn = t
            stopLink()
            return
        }
        #endif
        let W = pageFrame.width
        let vx = t.mode == .forward ? v.dx : v.dx * 2
        t.velocity = CGVector(dx: vx, dy: v.dy)
        let x = t.finger.x
        let commit: Bool
        if cancelled {
            commit = false
        } else if t.mode == .forward {
            commit = vx < -500 || (x < W * 0.45 && vx < 300)
        } else {
            commit = vx > 500 || (x > -W * 0.1 && vx > -300)
        }
        aim(&t, commit: commit)
        turn = t
    }

    private func aim(_ t: inout Turn, commit: Bool) {
        t.commit = commit
        // forward + cancel and backward + commit both end with the sheet lying flat
        let toFlat = (t.mode == .forward) != commit
        t.target = toFlat ? t.grab : t.fullTurn
        t.damping = toFlat ? 1.0 : 0.86
    }

    // MARK: Turning

    @discardableResult
    private func beginTurn(mode: Mode, destination: Int, grabY: CGFloat, interactive: Bool) -> Bool {
        guard turn == nil else { note("begin: busy"); return false }
        guard !pageFrame.isEmpty else { note("begin: no page frame"); return false }
        guard curlView.isReady else { note("begin: curl not ready"); return false }
        view.endEditing(true)
        pageContainer.transform = .identity

        let size = pageFrame.size
        var y = min(max(grabY, 0), size.height)
        if y < size.height * 0.16 { y = 0 } else if y > size.height * 0.84 { y = size.height }
        let grab = CGPoint(x: size.width, y: y)
        let full = CGPoint(x: -size.width, y: y)

        let sheet = mode == .forward ? hosts[currentSlot] : hosts[prevSlot]
        guard let image = snapshot(sheet.view) else { note("begin: snapshot failed"); return false }
        guard curlView.load(snapshot: image) else { note("begin: texture failed \(image.size) x\(image.scale)"); return false }

        var u = curlView.uniforms
        let origin = view.convert(pageFrame.origin, to: curlView)
        u.pageOrigin = SIMD2(Float(origin.x), Float(origin.y))
        u.pageSize = SIMD2(Float(size.width), Float(size.height))
        u.mirror = rtl ? 1 : 0
        u.backTint = session.meta.style.paperTone.uiColor.simd4
        curlView.uniforms = u

        let startF = mode == .forward ? grab : full
        turn = Turn(mode: mode, destination: destination, grab: grab, fullTurn: full,
                    finger: startF, fingerTarget: startF, fingerAtStart: startF, dragging: interactive)
        curlView.isHidden = false
        render()
        if mode == .forward { sheet.view.alpha = 0 }   // the live page beneath now shows through
        startLink()
        note("begin: ok " + (mode == .forward ? "forward" : "backward"))
        return true
    }

    /// Turn to any page: neighbours with a full curl, distant pages by loading them under the sheet.
    func turn(to target: Int) {
        let count = session.meta.pages.count
        guard turn == nil, target >= 0, target < count, target != session.currentIndex else { return }
        view.endEditing(true)
        if reduceMotion || !curlView.isReady {
            crossfade(to: target)
            return
        }
        let forward = target > session.currentIndex
        configure(forward ? nextSlot : prevSlot, page: target, interactive: false)
        orderSlots()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.beginTurn(mode: forward ? .forward : .backward, destination: target,
                                 grabY: self.pageFrame.height * 0.62, interactive: false),
                  var t = self.turn else {
                // never leave the reader stuck on the old page
                self.crossfade(to: target)
                return
            }
            t.velocity = forward ? CGVector(dx: -1500, dy: -140) : CGVector(dx: 1500, dy: -60)
            self.aim(&t, commit: true)
            self.turn = t
        }
    }

    private func note(_ text: String) {
        #if DEBUG
        debugLabel.text = text
        debugLabel.accessibilityLabel = text
        #endif
    }

    private func crossfade(to target: Int) {
        guard target >= 0, target < session.meta.pages.count else { return }
        UIView.transition(with: pageContainer, duration: 0.3, options: [.transitionCrossDissolve]) {
            self.session.currentIndex = target
            self.configureSlots()
        }
        session.rememberCurrentPage()
    }

    /// First time only: the bottom corner lifts a little and settles back — no words needed.
    private func playTurnHint() {
        guard turn == nil, !reduceMotion else { return }
        guard beginTurn(mode: .forward, destination: session.currentIndex + 1,
                        grabY: pageFrame.height, interactive: false), var t = turn else { return }
        t.isPeek = true
        t.velocity = CGVector(dx: -700, dy: -300)
        t.commit = false
        t.target = t.grab
        t.damping = 0.55
        turn = t
    }

    func perform(_ tool: JournalTool) {
        guard turn == nil else { return }
        view.endEditing(true)
        switch session.apply(tool) {
        case .stay:
            UIView.transition(with: hosts[currentSlot].view, duration: 0.35, options: [.transitionCrossDissolve]) {
                self.configureSlots()
            }
            Haptics.pageSettled()
        case .go(let index):
            configureSlots()
            turn(to: index)
        }
    }

    // MARK: Frame loop

    private func startLink() {
        stopLink()
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        guard var t = turn else {
            stopLink()
            return
        }
        let now = link.timestamp
        var dt = t.lastTime == 0 ? 1.0 / 60 : now - t.lastTime
        dt = min(max(dt, 1.0 / 240), 1.0 / 30)
        t.lastTime = now
        let size = pageFrame.size
        let W = size.width
        let h = CGFloat(dt)

        if t.dragging {
            let f = CurlGeometry.constrain(t.fingerTarget, grab: t.grab, size: size)
            let inst = CGVector(dx: (f.x - t.finger.x) / h, dy: (f.y - t.finger.y) / h)
            t.velocity = CGVector(dx: t.velocity.dx * 0.6 + inst.dx * 0.4, dy: t.velocity.dy * 0.6 + inst.dy * 0.4)
            t.finger = f
        } else if let target = t.target {
            let k: CGFloat = 230
            let c = 2 * sqrt(k) * t.damping
            let steps = 4
            let sh = h / CGFloat(steps)
            let toFlat = target == t.grab
            for _ in 0..<steps {
                let ax = -k * (t.finger.x - target.x) - c * t.velocity.dx
                let ay = -k * (t.finger.y - target.y) - c * t.velocity.dy
                t.velocity.dx += ax * sh
                t.velocity.dy += ay * sh
                t.finger.x += t.velocity.dx * sh
                t.finger.y += t.velocity.dy * sh
                if toFlat, t.finger.x > t.grab.x {
                    // the sheet can't bend past flat
                    t.finger.x = t.grab.x
                    t.velocity.dx = min(0, t.velocity.dx)
                }
            }
            t.finger = CurlGeometry.constrain(t.finger, grab: t.grab, size: size)
        }

        let speed = hypot(t.velocity.dx, t.velocity.dy)
        // faster hands make the paper billow: a bigger, softer bend
        let targetRadius = W * 0.085 + min(speed * 0.010, W * 0.16)
        t.radius += (targetRadius - t.radius) * min(1, h * 9)
        turn = t
        render()

        let dist = hypot(t.grab.x - t.finger.x, t.grab.y - t.finger.y)
        if !t.isPeek { PaperSound.shared.update(speed: speed / W, lift: dist / (2 * W)) }

        if !t.dragging, let target = t.target {
            let d = hypot(t.finger.x - target.x, t.finger.y - target.y)
            let overSpine = target == t.fullTurn && t.finger.x <= -W * 0.96
            if overSpine || (d < 0.8 && speed < 25) {
                finishTurn()
            }
        }
    }

    private func render() {
        guard let t = turn else { return }
        let W = pageFrame.width
        let dist = hypot(t.grab.x - t.finger.x, t.grab.y - t.finger.y)
        let r = min(t.radius, dist * 0.3)
        let line = CurlGeometry.line(grab: t.grab, finger: t.finger, radius: r)
        var u = curlView.uniforms
        u.linePoint = SIMD2(Float(line.point.x), Float(line.point.y))
        u.lineNormal = SIMD2(Float(line.normal.dx), Float(line.normal.dy))
        u.radius = Float(r)
        // shadow grows as the sheet lifts and fades again as it lies down on the other side
        let progress = min(1, dist / (2 * W))
        u.shadowStrength = Float(min(1, dist / (W * 0.25)) * min(1, max(0, (1 - progress) / 0.2)))
        curlView.uniforms = u
        curlView.draw()
    }

    private func finishTurn() {
        guard let t = turn else { return }
        turn = nil
        stopLink()

        if t.commit {
            if t.mode == .forward {
                if t.destination >= session.meta.pages.count {
                    session.appendBlankPage()   // the waiting blank sheet becomes a real page
                }
                (prevSlot, currentSlot, nextSlot) = (currentSlot, nextSlot, prevSlot)
            } else {
                (prevSlot, currentSlot, nextSlot) = (nextSlot, prevSlot, currentSlot)
            }
            session.currentIndex = max(0, min(t.destination, session.meta.pages.count - 1))
            session.rememberCurrentPage()
        }
        configureSlots()
        curlView.isHidden = true
        curlView.releaseTexture()

        note("finished commit=\(t.commit) page=\(session.currentIndex + 1)")
        if t.isPeek {
            PaperSound.shared.quiet()
        } else {
            Haptics.pageSettled()
            PaperSound.shared.settle(strength: t.commit ? 1 : 0.5)
        }
    }

    // MARK: Snapshot

    private func snapshot(_ v: UIView) -> UIImage? {
        guard v.bounds.width > 1, v.bounds.height > 1 else { return nil }
        // A live PencilKit canvas may not appear in a snapshot; draw its strokes ourselves.
        let canvases = v.allSubviews(of: PKCanvasView.self)
        canvases.forEach { $0.isHidden = true }
        defer { canvases.forEach { $0.isHidden = false } }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(view.traitCollection.displayScale, 3)
        format.opaque = false
        format.preferredRange = .standard   // 8-bit sRGB: what the curl texture expects
        return UIGraphicsImageRenderer(bounds: v.bounds, format: format).image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
            for c in canvases {
                let r = c.convert(c.bounds, to: v)
                c.drawing.image(from: c.bounds, scale: format.scale).draw(in: r)
            }
        }
    }

    // MARK: Keyboard — keep the line being written above the keyboard

    @objc private func keyboardWillChange(_ n: Notification) {
        guard let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        keyboardFrame = view.convert(end, from: nil)
        followCaret()
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        keyboardFrame = .null
        followCaret()
    }

    @objc private func followCaret() {
        guard turn == nil else { return }
        var shift: CGFloat = 0
        if !keyboardFrame.isNull, keyboardFrame.minY < view.bounds.maxY,
           let responder = hosts[currentSlot].view.findFirstResponder() {
            var rect: CGRect
            if let tv = responder as? UITextView, let end = tv.selectedTextRange?.end {
                rect = tv.convert(tv.caretRect(for: end), to: view)
            } else {
                rect = responder.convert(responder.bounds, to: view)
            }
            rect.origin.y -= pageContainer.transform.ty
            shift = max(0, rect.maxY + 18 - keyboardFrame.minY)
        }
        guard abs(shift + pageContainer.transform.ty) > 0.5 else { return }
        UIView.animate(withDuration: 0.28, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.pageContainer.transform = CGAffineTransform(translationX: 0, y: -shift)
        }
    }
}

extension UIView {
    func allSubviews<T: UIView>(of type: T.Type) -> [T] {
        var result: [T] = []
        for s in subviews {
            if let t = s as? T { result.append(t) }
            result.append(contentsOf: s.allSubviews(of: type))
        }
        return result
    }

    func findFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for s in subviews {
            if let r = s.findFirstResponder() { return r }
        }
        return nil
    }
}
