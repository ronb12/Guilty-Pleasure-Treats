//
//  SavedCustomer.swift
//  Guilty Pleasure Treats
//
//  Customer record the owner can add/edit/delete (contact list).
//

import Foundation

struct SavedCustomer: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var phone: String
    var email: String?
    var address: String?
    var street: String?
    var addressLine2: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var notes: String?
    /// Kitchen-facing note for saved contact (same intent as account food allergies).
    var foodAllergies: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case email
        case address
        case street
        case addressLine2
        case city
        case state
        case postalCode
        case notes
        case foodAllergies
        case createdAt
        case updatedAt
    }

    /// Single-line display (e.g. for list rows). Prefers structured fields, then address.
    var addressDisplay: String? {
        if let s = street, let c = city, let st = state, let z = postalCode {
            let parts = [s, addressLine2, "\(c), \(st) \(z)"].compactMap { $0?.isEmpty == false ? $0 : nil }
            return parts.joined(separator: ", ")
        }
        return address?.replacingOccurrences(of: "\n", with: ", ")
    }
}
