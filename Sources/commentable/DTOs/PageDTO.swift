import Fluent
import Vapor

struct PageDTO: Content {
    var id: UUID?
    var websiteId: UUID?
    var path: String?
    var createdAt: Date?
}

struct PageWithCommentsDTO: Content {
    var id: UUID?
    var path: String
    var createdAt: Date?
    var commentCount: Int
}
