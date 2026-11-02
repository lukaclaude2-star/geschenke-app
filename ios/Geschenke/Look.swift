import SwiftUI

/// Stil C – dunkel & edel: Nachtblau mit Gold-Akzenten (Grundbaustein 12).
enum Look {
    static let hintergrund = Color(hex: 0x11131C)
    static let karte = Color(hex: 0x1C1F2B)
    static let rand = Color(hex: 0x2C3040)
    static let gold = Color(hex: 0xE0B84C)
    static let text = Color(hex: 0xEEEEEE)
    static let leise = Color(hex: 0xEEEEEE).opacity(0.6)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct GoldKnopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Look.hintergrund)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Look.gold.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RandKnopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Look.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Look.karte.opacity(configuration.isPressed ? 0.6 : 1))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Look.gold, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct Abzeichen: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Look.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Look.gold.opacity(0.12))
            .overlay(Capsule().stroke(Look.gold.opacity(0.4), lineWidth: 1))
            .clipShape(Capsule())
    }
}

extension View {
    func nachtblau() -> some View {
        self.foregroundStyle(Look.text)
            .background(Look.hintergrund.ignoresSafeArea())
            .scrollContentBackground(.hidden)
    }
}
