//
//  AppKeyAPIManager.swift
//  AppKeyIDSwift
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.
//
//  Created by Tola Voeung on 27/8/25.
//

import Foundation
import CryptoKit


@available(iOS 16.0, *)
@MainActor public var AppKeyIDAPI = AppKeyIDAPIManager.shared


@available(iOS 16.0, *)
@MainActor public class AppKeyIDAPIManager:ObservableObject {
    public static let shared = AppKeyIDAPIManager()
    
    public var appKeyRestAddress: String? = ""
    
    public var akUser:AKUser? = nil
    public var accessToken:String = ""
    public var jwt: String?
    public var idToken: String?
    
    // Configure
    @MainActor public func configure(appKeyRestAddress: String = "") {
        
        logout()
        
       
        if appKeyRestAddress == "" {
            self.appKeyRestAddress = "https://api.appkey.io"

        } else {
            self.appKeyRestAddress = appKeyRestAddress
        }
        
    }
    
    @MainActor public func signup(email:String, firstName:String, lastName:String, country:String? = nil) async throws -> AKSignupChallenge? {
        
        
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/register"
        
        do {
            let moddedHandle = email.replacingOccurrences(of: "+", with: "%2B")
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "firstName", value: firstName),
                                                URLQueryItem(name: "lastName", value: lastName),
                                                URLQueryItem(name: "country", value: country),
                                                URLQueryItem(name: "email", value: moddedHandle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            let result = try JSONDecoder().decode(AKSignupChallenge.self, from: data)
           
            
            return result
            
            
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    @MainActor public func signupConfirm(email:String, attest:AKAttestation) async throws -> AKSignupData {
        
       
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/registerConfirm"
        do {
            let moddedHandle = email.replacingOccurrences(of: "+", with: "%2B")
            let attetstRsponse = "{\"attestationObject\": \"\(attest.response.attestationObject)\", \"clientDataJSON\": \"\(attest.response.clientDataJSON)\"}"
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "email", value: moddedHandle),
                                                URLQueryItem(name: "id", value: attest.id),
                                                URLQueryItem(name: "response", value: attetstRsponse )
            ]
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
           
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            var signData = try JSONDecoder().decode(AKSignupData.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                signData.signUpToken = json["signup-token"] as? String
            }
            
            
            return signData
            
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    
    @MainActor public func signupComplete(signupToken:String, code:String) async throws -> Bool {
        
       
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }
        
        let url = "\(appKeyRestAddress)/api/authn/registerComplete"
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "code", value: code)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["signup-token": signupToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            //print("signupComplete jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            self.akUser = try makeUser(data)
            return true
            
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    @MainActor public func login(email:String) async throws -> AKLoginChallenge? {
        
       
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/login"
        
        do {
            // your post request data
            let moddedHandle = email.replacingOccurrences(of: "+", with: "%2B")
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "email", value: moddedHandle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
                        
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            let result = try JSONDecoder().decode(AKLoginChallenge.self, from: data)
            return result
            
            
        }
        catch let error as AppKeyIDError {
            print("login error \(error.message)")
            throw error
        }
        catch {
            print("login error \(error.localizedDescription)")
            throw error
        }
    }
    
    
    @MainActor public func loginComplete(email:String, assertion:AKAssertion) async throws -> AKUser? {
        
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/loginComplete"
        do {
            
            
            let assertRsponse = "{\"authenticatorData\": \"\(assertion.response.authenticatorData)\", \"clientDataJSON\": \"\(assertion.response.clientDataJSON)\", \"signature\": \"\(assertion.response.signature)\", \"userHandle\": \"\(assertion.response.userHandle)\"}"
            
            let moddedHandle = email.replacingOccurrences(of: "+", with: "%2B")
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "email", value: moddedHandle),
                                                URLQueryItem(name: "id", value: assertion.id),
                                                URLQueryItem(name: "response", value: assertRsponse )
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
                        
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
           
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            self.akUser = try makeUser(data)
            return self.akUser!
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
            print(error.localizedDescription)
            throw error
        }
    }
    
    
    
    // user must do login ceremony process to get new access token before call this deleteAccount
    @MainActor public func deleteAccount() async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/deleteAccount"
        do {
             
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            return true
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    
    @MainActor public func verify(email:String) async throws -> AKLoginChallenge? {
     
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/verify"
        
        do {
            // your post request data
            let moddedHandle = email.replacingOccurrences(of: "+", with: "%2B")
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "email", value: moddedHandle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            let result = try JSONDecoder().decode(AKLoginChallenge.self, from: data)
            
            return result
            
        }
        catch let error as AppKeyIDError {
           
            throw error
        }
        catch {
            
            throw error
        }
    }
    
    @MainActor public func verifyComplete(email:String, assertion:AKAssertion) async throws -> AKUser {
        
      
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/verifyComplete"
        do {
            
            
            let assertRsponse = "{\"authenticatorData\": \"\(assertion.response.authenticatorData)\", \"clientDataJSON\": \"\(assertion.response.clientDataJSON)\", \"signature\": \"\(assertion.response.signature)\", \"userHandle\": \"\(assertion.response.userHandle)\"}"
            
            let moddedHandle = email.replacingOccurrences(of: "+", with: "%2B")
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "email", value: moddedHandle),
                                                URLQueryItem(name: "id", value: assertion.id),
                                                URLQueryItem(name: "response", value: assertRsponse )
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            
            var user = try JSONDecoder().decode(AKUser.self, from: data)
            
            self.akUser = try makeUser(data)
            return self.akUser!
            
             
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
           
            throw error
        }
    }
    
    
    
    @MainActor public func updateProfile(firstName:String, lastName:String, country:String? = nil) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/updateProfile"
        do {
            
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                URLQueryItem(name: "firstName", value: firstName),
                URLQueryItem(name: "lastName", value: lastName),
                URLQueryItem(name: "country", value: country)
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            return true
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    
    
    @MainActor public func addPasskey() async throws -> AKSignupChallenge {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/addPasskey"
        
        do {
            
            var requestBodyComponents = URLComponents()
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            let result = try JSONDecoder().decode(AKSignupChallenge.self, from: data)
            
            return result
            
        }
        catch let error as AppKeyIDError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    @MainActor public func addPasskeyComplete(attest:AKAttestation) async throws -> AKUser {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/addPasskeyComplete"
        
        do {
            
            let attetstRsponse = "{\"attestationObject\": \"\(attest.response.attestationObject)\", \"clientDataJSON\": \"\(attest.response.clientDataJSON)\"}"
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "id", value: attest.id),
                                                URLQueryItem(name: "response", value: attetstRsponse )
            ]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
             
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            self.akUser = try makeUser(data)
            return self.akUser!
            
        }
        catch let error as AppKeyIDError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    
    @MainActor public func updatePasskey(keyId:String, keyName:String) async throws -> AKUser? {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/updatePasskey"
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "keyId", value: keyId),
                                                URLQueryItem(name: "keyName", value: keyName)
            ]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
             
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            self.akUser = try makeUser(data)
            return self.akUser!
            
        }
        catch let error as AppKeyIDError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    @MainActor public func removePasskey(keyId:String) async throws -> AKUser? {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/authn/removePasskey"
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "keyId", value: keyId)
            ]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
             
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            self.akUser = try makeUser(data)
            return self.akUser!
            
        }
        catch let error as AppKeyIDError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    
    
    
    @MainActor public func scanAppKeyQR(url:String) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }
        
        do {
            
            if !url.contains("/api/appkeyid/scan/") {
                throw AppKeyIDError.invalidData
            }
           
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            urlRequest.httpMethod = "GET"
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            return true
            
             
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
           
            throw error
        }
    }
    
    
    
    @MainActor public func remoteAppKeyID(appId:String) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyIDError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appkeyid/remove"
        
        do {
           
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "appId", value: appId)
            ]
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyIDError.checkResponse(data: data, response: response)
            
            return true
            
             
        }
        catch let error as AppKeyIDError {
            throw error
        }
        catch {
           
            throw error
        }
    }
    
    
    
    
    func makeUser(_ data: Data) throws -> AKUser {
        do {
            var user = try JSONDecoder().decode(AKUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
                user.idToken = json["id-token"] as? String
                
                self.jwt = user.jwt
                self.idToken = user.idToken
            }
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            
            return user
            
        }
        catch {
             throw error
        }
       
    }
    
    
    @MainActor public func logout() {
        
        self.akUser = nil
        self.accessToken = ""
        self.idToken = ""
        self.jwt = nil
    }
    
}
