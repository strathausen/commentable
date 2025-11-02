import Vapor

struct RedirectMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Check if user is authenticated
        if request.auth.has(User.self) {
            return try await next.respond(to: request)
        }

        // Redirect to login page if not authenticated
        return request.redirect(to: "/login")
    }
}
