import SwiftUI

// MARK: - Variation 2: six-month trend

struct TrendCard: View {
    @State private var grown = false

    private func short(_ n: Int) -> String { String(format: "%.1fk", Double(n) / 1000) }

    var body: some View {
        let months = SpendData.months
        let maxTotal = months.map(\.total).max() ?? 1
        let usual = SpendData.averageOfPreviousMonths
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("Last 6 months")
                Spacer()
                DeltaPill(now: SpendData.total, prev: usual)
            }
            BigAmount(SpendData.total)
                .padding(.top, 10)
            Text("August · your usual month is about \(aed(usual))")
                .font(.system(size: 15))
                .foregroundStyle(Theme.text2)
                .padding(.top, 8)

            GeometryReader { geo in
                let labelBlock: CGFloat = 44   // value above, month below
                let barArea = geo.size.height - labelBlock
                let scale = barArea / CGFloat(maxTotal)
                let lineY = 22 + barArea - CGFloat(usual) * scale
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: lineY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: lineY))
                    }
                    .stroke(Theme.text2.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(months) { month in
                            let isAugust = month.id == months.last?.id
                            VStack(spacing: 6) {
                                Text(short(month.total))
                                    .font(.system(size: 11.5, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(isAugust ? Theme.lime : Theme.text3)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isAugust ? Theme.lime : Color(hex: 0x2F7F77).opacity(0.7))
                                    .frame(height: max(6, CGFloat(month.total) * scale * (grown ? 1 : 0.02)))
                                Text(month.label)
                                    .font(.system(size: 12, weight: isAugust ? .semibold : .regular))
                                    .foregroundStyle(isAugust ? Theme.text : Theme.text3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: geo.size.height, alignment: .bottom)
                }
            }
            .frame(height: 190)
            .padding(.top, 22)
            .onAppear {
                withAnimation(.spring(duration: 0.9)) { grown = true }
            }
        }
        .padding(20)
        .cardBackground(radius: 26)
    }
}

/// Categories against their five-month average, biggest drop first.
struct DeltaListCard: View {
    let onTap: (SpendCategory) -> Void

