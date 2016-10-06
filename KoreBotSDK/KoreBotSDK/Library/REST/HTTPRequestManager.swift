//
//  HTTPRequestManager.swift
//  KoreBotSDK
//
//  Created by Srinivas Vasadi on 21/04/16.
//  Copyright © 2016 Kore. All rights reserved.
//

import Foundation
import AFNetworking
import Mantle

public class HTTPRequestManager : NSObject {
    var options: AnyObject?
    static var instance: HTTPRequestManager!

    // MARK: request manager shared instance
    public static let sharedManager : HTTPRequestManager = {
        if (instance == nil) {
            instance = HTTPRequestManager()
        }
        return instance
    }()
    
    // MARK: requests
    public func authorizeWithToken(accessToken: String!, botInfo: AnyObject!, success:((_ token: String?) -> Void)?, failure:((_ error: Error) -> Void)?) {
        let urlString: String = Constants.URL.jwtUrl
        let requestSerializer = AFJSONRequestSerializer()
        requestSerializer.httpMethodsEncodingParametersInURI = Set.init(["GET"]) as Set<String>
        requestSerializer.setValue("Keep-Alive", forHTTPHeaderField:"Connection")        
        requestSerializer.setValue(accessToken, forHTTPHeaderField:"Authorization")
        let parameters: NSDictionary = ["botInfo": botInfo]

        let operationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(baseURL: NSURL.init(string: Constants.URL.baseUrl) as URL!)
        operationManager.responseSerializer = AFJSONResponseSerializer.init()
        operationManager.requestSerializer = requestSerializer
        operationManager.post(urlString, parameters: parameters, success: { (operation, responseObject) in
            let error: NSError?
            let jwt: JwtModel = try! (MTLJSONAdapter.model(of: JwtModel.self, fromJSONDictionary: responseObject! as! [NSObject : AnyObject]) as! JwtModel)
            
            success?(jwt.jwtToken)

        }) { (operation, error) in
            failure?(error!)
        }
    }
    
    public func signInWithToken(token: AnyObject!, botInfo: AnyObject!, success:((_ user: UserModel?, _ authInfo: AuthInfoModel?) -> Void)?, failure:((_ error: Error) -> Void)?)  {
        let urlString: String = Constants.URL.jwtAuthorizationUrl
        let requestSerializer = AFJSONRequestSerializer()
        requestSerializer.httpMethodsEncodingParametersInURI = Set.init(["GET"]) as Set<String>
        requestSerializer.setValue("Keep-Alive", forHTTPHeaderField:"Connection")
        let parameters: NSDictionary = ["assertion":token!, "botInfo": botInfo]

        let operationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(baseURL: NSURL.init(string: Constants.URL.baseUrl) as URL!)
        operationManager.responseSerializer = AFJSONResponseSerializer.init()
        operationManager.requestSerializer = requestSerializer
        operationManager.post(urlString, parameters: parameters, success: { (operation, responseObject) in
            let error: Error?
            if responseObject is [NSObject : AnyObject] {
                let dictionary = responseObject as! [String : AnyObject]
                let authorization: [NSObject : AnyObject] = dictionary["authorization"] as! [NSObject : AnyObject]
                let userInfo: [NSObject : AnyObject] = dictionary["userInfo"] as! [NSObject : AnyObject]
                let authInfo: AuthInfoModel = try! (MTLJSONAdapter.model(of: AuthInfoModel.self, fromJSONDictionary: authorization) as! AuthInfoModel)
                let user: UserModel = try! (MTLJSONAdapter.model(of: UserModel.self, fromJSONDictionary: userInfo) as! UserModel)
                success?(user, authInfo)
            } else {
                failure?(NSError(domain: "", code: 0, userInfo: [:]))
            }
            print(operation?.responseObject)
        }) { (operation, error) in
            if (operation?.responseObject != nil) {
                print(operation?.responseObject)
            }
            failure?(error!)
        }
    }
    
    public func getRtmUrlWithAuthInfoModel(authInfo: AuthInfoModel!, botInfo: AnyObject!, success:((_ botInfo: BotInfoModel?) -> Void)?, failure:((_ error: Error) -> Void)?)  {
        let urlString: String = Constants.URL.rtmUrl
        let requestSerializer = AFJSONRequestSerializer()
        requestSerializer.httpMethodsEncodingParametersInURI = Set.init(["GET"]) as Set<String>
        requestSerializer.setValue("Keep-Alive", forHTTPHeaderField:"Connection")
        
        let accessToken: String = String(format: "%@ %@", authInfo.tokenType!, authInfo.accessToken!)
        requestSerializer.setValue(accessToken, forHTTPHeaderField:"Authorization")

        let parameters: NSDictionary = ["botInfo": botInfo, "authorization": accessToken]
        let operationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(baseURL: NSURL.init(string: Constants.URL.baseUrl) as URL!)
        operationManager.responseSerializer = AFJSONResponseSerializer.init()
        operationManager.requestSerializer = requestSerializer
        operationManager.post(urlString, parameters: parameters, success: { (operation, responseObject) in
            print(responseObject)
            let error: NSError?
            let botInfo: BotInfoModel = try! (MTLJSONAdapter.model(of: BotInfoModel.self, fromJSONDictionary: responseObject! as! [NSObject : AnyObject]) as! BotInfoModel)
            
            success?(botInfo)
            print(operation?.responseObject)
        }) { (operation, requestError) in
            if (operation?.responseObject != nil) {
                print(operation?.responseObject)
            }
            failure?(requestError!)
        }
    }
    
