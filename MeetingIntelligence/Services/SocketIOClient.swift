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
    private var isConnecting = false
    private var eventHandlers: [String: [(Any) -> Void]] = [:]
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var storedAuth: [String: String]?
    private let serverURL = "wss://dashmet-rca-api.onrender.com"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }
    
    // MARK: - Connect
    
    func connect(userId: String, organizationId: String) {
        guard !isConnected, !isConnecting else { return }
        
        // Socket.IO WebSocket URL with EIO=4 (Engine.IO v4)
        guard let url = URL(string: "\(serverURL)/socket.io/?EIO=4&transport=websocket") else { return }
        
        isConnecting = true
        storedAuth = ["userId": userId, "organizationId": organizationId]
        
        // Cancel any existing task before creating a new one
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start listening for messages
        receiveMessage()
    }
    
    // MARK: - Disconnect
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        isConnecting = false
        reconnectAttempts = 0
        storedAuth = nil
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
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                default:
                    break
                }
                // Continue listening
                self.receiveMessage()
            case .failure:
                self.handleDisconnect()
            }
        }
    }
    
    private func handleDisconnect() {
        isConnected = false
        isConnecting = false
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask = nil
        
        // Attempt reconnect with exponential backoff, up to max attempts
        guard let auth = storedAuth, reconnectAttempts < maxReconnectAttempts else { return }
        
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts * reconnectAttempts) * 2.0, 30.0) // 2, 8, 18, 30, 30
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isConnected, !self.isConnecting else { return }
            self.connect(userId: auth["userId"]!, organizationId: auth["organizationId"]!)
        }
    }
    
    private func handleMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Engine.IO packet types: 0=open, 1=close, 2=ping, 3=pong, 4=message
        let firstChar = text.first!
        
        switch firstChar {
        case "0":
            // Open handshake received - send Socket.IO CONNECT with auth
            if let auth = storedAuth {
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
            isConnecting = false
            reconnectAttempts = 0
            
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
        guard webSocketTask != nil else { return }
        webSocketTask?.send(.string(text)) { [weak self] error in
            if error != nil {
                self?.handleDisconnect()
            }
        }
    }
    
    // MARK: - Ping Timer
    
    private func startPingTimer(interval: TimeInterval) {
        pingTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, self.isConnected else { return }
                self.send("2")
            }
        }
    }
}
