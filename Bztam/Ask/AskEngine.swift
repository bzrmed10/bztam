import Foundation

/// What a question asks, in a form code can answer. The model (or the rules) only fill this in;
/// every number in the answer is computed by `AskEngine` from the user's entries.
struct AskQuery: Equatable, Sendable {
    enum Metric: String, CaseIterable, Sendable {
        /// Total spent.
        case spent
        /// Total money in.
        case earned
        /// What's left this period (overall or in one category).
        case left
        /// How many expenses.
        case count
        /// The single biggest expense.
        case biggest
        /// The category where most money went.
        case top
        /// Who owes you and whom you owe (split bills).
        case owed
    }

    enum Range: String, CaseIterable, Sendable {
        case thisPeriod, lastPeriod, thisWeek, lastWeek, today, yesterday, thisYear, all
    }

    var metric: Metric = .spent
    var range: Range = .thisPeriod
    var categoryID: UUID?
    /// Folded shop key (`CategoryMemory.key`), matched against entries.
    var merchant: String?
}

/// A category as plain values for the engine.
struct AskCategory: Sendable, Equatable {
    var id: UUID
    var key: String
    var name: String
    /// Budget for the current period (moves included).
    var budget: Centimes
}

/// Everything the engine needs, without the database.
struct AskContext: Sendable {
    var records: [EntryRecord]
    var categories: [AskCategory]
    var payday: Int
    /// Split balances: friends who owe you, and friends you owe.
    var owedToMe: [AskDebt] = []
    var iOwe: [AskDebt] = []
    var now: Date = .now
    var calendar: Calendar = .current

    /// Shop names as the user typed them, keyed by their folded form, most used first.
    var merchants: [AskMerchant] {
        var names: [String: String] = [:]
        var counts: [String: Int] = [:]
        for r in records where r.kind == .expense {
            let k = CategoryMemory.key(r.merchant)
            guard k.count >= 3 else { continue }
            if names[k] == nil { names[k] = r.merchant.trimmingCharacters(in: .whitespaces) }
            counts[k, default: 0] += 1
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { AskMerchant(key: $0.key, name: names[$0.key] ?? $0.key) }
    }
}

struct AskDebt: Sendable, Equatable {
    var name: String
    var amount: Centimes
}

struct AskMerchant: Sendable, Equatable {
    var key: String
    var name: String
}

struct AskAnswer: Equatable, Sendable {
    /// The main number, shown big. Nil when the answer is not an amount (or nothing was found).
    var amount: Centimes?
    var sentence: String
    /// How the question was understood ("Spent", "Café & Food", "this period").
    var understood: [String]
    /// Entries behind the answer, newest first (biggest first for "biggest"), at most 5.
    var entries: [EntryRecord]
    var isHelp = false
}

/// Turns a question into an `AskQuery` with keyword rules (French, English, Darija in Latin letters).
/// Used alone when Apple Intelligence is off, and first when it is on: the model only fills what the rules missed.
enum AskParser {
    struct Result: Equatable {
        var query = AskQuery()
        var foundMetric = false
        var foundRange = false
        /// The question mentions money or matched something; otherwise Ask shows examples.
        var aboutMoney = false
    }