    private var rows: [SpendCategory] {
        SpendData.categories.sorted { $0.vsAverage < $1.vsAverage }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("August vs your usual month")
                .padding(.bottom, 6)
            ForEach(rows) { category in
                Divider().overlay(Theme.line)
                Button { onTap(category) } label: {
                    HStack(spacing: 12) {
                        Circle().fill(Theme.ramp[category.colorIndex]).frame(width: 10, height: 10)
                        Text(category.name)
                            .font(.system(size: 17))
                            .foregroundStyle(Color(hex: 0xE6EAE8))
                        Spacer()
                        Text(category.now.formatted(.number))
                            .font(.system(size: 17, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: 0xF4F6F5))
                        Text(signed(category.vsAverage))
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(color(for: category.vsAverage))
                            .frame(width: 58, alignment: .trailing)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .cardBackground(radius: 26)
    }

    private func signed(_ n: Int) -> String {
        if n == 0 { return "same" }
        return (n < 0 ? "−" : "+") + abs(n).formatted(.number)
    }

    private func color(for n: Int) -> Color {
        if n < -20 { return Theme.green }
        if n > 20 { return Theme.amber }
        return Theme.text2
    }
}

struct MonthDetailCard: View {
    var body: some View {
        let may = SpendData.highestMonth
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("May · highest month")
                Spacer()
                DeltaPill(now: may.total, prev: SpendData.averageOfPreviousMonths)
            }
            BigAmount(may.total)
                .padding(.top, 10)
            Text("Eid al-Adha, 26 to 29 May · Istanbul trip")
                .font(.system(size: 15))
                .foregroundStyle(Theme.text2)
                .padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(Array(SpendData.mayDrivers.enumerated()), id: \.offset) { _, driver in
                    Divider().overlay(Theme.line)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(driver.0)
                                .font(.system(size: 16.5, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Text(driver.1)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text2)
                        }
                        Spacer()
                        Text(aed(driver.2))
                            .font(.system(size: 16.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.vertical, 13)
                }
            }
            .padding(.top, 14)
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .cardBackground(radius: 26)
    }
}

// MARK: - Variation 3: merchants

struct CategoryTag: View {
    let categoryID: String

    var body: some View {
        let category = SpendData.category(categoryID)
        HStack(spacing: 5) {
            Circle().fill(Theme.ramp[category.colorIndex]).frame(width: 6, height: 6)
            Text(category.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

struct MerchantsCard: View {
    let onTap: (MerchantTotal) -> Void
    @State private var showAll = false

    private var merchants: [MerchantTotal] { SpendData.merchants }
    private var visible: [MerchantTotal] { showAll ? merchants : Array(merchants.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("August spending")
                Spacer()
                DeltaPill(now: SpendData.total, prev: SpendData.prevTotal)
            }
            BigAmount(SpendData.total)
                .padding(.top, 10)
            Text("\(merchants.count) merchants · \(SpendData.paymentCount) payments · transfers excluded")
                .font(.system(size: 15))
                .foregroundStyle(Theme.text2)
                .padding(.top, 8)
                .padding(.bottom, 14)
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, merchant in
                Divider().overlay(Theme.line)
                Button { onTap(merchant) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text3)
                            .frame(width: 18, alignment: .leading)
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(merchant.name)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                Text(aed(merchant.total))
                                    .font(.system(size: 16.5, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.text)
                            }
                            HStack(spacing: 6) {
                                ForEach(merchant.categoryIDs, id: \.self) { CategoryTag(categoryID: $0) }
                                Spacer(minLength: 0)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
            if !showAll {
                Divider().overlay(Theme.line)
                Button {
                    withAnimation(.spring(duration: 0.4)) { showAll = true }
                } label: {
                    Text("Show all \(merchants.count) merchants")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 8)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .cardBackground(radius: 26)
    }
}

struct MerchantDetailCard: View {
    let merchant: MerchantTotal

    var body: some View {
        let share = Int((merchant.share * 100).rounded())
        let maxLine = merchant.lines.map(\.amount).max() ?? 1
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("\(merchant.name) · August")
                Spacer()
                DeltaPill(now: merchant.total, prev: merchant.prev)
            }
            BigAmount(merchant.total)
                .padding(.top, 10)
            Text("\(merchant.count) payment\(merchant.count == 1 ? "" : "s") · \(share)% of August")
                .font(.system(size: 15))
                .foregroundStyle(Theme.text2)
                .padding(.top, 8)
            VStack(spacing: 14) {
                ForEach(merchant.lines) { line in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(line.label)
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundStyle(Color(hex: 0xE3E7E5))
                            CategoryTag(categoryID: line.categoryID)
                            Spacer()
                            Text(aed(line.amount))
                                .font(.system(size: 15.5))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text2)
                        }
                        MerchantBar(
                            fraction: Double(line.amount) / Double(maxLine),
                            color: Theme.ramp[SpendData.category(line.categoryID).colorIndex]
                        )
                        if !line.detail.isEmpty {
                            Text(line.detail)
                                .font(.system(size: 13.5))
                                .foregroundStyle(Theme.text3)
                        }
                    }
                }
            }
            .padding(.top, 20)
            if let note = SpendData.merchantNotes[merchant.name] {
                Text(note)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Theme.text2)
                    .lineSpacing(3)
                    .padding(.top, 18)
            }
        }
        .padding(20)
        .cardBackground(radius: 26)
    }
}

// MARK: - Shared: largest purchases

struct TopPurchasesCard: View {
    var body: some View {
        let top = SpendData.topPurchases
        let restCount = SpendData.otherPaymentCount
        let restAverage = SpendData.otherPaymentAverage
        let timesAverage = Int((Double(top[0].amount) / Double(max(1, restAverage))).rounded())
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("Largest purchases · August")
                Spacer()
                Text("of \(aed(SpendData.total))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.bottom, 6)
            ForEach(Array(top.enumerated()), id: \.element.id) { index, purchase in
                let share = Double(purchase.amount) / Double(SpendData.total) * 100
                let category = SpendData.category(purchase.categoryID)
                Divider().overlay(Theme.line)
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(index == 0 ? Color(hex: 0x0B1409) : Theme.text3)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(index == 0 ? Theme.lime : Color.white.opacity(0.06)))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(purchase.merchant)
                                .font(.system(size: 17, weight: index == 0 ? .semibold : .medium))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text(aed(purchase.amount))
                                .font(.system(size: 17, weight: index == 0 ? .semibold : .medium))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text)
                        }
                        HStack {
                            Text("\(purchase.date) · \(category.name)")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text2)
                            Spacer()
                            Text(String(format: "%.1f%% of month", share))
                                .font(.system(size: 13.5, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(index == 0 ? Theme.lime : Theme.text2)
                        }
                    }
                }
                .padding(.vertical, 14)
            }
            Divider().overlay(Theme.line)
            Text("The other \(restCount) payments averaged \(aed(restAverage)). \(top[0].merchant) alone was about \(timesAverage)× that, and more than the next two together.")
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text2)
                .lineSpacing(3)
                .padding(.top, 14)
                .padding(.bottom, 6)
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .cardBackground(radius: 26)
    }
}
