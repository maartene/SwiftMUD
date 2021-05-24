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
    
    @Field(key: "is_online")
    var isOnline: Bool
    
    init() {
        
    }
    
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
        self.isOnline = false
    }
    
    static func createUser(username: String, password: String, on req: Request) -> EventLoopFuture<[Message]> {
        let newPlayer = Player(name: username)
        newPlayer.isOnline = true
        
        return newPlayer.save(on: req.db).map {
            return [Message(playerID: newPlayer.id, message: "Successfully created player \(newPlayer). Welcome \(newPlayer.name)!")]
        }
    }
    
    func setOnlineStatus(_ status: Bool, on req: Request) -> EventLoopFuture<Void> {
        isOnline = status
        return self.save(on: req.db)
    }
}

struct CreatePlayer: Migration {
    // Prepares the database for storing Galaxy models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Player.schema)
            .id()
            .field("name", .string)
            .field("current_room_id", .uuid)
            .field("is_online", .bool)
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Player.schema).delete()
    }
}
