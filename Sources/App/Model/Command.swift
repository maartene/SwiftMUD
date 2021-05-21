//
//  Command.swift
//  
//
//  Created by Maarten Engels on 21/05/2021.
//

import Foundation

struct Command: Codable {
    let ownerID: UUID
    let verb: String
    let noun: String?
    
    init(ownerID: UUID, verb: String, noun: String?) {
        self.ownerID = ownerID
        self.verb = verb
        self.noun = noun
    }
    
    init(from message: Message) {
        self.ownerID = message.playerID
        
        let splits = message.message.split(separator: " ")
        if splits.count == 0 {
            verb = ""
            noun = nil
        } else if splits.count == 1 {
            verb = String(splits[0])
            noun = nil
        } else {
            verb = String(splits[0])
            noun = splits.dropFirst().joined(separator: " ")
        }
    }
}
