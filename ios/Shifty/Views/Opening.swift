import SwiftUI
import UIKit

/// The opening at a launch of the app, the design the user picked of three: the icon, where iOS's launch left it,
/// opens into the Now screen's dial; its ticks come in, the whole ring unwinds to the day as it is, the dial settles in
/// its place and the screen is built round it. About two and a half seconds, and a tap skips it. One clock runs it:
/// the dial draws itself by it (ShiftDial, DialOpening), the screen's other parts come up by it (`openingPart`), and
/// the cover here hides the tab bar. Not at the first launch, which opens on the first setup, nor by a quick action or
/// a widget's link, nor with Reduce Motion; with the lock on, after it.
@MainActor @Observable
final class Opening {
    static let shared = Opening()

    /// The design's seconds to real ones: at its own speed, 1.4 seconds, it was too quick to take in.
    private static let stretch = 1.7
    /// In the design's seconds: the last part is up.
    private static let end = 1.31
    /// In the design's seconds: the ring is unwound and the dial nearly in place, and the iPhone taps once.
    private static let landing = 0.86

    /// Done with, or never to be shown, which `arm` alone changes.
    private(set) var over = true
    /// When it began. Until then the cover shows the icon still.
    private(set) var began: Date?
    /// The screen's middle, and the dial's in its place, on the screen: from where the dial begins.
    var screenMiddle: CGFloat?
    var dialMiddle: CGFloat?

    @ObservationIgnored private var waitsForLock = false
    @ObservationIgnored private var started = false

    /// At the app's launch: to be shown, unless the app opens on the first setup, motion is to be reduced or the
    /// screen is being read out.
    func arm(firstSetup: Bool) {
        guard !firstSetup, !UIAccessibility.isReduceMotionEnabled, !UIAccessibility.isVoiceOverRunning else { return }
        waitsForLock = UserDefaults.standard.bool(forKey: AppLock.key)
        over = false
    }

    /// The moment at `date`, in the design's seconds: 0 until it begins, and long past its end once it is over.
    func time(at date: Date) -> Double {
        if over { return 9 }
        guard let began else { return 0 }
        return date.timeIntervalSince(began) / Self.stretch
    }

    /// Waits until the moment `t` of the opening, in the design's seconds; at once when there is none or it is over.
    func reach(_ t: Double) async {
        while !over, began == nil, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !over, let began else { return }
        let wait = began.addingTimeInterval(t * Self.stretch).timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
    }

    /// From the dial's place to the screen's middle.
    var travel: CGFloat {
        guard let screenMiddle, let dialMiddle else { return 0 }
        return screenMiddle - dialMiddle
    }

    /// The app is in front, for the first time since it was launched.
    func start() {
        guard !over, !started, !waitsForLock else { return }
        started = true
        Task { await run() }
    }

    /// The lock is open.
    func unlocked() {
        guard waitsForLock else { return }
        waitsForLock = false
        start()
    }

    /// A tap on it, or the app opened for something else: the screen as it is, at once.
    func skip() {
        guard !over else { return }
        withAnimation(.easeOut(duration: 0.2)) { over = true }
    }

    private func run() async {
        // a beat on the icon, as iOS's zoom into the app ends and the screen under it is ready
        try? await Task.sleep(for: .seconds(0.2))
        var waited = 0.0
        while dialMiddle == nil, waited < 1 {
            try? await Task.sleep(for: .milliseconds(50))
            waited += 0.05
        }
        guard !over else { return }
        guard dialMiddle != nil else {
            skip()
            return
        }
        began = Date()
        let tap = UIImpactFeedbackGenerator(style: .light)
        tap.prepare()
        try? await Task.sleep(for: .seconds(Self.landing * Self.stretch))
        if !over { tap.impactOccurred() }
        try? await Task.sleep(for: .seconds((Self.end - Self.landing) * Self.stretch))
        over = true
    }
}

/// How far a part of the opening has come at the moment `t`, from `a` to `b`, from 0 to 1, on its curve.
enum OpeningCurve {
    static func line(_ t: Double, _ a: Double, _ b: Double) -> Double {
        min(1, max(0, (t - a) / (b - a)))
    }

    static func out3(_ t: Double, _ a: Double, _ b: Double) -> Double {
        1 - pow(1 - line(t, a, b), 3)
    }

    static func out5(_ t: Double, _ a: Double, _ b: Double) -> Double {
        1 - pow(1 - line(t, a, b), 5)
    }

    static func inOut2(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = line(t, a, b)
        return x < 0.5 ? 2 * x * x : 1 - pow(2 - 2 * x, 2) / 2
    }

    static func inOut3(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = line(t, a, b)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(2 - 2 * x, 3) / 2
    }

