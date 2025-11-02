import Fluent
import Vapor

struct WebsiteDTO: Content {
    var id: UUID?
    var userId: UUID?
    var name: String?
    var domain: String?
    var createdAt: Date?
}

struct CreateWebsiteDTO: Content {
    var name: String
    var domain: String

    func toModel(userId: UUID) -> Website {
        Website(userID: userId, name: name, domain: domain)
    }
}

struct WebsiteWithStatsDTO: Content {
    var id: UUID?
    var name: String
    var domain: String
    var createdAt: Date?
    var pageCount: Int
    var commentCount: Int
}
