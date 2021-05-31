//
//  File.swift
//  
//
//  Created by Maarten Engels on 24/05/2021.
//

import Foundation
import Vapor
import Fluent

struct GameState {
    static func loginUser(username: String, password: String, on req: Request) -> EventLoopFuture<[Message]> {
        req.logger.debug("Login attempt with userid \(username) and password \(password).")
        return Player.query(on: req.db)
            .filter(\.$name == username).first().flatMap { player in
            if let player = player {
                return player.setOnlineStatus(true, on: req).flatMap {
                    return Room.find(player.currentRoomID, on: req.db).flatMap { room in
                        return getPlayersInRoom(player.currentRoomID, on: req).map { otherPlayers in
                            var messages = [Message(playerID: player.id, message: "Successfully logged in. Welcome back \(player.name)!")]
                            if let room = room {
                                messages.append(contentsOf: roomEnterMessages(player: player, room: room, roomPlayers: otherPlayers))
                            }
                            return messages
                        }
                    }
                }
            } else {
                return Message(playerID: nil, message: "Failed to log in").asMessagesArrayFuture(on: req)
            }
        }
    }
    
    static func getPlayerRoomAndAllPlayers(for playerID: UUID, onlinePlayersOnly: Bool = true, on req: Request) -> EventLoopFuture<(player: Player?, room: Room?, roomPlayers: [Player])> {
        return Player.find(playerID, on: req.db).flatMap { player in
            guard let player = player else {
                return req.eventLoop.makeSucceededFuture((nil, nil, []))
            }
            
            return Room.find(player.currentRoomID, on: req.db).flatMap { room in
                guard let room = room else {
                    return req.eventLoop.makeSucceededFuture((player, nil, []))
                }
                
                return Player.query(on: req.db).filter(\.$currentRoomID == room.id).all().map { players in
                    if onlinePlayersOnly {
                        return (player, room, players.filter({ $0.isOnline }))
                    } else {
                        return (player, room, players)
                    }
                    
                }
            }
        }
    }
    
