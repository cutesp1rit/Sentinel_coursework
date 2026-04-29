import SentinelUI
import SentinelCore
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

                    CalendarMonthPickerSectionView(
                        isInlineMonthPickerVisible: store.isInlineMonthPickerVisible,
                        selectedDate: store.selectedDate,
                        selectedMonthLabel: store.selectedMonthLabel,
                        onToggle: {
                            store.send(.inlineMonthPickerVisibilityChanged(!store.isInlineMonthPickerVisible))
                        },
                        onSelectDate: { store.send(.selectedDateChanged($0)) }
                    )

                    if let errorMessage = store.errorMessage {
                        EmptyStateCard(title: L10n.Calendar.errorTitle, bodyText: errorMessage)
                    }

                    if store.isLoading && store.events.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xLarge)
                    } else {
                        ForEach(store.agendaSections) { section in
                            CalendarAgendaSectionView(
                                section: section,
                                selectedDate: store.selectedDate,
                                batteryState: store.state.dayBatteryState(for: section.id),
                                onBatteryRequested: { store.send(.dayBatteryRequested(section.id)) },
                                onDelete: { store.send(.deleteTapped($0)) },
                                onEdit: { store.send(.editTapped($0)) },
                                onVisibleDateChanged: { store.send(.visibleDateChanged($0)) }
                            )
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
