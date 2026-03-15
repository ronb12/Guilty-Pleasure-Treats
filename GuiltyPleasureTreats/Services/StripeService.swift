//
//  StripeService.swift
//  Guilty Pleasure Treats
//
//  Stripe payment integration. Uses your backend to create PaymentIntents;
//  replace baseURL with your own server or Firebase Cloud Functions.
//

import Foundation
import StripePaymentSheet

final class StripeService: ObservableObject {
    static let shared = StripeService()
    
    /// Your backend URL that creates PaymentIntents and returns client secret.
    /// In production, use Firebase Cloud Functions or your API.
    private let baseURL: String
    
    private init(baseURL: String = "https://your-backend.com") {
        self.baseURL = baseURL
    }
    
    /// Configure Stripe with publishable key (call at app launch).
    static func configure(publishableKey: String) {
        StripeAPI.defaultPublishableKey = publishableKey
    }
    
    /// Create a PaymentIntent on your backend, then present Payment Sheet.
    /// amount: total in cents (e.g. 1999 = $19.99)
    func presentPaymentSheet(
        amountCents: Int,
        orderId: String,
        customerName: String,
        customerEmail: String?
    ) async throws {
        let clientSecret = try await createPaymentIntent(amountCents: amountCents, orderId: orderId)
        
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Guilty Pleasure Treats"
        configuration.allowsDelayedPaymentMethods = false
        if let email = customerEmail {
            configuration.defaultBillingDetails.email = email
        }
        configuration.defaultBillingDetails.name = customerName
        
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        // Presenting must be done on main actor from a UI context.
        // In a real app you'd get the top view controller and call paymentSheet.present(from: vc)
        // For SwiftUI, use a wrapper that gets the window scene.
        await MainActor.run {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                paymentSheet.present(from: rootVC) { result in
                    switch result {
                    case .completed:
                        break
                    case .canceled:
                        break
                    case .failed(let error):
                        print("Payment failed: \(error)")
                    }
                }
            }
        }
    }
    
    /// Call your backend to create a PaymentIntent and return client_secret.
    private func createPaymentIntent(amountCents: Int, orderId: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/create-payment-intent") else {
            throw StripeError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "amount": amountCents,
            "currency": "usd",
            "orderId": orderId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw StripeError.backendError(String(data: data, encoding: .utf8) ?? "Unknown")
        }
        struct CreateIntentResponse: Decodable {
            let clientSecret: String
        }
        let decoded = try JSONDecoder().decode(CreateIntentResponse.self, from: data)
        return decoded.clientSecret
    }
}

enum StripeError: LocalizedError {
    case invalidURL
    case backendError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid payment URL"
        case .backendError(let msg): return "Payment error: \(msg)"
        }
    }
}
