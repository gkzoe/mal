import Foundation

// MARK: - Spending data (illustrative: March to August 2026, AED)

/// One merchant's spend inside one category. Careem appears three times
/// (rides, Quik groceries, food) so the merchant view can group them.
struct MerchantLine: Identifiable {
    let id = UUID()
    let merchant: String      // brand used for grouping, e.g. "Careem"
    let label: String         // what a category list shows, e.g. "Careem Quik"
    let categoryID: String
    let amount: Int
    let prev: Int             // July
    let count: Int
    let detail: String
    var isOther = false       // "Other dining" is not a merchant
}

struct Payment {
    let merchant: String
    let amount: Int
    let date: String
}

struct Purchase: Identifiable {
    var id: String { merchant + date }
    let merchant: String
    let amount: Int
    let date: String
    let longDate: String
    let categoryID: String
}

struct MonthTotal: Identifiable {
    var id: String { label }
    let label: String
    let total: Int
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

func percentChange(_ now: Int, _ prev: Int) -> Int {
    guard prev != 0 else { return 100 }
    return Int((Double(now - prev) / Double(prev) * 100).rounded())
}

struct SpendCategory: Identifiable {
    let id: String
    let name: String
    let prev: Int            // July
    let avg: Int             // average of March to July
    let spare: Double        // round-up spare change in August
    let largest: Payment
    let pattern: String
    let lead: String
    let colorIndex: Int

    var lines: [MerchantLine] {
        SpendData.lines.filter { $0.categoryID == id }.sorted { $0.amount > $1.amount }
    }
    var now: Int { lines.reduce(0) { $0 + $1.amount } }
    var count: Int { lines.reduce(0) { $0 + $1.count } }
    var deltaPercent: Int { percentChange(now, prev) }
    var direction: Direction { Direction(percent: deltaPercent) }
    var vsAverage: Int { now - avg }
}

struct MerchantTotal: Identifiable {
    var id: String { name }
    let name: String
    let total: Int
    let prev: Int
    let count: Int
    let categoryIDs: [String]      // ordered by amount within the merchant
    let lines: [MerchantLine]

    var share: Double { Double(total) / Double(SpendData.total) }
    var deltaPercent: Int { percentChange(total, prev) }
    var isNew: Bool { prev == 0 }
}

enum SpendData {
    static let lines: [MerchantLine] = [
        // Dining
        MerchantLine(merchant: "Talabat", label: "Talabat", categoryID: "dining", amount: 640, prev: 1010, count: 9, detail: "9 orders"),
        MerchantLine(merchant: "Zuma", label: "Zuma", categoryID: "dining", amount: 385, prev: 0, count: 1, detail: "1 visit"),
        MerchantLine(merchant: "Careem", label: "Careem Food", categoryID: "dining", amount: 220, prev: 380, count: 3, detail: "3 orders"),
        MerchantLine(merchant: "Arabian Tea House", label: "Arabian Tea House", categoryID: "dining", amount: 210, prev: 190, count: 3, detail: "3 visits"),
        MerchantLine(merchant: "Other", label: "Other", categoryID: "dining", amount: 485, prev: 1140, count: 12, detail: "12 payments", isOther: true),
        // Transfers
        MerchantLine(merchant: "Mum", label: "Mum", categoryID: "transfers", amount: 1200, prev: 1200, count: 1, detail: "monthly"),
        MerchantLine(merchant: "Ahmed R.", label: "Ahmed R.", categoryID: "transfers", amount: 400, prev: 600, count: 1, detail: ""),
        MerchantLine(merchant: "Nada K.", label: "Nada K.", categoryID: "transfers", amount: 200, prev: 800, count: 1, detail: ""),
        // Groceries
        MerchantLine(merchant: "Carrefour", label: "Carrefour", categoryID: "groceries", amount: 780, prev: 760, count: 6, detail: "6 trips"),
        MerchantLine(merchant: "Spinneys", label: "Spinneys", categoryID: "groceries", amount: 330, prev: 410, count: 3, detail: "3 trips"),
        MerchantLine(merchant: "Careem", label: "Careem Quik", categoryID: "groceries", amount: 290, prev: 120, count: 4, detail: "4 orders"),
        MerchantLine(merchant: "Kibsons", label: "Kibsons", categoryID: "groceries", amount: 210, prev: 200, count: 2, detail: "2 deliveries"),
        // Shopping
        MerchantLine(merchant: "Ounass", label: "Ounass", categoryID: "shopping", amount: 899, prev: 0, count: 1, detail: "1 order"),
        MerchantLine(merchant: "Zara", label: "Zara", categoryID: "shopping", amount: 260, prev: 520, count: 2, detail: "2 visits"),
        MerchantLine(merchant: "Apple", label: "Apple", categoryID: "shopping", amount: 221, prev: 530, count: 1, detail: "1 purchase"),
        // Transport
        MerchantLine(merchant: "Careem", label: "Careem Rides", categoryID: "transport", amount: 410, prev: 430, count: 13, detail: "13 rides"),
        MerchantLine(merchant: "ENOC", label: "ENOC", categoryID: "transport", amount: 240, prev: 250, count: 4, detail: "4 fill-ups"),
        MerchantLine(merchant: "Salik", label: "Salik", categoryID: "transport", amount: 70, prev: 70, count: 2, detail: "2 top-ups"),
        // Bills
        MerchantLine(merchant: "DEWA", label: "DEWA", categoryID: "bills", amount: 340, prev: 335, count: 1, detail: "electricity & water"),
        MerchantLine(merchant: "du", label: "du", categoryID: "bills", amount: 170, prev: 170, count: 1, detail: "mobile & home"),
        // Entertainment
        MerchantLine(merchant: "Dubai Opera", label: "Dubai Opera", categoryID: "entertainment", amount: 200, prev: 120, count: 1, detail: "1 ticket"),
        MerchantLine(merchant: "VOX Cinemas", label: "VOX Cinemas", categoryID: "entertainment", amount: 180, prev: 255, count: 3, detail: "3 visits"),
        MerchantLine(merchant: "Netflix", label: "Netflix", categoryID: "entertainment", amount: 56, prev: 56, count: 1, detail: "monthly"),
        MerchantLine(merchant: "Spotify", label: "Spotify", categoryID: "entertainment", amount: 24, prev: 24, count: 1, detail: "monthly")
    ]

