//
//  Lexer.swift
//  Text Adventure
//
//  Created by Maarten Engels on 21/04/2019.
//  Copyright © 2019 thedreamweb. All rights reserved.
//

import Foundation
import AppKit
import Logging

struct Lexer {
    static let logger = Logger(label: "Lexer")
    
    static let abbreviations = [
        "l": "LOOK",
        "speak": "SAY",
        "?": "HELP",
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
            logger.debug("Expanded string: \(string) to : \(expandedString)")
            return lex(Message(playerID: message.playerID, message: expandedString))
        }
        
        return Sentence.createSentence(message)
    }
    
}

enum Sentence {
    case empty
    case illegal
    case valid(playerID: UUID?, verb: String, nouns: [String])
    
    static func createSentence(_ message: Message) -> Sentence {
        let text = message.message
        let words = text.split(separator: " ")
        
        guard words.count > 0 else {
            return .empty
        }
        
        let uppercasedWords = words.map { $0.uppercased() }
        
        // the first word is always the verb
        let verb = String(uppercasedWords[0])
        
        // if only one word was found, the sentence is without a noun.
        if words.count == 1 {
            return .valid(playerID: message.playerID, verb: verb, nouns: [])
        }

        var nouns = [String]()
        var i = 1
        while i < words.count {
            // if more than one word was found, either the second word is a single noun or a sub-sentence if it starts with "
            if words[i].starts(with: "\"") {
                // we need to keep looping until we find a word that ends with an "
                //print(words[i].dropFirst())
                var subNoun = [String(words[i].drop(while: { $0 == "\"" })  )]
                var subsentenceCompleted = false
                i += 1
                while i < words.count && subsentenceCompleted == false  {
                    if words[i].last == "\"" {
                        subNoun.append(String(words[i].dropLast()))
                        subsentenceCompleted = true
                    } else {
                        subNoun.append(String(words[i]))
                    }
                    i += 1
                }
                nouns.append(subNoun.joined(separator: " "))
            } else {
                nouns.append(String(words[i]))
                i += 1
            }
        }
        
        return .valid(playerID: message.playerID, verb: verb, nouns: nouns)
        
//        // are there still more words?
//        if i < words.count {
//            let noun2: String
//            if words[i].starts(with: "\"") {
//                // we need to keep looping until we find a word that ends with an "
//                var nouns = [String(words[i].dropFirst())]
//                i += 1
//                var subsentenceCompleted = false
//                while i < words.count && subsentenceCompleted == false  {
//                    if words[i].last == "\"" {
//                        nouns.append(String(words[i].dropLast()))
//                        subsentenceCompleted = true
//                    } else {
//                        nouns.append(String(words[i]))
//                        i += 1
//                    }
//
//                }
//                noun2 = nouns.joined(separator: " ")
//            } else {
//                noun2 = String(words[i])
//            }
//            return .twoNouns(playerID: message.playerID, verb: verb, noun1: noun1, noun2: noun2)
//        } else {
//            return .oneNoun(playerID: message.playerID, verb: verb, noun: noun1)
//        }
    }
}
