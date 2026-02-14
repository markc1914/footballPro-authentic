//
//  RetroStyle.swift
//  footballPro
//
//  Authentic Front Page Sports: Football Pro '93 (Dynamix/Sierra) styling
//  Black backgrounds, dark maroon buttons, green play slots, amber LED digits
//

import SwiftUI

// MARK: - FPS '93 Color Palette (matched from actual gameplay video frames)

struct VGA {
    // Screen backgrounds
    static let screenBg = Color.black
    static let dialogBg = Color.black

    // Panel/frame colors — DOS medium gray (as seen in play calling screen frame)
    static let panelBg = Color(red: 0.63, green: 0.63, blue: 0.63)        // ~#A0A0A0 medium gray
    static let panelLight = Color(red: 0.75, green: 0.75, blue: 0.75)     // ~#C0C0C0 light gray highlight
    static let panelDark = Color(red: 0.40, green: 0.40, blue: 0.40)      // ~#666666 dark gray shadow
    static let panelVeryDark = Color(red: 0.12, green: 0.12, blue: 0.14)  // ~#1E1E24 scoreboard bg
    static let titleBarBg = Color(red: 0.40, green: 0.40, blue: 0.40)     // ~#666666

    // Button colors — TRUE RED (vivid, not dark maroon)
    static let buttonBg = Color(red: 0.73, green: 0.13, blue: 0.13)       // ~#BB2222 true red
    static let buttonHighlight = Color(red: 0.88, green: 0.22, blue: 0.22) // ~#E03838 lighter red
    static let buttonShadow = Color(red: 0.45, green: 0.06, blue: 0.06)   // ~#730F0F darker red

    // Play slot colors (bright green grid as seen in video)
    static let playSlotGreen = Color(red: 0.15, green: 0.58, blue: 0.15)  // ~#269426 bright green
    static let playSlotDark = Color(red: 0.08, green: 0.35, blue: 0.08)   // ~#145914 dark green border
    static let playSlotSelected = Color(red: 0.22, green: 0.72, blue: 0.22) // ~#38B838 highlight

    // Digital LED colors (amber clock display)
    static let digitalAmber = Color(red: 1.0, green: 0.65, blue: 0.0)     // ~#FFA600
    static let digitalDim = Color(red: 0.30, green: 0.20, blue: 0.0)      // ~#4D3300

    // Bevel border colors (DOS 3D effect — light top/left, dark bottom/right)
    static let highlightOuter = Color(red: 0.87, green: 0.87, blue: 0.87) // ~#DEDEDE white-ish
    static let highlightInner = Color(red: 0.75, green: 0.75, blue: 0.75) // ~#C0C0C0
    static let shadowInner = Color(red: 0.38, green: 0.38, blue: 0.38)    // ~#606060
    static let shadowOuter = Color(red: 0.20, green: 0.20, blue: 0.20)    // ~#333333

    // Field colors
    static let grassLight = Color(red: 0.18, green: 0.55, blue: 0.18)
    static let grassDark = Color(red: 0.10, green: 0.36, blue: 0.10)
    static let endZoneRed = Color(red: 0.55, green: 0.0, blue: 0.0)
    static let endZoneBlue = Color(red: 0.0, green: 0.0, blue: 0.50)
    static let fieldLine = Color(red: 0.95, green: 0.95, blue: 0.95)

    // Text colors
    static let yellow = Color(red: 1.0, green: 1.0, blue: 0.0)
    static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let green = Color(red: 0.0, green: 1.0, blue: 0.0)
    static let brightRed = Color(red: 1.0, green: 0.0, blue: 0.0)
    static let orange = Color(red: 1.0, green: 0.40, blue: 0.0)
    static let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)
    static let white = Color.white
    static let lightGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let darkGray = Color(red: 0.33, green: 0.33, blue: 0.33)
    static let black = Color.black

    // Chalkboard colors (kept for play diagram compatibility)
    static let chalkboardBg = Color(red: 0.10, green: 0.23, blue: 0.10)
    static let chalk = Color(red: 0.91, green: 0.91, blue: 0.82)
    static let chalkFaint = Color(red: 0.91, green: 0.91, blue: 0.82).opacity(0.5)
    static let chalkRed = Color(red: 1.0, green: 0.45, blue: 0.40)
    static let chalkYellow = Color(red: 1.0, green: 0.95, blue: 0.55)
    static let chalkBlue = Color(red: 0.55, green: 0.70, blue: 1.0)
}

// MARK: - Retro Font Helpers

