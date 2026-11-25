import Foundation

/// A savings goal as plain values for Ask.
struct AskGoal: Sendable, Equatable {
    var id: UUID
    var name: String
    var saved: Centimes
    var target: Centimes
    var deadline: Date?
}

/// A dart (tontine) as plain values for Ask.
struct AskDart: Sendable, Equatable {
    var name: String
    var amount: Centimes
    var pot: Centimes
    /// The next rounds from today: date and who collects ("You" for the user).
    var upcoming: [(date: Date, collector: String, isMe: Bool)]
    /// The date of the user's own turn, if still to come.
    var myTurn: Date?

    static func == (a: AskDart, b: AskDart) -> Bool {
        a.name == b.name && a.amount == b.amount && a.pot == b.pot && a.myTurn == b.myTurn
            && a.upcoming.map(\.date) == b.upcoming.map(\.date) && a.upcoming.map(\.collector) == b.upcoming.map(\.collector)
    }
}

/// A recurring bill still to come this period.
struct AskBill: Sendable, Equatable {
    var name: String
    var amount: Centimes
    var date: Date
    var categoryID: UUID?
}

extension AskEngine {
    // MARK: Periods

    /// The dates a question covers: a named month, days of a month, or one of the usual ranges.
    static func interval(_ q: AskQuery, context: AskContext) -> BudgetPeriod {
        let cal = context.calendar, now = context.now
        if q.month != nil || q.dayFrom != nil {
            var comps = cal.dateComponents([.year, .month], from: now)
            if let month = q.month {
                comps.month = month
                // Without a year, the most recent one: "October" in March means last October.
                if let year = q.year { comps.year = year } else if month > (cal.component(.month, from: now)) { comps.year = (comps.year ?? 2026) - 1 }
            }
            comps.day = 1
            guard let first = cal.date(from: comps), let monthSpan = cal.dateInterval(of: .month, for: first) else {
                return interval(q.range, context: context)
            }
            guard let from = q.dayFrom, let to = q.dayTo else { return BudgetPeriod(start: monthSpan.start, end: monthSpan.end) }
            let days = cal.range(of: .day, in: .month, for: first)?.count ?? 31
            let start = cal.date(byAdding: .day, value: min(from, days) - 1, to: monthSpan.start) ?? monthSpan.start
            let end = cal.date(byAdding: .day, value: min(to, days), to: monthSpan.start) ?? monthSpan.end
            return BudgetPeriod(start: start, end: end)
        }
        return interval(q.range, context: context)
    }

    static func rangeText(_ q: AskQuery, context: AskContext) -> String {
        let cal = context.calendar
        if let month = q.month {
            let name = DateText.monthName(cal.date(from: DateComponents(year: 2026, month: month, day: 1)) ?? context.now)
            let withYear = q.year.map { name + " " + String($0) } ?? name
            if let a = q.dayFrom, let b = q.dayTo { return L10n.t("from %d to %d %@", a, b, withYear) }
            return L10n.t("in %@", withYear)
        }
        if let a = q.dayFrom, let b = q.dayTo { return L10n.t("from the %d to the %d of this month", a, b) }
        return rangeText(q.range)
    }

    /// The period just before, of the same kind: last month, last week, yesterday, last year, the month before.
    static func previous(_ q: AskQuery, context: AskContext) -> (current: AskQuery, before: AskQuery) {
        var current = q, before = q
        current.compare = false
        before.compare = false
        if let month = q.month {
            let year = q.year ?? {
                let now = context.calendar.dateComponents([.year, .month], from: context.now)
                return month > (now.month ?? 12) ? (now.year ?? 2026) - 1 : (now.year ?? 2026)
            }()
            current.year = year
            before.month = month == 1 ? 12 : month - 1
            before.year = month == 1 ? year - 1 : year
            return (current, before)
        }
        switch q.range {
        case .thisPeriod, .lastPeriod: current.range = .thisPeriod; before.range = .lastPeriod
        case .thisWeek, .lastWeek: current.range = .thisWeek; before.range = .lastWeek
        case .today, .yesterday: current.range = .today; before.range = .yesterday
        case .thisYear:
            let y = context.calendar.component(.year, from: context.now)
            current.range = .thisYear
            before.month = nil
            before.year = y - 1
        case .all: current.range = .thisPeriod; before.range = .lastPeriod
        }
        return (current, before)
    }