    // MARK: anonymous user login
    public func anonymousUserSignIn(clientId: String!, success:((_ user: UserModel?, _ authInfo: AuthInfoModel?) -> Void)?, failure:((_ error: NSError) -> Void)?) {
        let urlString: String = Constants.URL.signInUrl
        let requestSerializer = AFJSONRequestSerializer()
        requestSerializer.httpMethodsEncodingParametersInURI = Set.init(["GET"]) as Set<String>
        requestSerializer.setValue("Keep-Alive", forHTTPHeaderField:"Connection")
        
        let uuid = Constants.getUUID()
        let parameters: NSDictionary = ["assertion":["subject":uuid, "issuer": clientId!]]
        
        let operationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(baseURL: NSURL.init(string: Constants.URL.baseUrl) as URL!)
        operationManager.responseSerializer = AFJSONResponseSerializer.init()
        operationManager.requestSerializer = requestSerializer
        operationManager.post(urlString, parameters: parameters, success: { (operation, responseObject) in
            let error: NSError?
            
            if responseObject is [NSObject : AnyObject] {
                let dictionary = responseObject as! [String : AnyObject]
                let authorization: [NSObject : AnyObject] = dictionary["authorization"] as! [NSObject : AnyObject]
                let userInfo: [NSObject : AnyObject] = dictionary["userInfo"] as! [NSObject : AnyObject]
                let authInfo: AuthInfoModel = try! (MTLJSONAdapter.model(of: AuthInfoModel.self, fromJSONDictionary: authorization) as! AuthInfoModel)
                let user: UserModel = try! (MTLJSONAdapter.model(of: UserModel.self, fromJSONDictionary: userInfo) as! UserModel)
                success?(user, authInfo)
            } else {
                failure?(NSError(domain: "", code: 0, userInfo: [:]))
            }
        }) { (operation, error) in
            if (operation?.responseObject != nil) {
                print(operation?.responseObject)
            }
            failure?(error as! NSError)
        }
    }
    
    // MARK: subscribe/ unsubscribte for
    public func subscribeToNotifications(deviceToken: Data!, userInfo: UserModel!, authInfo: AuthInfoModel!, success:((_ staus: Bool) -> Void)?, failure:((_ error: Error) -> Void)?) {
        let urlString: String = Constants.URL.subscribeUrl(userId: userInfo.userId)
        let requestSerializer = AFJSONRequestSerializer()
        requestSerializer.httpMethodsEncodingParametersInURI = Set.init(["GET"]) as Set<String>
        requestSerializer.setValue("Keep-Alive", forHTTPHeaderField:"Connection")
        
        let accessToken: String = String(format: "%@ %@", authInfo.tokenType!, authInfo.accessToken!)
        requestSerializer.setValue(accessToken, forHTTPHeaderField:"Authorization")

        let deviceId: String! = deviceToken.hexadecimal()
        if (deviceId == nil) {
            failure?(NSError(domain: "KoreBotSDK", code: 0, userInfo: ["message": "deviceId is nil"]))
            return
        }
        let parameters: NSDictionary = ["deviceId": deviceId, "osType": "ios"]
        
        let operationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(baseURL: NSURL.init(string: Constants.URL.baseUrl) as URL!)
        operationManager.responseSerializer = AFJSONResponseSerializer.init()
        operationManager.requestSerializer = requestSerializer
        operationManager.post(urlString, parameters: parameters, success: { (operation, responseObject) in
            success?(true)
        }) { (operation, error) in
            if (operation?.responseObject != nil) {
                print(operation?.responseObject)
            }
            failure?(error!)
        }
    }
    
    public func unsubscribeToNotifications(deviceToken: Data!, userInfo: UserModel!, authInfo: AuthInfoModel!, success:((_ staus: Bool) -> Void)?, failure:((_ error: Error) -> Void)?) {
        let urlString: String = Constants.URL.unSubscribeUrl(userId: userInfo.userId)
        let requestSerializer = AFJSONRequestSerializer()
        requestSerializer.httpMethodsEncodingParametersInURI = Set.init(["GET"]) as Set<String>
        requestSerializer.setValue("Keep-Alive", forHTTPHeaderField:"Connection")
        
        let accessToken: String = String(format: "%@ %@", authInfo.tokenType!, authInfo.accessToken!)
        requestSerializer.setValue(accessToken, forHTTPHeaderField:"Authorization")
        
        let deviceId: String! = deviceToken.hexadecimal()
        if (deviceId == nil) {
            failure?(NSError(domain: "KoreBotSDK", code: 0, userInfo: ["message": "deviceId is nil"]))
            return
        }
        
        let parameters: NSDictionary = ["deviceId": deviceId]
        
        let operationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(baseURL: NSURL.init(string: Constants.URL.baseUrl) as URL!)
        operationManager.responseSerializer = AFJSONResponseSerializer.init()
        operationManager.requestSerializer = requestSerializer
        operationManager.delete(urlString, parameters: parameters, success: { (operation, responseObject) in
            success?(true)
        }) { (operation, error) in
            if (operation?.responseObject != nil) {
                print(operation?.responseObject)
            }
            failure?(error!)
        }
    }
}

extension Data {
    func hexadecimal() -> String {
        return map { String(format: "%02x", $0) }
            .joined(separator: "")
    }
}
