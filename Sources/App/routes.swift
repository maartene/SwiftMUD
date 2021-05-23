import Vapor
import NIO

func routes(_ app: Application) throws {
    
    var userSocketMap = [UUID: WebSocket]()
    
    app.get { req in
        req.view.render("index")
    }

    app.get ("players") { req in
        Player.query(on: req.db).all()
    }
    
    app.get ("rooms") { req in
        Room.query(on: req.db).all()
    }
    
    app.webSocket("game") { req, ws in
        
        // ws.pingInterval = TimeAmount.seconds(5)
        
        let welcomeMessage = Message(playerID: nil, message: Parser.welcome())
        
        ws.send(welcomeMessage.jsonString)
        
//        World.main.players.append(newPlayer)
        
        ws.onText { ws, text in
            if let commandMessage = Message(from: text) {
                _ = Parser.parse(message: commandMessage, on: req).map { result in
                    
                    if let playerID = result.first?.playerID {
                        userSocketMap[playerID] = ws
                    }
                    
                    for message in result {
                        let html = AttributedTextFormatter.toHTML(text: message.message)
                        let messageToSend = Message(playerID: message.playerID, message: html)
                        if let playerID = message.playerID {
                            userSocketMap[playerID]?.send(messageToSend.jsonString)
                        } else {
                            ws.send(messageToSend.jsonString)
                        }
                    }
                }
            } else {
                ws.send("Failed to parse command.")
            }
        }
        
        ws.onClose.whenComplete { result in
            //ws.close()
            if let key = userSocketMap.first(where: { entry in
                entry.value === ws
            })?.key {
                print("Socket closed for user \(key)")
                userSocketMap.removeValue(forKey: key)
            }
        }
        
        ws.onPong { ws in
            print("received pong")
        }
        
        ws.onPing { ws in
            print("received ping")
        }
    }
}

struct Message: Content {
    let playerID: UUID?
    let message: String
    
    init(playerID: UUID?, message: String) {
        self.playerID = playerID
        self.message = message
    }
    
    init?(from json: String) {
        let decoder = JSONDecoder()
        do {
            guard let data = json.data(using: .utf8) else {
                print("Failed to convert received json to data.")
                return nil
            }
            
            let decodedMessage = try decoder.decode(Message.self, from: data)
            playerID = decodedMessage.playerID
            message = decodedMessage.message
        } catch {
            print("error decoding message \(json): \(error.localizedDescription)")
            return nil
        }
        
    }
    
    func asMessageFuture(on req: Request) -> EventLoopFuture<Message> {
        req.eventLoop.makeSucceededFuture(self)
    }
    
    func asMessagesArrayFuture(on req: Request) -> EventLoopFuture<[Message]> {
        req.eventLoop.makeSucceededFuture([self])
    }
    
    var jsonString: String {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return error.localizedDescription
        }
    }
}
