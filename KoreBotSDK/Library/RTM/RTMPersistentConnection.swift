//
//  KoreRTMClient.swift
//  KoreBotSDK
//
//  Created by developer@kore.com on 21/05/16.
//  Copyright © 2016 Kore Inc. All rights reserved.
//

import UIKit
import SocketRocket
import Mantle

@objc public protocol RTMPersistentConnectionDelegate {
    func rtmConnectionDidOpen()
    func rtmConnectionReady()
    func rtmConnectionDidClose(_ code: Int, reason: String?)
    func rtmConnectionDidFailWithError(_ error: NSError)
    @objc optional func didReceiveMessage(_ message: String)
    @objc optional func didReceiveMessageAck(_ ack: Ack)
    func didReceivedUserMessage(_ userMessageDict:[String:Any])
}

open class RTMTimer: NSObject {
    public enum RTMTimerState {
        case suspended
        case resumed
    }
    public var pingInterval: TimeInterval = 10.0
    open var timer: DispatchSourceTimer?
    open var eventHandler: (() -> Void)?
    open var state: RTMTimerState = .suspended
    
    // MARK: - init
    public init(timeInterval: TimeInterval = 10.0) {
        super.init()
        pingInterval = timeInterval
        initalizeTimer()
    }
    
    func initalizeTimer() {
        let intervalInNSec = pingInterval * Double(NSEC_PER_SEC)
        let startTime = DispatchTime.now() + Double(intervalInNSec) / Double(NSEC_PER_SEC)
        
        timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
        timer?.schedule(deadline: startTime, repeating: pingInterval)
        timer?.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
    }
    
    // MARK: -
    open func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer?.resume()
    }
    
    open func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer?.suspend()
    }
    
    // MARK: -
    deinit {
        timer?.setEventHandler {}
        timer?.cancel()
        
        resume()
        eventHandler = nil
    }
}

open class RTMPersistentConnection : NSObject, SRWebSocketDelegate {
    var botInfo: BotInfoModel!
    fileprivate var botInfoParameters: [String: Any]?
    fileprivate var reWriteOptions: [String: Any]?

    var websocket: SRWebSocket?
    var connectionDelegate: RTMPersistentConnectionDelegate?
    
    fileprivate var timerSource = RTMTimer()
    //    fileprivate let pingInterval: TimeInterval
    fileprivate var receivedLastPong = true
    open var tryReconnect = false
    
    // MARK: init
    override public init() {
        super.init()
    }
    
    public func connect(botInfo: BotInfoModel, botInfoParameters: [String: Any]?, reWriteOptions: [String: Any]? = nil, tryReconnect: Bool) {
        self.botInfo = botInfo
        self.botInfoParameters = botInfoParameters
        self.reWriteOptions = reWriteOptions
        self.tryReconnect = tryReconnect
        start()
    }
    
    open func start() {
        guard var urlString = botInfo.botUrl else {
            print("botUrl is nil")
            return
        }
        if tryReconnect == true {
            urlString.append("&isReconnect=true")
        }
        
        var urlComponents = URLComponents(string: urlString)
        if let scheme = reWriteOptions?["scheme"] as? String {
            urlComponents?.scheme = scheme
        }
        if let host = reWriteOptions?["host"] as? String {
            urlComponents?.host = host
        }
        if let port = reWriteOptions?["port"] as? Int {
            urlComponents?.port = port
        }
        
        if let url = urlComponents?.url {
            receivedLastPong = true
            websocket = SRWebSocket(urlRequest: URLRequest(url: url))
            websocket?.delegate = self
            websocket?.open()
        }
    }
    
    open func disconnect() {
        self.websocket?.close()
    }
    
