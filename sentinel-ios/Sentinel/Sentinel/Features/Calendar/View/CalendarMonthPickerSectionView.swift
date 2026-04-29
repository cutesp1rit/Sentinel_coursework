import SentinelUI
import SentinelCore
import SwiftUI

struct CalendarMonthPickerSectionView: View {
    let isInlineMonthPickerVisible: Bool
    let selectedDate: Date
    let selectedMonthLabel: String
    let onToggle: () -> Void
    let onSelectDate: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Button(action: onToggle) {
                HStack {
                    Text(selectedMonthLabel.capitalized)
                        .font(.headline.weight(.semibold))
                    Image(systemName: isInlineMonthPickerVisible ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isInlineMonthPickerVisible {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedDate },
                        set: onSelectDate
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
    }
}