    private static let metricPhrases: [(AskQuery.Metric, [String])] = [
        (.owed, ["OWES ME", "OWE ME", "WHO OWES", "I OWE", "DO I OWE", "ME DOIT", "ME DOIVENT", "JE DOIS", "DOIS JE", "QUI ME DOIT",
                 "KAYSALNI", "KAYSAL LIYA", "KAYSALO LIYA", "KANSAL", "KANSALO", "SALNI", "SAL LIYA", "KHASSO YRED", "KHASSHOM YRDO"]),
        (.count, ["HOW MANY", "HOW OFTEN", "COMBIEN DE FOIS", "NOMBRE DE", "CH7AL MN MRA", "CHHAL MN MRA", "CHHAL DYAL MRAT", "MRAT"]),
        (.biggest, ["BIGGEST", "LARGEST", "MOST EXPENSIVE", "PLUS GROSSE", "PLUS GROS", "PLUS GRANDE", "PLUS GRAND", "PLUS CHERE",
                    "PLUS CHER", "KBIRA", "KBIR", "AKBAR"]),
        (.top, ["WHERE DID", "WHERE DOES", "WHERE IS MY MONEY", "WHERE MY MONEY", "SPEND THE MOST", "SPENT THE MOST", "SPEND MOST",
                "SPENT MOST", "OU VA", "OU PASSE", "OU PART", "OU EST PASSE", "LE PLUS DEPENSE", "DEPENSE LE PLUS", "FIN MCHAW",
                "FIN MCHAT", "FIN KAYMCHI", "FIN KAYMCHIW", "FIN SREFT", "FIN KHLST"]),
        (.left, ["LEFT", "REMAINING", "REMAIN", "RESTE", "RESTANT", "RESTE T IL", "B9A", "BQA", "BAQI", "BA9I", "B9ALI", "BQALI",
                 "CAN I STILL SPEND", "CAN I SPEND"]),
        (.earned, ["EARN", "EARNED", "RECEIVED", "INCOME", "MONEY IN", "GOT PAID", "GAGNE", "RECU", "RENTRE", "RENTREES", "RENTREE",
                   "REVENU", "REVENUS", "SALARY", "SALAIRE", "DKHEL", "DKHLI", "DKHLO", "DKHAL", "KHLASS", "KHLAS"]),
        (.spent, ["SPEND", "SPENT", "SPENDING", "PAID", "COST", "DEPENSE", "DEPENSES", "DEPENSER", "PAYE", "SREFT", "SRAFT",
                  "KHLST", "KHALLAST", "DFA3T"]),
    ]

    private static let rangePhrases: [(AskQuery.Range, [String])] = [
        (.lastWeek, ["LAST WEEK", "PREVIOUS WEEK", "SEMAINE DERNIERE", "SEMAINE PASSEE", "DERNIERE SEMAINE", "SIMANA LI FATT",
                     "SIMANA LI FAT", "SEMANA LI FAT", "SIMANA LI DAZT", "SIMANA LI DAZET"]),
        (.lastPeriod, ["LAST MONTH", "PREVIOUS MONTH", "LAST PERIOD", "PREVIOUS PERIOD", "MOIS DERNIER", "MOIS PASSE", "DERNIER MOIS",
                       "MOIS PRECEDENT", "PERIODE PRECEDENTE", "CHHAR LI FAT", "CHHER LI FAT", "CHHAR LI DAZ", "CHHER LI DAZ", "CHHAR LI FATT"]),
        (.thisWeek, ["THIS WEEK", "CETTE SEMAINE", "HAD SIMANA", "HAD SEMANA", "WEEK", "SEMAINE", "SIMANA"]),
        (.yesterday, ["YESTERDAY", "HIER", "LBARH", "LBARE7", "LBAREH", "LBARE7"]),
        (.today, ["TODAY", "AUJOURD HUI", "LYOUM", "LYOMA", "LYOM", "LIOUM"]),
        (.thisYear, ["THIS YEAR", "CETTE ANNEE", "HAD L3AM", "HAD L3AME", "THE YEAR", "L ANNEE", "YEAR", "ANNEE"]),
        (.all, ["EVER", "ALL TIME", "IN TOTAL", "SO FAR", "DEPUIS LE DEBUT", "DEPUIS TOUJOURS", "AU TOTAL", "SINCE I STARTED",
                "SINCE THE START", "MN LWLL", "MN LAWEL"]),
        (.thisPeriod, ["THIS MONTH", "THIS PERIOD", "CE MOIS", "CETTE PERIODE", "HAD CHHAR", "HAD CHHER", "MONTH", "MOIS"]),
    ]

    private static let moneyWords = ["HOW MUCH", "COMBIEN", "CH7AL", "CHHAL", "CHHAL", "MONEY", "ARGENT", "FLOUS", "LFLOUS",
                                     "BUDGET", "DH", "DIRHAM", "DIRHAMS", "EXPENSE", "EXPENSES"]

