//
//  AICakeDesignOrder.swift
//  Guilty Pleasure Treats
//
//  AI-generated cake design; saved to Firestore and added to cart.
//

import Foundation
import FirebaseFirestore

/// Frosting options for AI Cake Designer (matches user-facing labels).
enum AIDesignFrosting: String, Codable, CaseIterable, Identifiable {
    case buttercream = "Buttercream"
    case creamCheese = "Cream Cheese"
    case chocolate = "Chocolate"
    var id: String { rawValue }
}

struct AICakeDesignOrder: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String?
    var size: String
    var flavor: String
    var frosting: String
    var designPrompt: String
    var generatedImageURL: String?
    var price: Double
    var orderId: String?
    var createdAt: Date?
    
    var sizeEnum: CakeSize? { CakeSize(rawValue: size) }
    var flavorEnum: CakeFlavor? { CakeFlavor(rawValue: flavor) }
    var frostingEnum: AIDesignFrosting? { AIDesignFrosting(rawValue: frosting) }
    
    var summary: String {
        [size, flavor, frosting]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
