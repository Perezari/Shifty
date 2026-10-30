import QuartzCore
import SwiftUI

/// The app's speed measured on the iPhone, there being no Mac for Instruments (Settings › תצוגה › מדידת מהירות),
/// and shown on a strip over the screens each second: its frames, those late and the longest, and how many times
/// each screen was drawn in it. A frame comes late when the main thread was busy; a screen that stutters with its
/// frames on time is the GPU's.
@MainActor @Observable
final class Perf {
    static let shared = Perf()
    nonisolated static let key = "perfStrip"

    /// The strip's line, once a second.
    private(set) var line = ""
    /// The last few things done (a tab chosen, a long press), each with the time its first frame took to come.
    private(set) var events: [String] = []
    @ObservationIgnored private var pending: (name: String, at: CFTimeInterval)?
    @ObservationIgnored private var running = false
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var clock: FrameClock?
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var since: CFTimeInterval = 0
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var late = 0
    @ObservationIgnored private var worst: CFTimeInterval = 0
    @ObservationIgnored private var draws: [String: Int] = [:]

    /// The screens counted, in the strip's order.
    private static let names = ["עכשיו", "כרטיסים", "משמרות", "שורה", "לוח", "יום", "הגדרות"]

    /// A screen drawn: counted apart from what is observed, so that counting draws nothing again.
    static func drew(_ name: String) {
        guard shared.running else { return }
        shared.draws[name, default: 0] += 1
    }

    /// Something done, timed to the next frame: how long the main thread took over it.
    static func event(_ name: String) {
        guard shared.running else { return }
        shared.pending = (name, CACurrentMediaTime())
    }

    func run(_ on: Bool) {
        guard on != running else { return }
        running = on
        guard on else {
            link?.invalidate()
            link = nil
            clock = nil
            line = ""
            events = []
            pending = nil
            return
        }
        let clock = FrameClock { [weak self] link in
            self?.frame(link)
        }
        let link = CADisplayLink(target: clock, selector: #selector(FrameClock.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.clock = clock
        self.link = link
        last = 0
        since = CACurrentMediaTime()
        frames = 0
        late = 0
        worst = 0
        draws = [:]
    }

    private func frame(_ link: CADisplayLink) {
        if let done = pending {
            pending = nil
            events.append("\(done.name) \(Int(((CACurrentMediaTime() - done.at) * 1000).rounded()))ms")
            if events.count > 4 { events.removeFirst() }
        }
        let now = link.timestamp
        if last > 0 {
            let gap = now - last
            // later than one and a half frames at 60 a second
            if gap > 0.025 { late += 1 }
            worst = max(worst, gap)
        }
        last = now
        frames += 1
        guard now - since >= 1 else { return }
        let counts = Self.names.compactMap { name in draws[name].map { "\(name) \($0)" } }
        line = "\(frames) פריימים · \(late) איטיים · הארוך \(Int((worst * 1000).rounded()))ms"
            + (counts.isEmpty ? "" : " · " + counts.joined(separator: " · "))
        since = now
        frames = 0
        late = 0
        worst = 0
        draws = [:]
    }
}

/// The display link's target: an object, as it asks for.
@MainActor
private final class FrameClock: NSObject {
    private let onFrame: (CADisplayLink) -> Void

    init(_ onFrame: @escaping (CADisplayLink) -> Void) {
        self.onFrame = onFrame
    }

    @objc func tick(_ link: CADisplayLink) {
        onFrame(link)
    }
}

/// The measures, on a strip under the status bar: the last second, and under it the last things done.
struct PerfStrip: View {
    var body: some View {
        let perf = Perf.shared
        VStack(spacing: 2) {
            Text(perf.line)
            if !perf.events.isEmpty {
                Text(perf.events.joined(separator: " · "))
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }
}
