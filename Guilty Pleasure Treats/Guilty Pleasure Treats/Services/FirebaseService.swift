//
//  FirebaseService.swift
//  Guilty Pleasure Treats
//
//  Firestore and Storage operations for products and orders.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

final class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Products
    
    /// Fetch all products, optionally filtered by category or featured.
    func fetchProducts(category: String? = nil, featuredOnly: Bool = false) async throws -> [Product] {
        var query: Query = db.collection(AppConstants.Firestore.products)
        if let category = category, !category.isEmpty {
            query = query.whereField("category", isEqualTo: category)
        }
        if featuredOnly {
            query = query.whereField("isFeatured", isEqualTo: true)
        }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Product.self)
        }
    }
    
    /// Fetch a single product by ID.
    func fetchProduct(id: String) async throws -> Product? {
        let doc = try await db.collection(AppConstants.Firestore.products).document(id).getDocument()
        return try doc.data(as: Product.self)
    }
    
    /// Add a new product (admin).
    func addProduct(_ product: Product) async throws -> String {
        var mutable = product
        mutable.createdAt = Date()
        mutable.updatedAt = Date()
        let ref = try db.collection(AppConstants.Firestore.products).addDocument(from: mutable)
        return ref.documentID
    }
    
    /// Update product (admin).
    func updateProduct(_ product: Product) async throws {
        guard let id = product.id else { return }
        var mutable = product
        mutable.updatedAt = Date()
        try db.collection(AppConstants.Firestore.products).document(id).setData(from: mutable, merge: true)
    }
    
    /// Upload product image to Firebase Storage and return download URL.
    func uploadProductImage(data: Data, productId: String) async throws -> String {
        let ref = storage.reference().child("products/\(productId).jpg")
        _ = try await ref.putDataAsync(data)
        return try await ref.downloadURL().absoluteString
    }
    
    // MARK: - Custom Cake Orders
    
    /// Save custom cake order to Firestore; returns document ID.
    func saveCustomCakeOrder(_ order: CustomCakeOrder) async throws -> String {
        var mutable = order
        mutable.createdAt = Date()
        let ref = try db.collection(AppConstants.Firestore.customCakeOrders).addDocument(from: mutable)
        return ref.documentID
    }
    
    /// Upload design reference image for a custom cake; returns download URL.
    func uploadCustomCakeDesignImage(data: Data, customCakeOrderId: String) async throws -> String {
        let ref = storage.reference().child("customCakeDesigns/\(customCakeOrderId).jpg")
        _ = try await ref.putDataAsync(data)
        return try await ref.downloadURL().absoluteString
    }
    
    /// Update custom cake order (e.g. set designImageURL or orderId after upload).
    func updateCustomCakeOrder(_ order: CustomCakeOrder) async throws {
        guard let id = order.id else { return }
        try db.collection(AppConstants.Firestore.customCakeOrders).document(id).setData(from: order, merge: true)
    }
    
    // MARK: - AI Cake Designs
    
    /// Save AI cake design to Firestore; returns document ID.
    func saveAICakeDesignOrder(_ order: AICakeDesignOrder) async throws -> String {
        var mutable = order
        mutable.createdAt = Date()
        let ref = try db.collection(AppConstants.Firestore.aiCakeDesigns).addDocument(from: mutable)
        return ref.documentID
    }
    
    /// Upload generated cake image to Storage; returns download URL.
    func uploadAICakeDesignImage(data: Data, designId: String) async throws -> String {
        let ref = storage.reference().child("aiCakeDesigns/\(designId).jpg")
        _ = try await ref.putDataAsync(data)
        return try await ref.downloadURL().absoluteString
    }
    
    /// Update AI cake design (e.g. set generatedImageURL after upload).
    func updateAICakeDesignOrder(_ order: AICakeDesignOrder) async throws {
        guard let id = order.id else { return }
        try db.collection(AppConstants.Firestore.aiCakeDesigns).document(id).setData(from: order, merge: true)
    }
    
    // MARK: - Orders
    
    /// Create a new order.
    func createOrder(_ order: Order) async throws -> String {
        var mutable = order
        mutable.createdAt = Date()
        mutable.updatedAt = Date()
        let ref = try db.collection(AppConstants.Firestore.orders).addDocument(from: mutable)
        return ref.documentID
    }
    
    /// Fetch orders for the current user.
    func fetchOrders(userId: String?) async throws -> [Order] {
        var query: Query = db.collection(AppConstants.Firestore.orders)
            .order(by: "createdAt", descending: true)
        if let userId = userId, !userId.isEmpty {
            query = query.whereField("userId", isEqualTo: userId)
        }
        let snapshot = try await query.limit(to: 50).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Order.self) }
    }
    
    /// Fetch all orders (admin).
    func fetchAllOrders() async throws -> [Order] {
        let snapshot = try await db.collection(AppConstants.Firestore.orders)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Order.self) }
    }
    
    /// Update order status (admin).
    func updateOrderStatus(orderId: String, status: OrderStatus) async throws {
        try await db.collection(AppConstants.Firestore.orders).document(orderId).updateData([
            "status": status.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    /// Update estimated ready time (admin).
    func updateOrderEstimatedReady(orderId: String, date: Date) async throws {
        try await db.collection(AppConstants.Firestore.orders).document(orderId).updateData([
            "estimatedReadyTime": Timestamp(date: date),
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - User Profile (admin flag, loyalty points)
    
    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection(AppConstants.Firestore.users).document(uid).getDocument()
        return try doc.data(as: UserProfile.self)
    }
    
    func setUserProfile(_ profile: UserProfile) async throws {
        try db.collection(AppConstants.Firestore.users).document(profile.uid).setData(from: profile, merge: true)
    }
    
    /// Add loyalty points (e.g. when an order is completed). 1 point per $1 spent.
    func addPoints(uid: String, points: Int) async throws {
        guard points > 0 else { return }
        let ref = db.collection(AppConstants.Firestore.users).document(uid)
        try await db.runTransaction { transaction, _ in
            let doc = try transaction.getDocument(ref)
            let current: Int
            if doc.exists, let profile = try? doc.data(as: UserProfile.self) {
                current = profile.points
            } else {
                current = 0
            }
            let newPoints = current + points
            transaction.setData(["uid": uid, "points": newPoints], forDocument: ref, merge: true)
        }
    }
    
    /// Redeem points (deduct). Returns true if the user had enough points.
    func redeemPoints(uid: String, points: Int) async throws -> Bool {
        guard points > 0 else { return false }
        let ref = db.collection(AppConstants.Firestore.users).document(uid)
        var success = false
        try await db.runTransaction { transaction, _ in
            let doc = try transaction.getDocument(ref)
            let profile: UserProfile
            if doc.exists, let p = try? doc.data(as: UserProfile.self) {
                profile = p
            } else {
                return
            }
            guard profile.points >= points else { return }
            transaction.updateData(["points": profile.points - points], forDocument: ref)
            success = true
        }
        return success
    }
}
