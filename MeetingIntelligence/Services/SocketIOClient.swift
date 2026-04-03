//
//  SocketIOClient.swift
//  MeetingIntelligence
//
//  Minimal Socket.IO v4 client using URLSessionWebSocketTask.
//  Supports auth handshake, ping/pong, and event listening.
//

import Foundation
import FirebaseAuth

class SocketIOClient {
    static let shared = SocketIOClient()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var isConnected = false
    private var eventHandlers: [String: [(Any) -> Void]] = [:]
    private var pingTimer: Timer?
    private let serverURL = "wss://dashmet-rca-api.onrender.com"
    
    private init() {
        session = URLSession(configuration: .default)
    }
    
    // MARK: - Connect
    
    func connect(userId: String, organizationId: String) {
        guard !isConnected, webSocketTask == nil else { return }
        
        // Socket.IO WebSocket URL with EIO=4 (Engine.IO v4)
        guard let url = URL(string: "\(serverURL)/socket.io/?EIO=4&transport=websocket") else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Store auth for the CONNECT packet
        let auth = ["userId": userId, "organizationId": organizationId]
        
        // Start listening for messages
        receiveMessage(auth: auth)
    }
    
    // MARK: - Disconnect
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    // MARK: - Event Handling
    
    func on(_ event: String, handler: @escaping (Any) -> Void) {
        if eventHandlers[event] == nil {
            eventHandlers[event] = []
        }
        eventHandlers[event]?.append(handler)
    }
    
    func removeAllHandlers() {
        eventHandlers.removeAll()
    }
    
    // MARK: - Message Processing
    
    private func receiveMessage(auth: [String: String]? = nil) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text, auth: auth)
                default:
                    break
                }
                // Continue listening
                self?.receiveMessage()
            case .failure:
                self?.isConnected = false
                // Attempt reconnect after delay
                if let auth = auth {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                        self?.webSocketTask = nil
                        self?.connect(userId: auth["userId"]!, organizationId: auth["organizationId"]!)
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ text: String, auth: [String: String]? = nil) {
        guard !text.isEmpty else { return }
        
        // Engine.IO packet types: 0=open, 1=close, 2=ping, 3=pong, 4=message
        let firstChar = text.first!
        
        switch firstChar {
        case "0":
            // Open handshake received - send Socket.IO CONNECT with auth
            if let auth = auth {
                if let authData = try? JSONSerialization.data(withJSONObject: auth),
                   let authStr = String(data: authData, encoding: .utf8) {
                    // 40 = Engine.IO message (4) + Socket.IO CONNECT (0)
                    send("40{\"auth\":\(authStr)}")
                }
            } else {
                send("40")
            }
            
            // Parse ping interval from handshake
            let payload = String(text.dropFirst())
            if let data = payload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pingInterval = json["pingInterval"] as? Int {
                startPingTimer(interval: TimeInterval(pingInterval) / 1000.0)
            }
            
        case "2":
            // Ping from server - respond with pong
            send("3")
            
        case "3":
            // Pong from server - ignore
            break
            
        case "4":
            // Socket.IO message
            handleSocketIOMessage(String(text.dropFirst()))
            
        default:
            break
        }
    }
    
    private func handleSocketIOMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        let firstChar = text.first!
        
        switch firstChar {
        case "0":
            // Socket.IO CONNECT ACK - we're fully connected
            isConnected = true
            
        case "2":
            // Socket.IO EVENT - format: 2["eventName", {data}]
            let payload = String(text.dropFirst())
            guard let data = payload.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let eventName = array.first as? String else { return }
            
            let eventData = array.count > 1 ? array[1] : [:]
            
            DispatchQueue.main.async { [weak self] in
                self?.eventHandlers[eventName]?.forEach { handler in
                    handler(eventData)
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Send
    
    private func send(_ text: String) {
        webSocketTask?.send(.string(text)) { _ in }
    }
    
    // MARK: - Ping Timer
    
    private func startPingTimer(interval: TimeInterval) {
        pingTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.send("2")
            }
        }
    }
}
