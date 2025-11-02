import Fluent
import Vapor
import struct Foundation.UUID

enum CommentStatus: String, Codable {
    case pending
    case approved
    case rejected
}

final class Comment: Model, @unchecked Sendable {
    static let schema = "comments"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "page_id")
    var page: Page

    @Field(key: "author_name")
    var authorName: String?

    @Field(key: "content")
    var content: String

    @Enum(key: "status")
    var status: CommentStatus

    @Field(key: "moderation_result")
    var moderationResult: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "moderated_at", on: .none)
    var moderatedAt: Date?

    init() { }

    init(id: UUID? = nil, pageID: UUID, authorName: String?, content: String, status: CommentStatus = .pending) {
        self.id = id
        self.$page.id = pageID
        self.authorName = authorName
        self.content = content
        self.status = status
    }

    func toDTO() -> CommentDTO {
        .init(
            id: self.id,
            pageId: self.$page.id,
            authorName: self.authorName,
            content: self.$content.value,
            status: self.$status.value,
            moderationResult: self.moderationResult,
            createdAt: self.createdAt,
            moderatedAt: self.moderatedAt
        )
    }
}
