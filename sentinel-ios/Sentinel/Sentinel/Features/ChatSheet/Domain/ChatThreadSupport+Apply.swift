import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

extension ChatThreadFeature {
    func applySuggestions(state: inout State, messageID: ChatThreadMessage.ID) -> Effect<Action> {
        guard let accessToken = state.accessToken,
              let activeChatID = state.activeChatID,
              let index = state.messages.firstIndex(where: { $0.id == messageID }),
              var payload = state.messages[index].suggestionsPayload,
              let applyPlan = payload.applyingSelectionPlan() else { return .none }

        payload.isApplying = true
        state.messages[index].suggestionsPayload = payload
        state.errorMessage = nil

        return .run { [calendarSyncClient, chatClient, eventsClient] send in
            do {
                let updatedMessage = try await chatClient.applyActions(activeChatID, messageID, applyPlan.acceptedIndices, accessToken)
                var canonicalEventsByID: [UUID: Event] = [:]

                if let syncRange = applyPlan.syncRange {
                    let rangedEvents = try await eventsClient.listEvents(syncRange.lowerBound, syncRange.upperBound, accessToken)
                    canonicalEventsByID = Dictionary(uniqueKeysWithValues: rangedEvents.map { ($0.id, $0) })
                }

                for eventID in applyPlan.upsertEventIDs where !canonicalEventsByID.keys.contains(eventID) {
                    canonicalEventsByID[eventID] = try await eventsClient.getEvent(eventID, accessToken)
                }

                if !canonicalEventsByID.isEmpty || !applyPlan.deletedEventIDs.isEmpty {
                    _ = try await calendarSyncClient.sync(.init(deletedEventIDs: applyPlan.deletedEventIDs, events: Array(canonicalEventsByID.values)))
                }

                await send(.suggestionApplyCompleted(messageID: messageID, updatedMessage: updatedMessage, requestToken: accessToken))
            } catch {
                await send(.suggestionApplyFailed(messageID: messageID, message: Self.errorMessage(for: error), requestToken: accessToken))
            }
        }
    }
}
