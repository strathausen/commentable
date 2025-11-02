import Fluent
import Vapor

struct UserDTO: Content {
    var id: UUID?
    var email: String?
    var createdAt: Date?
}

struct CreateUserDTO: Content {
    var email: String
    var password: String
}

struct LoginDTO: Content {
    var email: String
    var password: String
}
