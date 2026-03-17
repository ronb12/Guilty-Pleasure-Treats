//
//  CustomCakeBuilderView.swift
//  Guilty Pleasure Treats
//
//  Build a custom cake: size, flavor, frosting, message, design photo; dynamic price; save to Firestore and add to cart.
//

import SwiftUI

struct CustomCakeBuilderView: View {
    @StateObject private var viewModel = CustomCakeBuilderViewModel()
    @State private var showImagePicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) {
                        viewModel.errorMessage = nil
                    }
                }
                
                sectionHeader("Cake Size")
                sizePicker
                
                sectionHeader("Cake Flavor")
                flavorPicker
                
                sectionHeader("Frosting")
                frostingPicker
                
                sectionHeader("Cake Message (optional)")
                messageField
                
                sectionHeader("Design Reference (optional)")
                designPhotoSection
                
                priceAndAddSection
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Custom Cake")
        .inlineNavigationTitle()
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $viewModel.designImage)
        }
        .alert("Added to Cart", isPresented: $viewModel.addedToCart) {
            Button("OK", role: .cancel) { viewModel.addedToCart = false }
        } message: {
            Text("Your custom cake has been added to the cart.")
        }
        .task { await viewModel.loadOptions() }
        .refreshable { await viewModel.loadOptions() }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }
    
    private var sizePicker: some View {
        Group {
            if viewModel.optionsLoading && viewModel.sizes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.sizes) { size in
                        builderOptionRow(
                            title: size.label,
                            subtitle: size.price.currencyFormatted,
                            isSelected: viewModel.selectedSize?.id == size.id
                        ) {
                            viewModel.selectedSize = size
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var flavorPicker: some View {
        Group {
            if viewModel.optionsLoading && viewModel.flavors.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.flavors) { flavor in
                        builderOptionRow(
                            title: flavor.label,
                            subtitle: nil,
                            isSelected: viewModel.selectedFlavor?.id == flavor.id
                        ) {
                            viewModel.selectedFlavor = flavor
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var frostingPicker: some View {
        Group {
            if viewModel.optionsLoading && viewModel.frostings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.frostings) { frosting in
                        builderOptionRow(
                            title: frosting.label,
                            subtitle: nil,
                            isSelected: viewModel.selectedFrosting?.id == frosting.id
                        ) {
                            viewModel.selectedFrosting = frosting
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private func builderOptionRow(title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? AppConstants.Colors.accent : AppConstants.Colors.textSecondary.opacity(0.6))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var messageField: some View {
        TextField("e.g. Happy Birthday!", text: $viewModel.message, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var designPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload a photo for design reference (e.g. colors, decorations)")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Button {
                showImagePicker = true
            } label: {
                Group {
                    if let image = viewModel.designImage {
                        Image(platformImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(AppConstants.Colors.accent)
                            Text("Add photo")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                    }
                }
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            }
            .buttonStyle(.plain)
            if viewModel.designImage != nil {
                Button("Remove photo") {
                    viewModel.designImage = nil
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
    
    private var priceAndAddSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Total")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
                Text(viewModel.totalPrice.currencyFormatted)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            
            PrimaryButton(
                title: "Add to Cart",
                action: { Task { await viewModel.addToCart() } },
                isLoading: viewModel.isLoading
            )
        }
    }
}
