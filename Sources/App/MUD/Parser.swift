//
//  Parser.swift
//  Text Adventure
//
//  Created by Maarten Engels on 19/04/2019.
//  Copyright © 2019 thedreamweb. All rights reserved.
//

import Foundation
import AppKit
import Vapor
import Fluent

struct Parser {
    
    static func welcome() -> String {
        
        """
        <H1>Welcome to MUD</H1>
        Please login using:
        LOGIN <username> <password>
        Or create a new user using
        CREATEUSER <username> <password>
        """
        
    }
    
    
    
    static func parse(message: Message, on req: Request) -> EventLoopFuture<[Message]> {
        let newCommand: Command
        let sentence = Lexer.lex(message)
        
        switch sentence {
        case .illegal:
            return Message(playerID: message.playerID, message: "<DEBUG>Failed to parse: '\(message.message)'</DEBUG>\n").asMessagesArrayFuture(on: req)
        case .empty:
            return Message(playerID: message.playerID, message: "<DEBUG>nothing to parse</DEBUG>\n").asMessagesArrayFuture(on: req)
        case .noNoun(let playerID, let verbWord):
            guard let verb = Verb(rawValue: verbWord) else {
                let word = verbWord.isEmpty ? ", but none was found." : ", found: '\(verbWord)'"
                return Message(playerID: playerID, message: "<WARNING>Expected a verb as the first word\(word)</WARNING>\n").asMessagesArrayFuture(on: req)
            }
            newCommand = Command(playerID: playerID, verb: verb, noun: nil, indirectObject: nil)
        case .oneNoun(let playerID, let verbWord, let noun):
            guard let verb = Verb(rawValue: verbWord) else {
                let word = verbWord.isEmpty ? ", but none was found." : ", found: '\(verbWord)'"
                return Message(playerID: playerID, message: "<WARNING>Expected a verb as the first word\(word)</WARNING>\n").asMessagesArrayFuture(on: req)
            }
            newCommand = Command(playerID: playerID, verb: verb, noun: noun, indirectObject: nil)
        case .twoNouns(let playerID, let verbWord, let directObject, let relation, let indirectObject):
            guard let verb = Verb(rawValue: verbWord) else {
                let word = verbWord.isEmpty ? ", but none was found." : ", found: '\(verbWord)'"
                return Message(playerID: playerID, message: "<WARNING>Expected a verb as the first word\(word)</WARNING>\n").asMessagesArrayFuture(on: req)
            }
            
            guard directObject.count > 0 else {
                return Message(playerID: playerID, message: "<WARNING>Expected the direct object after verb '\(verb)', before relation '\(relation)', but did not find any.</WARNING>\n").asMessagesArrayFuture(on: req)
            }
            
            guard directObject.count > 0 else {
                return Message(playerID: playerID, message: "<WARNING>Expected the indirect object after relation '\(relation)', but did not find any.</WARNING>\n").asMessagesArrayFuture(on: req)
            }
            
            newCommand = Command(playerID: playerID, verb: verb, noun: directObject, indirectObject: indirectObject)
        }
        
//        if newCommand.verb.//
        
        if newCommand.verb.expectPlayerID && newCommand.playerID == nil {
            return Message(playerID: nil, message: "<WARNING>You need to be loged in as a player character to use the command \(newCommand.verb).</WARNING>\n").asMessagesArrayFuture(on: req)
        }
        
        if newCommand.verb.expectedNounCount == 1 && newCommand.noun == nil {
            return Message(playerID: newCommand.playerID, message: "<WARNING>Expected a noun for verb \(newCommand.verb), but did not find any.</WARNING>\n").asMessagesArrayFuture(on: req)
        }
        
        if newCommand.verb.expectedNounCount == 2 {
            if newCommand.noun == nil {
                return Message(playerID: newCommand.playerID, message: "<WARNING>Expected a direct object for verb \(newCommand.verb), but did not find any.</WARNING>\n").asMessagesArrayFuture(on: req)
            }
            if newCommand.indirectObject == nil {
                return Message(playerID: newCommand.playerID, message: "<WARNING>Expected an indirect object for verb \(newCommand.verb), but did not find any.</WARNING>\n").asMessagesArrayFuture(on: req)
            }
        }
                                
        // execute the command
        switch newCommand.verb {
        case .HELP:
            return Message(playerID: newCommand.playerID, message: help()).asMessagesArrayFuture(on: req)
        case .ABOUT:
            return Message(playerID: newCommand.playerID, message: about()).asMessagesArrayFuture(on: req)
        case .CREATEUSER:
            return createUser(username: newCommand.noun!, password: newCommand.indirectObject!, on: req)
        case .LOGIN:
            return loginUser(username: newCommand.noun!, password: newCommand.indirectObject!, on: req)
        case .DIG:
            return dig(owner: newCommand.playerID!, on: req)
        case .DESCRIBE_ROOM:
            return changeRoomData(playerID: newCommand.playerID!, newDescription: newCommand.noun!, on: req)
        case .RENAME_ROOM:
            return changeRoomData(playerID: newCommand.playerID!, newName: newCommand.noun!, on: req)
        case .TELEPORT:
            return teleport(playerID: newCommand.playerID!, roomIDString: newCommand.noun!, on: req)
        case .GO:
            return go(playerID: newCommand.playerID!, exit: newCommand.noun!, on: req)
        case .LOOK:
            return describeRoom(playerID: newCommand.playerID!, on: req)
//        case Verb.TAKE:
//            return take(itemName: newCommand.noun!)
//        case Verb.LOOKAT:
//            return lookat(objectName: newCommand.noun!)
//        case Verb.OPEN:
//            return open(doorName: newCommand.noun!)
//        case Verb.INVENTORY:
//            return inventory()
//        case Verb.USE:
//            return use(itemName: newCommand.noun!)
//        case Verb.COMBINE:
//            return combine(item1Name: newCommand.noun!, item2Name: newCommand.indirectObject!)
//        case Verb.SAVE:
//            return saveGame()
//        case Verb.LOAD:
//            return loadGame()
//        case Verb.QUIT:
//            NSApplication.shared.terminate(nil)
//            return "<H2>Good Bye!</H2>"
            
        default:
            // echo what comes in
            return Message(playerID: newCommand.playerID, message: "<DEBUG>Received command: \(newCommand)</DEBUG>\n").asMessagesArrayFuture(on: req)
        }
    }
    