    // MARK: Comparisons

    static func compare(_ q: AskQuery, context: AskContext) -> AskAnswer {
        let (now, before) = previous(q, context: context)
        func total(_ x: AskQuery) -> (Centimes, Int, String) {
            let period: BudgetPeriod
            if x.month == nil, x.dayFrom == nil, let y = x.year, x.range == q.range, q.range == .thisYear, x.year != nil {
                // Last year: the whole calendar year.
                let start = context.calendar.date(from: DateComponents(year: y, month: 1, day: 1)) ?? context.now
                let end = context.calendar.date(byAdding: .year, value: 1, to: start) ?? context.now
                period = BudgetPeriod(start: start, end: end)
            } else {
                period = interval(x, context: context)
            }
            let records = context.records.filter { r in
                guard period.contains(r.date) else { return false }
                if q.metric == .earned { return r.kind == .income && (q.incomeSource == nil || r.incomeSource == q.incomeSource) }
                guard r.kind == .expense, r.amount > 0 else { return false }
                if !q.categoryIDs.isEmpty { return r.categoryID.map(q.categoryIDs.contains) ?? false }
                if !q.excluded.isEmpty, let id = r.categoryID, q.excluded.contains(id) { return false }
                if let m = q.merchant { return CategoryMemory.key(r.merchant) == m }
                return true
            }
            let label = (x.year != nil && x.month == nil && q.range == .thisYear) ? L10n.t("in %@", String(x.year ?? 0)) : rangeText(x, context: context)
            return (records.reduce(0) { $0 + $1.amount }, records.count, label)
        }
        let (a, countA, labelA) = total(now)
        let (b, countB, labelB) = total(before)
        let target = context.categories.filter { q.categoryIDs.contains($0.id) }.map(\.name)
        let what = target.isEmpty ? (q.merchant.flatMap { key in context.merchants.first { $0.key == key }?.name }) : ListFormatter.localizedString(byJoining: target)
        var understood = [metricText(q.metric), L10n.t("compared")]
        if let what { understood.append(what) }
        understood.append(labelA)

        if q.metric == .count {
            let sentence = countA == countB
                ? L10n.t("%d expenses %@, the same as %@.", countA, labelA, labelB)
                : L10n.t("%d expenses %@, against %d %@.", countA, labelA, countB, labelB)
            return AskAnswer(amount: nil, sentence: sentence, understood: understood, entries: [])
        }
        let privacy: AmountPrivacy = q.metric == .earned ? .income : .any
        let diff = a - b
        let pct = b > 0 ? Int((Double(abs(diff)) / Double(b) * 100).rounded()) : 0
        let earned = q.metric == .earned
        let fa = Money.format(a, privacy: privacy), fd = Money.format(abs(diff), privacy: privacy)
        let sentence: String
        if b == 0 && a == 0 {
            sentence = L10n.t("Nothing %@ or %@.", labelA, labelB)
        } else if b == 0 {
            sentence = earned ? L10n.t("You received %@ %@, and nothing %@.", fa, labelA, labelB)
                              : L10n.t("You spent %@ %@, and nothing %@.", fa, labelA, labelB)
        } else if diff == 0 {
            sentence = earned ? L10n.t("You received %@ %@, exactly like %@.", fa, labelA, labelB)
                              : L10n.t("You spent %@ %@, exactly like %@.", fa, labelA, labelB)
        } else if diff > 0 {
            sentence = earned ? L10n.t("You received %@ %@: %@ more than %@ (+%d%%).", fa, labelA, fd, labelB, pct)
                              : L10n.t("You spent %@ %@: %@ more than %@ (+%d%%).", fa, labelA, fd, labelB, pct)
        } else {
            sentence = earned ? L10n.t("You received %@ %@: %@ less than %@ (−%d%%).", fa, labelA, fd, labelB, pct)
                              : L10n.t("You spent %@ %@: %@ less than %@ (−%d%%).", fa, labelA, fd, labelB, pct)
        }
        return AskAnswer(amount: a, sentence: sentence, understood: understood, entries: [], sensitive: q.metric == .earned)
    }

