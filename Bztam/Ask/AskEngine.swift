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
        /// Saved for a goal (or all goals) and what's left to reach it.
        case goal
        /// The next dart round, and when it's your turn to collect.
        case dart
        /// Recurring bills still due this period.
        case bills
        /// "Can I afford X?": X compared with what's left (facts only).
        case afford
        /// "Will I finish the month?": today's pace compared with what came in.
        case pace
    }

    enum Range: String, CaseIterable, Sendable {
        case thisPeriod, lastPeriod, thisWeek, lastWeek, today, yesterday, thisYear, all
    }

    var metric: Metric = .spent
    var range: Range = .thisPeriod
    /// Categories asked about together ("food and transport"); empty means all.
    var categoryIDs: [UUID] = []
    /// Categories left out ("everything except rent").
    var excluded: [UUID] = []
    /// Folded shop key (`CategoryMemory.key`), matched against entries.
    var merchant: String?
    /// Compare with the period before ("more than last month?").
    var compare = false
    /// A named month (1...12), with its year when said; replaces `range`.
    var month: Int?
    var year: Int?
    /// Days of the month ("between the 1st and the 10th"): of the named month, or of this calendar month.
    var dayFrom: Int?
    var dayTo: Int?
    /// The price in "can I afford…".
    var amount: Centimes?
    var goalID: UUID?
    /// Income source raw value (salary, freelance, family, other) for "earned".
    var incomeSource: String?

    /// The single category, when there is exactly one.
    var categoryID: UUID? {
        get { categoryIDs.count == 1 ? categoryIDs[0] : nil }
        set { categoryIDs = newValue.map { [$0] } ?? [] }
    }
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
    var goals: [AskGoal] = []
    var darts: [AskDart] = []
    var bills: [AskBill] = []
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
    /// The amount reveals money in (privacy mode hides it).
    var sensitive = false
    /// Questions to tap (when the question wasn't understood).
    var suggestions: [String] = []
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
        (.owed, ["من يدين لي", "من مدين لي", "شكون كيسالني", "كم علي", "OWES ME", "OWE ME", "WHO OWES", "I OWE", "DO I OWE", "ME DOIT", "ME DOIVENT", "JE DOIS", "DOIS JE", "QUI ME DOIT",
                 "KAYSALNI", "KAYSAL LIYA", "KAYSALO LIYA", "KANSAL", "KANSALO", "SALNI", "SAL LIYA", "KHASSO YRED", "KHASSHOM YRDO"]),
        (.count, ["HOW MANY", "HOW OFTEN", "COMBIEN DE FOIS", "NOMBRE DE", "CH7AL MN MRA", "CHHAL MN MRA", "CHHAL DYAL MRAT", "MRAT"]),
        (.biggest, ["BIGGEST", "LARGEST", "MOST EXPENSIVE", "PLUS GROSSE", "PLUS GROS", "PLUS GRANDE", "PLUS GRAND", "PLUS CHERE",
                    "PLUS CHER", "KBIRA", "KBIR", "AKBAR"]),
        (.top, ["WHERE DID", "WHERE DOES", "WHERE IS MY MONEY", "WHERE MY MONEY", "SPEND THE MOST", "SPENT THE MOST", "SPEND MOST",
                "SPENT MOST", "OU VA", "OU PASSE", "OU PART", "OU EST PASSE", "LE PLUS DEPENSE", "DEPENSE LE PLUS", "FIN MCHAW",
                "FIN MCHAT", "FIN KAYMCHI", "FIN KAYMCHIW", "FIN SREFT", "FIN KHLST"]),
        (.left, ["تبقى", "باقي", "بقي", "المتبقي", "LEFT", "REMAINING", "REMAIN", "RESTE", "RESTANT", "RESTE T IL", "B9A", "BQA", "BAQI", "BA9I", "B9ALI", "BQALI",
                 "CAN I STILL SPEND", "CAN I SPEND"]),
        (.earned, ["دخل", "الدخل", "راتب", "الراتب", "EARN", "EARNED", "RECEIVED", "INCOME", "MONEY IN", "GOT PAID", "GAGNE", "RECU", "RENTRE", "RENTREES", "RENTREE",
                   "REVENU", "REVENUS", "SALARY", "SALAIRE", "DKHEL", "DKHLI", "DKHLO", "DKHAL", "KHLASS", "KHLAS"]),
        (.spent, ["صرفت", "صرف", "مصروف", "المصاريف", "SPEND", "SPENT", "SPENDING", "PAID", "COST", "DEPENSE", "DEPENSES", "DEPENSER", "PAYE", "SREFT", "SRAFT",
                  "KHLST", "KHALLAST", "DFA3T"]),
    ]

    private static let rangePhrases: [(AskQuery.Range, [String])] = [
        (.lastWeek, ["LAST WEEK", "PREVIOUS WEEK", "SEMAINE DERNIERE", "SEMAINE PASSEE", "DERNIERE SEMAINE", "SIMANA LI FATT",
                     "SIMANA LI FAT", "SEMANA LI FAT", "SIMANA LI DAZT", "SIMANA LI DAZET"]),
        (.lastPeriod, ["الشهر الماضي", "الشهر اللي فات", "LAST MONTH", "PREVIOUS MONTH", "LAST PERIOD", "PREVIOUS PERIOD", "MOIS DERNIER", "MOIS PASSE", "DERNIER MOIS",
                       "MOIS PRECEDENT", "PERIODE PRECEDENTE", "CHHAR LI FAT", "CHHER LI FAT", "CHHAR LI DAZ", "CHHER LI DAZ", "CHHAR LI FATT"]),
        (.thisWeek, ["THIS WEEK", "CETTE SEMAINE", "HAD SIMANA", "HAD SEMANA", "WEEK", "SEMAINE", "SIMANA"]),
        (.yesterday, ["YESTERDAY", "HIER", "LBARH", "LBARE7", "LBAREH", "LBARE7"]),
        (.today, ["TODAY", "AUJOURD HUI", "LYOUM", "LYOMA", "LYOM", "LIOUM"]),
        (.thisYear, ["THIS YEAR", "CETTE ANNEE", "HAD L3AM", "HAD L3AME", "THE YEAR", "L ANNEE", "YEAR", "ANNEE"]),
        (.all, ["EVER", "ALL TIME", "IN TOTAL", "SO FAR", "DEPUIS LE DEBUT", "DEPUIS TOUJOURS", "AU TOTAL", "SINCE I STARTED",
                "SINCE THE START", "MN LWLL", "MN LAWEL"]),
        (.thisPeriod, ["هذا الشهر", "هاد الشهر", "THIS MONTH", "THIS PERIOD", "CE MOIS", "CETTE PERIODE", "HAD CHHAR", "HAD CHHER", "MONTH", "MOIS"]),
    ]

    private static let moneyWords = ["كم", "فلوس", "المال", "HOW MUCH", "COMBIEN", "CH7AL", "CHHAL", "CHHAL", "MONEY", "ARGENT", "FLOUS", "LFLOUS",
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

    // New kinds of questions (checked before the others: "je dois payer" is a bill, not a debt).
    private static let extraMetrics: [(AskQuery.Metric, [String])] = [
        (.pace, ["WILL I FINISH", "WILL I MAKE IT", "WILL IT LAST", "ENOUGH UNTIL", "ENOUGH TILL", "ON TRACK", "AT THIS RATE", "AT THIS PACE",
                 "VAIS JE TENIR", "JE VAIS TENIR", "JUSQU A LA FIN", "A CE RYTHME", "ASSEZ JUSQU", "GHADI NKMMEL", "GHADI YKFINI",
                 "WACH YKFINI", "WACH GHADI YKFINI", "YKFINI", "هل سيكفيني", "يكفيني"]),
        (.afford, ["CAN I AFFORD", "AFFORD", "CAN I BUY", "COULD I BUY", "PUIS JE ACHETER", "JE PEUX ACHETER", "JE PEUX M OFFRIR",
                   "PUIS JE M OFFRIR", "NQDER NCHRI", "N9DER NCHRI", "NQDR NCHRI", "N9DR NCHRI", "YMKN LIYA NCHRI", "WACH NQDER", "WACH N9DER",
                   "هل يمكنني شراء", "نقدر نشري"]),
        (.bills, ["BILLS DUE", "DUE THIS", "STILL DUE", "STILL TO PAY", "LEFT TO PAY", "HAVE TO PAY", "UPCOMING", "COMING UP", "RECURRING",
                  "A PAYER", "RESTE A PAYER", "DOIS ENCORE PAYER", "PRELEVEMENTS", "FACTURES A VENIR", "A VENIR", "KHASSNI NKHLS",
                  "KHASNI NKHLES", "BAQI MA KHLSTCH", "المستحقة", "خاصني نخلص"]),
        (.dart, ["DART", "DARET", "DARTS", "TONTINE", "TONTINES", "دارت"]),
        (.goal, ["SAVED", "SAVE", "SAVINGS", "SAVING", "GOAL", "GOALS", "EPARGNE", "EPARGNES", "ECONOMISE", "ECONOMIES", "OBJECTIF", "OBJECTIFS",
                 "WFFRT", "WEFFERT", "JM3T", "DAKHRT", "ادخرت", "وفرت", "هدف", "الادخار"]),
    ]

    private static let compareWords = ["MORE THAN", "LESS THAN", "COMPARED", "COMPARE", "VS", "VERSUS", "THAN LAST", "PLUS QUE", "MOINS QUE",
                                       "PAR RAPPORT", "COMPARE A", "KTER MN", "QAL MN", "9AL MN", "KTAR MN", "مقارنة", "أكثر من", "أقل من"]

    private static let exceptWords = ["EXCEPT", "BESIDES", "APART FROM", "WITHOUT", "EXCLUDING", "OTHER THAN", "SAUF", "HORS", "SANS",
                                      "A PART", "EN DEHORS", "MN GHIR", "ILA", "ماعدا", "باستثناء", "إلا"]

    private static let monthNames: [(Int, [String])] = [
        (1, ["JANUARY", "JANVIER", "يناير", "JANFI"]), (2, ["FEBRUARY", "FEVRIER", "فبراير", "FIBRAYER"]),
        (3, ["MARCH", "MARS", "مارس"]), (4, ["APRIL", "AVRIL", "أبريل", "ابريل", "ABRIL"]), (5, ["MAY", "MAI", "ماي", "مايو"]),
        (6, ["JUNE", "JUIN", "يونيو", "YOUNYOU"]), (7, ["JULY", "JUILLET", "يوليوز", "يوليو", "YOULYOUZ"]),
        (8, ["AUGUST", "AOUT", "غشت", "أغسطس", "GHOCHT"]), (9, ["SEPTEMBER", "SEPTEMBRE", "SEPT", "شتنبر", "سبتمبر", "CHOTANBIR"]),
        (10, ["OCTOBER", "OCTOBRE", "أكتوبر", "اكتوبر", "OKTOBER"]), (11, ["NOVEMBER", "NOVEMBRE", "نونبر", "نوفمبر", "NOUNBIR"]),
        (12, ["DECEMBER", "DECEMBRE", "دجنبر", "ديسمبر", "DJANBIR"]),
    ]

    private static let incomeSourceWords: [(String, [String])] = [
        ("freelance", ["FREELANCE", "FREELANCING", "MISSION", "MISSIONS", "SIDE JOB", "SIDE HUSTLE", "CLIENT", "CLIENTS", "KHDMA ZAYDA", "FRILANS"]),
        ("salary", ["SALARY", "SALAIRE", "PAYCHECK", "PAIE", "RATEB", "LKHLSA", "راتب", "الراتب"]),
        ("family", ["FAMILY", "FAMILLE", "PARENTS", "FAMILIA", "LWALIDIN", "عائلة", "العائلة"]),
    ]

    /// Words that start a follow-up ("and last month?", "et chez Marjane ?").
    private static let followUpStarts = ["AND", "ET", "WA", "W", "و", "WHAT ABOUT", "ET POUR", "ET EN", "OU"]

    /// A few more everyday words, for iPhones without Apple Intelligence.
    private static let moreMoneyWords = ["COST ME", "BLEW", "WASTED", "SPLURGE", "FLOUSI", "MASROUF", "MASRUF", "COMBIEN J AI", "CA M A COUTE"]

    static func parse(_ question: String, context: AskContext) -> Result {
        let text = " " + CategoryMemory.key(question) + " "
        var result = Result()
        func has(_ phrase: String) -> Bool { text.contains(" " + phrase + " ") }
        func has(_ phrase: String, in part: String) -> Bool { part.contains(" " + phrase + " ") }

        if let metric = extraMetrics.first(where: { $0.1.contains(where: has) })?.0 {
            result.query.metric = metric
            result.foundMetric = true
        } else if let metric = metricPhrases.first(where: { $0.1.contains(where: has) })?.0 {
            result.query.metric = metric
            result.foundMetric = true
        }
        if let range = rangePhrases.first(where: { $0.1.contains(where: has) })?.0 {
            result.query.range = range
            result.foundRange = true
        }
        result.query.compare = compareWords.contains(where: has)

        // A named month ("in October", "en mars 2026"), and days ("between the 1st and the 10th").
        if let month = monthNames.first(where: { $0.1.contains(where: has) })?.0 {
            result.query.month = month
            result.foundRange = true
            if let y = text.firstMatch(of: /\b(20\d\d)\b/), let year = Int(y.1) { result.query.year = year }
        }
        if let m = text.firstMatch(of: /(?:FROM|BETWEEN|DU|ENTRE|MN|BIN|من|بين) (?:THE |LE )?(\d{1,2})(?:ST|ND|RD|TH|ER)? (?:TO|AND|AU|ET|L|LL|HTA|حتى|إلى|و) (?:THE |LE )?(\d{1,2})(?:ST|ND|RD|TH)?\b/),
           let a = Int(m.1), let b = Int(m.2), (1...31).contains(a), (1...31).contains(b), a <= b {
            result.query.dayFrom = a
            result.query.dayTo = b
            result.foundRange = true
        }

        // Categories: before an "except" word they're asked about, after it they're left out.
        var askedPart = text, exceptPart = ""
        if let word = exceptWords.first(where: has), let r = text.range(of: " " + word + " ") {
            askedPart = String(text[..<r.lowerBound]) + " "
            exceptPart = " " + String(text[r.upperBound...])
        }
        func categories(in part: String, keywords: Bool) -> [UUID] {
            var found: [UUID] = []
            for c in context.categories {
                let name = CategoryMemory.key(c.name)
                let words = name.split(separator: " ").map(String.init).filter { $0.count >= 4 && !genericNameWords.contains($0) }
                let extra = keywords ? (categoryWords[c.key] ?? []) + (QuickEntryParser.categoryKeywords[c.key] ?? []) : []
                if (name.count >= 3 && has(name, in: part)) || words.contains(where: { has($0, in: part) })
                    || extra.contains(where: { has($0, in: part) }) {
                    found.append(c.id)
                }
            }
            return found
        }
        let joined = has("AND", in: askedPart) || has("ET", in: askedPart) || has("W", in: askedPart) || askedPart.contains(" و")
        // 1. The user's own category names win. 2. Then a shop they've paid before. 3. Then keywords ("taxi" → Transport).
        var asked = categories(in: askedPart, keywords: false)
        if asked.isEmpty {
            result.query.merchant = context.merchants.map(\.key).filter { has($0, in: askedPart) }.max { $0.count < $1.count }
        }
        if result.query.merchant == nil {
            let withKeywords = categories(in: askedPart, keywords: true)
            if asked.isEmpty || (joined && withKeywords.count > asked.count) { asked = withKeywords }
        }
        // Several categories only when the question really names several ("food and transport").
        if asked.count > 1 && !joined { asked = [asked[0]] }
        result.query.categoryIDs = asked
        result.query.excluded = exceptPart.isEmpty ? [] : categories(in: exceptPart, keywords: true).filter { !asked.contains($0) }

        // A goal by name ("the trip", "Eid"), or a dart by name.
        let goal = context.goals.first { g in
            let name = CategoryMemory.key(g.name)
            return name.count >= 3 && (has(name) || name.split(separator: " ").map(String.init).filter { $0.count >= 4 }.contains(where: has))
        }
        if let goal {
            result.query.goalID = goal.id
            if !result.foundMetric || result.query.metric == .spent {
                result.query.metric = .goal
                result.foundMetric = true
            }
            // "Eid" can also be a word in a category or shop: the goal wins only for goal questions.
            if result.query.metric == .goal { result.query.categoryIDs = []; result.query.merchant = nil }
        }
        if !result.foundMetric, context.darts.contains(where: { CategoryMemory.key($0.name).count >= 3 && has(CategoryMemory.key($0.name)) }) {
            result.query.metric = .dart
            result.foundMetric = true
        }

        // "Can I afford 3000 DH?": the price.
        if result.query.metric == .afford || has("CAN I SPEND") || has("PUIS JE DEPENSER") || has("NQDER NSREF"),
           let m = text.firstMatch(of: /\b(\d{1,9})(?: (\d{3}))?\b/) {
            let digits = String(m.1) + (m.2.map(String.init) ?? "")
            if let units = Int(digits), units > 0, units != result.query.year {
                result.query.amount = units * 100
                result.query.metric = .afford
                result.foundMetric = true
            }
        }
        if result.query.metric == .afford && result.query.amount == nil { result.query.metric = .left }

        // Money in by source.
        if result.query.metric == .earned || !result.foundMetric {
            if let source = incomeSourceWords.first(where: { $0.1.contains(where: has) })?.0,
               result.query.metric == .earned || has("FROM") || has("DE") || has("MN") {
                result.query.incomeSource = source
                result.query.metric = .earned
                result.foundMetric = true
            }
        }

        result.aboutMoney = result.foundMetric || result.foundRange || !result.query.categoryIDs.isEmpty || result.query.merchant != nil
            || result.query.goalID != nil || moneyWords.contains(where: has) || moreMoneyWords.contains(where: has)
            || question.contains(where: \.isNumber)
        return result
    }

    /// "And last month?" after a question: the previous question with the new part changed. Nil when it's a new question.
    static func followUp(_ question: String, result: Result, previous: AskQuery?) -> AskQuery? {
        guard let previous else { return nil }
        let text = " " + CategoryMemory.key(question) + " "
        let words = text.split(separator: " ").count
        let startsLikeFollowUp = followUpStarts.contains { text.hasPrefix(" " + $0 + " ") }
        let changesSomething = result.foundRange || !result.query.categoryIDs.isEmpty || result.query.merchant != nil || result.query.compare
        guard changesSomething, !result.foundMetric || startsLikeFollowUp, startsLikeFollowUp || words <= 4 else { return nil }
        var q = previous
        if result.foundMetric { q.metric = result.query.metric }
        if result.foundRange {
            q.range = result.query.range
            q.month = result.query.month
            q.year = result.query.year
            q.dayFrom = result.query.dayFrom
            q.dayTo = result.query.dayTo
        }
        if !result.query.categoryIDs.isEmpty { q.categoryIDs = result.query.categoryIDs; q.merchant = nil; q.excluded = result.query.excluded }
        if let m = result.query.merchant { q.merchant = m; q.categoryIDs = [] }
        if result.query.compare { q.compare = true }
        return q
    }

    /// When a question isn't understood: the closest questions to tap, using what it did mention.
    static func suggestions(for question: String, context: AskContext) -> [String] {
        let result = parse(question, context: context)
        var list: [String] = []
        if let c = context.categories.first(where: { result.query.categoryIDs.contains($0.id) }) {
            list.append(L10n.t("How much on %@ this month?", c.name))
            list.append(L10n.t("How much is left in %@?", c.name))
        }
        if let key = result.query.merchant, let shop = context.merchants.first(where: { $0.key == key }) {
            list.append(L10n.t("How many times at %@ this month?", shop.name))
        }
        list += [L10n.t("How much did I spend this month?"), L10n.t("Did I spend more than last month?"), L10n.t("Will I finish the month?")]
        return Array(list.prefix(4))
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
        case .goal: L10n.t("Savings goals")
        case .dart: L10n.t("Dart")
        case .bills: L10n.t("Bills to come")
        case .afford: L10n.t("Can I afford it")
        case .pace: L10n.t("This month's pace")
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
        switch q.metric {
        case .owed: return owed(context)
        case .goal: return goal(q, context: context)
        case .dart: return dart(context)
        case .bills: return bills(context)
        case .afford: return afford(q, context: context)
        case .pace: return pace(q, context: context)
        default: break
        }
        if q.compare, [.spent, .earned, .count].contains(q.metric) { return compare(q, context: context) }

        // "Left" is always about the current period.
        var q = q
        if q.metric == .left { q.range = .thisPeriod; q.month = nil; q.dayFrom = nil; q.dayTo = nil }
        let period = interval(q, context: context)
        let when = rangeText(q, context: context)
        let selected = context.categories.filter { q.categoryIDs.contains($0.id) }
        // One name for what was asked: "Café & Food", "Food and Transport", "everything except Rent".
        let groupName: String? = {
            if !selected.isEmpty { return ListFormatter.localizedString(byJoining: selected.map(\.name)) }
            let out = context.categories.filter { q.excluded.contains($0.id) }
            return out.isEmpty ? nil : L10n.t("everything except %@", ListFormatter.localizedString(byJoining: out.map(\.name)))
        }()
        let category: AskCategory? = groupName.map { name in
            AskCategory(id: selected.first?.id ?? UUID(), key: selected.count == 1 ? selected[0].key : "", name: name,
                        budget: selected.isEmpty ? 0 : selected.reduce(0) { $0 + $1.budget })
        }
        let merchantName = q.merchant.map { key in context.merchants.first { $0.key == key }?.name ?? key.capitalized }
        func categoryName(_ id: UUID?) -> String {
            context.categories.first { $0.id == id }?.name ?? L10n.t("Other")
        }
        func inCategory(_ id: UUID?) -> Bool {
            if !q.categoryIDs.isEmpty { return id.map(q.categoryIDs.contains) ?? false }
            if !q.excluded.isEmpty { return !(id.map(q.excluded.contains) ?? false) }
            return true
        }

        let inRange = context.records.filter { period.contains($0.date) }
        let expenses = inRange.filter { r in
            r.kind == .expense && r.amount > 0 && inCategory(r.categoryID)
                && (q.merchant == nil || CategoryMemory.key(r.merchant) == q.merchant)
        }
        let spent = expenses.reduce(0) { $0 + $1.amount }
        let newest = Array(expenses.sorted { $0.date > $1.date }.prefix(5))

        var understood = [metricText(q.metric)]
        if q.metric != .earned, q.metric != .top {
            if let category { understood.append(category.name) } else if let merchantName { understood.append(merchantName) }
        }
        if q.metric == .earned, let source = q.incomeSource, let s = IncomeSource(rawValue: source) { understood.append(s.title) }
        understood.append(when)

        func nothing() -> AskAnswer {
            let target = q.metric == .earned ? nil : (category?.name ?? merchantName)
            let sentence = target.map { L10n.t("Nothing for %@ %@.", $0, when) } ?? L10n.t("Nothing found %@.", when)
            return AskAnswer(amount: nil, sentence: sentence, understood: understood, entries: [])
        }

        switch q.metric {
        case .owed, .goal, .dart, .bills, .afford, .pace:
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
            let incomes = inRange.filter { $0.kind == .income && (q.incomeSource == nil || $0.incomeSource == q.incomeSource) }
            guard !incomes.isEmpty else { return nothing() }
            let total = incomes.reduce(0) { $0 + $1.amount }
            let sentence = q.incomeSource.flatMap(IncomeSource.init(rawValue:)).map {
                L10n.t("You received %@ from %@ %@.", Money.format(total, privacy: .income), $0.title.lowercased(), when)
            } ?? L10n.t("You received %@ %@.", Money.format(total, privacy: .income), when)
            return AskAnswer(amount: total, sentence: sentence,
                             understood: understood, entries: Array(incomes.sorted { $0.date > $1.date }.prefix(5)), sensitive: true)

        case .left:
            if let category {
                let used = inRange.filter { $0.kind == .expense && inCategory($0.categoryID) }.reduce(0) { $0 + $1.amount }
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
                ? L10n.t("%@ left to spend %@: %@ in, %@ spent.", Money.format(summary.left, privacy: .income), when,
                         Money.format(summary.moneyIn, privacy: .income), Money.format(summary.spent))
                : L10n.t("You spent %@ more than came in %@.", Money.format(-summary.left, privacy: .income), when)
            return AskAnswer(amount: summary.left, sentence: sentence, understood: understood, entries: [], sensitive: true)

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
            let all = inRange.filter { $0.kind == .expense && inCategory($0.categoryID) }
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
