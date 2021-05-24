//
//  Verb.swift
//  Text Adventure
//
//  Created by Maarten Engels on 15/11/2020.
//  Copyright © 2020 thedreamweb. All rights reserved.
//

import Foundation

enum Verb: String, CaseIterable {
    case LOGIN
    case CREATEUSER
    case DIG = "@DIG"
    case DESCRIBE_ROOM = "@DESCRIBEROOM"
    case RENAME_ROOM = "@RENAMEROOM"
    case TELEPORT = "@TELEPORT"
    case HELP
    case LOOK
    case LOOKAT
    case GO
    case OPEN
    case TAKE
    case ABOUT
    case INVENTORY
    case LOGOUT
    case SAY
    case WHISPER
//    case QUIT
//    case SAVE
//    case LOAD
    case USE
    case COMBINE
    
    var expectedNounCount: Int
    {
        switch self {
        case .LOGIN:
            return 2
        case .CREATEUSER:
            return 2
        case .DIG:
            return 0
        case .DESCRIBE_ROOM:
            return 1
        case .RENAME_ROOM:
            return 1
        case .TELEPORT:
            return 1
        case .LOOKAT:
            return 1
        case .GO:
            return 1
        case .OPEN:
            return 1
        case .TAKE:
            return 1
        case .USE:
            return 1
        case .COMBINE:
            return 2
        case .SAY:
            return 1
        case .WHISPER:
            return 2
        default:
            return 0
        }
    }
    
    var expectPlayerID: Bool {
        switch self {
        case .LOGIN:
            return false
        case .CREATEUSER:
            return false
        case .HELP:
            return false
        case .ABOUT:
            return false
        default:
            return true
        }
    }
    
    var explanation: String {
        get {
            var result = ""
            switch self {
            case .HELP:
                result += "Shows a list of commands."
            case .LOGIN:
                result += "Login with a player character you created earlier."
            case .CREATEUSER:
                result += "Create a new player character."
            case .DIG:
                result += "Create a new room. You will be teleported to the new room."
            case .DESCRIBE_ROOM:
                result += "Changes the current room's description to a new value."
            case .RENAME_ROOM:
                result += "Renames the current room to a new value."
            case .TELEPORT:
                result += "Move to a different room by specifying an id."
            case .GO:
                result += "Go into a numbered exit."
            case .SAY:
                result += "Say something out loud (everyone in the room can hear it)."
            case .WHISPER:
                result += "Say something to someone else (only the intended person can hear it)."
            case .ABOUT:
                result += "Information about this game."
            case .LOOK:
                result += "Look around in the current room."
            case .INVENTORY:
                result += "Show your inventory."
            case .LOGOUT:
                result += "Logs the current user out."
            case .OPEN:
                result += "Open a door or container (chest/box/safe/...)."
            case .LOOKAT:
                result += "Look at an object in the room or in your inventory."
            case .TAKE:
                result += "Pick up an item into your inventory."
            case .USE:
                result += "Use an item."
            case .COMBINE:
                result += "Combine two items together into a new one."
//            case .SAVE:
//                result += "Save your current progress."
//            case .LOAD:
//                result += "Load saved game."
            }
            
            if expectedNounCount == 2 {
                result += " use: <STRONG>\(self) [NOUN 1] [NOUN 2]</STRONG>"
            } else if expectedNounCount == 1 {
                result += " use: <STRONG>\(self) [NOUN]</STRONG>"
            } else {
                result += " use: <STRONG>\(self)</STRONG>"
            }
                        
            return result
        }
    }
}
