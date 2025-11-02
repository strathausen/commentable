import Fluent
import Vapor

struct DashboardController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Protected dashboard route
        let dashboard = routes.grouped("dashboard")
        let protected = dashboard.grouped(User.sessionAuthenticator(), RedirectMiddleware())
        protected.get(use: self.index)
    }

    @Sendable
    func index(req: Request) async throws -> View {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        // Check if showing archived
        let showArchived = (try? req.query.get(Bool.self, at: "archived")) ?? false

        let websites = try await Website.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$archived == showArchived)
            .with(\.$pages) { page in
                page.with(\.$comments)
            }
            .with(\.$moderationPrompts)
            .all()

        let websitesData = websites.map { website -> [String: Any] in
            let pageCount = website.pages.count
            let commentCount = website.pages.reduce(0) { $0 + $1.comments.count }

            return [
                "id": website.id?.uuidString ?? "",
                "name": website.name,
                "domain": website.domain,
                "pageCount": pageCount,
                "commentCount": commentCount,
                "archived": website.archived,
                "embedCode": generateEmbedCode(websiteID: website.id?.uuidString ?? "", req: req)
            ]
        }

        struct DashboardContext: Encodable {
            let user: UserDTO
            let websites: [[String: Any]]
            let showArchived: Bool

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(user, forKey: .user)
                try container.encode(showArchived, forKey: .showArchived)
                // Encode websites as unstructured data
                try container.encode(AnyCodable(websites), forKey: .websites)
            }

            enum CodingKeys: String, CodingKey {
                case user, websites, showArchived
            }
        }

        let context = DashboardContext(user: user.toDTO(), websites: websitesData, showArchived: showArchived)
        return try await req.view.render("dashboard", context)
    }

    private func generateEmbedCode(websiteID: String, req: Request) -> String {
        let baseURL = req.application.http.server.configuration.hostname
        let port = req.application.http.server.configuration.port
        let scheme = req.application.environment == .development ? "http" : "https"

        let embedURL: String
        if port == 80 || port == 443 {
            embedURL = "\(scheme)://\(baseURL)/embed/\(websiteID)"
        } else {
            embedURL = "\(scheme)://\(baseURL):\(port)/embed/\(websiteID)"
        }

        return """
        <iframe
          src="\(embedURL)?url="
          width="100%"
          height="600"
          frameborder="0">
        </iframe>
        <script>
          (function() {
            var iframe = document.currentScript.previousElementSibling;
            var url = window.location.href;
            iframe.src = iframe.src + encodeURIComponent(url);
          })();
        </script>
        """
    }
}
