import Foundation
import Testing
@testable import Bztam

struct DartTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }

    /// Five members, 1,000 DH each, the user collects third (round 2). First round 31 Jan 2027.
    private var plan: DartPlan {
        DartPlan(amount: 100_000, start: date(2027, 1, 31, 9), members: ["Karim", "Sara", "Me", "Omar", "Nadia"], meIndex: 2)
    }

    @Test func potAndCollectors() {
        #expect(plan.pot == 500_000)
        #expect(plan.collector(ofRound: 0) == 0)
        #expect(plan.collector(ofRound: 2) == 2)
        #expect(plan.myRound == 2)
    }

    @Test func roundDatesKeepTheEndOfTheMonth() {
        let days = (0..<4).map { cal.dateComponents([.month, .day], from: plan.date(ofRound: $0, calendar: cal)) }
        #expect(days.map { [$0.month!, $0.day!] } == [[1, 31], [2, 28], [3, 31], [4, 30]])
    }

    @Test func statusOverTime() {
        #expect(plan.status(on: date(2027, 1, 30), calendar: cal) == .notStarted(first: plan.start))
        // The round starts on its day, even before the hour it was set at.
        #expect(plan.status(on: date(2027, 1, 31, 7), calendar: cal) == .round(0))
        #expect(plan.status(on: date(2027, 2, 27), calendar: cal) == .round(0))
        #expect(plan.status(on: date(2027, 2, 28), calendar: cal) == .round(1))
        #expect(plan.status(on: date(2027, 5, 31), calendar: cal) == .round(4))
        #expect(plan.status(on: date(2027, 6, 30), calendar: cal) == .finished)
    }

    @Test func paymentsAndTotals() {
        var p = plan
        p.paid = [DartPlan.key(round: 0, member: 2), DartPlan.key(round: 0, member: 0), DartPlan.key(round: 2, member: 2)]
        #expect(p.paidCount(round: 0) == 2)
        #expect(p.hasPaid(2, round: 2) && !p.hasPaid(2, round: 1))
        #expect(p.myPaidTotal == 200_000)
        #expect(p.myReceivedTotal == 0)
        p.received = [2]
        #expect(p.myReceivedTotal == 500_000)
        // In round 3 the user still owes round 1 and round 3.
        #expect(p.myUnpaidRounds(on: date(2027, 4, 30), calendar: cal) == [1, 3])
        #expect(p.myUnpaidRounds(on: date(2027, 1, 1), calendar: cal).isEmpty)
    }

    @Test func upcomingRoundsForReminders() {
        let up = plan.upcomingRounds(after: date(2027, 3, 31, 18), limit: 3, calendar: cal)
        #expect(up.map { $0.round } == [2, 3, 4])
        #expect(plan.upcomingRounds(after: date(2027, 7, 1), calendar: cal).isEmpty)
    }

    @Test func emptyDartIsFinished() {
        let empty = DartPlan(amount: 100, start: date(2027, 1, 1), members: [], meIndex: 0)
        #expect(empty.status(on: date(2027, 1, 2), calendar: cal) == .finished)
        #expect(empty.pot == 0)
    }
}
