//
//  ContentView.swift
//  TestWalletAPI
//
//  Created by kokukuma on 2024/06/26.
//

import SwiftUI
import PassKit

struct ContentView: View {
    @State private var responseMessage = ""
    
    var body: some View {
        VStack {
            Button(action: {
                // postRequest()
                requestIdentityData()
            }) {
                Text("POSTリクエスト")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Text(responseMessage)
                .padding()
        }
        .padding()
    }
    
    func requestIdentityData() {
        let descriptor = PKIdentityDriversLicenseDescriptor()
        descriptor.addElements([.age(atLeast: 18)], intentToStore: .willNotStore)
        descriptor.addElements([.givenName, .familyName, .portrait], intentToStore: .mayStore(days: 30))
        
        let controller = PKIdentityAuthorizationController()
        controller.checkCanRequestDocument(descriptor) { canRequest in
            if canRequest {
                // サーバーからノンスを取得（例示のため、ここでは固定の値を使用）
                let nonce = "server-generated-nonce"
                let nonceData = nonce.data(using: .utf8)

                let request = PKIdentityRequest()
                request.descriptor = descriptor
                request.merchantIdentifier = "your-merchant-identifier"
                request.nonce = nonceData
                
                requestDocument(controller: controller, request: request)
            } else {
                print("Cannot request document")
            }
        }
    }
    
    func requestDocument(controller: PKIdentityAuthorizationController, request: PKIdentityRequest) {
        Task {
            do {
                let document = try await controller.requestDocument(request)
                // ここで、document.encryptedDataをサーバーに送信して検証
                // e.g., sendToServer(document.encryptedData)
                print("Document received: \(document)")
            } catch {
                print("Request failed: \(error.localizedDescription)")
            }
        }
    }



    func postRequest() {
        guard let url = URL(string: "https://fido-kokukuma.jp.ngrok.io/getIdentityRequest") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 送信するデータ（例としてJSONデータ）
        let postData: [String: Any] = ["protocol": "preview"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: postData, options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                // JSONデータをデコード
                let responseData = try JSONDecoder().decode(IdentityRequest.self, from: data)
                // デコードされたデータを使用
                DispatchQueue.main.async {
                    handleResponseData(responseData)
                }
            } catch {
                print("Decoding error: \(error)")
            }
        }
        
        task.resume()
    }
    
    func handleResponseData(_ responseData: IdentityRequest) {
        // ここでデコードされたデータをUIに反映させたり、他の処理を行う
        responseMessage = """
        ID: \(responseData.session_id)
        Data: \(responseData.data)
        """
    }

}

#Preview {
    ContentView()
}
