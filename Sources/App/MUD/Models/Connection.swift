//
//  Connection.swift
//  
//
//  Created by Maarten Engels on 29/05/2021.
//

import Foundation
import Vapor
import Fluent

final class Connection: Model, Content {
    static let schema = "connections"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "creator_id")
    var creatorID: UUID
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "is_open")
    var isOpen: Bool
    
    @Field(key: "required_item_to_open")
    var requiredItemToOpen: String?
    
    @Field(key: "room1_id")
    var room1ID: UUID
    
    @Field(key: "room2_id")
    var room2ID: UUID
    
    init() {
    }
    
    init(creatorID: UUID, name: String = "", between room1: UUID, and room2: UUID, requiredItemToOpen: String? = nil) {
        self.creatorID = creatorID
        self.name = name
        self.requiredItemToOpen = requiredItemToOpen
        self.isOpen = true
        self.room1ID = room1
        self.room2ID = room2
    }
    
    static func makeDoor(playerID: UUID, connectionID: UUID, requiredItemToOpen: String? = nil, on req: Request) -> EventLoopFuture<[Message]> {
        return Connection.find(connectionID, on: req.db).flatMap { connection in
            guard let connection = connection else {
                return Message(playerID: playerID, message: "<WARNING>Could not find connection with id \(connectionID)</WARNING>").asMessagesArrayFuture(on: req)
            }
            
            guard connection.creatorID == playerID else {
                return Message(playerID: playerID, message: "<WARNING>Only the creator of the connection can change it.</WARNING>").asMessagesArrayFuture(on: req)
            }
            
            connection.name = "Door"
            connection.isOpen = false
            connection.requiredItemToOpen = requiredItemToOpen
            
            return connection.save(on: req.db).map {
                return [Message(playerID: playerID, message: "<ACTION>Connection is now a door.</ACTION>")]
            }
        }
    }
    
    static func changeConnection(playerID: UUID, connectionID: UUID, action: String, on req: Request) -> EventLoopFuture<[Message]> {
        switch action.uppercased() {
        case "DOOR":
            return makeDoor(playerID: playerID, connectionID: connectionID, on: req)
        default:
            return Message(playerID: playerID, message: "Unknown action \(action)").asMessagesArrayFuture(on: req)
        }
    }
 
    func getOtherRoomID(for roomID: UUID) -> UUID? {
        if room1ID == roomID {
            return room2ID
        } else if room2ID == roomID {
            return room1ID
        }
        return nil
    }
    
    func getRoomOnOtherSide(from roomID: UUID, on req: Request) -> EventLoopFuture<(connection: Connection, room: Room?)> {
        let otherRoomID = getOtherRoomID(for: roomID)
        
        return Room.find(otherRoomID, on: req.db).map { room in
            return (self, room)
        }
    }
}

struct CreateConnection: Migration {
    // Prepares the database for storing Galaxy models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Connection.schema)
            .id()
            .field("creator_id", .uuid)
            .field("name", .string)
            .field("is_open", .bool)
            .field("required_item_to_open", .string)
            .field("room1_id", .uuid)
            .field("room2_id", .uuid)
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Room.schema).delete()
    }
}
