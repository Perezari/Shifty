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
    /// The moments after something done, as its animation runs: their frames and the longest of them.
    @ObservationIgnored private var settling: (since: CFTimeInterval, frames: Int, worst: CFTimeInterval)?
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
            settling = nil
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
        let now = link.timestamp
        if last > 0 {
            let gap = now - last
            // later than one and a half frames at 60 a second
            if gap > 0.025 { late += 1 }
            worst = max(worst, gap)
            if let s = settling { settling = (s.since, s.frames + 1, max(s.worst, gap)) }
        }
        last = now
        frames += 1
        if let done = pending {
            pending = nil
            events.append("\(done.name) \(Int(((CACurrentMediaTime() - done.at) * 1000).rounded()))ms")
            if events.count > 3 { events.removeFirst() }
            settling = (now, 0, 0)
        }
        // and once its animation is over, how it ran: 48 frames here are all there are at 120 a second, 24 at 60
        if let s = settling, now - s.since >= 0.4, let event = events.last {
            settling = nil
            events[events.count - 1] = event + " (\(s.frames) פריימים, הארוך \(Int((s.worst * 1000).rounded()))ms)"
        }
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
