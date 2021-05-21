//
//  Player.swift
//  
//
//  Created by Maarten Engels on 21/05/2021.
//

import Foundation

struct Player {
    let id: UUID
    let name: String
    var currentRoomID: UUID?
    
    func moved(to roomID: UUID) -> Player {
        var movedPlayer = self
        movedPlayer.currentRoomID = roomID
        return movedPlayer
    }
}
