//
//  Room.swift
//  
//
//  Created by Maarten Engels on 21/05/2021.
//

import Foundation

struct Room {
    let id: UUID
    let creatorID: UUID
    var name: String
    var description: String
    var connections = [UUID]()
    
    static var room0: Room {
        Room(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, name: "Room0", description: """
            Here you are. White is everywhere. There are no walls, there is no floor, there is no ceiling. Yet, you don't fall. When you walk, there is no where to go. Everything is white. Are you dead? Is this heaven? Is this hell? I guess you wanted to come here. Now, how do you get out of here?
            """)
    }
    
    static func descriptionChanged(to description: String, on room: Room) -> Room {
        var changedRoom = room
        changedRoom.description = description
        return changedRoom
    }
    
    static func nameChanged(to name: String, on room: Room) -> Room {
        var changedRoom = room
        changedRoom.name = name
        return changedRoom
    }
}
