import Foundation
import Testing
@testable import Sentinel

@MainActor
struct DTOCodingTests {
    @Test
    func authDTOsEncodeAndDecodeExpectedKeys() throws {
        let token = try AppConfiguration.jsonDecoder.decode(
            TokenDTO.self,
            from: Data(#"{"access_token":"abc","token_type":"bearer"}"#.utf8)
        )
        #expect(token == TokenDTO(accessToken: "abc", tokenType: "bearer"))

        let user = try AppConfiguration.jsonDecoder.decode(
            UserDTO.self,
            from: Data("""
            {
              "id":"\(Fixture.userID.uuidString)",
              "email":"jane.doe@example.com",
              "timezone":"Europe/Moscow",
              "locale":"ru_RU",
              "is_verified":true,
              "created_at":"2023-11-14T22:13:20Z"
            }
            """.utf8)
        )
        #expect(user.id == Fixture.userID)
        #expect(user.isVerified)

        let encoded = try AppConfiguration.jsonEncoder.encode(
            ResetPasswordRequestDTO(token: "reset", newPassword: "secret")
        )
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: String]
        #expect(object?["token"] == "reset")
        #expect(object?["new_password"] == "secret")
    }

    @Test
    func achievementAndEventDTOsRoundTrip() throws {
        let achievements = try AppConfiguration.jsonDecoder.decode(
            AchievementsResponseDTO.self,
            from: Data("""
            {
              "groups":[
                {
                  "group_code":"events_created",
                  "category":"daily_planning",
                  "counter_name":"events",
                  "current_value":2,
                  "levels":[
                    {
                      "id":"\(Fixture.levelID.uuidString)",
                      "level":1,
                      "title":"Starter",
                      "description":"Desc",
                      "icon":"star.fill",
                      "target_value":5,
                      "unlocked":true,
                      "earned_at":"2023-11-14T22:13:20Z"
                    }
                  ]
                }
              ]
            }
            """.utf8)
        )
        #expect(achievements.groups.first?.groupCode == "events_created")
        #expect(achievements.groups.first?.levels.first?.earnedAt == Fixture.referenceDate)

        let event = try AppConfiguration.jsonDecoder.decode(
            EventDTO.self,
            from: Data("""
            {
              "id":"\(Fixture.eventID.uuidString)",
              "user_id":"\(Fixture.userID.uuidString)",
              "title":"Planning",
              "description":"Discuss roadmap",
              "start_at":"2023-11-14T22:13:20Z",
              "end_at":"2023-11-14T23:13:20Z",
              "all_day":false,
              "type":"event",
              "location":"Office",
              "is_fixed":false,
              "source":"user",
              "created_at":"2023-11-14T22:13:20Z",
              "updated_at":"2023-11-14T22:13:20Z"
            }
            """.utf8)
        )
        #expect(event.id == Fixture.eventID)

        let createRequest = EventCreateRequestDTO(
            title: "Planning",
            description: "Discuss roadmap",
            startAt: Fixture.referenceDate,
            endAt: Fixture.secondaryDate,
            allDay: false,
            type: "event",
            location: "Office",
            isFixed: true,
            source: "ai"
        )
        let encoded = try AppConfiguration.jsonEncoder.encode(createRequest)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        #expect(object?["all_day"] as? Bool == false)
        #expect(object?["is_fixed"] as? Bool == true)
        #expect(object?["source"] as? String == "ai")
    }

    @Test
    func chatDTOsAndStructuredContentCoverBothVariants() throws {
        let chat = try AppConfiguration.jsonDecoder.decode(
            ChatDTO.self,
            from: Data("""
            {
              "id":"\(Fixture.chatID.uuidString)",
              "user_id":"\(Fixture.userID.uuidString)",
              "title":"Today",
              "last_message_at":"2023-11-14T22:13:20Z",
              "created_at":"2023-11-14T22:13:20Z",
              "updated_at":"2023-11-14T22:13:20Z"
            }
            """.utf8)
        )
        #expect(chat.id == Fixture.chatID)

        let eventActions = try AppConfiguration.jsonDecoder.decode(
            ChatStructuredContentDTO.self,
            from: Data("""
            {
              "type":"event_actions",
              "actions":[
                {
                  "action":"create",
                  "event_id":null,
                  "event_snapshot":null,
                  "payload":{
                    "title":"Planning",
                    "description":"Discuss roadmap",
                    "start_at":"2023-11-14T22:13:20Z",
                    "end_at":"2023-11-14T23:13:20Z",
                    "all_day":false,
                    "type":"event",
                    "location":"Office",
                    "is_fixed":false,
                    "source":"ai"
                  },
                  "status":"pending"
                }
              ]
            }
            """.utf8)
        )
        if case let .eventActions(content) = eventActions {
            #expect(content.actions.count == 1)
        } else {
            Issue.record("Expected event actions payload")
        }

        let imageMessage = try AppConfiguration.jsonDecoder.decode(
            ChatStructuredContentDTO.self,
            from: Data("""
            {
              "type":"image_message",
              "images":[
                {"url":"https://example.com/image.jpg","filename":"image.jpg","mime_type":"image/jpeg"}
              ]
            }
            """.utf8)
        )
        if case let .imageMessage(content) = imageMessage {
            #expect(content.images.first?.mimeType == "image/jpeg")
        } else {
            Issue.record("Expected image message payload")
        }

        let createRequest = ChatMessageCreateRequestDTO(
            role: "assistant",
            contentText: "Body",
            contentStructured: EventActionsContentDTO(type: "event_actions", actions: []),
            images: [ImageAttachmentDTO(url: "u", filename: "f", mimeType: "m")],
            aiModel: "gpt"
        )
        let encoded = try AppConfiguration.jsonEncoder.encode(createRequest)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        #expect(object?["role"] as? String == "assistant")
        #expect(object?["ai_model"] as? String == "gpt")

        _ = #expect(throws: DecodingError.self) {
            try AppConfiguration.jsonDecoder.decode(
                ChatStructuredContentDTO.self,
                from: Data(#"{"type":"unsupported"}"#.utf8)
            )
        }
    }
}
