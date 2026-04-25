import Foundation

enum L10n {
    enum App {
        static let navigationTitle = String(localized: "app.navigation_title")
        static let title = String(localized: "app.title")
    }

    enum Home {
        static let achievementsRailTitle = String(localized: "home.achievements_rail_title")
        static let allEventsBody = String(localized: "home.all_events_body")
        static let allEventsTitle = String(localized: "home.all_events_title")
        static let subtitle = String(localized: "home.subtitle")
        static let emptyTodayBody = String(localized: "home.empty_today_body")
        static let emptyTodayTitle = String(localized: "home.empty_today_title")
        static let heroTitle = String(localized: "home.hero_title")
        static let localStatus = String(localized: "home.local_status")
        static let metricBatteryTitle = String(localized: "home.metric_battery_title")
        static let metricFreeValue = String(localized: "home.metric_free_value")
        static let metricNextValue = String(localized: "home.metric_next_value")
        static let metricTodayTitle = String(localized: "home.metric_today_title")
        static let todaySnapshotTitle = String(localized: "home.today_snapshot_title")
        static let todaySectionTitle = String(localized: "home.today_section_title")
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
        static let rebalanceButton = String(localized: "home.rebalance_button")
        static let signInButton = String(localized: "home.sign_in_button")
        static let signedOutCardOneBody = String(localized: "home.signed_out_card_one_body")
        static let signedOutCardOneTitle = String(localized: "home.signed_out_card_one_title")
        static let signedOutCardTwoBody = String(localized: "home.signed_out_card_two_body")
        static let signedOutCardTwoTitle = String(localized: "home.signed_out_card_two_title")
        static let signedOutHeroBody = String(localized: "home.signed_out_hero_body")
        static let signedOutHeroEyebrow = String(localized: "home.signed_out_hero_eyebrow")
        static let signedOutHeroTitle = String(localized: "home.signed_out_hero_title")
        static let viewAllButton = String(localized: "home.view_all_button")

        static func heroSubtitle(_ name: String) -> String {
            String.localizedStringWithFormat(
                String(localized: "home.hero_subtitle_format"),
                name
            )
        }

