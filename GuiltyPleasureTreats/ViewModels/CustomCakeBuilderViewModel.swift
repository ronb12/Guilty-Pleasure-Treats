//
//  CustomCakeBuilderViewModel.swift
//  Guilty Pleasure Treats
//
//  State and actions for the custom cake builder: selections, price, save to Firestore, add to cart.
//

import Foundation
import UIKit

@MainActor
final class CustomCakeBuilderViewModel: ObservableObject {
    @Published var selectedSize: CakeSize = .six
    @Published var selectedFlavor: CakeFlavor = .chocolate
    @Published var selectedFrosting: FrostingType = .vanillaButtercream
    @Published var message: String = ""
    @Published var designImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addedToCart = false
    
    private let firebase = FirebaseService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared
    
    var totalPrice: Double { selectedSize.price }
    
    /// Save custom cake to Firestore (and upload design image), then add to cart.
    func addToCart() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var order = CustomCakeOrder(
            id: nil,
            userId: auth.currentUser?.uid,
            size: selectedSize.rawValue,
            flavor: selectedFlavor.rawValue,
            frosting: selectedFrosting.rawValue,
            message: message.trimmingCharacters(in: .whitespaces),
            designImageURL: nil,
            price: totalPrice,
            orderId: nil,
            createdAt: nil
        )
        
        do {
            let docId = try await firebase.saveCustomCakeOrder(order)
            order.id = docId
            
            if let image = designImage, let jpeg = image.jpegData(compressionQuality: 0.8) {
                let url = try await firebase.uploadCustomCakeDesignImage(data: jpeg, customCakeOrderId: docId)
                order.designImageURL = url
                try await firebase.updateCustomCakeOrder(order)
            }
            
            cart.addCustomCake(order)
            addedToCart = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