    /// Extra words for the built-in categories, on top of Type it's keywords.
    private static let categoryWords: [String: [String]] = [
        "food": ["FOOD", "EATING", "EAT", "MANGER", "RESTOS", "RESTAURANTS", "CAFES", "MAKLA", "LMAKLA"],
        "courses": ["GROCERY", "GROCERIES", "COURSES", "SUPERMARCHE", "SUPERMARKET", "TQEDA", "TQDYA"],
        "transport": ["TRANSPORT", "TRANSPORTS", "TAXIS", "CAR", "VOITURE", "TOMOBIL"],
        "bills": ["BILLS", "FACTURES", "WATER", "ELECTRICITY", "DOW"],
        "phone": ["PHONE", "TELEPHONE", "MOBILE", "INTERNET", "WIFI"],
        "rent": ["RENT", "LOYER", "HOUSING", "LOGEMENT", "KRA", "LKRA"],
        "goingout": ["GOING OUT", "SORTIES", "LOISIRS", "FUN", "SUBSCRIPTIONS", "ABONNEMENTS", "KHRJAT"],
    ]

    private static let genericNameWords: Set<String> = ["OTHER", "AUTRE", "AUTRES", "AND", "THE", "LES", "DES"]

    static func parse(_ question: String, context: AskContext) -> Result {
        let text = " " + CategoryMemory.key(question) + " "
        var result = Result()
        func has(_ phrase: String) -> Bool { text.contains(" " + phrase + " ") }

        if let metric = metricPhrases.first(where: { $0.1.contains(where: has) })?.0 {
            result.query.metric = metric
            result.foundMetric = true
        }
        if let range = rangePhrases.first(where: { $0.1.contains(where: has) })?.0 {
            result.query.range = range
            result.foundRange = true
        }

        // 1. The user's own category names ("Rent", "Loyer", or a custom one) win.
        var category: UUID?
        for c in context.categories {
            let name = CategoryMemory.key(c.name)
            if name.count >= 3, has(name) { category = c.id; break }
        }
        if category == nil {
            for c in context.categories {
                let words = CategoryMemory.key(c.name).split(separator: " ").map(String.init)
                    .filter { $0.count >= 4 && !genericNameWords.contains($0) }
                if words.contains(where: has) { category = c.id; break }
            }
        }
        // 2. Then a shop the user has paid before ("Marjane", "Netflix").
        var merchant: String?
        if category == nil {
            merchant = context.merchants.map(\.key).filter(has).max { $0.count < $1.count }
        }
        // 3. Then keywords ("taxi" → Transport).
        if category == nil, merchant == nil {
            for c in context.categories {
                let words = (categoryWords[c.key] ?? []) + (QuickEntryParser.categoryKeywords[c.key] ?? [])
                if words.contains(where: has) { category = c.id; break }
            }
        }
        result.query.categoryID = category
        result.query.merchant = merchant

        result.aboutMoney = result.foundMetric || result.foundRange || category != nil || merchant != nil
            || moneyWords.contains(where: has) || question.contains(where: \.isNumber)
        return result
    }
}

/// Answers an `AskQuery` from the entries. Pure, unit-tested; the only place Ask computes numbers.
enum AskEngine {
    static func interval(_ range: AskQuery.Range, context: AskContext) -> BudgetPeriod {
        let cal = context.calendar, now = context.now
        let current = BudgetCalculator.period(containing: now, payday: context.payday, calendar: cal)
        func span(_ c: Calendar.Component, _ date: Date) -> BudgetPeriod {
            let i = cal.dateInterval(of: c, for: date) ?? DateInterval(start: date, duration: 86_400)
            return BudgetPeriod(start: i.start, end: i.end)
        }
        switch range {
        case .thisPeriod: return current
        case .lastPeriod: return BudgetCalculator.period(current, offset: -1, payday: context.payday, calendar: cal)
        case .thisWeek: return span(.weekOfYear, now)
        case .lastWeek: return span(.weekOfYear, cal.date(byAdding: .day, value: -7, to: now) ?? now)
        case .today: return span(.day, now)
        case .yesterday: return span(.day, cal.date(byAdding: .day, value: -1, to: now) ?? now)
        case .thisYear: return span(.year, now)
        case .all: return BudgetPeriod(start: .distantPast, end: .distantFuture)
        }
    }

    static func rangeText(_ range: AskQuery.Range) -> String {
        switch range {
        case .thisPeriod: L10n.t("this period")
        case .lastPeriod: L10n.t("last period")
        case .thisWeek: L10n.t("this week")
        case .lastWeek: L10n.t("last week")
        case .today: L10n.t("today")
        case .yesterday: L10n.t("yesterday")
        case .thisYear: L10n.t("this year")
        case .all: L10n.t("since you started")
        }
    }