    static let categories: [SpendCategory] = [
        SpendCategory(
            id: "dining", name: "Dining", prev: 2720, avg: 2520, spare: 9.40,
            largest: Payment(merchant: "Zuma", amount: 385, date: "Fri 21 Aug"),
            pattern: "Most of it landed Thursday to Saturday evenings. You ordered in 9 times, down from 15 in July.",
            lead: "Fewer takeaway orders did most of the work.",
            colorIndex: 0
        ),
        SpendCategory(
            id: "transfers", name: "Transfers", prev: 2600, avg: 2120, spare: 0,
            largest: Payment(merchant: "Mum", amount: 1200, date: "Sun 30 Aug"),
            pattern: "The same standing transfer as every month. July had one extra transfer of AED 800 that did not repeat.",
            lead: "July had one extra transfer that did not repeat.",
            colorIndex: 1
        ),
        SpendCategory(
            id: "groceries", name: "Groceries", prev: 1490, avg: 1540, spare: 6.20,
            largest: Payment(merchant: "Carrefour", amount: 310, date: "Sat 8 Aug"),
            pattern: "Two big weekend shops made up almost half. Careem Quik picked up the midweek top-ups.",
            lead: "Two big weekend shops pushed it over July.",
            colorIndex: 2
        ),
        SpendCategory(
            id: "shopping", name: "Shopping", prev: 1050, avg: 1260, spare: 3.10,
            largest: Payment(merchant: "Ounass", amount: 899, date: "Fri 14 Aug"),
            pattern: "One Ounass order is almost two thirds of the category. Without it, shopping would have been below July.",
            lead: "One order explains nearly all of the rise.",
            colorIndex: 3
        ),
        SpendCategory(
            id: "transport", name: "Transport", prev: 750, avg: 780, spare: 8.90,
            largest: Payment(merchant: "ENOC", amount: 85, date: "Sun 2 Aug"),
            pattern: "Careem most weekday mornings, usually between 8 and 9am. Fuel was steady.",
            lead: "Mostly Careem, and steady.",
            colorIndex: 4
        ),
        SpendCategory(
            id: "bills", name: "Bills & utilities", prev: 505, avg: 510, spare: 0,
            largest: Payment(merchant: "DEWA", amount: 340, date: "Tue 4 Aug"),
            pattern: "Bills barely moved. DEWA was AED 5 higher, which lines up with the hotter month.",
            lead: "Nothing unusual here.",
            colorIndex: 5
        ),
        SpendCategory(
            id: "entertainment", name: "Entertainment", prev: 455, avg: 710, spare: 2.30,
            largest: Payment(merchant: "Dubai Opera", amount: 200, date: "Thu 27 Aug"),
            pattern: "Same as July almost to the dirham. Subscriptions are the only fixed part.",
            lead: "Nothing unusual here.",
            colorIndex: 6
        )
    ]

