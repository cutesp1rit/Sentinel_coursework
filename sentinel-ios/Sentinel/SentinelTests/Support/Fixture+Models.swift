import SentinelUI
import SentinelCore
import Foundation
@testable import Sentinel

extension Fixture {
    static func session(
        accessToken: String = "access-token",
        tokenType: String = "bearer"
    ) -> Session {
        Session(accessToken: accessToken, tokenType: tokenType)
    }

    static func authenticatedSession(
        accessToken: String = "access-token",
        tokenType: String = "bearer",
        email: String = "jane.doe@example.com"
    ) -> AuthenticatedSession {
        AuthenticatedSession(
            session: session(accessToken: accessToken, tokenType: tokenType),
            email: email
        )
    }

    static func user(
        id: UUID = userID,
        email: String = "jane.doe@example.com"
    ) -> User {
        User(
            id: id,
            email: email,
            timezone: "Europe/Moscow",
            locale: "ru_RU",
            isVerified: true,
            createdAt: referenceDate
        )
    }

    static func achievementLevel(
        id: UUID = levelID,
        level: Int = 1,
        targetValue: Int = 5,
        title: String = "Starter",
        unlocked: Bool = false,
        earnedAt: Date? = nil
    ) -> AchievementLevel {
        AchievementLevel(
            id: id,
            description: "Description",
            earnedAt: earnedAt,
            icon: "star.fill",
            level: level,
            targetValue: targetValue,
            title: title,
            unlocked: unlocked
        )
    }

    static func achievementGroup(
        groupCode: String = "events_created",
        currentValue: Int = 2,
        levels: [AchievementLevel]? = nil
    ) -> AchievementGroup {
        AchievementGroup(
            id: groupCode,
            category: "daily_planning",
            counterName: "events",
            currentValue: currentValue,
            groupCode: groupCode,
            levels: levels ?? [
                achievementLevel(unlocked: true, earnedAt: referenceDate),
                achievementLevel(
                    id: secondLevelID,
                    level: 2,
                    targetValue: 10,
                    title: "Builder",
                    unlocked: false
                )
            ]
        )
    }

    static func event(
        id: UUID = eventID,
        userId: UUID = userID,
        title: String = "Planning",
        description: String? = "Discuss roadmap",
        startAt: Date = referenceDate,
        endAt: Date? = secondaryDate,
        allDay: Bool = false,
        type: EventKind = .event,
        location: String? = "Office",
        isFixed: Bool = false,
        source: String = "user"
    ) -> Event {
        Event(
            id: id,
            userId: userId,
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            type: type,
            location: location,
            isFixed: isFixed,
            source: source,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static func chat(
        id: UUID = chatID,
        title: String = "Today"
    ) -> Chat {
        Chat(
            id: id,
            userId: userID,
            title: title,
            lastMessageAt: referenceDate,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static func eventAction(
        kind: EventAction.Kind = .create,
        eventId: UUID? = nil,
        title: String? = "Planning",
        location: String? = "Office",
        startAt: Date? = referenceDate,
        endAt: Date? = secondaryDate,
        allDay: Bool? = false,
        type: EventKind? = .event,
        status: EventAction.Status = .pending,
        snapshotTitle: String = "Existing"
    ) -> EventAction {
        EventAction(
            action: kind,
            eventId: eventId,
            payload: EventMutationPayload(
                title: title,
                description: "Description",
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                type: type,
                location: location,
                isFixed: false,
                source: "ai"
            ),
            status: status,
            eventSnapshot: EventAction.Snapshot(
                title: snapshotTitle,
                startAt: startAt ?? referenceDate,
                endAt: endAt
            )
        )
    }

    static func chatMessage(
        role: ChatMessage.Role = .assistant,
        markdownText: String? = "Body",
        actions: [EventAction]? = nil,
        images: [ChatImageAttachment] = []
    ) -> ChatMessage {
        ChatMessage(
            id: messageID,
            chatId: chatID,
            role: role,
            content: ChatMessage.Content(
                markdownText: markdownText,
                eventActions: actions.map { EventActionsContent(type: "event_actions", actions: $0) },
                images: images
            ),
            aiModel: "gpt",
            createdAt: referenceDate
        )
    }

    static func homeItem(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        subtitle: String = "Calendar"
    ) -> HomeScheduleItem {
        HomeScheduleItem(
            endDate: endDate,
            startDate: startDate,
            title: title,
            timeText: startDate.formatted(date: .omitted, time: .shortened),
            subtitle: subtitle
        )
    }
}
