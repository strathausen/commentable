import Vapor

struct CustomErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            let status: HTTPResponseStatus
            let reason: String

            switch error {
            case let abort as any AbortError:
                status = abort.status
                reason = abort.reason
            default:
                status = .internalServerError
                reason = "Internal server error"
            }

            request.logger.report(error: error)

            // For 404, render nice error page
            if status == .notFound {
                do {
                    let response = try await request.view.render("404").encodeResponse(for: request)
                    response.status = .notFound
                    return response
                } catch {
                    // Fallback
                    return Response(status: .notFound, body: .init(string: "404 - Page not found"))
                }
            }

            // For other errors, return simple text
            return Response(status: status, body: .init(string: "\(status.code) - \(reason)"))
        }
    }
}
