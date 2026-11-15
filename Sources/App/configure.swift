import FluentSQLiteDriver
import GraphiQLVapor
import Graphiti
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    app.databases.use(.sqlite(.memory), as: .sqlite)
    app.migrations.add(MigrateTodos())
    app.migrations.add(MigrateUsers())
    app.migrations.add(MigrateTags())
    app.migrations.add(MigrateTodosTags())
    try await app.autoMigrate()

    // Register the schema and its resolver.
    let todoSchema = try TodoSchemaProvider().get()
    app.register(graphQLSchema: todoSchema, withResolver: TodoResolver())

    // Enable GraphiQL web page to send queries to the GraphQL endpoint.
    // `environment.isRelease` reflects the build configuration, so use the environment name instead.
    if app.environment != .production {
        app.enableGraphiQL()
    }
}
