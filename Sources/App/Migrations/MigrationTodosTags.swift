import Fluent

struct MigrateTodosTags: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TodoTag.schema)
            .id()
            // Deleting either side of the relation removes the pivot row, so no orphans are left behind.
            .field("todo_id", .uuid, .required, .references(Todo.schema, "id", onDelete: .cascade))
            .field("tag_id", .uuid, .required, .references(Tag.schema, "id", onDelete: .cascade))
            .unique(on: "todo_id", "tag_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(TodoTag.schema).delete()
    }
}
