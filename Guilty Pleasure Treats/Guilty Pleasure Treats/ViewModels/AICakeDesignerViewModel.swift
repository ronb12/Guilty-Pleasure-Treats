//
//  AICakeDesignerViewModel.swift
//  Guilty Pleasure Treats
//
//  AI Cake Designer: build prompt from size/flavor/frosting + user description, generate image, confirm and add to cart.
//

import Combine
import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class AICakeDesignerViewModel: ObservableObject {
    @Published var selectedSize: CakeSize = .six
    @Published var selectedFlavor: CakeFlavor = .chocolate
    @Published var selectedFrosting: AIDesignFrosting = .buttercream
    @Published var designPrompt: String = ""
    @Published var generatedImageData: Data?
    @Published var isGenerating = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var addedToCart = false
    
    private let imageService = ImageGenerationService.shared
    private let api = VercelService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared
    
    var totalPrice: Double { selectedSize.price }
    var hasGeneratedImage: Bool { generatedImageData != nil }
    
    /// Build full prompt for the AI: cake specs + user description.
    private var fullPrompt: String {
        let specs = "\(selectedSize.rawValue) \(selectedFlavor.rawValue.lowercased()) cake with \(selectedFrosting.rawValue.lowercased()) frosting"
        let trimmed = designPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Professional photo of a \(specs), elegant bakery style, soft lighting, high quality"
        }
        return "Professional photo of a \(specs), \(trimmed), elegant bakery style, soft lighting, high quality"
    }
    
    /// Call AI image API and show preview.
    func generateDesign() async {
        let prompt = fullPrompt
        guard !prompt.isEmpty else {
            errorMessage = "Describe your cake design."
            return
        }
        isGenerating = true
        errorMessage = nil
        generatedImageData = nil
        defer { isGenerating = false }
        do {
            let data = try await imageService.generateImage(prompt: prompt)
            if PlatformImage(data: data) != nil {
                generatedImageData = data
            } else {
                errorMessage = "The image could not be displayed. Try again or use a different description."
            }
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    /// Save design to Firestore, upload image to Storage, add to cart.
    func confirmAndAddToCart() async {
        guard let imageData = generatedImageData else {
            errorMessage = "Generate a design first."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        var order = AICakeDesignOrder(
            id: nil,
            userId: auth.currentUser?.uid,
            size: selectedSize.rawValue,
            flavor: selectedFlavor.rawValue,
            frosting: selectedFrosting.rawValue,
            designPrompt: designPrompt.trimmingCharacters(in: .whitespaces),
            generatedImageURL: nil,
            price: totalPrice,
            orderId: nil,
            createdAt: nil
        )
        do {
            let docId = try await api.saveAICakeDesignOrder(order)
            order.id = docId
            let imageURL = try await api.uploadAICakeDesignImage(data: imageData, designId: docId)
            order.generatedImageURL = imageURL
            try await api.updateAICakeDesignOrder(order)
            cart.addAICakeDesign(order)
            addedToCart = true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func clearDesign() {
        generatedImageData = nil
        errorMessage = nil
    }
}
