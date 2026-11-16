import SwiftUI

// The marks on the Now screen's dial, each a view of its own: the dial (NowView's ShiftDial) places them, pops them up
// and takes their drags, and an opening's scene draws the very same views on its canvases (OpeningStage.swift), so
// that the dial it builds is the real one to the pixel. The dial's four hours, DialHours, are beside the dial itself.

/// Where the shift started: a play sign on a disc in the accent, in a finger's room; while it is dragged it has a
/// halo, as the flag has.
struct DialStartMark: View {
    var moving = false

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.accentColor))
            .background(Circle().fill(Color.accentColor.opacity(moving ? 0.22 : 0)).frame(width: 40, height: 40))
            .frame(width: 44, height: 44)
    }
}

/// Now: a white knob ringed in the state's color.
struct DialKnob: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(color, lineWidth: 3.5))
            .overlay(Circle().fill(color).frame(width: 9, height: 9))
            .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
    }
}

/// The goal's flag, in a halo that asks to be dragged; a check once the goal is reached. Its color is the accent, or a
/// plan's.
struct DialFlag: View {
    let color: Color
    let reached: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 42, height: 42)
            Circle()
                .fill(reached ? Color.accentColor : Color.white)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            Image(systemName: reached ? "checkmark" : "flag.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(reached ? Color.white : color)
        }
    }
}
