//
//  FriendlyErrorMessage.swift
//  Guilty Pleasure Treats
//
//  Maps API/network errors to short, user-friendly messages.
//

import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

enum FriendlyErrorMessage {
    /// Human-readable copy for Sign in with Apple **before** the server runs. Code **1000** = `ASAuthorizationError.failed` (not a wrong password—usually capability / provisioning / Simulator).
    static func appleSignInMessage(for error: Error) -> String? {
        #if canImport(AuthenticationServices)
        let ns = error as NSError
        // Same as `ASAuthorizationError.errorDomain` (string avoids SDK edge cases).
        if ns.domain == "com.apple.AuthenticationServices.AuthorizationError" {
            switch ns.code {
            case ASAuthorizationError.canceled.rawValue:
                return nil
            case ASAuthorizationError.failed.rawValue:
                return "Sign in with Apple couldn’t start (error 1000). This is usually an app setup issue, not your Apple ID password. Fix: Apple Developer → Identifiers → your App ID → enable Sign In with Apple; Xcode → target → Signing & Capabilities → add Sign In with Apple; clean build. On Simulator, sign in to an Apple ID under Settings → Apple ID, or try a real iPhone."
            case ASAuthorizationError.invalidResponse.rawValue:
                return "Sign in with Apple returned an invalid response. Please try again."
            case ASAuthorizationError.notHandled.rawValue:
                return "Sign in with Apple couldn’t be handled. Please try again."
            case ASAuthorizationError.unknown.rawValue:
                return "Sign in with Apple failed for an unknown reason. Please try again."
            default:
                break
            }
        }
        #endif
        return message(for: error)
    }

    /// Returns a short message suitable for ErrorMessageBanner. Uses Firebase-style messages for auth errors.
    static func message(for error: Error) -> String {
        if let authErr = error as? AuthError, let desc = authErr.errorDescription, !desc.isEmpty {
            return desc
        }
        // Stripe in-app payment (Payment Sheet, PaymentIntent)
        if let stripe = error as? StripeError {
            switch stripe {
            case .invalidURL:
                return "Payment couldn’t start. Please try again."
            case .paymentCanceled:
                return "Payment was canceled. If an order was started, contact the shop to pay—or try again."
            case .backendError(let msg):
                let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return "Payment couldn’t start. Please try again." }
                if trimmed.count < 220 { return trimmed }
                return String(trimmed.prefix(217)) + "…"
            }
        }
        if let api = error as? VercelAPIError, !api.message.isEmpty {
            var msg = api.message
            if let rid = api.requestId, !rid.isEmpty {
                msg += " (ref: \(rid.prefix(12)))"
            }
            if msg.contains("try again") || msg.contains("Please try again") {
                return msg
            }
            if msg.contains("not set up") || msg.contains("Run scripts") || msg.contains("schema") {
                return msg
            }
            if msg.contains("network") || msg.contains("connection") || msg.contains("Internet") {
                return "Connection problem. Please check your internet and try again."
            }
            if msg.contains("401") || msg.contains("Unauthorized") {
                return "Please sign in again."
            }
            if msg.contains("404") || msg.contains("not found") {
                return "Something went wrong. Please try again."
            }
            if msg.contains("500") || msg.contains("server") || msg.contains("FUNCTION_INVOCATION") {
                return "Something went wrong. Please try again."
            }
            return msg
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "No internet connection. Check your network and try again."
            case NSURLErrorTimedOut:
                return "Request took too long. Please try again."
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return "Connection problem. Please try again."
            default:
                break
            }
        }
        return "Something went wrong. Please try again."
    }
}
