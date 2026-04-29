import SentinelUI
import SentinelCore
import ComposableArchitecture
import SwiftUI

struct CalendarEditorView: View {
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
                    Button {
                        store.send(.editorDismissed)
                    } label: {
                        ToolbarTextLabel(L10n.Profile.closeButton)
                    }
                }

                ToolbarItem(placement: sentinelToolbarTrailingPlacement) {
                    Button {
                        store.send(.saveTapped)
                    } label: {
                        ToolbarTextLabel(L10n.Calendar.saveEvent)
                    }
                }
            }
        }
    }
}
