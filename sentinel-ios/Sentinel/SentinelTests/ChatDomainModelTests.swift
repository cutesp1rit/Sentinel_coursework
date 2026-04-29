import SentinelUI
import SentinelCore
import Foundation
import SwiftUI
import Testing
@testable import Sentinel

@MainActor
struct ChatDomainModelTests {
    @Test
    func chatDomainModelsCoverAttachmentAndListPresentation() {
        let remoteAttachment = ChatImageAttachment(
            url: "https://example.com/image.jpg",
            filename: "image.jpg",
            localData: nil,
            mimeType: "image/jpeg",
            previewData: nil
        )
        let localAttachment = ChatImageAttachment(
            url: "",
            filename: "local.png",
            localData: Data([0x01]),
            mimeType: "image/png",
            previewData: Data([0x01])
        )
        #expect(remoteAttachment.id == "https://example.com/image.jpg")
        #expect(localAttachment.id == "local-local.png")

        let emptyContent = ChatMessage.Content(markdownText: nil, eventActions: nil, images: [])
        #expect(emptyContent.isEmpty)
        #expect(!ChatMessage.Content(markdownText: "Body", eventActions: nil, images: []).isEmpty)

        let item = ChatListItem(chat: Fixture.chat())
        #expect(item.id == Fixture.chatID)
        #expect(item.title == "Today")
        #expect(item.subtitle?.isEmpty == false)

        let composer = ChatComposerAttachment(
            data: Data([0x02]),
            previewData: nil,
            filename: "local.png",
            mimeType: "image/png"
        )
        #expect(composer.imageAttachment.previewData == Data([0x02]))
    }

    @Test
    func chatSuggestionBuildsFallbackTitlesTimesAndStatus() {
        let create = ChatSuggestion(
            actionIndex: 0,
            action: Fixture.eventAction(kind: .create, eventId: nil, title: "", location: "", status: .pending)
        )
        #expect(create.id == "proposal-0")
        #expect(create.title == "Existing")
        #expect(create.location == "Create proposal")
        #expect(create.statusText == nil)
        #expect(!String(describing: create.statusTint).isEmpty)

        let update = ChatSuggestion(
            actionIndex: 2,
            action: Fixture.eventAction(
                kind: .update,
                eventId: Fixture.eventID,
                title: "Update Planning",
                location: "Office",
                startAt: Fixture.referenceDate,
                endAt: Fixture.secondaryDate,
                status: .accepted
            )
        )
        #expect(update.id == "event-\(Fixture.eventID.uuidString)-2")
        #expect(update.title == "Update Planning")
        #expect(update.location == "Office")
        #expect(update.statusText == L10n.ChatSheet.statusAccepted)
        #expect(update.timeRange.contains("-"))

        let delete = ChatSuggestion(
            actionIndex: 1,
            action: EventAction(
                action: .delete,
                eventId: Fixture.secondEventID,
                payload: nil,
                status: .rejected,
                eventSnapshot: EventAction.Snapshot(
                    title: "Existing Snapshot",
                    startAt: Fixture.referenceDate,
                    endAt: nil
                )
            )
        )
        #expect(delete.title == "Existing Snapshot")
        #expect(delete.location == "Existing Snapshot")
        #expect(delete.statusText == L10n.ChatSheet.statusRejected)
        #expect(!String(describing: delete.statusTint).isEmpty)
    }

    @Test
    func chatThreadMessageBuildsFromPlainTextAndStructuredActions() {
        let textMessage = ChatThreadMessage(role: .user, text: "Hello", images: [])
        #expect(textMessage.isUser)
        #expect(textMessage.hasBubbleContent)
        #expect(textMessage.suggestionsPayload == nil)

        let structured = ChatThreadMessage(
            chatMessage: Fixture.chatMessage(
                markdownText: "Body",
                actions: [
                    Fixture.eventAction(kind: .create, eventId: nil, title: "Plan A"),
                    Fixture.eventAction(kind: .update, eventId: Fixture.eventID, title: "Plan B")
                ],
                images: [
                    ChatImageAttachment(
                        url: "https://example.com/image.jpg",
                        filename: "image.jpg",
                        localData: nil,
                        mimeType: "image/jpeg",
                        previewData: nil
                    )
                ]
            )
        )
        #expect(structured.role == .assistant)
        #expect(structured.images.count == 1)
        #expect(structured.suggestionsPayload?.suggestions.count == 2)
        #expect(structured.hasBubbleContent)
    }

    @Test
    func suggestionsPayloadTracksSelectionAndApplyPlan() throws {
        let create = ChatSuggestion(
            actionIndex: 0,
            action: Fixture.eventAction(kind: .create, eventId: nil, title: "Create")
        )
        let update = ChatSuggestion(
            actionIndex: 1,
            action: Fixture.eventAction(kind: .update, eventId: Fixture.eventID, title: "Update")
        )
        let delete = ChatSuggestion(
            actionIndex: 2,
            action: EventAction(
                action: .delete,
                eventId: Fixture.secondEventID,
                payload: nil,
                status: .pending,
                eventSnapshot: EventAction.Snapshot(
                    title: "Delete",
                    startAt: Fixture.secondaryDate,
                    endAt: nil
                )
            )
        )

        var payload = ChatThreadMessage.SuggestionsPayload(suggestions: [create, update, delete])
        payload.selectedSuggestionIDs = [update.id, delete.id]

        #expect(payload.isSelected(update.id))
        #expect(payload.selectedPendingCount == 2)
        #expect(!payload.isSingleSuggestion)
        #expect(payload.addToCalendarTitle == L10n.ChatSheet.addCountToCalendar(2))
        #expect(payload.canAddToCalendar)
        #expect(payload.hasPendingSuggestions)
        #expect(payload.conflictDrafts.count == 3)

        let plan = try #require(payload.applyingSelectionPlan())
        #expect(plan.acceptedIndices == [1, 2])
        #expect(plan.deletedEventIDs == [Fixture.secondEventID])
        #expect(plan.upsertEventIDs == [Fixture.eventID])
        #expect(plan.syncRange?.lowerBound == Fixture.referenceDate)
        #expect(plan.syncRange?.upperBound == Fixture.secondaryDate)

        let updatedPayload = payload.updatingConflicts([
            create.id: true,
            update.id: false
        ])
        #expect(updatedPayload.suggestions[0].hasConflict)
        #expect(updatedPayload.suggestions[1].hasConflict == false)

        let autoApply = ChatThreadMessage.SuggestionsPayload(suggestions: [create])
        #expect(autoApply.applyingSelectionPlan()?.acceptedIndices == [0])

        let noPending = ChatThreadMessage.SuggestionsPayload(
            suggestions: [
                ChatSuggestion(
                    actionIndex: 0,
                    action: Fixture.eventAction(kind: .create, eventId: nil, title: "Done", status: .accepted)
                )
            ]
        )
        #expect(noPending.hasPendingSuggestions == false)
        #expect(noPending.canAddToCalendar == false)
        #expect(noPending.addToCalendarTitle == L10n.ChatSheet.applied)
    }

    @Test
    func messageSpacingVariesByNeighborRole() {
        let messages: [ChatThreadMessage] = [
            ChatThreadMessage(role: .user, text: "One"),
            ChatThreadMessage(role: .user, text: "Two"),
            ChatThreadMessage(role: .assistant, text: "Three")
        ]

        #expect(messages.spacing(after: 0) == AppSpacing.small)
        #expect(messages.spacing(after: 1) == AppSpacing.medium)
        #expect(messages.spacing(after: 2) == 0)
    }
}
