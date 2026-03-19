//
//  PhoneNormalization.swift
//  Guilty Pleasure Treats
//
//  Normalize phone strings for equality checks (admin matching, etc.) without DB schema changes.
//

import Foundation

/// Strips formatting so different user-entered formats still match (e.g. "(555) 123-4567" vs "5551234567").
/// Keeps a single leading `+` when present, then digits only.
func normalizePhoneForMatch(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    var rest = trimmed[...]
    var prefix = ""
    if rest.first == "+" {
        prefix = "+"
        rest = rest.dropFirst()
    }
    let digits = rest.filter(\.isNumber)
    return prefix + String(digits)
}
