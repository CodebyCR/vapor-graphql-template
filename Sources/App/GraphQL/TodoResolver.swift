import Graphiti
import Vapor

struct TodoResolver: Sendable, CustomDebugStringConvertible {
    var debugDescription: String {
        "TodoResolver"
    }

    func getAllUsers(request: Request, _: NoArguments) async throws -> [User] {
        try await User.query(on: request.db).all()
    }

    struct CreateUserArguments: Codable {
        let name: String
    }

    func createUser(
        request: Request,
        arguments: CreateUserArguments
    ) async throws -> User {
        let user = User(name: arguments.name)
        try await user.create(on: request.db)
        return user
    }

    struct DeleteUserArguments: Codable {
        let id: UUID
    }

    func deleteUser(request: Request, arguments: DeleteUserArguments) async throws -> Bool {
        guard let user = try await User.find(arguments.id, on: request.db) else {
            throw Abort(.notFound, reason: "No user with id \(arguments.id) exists.")
        }
        try await user.delete(on: request.db)
        return true
    }

    func getAllTodos(request: Request, _: NoArguments) async throws -> [Todo] {
        try await Todo.query(on: request.db).all()
    }

    struct CreateTodoArguments: Codable {
        let title: String
        let userID: UUID
    }

    func createTodo(request: Request, arguments: CreateTodoArguments) async throws -> Todo {
        guard try await User.find(arguments.userID, on: request.db) != nil else {
            throw Abort(.notFound, reason: "No user with id \(arguments.userID) exists.")
        }
        let todo = Todo(title: arguments.title, userID: arguments.userID)
        try await todo.create(on: request.db)
        return todo
    }

    struct DeleteTodoArguments: Codable {
        let id: UUID
    }

    func deleteTodo(request: Request, arguments: DeleteTodoArguments) async throws -> Bool {
        guard let todo = try await Todo.find(arguments.id, on: request.db) else {
            throw Abort(.notFound, reason: "No todo with id \(arguments.id) exists.")
        }
        try await todo.delete(on: request.db)
        return true
    }

    // Tag Resolver
    func getAllTags(request: Request, _: NoArguments) async throws -> [Tag] {
        try await Tag.query(on: request.db).all()
    }

    struct CreateTagArguments: Codable {
        let title: String
    }

    func createTag(request: Request, arguments: CreateTagArguments) async throws -> Tag {
        let tag = Tag(title: arguments.title)
        try await tag.create(on: request.db)
        return tag
    }

    struct AddTagToTodoArguments: Codable {
        let todoID: UUID
        let tagID: UUID
    }

    func addTagToTodo(request: Request, arguments: AddTagToTodoArguments) async throws -> Bool {
        async let tag = try await Tag.find(arguments.tagID, on: request.db)
        async let todo = try await Todo.find(arguments.todoID, on: request.db)
        guard let tag = try await tag else {
            throw Abort(.notFound, reason: "No tag with id \(arguments.tagID) exists.")
        }
        guard let todo = try await todo else {
            throw Abort(.notFound, reason: "No todo with id \(arguments.todoID) exists.")
        }
        // Attaching the same tag twice is a no-op instead of a unique constraint error.
        if try await !todo.$tags.isAttached(to: tag, on: request.db) {
            try await todo.$tags.attach(tag, on: request.db)
        }
        return true
    }
}
