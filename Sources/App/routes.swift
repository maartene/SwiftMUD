import Vapor
import NIO

func routes(_ app: Application) throws {
    
    var userSocketMap = [UUID: WebSocket]()
    
    app.get { req in
        req.view.render("index.html")
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
                ws.send("Failed to parse message.")
            }
        }
        
        ws.onClose.whenComplete { result in
            //ws.close()
            if let key = userSocketMap.first(where: { entry in
                entry.value === ws
            })?.key {
                req.logger.notice("Socket closed for user \(key)")
                _ = Player.find(key, on: req.db).flatMap { player -> EventLoopFuture<Void> in
                    userSocketMap.removeValue(forKey: key)
                    if let player = player {
                        return player.setOnlineStatus(false, on: req)
                    }
                    return req.eventLoop.makeSucceededVoidFuture()
                }
            }
        }
        
        ws.onPong { ws in
            req.logger.debug("received pong")
        }
        
        ws.onPing { ws in
            req.logger.debug("received ping")
        }
    }
}

struct Message: Content {
    static let logger = Logger(label: "Message")
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    
    let playerID: UUID?
    let message: String
    
    init(playerID: UUID?, message: String) {
        self.playerID = playerID
        self.message = message
    }
    
    init?(from json: String) {
        do {
            guard let data = json.data(using: .utf8) else {
                Self.logger.warning("Failed to convert received json to data.")
                return nil
            }
            
            let decodedMessage = try Self.decoder.decode(Message.self, from: data)
            playerID = decodedMessage.playerID
            message = decodedMessage.message
        } catch {
            Self.logger.warning("error decoding message \(json): \(error.localizedDescription)")
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
        do {
            let data = try Self.encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return error.localizedDescription
        }
    }
}