    // MARK: WebSocketDelegate methods
    open func webSocketDidOpen(_ webSocket: SRWebSocket) {
        self.connectionDelegate?.rtmConnectionDidOpen()
        
        timerSource.eventHandler = { [weak self] in
            if self?.receivedLastPong == false {
                // we did not receive the last pong
                // abort the socket so that we can spin up a new connection
                // self.websocket.close()
                // self.timerSource.suspend()
                // self.connectionDelegate?.rtmConnectionDidFailWithError(NSError())
            } else if self?.websocket?.readyState == .CLOSED || self?.websocket?.readyState == .CLOSING {
                self?.websocket?.close()
                self?.timerSource.suspend()
            } else if self?.websocket?.readyState == .OPEN {
                
                // we got a pong recently
                // send another ping
                self?.receivedLastPong = false
                _ = try? self?.websocket?.sendPing(Data())
            }
        }
        timerSource.resume()
    }
    
    open func webSocket(_ webSocket: SRWebSocket, didFailWithError error: Error) {
        self.connectionDelegate?.rtmConnectionDidFailWithError(error as NSError)
    }
    
    public func webSocket(_ webSocket: SRWebSocket, didCloseWithCode code: Int, reason: String?, wasClean: Bool) {
        self.connectionDelegate?.rtmConnectionDidClose(code, reason: reason)
    }
    
    open func webSocket(_ webSocket: SRWebSocket, didReceivePong pongPayload: Data?) {
        self.receivedLastPong = true
    }
    
    open func webSocket(_ webSocket: SRWebSocket, didReceiveMessage message: Any) {
        print(message)
        guard let message = message as? String,
            let responseObject = convertStringToDictionary(message),
            let type = responseObject["type"] as? String else {
                return
        }
        switch type {
        case "ready":
            connectionDelegate?.rtmConnectionReady()
        case "ok":
            if let model = try? MTLJSONAdapter.model(of: Ack.self, fromJSONDictionary: responseObject), let ack = model as? Ack {
                connectionDelegate?.didReceiveMessageAck?(ack)
            }
        case "bot_response":
            print("received: \(responseObject)")
            guard let array = responseObject["message"] as? Array<[String: Any]>, array.count > 0 else {
                return
            }
            connectionDelegate?.didReceiveMessage?(message)
            
        case "user_message":
            connectionDelegate?.didReceivedUserMessage(responseObject)
//            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "User_Message_Received"), object: responseObject)
        default:
            break
        }
    }
    
    open func webSocketShouldConvertTextFrameToString() -> ObjCBool {
        return true
    }
    
    // MARK: sending message
    open func sendMessage(_ message: String, parameters: [String: Any], options: [String: Any]?) {
        guard let readyState = self.websocket?.readyState else {
            return
        }
        switch (readyState) {
        case .CONNECTING:
            print("Socket is in CONNECTING state")
            break
        case .CLOSED:
            self.start()
            print("Socket is in CLOSED state")
            break
        case .CLOSING:
            print("Socket is in CLOSING state")
            break
        case .OPEN:
            print("Socket is in OPEN state")
            let dictionary: NSMutableDictionary = NSMutableDictionary()
            let messageObject: NSMutableDictionary = NSMutableDictionary()
            messageObject.addEntries(from: ["body": message, "attachments":[], "customData": parameters] as [String : Any])
            if let object = options {
                messageObject.addEntries(from: object)
            }
            
            dictionary.setObject(messageObject, forKey: "message" as NSCopying)
            dictionary.setObject("/bot.message", forKey: "resourceid" as NSCopying)
            if (self.botInfoParameters != nil) {
                dictionary.setObject(self.botInfoParameters as Any, forKey: "botInfo" as NSCopying)
            }
            let uuid: String = Constants.getUUID()
            dictionary.setObject(uuid, forKey: "id" as NSCopying)
            dictionary.setObject(uuid, forKey: "clientMessageId" as NSCopying)
            dictionary.setObject("iOS", forKey: "client" as NSCopying)

            let meta = ["timezone": TimeZone.current.identifier, "locale": Locale.current.identifier]
            dictionary.setValue(meta, forKey: "meta")
            
            debugPrint("send: \(dictionary)")
            
            let jsonData = try! JSONSerialization.data(withJSONObject: dictionary, options: JSONSerialization.WritingOptions.prettyPrinted)
            self.websocket?.send(jsonData)
            break
        }
    }
    
    // MARK: helpers
    func convertStringToDictionary(_ text: String) -> [String:AnyObject]? {
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }
}
