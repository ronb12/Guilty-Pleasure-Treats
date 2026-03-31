//
//  Event.swift
//  Guilty Pleasure Treats
//
//  Bakery event (tastings, pop-ups, etc.) from API.
//

import Foundation

struct Event: Identifiable, Codable, Hashable {
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

    init(
        id: String,
        title: String,
        eventDescription: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        imageURL: String? = nil,
        location: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.eventDescription = eventDescription
        self.startAt = startAt
        self.endAt = endAt
        self.imageURL = imageURL
        self.location = location
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else if let i = try? c.decode(Int64.self, forKey: .id) {
            id = String(i)
        } else {
            id = ""
        }
        title = try c.decode(String.self, forKey: .title)
        eventDescription = try c.decodeIfPresent(String.self, forKey: .eventDescription)
        startAt = try c.decodeIfPresent(Date.self, forKey: .startAt)
        endAt = try c.decodeIfPresent(Date.self, forKey: .endAt)
        if let raw = try c.decodeIfPresent(String.self, forKey: .imageURL) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            imageURL = t.isEmpty ? nil : t
        } else {
            imageURL = nil
        }
        location = try c.decodeIfPresent(String.self, forKey: .location)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(eventDescription, forKey: .eventDescription)
        try c.encodeIfPresent(startAt, forKey: .startAt)
        try c.encodeIfPresent(endAt, forKey: .endAt)
        let trimmedImage = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        try c.encodeIfPresent(
            (trimmedImage?.isEmpty == false) ? trimmedImage : nil,
            forKey: .imageURL
        )
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

extension Event {
    /// Public image URL for `AsyncImage`, after trimming. Handles occasional newline-padded values from APIs/DB.
    var resolvedImageURL: URL? {
        guard let raw = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let u = URL(string: raw), u.scheme != nil { return u }
        return nil
    }
}
