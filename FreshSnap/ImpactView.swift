//
//  ImpactView.swift
//  FreshSnap
//
//  Created by Mack Low on 17/11/2026.
//

import SwiftUI
import Charts

// FreshSnap – Week 9, Upgrade 1
// "Your impact" on Profile: how much food was used rather than wasted,
// money saved this month, and a weekly chart of food used and thrown away.

struct ImpactSection: View {
    let food: [FoodItem]          // this user's food

    private let weeksShown = 6

    // One bar on the chart
    private struct WeekBar: Identifiable {
        let id = UUID()
        let weekStart: Date
        let outcome: String       // "Used" or "Thrown away"
        let count: Int
    }

    private var finished: [FoodItem] {
        food.filter { $0.status != .inFridge }
    }

    private var usedCount: Int { finished.filter { $0.status == .used }.count }
    private var thrownCount: Int { finished.filter { $0.status == .thrownAway }.count }

    // e.g. 87 (%), or nil if nothing has been finished yet
    private var usedPercent: Int? {
        let total = usedCount + thrownCount
        guard total > 0 else { return nil }
        return Int((Double(usedCount) / Double(total) * 100).rounded())
    }

    private var savedThisMonth: Double {
        let calendar = Calendar.current
        return finished
            .filter { $0.status == .used && calendar.isDate($0.finishedDay, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.price }
    }

    // The start of each of the last 6 weeks, oldest first
    private var weekStarts: [Date] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<weeksShown).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek)
        }
    }

    private var bars: [WeekBar] {
        let calendar = Calendar.current
        return weekStarts.flatMap { start -> [WeekBar] in
            let inWeek = finished.filter {
                calendar.dateInterval(of: .weekOfYear, for: $0.finishedDay)?.start == start
            }
            return [
                WeekBar(weekStart: start, outcome: "Used",
                        count: inWeek.filter { $0.status == .used }.count),
                WeekBar(weekStart: start, outcome: "Thrown away",
                        count: inWeek.filter { $0.status == .thrownAway }.count)
            ]
        }
    }

    var body: some View {
        Section {
            if finished.isEmpty {
                Text("Mark food as used or thrown away, and your impact will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let usedPercent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You used \(usedPercent)% of your food")
                            .font(.title3.bold())
                        Text("\(usedCount) used, \(thrownCount) thrown away")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                LabeledContent("Saved this month",
                               value: savedThisMonth.formatted(.currency(code: "GBP")))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last \(weeksShown) weeks")
                        .font(.subheadline.weight(.semibold))

                    Chart(bars) { bar in
                        BarMark(
                            x: .value("Week", bar.weekStart, unit: .weekOfYear),
                            y: .value("Items", bar.count)
                        )
                        .foregroundStyle(by: .value("What happened", bar.outcome))
                        .position(by: .value("What happened", bar.outcome))
                    }
                    .chartForegroundStyleScale([
                        "Used": Color.green,
                        "Thrown away": Color.red
                    ])
                    .chartXAxis {
                        AxisMarks(values: weekStarts) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 180)
                    .accessibilityLabel("Food used and thrown away each week for the last \(weeksShown) weeks")
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Your impact")
        } footer: {
            if !finished.isEmpty {
                Text("Each pair of bars is one week: green for food used, red for food thrown away.")
            }
        }
    }
}
