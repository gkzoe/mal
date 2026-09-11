import SwiftUI

/// The three ways the assistant can answer "How was my spending last month?"
enum Variant: String, CaseIterable, Identifiable {
    case categories, trend, merchants, combined

    var id: String { rawValue }

    var number: String {
        switch self {
        case .categories: return "01"
        case .trend: return "02"
        case .merchants: return "03"
        case .combined: return "04"
        }
    }

    var title: String {
        switch self {
        case .categories: return "Categories vs last month"
        case .trend: return "Six-month trend"
        case .merchants: return "Where the money went"
        case .combined: return "All three, side by side"
        }
    }

    var subtitle: String {
        switch self {
        case .categories: return "August against July, category by category. Where did the change come from?"
        case .trend: return "August against the past five months. Is this a high or a low month for me?"
        case .merchants: return "Merchants ranked by spend, tagged with every category each one touches."
        case .combined: return "One answer, three lenses in a swipeable rail: categories, six months, merchants."
        }
    }
}

// MARK: - Picker screen

struct VariationMenu: View {
    let onSelect: (Variant) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow("Mal · case study")
                    .padding(.top, 28)
                Text("Spending recap")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
                Text("Four ways to answer “How was my spending last month?” Pick one to open the chat. The back arrow brings you back here.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text2)
                    .lineSpacing(3)
                    .padding(.bottom, 14)
                ForEach(Variant.allCases) { variant in
                    Button { onSelect(variant) } label: {
                        VariantRow(variant: variant)
                    }
                    .buttonStyle(PressStyle())
                }
                Text("Every variation shares the “My biggest purchase” and “Send this every month” follow-ups. Data is illustrative, AED, August 2026.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text3)
                    .lineSpacing(3)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}

struct VariantRow: View {
    let variant: Variant

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VariantGlyph(variant: variant)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(variant.number)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.lime)
                    Text(variant.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                Text(variant.subtitle)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text3)
                .padding(.top, 4)
        }
        .padding(18)
        .cardBackground(radius: 22)
    }
}

/// Tiny schematic of each card type, drawn with shapes.
struct VariantGlyph: View {
    let variant: Variant

    var body: some View {
        switch variant {
        case .categories:
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 2) {
                    let widths: [CGFloat] = [14, 11, 9, 6]
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2).fill(Theme.ramp[i]).frame(width: widths[i], height: 7)
                    }
                }
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: 4) {
                        Circle().fill(Theme.ramp[i]).frame(width: 4, height: 4)
                        RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.25)).frame(width: 18, height: 3)
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.5)).frame(width: 8, height: 3)
                    }
                }
            }
            .frame(width: 40)
        case .trend:
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(SpendData.months.enumerated()), id: \.offset) { index, month in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(index == SpendData.months.count - 1 ? Theme.lime : Color(hex: 0x2F7F77).opacity(0.8))
                        .frame(width: 4, height: CGFloat(month.total) / 10240 * 30)
                }
            }
        case .combined:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(i == 0 ? 0.35 : 0.14))
                        .frame(width: i == 0 ? 20 : 10, height: 30)
                }
            }
        case .merchants:
            VStack(alignment: .leading, spacing: 5) {
                let widths: [CGFloat] = [30, 26, 17]
                let colors = [4, 3, 0]
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: 4) {
                        Text("\(i + 1)").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.text3)
                        RoundedRectangle(cornerRadius: 2).fill(Theme.ramp[colors[i]]).frame(width: widths[i], height: 6)
                    }
                }
            }
        }
    }
}
