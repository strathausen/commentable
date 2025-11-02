import Fluent
import Vapor

struct ModerationPromptController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let prompts = routes.grouped("websites", ":websiteID", "moderation-prompts")
        let protected = prompts.grouped(User.sessionAuthenticator(), RedirectMiddleware())

        protected.get(use: self.index)
        protected.post(use: self.create)
        protected.group(":promptID") { prompt in
            prompt.patch(use: self.update)
            prompt.delete(use: self.delete)
        }

        protected.post("rerun", use: self.rerunModeration)
    }

    private func verifyWebsiteOwnership(websiteID: UUID, userID: UUID, db: any Database) async throws -> Website {
        guard let website = try await Website.find(websiteID, on: db) else {
            throw Abort(.notFound, reason: "Website not found")
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden, reason: "You don't have access to this website")
        }

        return website
    }

    @Sendable
    func index(req: Request) async throws -> View {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        let website = try await verifyWebsiteOwnership(websiteID: websiteID, userID: userID, db: req.db)

        let prompts = try await ModerationPrompt.query(on: req.db)
            .filter(\.$website.$id == websiteID)
            .sort(\.$createdAt, .descending)
            .all()

        struct ModerationPromptsContext: Encodable {
            let user: UserDTO
            let website: WebsiteDTO
            let prompts: [ModerationPromptDTO]
            let websiteId: String
        }

        let context = ModerationPromptsContext(
            user: user.toDTO(),
            website: website.toDTO(),
            prompts: prompts.map { $0.toDTO() },
            websiteId: websiteID.uuidString
        )

        return try await req.view.render("moderation-prompts", context)
    }

    @Sendable
    func create(req: Request) async throws -> ModerationPromptDTO {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        _ = try await verifyWebsiteOwnership(websiteID: websiteID, userID: userID, db: req.db)

        let createPrompt = try req.content.decode(CreateModerationPromptDTO.self)
        let prompt = createPrompt.toModel(websiteID: websiteID)

        try await prompt.save(on: req.db)
        return prompt.toDTO()
    }

    @Sendable
    func update(req: Request) async throws -> ModerationPromptDTO {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        _ = try await verifyWebsiteOwnership(websiteID: websiteID, userID: userID, db: req.db)

        guard let prompt = try await ModerationPrompt.find(req.parameters.get("promptID"), on: req.db) else {
            throw Abort(.notFound)
        }

        let updatePrompt = try req.content.decode(UpdateModerationPromptDTO.self)

        if let newPrompt = updatePrompt.prompt {
            prompt.prompt = newPrompt
        }
        if let isActive = updatePrompt.isActive {
            prompt.isActive = isActive
        }

        try await prompt.save(on: req.db)
        return prompt.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        _ = try await verifyWebsiteOwnership(websiteID: websiteID, userID: userID, db: req.db)

        guard let prompt = try await ModerationPrompt.find(req.parameters.get("promptID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await prompt.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func rerunModeration(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        _ = try await verifyWebsiteOwnership(websiteID: websiteID, userID: userID, db: req.db)

        // Get active prompts
        let prompts = try await ModerationPrompt.query(on: req.db)
            .filter(\.$website.$id == websiteID)
            .filter(\.$isActive == true)
            .all()

        let customPrompts = prompts.map { $0.prompt }

        // Get all pending comments for this website
        let pages = try await Page.query(on: req.db)
            .filter(\.$website.$id == websiteID)
            .all()

        let pageIDs = try pages.map { try $0.requireID() }

        let comments = try await Comment.query(on: req.db)
            .filter(\.$page.$id ~~ pageIDs)
            .filter(\.$status == .pending)
            .filter(\.$manuallyModerated == false)
            .all()

        // Re-run moderation for each comment (skip manually moderated)
        for comment in comments {
            do {
                let (approved, result) = try await req.moderation.moderateComment(comment, customPrompts: customPrompts)
                comment.status = approved ? .approved : .rejected
                comment.moderationResult = result
                comment.moderatedAt = Date()
                try await comment.save(on: req.db)
            } catch {
                req.logger.error("Failed to moderate comment \(comment.id?.uuidString ?? "unknown"): \(error)")
            }
        }

        return .accepted
    }
}
