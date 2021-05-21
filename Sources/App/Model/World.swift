//
//  World.swift
//  
//
//  Created by Maarten Engels on 21/05/2021.
//

import Foundation

struct World {
    static var main = World()
    
    var players = [Player]()
    var rooms = [Room]()
    
    mutating func parse(command: Command) -> String {
        guard let player = getPlayerWithID(command.ownerID) else {
            return "Could not find player with id \(command.ownerID)."
        }
        
        switch command.verb {
        case "@dig":
            return dig(command)
        case "look":
            if let roomID = player.currentRoomID {
                guard let room = getRoomWithID(roomID) else {
                    return "Could not find room with id \(roomID)."
                }
                
                return room.name + "\n" + room.description
                    + "\n" + getExitsForRoom(room)
                
            } else {
                return Room.room0.name + "\n" + Room.room0.description
            }
        case "login":
            if let roomID = player.currentRoomID {
                guard let room = getRoomWithID(roomID) else {
                    return "Could not find room with id \(roomID)."
                }
                
                return room.name + "\n" + room.description
                
            } else {
                return Room.room0.name + "\n" + Room.room0.description
            }
        case "@describeRoom":
            return changeRoomData(command, lens: Room.descriptionChanged)
        case "@renameRoom":
            return changeRoomData(command, lens: Room.nameChanged)
        default:
            return "Unknown command \(command.verb)"
        }
        
        if let roomID = player.currentRoomID {
            guard let room = getRoomWithID(roomID) else {
                return "Could not find room with id \(roomID)."
            }
            
            return room.name + "\n" + room.description
            
        } else {
            return Room.room0.name + "\n" + Room.room0.description
        }
    }
    
    func getRoomWithID(_ id: UUID) -> Room? {
        rooms.first(where: {$0.id == id})
    }
    
    func getPlayerWithID(_ id: UUID) -> Player? {
        players.first(where: { $0.id == id })
    }
    
    mutating func replacePlayer(_ player: Player) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index] = player
        } else {
            print("Failed to find player \(player.name) in the world.")
        }
    }
    
    mutating func replaceRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
        } else {
            print("Failed to find room \(room.name) in the world.")
        }
    }
    
    mutating func dig(_ command: Command) -> String {
        var newRoom = Room(id: UUID(), creatorID: command.ownerID, name: "Empty room", description: "There is nothing in the room.")
        
        guard let player = getPlayerWithID(command.ownerID) else {
            return "Could not find player with id \(command.ownerID)."
        }
        
        if var currentRoom = getRoomWithID(player.currentRoomID ?? UUID()) {
            currentRoom.connections.append(newRoom.id)
            newRoom.connections.append(currentRoom.id)
            replaceRoom(currentRoom)
        }
        
        if let movedPlayer = getPlayerWithID(command.ownerID)?.moved(to: newRoom.id) {
            replacePlayer(movedPlayer)
            rooms.append(newRoom)
            return "New room \(newRoom.name) created. You have been teleported there."
        }
        
        return "Failed to create new room."
        
        
    }
    
    mutating func changeRoomData(_ command: Command, lens: (String, Room) -> Room) -> String {
        guard let player = getPlayerWithID(command.ownerID) else {
            return "Could not find player with id \(command.ownerID)"
        }
        
        guard let roomID = player.currentRoomID else {
            return "Player is not in a valid room."
        }
        
        guard let room = getRoomWithID(roomID) else {
            return "Could not find room with id \(player.currentRoomID?.uuidString ?? "nil")"
        }
        
        replaceRoom(lens(command.noun ?? "nil", room))
        
        return "Successfully changed room."
    }
    
    func getExitsForRoom(_ room: Room) -> String {
        var result = "Exits: \n"
        for i in 0 ..< room.connections.count {
            result.append("\(i + 1). \(getRoomWithID(room.connections[i])?.name ?? "nil")")
        }
        return result
    }
    
//    mutating func changeRoomDescription(_ command: Command) -> String {
//        guard let player = getPlayerWithID(command.ownerID) else {
//            return "Could not find player with id \(command.ownerID)"
//        }
//
//        guard let roomID = player.currentRoomID else {
//            return "Player is not in a valid room."
//        }
//
//        guard let room = getRoomWithID(roomID) else {
//            return "Could not find room with id \(player.currentRoomID?.uuidString ?? "nil")"
//        }
//
//        replaceRoom(room.descriptionChanged(to: command.noun ?? "nil"))
//
//        return "Successfully changed description."
//    }
}
