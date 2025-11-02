import Fluent
import Vapor

struct CommentDTO: Content {
    var id: UUID?
    var pageId: UUID?
    var authorName: String?
    var content: String?
    var status: CommentStatus?
    var moderationResult: String?
    var createdAt: Date?
    var moderatedAt: Date?
    var manuallyModerated: Bool?
}

struct CreateCommentDTO: Content {
    var authorName: String?
    var content: String

    func toModel(pageID: UUID) -> Comment {
        Comment(pageID: pageID, authorName: authorName, content: content)
    }
}

struct PublicCommentDTO: Content {
    var id: UUID?
    var authorName: String?
    var content: String
    var createdAt: Date?
}
