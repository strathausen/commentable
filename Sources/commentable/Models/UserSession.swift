import Fluent
import Vapor
import struct Foundation.UUID

final class UserSession: Model, @unchecked Sendable {
    static let schema = "user_sessions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "token")
    var token: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?

    init() { }

    init(id: UUID? = nil, userID: UUID, token: String, expiresAt: Date) {
        self.id = id
        self.$user.id = userID
        self.token = token
        self.expiresAt = expiresAt
    }
}

