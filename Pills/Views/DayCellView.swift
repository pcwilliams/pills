import SwiftUI

struct DayCellView: View {
    let day: Int
    let date: Date
    let record: PillRecord?
    let isToday: Bool
    let isFuture: Bool
    let onToggleMorning: () -> Void
    let onToggleEvening: () -> Void

    private var morningTaken: Bool { record?.morningTaken ?? false }
    private var eveningTaken: Bool { record?.eveningTaken ?? false }
    private var canTap: Bool { !isFuture }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(day)")
                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .primary : .secondary)
                .frame(height: 16)

            Spacer()

            // Morning bar (cyan)
            pillBar(
                color: .cyan,
                taken: morningTaken,
                action: onToggleMorning
            )
            .frame(maxHeight: 16)

            Spacer()

            // Evening bar (orange)
            pillBar(
                color: .orange,
                taken: eveningTaken,
                action: onToggleEvening
            )
            .frame(maxHeight: 16)

            Spacer()
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.blue.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func pillBar(color: Color, taken: Bool, action: @escaping () -> Void) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(barColor(baseColor: color, taken: taken))
            .frame(maxHeight: .infinity)
            .frame(minHeight: 6)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canTap else { return }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                action()
            }
    }

    private func barColor(baseColor: Color, taken: Bool) -> Color {
        if taken && isToday {
            return Color.gray
        } else if taken {
            return Color.gray.opacity(0.4)
        } else if isToday {
            return baseColor
        } else {
            return baseColor.opacity(0.3)
        }
    }
}