struct RetroFont {
    static func tiny() -> Font { .system(size: 9, weight: .regular, design: .monospaced) }
    static func small() -> Font { .system(size: 10, weight: .regular, design: .monospaced) }
    static func body() -> Font { .system(size: 12, weight: .regular, design: .monospaced) }
    static func bodyBold() -> Font { .system(size: 12, weight: .bold, design: .monospaced) }
    static func header() -> Font { .system(size: 14, weight: .bold, design: .monospaced) }
    static func title() -> Font { .system(size: 18, weight: .bold, design: .monospaced) }
    static func large() -> Font { .system(size: 24, weight: .bold, design: .monospaced) }
    static func huge() -> Font { .system(size: 36, weight: .bold, design: .monospaced) }
    static func score() -> Font { .system(size: 48, weight: .bold, design: .monospaced) }
}

// MARK: - DOS 3D Beveled Panel Border

struct DOSPanelBorder: ViewModifier {
    let style: PanelStyle
    let borderWidth: CGFloat

    enum PanelStyle {
        case raised
        case sunken
    }

    init(_ style: PanelStyle = .raised, width: CGFloat = 2) {
        self.style = style
        self.borderWidth = width
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let bw = borderWidth

                    let topLeft = style == .raised ? VGA.highlightOuter : VGA.shadowOuter
                    let topLeftInner = style == .raised ? VGA.highlightInner : VGA.shadowInner
                    let bottomRight = style == .raised ? VGA.shadowOuter : VGA.highlightOuter
                    let bottomRightInner = style == .raised ? VGA.shadowInner : VGA.highlightInner

                    // Top edge (outer)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: w, y: 0))
                        p.addLine(to: CGPoint(x: w - bw, y: bw))
                        p.addLine(to: CGPoint(x: bw, y: bw))
                        p.closeSubpath()
                    }
                    .fill(topLeft)

                    // Left edge (outer)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: bw, y: bw))
                        p.addLine(to: CGPoint(x: bw, y: h - bw))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(topLeft)

                    // Top edge (inner)
                    Path { p in
                        p.move(to: CGPoint(x: bw, y: bw))
                        p.addLine(to: CGPoint(x: w - bw, y: bw))
                        p.addLine(to: CGPoint(x: w - bw * 2, y: bw * 2))
                        p.addLine(to: CGPoint(x: bw * 2, y: bw * 2))
                        p.closeSubpath()
                    }
                    .fill(topLeftInner)

                    // Left edge (inner)
                    Path { p in
                        p.move(to: CGPoint(x: bw, y: bw))
                        p.addLine(to: CGPoint(x: bw * 2, y: bw * 2))
                        p.addLine(to: CGPoint(x: bw * 2, y: h - bw * 2))
                        p.addLine(to: CGPoint(x: bw, y: h - bw))
                        p.closeSubpath()
                    }
                    .fill(topLeftInner)

                    // Bottom edge (outer)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: w - bw, y: h - bw))
                        p.addLine(to: CGPoint(x: bw, y: h - bw))
                        p.closeSubpath()
                    }
                    .fill(bottomRight)

                    // Right edge (outer)
                    Path { p in
                        p.move(to: CGPoint(x: w, y: 0))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: w - bw, y: h - bw))
                        p.addLine(to: CGPoint(x: w - bw, y: bw))
                        p.closeSubpath()
                    }
                    .fill(bottomRight)

                    // Bottom edge (inner)
                    Path { p in
                        p.move(to: CGPoint(x: bw, y: h - bw))
                        p.addLine(to: CGPoint(x: w - bw, y: h - bw))
                        p.addLine(to: CGPoint(x: w - bw * 2, y: h - bw * 2))
                        p.addLine(to: CGPoint(x: bw * 2, y: h - bw * 2))
                        p.closeSubpath()
                    }
                    .fill(bottomRightInner)

                    // Right edge (inner)
                    Path { p in
                        p.move(to: CGPoint(x: w - bw, y: bw))
                        p.addLine(to: CGPoint(x: w - bw, y: h - bw))
                        p.addLine(to: CGPoint(x: w - bw * 2, y: h - bw * 2))
                        p.addLine(to: CGPoint(x: w - bw * 2, y: bw * 2))
                        p.closeSubpath()
                    }
                    .fill(bottomRightInner)
                }
            )
    }
}

// MARK: - FPS '93 Button (Dark Maroon 3D Beveled)

struct FPSButton: View {
    let title: String
    let action: () -> Void
    var width: CGFloat? = nil

    @State private var isPressed = false

