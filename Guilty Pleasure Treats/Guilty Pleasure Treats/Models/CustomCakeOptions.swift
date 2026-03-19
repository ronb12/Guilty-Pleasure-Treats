//
//  CustomCakeOptions.swift
//  Guilty Pleasure Treats
//
//  Admin-managed options for Custom Cake Builder (sizes, flavors, frostings). Fetched from API.
//

import Foundation

struct CakeSizeOption: Identifiable, Codable, Equatable {
    var optionId: String?
    var label: String
    var price: Double
    var sortOrder: Int?
    /// Stable id for list identity; new items use a unique placeholder until saved.
    var id: String { optionId ?? "size-\(label)-\(sortOrder ?? 0)" }
    enum CodingKeys: String, CodingKey { case optionId = "id", label, price, sortOrder = "sortOrder" }
}

struct CakeFlavorOption: Identifiable, Codable, Equatable {
    var optionId: String?
    var label: String
    var sortOrder: Int?
    var id: String { optionId ?? "flavor-\(label)-\(sortOrder ?? 0)" }
    enum CodingKeys: String, CodingKey { case optionId = "id", label, sortOrder = "sortOrder" }
}

struct FrostingOption: Identifiable, Codable, Equatable {
    var optionId: String?
    var label: String
    var sortOrder: Int?
    var id: String { optionId ?? "frosting-\(label)-\(sortOrder ?? 0)" }
    enum CodingKeys: String, CodingKey { case optionId = "id", label, sortOrder = "sortOrder" }
}

struct ToppingOption: Identifiable, Codable, Equatable {
    var optionId: String?
    var label: String
    var price: Double
    var sortOrder: Int?
    var id: String { optionId ?? "topping-\(label)-\(sortOrder ?? 0)" }
    enum CodingKeys: String, CodingKey { case optionId = "id", label, price, sortOrder = "sortOrder" }
}

struct CustomCakeOptionsResponse: Codable, Equatable {
    var sizes: [CakeSizeOption]
    var flavors: [CakeFlavorOption]
    var frostings: [FrostingOption]
    var toppings: [ToppingOption]?
}
