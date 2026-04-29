import Foundation

extension APIModelConverter {
    public nonisolated static func convert(_ dto: TokenDTO) -> Session {
        Session(accessToken: dto.accessToken, tokenType: dto.tokenType)
    }

    public nonisolated static func convert(_ dto: UserDTO) -> User {
        User(
            id: dto.id,
            email: dto.email,
            timezone: dto.timezone,
            locale: dto.locale,
            isVerified: dto.isVerified,
            createdAt: dto.createdAt
        )
    }
}
