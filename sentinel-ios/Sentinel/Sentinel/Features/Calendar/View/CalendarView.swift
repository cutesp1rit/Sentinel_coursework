import ComposableArchitecture
import SwiftUI

struct CalendarView: View {
    let store: StoreOf<CalendarReducer>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                pickerRow

                datePickerCard

                if let errorMessage = store.errorMessage {
                    errorCard(message: errorMessage)
                }

                if store.isLoading && store.events.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xLarge)
                } else if store.events.isEmpty {
                    emptyState
                } else {
                    eventSections
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(HomeTopGradientBackground().ignoresSafeArea())
        .navigationTitle(store.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.send(.anchorDateAdvanced(-1))
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    store.send(.anchorDateAdvanced(1))
                } label: {
                    Image(systemName: "chevron.right")
                }

                Button {
                    store.send(.addTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { store.editor != nil },
                set: { if !$0 { store.send(.editorDismissed) } }
            )
        ) {
            if let editor = store.editor {
                CalendarEditorView(editor: editor, store: store)
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var pickerRow: some View {
        Picker(
            L10n.Calendar.modePickerTitle,
            selection: Binding(
                get: { store.displayMode },
                set: { store.send(.displayModeChanged($0)) }
            )
        ) {
            Text(L10n.Calendar.weekMode).tag(CalendarState.DisplayMode.week)
            Text(L10n.Calendar.monthMode).tag(CalendarState.DisplayMode.month)
        }
        .pickerStyle(.segmented)
    }

    private var datePickerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            DatePicker(
                "",
                selection: Binding(
                    get: { store.anchorDate },
                    set: { store.send(.anchorDateChanged($0)) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)

            Text(rangeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var eventSections: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            ForEach(groupedEvents, id: \.0) { date, events in
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(date.formatted(.dateTime.day().month(.wide)))
                        .font(.title3.weight(.semibold))

                    ForEach(events) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: Event) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(event.title)
                        .font(.body.weight(.semibold))
                    Text(event.type == .reminder ? L10n.Calendar.reminderTag : L10n.Calendar.eventTag)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(timeText(for: event))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if hasConflict(for: event) {
                Label(L10n.ChatSheet.conflict, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(AppSpacing.large)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .contextMenu {
            Button(L10n.Calendar.editEvent) {
                store.send(.editTapped(event.id))
            }
            Button(L10n.Calendar.deleteEvent, role: .destructive) {
                store.send(.deleteTapped(event.id))
            }
        }
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(L10n.Calendar.errorTitle)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(L10n.Home.emptyTodayTitle)
                .font(.headline)

            Text(L10n.Home.emptyTodayBody)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var groupedEvents: [(Date, [Event])] {
        let grouped = Dictionary(grouping: store.events) { Calendar.current.startOfDay(for: $0.startAt) }
        return grouped.keys.sorted().map { ($0, grouped[$0, default: []].sorted { $0.startAt < $1.startAt }) }
    }

    private func hasConflict(for event: Event) -> Bool {
        store.events.contains { other in
            guard other.id != event.id else { return false }
            guard Calendar.current.isDate(other.startAt, inSameDayAs: event.startAt) else { return false }
            let eventEnd = event.endAt ?? event.startAt
            let otherEnd = other.endAt ?? other.startAt
            return other.startAt < eventEnd && otherEnd > event.startAt
        }
    }

    private func timeText(for event: Event) -> String {
        if event.allDay {
            return L10n.Calendar.allDay
        }
        if let endAt = event.endAt {
            return "\(event.startAt.formatted(date: .omitted, time: .shortened)) - \(endAt.formatted(date: .omitted, time: .shortened))"
        }
        return event.startAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var rangeDescription: String {
        let calendar = Calendar.current

        switch store.displayMode {
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: store.anchorDate)
            let start = interval?.start ?? store.anchorDate
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(start.formatted(.dateTime.day().month(.abbreviated))) - \(end.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            return store.anchorDate.formatted(.dateTime.month(.wide).year())
        }
    }
}

private struct CalendarEditorView: View {
    let editor: CalendarState.Editor
    let store: StoreOf<CalendarReducer>

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Calendar.editorDetails) {
                    TextField(
                        L10n.Calendar.titlePlaceholder,
                        text: Binding(
                            get: { store.editor?.title ?? "" },
                            set: { store.send(.editorTitleChanged($0)) }
                        )
                    )

                    TextField(
                        L10n.Calendar.locationPlaceholder,
                        text: Binding(
                            get: { store.editor?.location ?? "" },
                            set: { store.send(.editorLocationChanged($0)) }
                        )
                    )

                    TextField(
                        L10n.Calendar.descriptionPlaceholder,
                        text: Binding(
                            get: { store.editor?.description ?? "" },
                            set: { store.send(.editorDescriptionChanged($0)) }
                        ),
                        axis: .vertical
                    )
                }

                Section(L10n.Calendar.editorTiming) {
                    Picker(
                        L10n.Calendar.typePicker,
                        selection: Binding(
                            get: { store.editor?.type ?? .event },
                            set: { store.send(.editorTypeChanged($0)) }
                        )
                    ) {
                        Text(L10n.Calendar.eventTag).tag(EventKind.event)
                        Text(L10n.Calendar.reminderTag).tag(EventKind.reminder)
                    }

                    Toggle(
                        L10n.Calendar.allDay,
                        isOn: Binding(
                            get: { store.editor?.allDay ?? false },
                            set: { store.send(.editorAllDayChanged($0)) }
                        )
                    )

                    DatePicker(
                        L10n.Calendar.startDate,
                        selection: Binding(
                            get: { store.editor?.startDate ?? editor.startDate },
                            set: { store.send(.editorStartDateChanged($0)) }
                        )
                    )

                    if (store.editor?.type ?? editor.type) == .event && !(store.editor?.allDay ?? editor.allDay) {
                        DatePicker(
                            L10n.Calendar.endDate,
                            selection: Binding(
                                get: { store.editor?.endDate ?? editor.endDate },
                                set: { store.send(.editorEndDateChanged($0)) }
                            )
                        )
                    }
                }
            }
            .navigationTitle(editor.eventID == nil ? L10n.Calendar.newEvent : L10n.Calendar.editEvent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Profile.closeButton) {
                        store.send(.editorDismissed)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Calendar.saveEvent) {
                        store.send(.saveTapped)
                    }
                }
            }
        }
    }
}
