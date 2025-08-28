//
//  AKDataModel.swift
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


 
public struct AKLoginChallenge:Decodable {
    
    
    public var rpId: String
    public var challenge:String
    public var timeout: Int
    public var userVerification: String
    public var requireAddPasskey:Bool?
}

public struct AKSingUpUser:Codable {
    public var id:String = ""
    public var name:String = ""
    public var displayName:String = ""
    public var email: String = ""
}


public struct AKCredential: Decodable {
    public var id:String
    public var type:String
}

 
public struct AKRegister: Decodable {
    public var status:Bool
    public var message: String
    public var user: AKUser
}

 
public struct AKErrorReturn: Decodable {
    public var code:Bool
    public var message: String
}

 
public struct AKSignupChallenge: Decodable {
    public var challenge:String
    public var user: AKSingUpUser
}

 
public struct AKAttestReponse:Codable {
    public var attestationObject:String
    public var clientDataJSON:String
}

 
public struct AKAttestation:Codable {
    public var id:String
    public var rawId:String?
    public var authenticatorAttachment:String?
    public var type:String?
    public var response:AKAttestReponse
}

 
public struct AKAssertion:Codable {
    public var id:String
    public var rawId:String?
    public var authenticatorAttachment:String?
    public var type:String?
    public var response:AKAssertResponse
}

 
public struct AKAssertResponse:Codable {
    public var authenticatorData:String
    public var clientDataJSON:String
    public var signature:String
    public var userHandle:String
}

 
public struct AKAuthenticationInfo:Decodable {
    public let newCounter:Int
    public let credentialID:String
    public let userVerified:Bool
    public let credentialDeviceType:String
    public let credentialBackedUp:Bool
    public let origin:String
    public let rpID:String
}


 
public struct AKSignupData:Codable {
    
    public let email:String
    public let message:String
    public var signUpToken:String?
}

 
public struct AKPasskey:Codable {
    public let id:String
    public let publicKey:String
    public let counter:Int
    public let deviceType:String
    public let credentialBackedUp:Bool
    public let name:String
    public let platform:String
    public let lastUsed: String
    public let createdAt: String
    public let updatedAt: String
    
}
 
struct AKLoginComplete:Decodable {
    public let verified:Bool
    public let authenticationInfo:AKAuthenticationInfo
    
}


 
public struct AKUser:Codable {
    public let userId:String
    public let firstName:String
    public let lastName:String
    public let email:String
    public let status:String
    public let authenticators:[AKPasskey]
    public var planId:String?
    public var accessToken:String?
    public var signUpToken:String?
    public let company:String?
    public let country:String?
    
}
