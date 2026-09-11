import SwiftUI
import UIKit
import Observation

/// Drives the scripted conversation for one variation. Everything here runs
/// on the main actor because the views observe it directly.
@MainActor
@Observable
final class ChatModel {
    let variant: Variant

    var messages: [Message] = []
    var input = ""
    var inChat = false
    var thinking = false
    var busy = false
    /// Bumped on every content change so the thread can scroll to the bottom.
    var revision = 0

    private var roundUpDismissed = false
    private var roundUpShown = false
    private var roundUpOn = false

    init(variant: Variant) {
        self.variant = variant
    }

    // MARK: - User intents

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        input = ""
        route(text)
    }

    /// Sends a suggested prompt straight away, as if the user typed and hit send.
    func ask(_ text: String) {
        guard !busy else { return }
        input = ""
        route(text)
    }

    func reset() {
        withAnimation(.easeOut(duration: 0.3)) {
            messages.removeAll()
            inChat = false
            thinking = false
        }
        busy = false
        roundUpShown = false
    }

    func route(_ text: String) {
        let lower = text.lowercased()
        let asksAboutSpending = ["spend", "spent", "last month", "august"].contains { lower.contains($0) }
        Task {
            if asksAboutSpending || messages.isEmpty {
                await overview(text)
            } else {
                await fallback(text)
            }
        }
    }

    func perform(_ followUp: FollowUp) {
        guard !busy else { return }
        Task {
            switch followUp.action {
            case .overview:
                await overview(followUp.label)
            case .drill(let id):
                await drill(SpendData.category(id), question: followUp.label)
            case .whyLower:
                await whyLower()
            case .monthDetail:
                await monthDetail()
            case .merchant(let name):
                await merchantDetail(SpendData.merchant(name), question: followUp.label)
            case .biggest:
                await biggest()
            case .monthly:
                await monthly()
            }
        }
    }

    func tapCategory(_ category: SpendCategory) {
        guard !busy else { return }
        Task { await drill(category, question: "Show me \(category.name.lowercased())") }
    }

    func tapMerchant(_ merchant: MerchantTotal) {
        guard !busy else { return }
        Task { await merchantDetail(merchant, question: "Show me \(merchant.name)") }
    }

    func toggleReasoning(_ id: UUID) {
        // Mutates in place without bumping `revision`, so the thread does not scroll.
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy(duration: 0.35)) {
            messages[index].reasoning?.expanded.toggle()
        }
    }

    func dismissRoundUp(_ id: UUID) {
        roundUpDismissed = true
        withAnimation(.easeOut(duration: 0.3)) {
            update(id) { $0.roundUp = nil }
        }
    }

    func explainRoundUp() {
        guard !busy else { return }
        Task { await roundUpExplain() }
    }

    func turnOnRoundUp(_ id: UUID) {
        roundUpOn = true
        haptic(.medium)
        withAnimation(.snappy(duration: 0.4)) {
            update(id) { $0.card = .roundUpConfirm }
        }
    }

    // MARK: - Helpers

    private func update(_ id: UUID, _ change: (inout Message) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
        revision += 1
    }

    private func pause(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Posts the user's bubble, then an empty assistant turn. Returns the assistant turn's id.
    private func begin(_ userText: String) async -> UUID {
        busy = true
        haptic(.light)
        if !inChat {
            withAnimation(.easeOut(duration: 0.35)) { inChat = true }
            await pause(300)
        }
        withAnimation(.spring(duration: 0.45)) {
            messages.append(Message(role: .user, userText: userText))
        }
        revision += 1
        await pause(350)
        let reply = Message(role: .assistant)
        withAnimation(.spring(duration: 0.45)) { messages.append(reply) }
        revision += 1
        return reply.id
    }

    private func reason(_ id: UUID, title: String, steps: [String]) async {
        thinking = true
        withAnimation(.spring(duration: 0.4)) {
            update(id) { $0.reasoning = Reasoning(title: title, steps: steps) }
        }
        for i in 0..<steps.count {
            withAnimation(.spring(duration: 0.35)) {
                update(id) { $0.reasoning?.revealed = i + 1 }
            }
            await pause(Int.random(in: 650...1000))
            withAnimation(.spring(duration: 0.35)) {
                update(id) { $0.reasoning?.completed = i + 1 }
            }
        }
        await pause(350)
        withAnimation(.snappy(duration: 0.4)) {
            update(id) {
                $0.reasoning?.finished = true
                $0.reasoning?.expanded = false
            }
        }
        thinking = false
        haptic(.light)
        await pause(250)
    }

    private func stream(_ id: UUID, _ segments: [TextSegment]) async {
        let total = segments.reduce(0) { $0 + $1.wordCount }
        update(id) { $0.segments = segments }
        var shown = 0
        while shown < total {
            shown = min(total, shown + 2)
            update(id) { $0.visibleWords = shown }
            await pause(70)
        }
    }

    private func finish(_ id: UUID, _ followUps: [FollowUp]) async {
        await pause(350)
        withAnimation(.spring(duration: 0.4)) {
            update(id) { $0.showActions = true }
        }
        // Let the answer land before offering next steps, then trickle them in.
        await pause(900)
        for followUp in followUps {
            withAnimation(.spring(duration: 0.4)) {
                update(id) { $0.followUps.append(followUp) }
            }
            await pause(420)
        }
        busy = false
    }

    private func showCard(_ id: UUID, _ card: CardKind) async {
        await pause(200)
        withAnimation(.spring(duration: 0.5)) {
            update(id) { $0.card = card }
        }
    }

    private var biggestFollowUp: FollowUp { FollowUp(label: "My biggest purchase", action: .biggest) }
    private var monthlyFollowUp: FollowUp { FollowUp(label: "Send this every month", action: .monthly) }

    // MARK: - Overview per variation

    private func overview(_ text: String) async {
        switch variant {
        case .categories: await overviewCategories(text)
        case .trend: await overviewTrend(text)
        case .merchants: await overviewMerchants(text)
        case .combined: await overviewCombined(text)
        }
    }

    /// Variation 4: the three widgets in one swipeable rail.
    private func overviewCombined(_ text: String) async {
        let id = await begin(text)
        await reason(id, title: "Looking into your spending", steps: [
            "Reading transactions since March",
            "Grouping \(SpendData.paymentCount) August payments by category and merchant",
            "Comparing August with July and your usual month"
        ])
        let usual = SpendData.averageOfPreviousMonths
        let gap = usual - SpendData.total
        await stream(id, [
            TextSegment("You spent "),
            TextSegment(aed(SpendData.total), bold: true),
            TextSegment(" in August, "),
            TextSegment("\(abs(SpendData.deltaPercent))% less than July", bold: true),
            TextSegment(" and \(aed(gap)) under your usual month. Dining and transfers dropped the most, and Careem was your biggest merchant once rides, groceries and food are added up. Swipe for each view.")
        ])
        await showCard(id, .rail)
        // Cross-sell: the whole month's spare change, right after the recap.
        if !roundUpDismissed && !roundUpOn {
            await pause(700)
            roundUpShown = true
            withAnimation(.spring(duration: 0.5)) {
                update(id) { $0.roundUp = .month }
            }
        }
        await finish(id, [
            FollowUp(label: "Why did shopping go up?", action: .drill("shopping")),
            FollowUp(label: "Why was August lower?", action: .whyLower),
            FollowUp(label: "Show me Careem", action: .merchant("Careem")),
            biggestFollowUp,
            monthlyFollowUp
        ])
    }

    /// Variation 1: August against July, by category.
    private func overviewCategories(_ text: String) async {
        let id = await begin(text)
        await reason(id, title: "Looking into your spending", steps: [
            "Reading your August transactions",
            "Grouping \(SpendData.paymentCount) payments into categories",
            "Comparing against July",
            "Looking for what changed"
        ])
        await stream(id, [
            TextSegment("You spent "),
            TextSegment(aed(SpendData.total), bold: true),
            TextSegment(" in August, about "),
            TextSegment("\(abs(SpendData.deltaPercent))% less", bold: true),
            TextSegment(" than July. Dining and transfers dropped the most. Shopping went up by almost a third, mostly down to one Ounass order.")
        ])
        await showCard(id, .insight)
        await finish(id, [
            FollowUp(label: "Why did shopping go up?", action: .drill("shopping")),
            biggestFollowUp,
            monthlyFollowUp
        ])
    }

    /// Variation 2: August against the previous five months.
    private func overviewTrend(_ text: String) async {
        let id = await begin(text)
        await reason(id, title: "Looking at your last six months", steps: [
            "Reading transactions since March",
            "Totalling each month",
            "Comparing August with your usual month"
        ])
        let usual = SpendData.averageOfPreviousMonths
        let gap = usual - SpendData.total
        let percent = Int((Double(gap) / Double(usual) * 100).rounded())
        await stream(id, [
            TextSegment("You spent "),
            TextSegment(aed(SpendData.total), bold: true),
            TextSegment(" in August, your "),
            TextSegment("lowest month since March", bold: true),
            TextSegment(". That is \(aed(gap)) (\(percent)%) under your usual month of about \(aed(usual)). May was the high point, mostly the Eid trip.")
        ])
        await showCard(id, .trend)
        await finish(id, [
            FollowUp(label: "Why was August lower?", action: .whyLower),
            FollowUp(label: "What happened in May?", action: .monthDetail),
            biggestFollowUp,
            monthlyFollowUp
        ])
    }

    /// Variation 3: merchants ranked across categories.
    private func overviewMerchants(_ text: String) async {
        let id = await begin(text)
        await reason(id, title: "Looking at where your money went", steps: [
            "Reading your August transactions",
            "Grouping \(SpendData.paymentCount) payments by merchant",
            "Tagging each merchant's categories",
            "Ranking by total"
        ])
        let top = SpendData.merchants
        await stream(id, [
            TextSegment("Your spending went to "),
            TextSegment("\(top.count) merchants", bold: true),
            TextSegment(" in August, not counting transfers. "),
            TextSegment("\(top[0].name) took the most at \(aed(top[0].total))", bold: true),
            TextSegment(", spread across rides, groceries and food orders. \(top[1].name) and \(top[2].name) were close behind, then \(top[3].name).")
        ])
        await showCard(id, .merchants)
        await finish(id, [
            FollowUp(label: "Show me \(top[0].name)", action: .merchant(top[0].name)),
            FollowUp(label: "Show me \(top[1].name)", action: .merchant(top[1].name)),
            biggestFollowUp,
            monthlyFollowUp
        ])
    }

    // MARK: - Drill-downs

    private func drill(_ c: SpendCategory, question: String) async {
        let id = await begin(question)
        let lower = c.name.lowercased()
        await reason(id, title: "Looking at \(lower)", steps: [
            "Filtering \(c.count) \(lower) payments",
            "Ranking merchants",
            "Comparing with July"
        ])
        let direction: String
        switch c.direction {
        case .down: direction = "down \(abs(c.deltaPercent))% from July"
        case .up: direction = "up \(c.deltaPercent)% on July"
        case .flat: direction = "about the same as July"
        }
        await stream(id, [
            TextSegment("\(c.name) came to "),
            TextSegment(aed(c.now), bold: true),
            TextSegment(", \(direction). \(c.lead)")
        ])
        await showCard(id, .drill(c.id))
        if c.spare > 0 && !roundUpDismissed && !roundUpShown && !roundUpOn {
            await pause(450)
            roundUpShown = true
            withAnimation(.spring(duration: 0.5)) {
                update(id) { $0.roundUp = .category(c.id) }
            }
        }
        let others = SpendData.categories.filter { $0.id != c.id }.prefix(2)
        var followUps = others.map { FollowUp(label: "Show me \($0.name.lowercased())", action: .drill($0.id)) }
        followUps.append(biggestFollowUp)
        await finish(id, followUps)
    }

    private func whyLower() async {
        let id = await begin("Why was August lower?")
        await reason(id, title: "Comparing August with your usual month", steps: [
            "Averaging each category over five months",
            "Finding the biggest gaps"
        ])
        let dining = SpendData.category("dining")
        let transfers = SpendData.category("transfers")
        let fun = SpendData.category("entertainment")
        await stream(id, [
            TextSegment("Three things. "),
            TextSegment("Dining was \(aed(abs(dining.vsAverage))) under", bold: true),
            TextSegment(" your usual month, with fewer takeaway orders. Transfers were \(aed(abs(transfers.vsAverage))) lower because July's extra transfer did not repeat. And you went out less: entertainment was \(aed(abs(fun.vsAverage))) under.")
        ])
        await showCard(id, .deltaList)
        await finish(id, [
            FollowUp(label: "Show me dining", action: .drill("dining")),
            FollowUp(label: "What happened in May?", action: .monthDetail),
            biggestFollowUp
        ])
    }

    private func monthDetail() async {
        let id = await begin("What happened in May?")
        await reason(id, title: "Looking at May", steps: [
            "Reading May transactions",
            "Finding what stood out"
        ])
        let may = SpendData.highestMonth
        let over = may.total - SpendData.averageOfPreviousMonths
        await stream(id, [
            TextSegment("May came to "),
            TextSegment(aed(may.total), bold: true),
            TextSegment(", about \(aed(over)) over your usual month. Eid al-Adha fell at the end of May and most of the extra was the trip: flights and a hotel in Istanbul, gifts for the family, and a lot more dinners out.")
        ])
        await showCard(id, .monthDetail)
        await finish(id, [
            FollowUp(label: "Why was August lower?", action: .whyLower),
            biggestFollowUp,
            monthlyFollowUp
        ])
    }

    private func merchantDetail(_ m: MerchantTotal, question: String) async {
        let id = await begin(question)
        await reason(id, title: "Looking at \(m.name)", steps: [
            "Pulling \(m.count) \(m.name) payment\(m.count == 1 ? "" : "s")",
            "Splitting by category",
            "Comparing with July"
        ])
        let direction: String
        if m.isNew {
            direction = "new this month"
        } else {
            switch Direction(percent: m.deltaPercent) {
            case .down: direction = "down \(abs(m.deltaPercent))% from July"
            case .up: direction = "up \(m.deltaPercent)% on July"
            case .flat: direction = "about the same as July"
            }
        }
        let share = Int((m.share * 100).rounded())
        let note = SpendData.merchantNotes[m.name] ?? ""
        await stream(id, [
            TextSegment("\(m.name) came to "),
            TextSegment(aed(m.total), bold: true),
            TextSegment(" across \(m.count) payment\(m.count == 1 ? "" : "s"), \(direction). That is \(share)% of your August spending. \(note)")
        ])
        await showCard(id, .merchant(m.name))
        let others = SpendData.merchants.filter { $0.name != m.name }.prefix(2)
        var followUps = others.map { FollowUp(label: "Show me \($0.name)", action: .merchant($0.name)) }
        followUps.append(biggestFollowUp)
        await finish(id, followUps)
    }

    // MARK: - Shared follow-ups

    private func biggest() async {
        let id = await begin("What was my biggest purchase?")
        await reason(id, title: "Finding your largest payments", steps: [
            "Scanning \(SpendData.paymentCount) August payments",
            "Setting aside transfers and bills",
            "Ranking by amount"
        ])
        let top = SpendData.topPurchases
        let share = Int((Double(top[0].amount) / Double(SpendData.total) * 100).rounded())
        let multiple = Int(Double(top[0].amount) / Double(top[1].amount))
        await stream(id, [
            TextSegment("Your largest single purchase was "),
            TextSegment("\(aed(top[0].amount)) at \(top[0].merchant)", bold: true),
            TextSegment(" on \(top[0].longDate). That is about "),
            TextSegment("\(share)% of everything", bold: true),
            TextSegment(" you spent in August and more than \(multiple)× the next largest, \(aed(top[1].amount)) at \(top[1].merchant). Your other \(SpendData.otherPaymentCount) payments averaged \(aed(SpendData.otherPaymentAverage)).")
        ])
        await showCard(id, .topPurchases)
        let contextual: FollowUp
        switch variant {
        case .categories: contextual = FollowUp(label: "Show me shopping", action: .drill("shopping"))
        case .trend: contextual = FollowUp(label: "Why was August lower?", action: .whyLower)
        case .merchants: contextual = FollowUp(label: "Show me \(top[0].merchant)", action: .merchant(top[0].merchant))
        case .combined: contextual = FollowUp(label: "Show me shopping", action: .drill("shopping"))
        }
        await finish(id, [contextual, monthlyFollowUp])
    }

    private func monthly() async {
        let id = await begin("Send this every month")
        await reason(id, title: "Setting up your recap", steps: ["Saving a monthly reminder"])
        await stream(id, [
            TextSegment("Done. You'll get a "),
            TextSegment("push notification on the 1st of every month", bold: true),
            TextSegment(" at 9am with your recap. The next one covers September and arrives on Thursday 1 October.")
        ])
        await showCard(id, .monthlyConfirm)
        await finish(id, [
            biggestFollowUp,
            FollowUp(label: "Back to my spending", action: .overview)
        ])
    }

    private func roundUpExplain() async {
        let id = await begin("How does Round-Up work?")
        await reason(id, title: "Checking Round-Up", steps: ["Estimating from your August card payments"])
        let perMonth = aed(Int(SpendData.spareTotal.rounded()))
        await stream(id, [
            TextSegment("Every card payment is rounded up to the next dirham and the difference moves into a separate "),
            TextSegment("Round-Up pot", bold: true),
            TextSegment(". It is Shariah-compliant, there is no fee, and you can move the money back whenever you like. Based on August that is roughly "),
            TextSegment("\(perMonth) a month", bold: true),
            TextSegment(" across \(SpendData.cardCount) payments, without changing anything you do.")
        ])
        await showCard(id, .roundUpCTA)
        await finish(id, [
            FollowUp(label: "Back to my spending", action: .overview),
            monthlyFollowUp
        ])
    }

    private func fallback(_ text: String) async {
        let id = await begin(text)
        await reason(id, title: "Thinking", steps: ["Understanding your question"])
        await stream(id, [
            TextSegment("This prototype only covers the monthly spending recap, so I cannot answer that one yet. Try asking about last month's spending, or pick one of the suggestions below.")
        ])
        await finish(id, [
            FollowUp(label: "How was my spending last month?", action: .overview),
            biggestFollowUp
        ])
    }
}
