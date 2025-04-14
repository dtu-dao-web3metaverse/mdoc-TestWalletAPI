//
//  ContentView.swift
//  TestWalletAPI
//
//  Created by kokukuma on 2024/06/26.
//

import SwiftUI
import PassKit

// let baseURL = "https://fido-kokukuma.jp.ngrok.io"
//let baseURL = "http://localhost:8080"
let baseURL = "https://0312-240d-1a-fd8-8700-316d-89df-734b-85f7.ngrok-free.app"
extension Data {
    func base64URLEncodedString() -> String {
        let base64String = self.base64EncodedString()
        let base64URLString = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return base64URLString
    }
}

struct ContentView: View {
    @State private var responseMessage = ""
    @State private var elements: [Element] = []
    
    var body: some View {
        VStack {
            Button(action: {
                elements.removeAll()
                Task {
                    await main()
                }
            }) {
                Text("Verify with Wallet API")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if !elements.isEmpty {
                List(elements) { element in
                    VStack(alignment: .leading) {
                        Text("Namespace: \(element.namespace)")
                        Text("Identifier: \(element.identifier)")
                        Text("Value: \(String(describing: element.value))")
                    }
                    .padding()
                }
            }else{
                Text(responseMessage).padding()
            }

        }
        .padding()
    }
    
    func decodeBase64URLString(_ base64URLString: String) -> Data? {
        var base64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = base64.count % 4
        if paddingLength > 0 {
            base64.append(String(repeating: "=", count: 4 - paddingLength))
        }

        return Data(base64Encoded: base64)
    }

    
    func main() async {
        do {
            let req = try await fetchIdentityRequest()
            
            let descriptor = PKIdentityDriversLicenseDescriptor()
            descriptor.addElements([.age(atLeast: 18), .documentNumber, .issuingAuthority], intentToStore: .willNotStore)
            descriptor.addElements([.givenName, .familyName, .address,], intentToStore: .mayStore)
            // descriptor.addElements([.dateOfBirth], intentToStore: .mayStore(days: 300000))

            // let nonceData = req.data.nonce.data(using: .utf8)
            let nonceData = decodeBase64URLString(req.data.nonce)

            let request = PKIdentityRequest()
            request.descriptor = descriptor
            request.merchantIdentifier = "PassKit_Identity_Test_Merchant_ID"
            request.nonce = nonceData

            // @@ nonce,merchantId,publickeyをログに出力
            print("🔍 nonce: \(nonceData?.map { String(format: "%02x", $0) }.joined() ?? "nil"))")
            print("🧾 merchantIdentifier: \(request.merchantIdentifier ?? "nil")")
            print("🔑 readerPublicKey (base64): \(req.data.readerPublicKey ?? "nil")")
            
            
            let controller = PKIdentityAuthorizationController()
            controller.checkCanRequestDocument(descriptor) { canRequest in
                if canRequest {
                    requestDocument(controller: controller, request: request, session_id: req.session_id)
                } else {
                    print("Cannot request document")
                }
            }
        } catch {
            DispatchQueue.main.async {
                responseMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    func requestDocument(controller: PKIdentityAuthorizationController, request: PKIdentityRequest, session_id: String) {
        Task {
            do {
                let document = try await controller.requestDocument(request)

                // @@提示データの大きさ確認
                print("✅ encryptedData byte size: \(document.encryptedData.count)")

                guard let url = URL(string: "\(baseURL)/verifyIdentityResponse") else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                let postData: [String: Any] = [
                    "session_id": session_id,
                    "protocol": "apple",
                    "data": document.encryptedData.base64URLEncodedString(),
                    // "origin": "dummy",
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: postData, options: [])
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("Error: \(error)")
                        return
                    }
                    
                    guard let data = data else { return }
                    
                    do {
                        let responseData = try JSONDecoder().decode(VerifyResponse.self, from: data)
                        DispatchQueue.main.async {
                            handleResponseData(responseData)
                        }
                    } catch {
                        print("Decoding error: \(error)")
                    }
                }
                task.resume()
                
           } catch {
                print("Request failed: \(error.localizedDescription)")
            }
        }
    }

    func fetchIdentityRequest() async throws -> IdentityRequest {
        let url = URL(string: "\(baseURL)/getIdentityRequest")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let postData: [String: Any] = ["protocol": "apple"]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])
        } catch {
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }
        
        let responseData = try JSONDecoder().decode(IdentityRequest.self, from: data)
        return responseData
    }


    func handleResponseData(_ responseData: VerifyResponse) {
        if let error = responseData.error {
            responseMessage = "Error: \(error)"
        } else {
            responseMessage = "No error"
        }

        if let elements = responseData.elements {
            self.elements = elements
        } else {
            self.elements = []
        }
    }

}

#Preview {
    ContentView()
}
