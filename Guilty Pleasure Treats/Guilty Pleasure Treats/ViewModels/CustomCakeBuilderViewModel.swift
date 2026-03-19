//
//  CustomCakeBuilderViewModel.swift
//  Guilty Pleasure Treats
//
//  State and actions for the custom cake builder: selections, price, save to Firestore, add to cart.
//  Loads sizes, flavors, frostings from API; falls back to app enums when API is unavailable.
//

import Combine
import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class CustomCakeBuilderViewModel: ObservableObject {
    @Published var sizes: [CakeSizeOption] = []
    @Published var flavors: [CakeFlavorOption] = []
    @Published var frostings: [FrostingOption] = []
    @Published var toppings: [ToppingOption] = []
    @Published var selectedSize: CakeSizeOption?
    @Published var selectedFlavor: CakeFlavorOption?
    @Published var selectedFrosting: FrostingOption?
    @Published var selectedToppingIds: Set<String> = []
    @Published var message: String = ""
    @Published var designImage: PlatformImage?
    @Published var isLoading = false
    @Published var optionsLoading = false
    @Published var errorMessage: String?
    @Published var addedToCart = false
    
    private let api = VercelService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared
    
    var totalPrice: Double {
        let base = selectedSize?.price ?? 0
        let toppingTotal = selectedToppingIds.compactMap { id in toppings.first(where: { $0.id == id })?.price }.reduce(0, +)
        return base + toppingTotal
    }

    var selectedToppings: [ToppingOption] {
        toppings.filter { selectedToppingIds.contains($0.id) }
    }
    
    /// Load options from API; on failure or empty, use enum defaults so builder always works.
    func loadOptions() async {
        optionsLoading = true
        defer { optionsLoading = false }
        do {
            let res = try await api.fetchCustomCakeOptions()
            if !res.sizes.isEmpty, !res.flavors.isEmpty, !res.frostings.isEmpty {
                sizes = res.sizes
                flavors = res.flavors
                frostings = res.frostings
                toppings = res.toppings ?? []
                if selectedSize == nil || !sizes.contains(where: { $0.id == selectedSize?.id }) { selectedSize = sizes.first }
                if selectedFlavor == nil || !flavors.contains(where: { $0.id == selectedFlavor?.id }) { selectedFlavor = flavors.first }
                if selectedFrosting == nil || !frostings.contains(where: { $0.id == selectedFrosting?.id }) { selectedFrosting = frostings.first }
                return
            }
        } catch { }
        useEnumFallback()
    }
    
    private func useEnumFallback() {
        sizes = CakeSize.allCases.enumerated().map { i, s in
            CakeSizeOption(optionId: nil, label: s.rawValue, price: s.price, sortOrder: i)
        }
        flavors = CakeFlavor.allCases.enumerated().map { i, f in
            CakeFlavorOption(optionId: nil, label: f.rawValue, sortOrder: i)
        }
        frostings = FrostingType.allCases.enumerated().map { i, f in
            FrostingOption(optionId: nil, label: f.rawValue, sortOrder: i)
        }
        toppings = CakeTopping.allCases.enumerated().map { i, t in
            ToppingOption(optionId: nil, label: t.rawValue, price: t.price, sortOrder: i)
        }
        if selectedSize == nil { selectedSize = sizes.first }
        if selectedFlavor == nil { selectedFlavor = flavors.first }
        if selectedFrosting == nil { selectedFrosting = frostings.first }
    }
    
    /// Save custom cake (and upload design image), then add to cart.
    func addToCart() async {
        guard let size = selectedSize, let flavor = selectedFlavor, let frosting = selectedFrosting else {
            errorMessage = "Please select size, flavor, and frosting."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let toppingLabels = selectedToppings.map(\.label)
        var order = CustomCakeOrder(
            id: nil,
            userId: auth.currentUser?.uid,
            size: size.label,
            flavor: flavor.label,
            frosting: frosting.label,
            toppings: toppingLabels.isEmpty ? nil : toppingLabels,
            message: message.trimmingCharacters(in: .whitespaces),
            designImageURL: nil,
            price: totalPrice,
            orderId: nil,
            createdAt: nil
        )
        
        do {
            let docId = try await api.saveCustomCakeOrder(order)
            order.id = docId
            
            if let image = designImage, let jpeg = image.jpegData(compressionQuality: 0.8) {
                let url = try await api.uploadCustomCakeDesignImage(data: jpeg, customCakeOrderId: docId)
                order.designImageURL = url
                try await api.updateCustomCakeOrder(order)
            }
            
            cart.addCustomCake(order)
            addedToCart = true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
