import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x070A0B)
    static let surface = Color(hex: 0x15191B)
    static let surface2 = Color(hex: 0x1C1F21)
    static let bubble = Color(hex: 0x1E2224)
    static let composer = Color(hex: 0x1B1E20)
    static let text = Color(hex: 0xF1F4F2)
    static let text2 = Color(hex: 0xAAB2AE)
    static let text3 = Color(hex: 0x6F7876)
    static let lime = Color(hex: 0xE6F5A3)
    static let green = Color(hex: 0x4CCF8A)
    static let amber = Color(hex: 0xF0B46A)
    static let line = Color.white.opacity(0.07)

    /// Category ramp, brightest first. Assigned by category size.
    static let ramp: [Color] = [
        Color(hex: 0xD8F0A8), Color(hex: 0x9FD98F), Color(hex: 0x63BF85), Color(hex: 0x3AA080),
        Color(hex: 0x2F7F77), Color(hex: 0x345F66), Color(hex: 0x3F4A55)
    ]
}

func aed(_ n: Int) -> String { "AED " + n.formatted(.number) }
func aed(_ n: Double) -> String { "AED " + String(format: "%.2f", n) }

/// Scale + fade on press, close to the feel of the reference app.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension View {
    func cardBackground(radius: CGFloat) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
