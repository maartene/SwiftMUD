//
//  Room.swift
//  
//
//  Created by Maarten Engels on 21/05/2021.
//

import Foundation
import Fluent
import Vapor

final class Room: Model, Content {
    static let schema = "rooms"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "creator_id")
    var creatorID: UUID
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "connections")
    var connections: [UUID]
    
    init() { }
    
    init(creatorID: UUID, name: String, description: String) {
        self.creatorID = creatorID
        self.name = name
        self.description = description
        self.connections = [UUID]()
    }
}

struct CreateRoom: Migration {
    // Prepares the database for storing Galaxy models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Room.schema)
            .id()
            .field("creator_id", .uuid)
            .field("name", .string)
            .field("description", .string)
            .field("connections", .array(of: .uuid))
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Room.schema).delete()
    }
}
