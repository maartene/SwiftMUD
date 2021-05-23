//
//  Lexer.swift
//  Text Adventure
//
//  Created by Maarten Engels on 21/04/2019.
//  Copyright © 2019 thedreamweb. All rights reserved.
//

import Foundation
import AppKit

struct Lexer {
    
    static let abbreviations = [
        "n": "GO NORTH",
        "s": "GO SOUTH",
        "e": "GO EAST",
        "w": "GO WEST",
        "l": "LOOK",
        "?": "HELP",
        "exit": "QUIT",
        "get": "TAKE",
        "i": "INVENTORY"
    ]
    
    static func lex(_ message: Message) -> Sentence {
        let string = message.message
        let subStrings = string.split(separator: " ")
        
        guard subStrings.count > 0 else {
            return .empty
        }
        
        if let abbreviation = abbreviations[String(subStrings[0])] {
            var expandedString = abbreviation
            for i in 1 ..< subStrings.count {
                expandedString += " " + subStrings[i]
            }
            print("Expanded string: \(string) to : \(expandedString)")
            return lex(Message(playerID: message.playerID, message: expandedString))
        }
        
        return Sentence.createSentence(message)
    }
    
}

enum Sentence {
    case empty
    case illegal
    case noNoun(playerID: UUID?, verb: String)
    case oneNoun(playerID: UUID?, verb: String, noun: String)
    case twoNouns(playerID: UUID?, verb: String, noun1: String, relation: String, noun2: String)
    
    static func createSentence(_ message: Message) -> Sentence {
        let text = message.message
        let words = text.split(separator: " ")
        
        guard words.count > 0 else {
            return .empty
        }
        
        let uppercasedWords = words.map { $0.uppercased() }
        let verb = String(uppercasedWords[0])
        
        if words.count == 1 {
            return .noNoun(playerID: message.playerID, verb: verb)
        }
        
        if let withIndex = uppercasedWords.firstIndex(of: "WITH") {
            guard withIndex > 0 && withIndex < words.count else {
                return .illegal
            }
            
            let with = String(uppercasedWords[withIndex])
            let noun1words = words[1 ..< withIndex]
            let noun2words = words[withIndex + 1 ..< words.count]
            let noun1 = noun1words.joined(separator: " ")
            let noun2 = noun2words.joined(separator: " ")
            
            /*guard noun1.count > 0, noun2.count > 0 else {
                return .illegal
            }*/
            
            let sentence = Sentence.twoNouns(playerID: message.playerID, verb: verb, noun1: noun1, relation: with, noun2: noun2)
            return sentence
        }
        
        assert(words.count >= 2)
        let nounWords = words[1 ..< words.count]
        let noun = nounWords.joined(separator: " ")
        let sentence = Sentence.oneNoun(playerID: message.playerID, verb: String(verb), noun: noun)
        return sentence
    }
}