    static func about() -> String {
        return """
        This is a small MUD written in Swift. I Hope you have fun playing it.
        (c) thedreamweb.eu / Maarten Engels, 2021. Apache 2.0 license
        See https://github.com/maartene/SwiftMUD for more information.
        """
    }
    
    static func createUser(username: String, password: String, on req: Request) -> EventLoopFuture<[Message]> {
        let newPlayer = Player(name: username)
        
        return newPlayer.save(on: req.db).map {
            return [Message(playerID: newPlayer.id, message: "Successfully created player \(newPlayer). Welcome \(newPlayer.name)!")]
        }
    }
    
    static func loginUser(username: String, password: String, on req: Request) -> EventLoopFuture<[Message]> {
        return Player.query(on: req.db)
            .filter(\.$name == username).first().flatMap { player in
            if let player = player {
                return Room.find(player.currentRoomID, on: req.db).flatMap { room in
                    return getPlayersInRoom(player.currentRoomID, on: req).map { otherPlayers in
                        var messages = [Message(playerID: player.id, message: "Successfully logged in. Welcome back \(player.name)!")]
                        if let room = room {
                            messages.append(contentsOf: roomEnterMessages(player: player, room: room, roomPlayers: otherPlayers))
                        }
                        return messages
                    }
                }
            } else {
                return Message(playerID: nil, message: "Failed to log in").asMessagesArrayFuture(on: req)
            }
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
                    return [Message(playerID: player.id, message: "Successfully created new room \(player). You have been teleported into the new room.")]
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
    
//    func lookat(objectName: String) -> String {
//        // First, check whether player intents to look at a door.
//        if objectName.uppercased() == "DOOR" {
//            if world.doorsInRoom(room: world.currentRoom).count > 0 {
//                var result = ""
//                for door in world.doorsInRoom(room: world.currentRoom) {
//                    result += "The door to the <EXIT>\(door.direction(from: world.currentRoom))</EXIT> requires <ITEM>\(door.requiresItemToOpen?.name ?? "no item")</ITEM> to open."
//                }
//                return result + "\n"
//            } else {
//                return "<WARNING>There is no </WARNING> <EXIT>DOOR</EXIT> <WARNING> in the current room.</WARNING>\n"
//            }
//        }
//
//        // check whether there is an item in the room called itemName
//        var itemsInRoomAndInventory = world.currentRoom.items
//        itemsInRoomAndInventory.append(contentsOf: world.inventory)
//
//        let possibleItems = itemsInRoomAndInventory.filter { item in item.canBe(partOfName: objectName) }
//
//        switch possibleItems.count {
//        case 0:
//            return "<WARNING>There is no </WARNING><ITEM>\(objectName)</ITEM><WARNING> in the current room.</WARNING>\n"
//        case 1:
//            guard let item = possibleItems.first else {
//                return "<DEBUG>Unexpected nil value in \(possibleItems).first</DEBUG>\n"
//            }
//            return "<ITEM>\(item.name)</ITEM>: \(item.description)\n"
//        case 2...:
//            return "<WARNING>More than one item contains </WARNING><ITEM>\(objectName)</ITEM><WARNING>. Please be more specific.</WARNING>\n"
//        default:
//            return "<DEBUG>Negative item count should not be possible.</DEBUG>"
//        }
//    }
    
//    func use(itemName: String) -> String {
//        // get a list of all items in inventory that somehow have the itemName in it's name
//        //let potentialItems = world.inventory.filter { item in item.name.uppercased().contains(itemName.uppercased()) }
//        let potentialItems = world.inventory.filter { item in item.canBe(partOfName: itemName) }
//
//        switch potentialItems.count {
//        case 0:
//            return "<WARNING>You don't carry an item with name: '\(itemName)'.</WARNING>\n"
//        case 1:
//            // we found an item
//            guard let item = potentialItems.first else {
//                return "<DEBUG>For some reason a nil value for found for the item.</DEBUG>\n"
//            }
//
//            switch world.use(item: item) {
//            case .noEffect:
//                return "You try and use the <ITEM>\(item.name)</ITEM>, but it has no effect.\n"
//            case .itemHadEffect:
//                return "You used the <ITEM>\(item.name)</ITEM>. It has the following effect: \(item.effect!).\n" + describeRoom()
//            case .itemHadNoEffect:
//                return "This does not seem to be the right place to use the <ITEM>\(item.name)</ITEM>.\n"
//            default:
//                return "<DEBUG>Unexpected result from using item <ITEM>\(item.name)</ITEM>.</DEBUG>\n"
//            }
//
//        case 2...:
//            return "<WARNING>More than one item contains the name </WARNING><ITEM>\(itemName)</ITEM><WARNING>. Please be more specific.</WARNING>\n"
//        default:
//            return "<DEBUG>A negative value of potentialItems.count was observed.</DEBUG>\n"
//        }
//    }
        
//    func combine(item1Name: String, item2Name: String) -> String {
//        let potentialItem1s = world.inventory.filter { item in item.canBe(partOfName: item1Name) }
//        let potentialItem2s = world.inventory.filter { item in item.canBe(partOfName: item2Name) }
//
//        /*potentialItems = potentialItems.filter { item in
//            return item.combineItemName != nil
//        }
//
//        potentialIndirectObjects = potentialIndirectObjects.filter { item in
//            return item.combineItemName != nil
//        }*/
//
//        switch (potentialItem1s.count, potentialItem2s.count) {
//        case (0,0):
//            return "<WARNING>Could not match <ITEM>\(item1Name)</ITEM> and <ITEM>\(item2Name)</ITEM> with any objects in inventory.</WARNING>\n"
//        case (1,0):
//            return "<WARNING>Could not match second object <ITEM>\(item2Name)</ITEM> with any objects in inventory.</WARNING>\n"
//        case (0,1):
//            return "<WARNING>Could not match first object <ITEM>\(item1Name)</ITEM> with any objects in inventory.</WARNING>\n"
//        case (2..., 2...):
//            return "<ITEM>\(item1Name)</ITEM> <WARNING>and</WARNING> <ITEM>\(item2Name)</ITEM> <WARNING>are ambiguous. Please be more specific.</WARNING>\n"
//        case (2..., _):
//            return "<WARNING><ITEM>\(item1Name)</ITEM> is ambiguous. Please be more specific.</WARNING>\n"
//        case (_, 2...):
//            return "<WARNING><ITEM>\(item2Name)</ITEM> is ambiguous. Please be more specific.</WARNING>\n"
//        case (1,1):
//            switch world.use(item: potentialItem1s[0], with: potentialItem2s[0]) {
//            case .itemHadEffect:
//                return "Combined <ITEM>\(potentialItem1s[0].name)</ITEM> with <ITEM>\(potentialItem2s[0].name)</ITEM> into new object <ITEM>\(potentialItem1s[0].replaceWithAfterUse ?? "UNKNOWN")</ITEM>\n"
//            case .itemsCannotBeCombined:
//                return "<WARNING>You cannot combine </WARNING><ITEM>\(potentialItem1s[0].name)</ITEM> <WARNING>and</WARNING> <ITEM>\(potentialItem2s[0].name)</ITEM><WARNING>.</WARNING>\n"
//            default:
//                return "<DEBUG>Unexpected result from trying to use \(potentialItem1s[0].name) with \(potentialItem2s[0].name).\n"
//            }
//        default:
//            return "<DEBUG>Unknown combination of \(potentialItem1s.count) and \(potentialItem2s.count).</DEBUG>\n"
//        }
//    }
    
    static func go(playerID: UUID, exit: String, on req: Request) -> EventLoopFuture<[Message]> {
        guard let exitIndex = Int(exit) else {
            return Message(playerID: playerID, message: "Could not convert \(exit) to a number.").asMessagesArrayFuture(on: req)
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
                
                guard (0 ..< room.connections.count).contains(exitIndex) else {
                    return Message(playerID: playerID, message: "No exit with index \(exitIndex) is available in this room.").asMessagesArrayFuture(on: req)
                }
                
                let connections = room.connections.sorted(by: { $0.uuidString < $1.uuidString })
                let newRoomID = connections[exitIndex]
                
                player.currentRoomID = newRoomID
                
                return getPlayersInRoom(newRoomID, on: req).flatMap { roomPlayers in
                    return getPlayersInRoom(currentRoomID, on: req).flatMap { currentRoomPlayers in
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
        result.append(Message(playerID: player.id, message: "Entered room \(room.name)"))
        for roomPlayer in roomPlayers {
            if roomPlayer.id != player.id {
                result.append(Message(playerID: roomPlayer.id, message: "\(player.name ) entered the room."))
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
                result.append(Message(playerID: roomPlayer.id, message: "\(player.name ) leaved the room."))
            }
        }
        //print(result)
        return result
    }
    
//    func take(itemName: String) -> String {
//        // first try and find the item in the room
////        var potentialItems = [Item]()
////        for index in 0 ..< world.currentRoom.items.count {
////            if world.currentRoom.items[index].name.uppercased() == itemName.uppercased() {
////                let item = world.currentRoom.items[index]
////                if world.take(item: item) {
////                    return "\nYou picked up <ITEM>\(item.name)</ITEM>.\n"
////                } else {
////                    return "\nYou could not pick up <ITEM>\(item.name)</ITEM>\n"
////                }
////            }
////
////            // get an array of all the words that make up the item name. We can use this to find all matching items
////            let itemWords = world.currentRoom.items[index].name.split(separator: " ")
////
////            itemWords.forEach { itemWord in
////                let takeWords = itemName.split(separator: " ")
////                takeWords.forEach { takeWord in
////                    if itemWord.uppercased().starts(with: takeWord.uppercased()) {
////                        let potentialItem = world.currentRoom.items[index]
////                        if potentialItems.contains(potentialItem) == false {
////                            potentialItems.append(potentialItem)
////                        }
////                    }
////                }
////            }
////        }
//
//        let potentialItems = world.currentRoom.items.filter { item in item.canBe(partOfName: itemName) }
//
//        switch potentialItems.count {
//        case 0:
//            // no potential item was found
//            return "There is no <ITEM>\(itemName)</ITEM> here.\n"
//        case 1:
//            // we found exactly one item that matches. Try and get the item.
//            let item = potentialItems.first!
//            if world.take(item: item) {
//                return "\nYou picked up <ITEM>\(item.name)</ITEM>.\n"
//            } else {
//                return "\nYou could not pick up <ITEM>\(item.name)</ITEM>\n"
//            }
//        default:
//            // more than one potential item was found, how can we choose?
//            return "\nMore than one item matches <ITEM>\(itemName)</ITEM>. Please be more specific.\n"
//        }
//    }
//
//    func open(doorName: String) -> String {
//        func interpretDoorOpenResult(_ doorResult: Door.DoorResult) -> String {
//            var result = ""
//            switch doorResult {
//            case .doorDidOpen:
//                result += "<ACTION>You opened the door.</ACTION>\n"
//                result += describeRoom()
//            case .missingItemToOpen(let item):
//                result = "<WARNING>You require <ITEM>\(item.name)</ITEM> to open the door.</WARNING>\n"
//            default:
//                result = "<DEBUG>Failed to open door: \(doorResult)</DEBUG>\n"
//            }
//            return result
//        }
//
//        if world.doorsInRoom(room: world.currentRoom).count < 1 {
//            return "<WARNING>There is no closed door here.</WARNING>\n"
//        }
//
//        let doorsInCurrentRoom = world.doorsInRoom(room: world.currentRoom)
//
//        guard doorsInCurrentRoom.count > 0 else {
//            return "<WARNING>There is no closed door here.</WARNING>\n"
//        }
//
//        let filteredDoors = doorsInCurrentRoom.filter { door in
//            door.name.uppercased().contains(doorName.uppercased())
//        }
//
//        if filteredDoors.count == 0 {
//            return "<WARNING>Could not find door with name \(doorName) in this room.</WARNING>\n"
//        } else if filteredDoors.count > 1 {
//            return "<WARNING>Please be more specific which door you want to open.</WARNING>\n"
//        } else {
//            let door = filteredDoors[0]
//            let result = world.open(door: door)
//            return interpretDoorOpenResult(result)
//        }
//    }
    
    static func help() -> String {
        var result = "\n<H3>Commands:</H3>"
        Verb.allCases.forEach {
            result += "<STRONG>\($0.rawValue)</STRONG>   " + $0.explanation + "\n"
        }
        result += "\n"
        return result
    }
    
//    func inventory() -> String {
//        var result = "\nYou carry: \n"
//        if world.inventory.count > 0 {
//            world.inventory.forEach {
//                result += "<ITEM>\($0.name)</ITEM>\n"
//            }
//        } else {
//            result += "Nothing.\n"
//        }
//        //result += "\n"
//        return result
//    }
//
//    func saveGame() -> String {
//        if world.saveGame() {
//            return "Save succesfull!"
//        } else {
//            return "<WARNING>Failed to save.</WARNING>"
//        }
//    }
//
//    mutating func loadGame() -> String {
//        var result = ""
//
//        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            return "<DUBUG>Failed to get document directory.</DEBUG>"
//        }
//
//        let fileURL = dir.appendingPathComponent("taSave.json")
//
//        if let newWorld = World.loadGame(from: fileURL) {
//            world = newWorld
//            result += "Succesfully loaded world."
//            result += describeRoom()
//        } else {
//            result += "<WARNING>Could not load game.</WARNING>"
//        }
//        return result
//    }
    
    func expectNoun(noun: String) -> Bool {
        if noun == "" {
            return false
        }
        
        return true
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
                    return Message(playerID: player.id, message: "Could not find room with id \(roomID)").asMessagesArrayFuture(on: req)
                }
                
                return getPlayersInRoom(roomID, on: req).flatMap { roomPlayers in
                    let roomPlayers = roomPlayers.sorted(by: { $0.id?.uuidString ?? "" < $1.id?.uuidString ?? "" })
                    return Room.query(on: req.db).filter(\.$id ~~ room.connections).all().map { connectedRooms in
                        let connectedRooms = connectedRooms.sorted(by: { $0.id?.uuidString ?? "" < $1.id?.uuidString ?? "" })
                        
                        var text = room.name + "\n"
                        text += room.description + "\n"
                        
                        text += "Exits: \n"
                        for i in 0 ..< connectedRooms.count {
                            text += "\(i). " + connectedRooms[i].name + "\n"
                        }
                        
                        text += "Other players: \n"
                        for i in 0 ..< roomPlayers.count {
                            if roomPlayers[i].id != player.id {
                                text += "\(roomPlayers[i].name)"
                            }
                        }
                        
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
    
    static func getPlayersInRoom(_ roomID: UUID?, on req: Request) -> EventLoopFuture<[Player]> {
        return Player.query(on: req.db).filter(\.$currentRoomID == roomID).all().map { players in
            return players
        }
    }
//
//    func showDescription() -> String {
//        return "<H3>\(world.currentRoom.name)</H3>" + world.currentRoom.description + "\n"
//    }
//
//    func showExits() -> String {
//        var result = ""
//        world.currentRoom.exits.keys.forEach {
//            result += "There is an exit to the <EXIT>\($0)</EXIT>.\n"
//        }
//        return result
//    }
//
//    func showItems() -> String {
//        var result = ""
//        world.currentRoom.items.forEach {
//            result += "You see a <ITEM>\($0.name)</ITEM>\n"
//        }
//
//        return result
//    }
//
//    func showDoors() -> String {
//        let doorsInRoom = world.doorsInRoom(room: world.currentRoom)
//
//        var result = ""
//        doorsInRoom.forEach {
//            result += "There is a <EXIT>\($0.name.uppercased())</EXIT> to the <EXIT>\($0.direction(from: world.currentRoom))</EXIT>\n"
//        }
//
//        return result
//    }
}

struct Command {
    let playerID: UUID?
    let verb: Verb
    let noun: String?
    let indirectObject: String?
}

extension String {
    func asStringFuture(on req: Request) -> EventLoopFuture<String> {
        req.eventLoop.makeSucceededFuture(self)
    }
}
