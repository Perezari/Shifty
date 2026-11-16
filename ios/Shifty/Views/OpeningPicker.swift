import SwiftUI
import UIKit

/// The opening played at a launch, chosen in Settings › פתיחה: the classic one, which the app's own views play
/// (Opening.swift); one of the six in which the logo's man acts, each a scene (Opening/Scenes) played on the stage
/// (OpeningStage.swift); or another of the six at each launch.
enum OpeningChoice: String, CaseIterable, Identifiable {
    case classic, handlebar, monocle, mrnow, chapeau, ride, butterfly, shuffle

    /// Where the choice is kept (UserDefaults, this device's alone), and what it is with nothing kept.
    static let key = "openingChoice"
    static let standard = OpeningChoice.handlebar
    /// Where the scene the shuffle drew last is kept.
    private static let drawnKey = "openingDrawn"
    /// The six the shuffle draws from.
    private static let scenes: [OpeningChoice] = [.handlebar, .monocle, .mrnow, .chapeau, .ride, .butterfly]

    var id: String { rawValue }

    /// The choice kept; the standard one also for a name this version does not have.
    static var kept: OpeningChoice {
        UserDefaults.standard.string(forKey: key).flatMap(OpeningChoice.init(rawValue:)) ?? standard
    }

    var name: String {
        switch self {
        case .classic: return "קלאסי"
        case .handlebar: return "השפם"
        case .monocle: return "המונוקל"
        case .mrnow: return "מר עכשיו"
        case .chapeau: return "שאפו"
        case .ride: return "הסיבוב"
        case .butterfly: return "הפרפר"
        case .shuffle: return "כל פעם אחרת"
        }
    }

    /// Its own scene; none for the classic nor for the shuffle.
    var own: (any OpeningScene)? {
        switch self {
        case .classic, .shuffle: return nil
        case .handlebar: return HandlebarOpening()
        case .monocle: return MonocleOpening()
        case .mrnow: return MrNowOpening()
        case .chapeau: return ChapeauOpening()
        case .ride: return RideOpening()
        case .butterfly: return ButterflyOpening()
        }
    }

    /// The scene to play now: its own, or for the shuffle one of the six drawn here, never the one it drew last. Nil
    /// for the classic.
    func scene() -> (any OpeningScene)? {
        guard self == .shuffle else { return own }
        let defaults = UserDefaults.standard
        let last = defaults.string(forKey: Self.drawnKey)
        let drawn = Self.scenes.filter { $0.rawValue != last }.randomElement() ?? Self.standard
        defaults.set(drawn.rawValue, forKey: Self.drawnKey)
        return drawn.own
    }
}

/// An opening played from the settings, to see it. The launch picture comes up over the settings, the tabs go to the
/// Now screen under it, the opening plays as at a launch (Opening.replay), the Now screen stays a moment, and the
/// settings are back where they were. A tap at any time, or the app leaving the front, goes straight back.
@MainActor @Observable
final class OpeningPreview {
    static let shared = OpeningPreview()

    /// What is over the tabs beside the opening itself (OpeningPreviewCover).
    enum Stage {
        /// The launch picture, coming up over the settings.
        case curtain
        /// The opening itself: Opening's own cover.
        case playing
        /// The Now screen, a moment.
        case looking
        /// The app's background, on the way back to the settings.
        case leaving
    }

    /// Nil with none on.
    private(set) var stage: Stage?
    /// The Now screen is wanted under the cover: the tabs go there, and back to the settings after (RootView).
    private(set) var onNow = false

    @ObservationIgnored private var flow: Task<Void, Never>?

    func play(_ choice: OpeningChoice) {
        guard stage == nil, Opening.shared.over else { return }
        let scene = choice.scene()
        withAnimation(.easeOut(duration: 0.15)) { stage = .curtain }
        flow = Task {
            await Self.pause(0.22)
            if Task.isCancelled { return }
            // the Now screen, under the launch picture, a moment before it is asked where its dial is
            onNow = true
            await Self.pause(0.06)
            if Task.isCancelled { return }
            stage = .playing
            Opening.shared.replay(scene)
            while !Opening.shared.over, !Task.isCancelled {
                await Self.pause(0.03)
            }
            if Task.isCancelled { return }
            if Opening.shared.skipped {
                await leave()
                return
            }
            stage = .looking
            await Self.pause(0.9)
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.18)) { stage = .leaving }
            await Self.pause(0.2)
            if Task.isCancelled { return }
            onNow = false
            await Self.pause(0.05)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) { stage = nil }
        }
    }

    /// Straight back to the settings.
    func stop() {
        guard stage != nil else { return }
        flow?.cancel()
        flow = Task { await leave() }
    }

    /// The opening ended where it is, the app's background over everything at once, the settings under it, and the
    /// background fades away.
    private func leave() async {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            Opening.shared.stop()
            stage = .leaving
        }
        await Self.pause(0.05)
        onNow = false
        await Self.pause(0.05)
        withAnimation(.easeOut(duration: 0.25)) { stage = nil }
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

/// Over the tabs during a preview, before the opening itself and after it: the launch picture coming up, the app's
/// background on the way back, and a tap anywhere to go straight back.
struct OpeningPreviewCover: View {
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let stage = OpeningPreview.shared.stage
        ZStack {
            if stage == .curtain {
                ZStack {
                    Color.appBackground
                    Image("LaunchMister")
                }
                .transition(.opacity)
            }
            if stage == .leaving {
                Color.appBackground
                    .transition(.opacity)
            }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { OpeningPreview.shared.stop() }
        }
        .ignoresSafeArea()
        .onChange(of: phase) { _, now in
            if now != .active { OpeningPreview.shared.stop() }
        }
    }
}

