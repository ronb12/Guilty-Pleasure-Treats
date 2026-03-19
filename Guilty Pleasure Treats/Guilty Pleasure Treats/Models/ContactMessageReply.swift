//
//  ContactMessageReply.swift
//  Guilty Pleasure Treats
//
//  Admin reply to a contact message; customer sees these in app.
//

import Foundation

struct ContactMessageReply: Identifiable, Codable {
    var id: String
    var contactMessageId: String
    var body: String
    var createdAt: Date?
    var subject: String?

    enum CodingKeys: String, CodingKey {
        case id, body, subject
        case contactMessageId = "contactMessageId"
        case createdAt = "createdAt"
    }
}