    static func say(playerID: UUID, sentence: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).map { result in
            guard let player = result.player else {
                return [Message(playerID: playerID, message: "<WARNING>Could not find player with id \(playerID).</WARNING>")]
            }
            var messages = [Message]()
            messages.append(Message(playerID: playerID, message: "<ACTION>You say:</ACTION> \(sentence)"))
            
            for roomPlayer in result.roomPlayers {
                if roomPlayer.id != player.id {
                    messages.append(Message(playerID: roomPlayer.id, message: "<PLAYER>\(player.name) says:</PLAYER> \(sentence)"))
                }
            }
            
            return messages
        }
    }
    
    static func whisper(playerID: UUID, targetPlayerName: String, sentence: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).map { result in
            guard let player = result.player else {
                return [Message(playerID: playerID, message: "<ERROR>Could not find player with id \(playerID).</ERROR>")]
            }
            
            guard let targetPlayer = result.roomPlayers.first(where: {$0.name == targetPlayerName}) else {
                return [Message(playerID: playerID, message: "<WARNING>\(targetPlayerName) is not in the room.</WARNING>")]
            }
            
            var messages = [Message]()
            messages.append(Message(playerID: playerID, message: "<ACTION>You say:</ACTION> \(sentence) to <PLAYER>\(targetPlayerName)</PLAYER>"))
            
            for roomPlayer in result.roomPlayers {
                if roomPlayer.id == targetPlayer.id {
                    messages.append(Message(playerID: roomPlayer.id, message: "<PLAYER>\(player.name) says </PLAYER> '\(sentence)' to you."))
                } else if roomPlayer.id != player.id {
                    messages.append(Message(playerID: roomPlayer.id, message: "<PLAYER>\(player.name)<PLAYER> whispers something to <PLAYER>\(targetPlayerName)</PLAYER>"))
                }
            }
            
            return messages
        }
    }
    
    static func dig(owner: UUID, on req: Request) -> EventLoopFuture<[Message]> {
        let newRoom = Room(creatorID: owner, name: "Empty room #\(Int.random(in: 0...1000))", description: "There is nothing in this room.")
        
        return Player.find(owner, on: req.db).flatMap { player in
            guard let player = player else {
                fatalError("Could not find player with id \(owner)")
            }
            
            return newRoom.save(on: req.db).flatMap {
                if let currentRoomID = player.currentRoomID {
                    let connection = Connection(creatorID: owner, between: currentRoomID, and: newRoom.id!)
                    connection.save(on: req.db).map {
                        req.logger.info("Done saving connection \(connection.id?.uuidString ?? "")")
                    }
                }
                player.currentRoomID = newRoom.id
                return player.save(on: req.db).map {
                    return [Message(playerID: player.id, message: "<ACTION>Successfully created new room \(newRoom). You have been teleported into the new room.</ACTION>")]
                }
            }
        }
    }

    static func changeRoomData(playerID: UUID, newName: String? = nil, newDescription: String? = nil, on req: Request) -> EventLoopFuture<[Message]> {
        guard newName != nil || newDescription != nil else {
            return Message(playerID: playerID, message: "No new name or description received. Room remains unchanged.").asMessagesArrayFuture(on: req)
        }
        
        return Player.find(playerID, on: req.db).flatMap { player in
            guard let player = player else {
                return Message(playerID: playerID, message: "No player found with id \(playerID)").asMessagesArrayFuture(on: req)
            }
            
            guard let currentRoomID = player.currentRoomID else {
                return Message(playerID: playerID, message: "Player is not in a valid room.").asMessagesArrayFuture(on: req)
            }
            
            return Room.find(currentRoomID, on: req.db).flatMap { room in
                guard let room = room else {
                    return Message(playerID: playerID, message: "No room found with id \(currentRoomID)").asMessagesArrayFuture(on: req)
                }
                
                guard room.creatorID == player.id else {
                    return Message(playerID: player.id, message: "Only rooms creator can change description.").asMessagesArrayFuture(on: req)
                }
                
                room.name = newName ?? room.name
                room.description = newDescription ?? room.description
                
                return room.save(on: req.db).map {
                    return [Message(playerID: player.id, message: "Succesfully changed room.")]
                }
            }
        }
    }
    
    static func go(playerID: UUID, exit: String, on req: Request) -> EventLoopFuture<[Message]> {
        guard let exitIndex = Int(exit) else {
            return Message(playerID: playerID, message: "Could not convert \(exit) to a number.").asMessagesArrayFuture(on: req)
        }
        
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).flatMap { currentRoomResult in
            guard let player = currentRoomResult.player else {
                fatalError()
            }
            
            guard let currentRoom = currentRoomResult.room else {
                fatalError()
            }
            
            guard let currentRoomID = currentRoom.id else {
                fatalError()
            }
            
            return currentRoom.getConnections(on: req).flatMap { unsortedConnections in
                let connections = unsortedConnections.sorted(by: { $0.getOtherRoomID(for: currentRoomID)?.uuidString ?? "" < $1.getOtherRoomID(for: currentRoomID)?.uuidString ?? "" })

                guard (0 ..< connections.count).contains(exitIndex) else {
                    return Message(playerID: playerID, message: "No exit with index \(exitIndex) is available in this room.").asMessagesArrayFuture(on: req)
                }
                
                let connection = connections[exitIndex]
                
                guard connection.isOpen else {
                    return Message(playerID: playerID, message: "The \(connection.name) is closed.").asMessagesArrayFuture(on: req)
                }
                
                let newRoomID = connection.getOtherRoomID(for: currentRoomID)
                
                player.currentRoomID = newRoomID
                
                return getPlayersInRoom(newRoomID, on: req).flatMap { newRoomPlayers in
                    return Room.find(newRoomID, on: req.db).flatMap { newRoom in
                        guard let newRoom = newRoom else {
                            fatalError()
                        }
                        
                        return player.save(on: req.db).map {
                            var messages = roomEnterMessages(player: player, room: newRoom, roomPlayers: newRoomPlayers)
                            messages.append(contentsOf: roomLeaveMessages(player: player, room: currentRoom, roomPlayers: currentRoomResult.roomPlayers))
                            return messages
                        }
                    }
                }
            }
        }
    }
    
    static func teleport(playerID: UUID, roomIDString: String, on req: Request) -> EventLoopFuture<[Message]> {
        return Player.find(playerID, on: req.db).flatMap { player in
            guard let player = player else {
                return Message(playerID: playerID, message: "No player found with id \(playerID)").asMessagesArrayFuture(on: req)
            }
            
        
            guard let roomID = UUID(uuidString: roomIDString) else {
                return Message(playerID: playerID, message: "\(roomIDString) is not a valid room ID").asMessagesArrayFuture(on: req)
            }
            
            return Room.find(player.currentRoomID, on: req.db).flatMap { currentRoom in
                return Room.find(roomID, on: req.db).flatMap { room in
                    guard let room = room else {
                        return Message(playerID: player.id, message: "Room with id \(roomID) does not exist.").asMessagesArrayFuture(on: req)
                    }
                    
                    return getPlayersInRoom(roomID, on: req).flatMap { roomPlayers in
                        player.currentRoomID = roomID
                        //print(roomPlayers)
                        return getPlayersInRoom(currentRoom?.id, on: req).flatMap { currentRoomPlayers in
                            return player.save(on: req.db).map {
                                var messages = roomEnterMessages(player: player, room: room, roomPlayers: roomPlayers)
                                messages.append(contentsOf: roomLeaveMessages(player: player, room: room, roomPlayers: currentRoomPlayers))
                                return messages
                            }
                        }
                        
                    }
                }
            }
        }
    }
    
    static func roomEnterMessages(player: Player, room: Room, roomPlayers: [Player]) -> [Message] {
        var result = [Message]()
        result.append(Message(playerID: player.id, message: "<ACTION>Entered room \(room.name)</ACTION>"))
        for roomPlayer in roomPlayers {
            if roomPlayer.id != player.id {
                result.append(Message(playerID: roomPlayer.id, message: "<INFO>\(player.name ) entered the room.</INFO>"))
            }
        }
        //print(result)
        return result
    }
    
    static func roomLeaveMessages(player: Player, room: Room, roomPlayers: [Player]) -> [Message] {
        var result = [Message]()
//        result.append(Message(playerID: player.id, message: "Entered room \(room.name)"))
        for roomPlayer in roomPlayers {
            if roomPlayer.id != player.id {
                result.append(Message(playerID: roomPlayer.id, message: "<INFO>\(player.name ) leaved the room.</INFO>"))
            }
        }
        //print(result)
        return result
    }
    
    
    static func openExit(playerID: UUID, exitIndex: String, on req: Request) -> EventLoopFuture<[Message]> {
        guard let exitIndex = Int(exitIndex) else {
            return Message(playerID: playerID, message: "Could not convert \(exit) to a number.").asMessagesArrayFuture(on: req)
        }
        
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).flatMap { currentRoomResult in
            guard let player = currentRoomResult.player else {
                fatalError()
            }
            
            guard let currentRoom = currentRoomResult.room else {
                fatalError()
            }
            
            guard let currentRoomID = currentRoom.id else {
                fatalError()
            }
            
            return currentRoom.getConnections(on: req).flatMap { unsortedConnections in
                let connections = unsortedConnections.sorted(by: { $0.getOtherRoomID(for: currentRoomID)?.uuidString ?? "" < $1.getOtherRoomID(for: currentRoomID)?.uuidString ?? "" } )
                
                guard (0 ..< connections.count).contains(exitIndex) else {
                    return Message(playerID: playerID, message: "No exit with index \(exitIndex) is available in this room.").asMessagesArrayFuture(on: req)
                }
                
                let connection = connections[exitIndex]
                
                guard connection.isOpen == false else {
                    return Message(playerID: playerID, message: "The exit is already open.").asMessagesArrayFuture(on: req)
                }
                
                if let requiredItem = connection.requiredItemToOpen {
                    return Message(playerID: playerID, message: "The exit requires \(requiredItem) to open.").asMessagesArrayFuture(on: req)
                } else {
                    connection.isOpen = true
                }
                
                return connection.save(on: req.db).map {
                    var messages = [Message(playerID: playerID, message: "<ACTION>You opened the <ITEM>\(connection.name)</ITEM>")]
                    for roomPlayer in currentRoomResult.roomPlayers {
                        if roomPlayer.id != player.id {
                            messages.append(Message(playerID: roomPlayer.id, message: "<PLAYER>\(player.name)</PLAYER> opened the <ITEM>\(connection.name)</ITEM>."))
                        }
                    }
                    return messages
                }
            }
        }
    }
    
    static func describeRoom(playerID: UUID, on req: Request) -> EventLoopFuture<[Message]> {
        return Player.find(playerID, on: req.db).flatMap { player in
            guard let player = player else {
                return Message(playerID: nil, message: "<ERROR>Could not find player with id \(playerID)</ERROR>").asMessagesArrayFuture(on: req)
            }
            
            guard let roomID = player.currentRoomID else {
                return Message(playerID: player.id, message: "VOID ROOM").asMessagesArrayFuture(on: req)
            }
            
            return Room.find(roomID, on: req.db).flatMap { room in
                guard let room = room else {
                    return Message(playerID: player.id, message: "<WARNING>Could not find room with id \(roomID)</WARNING>").asMessagesArrayFuture(on: req)
                }
                
                return room.getConnections(on: req).flatMap { connections in
                    return getPlayersInRoom(roomID, on: req).flatMap { roomPlayers in
                        let roomPlayers = roomPlayers.sorted(by: { $0.id?.uuidString ?? "" < $1.id?.uuidString ?? "" })
                        
                        //let connections = connections.compactMap( { $0.id != nil ? $0 : nil })
                        let otherRoomFutures = connections.map { $0.getRoomOnOtherSide(from: roomID, on: req) }
                        
                        return otherRoomFutures.flatten(on: req.eventLoop).map { otherRoomsAndConnections in
                            let sortedOtherRoomsAndConnections = otherRoomsAndConnections.sorted(by: { c1, c2 in
                                c1.connection.id?.uuidString ?? "" < c2.connection.id?.uuidString ?? ""
                            })
                                                    
                            var text = "<STRONG>" + room.name + "</STRONG>\n"
                            text += room.description + "\n"
                            
                            text += "<STRONG>Items:</STRONG>\n"
                            for i in 0 ..< room.items.count {
                                text += "<ITEM>" + room.items[i].name + "</ITEM>\n"
                            }
                            
                            text += "<STRONG>Exits:</STRONG>\n"
                            for i in 0 ..< sortedOtherRoomsAndConnections.count {
                                let roomAndConnection = sortedOtherRoomsAndConnections[i]
                                if roomAndConnection.connection.isOpen == false {
                                    text += "\(i). A <ITEM>" + roomAndConnection.connection.name + "</ITEM> is blocking this exit\n"
                                } else {
                                    text += "<EXIT>\(i). " + (roomAndConnection.room?.name ?? "unknown room") + "</EXIT>\n"
                                }
                            }
                            
                            text += "<STRONG>Other players:</STRONG>\n"
                            for i in 0 ..< roomPlayers.count {
                                if roomPlayers[i].id != player.id {
                                    text += "<PLAYER>\(roomPlayers[i].name)</PLAYER>"
                                }
                            }
                            text += "\n"
                            
                            return [Message(playerID: player.id, message: text)]
                        }
                        
                        
                    }
                }
            }
        }
        /*
        var result = "\n"
        if world.currentRoom.isDark && world.flags.contains("light") == false {
            result += "It's too dark to see.\n"
        } else {
            result += showDescription()
            result += showExits()
            result += showItems()
            result += showDoors()
        }
        return result*/
    }
    
    static func getPlayersInRoom(_ roomID: UUID?, onlinePlayersOnly: Bool = true, on req: Request) -> EventLoopFuture<[Player]> {
        return Player.query(on: req.db).filter(\.$currentRoomID == roomID).all().map { players in
            if onlinePlayersOnly {
                return players.filter( { $0.isOnline })
            } else {
                return players
            }
        }
    }
    
    static func getTechnicalRoomDescription(playerID: UUID, objectName: String, on req: Request) -> EventLoopFuture<[Message]> {
        
        if objectName.uppercased() == "CURRENT" {
            return Player.find(playerID, on: req.db).flatMap { player in
                guard let player = player else {
                    fatalError()
                }
                
                guard let currentRoomID = player.currentRoomID else {
                    fatalError()
                }
                
                return Room.getTechnicalDescription(playerID: playerID, roomID: currentRoomID, on: req)
            }
        } else {
            if let roomID = UUID(uuidString: objectName) {
                return Room.getTechnicalDescription(playerID: playerID, roomID: roomID, on: req)
            } else {
                return Message(playerID: playerID, message: "'\(objectName)' is not a valid UUID.").asMessagesArrayFuture(on: req)
            }
        }
    }
    
    static func createItem(creator: UUID, objectName: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: creator, on: req).flatMap { result in
            let newItem = Item(name: objectName, description: "New item")
            
            guard let room = result.room else {
                return Message(playerID: creator, message: "Could not find room.").asMessagesArrayFuture(on: req)
            }
            
            room.items.append(newItem)
            
            return room.save(on: req.db).map {
                return [Message(playerID: creator, message: "Successfully created \(newItem)")]
            }
        }
    }
    
    static func pickupItem(playerID: UUID, itemName: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).flatMap { result in
            guard let player = result.player else {
                return Message(playerID: nil, message: "<ERROR>Could not find player with id \(playerID).</ERROR>").asMessagesArrayFuture(on: req)
            }
            
            guard let room = result.room else {
                return Message(playerID: player.id, message: "<WARNING>Could not find room with id \(player.currentRoomID?.uuidString ?? "unknown").</WARNING>").asMessagesArrayFuture(on: req)
            }
                
            guard let index = room.items.firstIndex(where: { $0.name.uppercased() == itemName.uppercased() }) else {
                return Message(playerID: player.id, message: "<WARNING>There is no \(itemName) in this room.</WARNING>").asMessagesArrayFuture(on: req)
            }
                
            let item = room.items[index]
                
            player.inventory.append(item)
            room.items.remove(at: index)
            
            return player.save(on: req.db).flatMap {
                return room.save(on: req.db).map {
                    var messages = [Message(playerID: playerID, message: "You picked up <ITEM>\(item.name)</ITEM>")]
                    for roomPlayer in result.roomPlayers {
                        if roomPlayer.id != player.id {
                            messages.append(Message(playerID: roomPlayer.id, message: "\(player.name) picked up the <ITEM>\(item.name)</ITEM>"))
                        }
                    }
                    return messages
                }
            }
        }
    }
    
    static func dropItem(playerID: UUID, itemName: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).flatMap { result in
            guard let player = result.player else {
                return Message(playerID: nil, message: "<ERROR>Could not find player with id \(playerID).</ERROR>").asMessagesArrayFuture(on: req)
            }
            
            guard let room = result.room else {
                return Message(playerID: player.id, message: "<WARNING>Could not find room with id \(player.currentRoomID?.uuidString ?? "unknown").</WARNING>").asMessagesArrayFuture(on: req)
            }
                
            guard let index = player.inventory.firstIndex(where: { $0.name.uppercased() == itemName.uppercased() }) else {
                return Message(playerID: player.id, message: "<WARNING>You are not carrying a \(itemName).</WARNING>").asMessagesArrayFuture(on: req)
            }
                
            let item = player.inventory[index]
                
            player.inventory.remove(at: index)
            room.items.append(item)
            
            return room.save(on: req.db).flatMap {
                return player.save(on: req.db).map {
                    var messages = [Message(playerID: playerID, message: "You dropped the <ITEM>\(item.name)</ITEM>")]
                    for roomPlayer in result.roomPlayers {
                        if roomPlayer.id != player.id {
                            messages.append(Message(playerID: roomPlayer.id, message: "\(player.name) dropped the <ITEM>\(item.name)</ITEM>"))
                        }
                    }
                    return messages
                }
            }
        }
    }
    
    static func lookAt(playerID: UUID, lookedAtName: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).map { result in
            guard let player = result.player else {
                return [Message(playerID: nil, message: "<ERROR>Could not find player with id \(playerID)</ERROR>")]
            }
            
            // add doors and exists
            
            if let item = player.inventory.first(where: { $0.name.uppercased() == lookedAtName.uppercased() }) {
                return [Message(playerID: player.id, message: "\(item.description)")]
            } else if let room = result.room {
                if let item = room.items.first(where: { $0.name.uppercased() == lookedAtName.uppercased() }) {
                    return [Message(playerID: player.id, message: "\(item.description)")]
                } else if let lookedAtPlayer = result.roomPlayers.first(where: { $0.name.uppercased() == lookedAtName.uppercased() }) {
                    return [
                    Message(playerID: player.id, message: "You look at <PLAYER>\(lookedAtPlayer.name)</PLAYER>"),
                    Message(playerID: lookedAtPlayer.id, message: "<PLAYER>\(player.name)</PLAYER> is looking at you.")]
                }
            }
            
            return [Message(playerID: player.id, message: "You are not carrying, nor is there a <ITEM>\(lookedAtName)</ITEM> in the room.")]
        }
        
    }
    
    static func getPlayerAndRoom(playerID: UUID, on req: Request) -> EventLoopFuture<(player: Player?, room: Room?)> {
        return Player.find(playerID, on: req.db).flatMap { player in
            guard let player = player else {
                return req.eventLoop.makeSucceededFuture((nil, nil))
            }
            
            return Room.find(player.currentRoomID, on: req.db).map { room in
                return (player, room)
            }
        }
    }
}
