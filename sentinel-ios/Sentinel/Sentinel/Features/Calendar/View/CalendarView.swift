import ComposableArchitecture
import SwiftUI

struct CalendarView: View {
    let store: StoreOf<CalendarReducer>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                WeekStrip(
                    days: weekStripDays,
                    onSelect: { store.send(.selectedDateChanged($0)) },
                    onSwipe: { store.send(.weekAdvanced($0)) }
                )

                Button {
                    store.send(.monthPickerPresentationChanged(true))
                } label: {
                    HStack {
                        Text(store.selectedMonthLabel.capitalized)
                            .font(.headline.weight(.semibold))

                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if let errorMessage = store.errorMessage {
                    EmptyStateCard(title: L10n.Calendar.errorTitle, bodyText: errorMessage)
                }

                if store.isLoading && store.events.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xLarge)
                } else {
                    agendaContent
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(HomeTopGradientBackground().ignoresSafeArea())
        .navigationTitle(store.navigationTitle)
        .sentinelLargeNavigationTitle()
        .toolbar {
            ToolbarItem(placement: sentinelToolbarTrailingPlacement) {
                Button {
                    store.send(.addTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { store.isMonthPickerPresented },
                set: { store.send(.monthPickerPresentationChanged($0)) }
            )
        ) {
            MonthPicker(
                selectedDate: Binding(
                    get: { store.selectedDate },
                    set: { store.send(.selectedDateChanged($0)) }
                )
            )
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

    private var agendaContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AgendaDayHeader(
                title: dayHeaderTitle(for: store.selectedDate),
                subtitle: store.selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
            )

            if selectedDayEvents.isEmpty {
                EmptyStateCard(
                    title: L10n.Calendar.emptySelectedDayTitle,
                    bodyText: L10n.Calendar.emptySelectedDayBody
                )
            } else {
                VStack(spacing: AppSpacing.medium) {
                    ForEach(selectedDayEvents) { event in
                        eventRow(event)
                    }
                }
            }

            if !upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(L10n.Calendar.upcomingTitle)
                        .font(.headline)

                    ForEach(upcomingEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: Event) -> some View {
        EventRowCard(
            title: event.title,
            badge: event.type == .reminder ? L10n.Calendar.reminderTag : L10n.Calendar.eventTag,
            time: timeText(for: event),
            location: event.location,
            conflictTitle: hasConflict(for: event) ? L10n.ChatSheet.conflict : nil
        ) {
            store.send(.editTapped(event.id))
        }
        .contextMenu {
            Button(L10n.Calendar.editEvent) {
                store.send(.editTapped(event.id))
            }
            Button(L10n.Calendar.deleteEvent, role: .destructive) {
                store.send(.deleteTapped(event.id))
            }
        }
    }

    private var weekStripDays: [WeekStripDay] {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: store.selectedDate)
        let startOfWeek = weekInterval?.start ?? store.selectedDate

        return (0 ..< 7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else {
                return nil
            }

            return WeekStripDay(
                id: date.formatted(.iso8601.year().month().day()),
                date: date,
                weekday: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: date.formatted(.dateTime.day()),
                isSelected: calendar.isDate(date, inSameDayAs: store.selectedDate),
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private var selectedDayEvents: [Event] {
        let calendar = Calendar.current
        return store.events
            .filter { calendar.isDate($0.startAt, inSameDayAs: store.selectedDate) }
            .sorted { $0.startAt < $1.startAt }
    }

    private var upcomingEvents: [Event] {
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: store.selectedDate)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedStart) ?? selectedStart

        return store.events
            .filter { $0.startAt >= nextDay }
            .sorted { $0.startAt < $1.startAt }
            .prefix(4)
            .map { $0 }
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

    private func dayHeaderTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Calendar.today
        }
        if calendar.isDateInTomorrow(date) {
            return L10n.Calendar.tomorrow
        }
        return date.formatted(.dateTime.day().month(.wide))
    }

    private func timeText(for event: Event) -> String {
        if event.allDay {
            return L10n.Calendar.allDay
        }
        if let endAt = event.endAt {
            return "\(event.startAt.formatted(date: .omitted, time: .shortened)) - \(endAt.formatted(date: .omitted, time: .shortened))"
        }
        if event.type == .reminder {
            return event.startAt.formatted(date: .omitted, time: .shortened)
        }
        return event.startAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct MonthPicker: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.large) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                PrimaryButton(L10n.Profile.closeButton) {
                    dismiss()
                }
            }
            .padding(AppSpacing.large)
            .navigationTitle(L10n.Calendar.selectMonth)
            .sentinelInlineNavigationTitle()
        }
        .presentationDetents([.medium])
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
            .sentinelInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: sentinelToolbarLeadingPlacement) {
                    Button(L10n.Profile.closeButton) {
                        store.send(.editorDismissed)
                    }
                }

                ToolbarItem(placement: sentinelToolbarTrailingPlacement) {
                    Button(L10n.Calendar.saveEvent) {
                        store.send(.saveTapped)
                    }
                }
            }
        }
    }
}
