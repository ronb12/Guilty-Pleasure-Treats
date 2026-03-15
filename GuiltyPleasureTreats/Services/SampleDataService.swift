//
//  SampleDataService.swift
//  Guilty Pleasure Treats
//
//  Seeds Firestore with sample bakery products. Run once (e.g. from Admin or dev menu).
//

import Foundation
import FirebaseFirestore

enum SampleDataService {
    
    static let sampleProducts: [Product] = [
        Product(
            name: "Red Velvet Cupcake",
            productDescription: "Classic red velvet with cream cheese frosting and a hint of cocoa.",
            price: 4.50,
            imageURL: nil,
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: true,
            isSoldOut: false
        ),
        Product(
            name: "Chocolate Lovers Cupcake",
            productDescription: "Rich chocolate cake with chocolate buttercream and sprinkles.",
            price: 4.25,
            imageURL: nil,
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: true,
            isSoldOut: false
        ),
        Product(
            name: "Vanilla Bean Cupcake",
            productDescription: "Light vanilla cake with vanilla bean frosting.",
            price: 3.99,
            imageURL: nil,
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: false,
            isSoldOut: false
        ),
        Product(
            name: "Chocolate Chip Cookie",
            productDescription: "Fresh-baked cookie loaded with milk chocolate chips.",
            price: 2.50,
            imageURL: nil,
            category: ProductCategory.cookies.rawValue,
            isFeatured: true,
            isSoldOut: false
        ),
        Product(
            name: "Oatmeal Raisin Cookie",
            productDescription: "Hearty oatmeal cookie with plump raisins and cinnamon.",
            price: 2.75,
            imageURL: nil,
            category: ProductCategory.cookies.rawValue,
            isFeatured: false,
            isSoldOut: false
        ),
        Product(
            name: "Snickerdoodle",
            productDescription: "Soft cookie rolled in cinnamon sugar.",
            price: 2.50,
            imageURL: nil,
            category: ProductCategory.cookies.rawValue,
            isFeatured: false,
            isSoldOut: false
        ),
        Product(
            name: "Birthday Cake (6 inch)",
            productDescription: "Two-layer vanilla or chocolate cake with buttercream. Serves 6-8.",
            price: 28.00,
            imageURL: nil,
            category: ProductCategory.cakes.rawValue,
            isFeatured: true,
            isSoldOut: false
        ),
        Product(
            name: "Carrot Cake (8 inch)",
            productDescription: "Spiced carrot cake with cream cheese frosting and walnuts.",
            price: 32.00,
            imageURL: nil,
            category: ProductCategory.cakes.rawValue,
            isFeatured: false,
            isSoldOut: false
        ),
        Product(
            name: "Chocolate Fudge Brownie",
            productDescription: "Dense, fudgy brownie with a crackly top.",
            price: 4.00,
            imageURL: nil,
            category: ProductCategory.brownies.rawValue,
            isFeatured: true,
            isSoldOut: false
        ),
        Product(
            name: "Blondie",
            productDescription: "Buttery brown sugar blondie with white chocolate chips.",
            price: 4.00,
            imageURL: nil,
            category: ProductCategory.brownies.rawValue,
            isFeatured: false,
            isSoldOut: false
        ),
        Product(
            name: "Pumpkin Spice Cupcake",
            productDescription: "Seasonal pumpkin cupcake with cream cheese frosting and nutmeg.",
            price: 4.75,
            imageURL: nil,
            category: ProductCategory.seasonalTreats.rawValue,
            isFeatured: true,
            isSoldOut: false
        ),
        Product(
            name: "Peppermint Brownie",
            productDescription: "Chocolate brownie with crushed candy canes. Holiday special.",
            price: 4.50,
            imageURL: nil,
            category: ProductCategory.seasonalTreats.rawValue,
            isFeatured: false,
            isSoldOut: false
        ),
    ]
    
    /// Call once to seed the products collection. Skips if collection already has docs (optional).
    static func seedProductsIfNeeded() async throws {
        let db = Firestore.firestore()
        let snapshot = try await db.collection(AppConstants.Firestore.products).limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }
        
        for product in sampleProducts {
            var p = product
            p.createdAt = Date()
            p.updatedAt = Date()
            _ = try db.collection(AppConstants.Firestore.products).addDocument(from: p)
        }
    }
}
