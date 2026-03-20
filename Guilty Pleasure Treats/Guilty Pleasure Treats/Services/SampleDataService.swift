//
//  SampleDataService.swift
//  Guilty Pleasure Treats
//
//  Legacy stub: sample products/orders were removed for production. Lists are empty when the API has no data.
//

import Foundation

enum SampleDataService {
    /// Empty — menu and admin load only real data from the API / Neon.
    static let sampleProducts: [Product] = []

    /// Empty — order history shows only real orders from the API.
    static let sampleOrders: [Order] = []

    /// Reserved for optional one-time seeding; products are managed via Admin or SQL.
    static func seedProductsIfNeeded() async throws {}
}
