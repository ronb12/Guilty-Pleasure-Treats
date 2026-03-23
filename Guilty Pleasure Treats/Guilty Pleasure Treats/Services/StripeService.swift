//
//  StripeService.swift
//  Guilty Pleasure Treats
//
//  Stripe payment integration. Uses your backend to create PaymentIntents;
//  replace baseURL with your Vercel (or other) backend.
//

import Combine
import Foundation

#if !os(macOS)
import StripePaymentSheet

final class StripeService: ObservableObject {
    static let shared = StripeService()
    
    /// Backend URL that creates PaymentIntents and returns client secret (set in AppConstants).
    /// Same host as Vercel API (orders, etc.); avoids mismatched env URLs.
    private let baseURL: String
    
    private init(baseURL: String = AppConstants.vercelBaseURLString ?? AppConstants.stripeBackendURLString) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/")
            ? String(baseURL.dropLast())
            : baseURL
    }
    
    /// Configure Stripe with publishable key (call at app launch).
    static func configure(publishableKey: String) {
        StripeAPI.defaultPublishableKey = publishableKey
    }

    /// Ensures the SDK has a publishable key before Payment Sheet (server may omit pk; AppConstants may hold fallback).
    static func ensurePublishableKeyConfigured() {
        let current = (StripeAPI.defaultPublishableKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty { return }
        if let app = AppConstants.stripePublishableKey?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty {
            configure(publishableKey: app)
        }
    }

    /// Call before creating an order when you intend to collect card payment on iOS.
    static func canStartCheckout() -> Bool {
        ensurePublishableKeyConfigured()
        let pk = (StripeAPI.defaultPublishableKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !pk.isEmpty
    }
    
    /// Fetches `client_secret` from your backend. Use with `makePaymentSheet` and SwiftUI `.paymentSheet(...)`.
    func fetchPaymentIntentClientSecret(amountCents: Int, orderId: String) async throws -> String {
        Self.ensurePublishableKeyConfigured()
        let trimmedPk = (StripeAPI.defaultPublishableKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPk.isEmpty else {
            throw StripeError.backendError(
                "Missing Stripe publishable key. Add it in Admin → Business Settings or AppConstants."
            )
        }
        StripeAPI.defaultPublishableKey = trimmedPk
        return try await createPaymentIntent(amountCents: amountCents, orderId: orderId)
    }

    /// Builds a `PaymentSheet` for SwiftUI presentation (see `CheckoutView` + `.paymentSheet`).
    func makePaymentSheet(clientSecret: String, customerName: String, customerEmail: String?) -> PaymentSheet {
        Self.ensurePublishableKeyConfigured()
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Guilty Pleasure Treats"
        configuration.allowsDelayedPaymentMethods = false
        if let email = customerEmail {
            configuration.defaultBillingDetails.email = email
        }
        configuration.defaultBillingDetails.name = customerName
        return PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
    }

    /// Call your backend to create a PaymentIntent and return client_secret.
    private func createPaymentIntent(amountCents: Int, orderId: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/stripe/create-payment-intent") else {
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
        guard let http = response as? HTTPURLResponse else {
            throw StripeError.backendError("Invalid response from payment server.")
        }
        guard http.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "Unknown"
            throw StripeError.backendError(raw)
        }
        struct CreateIntentResponse: Decodable {
            let clientSecret: String
            enum CodingKeys: String, CodingKey {
                case clientSecret
                case client_secret
            }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                if let s = try c.decodeIfPresent(String.self, forKey: .clientSecret) {
                    clientSecret = s
                } else {
                    clientSecret = try c.decode(String.self, forKey: .client_secret)
                }
            }
        }
        let decoded = try JSONDecoder().decode(CreateIntentResponse.self, from: data)
        return decoded.clientSecret
    }
}
#else
/// macOS: Stripe Payment Sheet is not used; checkout uses pay-by-link. This stub remains so any stray `.stripe` path fails clearly.
final class StripeService: ObservableObject {
    static let shared = StripeService()
    private init() {}
    static func configure(publishableKey: String) {}
    static func ensurePublishableKeyConfigured() {}
    static func canStartCheckout() -> Bool { false }
    func fetchPaymentIntentClientSecret(amountCents: Int, orderId: String) async throws -> String {
        throw StripeError.backendError(
            "In-app card checkout isn’t available on Mac. Use pay-by-link (place your order and pay when the shop sends the link)."
        )
    }
}
#endif

enum StripeError: LocalizedError {
    case invalidURL
    case backendError(String)
    /// User closed the sheet or payment did not complete — do not show “order confirmed” without payment.
    case paymentCanceled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid payment URL"
        case .backendError(let msg): return "Payment error: \(msg)"
        case .paymentCanceled:
            return "Payment was canceled. If an order was started, contact the shop to pay or try placing your order again."
        }
    }
}