    static let total = categories.reduce(0) { $0 + $1.now }            // 8,420
    static let prevTotal = categories.reduce(0) { $0 + $1.prev }        // 9,570
    static let deltaPercent = percentChange(total, prevTotal)           // -12
    static let paymentCount = categories.reduce(0) { $0 + $1.count }    // 77
    static let cardCount = categories.filter { $0.spare > 0 }.reduce(0) { $0 + $1.count }
    static let spareTotal = categories.reduce(0.0) { $0 + $1.spare }    // 29.90

    static func category(_ id: String) -> SpendCategory {
        categories.first { $0.id == id }!
    }

    // Variation 2: six months of totals.
    static let months: [MonthTotal] = [
        MonthTotal(label: "Mar", total: 9120),
        MonthTotal(label: "Apr", total: 8860),
        MonthTotal(label: "May", total: 10240),
        MonthTotal(label: "Jun", total: 9410),
        MonthTotal(label: "Jul", total: 9570),
        MonthTotal(label: "Aug", total: 8420)
    ]
    static let averageOfPreviousMonths = months.dropLast().reduce(0) { $0 + $1.total } / (months.count - 1)   // 9,440
    static let highestMonth = months.max { $0.total < $1.total }!
    static let mayDrivers: [(String, String, Int)] = [
        ("Emirates", "Flights to Istanbul, 24 May", 1850),
        ("Hotel", "Four nights, Istanbul", 1320),
        ("Eid gifts & transfers", "Family, 25 to 27 May", 900),
        ("Dining out", "12 dinners, up from 7", 2960)
    ]

    // Variation 3: merchants ranked across categories, transfers excluded.
    static let merchants: [MerchantTotal] = {
        let eligible = lines.filter { $0.categoryID != "transfers" && !$0.isOther }
        var order: [String] = []
        var grouped: [String: [MerchantLine]] = [:]
        for line in eligible {
            if grouped[line.merchant] == nil { order.append(line.merchant) }
            grouped[line.merchant, default: []].append(line)
        }
        return order.map { name -> MerchantTotal in
            let group = grouped[name]!.sorted { $0.amount > $1.amount }
            return MerchantTotal(
                name: name,
                total: group.reduce(0) { $0 + $1.amount },
                prev: group.reduce(0) { $0 + $1.prev },
                count: group.reduce(0) { $0 + $1.count },
                categoryIDs: group.map(\.categoryID),
                lines: group
            )
        }
        .sorted { $0.total > $1.total }
    }()

    static func merchant(_ name: String) -> MerchantTotal {
        merchants.first { $0.name == name }!
    }

    static let merchantNotes: [String: String] = [
        "Careem": "Careem shows up in three categories, so it looks smaller in a category view than it really is. Fewer food orders, more Quik grocery orders than July.",
        "Ounass": "One order, one category. It is also your largest single purchase this month.",
        "Carrefour": "Six trips. Two big weekend shops made up almost half of it.",
        "Talabat": "Nine orders, down from 15 in July. Mostly Thursday and Friday evenings."
    ]

    // Shared "biggest purchase" follow-up: top three, transfers and bills excluded.
    static let topPurchases: [Purchase] = [
        Purchase(merchant: "Ounass", amount: 899, date: "Fri 14 Aug", longDate: "Friday 14 August", categoryID: "shopping"),
        Purchase(merchant: "Zuma", amount: 385, date: "Fri 21 Aug", longDate: "Friday 21 August", categoryID: "dining"),
        Purchase(merchant: "Carrefour", amount: 310, date: "Sat 8 Aug", longDate: "Saturday 8 August", categoryID: "groceries")
    ]
    /// Everything that is not one of the top three, so the sentence and the card agree.
    static let otherPaymentCount = paymentCount - topPurchases.count
    static let otherPaymentAverage = (total - topPurchases.reduce(0) { $0 + $1.amount }) / max(1, otherPaymentCount)
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
    case insight            // v1: categories vs July
    case drill(String)      // v1: one category
    case trend              // v2: six-month bars
    case deltaList          // v2: categories vs usual month
    case monthDetail        // v2: what happened in May
    case merchants          // v3: ranked merchants
    case merchant(String)   // v3: one merchant
    case topPurchases       // shared: largest purchases
    case monthlyConfirm
    case roundUpCTA
    case roundUpConfirm
}

enum FollowAction {
    case overview
    case drill(String)
    case whyLower
    case monthDetail
    case merchant(String)
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
