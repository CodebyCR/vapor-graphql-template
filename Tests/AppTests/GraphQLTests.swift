@testable import App
import GraphQL
import Vapor
import XCTVapor

final class GraphQLTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    // MARK: - Helpers

    private struct Response {
        let status: HTTPStatus
        let json: [String: Any]

        var data: [String: Any]? { json["data"] as? [String: Any] }
        var errors: [[String: Any]] { json["errors"] as? [[String: Any]] ?? [] }
    }

    private struct Body: Encodable {
        let query: String
        let variables: [String: String]
    }

    /// Sends a GraphQL request through the real HTTP stack and returns the decoded JSON body.
    @discardableResult
    private func send(_ query: String, variables: [String: String] = [:]) async throws -> Response {
        var result: Response?
        try await app.test(.POST, "graphql", beforeRequest: { request in
            try request.content.encode(Body(query: query, variables: variables), as: .json)
        }, afterResponse: { response async throws in
            let object = try JSONSerialization.jsonObject(with: Data(response.body.readableBytesView))
            result = Response(status: response.status, json: try XCTUnwrap(object as? [String: Any]))
        })
        return try XCTUnwrap(result)
    }

    private func createUser(_ name: String = "Alice") async throws -> String {
        let response = try await send("mutation { createUser(name: \"\(name)\") { id } }")
        let user = try XCTUnwrap(response.data?["createUser"] as? [String: Any])
        return try XCTUnwrap(user["id"] as? String)
    }

    private func createTodo(_ title: String = "Todo", userID: String) async throws -> String {
        let response = try await send("mutation { createTodo(title: \"\(title)\", userID: \"\(userID)\") { id } }")
        let todo = try XCTUnwrap(response.data?["createTodo"] as? [String: Any])
        return try XCTUnwrap(todo["id"] as? String)
    }

    private func createTag(_ title: String = "Tag") async throws -> String {
        let response = try await send("mutation { createTag(title: \"\(title)\") { id } }")
        let tag = try XCTUnwrap(response.data?["createTag"] as? [String: Any])
        return try XCTUnwrap(tag["id"] as? String)
    }

    // MARK: - Users

    func testCreateUserReturnsISO8601Date() async throws {
        let response = try await send("mutation { createUser(name: \"Alice\") { name createdAt } }")

        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.errors.isEmpty)
        let user = try XCTUnwrap(response.data?["createUser"] as? [String: Any])
        XCTAssertEqual(user["name"] as? String, "Alice")
        let createdAt = try XCTUnwrap(user["createdAt"] as? String)
        XCTAssertNotNil(ISO8601DateFormatter().date(from: createdAt), "\(createdAt) is not ISO 8601")
    }

    func testUsersQueryListsCreatedUsers() async throws {
        _ = try await createUser("Alice")
        _ = try await createUser("Bob")

        let response = try await send("{ users { name } }")

        let users = try XCTUnwrap(response.data?["users"] as? [[String: Any]])
        XCTAssertEqual(users.compactMap { $0["name"] as? String }.sorted(), ["Alice", "Bob"])
    }

    func testDeleteUserCascadesToTodos() async throws {
        let userID = try await createUser()
        _ = try await createTodo(userID: userID)

        let deleted = try await send("mutation { deleteUser(id: \"\(userID)\") }")
        XCTAssertEqual(deleted.data?["deleteUser"] as? Bool, true)

        let response = try await send("{ users { id } todos { id } }")
        XCTAssertEqual((response.data?["users"] as? [Any])?.count, 0)
        XCTAssertEqual((response.data?["todos"] as? [Any])?.count, 0)
    }

    // MARK: - Todos and relations

    func testTodoResolvesParentAndSiblings() async throws {
        let userID = try await createUser("Alice")
        let todoID = try await createTodo("Write tests", userID: userID)
        let tagID = try await createTag("work")
        try await send("mutation { addTagToTodo(tagID: \"\(tagID)\", todoID: \"\(todoID)\") }")

        let response = try await send("{ todos { title user { name todos { title } } tags { title todos { title } } } }")

        XCTAssertTrue(response.errors.isEmpty, "\(response.errors)")
        let todos = try XCTUnwrap(response.data?["todos"] as? [[String: Any]])
        let todo = try XCTUnwrap(todos.first)
        XCTAssertEqual(todo["title"] as? String, "Write tests")
        let user = try XCTUnwrap(todo["user"] as? [String: Any])
        XCTAssertEqual(user["name"] as? String, "Alice")
        XCTAssertEqual((user["todos"] as? [[String: Any]])?.first?["title"] as? String, "Write tests")
        let tags = try XCTUnwrap(todo["tags"] as? [[String: Any]])
        XCTAssertEqual(tags.first?["title"] as? String, "work")
        XCTAssertEqual((tags.first?["todos"] as? [[String: Any]])?.first?["title"] as? String, "Write tests")
    }

    func testOptionalParentIsNullByDefault() async throws {
        _ = try await createUser()

        let response = try await send("{ users { currentTodo { title } } }")

        let users = try XCTUnwrap(response.data?["users"] as? [[String: Any]])
        XCTAssertTrue(users.first?["currentTodo"] is NSNull)
    }

    func testCreateTodoWithVariables() async throws {
        let userID = try await createUser()

        let response = try await send(
            "mutation Create($user: UUID!) { createTodo(title: \"Vars\", userID: $user) { title } }",
            variables: ["user": userID]
        )

        XCTAssertTrue(response.errors.isEmpty, "\(response.errors)")
        let todo = try XCTUnwrap(response.data?["createTodo"] as? [String: Any])
        XCTAssertEqual(todo["title"] as? String, "Vars")
    }

    func testDeleteTodoRemovesTagAssociation() async throws {
        let userID = try await createUser()
        let todoID = try await createTodo(userID: userID)
        let tagID = try await createTag()
        try await send("mutation { addTagToTodo(tagID: \"\(tagID)\", todoID: \"\(todoID)\") }")

        try await send("mutation { deleteTodo(id: \"\(todoID)\") }")

        let response = try await send("{ tags { todos { title } } }")
        let tags = try XCTUnwrap(response.data?["tags"] as? [[String: Any]])
        XCTAssertEqual((tags.first?["todos"] as? [Any])?.count, 0)
    }

    func testAddTagToTodoTwiceIsIdempotent() async throws {
        let userID = try await createUser()
        let todoID = try await createTodo(userID: userID)
        let tagID = try await createTag()
        let mutation = "mutation { addTagToTodo(tagID: \"\(tagID)\", todoID: \"\(todoID)\") }"

        let first = try await send(mutation)
        let second = try await send(mutation)

        XCTAssertEqual(first.data?["addTagToTodo"] as? Bool, true)
        XCTAssertEqual(second.data?["addTagToTodo"] as? Bool, true)
        XCTAssertTrue(second.errors.isEmpty)
        let response = try await send("{ todos { tags { title } } }")
        let todos = try XCTUnwrap(response.data?["todos"] as? [[String: Any]])
        XCTAssertEqual((todos.first?["tags"] as? [Any])?.count, 1)
    }

    // MARK: - Errors

    func testCreateTodoForUnknownUserReports404WithReason() async throws {
        let unknown = UUID().uuidString

        let response = try await send("mutation { createTodo(title: \"x\", userID: \"\(unknown)\") { id } }")

        XCTAssertEqual(response.status, .ok, "GraphQL reports errors in the body")
        let error = try XCTUnwrap(response.errors.first)
        XCTAssertEqual(error["message"] as? String, "No user with id \(unknown) exists.")
        XCTAssertEqual((error["extensions"] as? [String: Any])?["status"] as? Int, 404)
        XCTAssertEqual(error["path"] as? [String], ["createTodo"])
    }

    func testDeleteUnknownTodoReports404() async throws {
        let unknown = UUID().uuidString

        let response = try await send("mutation { deleteTodo(id: \"\(unknown)\") }")

        let error = try XCTUnwrap(response.errors.first)
        XCTAssertEqual(error["message"] as? String, "No todo with id \(unknown) exists.")
        XCTAssertEqual((error["extensions"] as? [String: Any])?["status"] as? Int, 404)
    }

    func testInvalidQueryReportsValidationError() async throws {
        let response = try await send("{ doesNotExist }")

        let error = try XCTUnwrap(response.errors.first)
        XCTAssertTrue((error["message"] as? String)?.contains("doesNotExist") == true)
        XCTAssertNil(response.data)
    }

    func testInvalidUUIDArgumentIsRejected() async throws {
        let response = try await send("mutation { deleteTodo(id: \"not-a-uuid\") }")

        XCTAssertFalse(response.errors.isEmpty)
    }

    // MARK: - HTTP surface

    func testGetEndpointExecutesQueryParameter() async throws {
        _ = try await createUser("Alice")

        try await app.test(.GET, "graphql?query=%7B%20users%20%7B%20name%20%7D%20%7D", afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)
            XCTAssertTrue(response.body.string.contains("Alice"))
        })
    }

    func testGetEndpointWithoutQueryIsBadRequest() async throws {
        try await app.test(.GET, "graphql", afterResponse: { response async throws in
            XCTAssertEqual(response.status, .badRequest)
        })
    }

    func testGraphiQLIsServedInDevelopment() async throws {
        try await app.test(.GET, "/", afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)
            XCTAssertTrue(response.body.string.contains("GraphiQL"))
        })
    }
}
