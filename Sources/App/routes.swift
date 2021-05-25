import Vapor
import NIO

struct Session {
    let sessionID: UUID
    var playerID: UUID?
    let socket: WebSocket
        
    mutating func setPlayerID(_ playerID: UUID) {
        if self.playerID == nil {
            self.playerID = playerID
        }
    }
}

struct SessionsContainer {
    static let logger = Logger(label: "SessionsContainer")
    private var sessions = [Session]()
    
    func getSession(sessionID: UUID) -> Session? {
        sessions.first { $0.sessionID == sessionID }
    }
    
    func getSession(for socket: WebSocket) -> Session? {
        sessions.first { $0.socket === socket }
    }
    
    func getSession(playerID: UUID) -> Session? {
        sessions.first { $0.playerID == playerID }
    }
    
    mutating func addSession(webSocket: WebSocket) -> Session? {
        guard getSession(for: webSocket) == nil else {
            Self.logger.warning("A session for this socket already exists.")
            return nil
        }
        
        let newSession = Session(sessionID: UUID(), playerID: nil, socket: webSocket)
        sessions.append(newSession)
        
        return newSession
    }
    
    mutating func setPlayerID(for session: Session, to playerID: UUID) {
        guard let storedSession = getSession(sessionID: session.sessionID) else {
            Self.logger.warning("A session for this session idea does not exists.")
            return
        }
        
        guard storedSession.socket === session.socket else {
            Self.logger.warning("Socket stored with session and for this session do not match.")
            return
        }
        
        guard storedSession.playerID == nil else {
            Self.logger.warning("A playerid is already stored for this session.")
            return
        }
        
        if let index = sessions.firstIndex(where: { $0.sessionID == session.sessionID }) {
            sessions[index].setPlayerID(playerID)
            Self.logger.info("Successfully stored playerID in session.")
        }
    }
    
    mutating func removeSession(_ sessionID: UUID) {
        if let index = sessions.firstIndex(where: { $0.sessionID == sessionID } ) {
            sessions.remove(at: index)
        }
    }
}

func routes(_ app: Application) throws {
    var sessions = SessionsContainer()
    
//    var userSocketMap = [UUID: WebSocket]()
//    var sessionSocketMap = [UUID: WebSocket]()
//
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
        
        guard let newSession = sessions.addSession(webSocket: ws) else {
            req.logger.warning("Failed to create session. Closing socket.")
            _ = ws.close()
            return
        }
        
        let sessionMessage = SessionMessage(sessionID: newSession.sessionID)
        
        ws.send(sessionMessage.jsonString)
        ws.send(welcomeMessage.jsonString)
        
//        World.main.players.append(newPlayer)
        
        ws.onText { ws, text in
            guard let session = sessions.getSession(for: ws) else {
                req.logger.warning("No session found for this socket. Closing socket.")
                _ = ws.close()
                return
            }
            
            if let commandMessage = Message(from: text) {
                // before we parse, we need to check wether the sessionID from this message (stored in 'playerID') corresponds to the known websocket.
                guard commandMessage.playerID == session.sessionID else {
                    req.logger.warning("Session found in message does not match with stored session for this websocket. Closing socket.")
                    _ = ws.close()
                    return
                }
                
                // we create a new message based on the received commandMessage's text and playerID as found in the current session.
                let messageToParse = Message(playerID: session.playerID, message: commandMessage.message)
            
                _ = Parser.parse(message: messageToParse, on: req).map { result in
                    
                    // it's possible that the result contains a playerID - for instance after logging in.
                    if let playerID = result.first?.playerID, session.playerID == nil {
                        sessions.setPlayerID(for: session, to: playerID)
                    }
                    
                    for message in result {
                        let html = AttributedTextFormatter.toHTML(text: message.message)
                        let messageToSend = Message(playerID: message.playerID, message: html)
                        if let playerID = message.playerID {
                            if let sendSession = sessions.getSession(playerID: playerID) {
                                sendSession.socket.send(messageToSend.jsonString)
                            }
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
            if let session = sessions.getSession(for: ws) {
                req.logger.notice("Socket closed for user \(session.playerID?.uuidString ?? "unknown")")
                
                _ = Player.find(session.playerID, on: req.db).flatMap { player -> EventLoopFuture<Void> in
                    sessions.removeSession(session.sessionID)
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

struct SessionMessage: Content {
    static let logger = Logger(label: "SessionMessage")
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    
    private(set) var type = "SessionMessage"
    let sessionID: UUID
    
    init(from session: Session) {
        self.sessionID = session.sessionID
    }
    
    init(sessionID: UUID) {
        self.sessionID = sessionID
    }
    
    init?(from json: String) {
        do {
            guard let data = json.data(using: .utf8) else {
                Self.logger.warning("Failed to convert received json to data.")
                return nil
            }
            
            let decodedMessage = try Self.decoder.decode(SessionMessage.self, from: data)
            sessionID = decodedMessage.sessionID
        } catch {
            Self.logger.warning("error decoding session message \(json): \(error.localizedDescription)")
            return nil
        }
        
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

struct Message: Content {
    static let logger = Logger(label: "Message")
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    
    private(set) var type = "Message"
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