    /// Past 1 a little on the way, and back.
    static func back(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = line(t, a, b) - 1
        return 1 + 2.9 * x * x * x + 1.9 * x * x
    }

    /// A mark of the dial popping up, from `a`; never quite 0, as a scale of nothing draws badly.
    static func pop(_ t: Double, _ a: Double) -> Double {
        max(0.001, back(t, a, a + 0.18))
    }
}

extension View {
    /// A part of the Now screen coming up in the opening, from the moment `start` (the design's seconds); once it is
    /// over, as it is.
    func openingPart(_ start: Double) -> some View {
        modifier(OpeningPart(start: start))
    }
}

private struct OpeningPart: ViewModifier {
    let start: Double

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: Opening.shared.over)) { context in
            let shown = OpeningCurve.out3(Opening.shared.time(at: context.date), start, start + 0.34)
            content
                .opacity(shown)
                .offset(y: CGFloat(1 - shown) * 46)
        }
    }
}

/// Over the tabs while the opening is on: the icon on the app's background until it begins, the very picture of
/// iOS's launch screen, so that the launch runs straight into it; then only over the tab bar, which the Now screen's
/// parts cannot hide, until its turn comes. A tap anywhere skips it.
struct OpeningCover: View {
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let opening = Opening.shared
        if !opening.over {
            GeometryReader { proxy in
                ZStack {
                    if opening.began == nil {
                        Color.appBackground
                        Image("LaunchShekel")
                    } else {
                        OpeningCurtain()
                    }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { opening.skip() }
                }
                .onChange(of: proxy.frame(in: .global).midY, initial: true) { _, middle in
                    opening.screenMiddle = middle
                }
            }
            .ignoresSafeArea()
            .onChange(of: phase, initial: true) { _, now in
                if now == .active { opening.start() }
            }
        }
    }
}

/// The app's background over the tab bar, its top edge soft, going away in the last part of the opening.
private struct OpeningCurtain: View {
    var body: some View {
        TimelineView(.animation) { context in
            let shown = OpeningCurve.out3(Opening.shared.time(at: context.date), 0.96, 1.3)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(colors: [Color.appBackground.opacity(0), Color.appBackground], startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
                Color.appBackground
                    .frame(height: 106)
            }
            .opacity(1 - shown)
        }
        .allowsHitTesting(false)
    }
}

/// The dial while the opening is on, at its moment `time`, everything but its hours and its marks, which are the real
/// ones: on one canvas, a frame at a time, as the ticks come in one after another. Once it is over the real dial takes
/// its place, drawn the same.
struct DialOpening: View {
    let size: CGFloat
    let layout: DialLayout
    let time: Double

    var body: some View {
        Canvas { context, _ in
            OpeningDrawing.draw(context, size: size, layout: layout, at: time)
        }
        .frame(width: size, height: size)
    }
}

private enum OpeningDrawing {
    /// The icon's ground, top and bottom, as ios/AppIcon.svg paints it (AppIcon-dark.svg in the dark look), 0...255.
    private static let lightGround: (top: [Double], bottom: [Double]) = ([255, 255, 255], [227, 237, 235])
    private static let darkGround: (top: [Double], bottom: [Double]) = ([38, 43, 46], [11, 12, 13])

    static func draw(_ context: GraphicsContext, size: CGFloat, layout: DialLayout, at t: Double) {
        let c = size / 2
        let r = size * 160 / 350
        let w = size * 22 / 350
        track(context, c, r, w, at: t)
        ticks(context, c, r, w, at: t)
        pieces(context, c, r, w, layout, at: t)
        ring(context, c, r, w, layout, at: t)
        icon(context, c, r, w, at: t)
    }

    private static func track(_ context: GraphicsContext, _ c: CGFloat, _ r: CGFloat, _ w: CGFloat, at t: Double) {
        let alpha = OpeningCurve.line(t, 0.2, 0.38)
        guard alpha > 0 else { return }
        context.stroke(circle(c, r), with: .color(Color.primary.opacity(0.06 * alpha)), lineWidth: w)
    }

    /// The minutes' ticks, in a wave clockwise from 12.
    private static func ticks(_ context: GraphicsContext, _ c: CGFloat, _ r: CGFloat, _ w: CGFloat, at t: Double) {
        for i in 0..<60 {
            let from = 0.3 + Double(i) / 60 * 0.34
            let k = OpeningCurve.back(t, from, from + 0.16)
            guard k > 0 else { continue }
            let big = i % 5 == 0
            let thick: CGFloat = big ? 2 : 1.5
            let long: CGFloat = (big ? 9 : 4) * CGFloat(k)
            let middle: CGFloat = r - w / 2 - (big ? 11.5 : 9)
            let shade: Color = big ? Color.secondary : Color.secondary.opacity(0.45)
            let rect = CGRect(x: -thick / 2, y: -middle - long / 2, width: thick, height: long)
            var g = context
            g.translateBy(x: c, y: c)
            g.rotate(by: .degrees(Double(i) * 6))
            g.opacity = min(1, k)
            g.fill(Path(roundedRect: rect, cornerRadius: min(thick, long) / 2), with: .color(shade))
        }
    }

