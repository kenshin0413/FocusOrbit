import SwiftUI

struct MissionPassCard: View {
    let mission: Mission
    var crewName: String
    var completed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MISSION PASS").font(.system(size: 28, weight: .black, design: .rounded)).tracking(1)
                    Text("FOCUS ORBIT TRANSIT AUTHORITY").font(.caption2).tracking(1.5).foregroundStyle(.secondary)
                }
                Spacer(); Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2)
            }
            Divider()
            passRow("CREW", crewName)
            passRow("FROM", "EARTH ORBIT")
            passRow("DESTINATION", mission.destination.englishName)
            passRow("MISSION", mission.focusTitle)
            passRow("DURATION", "\(mission.durationMinutes) MIN")
            passRow("MISSION NO", mission.missionNumber)
            HStack { Text("STATUS").frame(width: 92, alignment: .leading); Text(completed ? "COMPLETE" : "READY").foregroundStyle(completed ? .green : .blue) }
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            if completed {
                Text("MISSION COMPLETE").font(.system(.headline, design: .rounded, weight: .black)).tracking(1.5).foregroundStyle(.red)
                    .padding(.horizontal, 18).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 5).stroke(.red, lineWidth: 3)).rotationEffect(.degrees(-7)).frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.17))
        .padding(24)
        .background(Color(red: 0.92, green: 0.93, blue: 0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .trailing) { Rectangle().fill(mission.destination.accent).frame(width: 7).padding(.vertical, 24) }
        .shadow(color: mission.destination.accent.opacity(0.18), radius: 24)
    }

    private func passRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: 92, alignment: .leading).foregroundStyle(.secondary)
            Text(value).lineLimit(2)
        }.font(.system(.subheadline, design: .monospaced, weight: .semibold))
    }
}