        static func todayCount(_ count: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "home.today_count_format"),
                count
            )
        }
    }

    enum ChatSheet {
        static let addAttachmentAccessibility = String(localized: "chat_sheet.add_attachment_accessibility")
        static let attachmentLimitReached = String(localized: "chat_sheet.attachment_limit_reached")
        static let attachmentTooLarge = String(localized: "chat_sheet.attachment_too_large")
        static let composerPlaceholder = String(localized: "chat_sheet.composer_placeholder")
        static let deleteChat = String(localized: "chat_sheet.delete_chat")
        static let authRequiredBody = String(localized: "chat_sheet.auth_required_body")
        static let authRequiredTitle = String(localized: "chat_sheet.auth_required_title")
        static let errorTitle = String(localized: "chat_sheet.error_title")
        static let historyButtonAccessibility = String(localized: "chat_sheet.history_button_accessibility")
        static let historyTitle = String(localized: "chat_sheet.history_title")
        static let loadEarlierMessages = String(localized: "chat_sheet.load_earlier_messages")
        static let loadingChats = String(localized: "chat_sheet.loading_chats")
        static let loadingMessages = String(localized: "chat_sheet.loading_messages")
        static let newChat = String(localized: "chat_sheet.new_chat")
        static let noChatsBody = String(localized: "chat_sheet.no_chats_body")
        static let noChatsTitle = String(localized: "chat_sheet.no_chats_title")
        static let noMessagesBody = String(localized: "chat_sheet.no_messages_body")
        static let noMessagesTitle = String(localized: "chat_sheet.no_messages_title")
        static let removeAttachmentAccessibility = String(localized: "chat_sheet.remove_attachment_accessibility")
        static let retry = String(localized: "chat_sheet.retry")
        static let sendMessageAccessibility = String(localized: "chat_sheet.send_message_accessibility")
        static let selectedImages = String(localized: "chat_sheet.selected_images")
        static let suggestedEvents = String(localized: "chat_sheet.suggested_events")
        static let thinking = String(localized: "chat_sheet.thinking")
        static let conflict = String(localized: "chat_sheet.conflict")
        static let addToCalendar = String(localized: "chat_sheet.add_to_calendar")
        static let applied = String(localized: "chat_sheet.applied")
        static let syncingToCalendar = String(localized: "chat_sheet.syncing_to_calendar")
        static let statusAccepted = String(localized: "chat_sheet.status.accepted")
        static let statusRejected = String(localized: "chat_sheet.status.rejected")

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
        static let accountDeletedStatus = String(localized: "profile.account_deleted_status")
        static let authHint = String(localized: "profile.auth_hint")
        static let backToSignInButton = String(localized: "profile.back_to_sign_in_button")
        static let backToEmailButton = String(localized: "profile.back_to_email_button")
        static let cancelButton = String(localized: "profile.cancel_button")
        static let closeButton = String(localized: "profile.close_button")
        static let confirmPasswordPlaceholder = String(localized: "profile.confirm_password_placeholder")
        static let confirmPasswordRequired = String(localized: "profile.confirm_password_required")
        static let continueButton = String(localized: "profile.continue_button")
        static let deleteAccountBody = String(localized: "profile.delete_account_body")
        static let deleteAccountButton = String(localized: "profile.delete_account_button")
        static let deleteAccountConfirmButton = String(localized: "profile.delete_account_confirm_button")
        static let deleteAccountPasswordPlaceholder = String(localized: "profile.delete_account_password_placeholder")
        static let deleteAccountPasswordRequired = String(localized: "profile.delete_account_password_required")
        static let emailInvalid = String(localized: "profile.email_invalid")
        static let emailPlaceholder = String(localized: "profile.email_placeholder")
        static let emailRequired = String(localized: "profile.email_required")
        static let emailVerifiedStatus = String(localized: "profile.email_verified_status")
        static let forgotPasswordButton = String(localized: "profile.forgot_password_button")
        static let forgotPasswordBody = String(localized: "profile.forgot_password_body")
        static let forgotPasswordTitle = String(localized: "profile.forgot_password_title")
        static let loggedOutStatus = String(localized: "profile.logged_out_status")
        static let loginButton = String(localized: "profile.login_button")
        static let loginMode = String(localized: "profile.login_mode")
        static let logoutButton = String(localized: "profile.logout_button")
        static let logoutHint = String(localized: "profile.logout_hint")
        static let manualResetHint = String(localized: "profile.manual_reset_hint")
        static let manualVerificationHint = String(localized: "profile.manual_verification_hint")
        static let modePickerLabel = String(localized: "profile.mode_picker_label")
        static let newPasswordPlaceholder = String(localized: "profile.new_password_placeholder")
        static let openButton = String(localized: "profile.open_button")
        static let passwordPlaceholder = String(localized: "profile.password_placeholder")
        static let passwordResetEmailSent = String(localized: "profile.password_reset_email_sent")
        static let passwordResetSucceeded = String(localized: "profile.password_reset_succeeded")
        static let passwordRequired = String(localized: "profile.password_required")
        static let passwordsDoNotMatch = String(localized: "profile.passwords_do_not_match")
        static let passwordTooShort = String(localized: "profile.password_too_short")
        static let registerEmailStepBody = String(localized: "profile.register_email_step_body")
        static let registerEmailStepTitle = String(localized: "profile.register_email_step_title")
        static let registerButton = String(localized: "profile.register_button")
        static let registerMode = String(localized: "profile.register_mode")
        static let registerPasswordStepTitle = String(localized: "profile.register_password_step_title")
        static let resendVerificationButton = String(localized: "profile.resend_verification_button")
        static let resetPasswordButton = String(localized: "profile.reset_password_button")
        static let resetTokenPlaceholder = String(localized: "profile.reset_token_placeholder")
        static let resetTokenRequired = String(localized: "profile.reset_token_required")
        static let restoringStatus = String(localized: "profile.restoring_status")
        static let sendResetLinkButton = String(localized: "profile.send_reset_link_button")
        static let sessionStoredBody = String(localized: "profile.session_stored_body")
        static let signedInStatus = String(localized: "profile.signed_in_status")
        static let signedInTitle = String(localized: "profile.signed_in_title")
        static let signedOutBody = String(localized: "profile.signed_out_body")
        static let signedOutTitle = String(localized: "profile.signed_out_title")
        static let title = String(localized: "profile.title")
        static let trySignInAgainButton = String(localized: "profile.try_sign_in_again_button")
        static let verificationTokenPlaceholder = String(localized: "profile.verification_token_placeholder")
        static let verificationEmailResent = String(localized: "profile.verification_email_resent")
        static let verificationRequiredStatus = String(localized: "profile.verification_required_status")
        static let verificationRequiredTitle = String(localized: "profile.verification_required_title")
        static let verificationTokenRequired = String(localized: "profile.verification_token_required")
        static let verifyEmailButton = String(localized: "profile.verify_email_button")

        static func verificationRequiredBody(_ email: String) -> String {
            String.localizedStringWithFormat(
                String(localized: "profile.verification_required_body_format"),
                email
            )
        }

        static func verificationPendingBody(_ email: String) -> String {
            String.localizedStringWithFormat(
                String(localized: "profile.verification_pending_body_format"),
                email
            )
        }
    }

    enum Settings {
        static let achievements = String(localized: "settings.achievements")
        static let authStatus = String(localized: "settings.auth_status")
        static let defaultPromptFooter = String(localized: "settings.default_prompt_footer")
        static let defaultPromptTitle = String(localized: "settings.default_prompt_title")
        static let logout = String(localized: "settings.logout")
        static let notificationsDenied = String(localized: "settings.notifications_denied")
        static let notificationsEnabled = String(localized: "settings.notifications_enabled")
        static let notificationsTitle = String(localized: "settings.notifications_title")
        static let savePromptButton = String(localized: "settings.save_prompt_button")
        static let savedStatus = String(localized: "settings.saved_status")
        static let title = String(localized: "settings.title")
    }

    enum Calendar {
        static let allDay = String(localized: "calendar.all_day")
        static let deleteEvent = String(localized: "calendar.delete_event")
        static let descriptionPlaceholder = String(localized: "calendar.description_placeholder")
        static let editorDetails = String(localized: "calendar.editor_details")
        static let editorTiming = String(localized: "calendar.editor_timing")
        static let editEvent = String(localized: "calendar.edit_event")
        static let endDate = String(localized: "calendar.end_date")
        static let errorTitle = String(localized: "calendar.error_title")
        static let eventTag = String(localized: "calendar.event_tag")
        static let locationPlaceholder = String(localized: "calendar.location_placeholder")
        static let modePickerTitle = String(localized: "calendar.mode_picker_title")
        static let monthMode = String(localized: "calendar.month_mode")
        static let monthTitle = String(localized: "calendar.month_title")
        static let newEvent = String(localized: "calendar.new_event")
        static let reminderTag = String(localized: "calendar.reminder_tag")
        static let saveEvent = String(localized: "calendar.save_event")
        static let startDate = String(localized: "calendar.start_date")
        static let titlePlaceholder = String(localized: "calendar.title_placeholder")
        static let titleRequired = String(localized: "calendar.title_required")
        static let typePicker = String(localized: "calendar.type_picker")
        static let weekMode = String(localized: "calendar.week_mode")
        static let weekTitle = String(localized: "calendar.week_title")
    }

    enum Achievements {
        static let title = String(localized: "achievements.title")
        static let summaryTitle = String(localized: "achievements.summary_title")
        static let loading = String(localized: "achievements.loading")
        static let errorTitle = String(localized: "achievements.error_title")
        static let emptyTitle = String(localized: "achievements.empty_title")
        static let emptyBody = String(localized: "achievements.empty_body")
        static let completedGroup = String(localized: "achievements.completed_group")
        static let unlocked = String(localized: "achievements.unlocked")
        static let eventsCreated = String(localized: "achievements.group.events_created")
        static let aiAssisted = String(localized: "achievements.group.ai_assisted")
        static let reminders = String(localized: "achievements.group.reminders")
        static let activeDays = String(localized: "achievements.group.active_days")

        static func earnedAt(_ date: String) -> String {
            String.localizedStringWithFormat(
                String(localized: "achievements.earned_at_format"),
                date
            )
        }

        static func level(_ level: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "achievements.level_format"),
                level
            )
        }

        static func progressToLevel(_ current: Int, _ target: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "achievements.progress_to_level_format"),
                current,
                target
            )
        }

        static func summaryBody(_ unlocked: Int, _ total: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "achievements.summary_body_format"),
                unlocked,
                total
            )
        }

        static func target(_ target: Int) -> String {
            String.localizedStringWithFormat(
                String(localized: "achievements.target_format"),
                target
            )
        }
    }
}