    /// The day as it is, under the ring until the ring unwinds off it.
    private static func pieces(_ context: GraphicsContext, _ c: CGFloat, _ r: CGFloat, _ w: CGFloat, _ layout: DialLayout, at t: Double) {
        let alpha = OpeningCurve.line(t, 0.36, 0.5)
        guard alpha > 0 else { return }
        var g = context
        g.opacity = alpha
        let start = layout.startDeg
        for piece in layout.pieces {
            let path = arc(c, r, start + piece.from, start + piece.to)
            g.stroke(path, with: .color(piece.kind.color), style: StrokeStyle(lineWidth: w, lineCap: .butt))
        }
    }

    /// The whole ring in the accent, once the icon has opened into it, unwinding: to now with a shift running, and
    /// back to its start with none. Over the time worked it fades instead, for a break's color to show there.
    private static func ring(_ context: GraphicsContext, _ c: CGFloat, _ r: CGFloat, _ w: CGFloat, _ layout: DialLayout, at t: Double) {
        let unwind = OpeningCurve.inOut3(t, 0.38, 0.86)
        guard t >= 0.36, unwind < 1 else { return }
        let start = layout.startDeg
        let worked = layout.goalDeg != nil ? layout.nowDeg : 0
        let span = 360 + (worked - 360) * unwind
        let style = StrokeStyle(lineWidth: w, lineCap: .butt)
        context.stroke(arc(c, r, start + max(0, worked - 1), start + span), with: .color(Color.accentColor), style: style)
        if worked > 0 {
            var g = context
            g.opacity = 1 - unwind
            g.stroke(arc(c, r, start, start + worked), with: .color(Color.accentColor), style: style)
        }
    }

