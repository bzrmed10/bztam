import Foundation
import SwiftData
import Testing
@testable import Bztam

@MainActor
struct ResetDataTests {
    @Test func deletesEverythingAndShowsOnboardingAgain() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let settings = DataStore.settings(in: context)
        settings.onboardingDone = true
        settings.payday = 25
        DataStore.ensureCategories(in: context, income: 800_000)
        let food = try #require(try context.fetch(FetchDescriptor<BudgetCategory>()).first)
        context.insert(Entry(kind: .expense, amount: 4_000, merchant: "Café", category: food))
        context.insert(Entry(kind: .income, amount: 800_000, merchant: "Salary"))
        context.insert(Friend(name: "Sara"))
        try context.save()

        ResetData.deleteEverything(in: context)

        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<BudgetCategory>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Friend>()) == 0)
        let rows = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(rows.count == 1)
        #expect(rows.first?.onboardingDone == false)
        #expect(rows.first?.payday == 1)
    }
}