/// The openings in Settings › פתיחה, four to a row as the icons are three (IconPicker): each a small picture with its
/// name under it, the chosen one ringed in the accent. A tap chooses one, with a light tap of the iPhone, and plays it
/// at once (OpeningPreview).
struct OpeningPicker: View {
    @AppStorage(OpeningChoice.key) private var kept = OpeningChoice.standard.rawValue
    private static let size: CGFloat = 58
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        let chosen = OpeningChoice(rawValue: kept) ?? OpeningChoice.standard
        LazyVGrid(columns: Self.columns, spacing: 16) {
            ForEach(OpeningChoice.allCases) { choice in
                Button {
                    choose(choice)
                } label: {
                    VStack(spacing: 7) {
                        picture(choice, chosen: choice == chosen)
                        Text(choice.name)
                            .font(.footnote)
                            .foregroundStyle(choice == chosen ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.name)
                .accessibilityAddTraits(choice == chosen ? .isSelected : [])
            }
        }
        .padding(.vertical, 14)
    }

    private func picture(_ choice: OpeningChoice, chosen: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.size * 0.2237, style: .continuous)
        let ring = RoundedRectangle(cornerRadius: (Self.size + 10) * 0.2237, style: .continuous)
        return OpeningPoster(choice: choice)
            .frame(width: Self.size, height: Self.size)
            .background(Color.appBackground)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            .padding(5)
            .overlay(ring.strokeBorder(Color.accentColor, lineWidth: 2.5).opacity(chosen ? 1 : 0))
            .accessibilityHidden(true)
    }

    private func choose(_ choice: OpeningChoice) {
        withAnimation(.snappy(duration: 0.2)) { kept = choice.rawValue }
        UISelectionFeedbackGenerator().selectionChanged()
        OpeningPreview.shared.play(choice)
    }
}

/// A choice's small picture. A scene's is its own frame at its poster moment, drawn live by the stage's player on the
/// made-up shift (OpeningLayout.mock) in the app's colors as they are now; the classic's is its signature moment, the
/// whole ring in the accent, drawn with the kit; the shuffle's is its sign.
private struct OpeningPoster: View {
    let choice: OpeningChoice
    @Environment(\.self) private var environment

    /// A cut of the design's screen: its middle and its side, in the design's points.
    private struct Cut {
        var x: Double
        var y: Double
        var side: Double
    }

    /// Each picture's cut of the design's screen of 402 x 874 points (the dial's middle is at 201, 293 and its size
    /// 350; the launch icon's is at 201, 437 and its side 120). Tuned by eye on the pictures as they are drawn here,
    /// the two canvases alone at 58 points, light and dark: each cut is close on what the man does at his scene's
    /// poster moment, so that it reads at this size and the seven weigh about the same. A cut goes with its scene's
    /// `poster` (Opening/Scenes): whoever changes the one looks at the other.
    private static let cuts: [OpeningChoice: Cut] = [
        // the whole ring with air round it, about the size of the handlebar's loop beside it
        .classic: Cut(x: 201, y: 293, side: 420),
        // the whole loop of mustache over him, down to his bow tie
        .handlebar: Cut(x: 201, y: 325, side: 434),
        // his face, the monocle in the picture's very middle
        .monocle: Cut(x: 201, y: 294, side: 280),
        // the giant knob with him in it, the ring's road coming in from the corner
        .mrnow: Cut(x: 273, y: 391, side: 222),
        // his head and the mustache held out beside it, at the dial's own height: its ring shows in the corners alone
        .chapeau: Cut(x: 203, y: 293, side: 300),
        // the medallion on the ring at 12, the arc behind him and the bare track ahead
        .ride: Cut(x: 205, y: 137, side: 150),
        // him in his tile and the bow tie in the air beside his head
        .butterfly: Cut(x: 245, y: 536, side: 226),
    ]
    /// The dial and the launch icon's place, both whole: for a choice the table does not name.
    private static let wide = Cut(x: 201, y: 310, side: 402)

    var body: some View {
        if choice == .shuffle {
            Image(systemName: "shuffle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                let still = Self.still(of: choice, in: OpeningTheme.real(in: environment))
                let fit = Self.fit(Self.cuts[choice] ?? Self.wide, in: proxy.size)
                OpeningCanvas(lists: [still.under, still.over], scale: fit.scale, offset: fit.offset, own: 1,
                              marks: OpeningMarksLook(knob: Color.accentColor, flag: Color.accentColor, reached: false))
            }
        }
    }

    /// The frame a choice's picture shows. (Not named `frame`, which every view has of its own.)
    private static func still(of choice: OpeningChoice, in theme: OpeningTheme) -> OpeningFrame {
        let layout = OpeningLayout.mock(theme)
        if let scene = choice.own {
            return scene.frame(at: scene.poster, layout: layout, theme: theme)
        }
        // the classic: the whole ring in the accent, before it unwinds to the day, with no marks yet
        let kit = OpeningKit(layout: layout, theme: theme)
        kit.dial(wind: 360, ahead: 0, marks: [0, 0, 0])
        return OpeningFrame(under: kit.g.ops, over: kit.o.ops, parts: [:], counted: nil)
    }

    /// The design laid on a picture of `size` so that the cut fills it: its scale and its move.
    private static func fit(_ cut: Cut, in size: CGSize) -> (scale: CGFloat, offset: CGSize) {
        let scale = min(size.width, size.height) / CGFloat(cut.side)
        let left = size.width / 2 - CGFloat(cut.x) * scale
        let top = size.height / 2 - CGFloat(cut.y) * scale
        return (scale, CGSize(width: left, height: top))
    }
}
