//
//  ContentView.swift
//  TestWalletAPI
//
//  Created by kokukuma on 2024/06/26.
//

import SwiftUI
import PassKit

let baseURL = "http://localhost:8080"
//let baseURL = "ngrokで採番したサーバのURL"

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

struct IdentityElementSelection: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: PKIdentityElement
    var isSelected: Bool
}

struct ContentView: View {
    @State private var responseMessage = ""
    @State private var elements: [Element] = []
    @State private var showElementSelector = false
    @State private var selectableElements: [IdentityElementSelection] = [
        IdentityElementSelection(label: "Given Name", value: .givenName, isSelected: false),
        IdentityElementSelection(label: "Family Name", value: .familyName, isSelected: false),
        IdentityElementSelection(label: "Address", value: .address, isSelected: false),
        IdentityElementSelection(label: "Age 18+", value: .age(atLeast: 18), isSelected: false),
        IdentityElementSelection(label: "Document Number", value: .documentNumber, isSelected: false),
        IdentityElementSelection(label: "Issuing Authority", value: .issuingAuthority, isSelected: false)
    ]

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
            .padding(.bottom, 10)

            Button(action: {
                showElementSelector = true
            }) {
                Text("Verify with Wallet API\n(select element)")
                    .multilineTextAlignment(.center)
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
            } else {
                Text(responseMessage).padding()
            }
            Text("Contact: jpabweb3@abeam.com\nThis is a test app for internal verification purposes only.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.top, 20)

        }
        .padding()
        .sheet(isPresented: $showElementSelector) {
            VStack {
                Text("Select Elements to Present")
                    .font(.headline)
                    .padding()

                List {
                    ForEach($selectableElements) { $item in
                        Toggle(isOn: $item.isSelected) {
                            Text(item.label)
                        }
                    }
                }

                HStack {
                    Button("Cancel") {
                        showElementSelector = false
                    }
                    .padding()

                    Spacer()

                    Button("OK") {
                        showElementSelector = false
                        elements.removeAll()
                        Task {
                            await main(useSelectedElements: true)
                        }
                    }
                    .padding()
                }
            }
        }
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

    func main(useSelectedElements: Bool = false) async {
        do {
            let req = try await fetchIdentityRequest()

            let descriptor = PKIdentityDriversLicenseDescriptor()
            let selected = useSelectedElements ? selectableElements.filter { $0.isSelected }.map { $0.value } : [.age(atLeast: 18), .documentNumber, .issuingAuthority, .givenName, .familyName, .address]

            descriptor.addElements(selected, intentToStore: .willNotStore)

            let nonceData = decodeBase64URLString(req.data.nonce)

            let request = PKIdentityRequest()
            request.descriptor = descriptor
            request.merchantIdentifier = "PassKit_Identity_Test_Merchant_ID"
            request.nonce = nonceData

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

                guard let url = URL(string: "\(baseURL)/verifyIdentityResponse") else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"

                let postData: [String: Any] = [
                    "session_id": session_id,
                    "protocol": "apple",
                    "data": document.encryptedData.base64URLEncodedString(),
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
        let url = URL(string: "\(baseURL)/getIdentityRequest")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let postData: [String: Any] = ["protocol": "apple"]
        request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }

        return try JSONDecoder().decode(IdentityRequest.self, from: data)
    }

    func handleResponseData(_ responseData: VerifyResponse) {
        if let error = responseData.error {
            responseMessage = "Error: \(error)"
        } else {
            responseMessage = "No error"
        }

        elements = responseData.elements ?? []
    }
}

#Preview {
    ContentView()
}
