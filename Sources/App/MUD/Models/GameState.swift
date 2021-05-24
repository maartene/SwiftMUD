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
                    messages.append(Message(playerID: roomPlayer.id, message: "<ACTION>\(player.name) says:</ACTION> \(sentence)"))
                }
            }
            
            return messages
        }
    }
    
    static func whisper(playerID: UUID, targetPlayerName: String, sentence: String, on req: Request) -> EventLoopFuture<[Message]> {
        return getPlayerRoomAndAllPlayers(for: playerID, on: req).map { result in
            guard let player = result.player else {
                return [Message(playerID: playerID, message: "<WARNING>Could not find player with id \(playerID).</WARNING>")]
            }
            
            guard let targetPlayer = result.roomPlayers.first(where: {$0.name == targetPlayerName}) else {
                return [Message(playerID: playerID, message: "<WARNING>\(targetPlayerName) is not in the room.</WARNING>")]
            }
            
            var messages = [Message]()
            messages.append(Message(playerID: playerID, message: "<ACTION>You say:</ACTION> \(sentence) <ACTION>to \(targetPlayerName)</ACTION>"))
            
            for roomPlayer in result.roomPlayers {
                if roomPlayer.id == targetPlayer.id {
                    messages.append(Message(playerID: roomPlayer.id, message: "<ACTION>\(player.name) says </ACTION> \(sentence) <ACTION>to you.</ACTION>"))
                } else if roomPlayer.id != player.id {
                    messages.append(Message(playerID: roomPlayer.id, message: "<ACTION>\(player.name) whispers something to \(targetPlayerName)</ACTION>"))
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
            
            if let currentRoomID = player.currentRoomID {
                newRoom.connections.append(currentRoomID)
            }
            
            return newRoom.save(on: req.db).flatMap {
                if let currentRoomID = player.currentRoomID, let newRoomID = newRoom.id {
                    _ = Room.find(currentRoomID, on: req.db).map { room in
                        room?.connections.append(newRoomID)
                        _ = room?.save(on: req.db)
                    }
                }
                
                player.currentRoomID = newRoom.id
                return player.save(on: req.db).map {
                    return [Message(playerID: player.id, message: "<ACTION>Successfully created new room \(player). You have been teleported into the new room.</ACTION>")]
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
            
            guard (0 ..< currentRoom.connections.count).contains(exitIndex) else {
                return Message(playerID: playerID, message: "No exit with index \(exitIndex) is available in this room.").asMessagesArrayFuture(on: req)
            }
            
            let connections = currentRoom.connections.sorted(by: { $0.uuidString < $1.uuidString })
            let newRoomID = connections[exitIndex]
            
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
    
    static func describeRoom(playerID: UUID, on req: Request) -> EventLoopFuture<[Message]> {
        return Player.find(playerID, on: req.db).flatMap { player in
            guard let player = player else {
                return Message(playerID: nil, message: "Could not find player with id \(playerID)").asMessagesArrayFuture(on: req)
            }
            
            guard let roomID = player.currentRoomID else {
                return Message(playerID: player.id, message: "VOID ROOM").asMessagesArrayFuture(on: req)
            }
            
            return Room.find(roomID, on: req.db).flatMap { room in
                guard let room = room else {
                    return Message(playerID: player.id, message: "<WARNING>Could not find room with id \(roomID)</WARNING>").asMessagesArrayFuture(on: req)
                }
                
                return getPlayersInRoom(roomID, on: req).flatMap { roomPlayers in
                    let roomPlayers = roomPlayers.sorted(by: { $0.id?.uuidString ?? "" < $1.id?.uuidString ?? "" })
                    return Room.query(on: req.db).filter(\.$id ~~ room.connections).all().map { connectedRooms in
                        let connectedRooms = connectedRooms.sorted(by: { $0.id?.uuidString ?? "" < $1.id?.uuidString ?? "" })
                        
                        var text = "<STRONG>" + room.name + "</STRONG>\n"
                        text += room.description + "\n"
                        
                        text += "<STRONG>Exits:</STRONG>\n"
                        for i in 0 ..< connectedRooms.count {
                            text += "<EXIT>\(i). " + connectedRooms[i].name + "</EXIT>\n"
                        }
                        
                        text += "<STRONG>Other players:</STRONG>\n"
                        for i in 0 ..< roomPlayers.count {
                            if roomPlayers[i].id != player.id {
                                text += "\(roomPlayers[i].name)"
                            }
                        }
                        text += "\n"
                        
                        return [Message(playerID: player.id, message: text)]
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
    
    
    
}
