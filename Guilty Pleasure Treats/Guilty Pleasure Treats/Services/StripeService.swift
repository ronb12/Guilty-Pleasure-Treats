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
import UIKit

final class StripeService: ObservableObject {
    static let shared = StripeService()
    
    /// Backend URL that creates PaymentIntents and returns client secret (set in AppConstants).
    private let baseURL: String
    
    private init(baseURL: String = AppConstants.stripeBackendURLString) {
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
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                guard let presenter = Self.topViewControllerForPaymentSheet() else {
                    continuation.resume(throwing: StripeError.backendError(
                        "Could not open the payment screen. Close and reopen checkout, then try again."
                    ))
                    return
                }
                paymentSheet.present(from: presenter) { result in
                    switch result {
                    case .completed:
                        continuation.resume()
                    case .canceled:
                        continuation.resume()
                    case .failed(let error):
                        continuation.resume(throwing: StripeError.backendError(error.localizedDescription))
                    }
                }
            }
        }
    }
    
    /// SwiftUI apps often need the topmost VC; presenting from `rootViewController` alone can fail silently.
    private static func topViewControllerForPaymentSheet() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene.windows.first?.rootViewController
        else { return nil }
        return topPresented(from: root)
    }
    
    private static func topPresented(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topPresented(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topPresented(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topPresented(from: selected)
        }
        return vc
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
#else
/// macOS: Stripe Payment Sheet is not used; checkout uses pay-by-link. This stub remains so any stray `.stripe` path fails clearly.
final class StripeService: ObservableObject {
    static let shared = StripeService()
    private init() {}
    static func configure(publishableKey: String) {}
    func presentPaymentSheet(
        amountCents: Int,
        orderId: String,
        customerName: String,
        customerEmail: String?
    ) async throws {
        throw StripeError.backendError(
            "In-app card checkout isn’t available on Mac. Use pay-by-link (place your order and pay when the shop sends the link)."
        )
    }
}
#endif

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
