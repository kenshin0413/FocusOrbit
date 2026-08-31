import SwiftUI

struct MetricCard: View {
    let label: String
    let value: String
    var symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(AppTheme.secondary)
                Spacer()
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.blue)
                    .padding(8)
                    .background(AppTheme.blue.opacity(0.12), in: Circle())
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .light))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .spacePanel()
    }
}
