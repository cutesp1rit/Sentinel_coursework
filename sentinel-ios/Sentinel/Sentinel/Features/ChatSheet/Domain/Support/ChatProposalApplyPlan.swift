import Foundation

struct ChatProposalApplyPlan: Equatable {
    let acceptedIndices: [Int]
    let deletedEventIDs: Set<UUID>
    let syncRange: ClosedRange<Date>?
    let upsertEventIDs: Set<UUID>
}

extension ChatThreadMessage.SuggestionsPayload {
    var conflictDrafts: [CalendarSyncClient.Draft] {
        suggestions.compactMap { suggestion in
            guard suggestion.status == .pending, let startAt = suggestion.startAt else {
                return nil
            }
            return CalendarSyncClient.Draft(
                id: suggestion.id,
                allDay: suggestion.allDay,
                endAt: suggestion.endAt,
                eventKind: suggestion.eventKind,
                existingServerEventID: suggestion.eventId,
                startAt: startAt,
                title: suggestion.title
            )
        }
    }

    var hasPendingSuggestions: Bool {
        suggestions.contains(where: { $0.status == .pending })
    }

    func applyingSelectionPlan() -> ChatProposalApplyPlan? {
        let pendingSuggestions = suggestions.filter { $0.status == .pending }
        let acceptedSuggestions: [ChatSuggestion] = pendingSuggestions.count == 1
            ? pendingSuggestions
            : suggestions.filter { selectedSuggestionIDs.contains($0.id) && $0.status == .pending }

        let acceptedIndices = acceptedSuggestions.map(\.actionIndex).sorted()
        guard !acceptedIndices.isEmpty else { return nil }

        let datedSuggestions = acceptedSuggestions.filter { $0.action != .delete }
        let startDates = datedSuggestions.compactMap(\.startAt)
        let endDates = datedSuggestions.compactMap { $0.endAt ?? $0.startAt }
        let syncRange: ClosedRange<Date>? = {
            guard let earliestStart = startDates.min(), let latestEnd = endDates.max() else { return nil }
            return earliestStart...latestEnd
        }()

        return ChatProposalApplyPlan(
            acceptedIndices: acceptedIndices,
            deletedEventIDs: Set(acceptedSuggestions.filter { $0.action == .delete }.compactMap(\.eventId)),
            syncRange: syncRange,
            upsertEventIDs: Set(acceptedSuggestions.filter { $0.action == .update }.compactMap(\.eventId))
        )
    }

    func updatingConflicts(_ conflicts: [ChatSuggestion.ID: Bool]) -> Self {
        var nextPayload = self
        nextPayload.suggestions = suggestions.map { suggestion in
            var updatedSuggestion = suggestion
            updatedSuggestion.hasConflict = conflicts[suggestion.id] ?? suggestion.hasConflict
            return updatedSuggestion
        }
        return nextPayload
    }
}
