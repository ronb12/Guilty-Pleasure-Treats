//
//  CheckoutDebugLog.swift
//  Guilty Pleasure Treats
//
//  Console + optional in-app trace for Place Order → Stripe troubleshooting.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum CheckoutDebugLog {
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Logs to Xcode console (filter: `CheckoutDebug`).
    static func console(_ message: String) {
        let ts = iso8601.string(from: Date())
        print("[CheckoutDebug] \(ts) \(message)")
    }

    /// Safe preview of a Stripe client secret (never log full secret).
    static func describeClientSecret(_ secret: String) -> String {
        let t = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "(empty)" }
        if t.count <= 24 { return "\(t.prefix(8))…(len:\(t.count))" }
        return "\(t.prefix(12))…\(t.suffix(8)) (len:\(t.count))"
    }

    /// Copy full trace from the in-app debug panel.
    static func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
