import ComposableArchitecture
import SwiftUI

struct CalendarView: View {
    let store: StoreOf<CalendarReducer>

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.large, pinnedViews: [.sectionHeaders]) {
                    WeekStrip(
                        days: store.weekStripDays,
                        onSelect: { store.send(.selectedDateChanged($0)) },
                        onSwipe: { store.send(.weekAdvanced($0)) }
                    )
                    .padding(.top, AppSpacing.xLarge)

                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Button {
                            store.send(.inlineMonthPickerVisibilityChanged(!store.isInlineMonthPickerVisible))
                        } label: {
                            HStack {
                                Text(store.selectedMonthLabel.capitalized)
                                    .font(.headline.weight(.semibold))
                                Image(systemName: store.isInlineMonthPickerVisible ? "chevron.up" : "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        if store.isInlineMonthPickerVisible {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { store.selectedDate },
                                    set: { store.send(.selectedDateChanged($0)) }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                        }
                    }

                    if let errorMessage = store.errorMessage {
                        EmptyStateCard(title: L10n.Calendar.errorTitle, bodyText: errorMessage)
                    }

                    if store.isLoading && store.events.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xLarge)
                    } else {
                        ForEach(store.agendaSections) { section in
                            Section {
                                VStack(spacing: AppSpacing.medium) {
                                    if section.rows.isEmpty {
                                        if Calendar.current.isDate(section.date, inSameDayAs: store.selectedDate) {
                                            EmptyStateCard(
                                                title: L10n.Calendar.emptySelectedDayTitle,
                                                bodyText: L10n.Calendar.emptySelectedDayBody
                                            )
                                        } else {
                                            Color.clear
                                                .frame(height: AppSpacing.small)
                                        }
                                    } else {
                                        ForEach(section.rows) { row in
                                            EventRowCard(
                                                title: row.title,
                                                badge: row.badge,
                                                isFixed: row.isFixed,
                                                time: row.time,
                                                location: row.location,
                                                conflictTitle: row.conflictTitle
                                            ) {
                                                store.send(.editTapped(row.id))
                                            }
                                            .contextMenu {
                                                Button(L10n.Calendar.editEvent) {
                                                    store.send(.editTapped(row.id))
                                                }
                                                Button(L10n.Calendar.deleteEvent, role: .destructive) {
                                                    store.send(.deleteTapped(row.id))
                                                }
                                            }
                                        }
                                    }
                                }
                                .onAppear {
                                    store.send(.visibleDateChanged(section.date))
                                }
                            } header: {
                                AgendaDayHeader(
                                    title: section.title,
                                    subtitle: section.subtitle
                                )
                                .id(section.id)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: CalendarSectionOffsetKey.self,
                                            value: [section.id: proxy.frame(in: .named("calendarScroll")).minY]
                                        )
                                    }
                                )
                                .padding(.top, AppSpacing.small)
                                .padding(.bottom, AppSpacing.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.xLarge)
            }
            .coordinateSpace(name: "calendarScroll")
            .onChange(of: store.pendingScrollSectionID) { _, sectionID in
                guard let sectionID else { return }
                withAnimation(.snappy(duration: AppAnimationDuration.settle)) {
                    scrollProxy.scrollTo(sectionID, anchor: .top)
                }
            }
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
        .onPreferenceChange(CalendarSectionOffsetKey.self) { offsets in
            if let visibleDate = store.state.visibleSectionDate(for: offsets) {
                store.send(.visibleDateChanged(visibleDate))
            }
        }
    }
}

private struct CalendarSectionOffsetKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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

                    Toggle(
                        L10n.Calendar.fixedEvent,
                        isOn: Binding(
                            get: { store.editor?.isFixed ?? false },
                            set: { store.send(.editorFixedChanged($0)) }
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
