//
//  WebsocketClient.swift
//  There Then
//
//  Created by Paul Wicks on 8/13/25.
//
import Foundation

class WebSocketClient: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    private let session: URLSession

    var onMessage: ((String) -> Void)?

    init(url: URL) {
        self.url = url
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue())
        super.init()
    }

    func connect() {
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    func send(message: String) {
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.onMessage?(text)
                case .data(let data):
                    print("Received binary data: \(data)")
                @unknown default:
                    break
                }
            }
            self?.receiveMessage()
        }
    }
}

// Usage Example:
// let wsClient = WebSocketClient(url: URL(string: "ws://yourserver/ws/chat/")!)
// wsClient.onMessage = { message in print("Received: \(message)") }
// wsClient.connect()
// wsClient.send(message: "Hello from iOS!")
// wsClient.disconnect()
