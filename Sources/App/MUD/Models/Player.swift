//
//  Player.swift
//  
//
//  Created by Maarten Engels on 21/05/2021.
//

import Foundation
import Fluent
import Vapor

final class Player: Model, Content {
    static let schema = "players"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "current_room_id")
    var currentRoomID: UUID?
    
    init() {
        
    }
    
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
    
    func moved(to roomID: UUID) -> Player {
        var movedPlayer = self
        movedPlayer.currentRoomID = roomID
        return movedPlayer
    }
}

struct CreatePlayer: Migration {
    // Prepares the database for storing Galaxy models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Player.schema)
            .id()
            .field("name", .string)
            .field("current_room_id", .uuid)
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Player.schema).delete()
    }
}
