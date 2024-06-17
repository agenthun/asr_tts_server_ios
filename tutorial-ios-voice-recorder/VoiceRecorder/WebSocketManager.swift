import Foundation

class WebSocketManager {
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func connect() {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
        print("Connected to WebSocket")
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        print("Disconnected from WebSocket")
    }
    
    func sendMessage(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
            } else {
                print("Message sent: \(message)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket receiving error: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received text: \(text)")
                    self?.handleReceivedMessage(text)
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    break
                }
                // Keep listening for new messages
                self?.receiveMessage()
            }
        }
    }
    
    private func handleReceivedMessage(_ message: String) {
        // Handle the received message here
        print("Handled message: \(message)")
    }
    
    deinit {
        disconnect()
    }
}
