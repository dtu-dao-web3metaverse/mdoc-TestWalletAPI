//
//  ResponseData.swift
//  TestWalletAPI
//
//  Created by kokukuma on 2024/06/26.
//

import Foundation

struct IdentityRequestData: Codable {
    let nonce: String
    let readerPublicKey: String
    // let selector: String
}

struct IdentityRequest: Codable {
    let session_id: String
    let data: IdentityRequestData
}