    static func metricText(_ metric: AskQuery.Metric) -> String {
        switch metric {
        case .spent: L10n.t("Spent")
        case .earned: L10n.t("Money in")
        case .left: L10n.t("Left")
        case .count: L10n.t("How many")
        case .biggest: L10n.t("Biggest")
        case .top: L10n.t("Top category")
        case .owed: L10n.t("Friends")
        }
    }

    static func help() -> AskAnswer {
        AskAnswer(amount: nil, sentence: L10n.t("I answer questions about your money, like how much you spent on food this month or what's left."),
                  understood: [], entries: [], isHelp: true)
    }

    private static func owed(_ context: AskContext) -> AskAnswer {
        let them = context.owedToMe.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }
        let me = context.iOwe.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }
        guard !them.isEmpty || !me.isEmpty else {
            return AskAnswer(amount: nil, sentence: L10n.t("Nobody owes you anything, and you owe nobody."),
                             understood: [metricText(.owed)], entries: [])
        }
        func list(_ d: [AskDebt]) -> String { ListFormatter.localizedString(byJoining: d.map { "\($0.name) \(Money.format($0.amount))" }) }
        var parts: [String] = []
        if !them.isEmpty { parts.append(L10n.t("Owed to you: %@.", list(them))) }
        if !me.isEmpty { parts.append(L10n.t("You owe: %@.", list(me))) }
        let total = them.reduce(0) { $0 + $1.amount }
        return AskAnswer(amount: them.isEmpty ? nil : total, sentence: parts.joined(separator: " "),
                         understood: [metricText(.owed)], entries: [])
    }

    static func answer(_ q: AskQuery, context: AskContext) -> AskAnswer {
        // "Left" is always about the current period.
        let range: AskQuery.Range = q.metric == .left ? .thisPeriod : q.range
        let period = interval(range, context: context)
        let when = rangeText(range)
        let category = context.categories.first { $0.id == q.categoryID }
        let merchantName = q.merchant.map { key in context.merchants.first { $0.key == key }?.name ?? key.capitalized }
        func categoryName(_ id: UUID?) -> String {
            context.categories.first { $0.id == id }?.name ?? L10n.t("Other")
        }

        let inRange = context.records.filter { period.contains($0.date) }
        let expenses = inRange.filter { r in
            r.kind == .expense && r.amount > 0
                && (category == nil || r.categoryID == category?.id)
                && (q.merchant == nil || CategoryMemory.key(r.merchant) == q.merchant)
        }
        let spent = expenses.reduce(0) { $0 + $1.amount }
        let newest = Array(expenses.sorted { $0.date > $1.date }.prefix(5))

        if q.metric == .owed { return owed(context) }

        var understood = [metricText(q.metric)]
        if q.metric != .earned, q.metric != .top {
            if let category { understood.append(category.name) } else if let merchantName { understood.append(merchantName) }
        }
        understood.append(when)

        func nothing() -> AskAnswer {
            let target = q.metric == .earned ? nil : (category?.name ?? merchantName)
            let sentence = target.map { L10n.t("Nothing for %@ %@.", $0, when) } ?? L10n.t("Nothing found %@.", when)
            return AskAnswer(amount: nil, sentence: sentence, understood: understood, entries: [])
        }

        switch q.metric {
        case .owed:
            return owed(context)
        case .spent:
            guard !expenses.isEmpty else { return nothing() }
            let amount = Money.format(spent)
            let sentence: String
            if let category {
                sentence = L10n.t("You spent %@ on %@ %@.", amount, category.name, when)
            } else if let merchantName {
                sentence = L10n.t("You spent %@ at %@ %@.", amount, merchantName, when)
            } else {
                sentence = L10n.t("You spent %@ %@.", amount, when)
            }
            return AskAnswer(amount: spent, sentence: sentence, understood: understood, entries: newest)

        case .earned:
            let incomes = inRange.filter { $0.kind == .income }
            guard !incomes.isEmpty else { return nothing() }
            let total = incomes.reduce(0) { $0 + $1.amount }
            return AskAnswer(amount: total, sentence: L10n.t("You received %@ %@.", Money.format(total), when),
                             understood: understood, entries: Array(incomes.sorted { $0.date > $1.date }.prefix(5)))

        case .left:
            if let category {
                let used = inRange.filter { $0.kind == .expense && $0.categoryID == category.id }.reduce(0) { $0 + $1.amount }
                guard category.budget > 0 else {
                    return AskAnswer(amount: nil, sentence: L10n.t("%@ has no budget. You spent %@ there %@.", category.name, Money.format(used), when),
                                     understood: understood, entries: newest)
                }
                let left = category.budget - used
                let sentence = left >= 0
                    ? L10n.t("%@ left in %@ %@, out of %@.", Money.format(left), category.name, when, Money.format(category.budget))
                    : L10n.t("You're %@ over in %@ %@.", Money.format(-left), category.name, when)
                return AskAnswer(amount: left, sentence: sentence, understood: understood, entries: newest)
            }
            let summary = BudgetCalculator.summary(
                entries: inRange.map { EntryValue(kind: $0.kind, amount: $0.amount, date: $0.date, categoryID: $0.categoryID) },
                categories: [], period: period)
            let sentence = summary.left >= 0
                ? L10n.t("%@ left to spend %@: %@ in, %@ spent.", Money.format(summary.left), when,
                         Money.format(summary.moneyIn), Money.format(summary.spent))
                : L10n.t("You spent %@ more than came in %@.", Money.format(-summary.left), when)
            return AskAnswer(amount: summary.left, sentence: sentence, understood: understood, entries: [])

        case .count:
            guard !expenses.isEmpty else { return nothing() }
            let n = expenses.count, total = Money.format(spent)
            let sentence: String
            if let merchantName {
                sentence = n == 1 ? L10n.t("Once at %@ %@, %@.", merchantName, when, total)
                                  : L10n.t("%d times at %@ %@, %@ in total.", n, merchantName, when, total)
            } else if let category {
                sentence = n == 1 ? L10n.t("1 expense in %@ %@, %@.", category.name, when, total)
                                  : L10n.t("%d expenses in %@ %@, %@ in total.", n, category.name, when, total)
            } else {
                sentence = n == 1 ? L10n.t("1 expense %@, %@.", when, total)
                                  : L10n.t("%d expenses %@, %@ in total.", n, when, total)
            }
            return AskAnswer(amount: nil, sentence: sentence, understood: understood, entries: newest)

        case .biggest:
            guard let top = expenses.max(by: { $0.amount != $1.amount ? $0.amount < $1.amount : $0.date < $1.date }) else { return nothing() }
            let what = top.merchant.trimmingCharacters(in: .whitespaces).isEmpty ? categoryName(top.categoryID) : top.merchant
            let amount = Money.format(top.amount), day = DateText.short(top.date)
            let sentence: String
            if let category {
                sentence = L10n.t("Your biggest expense in %@ %@: %@, %@ on %@.", category.name, when, what, amount, day)
            } else if let merchantName {
                sentence = L10n.t("Your biggest expense at %@ %@: %@ on %@.", merchantName, when, amount, day)
            } else {
                sentence = L10n.t("Your biggest expense %@: %@, %@ on %@.", when, what, amount, day)
            }
            let biggest = Array(expenses.sorted { $0.amount > $1.amount }.prefix(5))
            return AskAnswer(amount: top.amount, sentence: sentence, understood: understood, entries: biggest)

        case .top:
            let all = inRange.filter { $0.kind == .expense }
            let byCategory = Dictionary(grouping: all, by: \.categoryID).mapValues { $0.reduce(0) { $0 + $1.amount } }
            guard let best = byCategory.max(by: { $0.value != $1.value ? $0.value < $1.value : categoryName($0.key) > categoryName($1.key) })
            else { return nothing() }
            let total = all.reduce(0) { $0 + $1.amount }
            let share = total > 0 ? Int((Double(best.value) / Double(total) * 100).rounded()) : 0
            let sentence = L10n.t("Most went to %@ %@: %@, %d%% of what you spent.", categoryName(best.key), when, Money.format(best.value), share)
            let behind = Array(all.filter { $0.categoryID == best.key }.sorted { $0.amount > $1.amount }.prefix(5))
            return AskAnswer(amount: best.value, sentence: sentence, understood: understood, entries: behind)
        }
    }
}
