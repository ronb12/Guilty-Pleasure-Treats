//
//  FriendlyErrorMessage.swift
//  Guilty Pleasure Treats
//
//  Maps API/network errors to short, user-friendly messages.
//

import Foundation

enum FriendlyErrorMessage {
    /// Returns a short message suitable for ErrorMessageBanner. Uses Firebase-style messages for auth errors.
    static func message(for error: Error) -> String {
        if let authErr = error as? AuthError, let desc = authErr.errorDescription, !desc.isEmpty {
            return desc
        }
        if let api = error as? VercelAPIError, !api.message.isEmpty {
            let msg = api.message
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
