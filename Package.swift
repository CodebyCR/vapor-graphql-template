// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "GraphQL-Todo",
    platforms: [.macOS(.v15)],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.1"),

        // 🔵 Swift ORM (queries, models, relations, etc) built on SQLite 3.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),

        // 🌐 GraphQL
        .package(url: "https://github.com/GraphQLSwift/GraphQL.git", from: "4.3.0"), // GraphQL Core
        .package(url: "https://github.com/GraphQLSwift/Graphiti.git", from: "3.1.0"), // Schema DSL
        .package(url: "https://github.com/alexsteinerde/graphiql-vapor.git", from: "2.5.0"), // Web Query Page
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "GraphQL", package: "GraphQL"),
                .product(name: "Graphiti", package: "Graphiti"),
                .product(name: "GraphiQLVapor", package: "graphiql-vapor"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ]),
    ]
)
