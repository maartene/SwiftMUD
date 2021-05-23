////
////  World.swift
////
////
////  Created by Maarten Engels on 21/05/2021.
////
//
//import Foundation
//
//struct World {
//    static var main = World()
//
//    var players = [Player]()
//    var rooms = [Room]()
//
//    mutating func parse(command: Command) -> String {
//        guard let player = getPlayerWithID(command.ownerID) else {
//            return "Could not find player with id \(command.ownerID)."
//        }
//
//        switch command.verb {
//        case "@dig":
//            return dig(digger: player)
//        case "look":
//            return look(player)
//        case "login":
//            return look(player)
//        case "move":
//            return move(player, exit: command.noun)
//        case "@describeRoom":
//            return changeRoomData(player, noun: command.noun, lens: Room.descriptionChanged)
//        case "@renameRoom":
//            return changeRoomData(player, noun: command.noun, lens: Room.nameChanged)
//        case "@describe":
//            return describe(roomID: player.currentRoomID)
//        default:
//            return "Unknown command \(command.verb)"
//        }
//    }
//
//    func getRoomWithID(_ id: UUID) -> Room? {
//        rooms.first(where: {$0.id == id})
//    }
//
//    func getPlayerWithID(_ id: UUID) -> Player? {
//        players.first(where: { $0.id == id })
//    }
//
//    mutating func replacePlayer(_ player: Player) {
//        if let index = players.firstIndex(where: { $0.id == player.id }) {
//            players[index] = player
//        } else {
//            print("Failed to find player \(player.name) in the world.")
//        }
//    }
//
//    mutating func replaceRoom(_ room: Room) {
//        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
//            rooms[index] = room
//        } else {
//            print("Failed to find room \(room.name) in the world.")
//        }
//    }
//
//    mutating func dig(digger player: Player) -> String {
//        var newRoom = Room(id: UUID(), creatorID: player.id!, name: "Empty room #\(rooms.count)", description: "There is nothing in the room.")
//
//        if var currentRoom = getRoomWithID(player.currentRoomID ?? UUID()) {
//            currentRoom.connections.append(newRoom.id)
//            newRoom.connections.append(currentRoom.id)
//            replaceRoom(currentRoom)
//        }
//
//        let movedPlayer = player.moved(to: newRoom.id)
//        replacePlayer(movedPlayer)
//        rooms.append(newRoom)
//        return "New room \(newRoom.name) created. You have been teleported there."
//    }
//
//    mutating func changeRoomData(_ player: Player, noun: String?, lens: (String, Room) -> Room) -> String {
//        guard let newData = noun else {
//            return "Missing new data for room. Room not changed."
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
//        replaceRoom(lens(newData, room))
//
//        return "Successfully changed room."
//    }
//
//    func getExitsForRoom(_ room: Room) -> String {
//        var result = "Exits: \n"
//        for i in 0 ..< room.connections.count {
//            result.append("\(i). \(getRoomWithID(room.connections[i])?.name ?? "nil")")
//        }
//        return result
//    }
//
//    func look(_ player: Player) -> String {
//        if let roomID = player.currentRoomID {
//            guard let room = getRoomWithID(roomID) else {
//                return "Could not find room with id \(roomID)."
//            }
//
//            return room.name + "\n" + room.description
//                + "\n" + getExitsForRoom(room)
//
//        } else {
//            return Room.room0.name + "\n" + Room.room0.description
//        }
//    }
//
//    func help() -> String {
//        """
//        Possible commands:
//        General commands:
//        LOOK: Gives a description of the current room including all exits
//        MOVE <exit number>: Go to the room indicated by the numbered exit
//
//        Build commands:
//        @dig: Create a new room
//        @renameRoom <new name>: Sets the current room's name to the value of <new name>.
//        @describeRoom <new description>: Sets the current room's description to the value of <new description>
//        @describe: Shows technical details for the current room.
//
//        """
//    }
//
//    func describe(roomID: UUID?) -> String {
//        guard let roomID = roomID else {
//            return "No room id passed."
//        }
//
//        guard let room = getRoomWithID(roomID) else {
//            return "Room with id \(roomID) not found."
//        }
//
//        return """
//            Room:
//            id: \(room.id)
//            created by: \(room.creatorID) \(getPlayerWithID(room.creatorID)?.name ?? "unknown player")
//            name: \(room.name)
//            description: \(room.description)
//            connections: \(room.connections)
//            """
//    }
//
//    mutating func move(_ player: Player, exit: String?) -> String {
//        guard let exitString = exit else {
//            return "Missing exit index to move to."
//        }
//        guard let exitIndex = Int(exitString) else {
//            return "Failed to convert '\(exitString)' to an integer."
//        }
//
//        guard let currentRoomID = player.currentRoomID else {
//            return "Player is not in a valid room."
//        }
//
//        guard let currentRoom = getRoomWithID(currentRoomID) else {
//            return "Player is not in a valid room."
//        }
//
//        guard (0 ..< currentRoom.connections.count).contains(exitIndex) else {
//            return "There is no exit numbered '\(exitIndex)'."
//        }
//
//        let newRoomID = currentRoom.connections[exitIndex]
//
//        let movedPlayer = player.moved(to: newRoomID)
//        replacePlayer(movedPlayer)
//
//        return look(movedPlayer)
//    }
//
////    mutating func changeRoomDescription(_ command: Command) -> String {
////        guard let player = getPlayerWithID(command.ownerID) else {
////            return "Could not find player with id \(command.ownerID)"
////        }
////
////        guard let roomID = player.currentRoomID else {
////            return "Player is not in a valid room."
////        }
////
////        guard let room = getRoomWithID(roomID) else {
////            return "Could not find room with id \(player.currentRoomID?.uuidString ?? "nil")"
////        }
////
////        replaceRoom(room.descriptionChanged(to: command.noun ?? "nil"))
////
////        return "Successfully changed description."
////    }
//}
