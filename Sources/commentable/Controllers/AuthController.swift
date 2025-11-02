import Fluent
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        auth.post("register", use: self.register)
        auth.post("login", use: self.login)

        let protected = auth.grouped(User.sessionAuthenticator())
        protected.post("logout", use: self.logout)
        protected.get("me", use: self.me)
    }

    @Sendable
    func register(req: Request) async throws -> UserDTO {
        let createUser = try req.content.decode(CreateUserDTO.self)

        // Check if user already exists
        if let _ = try await User.query(on: req.db)
            .filter(\.$email == createUser.email)
            .first() {
            throw Abort(.conflict, reason: "User with this email already exists")
        }

        let passwordHash = try Bcrypt.hash(createUser.password)
        let user = User(email: createUser.email, passwordHash: passwordHash)

        try await user.save(on: req.db)
        return user.toDTO()
    }

    @Sendable
    func login(req: Request) async throws -> Response {
        let loginDTO = try req.content.decode(LoginDTO.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$email == loginDTO.email)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        guard try user.verify(password: loginDTO.password) else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        // Create session
        let token = [UInt8].random(count: 32).base64
        let expiresAt = Date().addingTimeInterval(60 * 60 * 24 * 30) // 30 days
        let session = UserSession(userID: try user.requireID(), token: token, expiresAt: expiresAt)
        try await session.save(on: req.db)

        // Set cookie
        let cookie = HTTPCookies.Value(
            string: token,
            expires: expiresAt,
            maxAge: 60 * 60 * 24 * 30,
            domain: nil,
            path: "/",
            isSecure: req.application.environment != .development,
            isHTTPOnly: true,
            sameSite: .lax
        )

        let response = Response(status: .ok)
        response.cookies["session"] = cookie
        try response.content.encode(user.toDTO())
        return response
    }

    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        if let sessionToken = req.cookies["session"]?.string {
            try await UserSession.query(on: req.db)
                .filter(\.$user.$id == user.requireID())
                .filter(\.$token == sessionToken)
                .delete()
        }

        req.auth.logout(User.self)
        return .noContent
    }

    @Sendable
    func me(req: Request) async throws -> UserDTO {
        let user = try req.auth.require(User.self)
        return user.toDTO()
    }
}

extension User {
    static func sessionAuthenticator() -> UserSessionAuthenticator {
        UserSessionAuthenticator()
    }
}

struct UserSessionAuthenticator: AsyncRequestAuthenticator {
    func authenticate(request: Request) async throws {
        guard let sessionToken = request.cookies["session"]?.string else {
            return
        }

        guard let session = try await UserSession.query(on: request.db)
            .filter(\.$token == sessionToken)
            .with(\.$user)
            .first(),
              let expiresAt = session.expiresAt,
              expiresAt > Date() else {
            return
        }

        request.auth.login(session.user)
    }
}
