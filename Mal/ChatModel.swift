import SwiftUI
import UIKit
import Observation

/// Drives the scripted conversation. Everything here runs on the main actor
/// because the views observe it directly.
@MainActor
@Observable
final class ChatModel {
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

    func toggleReasoning(_ id: UUID) {
        withAnimation(.snappy(duration: 0.35)) {
            update(id) { $0.reasoning?.expanded.toggle() }
        }
    }

    func dismissRoundUp(_ id: UUID) {
        roundUpDismissed = true
        withAnimation(.easeOut(duration: 0.3)) {
            update(id) { $0.roundUpCategory = nil }
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
            update(id) {
                $0.showActions = true
                $0.followUps = followUps
            }
        }
        busy = false
    }

    private func showCard(_ id: UUID, _ card: CardKind) async {
        await pause(200)
        withAnimation(.spring(duration: 0.5)) {
            update(id) { $0.card = card }
        }
    }

    // MARK: - Flows

    private func overview(_ text: String) async {
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
            TextSegment(" than July. Dining and transfers dropped the most. Shopping went up by almost a third, mostly down to one Noon order.")
        ])
        await showCard(id, .insight)
        await finish(id, [
            FollowUp(label: "Why did shopping go up?", action: .drill("shopping")),
            FollowUp(label: "My biggest purchase", action: .biggest),
            FollowUp(label: "Send this every month", action: .monthly)
        ])
    }

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
                update(id) { $0.roundUpCategory = c.id }
            }
        }
        let others = SpendData.categories.filter { $0.id != c.id }.prefix(2)
        var followUps = others.map { FollowUp(label: "Show me \($0.name.lowercased())", action: .drill($0.id)) }
        followUps.append(FollowUp(label: "My biggest purchase", action: .biggest))
        await finish(id, followUps)
    }

    private func biggest() async {
        let id = await begin("What was my biggest purchase?")
        await reason(id, title: "Finding your largest payment", steps: [
            "Scanning \(SpendData.paymentCount) August payments",
            "Excluding transfers"
        ])
        await stream(id, [
            TextSegment("Your largest single purchase was "),
            TextSegment("AED 899 at Noon", bold: true),
            TextSegment(" on Friday 14 August. It is the main reason shopping was up on July.")
        ])
        await showCard(id, .receipt)
        await finish(id, [
            FollowUp(label: "Show me shopping", action: .drill("shopping")),
            FollowUp(label: "Send this every month", action: .monthly)
        ])
    }

    private func monthly() async {
        let id = await begin("Send this every month")
        await reason(id, title: "Setting up your recap", steps: ["Saving a monthly reminder"])
        await stream(id, [
            TextSegment("Done. I will send your spending recap on the "),
            TextSegment("1st of every month", bold: true),
            TextSegment(" at 9am. Your next one covers September and arrives on Thursday 1 October.")
        ])
        await showCard(id, .monthlyConfirm)
        await finish(id, [
            FollowUp(label: "My biggest purchase", action: .biggest),
            FollowUp(label: "Show me dining", action: .drill("dining"))
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
            FollowUp(label: "Send this every month", action: .monthly)
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
            FollowUp(label: "My biggest purchase", action: .biggest)
        ])
    }
}
