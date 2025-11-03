import Fluent
import Vapor
import struct Foundation.UUID

final class AuditLog: Model, @unchecked Sendable {
    static let schema = "audit_logs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "action")
    var action: String

    @Field(key: "entity_type")
    var entityType: String

    @Field(key: "entity_id")
    var entityId: UUID?

    @Field(key: "metadata")
    var metadata: [String: String]?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, userID: UUID, action: String, entityType: String, entityId: UUID? = nil, metadata: [String: String]? = nil) {
        self.id = id
        self.$user.id = userID
        self.action = action
        self.entityType = entityType
        self.entityId = entityId
        self.metadata = metadata
    }
}
