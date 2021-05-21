import Vapor
import NIO

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    
    app.webSocket("game") { req, ws in
        
        // ws.pingInterval = TimeAmount.seconds(5)
        
        let newPlayer = Player(id: UUID(), name: "Maarten")
        World.main.players.append(newPlayer)
        
        let command = Command(ownerID: newPlayer.id, verb: "login", noun: nil)
        let message = Message(playerID: newPlayer.id, message: World.main.parse(command: command))
        
        ws.send(message.jsonString)
        
        ws.onText { ws, text in
            if let commandMessage = Message(from: text) {
                let command = Command(from: commandMessage)
                let message = Message(playerID: command.ownerID, message: World.main.parse(command: command))
                ws.send(message.jsonString)
            } else {
                ws.send("Failed to parse command.")
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
    let playerID: UUID
    let message: String
    
    init(playerID: UUID, message: String) {
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
            print("error decoding message: \(error.localizedDescription)")
            return nil
        }
        
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