    // MARK: Goals, darts, bills

    static func goal(_ q: AskQuery, context: AskContext) -> AskAnswer {
        let understood = [metricText(.goal)]
        if let g = context.goals.first(where: { $0.id == q.goalID }) {
            var sentence: String
            if g.target > 0 {
                let pct = Int((GoalMath.progress(saved: g.saved, target: g.target) * 100).rounded())
                let toGo = max(0, g.target - g.saved)
                sentence = toGo == 0
                    ? L10n.t("You've saved %@ for %@: the goal is reached.", Money.format(g.saved), g.name)
                    : L10n.t("You've saved %@ for %@, %d%% of %@. %@ to go.", Money.format(g.saved), g.name, pct,
                             Money.format(g.target), Money.format(toGo))
                if toGo > 0, let deadline = g.deadline {
                    let monthly = GoalMath.suggestedMonthly(target: g.target, saved: g.saved, deadline: deadline, now: context.now,
                                                            calendar: context.calendar)
                    if monthly > 0 { sentence += " " + L10n.t("%@ a month gets you there by %@.", Money.format(monthly), DateText.short(deadline)) }
                }
            } else {
                sentence = L10n.t("You've saved %@ for %@.", Money.format(g.saved), g.name)
            }
            return AskAnswer(amount: g.saved, sentence: sentence, understood: understood + [g.name], entries: [])
        }
        guard !context.goals.isEmpty else {
            return AskAnswer(amount: nil, sentence: L10n.t("You have no savings goal yet. Add one in Plan."), understood: understood, entries: [])
        }
        let total = context.goals.reduce(0) { $0 + $1.saved }
        let list = ListFormatter.localizedString(byJoining: context.goals.map { "\($0.name) \(Money.format($0.saved))" })
        let sentence = context.goals.count == 1
            ? L10n.t("You've saved %@ for %@.", Money.format(total), context.goals[0].name)
            : L10n.t("You've saved %@ in %d goals: %@.", Money.format(total), context.goals.count, list)
        return AskAnswer(amount: total, sentence: sentence, understood: understood, entries: [])
    }

    static func dart(_ context: AskContext) -> AskAnswer {
        let understood = [metricText(.dart)]
        let active = context.darts.filter { !$0.upcoming.isEmpty }
        guard !active.isEmpty else {
            return AskAnswer(amount: nil, sentence: context.darts.isEmpty ? L10n.t("You have no dart.") : L10n.t("Your darts are finished."),
                             understood: understood, entries: [])
        }
        var parts: [String] = []
        var amount: Centimes?
        for d in active {
            var line: String
            if let next = d.upcoming.first {
                line = next.isMe
                    ? L10n.t("%@: next round on %@, and it's your turn to collect %@.", d.name, DateText.short(next.date), Money.format(d.pot))
                    : L10n.t("%@: next round on %@, %@ collects. You pay %@.", d.name, DateText.short(next.date), next.collector, Money.format(d.amount))
                if !next.isMe, let mine = d.myTurn {
                    line += " " + L10n.t("Your turn: %@ (%@).", DateText.short(mine), Money.format(d.pot))
                }
            } else {
                line = d.name
            }
            if amount == nil, d.myTurn != nil { amount = d.pot }
            parts.append(line)
        }
        return AskAnswer(amount: amount, sentence: parts.joined(separator: " "), understood: understood, entries: [])
    }