    init(_ title: String, width: CGFloat? = nil, action: @escaping () -> Void) {
        self.title = title
        self.width = width
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RetroFont.bodyBold())
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(minWidth: width ?? 0)
                .background(isPressed ? VGA.buttonShadow : VGA.buttonBg)
                .overlay(
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let bw: CGFloat = 2

                        let topColor = isPressed ? VGA.buttonShadow : VGA.buttonHighlight
                        let bottomColor = isPressed ? VGA.buttonHighlight : VGA.buttonShadow

                        // Top bevel
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: 0))
                            p.addLine(to: CGPoint(x: w, y: 0))
                            p.addLine(to: CGPoint(x: w - bw, y: bw))
                            p.addLine(to: CGPoint(x: bw, y: bw))
                            p.closeSubpath()
                        }.fill(topColor)

                        // Left bevel
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: 0))
                            p.addLine(to: CGPoint(x: bw, y: bw))
                            p.addLine(to: CGPoint(x: bw, y: h - bw))
                            p.addLine(to: CGPoint(x: 0, y: h))
                            p.closeSubpath()
                        }.fill(topColor)

                        // Bottom bevel
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h))
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: w - bw, y: h - bw))
                            p.addLine(to: CGPoint(x: bw, y: h - bw))
                            p.closeSubpath()
                        }.fill(bottomColor)

                        // Right bevel
                        Path { p in
                            p.move(to: CGPoint(x: w, y: 0))
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: w - bw, y: h - bw))
                            p.addLine(to: CGPoint(x: w - bw, y: bw))
                            p.closeSubpath()
                        }.fill(bottomColor)
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - FPS '93 Dialog Frame (Dark Charcoal Beveled)

struct FPSDialog<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let title = title {
                HStack {
                    Text(title)
                        .font(RetroFont.bodyBold())
                        .foregroundColor(VGA.lightGray)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VGA.titleBarBg)
            }

            content
                .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised))
    }
}

// MARK: - FPS '93 Bevel Frame (Simple charcoal border)

struct FPSBevelFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(VGA.panelBg)
            .modifier(DOSPanelBorder(.raised))
    }
}

// MARK: - FPS '93 Digital Clock (Amber LED Digits)

struct FPSDigitalClock: View {
    let time: String
    var fontSize: CGFloat = 28

    var body: some View {
        ZStack {
            // Dim "ghost" digits behind (like real LED segments)
            Text(ghostText(for: time))
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(VGA.digitalDim)

            // Active digits
            Text(time)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(VGA.digitalAmber)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black)
    }

    private func ghostText(for time: String) -> String {
        time.map { ch in
            if ch.isNumber { return "8" }
            return String(ch)
        }.joined()
    }
}

// MARK: - FPS '93 Play Slot (Green Rectangle)

struct FPSPlaySlot: View {
    let number: Int
    let playName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(RetroFont.small())
                    .foregroundColor(isSelected ? .black : VGA.playSlotDark)
                    .frame(width: 18, alignment: .trailing)

                Text(playName)
                    .font(.system(size: 11, weight: .regular, design: .monospaced).italic())
                    .foregroundColor(isSelected ? .black : .white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isSelected ? VGA.playSlotSelected : VGA.playSlotGreen)
            .overlay(
                Rectangle()
                    .stroke(VGA.playSlotDark, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy DOS Components (kept for backward compat during transition)

struct DOSPanel<Content: View>: View {
    let style: DOSPanelBorder.PanelStyle
    let backgroundColor: Color
    @ViewBuilder let content: Content

    init(
        _ style: DOSPanelBorder.PanelStyle = .raised,
        backgroundColor: Color = VGA.panelBg,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        content
            .background(backgroundColor)
            .modifier(DOSPanelBorder(style))
    }
}

struct DOSWindowFrame<Content: View>: View {
    let title: String
    let titleColor: Color
    let titleBarColor: Color
    @ViewBuilder let content: Content

    init(
        _ title: String,
        titleColor: Color = .white,
        titleBarColor: Color = VGA.titleBarBg,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleColor = titleColor
        self.titleBarColor = titleBarColor
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(RetroFont.bodyBold())
                    .foregroundColor(titleColor)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(titleBarColor)

            content
                .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised))
    }
}

struct DOSButton: View {
    let title: String
    let color: Color
    let textColor: Color
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, color: Color = VGA.buttonBg, textColor: Color = .white, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.textColor = textColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RetroFont.bodyBold())
                .foregroundColor(textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color)
                .modifier(DOSPanelBorder(isPressed ? .sunken : .raised, width: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct DOSSeparator: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(VGA.shadowInner).frame(height: 1)
            Rectangle().fill(VGA.highlightOuter).frame(height: 1)
        }
    }
}

struct DOSTerminal<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(VGA.black)
            .modifier(DOSPanelBorder(.sunken))
    }
}

// MARK: - View Extensions

extension View {
    func dosPanel(_ style: DOSPanelBorder.PanelStyle = .raised) -> some View {
        self.modifier(DOSPanelBorder(style))
    }

    func dosPanelBackground(_ style: DOSPanelBorder.PanelStyle = .raised, color: Color = VGA.panelBg) -> some View {
        self.background(color).modifier(DOSPanelBorder(style))
    }
}
