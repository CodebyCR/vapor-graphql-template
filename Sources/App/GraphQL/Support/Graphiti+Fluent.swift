import Fluent
import Graphiti
import Vapor

// Helpers that expose Fluent relationship properties as GraphQL fields.
// The relationship is loaded lazily from the database when the field is requested.

// MARK: - @Children

extension Graphiti.Field where Arguments == NoArguments, Context == Request, ObjectType: Model {
    /// Creates a GraphQL field for a one-to-many relationship.
    /// - Parameters:
    ///   - name: Field name
    ///   - keyPath: KeyPath to the `@Children` property
    public convenience init<ChildType: Model>(
        _ name: FieldKey,
        with keyPath: KeyPath<ObjectType, ChildrenProperty<ObjectType, ChildType>>
    ) where FieldType == [ChildType] {
        self.init(name.description, at: { object in
            { request, _ in
                try await object[keyPath: keyPath].query(on: request.db).all()
            }
        })
    }
}

// MARK: - @Parent

extension Graphiti.Field where Arguments == NoArguments, Context == Request, ObjectType: Model {
    /// Creates a GraphQL field for a many-to-one relationship.
    /// - Parameters:
    ///   - name: Field name
    ///   - keyPath: KeyPath to the `@Parent` property
    public convenience init(
        _ name: FieldKey,
        with keyPath: KeyPath<ObjectType, ParentProperty<ObjectType, FieldType>>
    ) where FieldType: Model {
        self.init(name.description, at: { object in
            { request, _ in
                try await object[keyPath: keyPath].get(on: request.db)
            }
        })
    }
}

// MARK: - @OptionalParent

extension Graphiti.Field where Arguments == NoArguments, Context == Request, ObjectType: Model {
    /// Creates a GraphQL field for an optional many-to-one relationship.
    /// - Parameters:
    ///   - name: Field name
    ///   - keyPath: KeyPath to the `@OptionalParent` property
    public convenience init<ParentType: Model>(
        _ name: FieldKey,
        with keyPath: KeyPath<ObjectType, OptionalParentProperty<ObjectType, ParentType>>
    ) where FieldType == ParentType? {
        self.init(name.description, at: { object in
            { request, _ in
                try await object[keyPath: keyPath].get(on: request.db)
            }
        })
    }
}

// MARK: - @OptionalChild

extension Graphiti.Field where Arguments == NoArguments, Context == Request, ObjectType: Model {
    /// Creates a GraphQL field for an optional one-to-one relationship.
    /// - Parameters:
    ///   - name: Field name
    ///   - keyPath: KeyPath to the `@OptionalChild` property
    public convenience init<ChildType: Model>(
        _ name: FieldKey,
        with keyPath: KeyPath<ObjectType, OptionalChildProperty<ObjectType, ChildType>>
    ) where FieldType == ChildType? {
        self.init(name.description, at: { object in
            { request, _ in
                try await object[keyPath: keyPath].get(on: request.db)
            }
        })
    }
}

// MARK: - @Siblings

extension Graphiti.Field where Arguments == NoArguments, Context == Request, ObjectType: Model {
    /// Creates a GraphQL field for a many-to-many relationship.
    /// - Parameters:
    ///   - name: Field name
    ///   - keyPath: KeyPath to the `@Siblings` property
    public convenience init<ToType: Model, ThroughType: Model>(
        _ name: FieldKey,
        with keyPath: KeyPath<ObjectType, SiblingsProperty<ObjectType, ToType, ThroughType>>
    ) where FieldType == [ToType] {
        self.init(name.description, at: { object in
            { request, _ in
                try await object[keyPath: keyPath].query(on: request.db).all()
            }
        })
    }
}
