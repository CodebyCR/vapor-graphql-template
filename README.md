# GraphQL Vapor Template

[![Language](https://img.shields.io/badge/Swift-6.1-brightgreen.svg)](http://swift.org)
[![Vapor Version](https://img.shields.io/badge/Vapor-4-F6CBCA.svg)](http://vapor.codes)

This is a template that can be used to create Vapor applications that include GraphQL APIs. It's based on [GraphQL](https://github.com/GraphQLSwift/GraphQL), [Graphiti](https://github.com/GraphQLSwift/Graphiti) and ships its own small set of Vapor and Fluent helpers in `Sources/App/GraphQL/Support` (the former [GraphQLKit](https://github.com/alexsteinerde/graphql-kit) is no longer needed).

## Getting Started

### Requirements

- Swift 6.1 or newer (Xcode 16.4 or newer on macOS 15)
- Optionally [Apple's `container`](https://github.com/apple/container) or Docker to run the server in a container

### Run locally

```bash
swift run Run serve
```

The server listens on `http://127.0.0.1:8080`. In the default `development` environment the GraphiQL web interface is served at `http://127.0.0.1:8080/` and the GraphQL endpoint at `/graphql`. The endpoint accepts `POST` requests with a JSON body (`query`, `operationName`, `variables`) and `GET` requests with the same values as query parameters.

Run in production mode to disable GraphiQL:

```bash
swift run -c release Run serve --env production
```

### Run with Apple's `container`

`container.sh` builds the image from the `Dockerfile`, starts the container service if needed and publishes the port on `127.0.0.1`:

```bash
./container.sh            # build if needed and start in production mode
DEV=1 ./container.sh      # development mode with GraphiQL at /
PORT=9000 ./container.sh  # publish on a different host port
./container.sh rebuild    # rebuild the image without cache, then start
./container.sh logs       # follow the server log
./container.sh status     # show whether the container is running
./container.sh stop       # stop and remove the container
```

The database is stored in `./data` on the host (override with `DATA_DIR`) and survives container restarts. The first build downloads the Swift toolchain and compiles all dependencies, which takes a few minutes.

The same image works with Docker:

```bash
docker build -t vapor-graphql-template .
docker run --rm -p 127.0.0.1:8080:8080 -v "$PWD/data:/app/data" vapor-graphql-template
```

### Database

The template uses SQLite. Outside of tests the database is a file, `db.sqlite` in the working directory by default. Set `DATABASE_PATH` to change the location; the container image sets it to `/app/data/db.sqlite`. Migrations run automatically on start. Tests use a fresh in-memory database for every test case.

### Tests

```bash
swift test
```

The tests in `Tests/AppTests` send real HTTP requests through the Vapor application and cover all queries, mutations, relationship fields, cascading deletes and the error responses.

### Errors

GraphQL reports errors in the response body with HTTP status 200. Errors thrown as Vapor `Abort` in a resolver are returned with their reason as the message and the HTTP status in `extensions`:

```json
{
  "errors": [
    {
      "message": "No todo with id 1F3F5F3E-… exists.",
      "locations": [{ "line": 1, "column": 12 }],
      "path": ["deleteTodo"],
      "extensions": { "status": 404 }
    }
  ]
}
```

Every error is also written to the server log: resolver failures at `error` level, rejected queries at `notice` level.

### Project structure

- `Sources/App/Models` – Fluent models (`User`, `Todo`, `Tag` and the `TodoTag` pivot)
- `Sources/App/Migrations` – database schema with foreign keys and cascading deletes
- `Sources/App/GraphQL/TodoSchema.swift` – the Graphiti schema definition
- `Sources/App/GraphQL/TodoResolver.swift` – the resolver functions behind queries and mutations
- `Sources/App/GraphQL/Support` – helpers that expose Fluent relationships as GraphQL fields and register the endpoint in Vapor

## Example Queries:

### Query

```graphql
# Quering all todos with its ids and titles.
query GetAllTodos {
  todos {
    id
    title
    tags {
      title
    }
    user {
      name
    }
  }
}

# But we can also just query ids and it will only send them without the title data.
query GetTodoIDs {
  todos {
    id
  }
}

# We can also query all users and their specific todos.
query GetAllUsersWithTodos {
  users {
    id
    todos {
      id
      title
    }
  }
}

# Quering all tags with its ids and titles.
query GetAllTags {
  tags {
    id
    title
    todos {
      title
    }
  }
}

# We can pass an argument directly to the query
mutation createUser {
  createUser(name: "Jess") {
    id
    name
    createdAt
  }
}

# We can pass multiple arguments directly to the query
mutation createTodo($userId: UUID!) {
  createTodo(title: "Use GraphQL", userID: $userId) {
    id
    title
  }
}

# Or we can also define parameters that are fetched from the JSON formatted parameters field below.
mutation deleteTodo($todoId: UUID!) {
  deleteTodo(id: $todoId)
}

# Deleting a user also deletes all of their todos.
mutation deleteUser($userId: UUID!) {
  deleteUser(id: $userId)
}

# Create a new tag
mutation createTag {
  createTag(title: "Important") {
    id
  }
}

# Assign a tag to a todo item
mutation addTag2Todo($todoId: UUID!, $tagId: UUID!) {
  addTagToTodo(tagID: $tagId, todoID: $todoId)
}
```

### Parameters

```json
{
  "userId": "<Generated User Id>",
  "todoId": "<Generated Todo Id>",
  "tagId": "<Generated Tag Id>"
}
```
