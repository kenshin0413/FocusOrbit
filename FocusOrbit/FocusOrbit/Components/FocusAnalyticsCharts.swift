import Charts
import SwiftUI

struct DailyFocusChart: View {
    let points: [FocusChartPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("日", point.date, unit: .day),
                y: .value("集中時間", point.seconds / 60)
            )
            .foregroundStyle(AppTheme.navigation.gradient)
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel { if let minutes = value.as(Double.self) { Text(String(localized: "chart.minutes_value", defaultValue: "\(Int(minutes))分")) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "chart.daily_focus", defaultValue: "直近7日間の集中時間"))
        .accessibilityValue(points.map { String(localized: "chart.daily_focus.value", defaultValue: "\($0.label)曜日 \(Int($0.seconds / 60))分") }.joined(separator: "、"))
    }
}

struct FocusCategoryChart: View {
    let title: String
    let points: [CategoryFocusPoint]
    let unit: String
    var color: Color = AppTheme.transit

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value("分類", point.label), y: .value(title, point.value))
                .foregroundStyle(color.gradient)
                .cornerRadius(3)
            if point.value > 0 {
                PointMark(x: .value("分類", point.label), y: .value(title, point.value))
                    .symbolSize(18).foregroundStyle(.white)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel { if let number = value.as(Double.self) { Text(String(localized: "chart.category_value", defaultValue: "\(Int(number))\(unit)")) } }
            }
        }
        .chartXAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
        .frame(height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(points.map { String(localized: "chart.category_accessibility_value", defaultValue: "\($0.label) \(Int($0.value))\(unit)") }.joined(separator: "、"))
    }
}

struct RatingDistributionChart: View {
    let items: [RatingDistributionItem]

    var body: some View {
        Chart(items) { item in
            BarMark(x: .value("件数", item.count), y: .value("評価", item.rating.title))
                .foregroundStyle(AppTheme.success.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing) { Text(String(localized: "chart.rating_count", defaultValue: "\(item.count)件")).font(.caption2).foregroundStyle(AppTheme.secondary) }
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks { AxisValueLabel().font(.caption2) } }
        .frame(height: 145)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "chart.rating_distribution", defaultValue: "集中評価の分布"))
        .accessibilityValue(items.map { String(localized: "chart.rating_distribution.value", defaultValue: "\($0.rating.title) \($0.count)件") }.joined(separator: "、"))
    }
}
