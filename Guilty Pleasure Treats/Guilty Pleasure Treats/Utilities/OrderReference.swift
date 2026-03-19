//
//  OrderReference.swift
//  Guilty Pleasure Treats
//
//  Human-facing order numbers always start with "GPT-" (brand prefix + 8 hex chars from the stored order UUID).
//  The full UUID remains the canonical id for APIs and database.
//

import Foundation

enum OrderReference {
    /// Display code shown in UI, emails, and notifications, e.g. `GPT-A1B2C3D4`.
    static func displayCode(from orderId: String) -> String {
        let trimmed = orderId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "GPT" }
        let compact = trimmed.replacingOccurrences(of: "-", with: "")
        if compact.count >= 8 {
            return "GPT-\(String(compact.prefix(8)).uppercased())"
        }
        let suffix = String(trimmed.prefix(12)).replacingOccurrences(of: "-", with: "")
        return suffix.isEmpty ? "GPT-\(trimmed)" : "GPT-\(suffix.uppercased())"
    }
}
