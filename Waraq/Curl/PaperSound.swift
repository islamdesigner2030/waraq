import AVFoundation
import UIKit

/// A soft, low paper rustle synthesised in real time and driven by the page's motion,
/// so the sound is always in step with the finger. Plus a muted "settle" as the page lands.
/// Uses the ambient audio category: it respects the silent switch and mixes with music.
final class PaperSound {
    static let shared = PaperSound()

    var isEnabled = true {
        didSet { if !isEnabled { synth.targetGain = 0 } }
    }

    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private let synth = Synth()

    /// Shared between the main thread (writes targets) and the audio thread (reads them).
    /// Plain floats: a torn read only means one slightly different sample.
    final class Synth {
        var targetGain: Float = 0
        var brightness: Float = 0.5
        var thump: Float = 0
        // audio-thread state
        var gain: Float = 0
        var bright: Float = 0.5
        var thumpEnv: Float = 0
        var low: Float = 0
        var lp: Float = 0
        var hp: Float = 0
        var grain: Float = 0
        var seed: UInt32 = 0x2545F491
        var sampleRate: Float = 48_000
    }

    func prepare() {
        guard engine == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        var rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if rate <= 0 { rate = 48_000 }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        let s = synth
        s.sampleRate = Float(rate)

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let sr = s.sampleRate
            let twoPi: Float = 2 * .pi
            let lowCoef = 1 - expf(-twoPi * 220 / sr)
            let hpCoef = 1 - expf(-twoPi * 260 / sr)
            for frame in 0..<Int(frameCount) {
                s.seed = s.seed &* 1_664_525 &+ 1_013_904_223
                let white = Float(Int32(bitPattern: s.seed)) / Float(Int32.max)

                s.gain += (s.targetGain - s.gain) * 0.0009
                s.bright += (s.brightness - s.bright) * 0.0005
                let lpCut: Float = 900 + 2600 * s.bright
                let lpCoef = 1 - expf(-twoPi * lpCut / sr)

                // band-limited noise: the body of the rustle
                s.lp += (white - s.lp) * lpCoef
                s.hp += (s.lp - s.hp) * hpCoef
                var band = s.lp - s.hp

                // sparse grains give the papery crackle, more of them when moving fast
                if (s.seed >> 9) % 4000 < UInt32(s.gain * 60) { s.grain = 1 }
                s.grain *= 0.9965
                band *= 0.65 + 0.9 * s.grain

                // settle: a short, very low, muffled thump
                if s.thump > 0 { s.thumpEnv = min(1, s.thumpEnv + s.thump); s.thump = 0 }
                s.thumpEnv *= 0.99925
                s.low += (white - s.low) * lowCoef

                var out = band * s.gain * 0.9 + s.low * s.thumpEnv * 1.6
                out = tanhf(out * 1.2) * 0.7
                for buffer in buffers {
                    let ptr = UnsafeMutableBufferPointer<Float>(buffer)
                    if frame < ptr.count { ptr[frame] = out }
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.85
        do {
            try engine.start()
            self.engine = engine
            self.source = node
        } catch {
            self.engine = nil
        }
    }

    func shutdown() {
        synth.targetGain = 0
        engine?.stop()
        engine = nil
        source = nil
    }

    /// speed: page speed in page-widths per second. lift: 0 (flat) … 1 (fully turned).
    func update(speed: CGFloat, lift: CGFloat) {
        guard isEnabled, engine != nil else { return }
        let s = Float(min(1.4, speed))
        let l = Float(min(1, max(0, lift)))
        synth.targetGain = min(0.55, s * 0.42) * (0.35 + 0.65 * min(1, l * 3))
        synth.brightness = min(1, s * 0.6)
    }

    func quiet() { synth.targetGain = 0 }

    func settle(strength: CGFloat = 1) {
        synth.targetGain = 0
        guard isEnabled, engine != nil else { return }
        synth.thump = Float(min(1, max(0.2, strength))) * 0.5
    }
}

enum Haptics {
    static func pageSettled() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.impactOccurred(intensity: 0.45)
    }

    static func saved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func pageFull() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.4)
    }
}
