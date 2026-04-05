import ComposableArchitecture
import Foundation

struct ChatClient: Sendable {
    var applyActions: @Sendable (_ chatID: UUID, _ messageID: UUID, _ acceptedIndices: [Int], _ bearerToken: String) async throws -> ChatMessage
    var createChat: @Sendable (_ title: String, _ bearerToken: String) async throws -> Chat
    var listChats: @Sendable (_ bearerToken: String) async throws -> [Chat]
    var listMessages: @Sendable (_ chatID: UUID, _ before: UUID?, _ limit: Int, _ bearerToken: String) async throws -> ([ChatMessage], Bool)
    var sendMessage: @Sendable (_ chatID: UUID, _ role: String, _ contentText: String?, _ bearerToken: String) async throws -> ChatMessage
}

extension ChatClient: DependencyKey {
    static let liveValue = ChatClient(
        applyActions: { chatID, messageID, acceptedIndices, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    ApplyActionsRequestDTO(acceptedIndices: acceptedIndices)
                )
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "chats/\(chatID.uuidString)/messages/\(messageID.uuidString)/apply",
                    method: .post,
                    body: body,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(ChatMessageDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        createChat: { title, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(ChatCreateRequestDTO(title: title))
            }
            let data = try await liveAPISend(
                APIRequest(path: "chats/", method: .post, body: body, bearerToken: bearerToken)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(ChatDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        listChats: { bearerToken in
            let data = try await liveAPISend(
                APIRequest(path: "chats/", method: .get, bearerToken: bearerToken)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(ChatListDTO.self, from: data)
            }
            return dto.items.map(APIModelConverter.convert)
        },
        listMessages: { chatID, before, limit, bearerToken in
            var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
            if let before {
                queryItems.append(URLQueryItem(name: "before", value: before.uuidString))
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "chats/\(chatID.uuidString)/messages",
                    method: .get,
                    queryItems: queryItems,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(ChatMessageListDTO.self, from: data)
            }
            return (dto.items.map(APIModelConverter.convert), dto.hasMore)
        },
        sendMessage: { chatID, role, contentText, bearerToken in
            debugTrace("ChatClient.sendMessage -> chatID=\(chatID), role=\(role), draft=\(contentText ?? "nil")")
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    ChatMessageCreateRequestDTO(
                        role: role,
                        contentText: contentText,
                        contentStructured: nil,
                        aiModel: nil
                    )
                )
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "chats/\(chatID.uuidString)/messages",
                    method: .post,
                    body: body,
                    bearerToken: bearerToken,
                    timeoutInterval: 180
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(ChatMessageDTO.self, from: data)
            }
            debugTrace(
                "ChatClient.sendMessage <- assistant id=\(dto.id), role=\(dto.role), " +
                "text=\(dto.contentText ?? "nil"), structured=\(dto.contentStructured != nil)"
            )
            return APIModelConverter.convert(dto)
        }
    )
}

extension DependencyValues {
    nonisolated var chatClient: ChatClient {
        get { self[ChatClient.self] }
        set { self[ChatClient.self] = newValue }
    }
}
