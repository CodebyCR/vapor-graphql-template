import Fluent

struct MigrateUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("name", .string, .required)
            // Deleting the current todo clears the reference instead of blocking the delete.
            .field("current_todo_id", .uuid, .references("todos", "id", onDelete: .setNull))
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