    /// The icon: a rounded square growing into the dial's circle in the accent, its mark fading and a hole opening in
    /// its middle, until it is the ring. It begins as LaunchShekel, the picture iOS's launch screen leaves: white, with a
    /// hairline inside its edge, or AppIcon-dark.svg's in the dark look.
    private static func icon(_ context: GraphicsContext, _ c: CGFloat, _ r: CGFloat, _ w: CGFloat, at t: Double) {
        let p = OpeningCurve.inOut3(t, 0.03, 0.36)
        guard p < 1 else { return }
        let dark = context.environment.colorScheme == .dark
        let half: CGFloat = 60 + (r + w / 2 - 60) * CGFloat(p)
        let corner: CGFloat = 27 + (half - 27) * CGFloat(pow(p, 0.55))
        let hole: CGFloat = (r - w / 2) * CGFloat(OpeningCurve.inOut3(t, 0.13, 0.36))
        let box = CGRect(x: c - half, y: c - half, width: half * 2, height: half * 2)
        var shape = Path(roundedRect: box, cornerRadius: corner, style: .circular)
        if hole > 0 {
            shape.addPath(circle(c, hole))
        }
        let stops = [0, 0.1375, 0.275, 0.4125, 0.55, 1].map { y in
            Gradient.Stop(color: ground(y, dark: dark).mix(with: Color.accentColor, by: p), location: y)
        }
        let shading = GraphicsContext.Shading.linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: box.midX, y: box.minY),
                                                             endPoint: CGPoint(x: box.midX, y: box.maxY))
        context.fill(shape, with: shading, style: FillStyle(eoFill: true))
        let k = half / 256
        if !dark {
            let inset = 1.1 * k
            let edge = Path(roundedRect: box.insetBy(dx: inset, dy: inset), cornerRadius: corner - inset, style: .circular)
            context.stroke(edge, with: .color(Color.black.opacity(0.07 * (1 - p))), lineWidth: 2.2 * k)
        }
        let alpha = 1 - OpeningCurve.out3(t, 0.04, 0.17)
        if alpha > 0 {
            mark(context, c, k, dark: dark, alpha: alpha)
        }
    }

    /// The icon's ground at `y`, 0 at its top and 1 at its bottom: its gradient under a white sheen, 16% at the top
    /// and gone by 55%, as the SVG lays them.
    private static func ground(_ y: Double, dark: Bool) -> Color {
        let (top, bottom) = dark ? darkGround : lightGround
        let sheen = 0.16 * max(0, 1 - y / 0.55)
        func channel(_ i: Int) -> Double {
            let base = (top[i] + (bottom[i] - top[i]) * y) / 255
            return base + (1 - base) * sheen
        }
        return Color(red: channel(0), green: channel(1), blue: channel(2))
    }

    /// The icon's mark, as ios/AppIcon.svg draws it, by `k` from its 512 points: a clock's twelve ticks, the four at
    /// 12, 3, 6 and 9 longer, and the shekel sign, in the app's color, brighter in the dark look.
    private static func mark(_ context: GraphicsContext, _ c: CGFloat, _ k: CGFloat, dark: Bool, alpha: Double) {
        let tick = dark ? Color(red: 63 / 255, green: 220 / 255, blue: 200 / 255)
                        : Color(red: 15 / 255, green: 157 / 255, blue: 143 / 255)
        for i in 0..<12 {
            let big = i % 3 == 0
            let inner: CGFloat = big ? 168 : 180
            var line = Path()
            line.move(to: CGPoint(x: 0, y: -inner * k))
            line.addLine(to: CGPoint(x: 0, y: -204 * k))
            var g = context
            g.translateBy(x: c, y: c)
            g.rotate(by: .degrees(Double(i) * 30))
            g.stroke(line, with: .color(tick.opacity((big ? 0.9 : 0.4) * alpha)),
                     style: StrokeStyle(lineWidth: (big ? 15 : 10) * k, lineCap: .round))
        }
        let from = dark ? Color(red: 75 / 255, green: 232 / 255, blue: 212 / 255)
                        : Color(red: 30 / 255, green: 198 / 255, blue: 180 / 255)
        let to = dark ? Color(red: 17 / 255, green: 163 / 255, blue: 147 / 255)
                      : Color(red: 10 / 255, green: 120 / 255, blue: 109 / 255)
        let gradient = Gradient(colors: [from.opacity(alpha), to.opacity(alpha)])
        let style = StrokeStyle(lineWidth: 32 * k, lineCap: .round, lineJoin: .round)
        for part in shekel(c, k) {
            let box = part.boundingRect
            context.stroke(part, with: .linearGradient(gradient, startPoint: box.origin,
                                                      endPoint: CGPoint(x: box.maxX, y: box.maxY)), style: style)
        }
    }

    /// The shekel sign's two strokes, by `k` from AppIcon.svg's 512 points about its middle: an arch whose left leg
    /// reaches down, and interlocked with it a cup whose right leg reaches up.
    private static func shekel(_ c: CGFloat, _ k: CGFloat) -> [Path] {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: c + (x - 256) * k, y: c + (y - 256) * k)
        }
        let radius = 50 * k
        var arch = Path()
        arch.move(to: at(166, 346))
        arch.addLine(to: at(166, 216))
        arch.addArc(center: at(216, 216), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        arch.addLine(to: at(236, 166))
        arch.addArc(center: at(236, 216), radius: radius, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        arch.addLine(to: at(286, 290))
        var cup = Path()
        cup.move(to: at(226, 222))
        cup.addLine(to: at(226, 296))
        cup.addArc(center: at(276, 296), radius: radius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        cup.addLine(to: at(296, 346))
        cup.addArc(center: at(296, 296), radius: radius, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        cup.addLine(to: at(346, 166))
        return [arch, cup]
    }

    private static func circle(_ c: CGFloat, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c - radius, y: c - radius, width: radius * 2, height: radius * 2))
    }

    /// An arc from `from` to `to`, in degrees clockwise from 12.
    private static func arc(_ c: CGFloat, _ radius: CGFloat, _ from: Double, _ to: Double) -> Path {
        guard to > from else { return Path() }
        guard to - from < 359.9 else { return circle(c, radius) }
        var path = Path()
        path.addArc(center: CGPoint(x: c, y: c), radius: radius, startAngle: .degrees(from - 90),
                    endAngle: .degrees(to - 90), clockwise: false)
        return path
    }
}

/// iOS keeps its own picture of the launch screen, and after an update may go on showing the old one: 1.5's first
/// launches showed the old icon fading into the new. So the launch picture takes a new name with a new design
/// (LaunchShekel; LaunchIcon until 1.5), and once a version, a few seconds into the launch, the kept picture is thrown
/// away for iOS to draw it again at the next launch.
enum LaunchScreenCache {
    private static let key = "launchScreenClearedFor"

    static func clearOncePerVersion() {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String ?? "") + "-" + (info?["CFBundleVersion"] as? String ?? "")
        guard UserDefaults.standard.string(forKey: key) != version else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
            try? FileManager.default.removeItem(at: URL.libraryDirectory.appending(path: "SplashBoard", directoryHint: .isDirectory))
            UserDefaults.standard.set(version, forKey: key)
        }
    }
}
