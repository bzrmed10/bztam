import Foundation
import SwiftData
import Testing
@testable import Bztam

struct SplitMathTests {
    @Test func equalSharesAlwaysAddUp() {
        #expect(SplitMath.equalShares(total: 60_000, people: 4, payerIndex: 0) == [15_000, 15_000, 15_000, 15_000])
        // 320 DH for 3: the payer absorbs the extra centimes.
        #expect(SplitMath.equalShares(total: 32_000, people: 3, payerIndex: 1) == [10_666, 10_668, 10_666])
        // Payer not sharing: leftovers go to the first people.
        #expect(SplitMath.equalShares(total: 10_001, people: 2, payerIndex: nil) == [5_001, 5_000])
        #expect(SplitMath.equalShares(total: 0, people: 3, payerIndex: 0).isEmpty)
        for total in [1, 7, 99, 100_003] {
            #expect(SplitMath.equalShares(total: total, people: 3, payerIndex: 2).reduce(0, +) == total)
        }
    }

    @Test func paymentsClearOldestFirst() {
        let a = SplitMath.allocate(20_000, over: [15_000, 0, 10_000])
        #expect(a.map { $0.index } == [0, 2])
        #expect(a.map { $0.amount } == [15_000, 5_000])
        #expect(SplitMath.allocate(5_000, over: []).isEmpty)
    }
}

@MainActor
struct SplitFlowTests {
    private func spent(_ c: BudgetCategory, _ context: ModelContext) -> Centimes {
        ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).filter { $0.kind == .expense && $0.category?.id == c.id }.reduce(0) { $0 + $1.amount }
    }

    @Test func youPaidThenFriendsPayBackLikeARefund() throws {
        let context = DataStore.makeContainer(inMemory: true).mainContext
        let out = BudgetCategory(key: "goingout", name: "Going out", symbol: "sparkles", budget: 60_000, order: 1)
        context.insert(out)
        let karim = Friend(name: "Karim"), sara = Friend(name: "Sara"), omar = Friend(name: "Omar")
        for f in [karim, sara, omar] { context.insert(f) }

        SplitActions.create(merchant: "Café Clock", total: 60_000, date: .now, category: out, payer: nil,
                            friends: [karim, sara, omar], includesMe: true, remind: false, context: context)
        // Like a bank: the whole bill leaves your money.
        #expect(spent(out, context) == 60_000)
        #expect(SplitActions.balances(context: context).first { $0.name == "Karim" }?.owesYou == 15_000)

        // Karim pays 100, then 50: it comes back into Going out, not as money in.
        SplitActions.friendPaidBack(karim, amount: 10_000, context: context)
        SplitActions.friendPaidBack(karim, amount: 5_000, context: context)
        #expect(spent(out, context) == 45_000)
        #expect(((try? context.fetch(FetchDescriptor<Entry>())) ?? []).allSatisfy { $0.kind == .expense })
        #expect(SplitActions.balances(context: context).first { $0.name == "Karim" }?.owesYou == 0)

        let period = BudgetCalculator.period(containing: .now, payday: 1)
        #expect(SplitActions.comingBack(categoryID: out.id, in: period, context: context) == 30_000)

        // Once everyone has paid, only your share is left as spent.
        SplitActions.friendPaidBack(sara, amount: 15_000, context: context)
        SplitActions.forget(omar, owedToMe: true, context: context)
        #expect(spent(out, context) == 30_000)
        #expect(SplitActions.comingBack(categoryID: out.id, in: period, context: context) == 0)
    }

    @Test func friendPaidNothingLeavesUntilYouPayBack() throws {
        let context = DataStore.makeContainer(inMemory: true).mainContext
        let out = BudgetCategory(key: "goingout", name: "Going out", symbol: "sparkles", budget: 60_000, order: 1)
        context.insert(out)
        let sara = Friend(name: "Sara"), nadia = Friend(name: "Nadia")
        context.insert(sara); context.insert(nadia)

        let result = SplitActions.create(merchant: "Pizza", total: 32_000, date: .now, category: out, payer: sara,
                                         friends: [sara, nadia], includesMe: true, remind: false, context: context)
        #expect(spent(out, context) == 0)
        #expect(result.lines.first { $0.isPayer }?.name == "Sara")
        #expect(SplitActions.balances(context: context).first { $0.name == "Sara" }?.youOwe == 10_666)
        // Nadia owes Sara, not you.
        #expect(SplitActions.balances(context: context).first { $0.name == "Nadia" }?.owesYou == 0)

        SplitActions.youPaidBack(sara, amount: 10_666, context: context)
        #expect(spent(out, context) == 10_666)
        #expect(SplitActions.balances(context: context).first { $0.name == "Sara" }?.youOwe == 0)
    }

    @Test func messageListsFriendsShares() {
        let lines = [SplitActions.Line(name: L10n.t("You"), amount: 15_000, isPayer: true),
                     SplitActions.Line(name: "Karim", amount: 15_000, isPayer: false)]
        let text = SplitActions.message(merchant: "Café Clock", total: 30_000, date: .now, lines: lines, paidByMe: true, payerName: nil)
        #expect(text.contains("Café Clock"))
        #expect(text.contains("Karim"))
        #expect(!text.contains(L10n.t("Me") + ":"))
    }
}
