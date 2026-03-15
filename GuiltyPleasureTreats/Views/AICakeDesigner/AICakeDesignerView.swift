//
//  AICakeDesignerView.swift
//  Guilty Pleasure Treats
//
//  AI Cake Designer: size, flavor, frosting, design description, generate preview, confirm and add to order.
//

import SwiftUI

struct AICakeDesignerView: View {
    @StateObject private var viewModel = AICakeDesignerViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) {
                        viewModel.errorMessage = nil
                    }
                }
                
                sectionHeader("Cake size")
                sizeSection
                
                sectionHeader("Flavor")
                flavorSection
                
                sectionHeader("Frosting")
                frostingSection
                
                sectionHeader("Describe your design")
                designPromptSection
                
                generateButton
                
                if viewModel.hasGeneratedImage {
                    previewSection
                    confirmSection
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("AI Cake Designer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Added to Cart", isPresented: $viewModel.addedToCart) {
            Button("OK", role: .cancel) { viewModel.addedToCart = false }
        } message: {
            Text("Your AI-designed cake has been added to the cart.")
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }
    
    private var sizeSection: some View {
        scrollableChips(CakeSize.allCases.map(\.rawValue)) { raw in
            if let size = CakeSize(rawValue: raw) {
                viewModel.selectedSize = size
            }
        } selectedRaw: { viewModel.selectedSize.rawValue }
    }
    
    private var flavorSection: some View {
        scrollableChips(CakeFlavor.allCases.map(\.rawValue)) { raw in
            if let flavor = CakeFlavor(rawValue: raw) {
                viewModel.selectedFlavor = flavor
            }
        } selectedRaw: { viewModel.selectedFlavor.rawValue }
    }
    
    private var frostingSection: some View {
        scrollableChips(AIDesignFrosting.allCases.map(\.rawValue)) { raw in
            if let frosting = AIDesignFrosting(rawValue: raw) {
                viewModel.selectedFrosting = frosting
            }
        } selectedRaw: { viewModel.selectedFrosting.rawValue }
    }
    
    private func scrollableChips(
        _ options: [String],
        action: @escaping (String) -> Void,
        selectedRaw: () -> String
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    chipButton(
                        title: option,
                        isSelected: selectedRaw() == option
                    ) { action(option) }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : AppConstants.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? AppConstants.Colors.accent : AppConstants.Colors.cardBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private var designPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example: “Pink birthday cake with gold sprinkles” or “Elegant white wedding cake with roses”")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField("Describe your cake design...", text: $viewModel.designPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var generateButton: some View {
        PrimaryButton(
            title: "Generate Cake Design",
            action: { Task { await viewModel.generateDesign() } },
            isLoading: viewModel.isGenerating
        )
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your design")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if let data = viewModel.generatedImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                            .stroke(AppConstants.Colors.accent.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            Button("Generate again") {
                viewModel.clearDesign()
            }
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.accent)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var confirmSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Price")
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
                Text(viewModel.totalPrice.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            
            PrimaryButton(
                title: "Confirm & Add to Order",
                action: { Task { await viewModel.confirmAndAddToCart() } },
                isLoading: viewModel.isSaving
            )
        }
    }
}
