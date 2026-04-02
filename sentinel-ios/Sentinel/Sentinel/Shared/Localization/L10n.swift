import Foundation

enum L10n {
    enum App {
        static let navigationTitle = String(localized: "app.navigation_title")
        static let title = String(localized: "app.title")
    }

    enum Home {
        static let subtitle = String(localized: "home.subtitle")
        static let localStatus = String(localized: "home.local_status")
        static let todaySnapshotTitle = String(localized: "home.today_snapshot_title")
        static let eventsTitle = String(localized: "home.events_title")
        static let calendarTitle = String(localized: "home.calendar_title")
        static let batteryTitle = String(localized: "home.battery_title")
        static let actionsTitle = String(localized: "home.actions_title")
        static let connectCalendarTitle = String(localized: "home.connect_calendar_title")
        static let connectCalendarBody = String(localized: "home.connect_calendar_body")
        static let loadingTitle = String(localized: "home.loading_title")
        static let loadingBody = String(localized: "home.loading_body")
        static let noEventsTitle = String(localized: "home.no_events_title")
        static let noEventsBody = String(localized: "home.no_events_body")
        static let calendarDeniedTitle = String(localized: "home.calendar_denied_title")
        static let calendarDeniedBody = String(localized: "home.calendar_denied_body")
        static let calendarErrorTitle = String(localized: "home.calendar_error_title")
        static let calendarErrorBody = String(localized: "home.calendar_error_body")
        static let calendarPreviewBody = String(localized: "home.calendar_preview_body")
        static let todaySummaryBody = String(localized: "home.today_summary_body")
        static let noEventsToday = String(localized: "home.no_events_today")
        static let noEventsTodayBody = String(localized: "home.no_events_today_body")
        static let batteryPlaceholderTitle = String(localized: "home.battery_placeholder_title")
        static let batteryPlaceholderBody = String(localized: "home.battery_placeholder_body")
        static let batteryUnavailableTitle = String(localized: "home.battery_unavailable_title")
        static let batteryUnavailableBody = String(localized: "home.battery_unavailable_body")
        static let chatTitle = String(localized: "home.chat_title")
        static let chatBody = String(localized: "home.chat_body")
        static let rebalanceTitle = String(localized: "home.rebalance_title")
        static let rebalanceBody = String(localized: "home.rebalance_body")
    }

    enum ChatSheet {
        static let addAttachmentAccessibility = String(localized: "chat_sheet.add_attachment_accessibility")
        static let composerPlaceholder = String(localized: "chat_sheet.composer_placeholder")
        static let sendMessageAccessibility = String(localized: "chat_sheet.send_message_accessibility")
        static let suggestedEvents = String(localized: "chat_sheet.suggested_events")
        static let conflict = String(localized: "chat_sheet.conflict")
        static let addToCalendar = String(localized: "chat_sheet.add_to_calendar")

        static func selectedCount(_ count: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "chat_sheet.selected_count_format"),
                count
            )
        }

        static func addCountToCalendar(_ count: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "chat_sheet.add_count_to_calendar_format"),
                count
            )
        }

        enum Mock {
            static let suggestionOneTitle = String(localized: "chat_sheet.mock.suggestion_one.title")
            static let suggestionOneTimeRange = String(localized: "chat_sheet.mock.suggestion_one.time_range")
            static let suggestionOneLocation = String(localized: "chat_sheet.mock.suggestion_one.location")

            static let suggestionTwoTitle = String(localized: "chat_sheet.mock.suggestion_two.title")
            static let suggestionTwoTimeRange = String(localized: "chat_sheet.mock.suggestion_two.time_range")
            static let suggestionTwoLocation = String(localized: "chat_sheet.mock.suggestion_two.location")

            static let suggestionThreeTitle = String(localized: "chat_sheet.mock.suggestion_three.title")
            static let suggestionThreeTimeRange = String(localized: "chat_sheet.mock.suggestion_three.time_range")
            static let suggestionThreeLocation = String(localized: "chat_sheet.mock.suggestion_three.location")

            static let messageOne = String(localized: "chat_sheet.mock.message_one")
            static let messageTwo = String(localized: "chat_sheet.mock.message_two")
            static let messageThree = String(localized: "chat_sheet.mock.message_three")
        }
    }

    enum Profile {
        static let authHint = String(localized: "profile.auth_hint")
        static let closeButton = String(localized: "profile.close_button")
        static let emailInvalid = String(localized: "profile.email_invalid")
        static let emailPlaceholder = String(localized: "profile.email_placeholder")
        static let emailRequired = String(localized: "profile.email_required")
        static let loggedOutStatus = String(localized: "profile.logged_out_status")
        static let loginButton = String(localized: "profile.login_button")
        static let loginMode = String(localized: "profile.login_mode")
        static let logoutButton = String(localized: "profile.logout_button")
        static let logoutHint = String(localized: "profile.logout_hint")
        static let modePickerLabel = String(localized: "profile.mode_picker_label")
        static let openButton = String(localized: "profile.open_button")
        static let passwordPlaceholder = String(localized: "profile.password_placeholder")
        static let passwordRequired = String(localized: "profile.password_required")
        static let registerButton = String(localized: "profile.register_button")
        static let registerMode = String(localized: "profile.register_mode")
        static let restoringStatus = String(localized: "profile.restoring_status")
        static let sessionStoredBody = String(localized: "profile.session_stored_body")
        static let signedInStatus = String(localized: "profile.signed_in_status")
        static let signedInTitle = String(localized: "profile.signed_in_title")
        static let signedOutBody = String(localized: "profile.signed_out_body")
        static let signedOutTitle = String(localized: "profile.signed_out_title")
        static let title = String(localized: "profile.title")
    }
}
