//
//  Event.swift
//  Guilty Pleasure Treats
//
//  Bakery event (tastings, pop-ups, etc.) from API.
//

import Foundation

struct Event: Identifiable, Codable {
    var id: String
    var title: String
    var eventDescription: String?
    var startAt: Date?
    var endAt: Date?
    var imageURL: String?
    var location: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case eventDescription = "description"
        case startAt = "start_at"
        case endAt = "end_at"
        case imageURL = "image_url"
        case location
        case createdAt = "created_at"
    }
}