    static func bills(_ context: AskContext) -> AskAnswer {
        let understood = [metricText(.bills), rangeText(.thisPeriod)]
        let period = interval(.thisPeriod, context: context)
        let due = context.bills.filter { period.contains($0.date) && $0.date >= context.calendar.startOfDay(for: context.now) }
            .sorted { $0.date < $1.date }
        guard !due.isEmpty else {
            return AskAnswer(amount: 0, sentence: L10n.t("No more recurring bills this period."), understood: understood, entries: [])
        }
        let total = due.reduce(0) { $0 + $1.amount }
        let list = ListFormatter.localizedString(byJoining: due.prefix(4).map { "\($0.name) (\(DateText.short($0.date)))" })
        let sentence = due.count == 1
            ? L10n.t("1 bill still to come this period: %@, %@.", list, Money.format(total))
            : L10n.t("%d bills still to come this period, %@ in total: %@.", due.count, Money.format(total), list)
        let entries = due.prefix(5).map { EntryRecord(kind: .expense, amount: $0.amount, date: $0.date, merchant: $0.name, categoryID: $0.categoryID) }
        return AskAnswer(amount: total, sentence: sentence, understood: understood, entries: Array(entries))
    }

    // MARK: Can I, will I (numbers only, never advice)

    private static func thisPeriod(_ context: AskContext) -> (period: BudgetPeriod, summary: PeriodSummary) {
        let period = interval(.thisPeriod, context: context)
        let summary = BudgetCalculator.summary(
            entries: context.records.filter { period.contains($0.date) }
                .map { EntryValue(kind: $0.kind, amount: $0.amount, date: $0.date, categoryID: $0.categoryID) },
            categories: [], period: period)
        return (period, summary)
    }

    static func afford(_ q: AskQuery, context: AskContext) -> AskAnswer {
        let price = q.amount ?? 0
        let (_, s) = thisPeriod(context)
        let after = s.left - price
        let saved = context.goals.reduce(0) { $0 + $1.saved }
        let understood = [metricText(.afford), Money.format(price), rangeText(.thisPeriod)]
        var sentence = after >= 0
            ? L10n.t("Yes, this period: after %@ you'd still have %@ left to spend.", Money.format(price), Money.format(after, privacy: .income))
            : L10n.t("Not this period: %@ is %@ more than what's left (%@).", Money.format(price), Money.format(-after, privacy: .income),
                     Money.format(max(0, s.left), privacy: .income))
        if after < 0 && saved >= -after {
            sentence += " " + L10n.t("Your goals hold %@.", Money.format(saved))
        }
        return AskAnswer(amount: after, sentence: sentence, understood: understood, entries: [], sensitive: true)
    }

    static func pace(_ q: AskQuery, context: AskContext) -> AskAnswer {
        let (period, s) = thisPeriod(context)
        let cal = context.calendar
        let totalDays = max(1, cal.dateComponents([.day], from: period.start, to: period.end).day ?? 30)
        let elapsed = max(1, min(totalDays, (cal.dateComponents([.day], from: period.start, to: context.now).day ?? 0) + 1))
        let understood = [metricText(.pace), rangeText(.thisPeriod)]
        guard s.moneyIn > 0 else {
            return AskAnswer(amount: nil, sentence: L10n.t("Add your money in for this period first, then I can tell you."),
                             understood: understood, entries: [])
        }
        let projected = s.spent * totalDays / elapsed
        let keep = s.moneyIn - projected
        let daysLeft = totalDays - elapsed
        let sentence: String
        if keep >= 0 {
            sentence = L10n.t("At this pace you'd spend about %@ this period and keep about %@. %@ a day is what you can spend for the %d days left.",
                              Money.format(projected), Money.format(keep, privacy: .income),
                              Money.format(daysLeft > 0 ? max(0, s.left) / daysLeft : 0, privacy: .income), daysLeft)
        } else {
            let perDay = projected / totalDays
            let shortDays = perDay > 0 ? Int((Double(-keep) / Double(perDay)).rounded(.up)) : 0
            sentence = L10n.t("At this pace you'd spend about %@ against %@ in, so you'd run short about %d days before payday.",
                              Money.format(projected), Money.format(s.moneyIn, privacy: .income), min(shortDays, max(daysLeft, 1)))
        }
        return AskAnswer(amount: keep, sentence: sentence, understood: understood, entries: [], sensitive: true)
    }
}
