//
//  Parser.swift
//  Text Adventure
//
//  Created by Maarten Engels on 19/04/2019.
//  Copyright © 2019 thedreamweb. All rights reserved.
//

import Foundation
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
        let sentence = Lexer.lex(message)
        
        guard let newCommand = Command.createCommand(from: sentence) else {
            return Message(playerID: message.playerID, message: "<DEBUG>Failed to parse: '\(message.message)'</DEBUG>\n").asMessagesArrayFuture(on: req)
        }
        
        // execute the command
        switch newCommand.verb {
        case .HELP:
            return Message(playerID: newCommand.playerID, message: help()).asMessagesArrayFuture(on: req)
        case .ABOUT:
            return Message(playerID: newCommand.playerID, message: about()).asMessagesArrayFuture(on: req)
        case .CREATEUSER:
            return Player.createUser(username: newCommand.nouns[0], password: newCommand.nouns[1], on: req)
        case .LOGIN:
            if newCommand.playerID != nil {
                return Message(playerID: message.playerID, message: "<WARNING>You are already logged in. Logout first if you want to login as a different character.</WARNING>").asMessagesArrayFuture(on: req)
            } else {
                return GameState.loginUser(username: newCommand.nouns[0], password: newCommand.nouns[1], on: req)
            }
        case .DIG:
            return GameState.dig(owner: newCommand.playerID!, on: req)
        case .CREATE:
            return create(creator: newCommand.playerID!, objectType: newCommand.nouns[0], objectName: newCommand.nouns[1], on: req)
        case .CHANGE_ROOM:
            return changeRoom(playerID: newCommand.playerID!, dataElement: newCommand.nouns[0], newValue: newCommand.nouns[1], on: req)
        case .TELEPORT:
            return GameState.teleport(playerID: newCommand.playerID!, roomIDString: newCommand.nouns[0], on: req)
        case .GO:
            return GameState.go(playerID: newCommand.playerID!, exit: newCommand.nouns[0], on: req)
        case .LOOK:
            return GameState.describeRoom(playerID: newCommand.playerID!, on: req)
        case .SAY:
            return GameState.say(playerID: newCommand.playerID!, sentence: newCommand.nouns[0], on: req)
        case .WHISPER:
            return GameState.whisper(playerID: newCommand.playerID!, targetPlayerName: newCommand.nouns[0], sentence: newCommand.nouns[1], on: req)
        case Verb.TAKE:
            return GameState.pickupItem(playerID: newCommand.playerID!, itemName: newCommand.nouns[0], on: req)
        case .DROP:
            return GameState.dropItem(playerID: newCommand.playerID!, itemName: newCommand.nouns[0], on: req)
//        case Verb.LOOKAT:
//            return lookat(objectName: newCommand.noun!)
//        case Verb.OPEN:
//            return open(doorName: newCommand.noun!)
        case .INVENTORY:
            return Player.showInventory(for: newCommand.playerID!, on: req)
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
    
    
    static func create(creator: UUID, objectType: String, objectName: String, on req: Request) -> EventLoopFuture<[Message]> {
        switch objectType.uppercased() {
        case "ITEM":
            return GameState.createItem(creator: creator, objectName: objectName, on: req)
        default:
            return Message(playerID: creator, message: "Please specify a type of object to create. For instance: @CREATE ITEM <item name>.").asMessagesArrayFuture(on: req)
        }
    }
    
    static func changeRoom(playerID: UUID, dataElement: String, newValue: String, on req: Request) -> EventLoopFuture<[Message]> {
        switch dataElement.uppercased() {
        case "NAME":
            return GameState.changeRoomData(playerID: playerID, newName: newValue, newDescription: nil, on: req)
        case "DESCRIPTION":
            return GameState.changeRoomData(playerID: playerID, newName: nil, newDescription: newValue, on: req)
        default:
            return Message(playerID: playerID, message: "Changing of data element \(dataElement) is not (yet) supported.").asMessagesArrayFuture(on: req)
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
    
//    func expectNoun(noun: String) -> Bool {
//        if noun == "" {
//            return false
//        }
//
//        return true
//    }
    
    
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
    let nouns: [String]
    
    static func createCommand(from sentence: Sentence) -> Command? {
        switch sentence {
        case .illegal:
            return nil
        case .empty:
            return nil
        case .valid(let playerID, let verb, let nouns):
            guard let verb = Verb(rawValue: verb) else {
                return nil
            }
            
            guard verb.expectPlayerID == false || playerID != nil else {
                return nil
            }
            
            guard verb.expectedNounCount <= nouns.count else {
                return nil
            }
            
            return Command(playerID: playerID, verb: verb, nouns: nouns)
        }
    }
}
