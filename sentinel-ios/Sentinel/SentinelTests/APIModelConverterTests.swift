import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct APIModelConverterTests {
    @Test
    func apiModelConverterMapsDTOsAndFallbacks() {
        let user = APIModelConverter.convert(
            UserDTO(
                id: Fixture.userID,
                email: "jane.doe@example.com",
                timezone: "Europe/Moscow",
                locale: "ru_RU",
                isVerified: true,
                createdAt: Fixture.referenceDate
            )
        )
        #expect(user == Fixture.user())

        let event = APIModelConverter.convert(
            EventDTO(
                id: Fixture.eventID,
                userId: Fixture.userID,
                title: "Planning",
                description: "Discuss roadmap",
                startAt: Fixture.referenceDate,
                endAt: Fixture.secondaryDate,
                allDay: false,
                type: "unknown",
                location: "Office",
                isFixed: false,
                source: "user",
                createdAt: Fixture.referenceDate,
                updatedAt: Fixture.referenceDate
            )
        )
        #expect(event.type == .event)

        let message = APIModelConverter.convert(
            ChatMessageDTO(
                id: Fixture.messageID,
                chatId: Fixture.chatID,
                role: "mystery",
                contentText: "Body",
                contentStructured: .imageMessage(
                    ImageMessageContentDTO(
                        type: "image_message",
                        images: [ImageAttachmentDTO(url: "", filename: "local.png", mimeType: "image/png")]
                    )
                ),
                aiModel: "gpt",
                createdAt: Fixture.referenceDate
            )
        )
        #expect(message.role == .user)
        #expect(message.content.images.first?.filename == "local.png")

        let action = APIModelConverter.convert(
            EventActionDTO(
                action: "mystery",
                eventId: Fixture.eventID,
                eventSnapshot: EventSnapshotDTO(
                    title: "Snapshot",
                    startAt: Fixture.referenceDate,
                    endAt: Fixture.secondaryDate
                ),
                payload: EventMutationPayloadDTO(
                    title: "Payload",
                    description: "Body",
                    startAt: Fixture.referenceDate,
                    endAt: Fixture.secondaryDate,
                    allDay: false,
                    type: "mystery",
                    location: "Office",
                    isFixed: true,
                    source: "ai"
                ),
                status: "mystery"
            )
        )
        #expect(action.action == .create)
        #expect(action.status == .pending)
        #expect(action.payload?.type == nil)

        let group = APIModelConverter.convert(
            AchievementGroupDTO(
                groupCode: "events_created",
                category: "daily_planning",
                counterName: "events",
                currentValue: 4,
                levels: [
                    AchievementLevelDTO(
                        id: Fixture.levelID,
                        level: 1,
                        title: "Starter",
                        description: "Desc",
                        icon: "star.fill",
                        targetValue: 5,
                        unlocked: true,
                        earnedAt: Fixture.referenceDate
                    )
                ]
            )
        )
        #expect(group.groupCode == "events_created")
        #expect(group.levels.first?.unlocked == true)
    }
}
