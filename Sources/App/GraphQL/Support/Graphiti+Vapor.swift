import GraphQL
import Graphiti
import Vapor

/// The body of a GraphQL request as sent by GraphiQL and most clients.
struct GraphQLQueryRequest: Content {
    var query: String
    var operationName: String?
    var variables: [String: Map]?
}

extension RoutesBuilder {
    /// Registers a GraphQL endpoint that accepts `POST` requests with a JSON body
    /// and `GET` requests with `query`, `operationName` and `variables` query parameters.
    /// - Parameters:
    ///   - schema: The Graphiti schema to execute queries against.
    ///   - resolver: The root resolver instance.
    ///   - path: The route path, defaults to `graphql`.
    public func register<Resolver: Sendable>(
        graphQLSchema schema: Schema<Resolver, Request>,
        withResolver resolver: Resolver,
        at path: PathComponent = "graphql"
    ) {
        self.post(path) { request async throws -> Response in
            let query = try request.content.decode(GraphQLQueryRequest.self)
            return try await request.execute(query, schema: schema, resolver: resolver)
        }

        self.get(path) { request async throws -> Response in
            guard let queryString = request.query[String.self, at: "query"] else {
                throw Abort(.badRequest, reason: "Missing `query` parameter")
            }
            let variables = try request.query[String.self, at: "variables"].map {
                try JSONDecoder().decode([String: Map].self, from: Data($0.utf8))
            }
            let query = GraphQLQueryRequest(
                query: queryString,
                operationName: request.query[String.self, at: "operationName"],
                variables: variables
            )
            return try await request.execute(query, schema: schema, resolver: resolver)
        }
    }
}

extension Request {
    fileprivate func execute<Resolver: Sendable>(
        _ query: GraphQLQueryRequest,
        schema: Schema<Resolver, Request>,
        resolver: Resolver
    ) async throws -> Response {
        var result = try await schema.execute(
            request: query.query,
            resolver: resolver,
            context: self,
            variables: query.variables ?? [:],
            operationName: query.operationName
        )
        // Vapor's `Abort` describes itself as "Abort.404: reason". Clients get the reason as the
        // message and the HTTP status code in `extensions`, matching how REST routes would report it.
        result.errors = result.errors.map { error in
            guard let abort = error.originalError as? AbortError else {
                return error
            }
            var extensions = error.extensions
            extensions["status"] = .int(Int(abort.status.code))
            return GraphQLError(
                message: abort.reason,
                locations: error.locations,
                path: error.path,
                extensions: extensions
            )
        }
        // GraphQL reports errors inside the response body with HTTP 200, so Vapor never sees them.
        // Log them here so that resolver failures do not go unnoticed on the server.
        for error in result.errors {
            if error.path.elements.isEmpty {
                // No path means the query itself was invalid: a client mistake.
                self.logger.notice("GraphQL request rejected: \(error.message)")
            } else {
                let path = error.path.elements.map(\.description).joined(separator: ".")
                self.logger.error("GraphQL resolver failed at \(path): \(error.message)")
            }
        }
        // `GraphQLJSONEncoder` keeps the field order of the query in the response.
        let body = try GraphQLJSONEncoder().encode(result)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }
}
