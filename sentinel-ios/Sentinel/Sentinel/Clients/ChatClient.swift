import ComposableArchitecture
import Foundation

struct ChatClient: Sendable {
    var applyActions: @Sendable (_ chatID: UUID, _ messageID: UUID, _ acceptedIndices: [Int], _ bearerToken: String) async throws -> ChatMessage
    var createChat: @Sendable (_ title: String, _ bearerToken: String) async throws -> Chat
    var deleteChat: @Sendable (_ chatID: UUID, _ bearerToken: String) async throws -> Void
    var listChats: @Sendable (_ bearerToken: String) async throws -> [Chat]
    var listMessages: @Sendable (_ chatID: UUID, _ before: UUID?, _ limit: Int, _ bearerToken: String) async throws -> ([ChatMessage], Bool)
    var sendMessage: @Sendable (_ chatID: UUID, _ role: String, _ contentText: String?, _ images: [ChatImageAttachment], _ bearerToken: String) async throws -> ChatMessage
    var uploadImage: @Sendable (_ chatID: UUID, _ filename: String, _ mimeType: String, _ data: Data, _ bearerToken: String) async throws -> ChatImageAttachment
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
        deleteChat: { chatID, bearerToken in
            _ = try await liveAPISend(
                APIRequest(
                    path: "chats/\(chatID.uuidString)",
                    method: .delete,
                    bearerToken: bearerToken
                )
            )
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
        sendMessage: { chatID, role, contentText, images, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    ChatMessageCreateRequestDTO(
                        role: role,
                        contentText: contentText,
                        contentStructured: nil,
                        images: images.map {
                            ImageAttachmentDTO(
                                url: $0.url,
                                filename: $0.filename,
                                mimeType: $0.mimeType
                            )
                        },
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
            return APIModelConverter.convert(dto)
        },
        uploadImage: { chatID, filename, mimeType, data, bearerToken in
            let boundary = "SentinelBoundary-\(UUID().uuidString)"
            let body = MultipartFormDataBody.makeSingleFileBody(
                named: "file",
                filename: filename,
                mimeType: mimeType,
                data: data,
                boundary: boundary
            )

            let responseData = try await liveAPISend(
                APIRequest(
                    path: "chats/\(chatID.uuidString)/upload",
                    method: .post,
                    body: body,
                    bearerToken: bearerToken,
                    contentType: "multipart/form-data; boundary=\(boundary)"
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(UploadResponseDTO.self, from: responseData)
            }
            return APIModelConverter.convert(ImageAttachmentDTO(url: dto.url, filename: dto.filename, mimeType: dto.mimeType))
        }
    )
}

extension DependencyValues {
    nonisolated var chatClient: ChatClient {
        get { self[ChatClient.self] }
        set { self[ChatClient.self] = newValue }
    }
}

private enum MultipartFormDataBody {
    nonisolated static func makeSingleFileBody(
        named name: String,
        filename: String,
        mimeType: String,
        data fileData: Data,
        boundary: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(lineBreak)"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(fileData)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
