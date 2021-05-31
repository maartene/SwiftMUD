//
//  Item.swift
//  Text Adventure
//
//  Created by Maarten Engels on 18/05/2019.
//  Copyright © 2019 thedreamweb. All rights reserved.
//

import Foundation
import Vapor
import Fluent

struct Item: Content {
    enum ItemEffect: Int, Codable {
        case light
    }
    
    enum ItemResult: String {
        case noEffect
        case itemHadNoEffect
        case itemHadEffect
        case itemsCannotBeCombined
        case itemNotInInventory
    }
    
    
    let name: String
    let description: String
    let effect: ItemEffect?
    let combineItemName: String?
    let replaceWithAfterUse: String?
    
    private init(name: String, description: String, effect: ItemEffect?, combineItemName: String?, replaceWithAfterUse: String?) {
        self.name = name
        self.description = description
        self.effect = effect
        self.combineItemName = combineItemName
        self.replaceWithAfterUse = replaceWithAfterUse
    }
    
    init(name: String, description: String) {
        self = Item(name: name, description: description, effect: nil, combineItemName: nil, replaceWithAfterUse: nil)
    }
    
    init(name: String, description: String, effect: ItemEffect) {
        self = Item(name: name, description: description, effect: effect, combineItemName: nil, replaceWithAfterUse: nil)
    }
    
    init(name: String, description: String, combineItemName: String, replaceWithAfterUse: String) {
        self = Item(name: name, description: description, effect: nil, combineItemName: combineItemName, replaceWithAfterUse: replaceWithAfterUse)
    }
    
    static var none: Item {
        Item(name: "none", description: "")
    }
}
