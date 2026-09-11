import Foundation

// MARK: - Spending data (illustrative: August 2026 vs July 2026, AED)

struct Merchant: Identifiable {
    let id = UUID()
    let name: String
    let amount: Int
    let detail: String
}

struct Payment {
    let merchant: String
    let amount: Int
    let date: String
}

enum Direction {
    case up, down, flat

    init(percent: Int) {
        if percent < -1 { self = .down } else if percent > 1 { self = .up } else { self = .flat }
    }

    var arrow: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .flat: return "→"
        }
    }
}

struct SpendCategory: Identifiable {
    let id: String
    let name: String
    let now: Int
    let prev: Int
    let count: Int
    let spare: Double
    let merchants: [Merchant]
    let largest: Payment
    let pattern: String
    let lead: String
    let colorIndex: Int

    var deltaPercent: Int { percentChange(now, prev) }
    var direction: Direction { Direction(percent: deltaPercent) }
}

func percentChange(_ now: Int, _ prev: Int) -> Int {
    Int((Double(now - prev) / Double(prev) * 100).rounded())
}

enum SpendData {
    static let categories: [SpendCategory] = [
        SpendCategory(
            id: "dining", name: "Dining", now: 1940, prev: 2720, count: 14, spare: 9.40,
            merchants: [
                Merchant(name: "Talabat", amount: 640, detail: "9 orders"),
                Merchant(name: "Zuma", amount: 385, detail: "1 visit"),
                Merchant(name: "Arabian Tea House", amount: 210, detail: "3 visits"),
                Merchant(name: "Other", amount: 705, detail: "")
            ],
            largest: Payment(merchant: "Zuma", amount: 385, date: "Fri 21 Aug"),
            pattern: "Most of it landed Thursday to Saturday evenings. You ordered in 9 times, down from 15 in July.",
            lead: "Fewer takeaway orders did most of the work.",
            colorIndex: 0
        ),
        SpendCategory(
            id: "transfers", name: "Transfers", now: 1800, prev: 2600, count: 3, spare: 0,
            merchants: [
                Merchant(name: "Mum", amount: 1200, detail: "monthly"),
                Merchant(name: "Ahmed R.", amount: 400, detail: ""),
                Merchant(name: "Nada K.", amount: 200, detail: "")
            ],
            largest: Payment(merchant: "Mum", amount: 1200, date: "Sun 30 Aug"),
            pattern: "The same standing transfer as every month. July had one extra transfer of AED 800 that did not repeat.",
            lead: "July had one extra transfer that did not repeat.",
            colorIndex: 1
        ),
        SpendCategory(
            id: "groceries", name: "Groceries", now: 1610, prev: 1490, count: 11, spare: 6.20,
            merchants: [
                Merchant(name: "Carrefour", amount: 920, detail: "6 trips"),
                Merchant(name: "Spinneys", amount: 480, detail: "3 trips"),
                Merchant(name: "Kibsons", amount: 210, detail: "2 deliveries")
            ],
            largest: Payment(merchant: "Carrefour", amount: 310, date: "Sat 8 Aug"),
            pattern: "Two big weekend shops made up more than half. The rest were small top-ups midweek.",
            lead: "Two big weekend shops pushed it over July.",
            colorIndex: 2
        ),
        SpendCategory(
            id: "shopping", name: "Shopping", now: 1380, prev: 1050, count: 7, spare: 3.10,
            merchants: [
                Merchant(name: "Noon", amount: 899, detail: "1 order"),
                Merchant(name: "Zara", amount: 260, detail: "2 visits"),
                Merchant(name: "Apple", amount: 221, detail: "1 purchase")
            ],
            largest: Payment(merchant: "Noon", amount: 899, date: "Fri 14 Aug"),
            pattern: "One Noon order is almost two thirds of the category. Without it, shopping would have been below July.",
            lead: "One order explains nearly all of the rise.",
            colorIndex: 3
        ),
        SpendCategory(
            id: "transport", name: "Transport", now: 720, prev: 750, count: 19, spare: 8.90,
            merchants: [
                Merchant(name: "Careem", amount: 410, detail: "13 rides"),
                Merchant(name: "ENOC", amount: 240, detail: "4 fill-ups"),
                Merchant(name: "Salik", amount: 70, detail: "2 top-ups")
            ],
            largest: Payment(merchant: "ENOC", amount: 85, date: "Sun 2 Aug"),
            pattern: "Careem most weekday mornings, usually between 8 and 9am. Fuel was steady.",
            lead: "Mostly Careem, and steady.",
            colorIndex: 4
        ),
        SpendCategory(
            id: "bills", name: "Bills & utilities", now: 510, prev: 505, count: 2, spare: 0,
            merchants: [
                Merchant(name: "DEWA", amount: 340, detail: "electricity & water"),
                Merchant(name: "du", amount: 170, detail: "mobile & home")
            ],
            largest: Payment(merchant: "DEWA", amount: 340, date: "Tue 4 Aug"),
            pattern: "Bills barely moved. DEWA was AED 5 higher, which lines up with the hotter month.",
            lead: "Nothing unusual here.",
            colorIndex: 5
        ),
        SpendCategory(
            id: "entertainment", name: "Entertainment", now: 460, prev: 455, count: 5, spare: 2.30,
            merchants: [
                Merchant(name: "Dubai Opera", amount: 200, detail: "1 ticket"),
                Merchant(name: "VOX Cinemas", amount: 180, detail: "3 visits"),
                Merchant(name: "Netflix", amount: 56, detail: "monthly"),
                Merchant(name: "Spotify", amount: 24, detail: "monthly")
            ],
            largest: Payment(merchant: "Dubai Opera", amount: 200, date: "Thu 27 Aug"),
            pattern: "Same as July almost to the dirham. Subscriptions are the only fixed part.",
            lead: "Nothing unusual here.",
            colorIndex: 6
        )
    ]

    static let total = categories.reduce(0) { $0 + $1.now }            // 8,420
    static let prevTotal = categories.reduce(0) { $0 + $1.prev }        // 9,570
    static let deltaPercent = percentChange(total, prevTotal)           // -12
    static let paymentCount = 118
    static let cardCount = categories.filter { $0.spare > 0 }.reduce(0) { $0 + $1.count }  // 56
    static let spareTotal = categories.reduce(0.0) { $0 + $1.spare }    // 29.90

    static func category(_ id: String) -> SpendCategory {
        categories.first { $0.id == id }!
    }
}

// MARK: - Conversation

enum Role { case user, assistant }

struct TextSegment {
    let text: String
    let bold: Bool

    init(_ text: String, bold: Bool = false) {
        self.text = text
        self.bold = bold
    }

    var wordCount: Int { text.split(separator: " ").count }
}

struct Reasoning {
    var title: String
    var steps: [String]
    var revealed = 0
    var completed = 0
    var finished = false
    var expanded = true
}

enum CardKind {
    case insight
    case drill(String)
    case receipt
    case monthlyConfirm
    case roundUpCTA
    case roundUpConfirm
}

enum FollowAction {
    case overview
    case drill(String)
    case biggest
    case monthly
}

struct FollowUp: Identifiable {
    let id = UUID()
    let label: String
    let action: FollowAction
}

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    var userText = ""
    var segments: [TextSegment] = []
    var visibleWords = 0
    var reasoning: Reasoning?
    var card: CardKind?
    var roundUpCategory: String?
    var showActions = false
    var followUps: [FollowUp] = []
}
