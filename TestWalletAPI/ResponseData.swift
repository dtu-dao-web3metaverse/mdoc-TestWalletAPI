//
//  ResponseData.swift
//  TestWalletAPI
//
//  Created by kokukuma on 2024/06/26.
//

import Foundation

struct IdentityRequestData: Codable {
    let nonce: String
    let readerPublicKey: String?
    // let selector: String
}

struct IdentityRequest: Codable {
    let session_id: String
    let data: IdentityRequestData
}

struct VerifyResponse: Codable {
    let error: String?
    let elements: [Element]?
}

struct Element: Codable, Identifiable {
    let id = UUID()
    let namespace: String
    let identifier: String
    let value: Any
    
    enum CodingKeys: String, CodingKey {
        case namespace
        case identifier
        case value
    }
    
    init(namespace: String, identifier: String, value: Any) {
        self.namespace = namespace
        self.identifier = identifier
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        namespace = try container.decode(String.self, forKey: .namespace)
        identifier = try container.decode(String.self, forKey: .identifier)
        
        if let intValue = try? container.decode(Int.self, forKey: .value) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .value) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self, forKey: .value) {
            value = boolValue
        } else if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            value = doubleValue
        } else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Unsupported value type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(namespace, forKey: .namespace)
        try container.encode(identifier, forKey: .identifier)
        
        if let intValue = value as? Int {
            try container.encode(intValue, forKey: .value)
        } else if let stringValue = value as? String {
            try container.encode(stringValue, forKey: .value)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue, forKey: .value)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue, forKey: .value)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value type"))
        }
    }

}
