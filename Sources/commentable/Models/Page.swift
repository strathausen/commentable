import Fluent
import Vapor
import struct Foundation.UUID

final class Page: Model, @unchecked Sendable {
    static let schema = "pages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "website_id")
    var website: Website

    @Field(key: "path")
    var path: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$page)
    var comments: [Comment]

    init() { }

    init(id: UUID? = nil, websiteID: UUID, path: String) {
        self.id = id
        self.$website.id = websiteID
        self.path = path
    }

    func toDTO() -> PageDTO {
        .init(
            id: self.id,
            websiteId: self.$website.id,
            path: self.$path.value,
            createdAt: self.createdAt
        )
    }
}
