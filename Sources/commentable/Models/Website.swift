import Fluent
import Vapor
import struct Foundation.UUID

final class Website: Model, @unchecked Sendable {
    static let schema = "websites"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "name")
    var name: String

    @Field(key: "domain")
    var domain: String

    @Field(key: "archived")
    var archived: Bool

    @Field(key: "style")
    var style: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$website)
    var pages: [Page]

    @Children(for: \.$website)
    var moderationPrompts: [ModerationPrompt]

    init() { }

    init(id: UUID? = nil, userID: UUID, name: String, domain: String, archived: Bool = false, style: String = "commentable") {
        self.id = id
        self.$user.id = userID
        self.name = name
        self.domain = domain
        self.archived = archived
        self.style = style
    }

    func toDTO() -> WebsiteDTO {
        .init(
            id: self.id,
            userId: self.$user.id,
            name: self.$name.value,
            domain: self.$domain.value,
            style: self.$style.value,
            createdAt: self.createdAt
        )
    }
}
