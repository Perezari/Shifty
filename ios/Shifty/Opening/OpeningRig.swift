import Foundation

/// The logo as the openings take it apart: the man's layers and where each lies, the points he moves about, the
/// nine ticks and the mustache's outline. All on the icon's grid of 512 x 512, x to the right and y down. Made from
/// the drawing by ios/Tests/OpeningCheck/mock/tools/rig.py, which cuts the layers' pictures too; the numbers here
/// are its rig.js.
enum OpeningRig {
    /// The icon's grid: its side.
    static let grid = 512.0

    /// Where a layer's picture lies on the grid.
    struct Layer {
        var x: Double
        var y: Double
        var w: Double
        var h: Double

        /// Its middle.
        var middle: OpeningPoint { (x + w / 2, y + h / 2) }
    }

    static let layers: [OpeningPicture: Layer] = [
        .man: Layer(x: 0, y: 0, w: 512, h: 512),
        .body: Layer(x: 0, y: 355, w: 512, h: 157),
        .head: Layer(x: 85.5, y: 67, w: 333.5, h: 324),
        .wings: Layer(x: 171.5, y: 356.5, w: 178.5, h: 102.5),
        .knot: Layer(x: 236, y: 377.5, w: 55, h: 54),
        .stache: Layer(x: 231.5, y: 245, w: 162, h: 75.5),
        .browL: Layer(x: 213, y: 196, w: 62, h: 40),
        .browR: Layer(x: 304, y: 180, w: 49.5, h: 27),
        .eyeL: Layer(x: 232.5, y: 230.5, w: 54.5, h: 32),
        .eyeR: Layer(x: 314.5, y: 214, w: 48, h: 29),
        .stacheL: Layer(x: 231.5, y: 250.5, w: 111, h: 70),
        .stacheR: Layer(x: 302, y: 245, w: 91.5, h: 57),
    ]

    static func layer(_ picture: OpeningPicture) -> Layer {
        layers[picture] ?? Layer(x: 0, y: 0, w: grid, h: grid)
    }

    /// The points the man's parts turn about, and his outlines' corners.
    struct Points {
        /// Where the head turns on the shirt.
        let neck: OpeningPoint = (265.4, 378.9)
        /// The mustache's middle.
        let stache: OpeningPoint = (322.1, 277.6)
        let stacheBox: (left: Double, top: Double, right: Double, bottom: Double) = (235.2, 248.7, 389.5, 316.4)
        /// The bow tie's knot, and its radius.
        let knot: (x: Double, y: Double, r: Double) = (263.3, 404.2, 24.9)
        let browL: OpeningPoint = (241.6, 211.7)
        let browR: OpeningPoint = (327.6, 192.0)
        /// The eye on our left, and the one on our right.
        let eyeL: OpeningPoint = (257.5, 243.1)
        let eyeR: OpeningPoint = (336.6, 225.8)
        let headTop: OpeningPoint = (292.7, 68.6)
        let headBox: (left: Double, top: Double, right: Double, bottom: Double) = (87.4, 68.6, 417.3, 385.8)
        /// The shirt's button.
        let button: OpeningPoint = (263.3, 467.4)
    }

    static let points = Points()

    /// The mustache's outline along its level middle line, from its left end (x0) to its right (x1): at each of
    /// 65 places, evenly, how far its upper edge is above the line and its lower edge below it.
    static let stacheX0 = 235.2
    static let stacheX1 = 389.5
    static let stacheY = 277.6
    static let stacheSamples: [(top: Double, bottom: Double)] = [
        (-5.72, 9.39), (0.41, 17.15), (2.45, 21.23), (2.45, 24.09), (1.22, 26.54), (-1.22, 28.58),
        (-2.04, 29.81), (-2.86, 31.44), (-3.27, 32.66), (-3.67, 33.89), (-3.27, 35.11), (-2.45, 35.93),
        (-1.63, 36.75), (-0.41, 37.15), (1.22, 37.97), (3.67, 38.38), (5.72, 38.38), (8.17, 38.79),
        (11.02, 38.79), (13.47, 38.79), (15.52, 38.79), (17.56, 38.38), (19.19, 38.38), (20.41, 37.97),
        (21.64, 37.15), (22.46, 36.75), (23.27, 35.93), (23.68, 35.11), (23.68, 33.89), (24.09, 32.66),
        (23.68, 31.44), (23.27, 29.81), (22.86, 28.17), (22.05, 26.13), (21.23, 24.09), (20.01, 21.64),
        (18.37, 18.78), (21.23, 15.52), (23.27, 12.25), (24.91, 13.47), (26.54, 15.11), (27.36, 16.33),
        (28.17, 17.56), (28.99, 18.37), (28.99, 19.19), (28.99, 19.6), (28.99, 20.01), (28.17, 20.41),
        (27.76, 20.41), (26.95, 20.41), (25.72, 20.01), (24.5, 20.01), (22.86, 19.19), (21.23, 18.37),
        (20.01, 17.56), (18.78, 16.74), (18.37, 15.52), (17.96, 13.88), (18.37, 12.25), (19.19, 10.62),
        (21.64, 8.17), (25.31, 5.72), (24.91, 2.45), (22.86, -2.04), (15.11, -11.43),
    ]

    /// The ticks' circle: its middle and its radius.
    static let ticksCircle: (x: Double, y: Double, r: Double) = (256, 243.6, 203)

    /// One of the logo's nine ticks: its two ends and its width, its middle, its angle clockwise from 12 round the
    /// ticks' circle, and the hour it stands at, in degrees.
    struct Tick {
        var x1: Double
        var y1: Double
        var x2: Double
        var y2: Double
        var w: Double
        var cx: Double
        var cy: Double
        var deg: Double
        var hour: Double
    }

    /// The hour each tick stands at, in degrees, clockwise from 12.
    static let hours: [Double] = [0, 30, 60, 90, 120, 240, 270, 300, 330]

    /// The nine ticks, clockwise from 12.
    static let ticks: [Tick] = {
        let drawn: [(Double, Double, Double, Double, Double)] = [
            (256.1, 28.6, 256, 51.4, 17.2),
            (144.2, 59.2, 156.9, 78.7, 17),
            (368.5, 59, 355.2, 78.9, 16.9),
            (69.2, 138.4, 91.8, 150.9, 17.5),
            (442.3, 138.2, 419.8, 150.8, 17.2),
            (41, 243.6, 64.7, 243.6, 16.8),
            (446.9, 243.6, 470.1, 243.6, 16.7),
            (86.5, 334.2, 66.4, 346.3, 16.5),
            (426.7, 336, 445.3, 346.9, 16.9),
        ]
        let circle = ticksCircle
        var list = drawn.map { t -> Tick in
            let cx = (t.0 + t.2) / 2, cy = (t.1 + t.3) / 2
            let deg = (atan2(cx - circle.x, circle.y - cy) * 180 / Double.pi + 360).truncatingRemainder(dividingBy: 360)
            return Tick(x1: t.0, y1: t.1, x2: t.2, y2: t.3, w: t.4, cx: cx, cy: cy, deg: deg, hour: 0)
        }
        list.sort { $0.deg < $1.deg }
        for i in list.indices { list[i].hour = hours[i] }
        return list
    }()
}
