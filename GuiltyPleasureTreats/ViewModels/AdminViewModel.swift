//
//  AdminViewModel.swift
//  Guilty Pleasure Treats
//
//  Admin: add/edit products, mark sold out, view orders.
//

import Foundation
import UIKit
import Combine

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Edit product form
    @Published var editingProduct: Product?
    @Published var newProductImage: UIImage?
    
    private let firebase = FirebaseService.shared
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await firebase.fetchProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func loadOrders() async {
        do {
            orders = try await firebase.fetchAllOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func addProduct(name: String, description: String, price: Double, category: String, isFeatured: Bool, image: UIImage?) async {
        var product = Product(
            name: name,
            productDescription: description,
            price: price,
            imageURL: nil,
            category: category,
            isFeatured: isFeatured,
            isSoldOut: false
        )
        do {
            let id = try await firebase.addProduct(product)
            if let image = image, let jpeg = image.jpegData(compressionQuality: 0.7) {
                let url = try await firebase.uploadProductImage(data: jpeg, productId: id)
                var updated = product
                updated.id = id
                updated.imageURL = url
                try await firebase.updateProduct(updated)
            }
            successMessage = "Product added."
            await loadProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateProduct(_ product: Product, newImage: UIImage?) async {
        do {
            if let img = newImage, let id = product.id, let jpeg = img.jpegData(compressionQuality: 0.7) {
                let url = try await firebase.uploadProductImage(data: jpeg, productId: id)
                var updated = product
                updated.imageURL = url
                updated.updatedAt = Date()
                try await firebase.updateProduct(updated)
            } else {
                try await firebase.updateProduct(product)
            }
            successMessage = "Product updated."
            await loadProducts()
            editingProduct = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func setSoldOut(product: Product, soldOut: Bool) async {
        var updated = product
        updated.isSoldOut = soldOut
        do {
            try await firebase.updateProduct(updated)
            successMessage = soldOut ? "Marked sold out." : "Marked available."
            await loadProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateOrderStatus(order: Order, status: OrderStatus) async {
        guard let orderId = order.id else { return }
        do {
            try await firebase.updateOrderStatus(orderId: orderId, status: status)
            if status == .completed, let uid = order.userId, !uid.isEmpty {
                let pointsToAdd = Int(order.total)
                if pointsToAdd > 0 {
                    try? await firebase.addPoints(uid: uid, points: pointsToAdd)
                }
            }
            successMessage = "Order updated."
            await loadOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
