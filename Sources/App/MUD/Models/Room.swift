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
    
//    @Field(key: "connections")
//    var connections: [UUID]
    
    @Field(key: "items")
    var items: [Item]
    
    init() { }
    
    init(creatorID: UUID, name: String, description: String) {
        self.creatorID = creatorID
        self.name = name
        self.description = description
        //self.connections = [UUID]()
        self.items = [Item]()
    }
    
    func getConnections(on req: Request) -> EventLoopFuture<[Connection]> {
        guard let roomID = id else {
            req.logger.warning("getConnections only works on rooms that already have an id.")
            return req.eventLoop.makeSucceededFuture([])
        }
        
        return Connection.query(on: req.db).group(.or) { group in
            group.filter(\.$room1ID == roomID).filter(\.$room2ID == roomID)
        }.all()
    }
    
    var technicalDescription: String {
        """
        ID:             \(id?.uuidString ?? "Not set")
        Created by:     \(creatorID)
        Name:           \(name)
        Description:    \(description)
        Items:          \(items)
        """
    }
    
    static func getTechnicalDescription(playerID: UUID, roomID: UUID, on req: Request) -> EventLoopFuture<[Message]> {
        return Room.find(roomID, on: req.db).flatMap { room in
            return Connection.query(on: req.db).group(.or) { group in
                group.filter(\.$room1ID == roomID).filter(\.$room2ID == roomID)
            }.all().map { connections in
                var result = room?.technicalDescription ?? "<WARNING>No room found with id \(roomID)</WARNING>\n"
                result += "Connections: \n"
                for connection in connections {
                    result += "\(connection).technicalDescription\n"
                }
                return [Message(playerID: playerID, message: result)]
            }
            
            
        }
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
            //.field("connections", .array(of: .uuid))
            .field("items", .array(of: .custom(Item.self)))
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Room.schema).delete()
    }
}
