//
//  AdminView.swift
//  Guilty Pleasure Treats
//
//  Hidden admin: products, orders, customers, special orders, promos, analytics, settings. Access via 5-tap on logo. Requires sign-in + isAdmin.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// On macOS returns short label so tab bar doesn’t truncate; on iOS returns full.
private func adminTabTitle(_ full: String, short: String) -> String {
    #if os(macOS)
    return short
    #else
    return full
    #endif
}

#if os(macOS)
/// Labels for the scrollable admin tab strip (order must match `TabView` tags 0…13 on iOS).
private let macOSAdminTabBarItems: [(title: String, icon: String)] = [
    ("Products", "list.bullet"),
    ("Cats", "folder.fill"),
    ("Orders", "doc.text"),
    ("Cust", "person.2"),
    ("Promos", "tag"),
    ("Cake", "birthday.cake"),
    ("Stats", "chart.bar"),
    ("Reviews", "star.fill"),
    ("Events", "calendar"),
    ("Margin", "percent"),
    ("Msgs", "envelope.badge"),
    ("Settings", "gearshape"),
    ("Gallery", "photo.on.rectangle.angled"),
    ("Stock", "shippingbox.fill"),
]
#endif

struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @StateObject private var viewModel = AdminViewModel()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if auth.currentUser == nil || !auth.isAdmin {
                AdminAccessDeniedView()
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Admin")
                            .font(.headline)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Spacer()
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                        .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppConstants.Colors.cardBackground)

                    #if os(macOS)
                    Divider()
                        .background(AppConstants.Colors.textSecondary.opacity(0.3))
                    #endif

                    if !viewModel.lowStockProducts.isEmpty {
                        Button {
                            selectedTab = 11
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.white)
                                Text("\(viewModel.lowStockProducts.count) item\(viewModel.lowStockProducts.count == 1 ? "" : "s") low in stock — tap to view")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                        }
                        .buttonStyle(.plain)
                    }

                    #if os(iOS)
                    TabView(selection: $selectedTab) {
                        adminTabPage(tag: 0)
                            .tabItem { Label(adminTabTitle("Products", short: "Products"), systemImage: "list.bullet") }
                            .tag(0)
                        adminTabPage(tag: 1)
                            .tabItem { Label(adminTabTitle("Categories", short: "Cats"), systemImage: "folder.fill") }
                            .tag(1)
                        adminTabPage(tag: 2)
                            .tabItem { Label(adminTabTitle("Orders", short: "Orders"), systemImage: "doc.text") }
                            .tag(2)
                        adminTabPage(tag: 3)
                            .tabItem { Label(adminTabTitle("Customers", short: "Cust"), systemImage: "person.2") }
                            .tag(3)
                        adminTabPage(tag: 4)
                            .tabItem { Label(adminTabTitle("Promos", short: "Promos"), systemImage: "tag") }
                            .tag(4)
                        adminTabPage(tag: 5)
                            .tabItem { Label(adminTabTitle("Cake Options", short: "Cake"), systemImage: "birthday.cake") }
                            .tag(5)
                        adminTabPage(tag: 6)
                            .tabItem { Label(adminTabTitle("Analytics", short: "Stats"), systemImage: "chart.bar") }
                            .tag(6)
                        adminTabPage(tag: 7)
                            .tabItem { Label(adminTabTitle("Reviews", short: "Reviews"), systemImage: "star.fill") }
                            .tag(7)
                        adminTabPage(tag: 8)
                            .tabItem { Label(adminTabTitle("Events", short: "Events"), systemImage: "calendar") }
                            .tag(8)
                        adminTabPage(tag: 9)
                            .tabItem { Label(adminTabTitle("Margins", short: "Margin"), systemImage: "percent") }
                            .tag(9)
                        adminTabPage(tag: 10)
                            .tabItem { Label(adminTabTitle("Messages", short: "Msgs"), systemImage: "envelope.badge") }
                            .tag(10)
                        adminTabPage(tag: 11)
                            .tabItem { Label(adminTabTitle("Settings", short: "Settings"), systemImage: "gearshape") }
                            .tag(11)
                        adminTabPage(tag: 12)
                            .tabItem { Label(adminTabTitle("Gallery", short: "Gallery"), systemImage: "photo.on.rectangle.angled") }
                            .tag(12)
                        adminTabPage(tag: 13)
                            .tabItem { Label(adminTabTitle("Inventory", short: "Stock"), systemImage: "shippingbox.fill") }
                            .tag(13)
                    }
                    #else
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 8) {
                            ForEach(Array(macOSAdminTabBarItems.enumerated()), id: \.offset) { index, item in
                                Button {
                                    selectedTab = index
                                } label: {
                                    Label(item.title, systemImage: item.icon)
                                        .labelStyle(.titleAndIcon)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(selectedTab == index ? AppConstants.Colors.accent : .secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppConstants.Colors.cardBackground)
                    Divider()
                        .background(AppConstants.Colors.textSecondary.opacity(0.3))
                    adminTabPage(tag: selectedTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .macOSConstrainedContent()
                    #endif
                }
                #if os(macOS)
                .macOSSheetTopPadding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppConstants.Colors.secondary)
                #endif
                .onAppear { applyPendingPushAction() }
                .onChange(of: notificationService.pendingPushAction) { _, _ in applyPendingPushAction() }
                .onAppear {
                    Task {
                        await viewModel.loadProducts()
                        await viewModel.loadProductCategories()
                        await viewModel.loadSavedCustomers()
                        await viewModel.loadOrders()
                        await viewModel.loadBusinessSettings()
                        await viewModel.loadPromotions()
                        await viewModel.loadSpecialOrders()
                        await viewModel.loadCustomCakeOptions()
                        await viewModel.loadContactMessages()
                        await viewModel.loadReviews()
                        await viewModel.loadEvents()
                        await viewModel.loadCakeGallery()
                        await NotificationService.shared.registerPushTokenWithBackend()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func adminTabPage(tag: Int) -> some View {
        switch tag {
        case 0: AdminProductsView(viewModel: viewModel)
        case 1: AdminCategoriesView(viewModel: viewModel)
        case 2: AdminOrdersView(viewModel: viewModel)
        case 3: AdminCustomersView(viewModel: viewModel)
        case 4: AdminPromotionsView(viewModel: viewModel)
        case 5: AdminCustomCakeOptionsView(viewModel: viewModel)
        case 6: AdminAnalyticsView(viewModel: viewModel)
        case 7: AdminReviewsView(viewModel: viewModel)
        case 8: AdminEventsView(viewModel: viewModel)
        case 9: AdminMarginsView(viewModel: viewModel)
        case 10:
            AdminContactMessagesView(
                viewModel: viewModel,
                onViewOrderFromMessage: { orderId in
                    viewModel.pendingOrderIdToOpen = orderId
                    selectedTab = 2
                }
            )
        case 11: AdminSettingsView(viewModel: viewModel)
        case 12: AdminCakeGalleryView(viewModel: viewModel)
        case 13: AdminInventoryView(viewModel: viewModel)
        default: EmptyView()
        }
    }

    private func applyPendingPushAction() {
        guard let action = notificationService.pendingPushAction else { return }
        switch action {
        case .openAdminMessages(let mid):
            selectedTab = 10
            viewModel.scrollToMessageId = mid
        case .openAdminOrder(orderId: _):
            selectedTab = 2
        case .openAdminInventory:
            selectedTab = 13
        case .openAdminReviews:
            selectedTab = 7
        case .openOrder(orderId: _):
            break
        case .openEvents:
            break
        case .openContactReplies:
            break
        case .openRewards:
            break
        }
        notificationService.clearPendingPushAction()
    }
}

struct AdminAccessDeniedView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Text("Admin Access")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Sign in with an owner account to manage the business.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Admin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
    }
}

struct AdminProductsView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAddProduct = false
    
    var body: some View {
        NavigationStack {
            List {
                #if os(macOS)
                /// Toolbar “Add” is often not visible here (nested `NavigationStack` in the admin sheet); match Categories tab.
                Section {
                    Button {
                        showAddProduct = true
                    } label: {
                        Label("Add product", systemImage: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
                #endif
                ForEach(viewModel.products, id: \.id) { product in
                    AdminProductRow(
                        product: product,
                        onEdit: { viewModel.editingProduct = product },
                        onToggleSoldOut: { Task { await viewModel.setSoldOut(product: product, soldOut: !product.isSoldOut) } }
                    )
                }
            }
            .navigationTitle("Products")
            #if os(macOS)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Products")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        showAddProduct = true
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Add") {
                        showAddProduct = true
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            #endif
            .overlay(alignment: .top) {
                if let msg = viewModel.errorMessage ?? viewModel.productLoadWarning {
                    ErrorMessageBanner(message: msg) { viewModel.dismissProductBanner() }
                        .padding()
                }
            }
            /// `List` + `.overlay(alignment: .bottom)` often centers the toast; `safeAreaInset` pins it to the bottom.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let msg = viewModel.successMessage {
                    Text(msg)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.green.opacity(0.18))
                }
            }
            .sheet(isPresented: $showAddProduct) {
                AddProductView(viewModel: viewModel)
                    .macOSAdminSheetSizeLarge()
            }
            .sheet(item: $viewModel.editingProduct) { product in
                EditProductView(product: product, viewModel: viewModel)
                    .macOSAdminSheetSizeLarge()
            }
        }
    }
}

struct AdminCategoriesView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAddCategory = false
    /// Use `sheet(item:)` (not `isPresented` + optional) so macOS always builds sheet content with a real category — otherwise the sheet can open empty.
    @State private var editingCategory: ProductCategoryItem?
    @State private var categoryToDelete: ProductCategoryItem?
    
    var body: some View {
        NavigationStack {
            List {
                #if os(macOS)
                Section {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add category", systemImage: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
                #endif
                ForEach(viewModel.productCategories.sorted { $0.displayOrder < $1.displayOrder }) { item in
                    HStack {
                        Text(item.name)
                            .font(.headline)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Spacer()
                        Text("Order: \(item.displayOrder)")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        Button("Edit") {
                            editingCategory = item
                        }
                            .foregroundStyle(AppConstants.Colors.accent)
                            .buttonStyle(.borderless)
                        Button("Delete", role: .destructive, action: { categoryToDelete = item })
                            .buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Add") {
                        showAddCategory = true
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet(viewModel: viewModel) {
                    showAddCategory = false
                }
                .macOSAdminSheetSize()
            }
            .sheet(item: $editingCategory) { item in
                EditCategorySheet(viewModel: viewModel, item: item) {
                    editingCategory = nil
                }
                .id(item.id)
                .macOSAdminSheetSize()
            }
            .alert("Delete category?", isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } })) {
                Button("Cancel", role: .cancel) { categoryToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let item = categoryToDelete {
                        Task {
                            await viewModel.deleteCategory(item)
                            categoryToDelete = nil
                        }
                    }
                }
            } message: {
                if let item = categoryToDelete {
                    Text("“\(item.name)” will be removed. You cannot delete a category that has products; move or delete those products first.")
                }
            }
            .overlay(alignment: .top) {
                if let msg = viewModel.categoryErrorMessage {
                    ErrorMessageBanner(message: msg) { viewModel.dismissCategoryBanner() }
                        .padding()
                }
                if let msg = viewModel.successMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Dismiss", action: { viewModel.dismissCategoryBanner() })
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
                    .padding()
                }
            }
        }
    }
}

struct AddCategorySheet: View {
    @ObservedObject var viewModel: AdminViewModel
    var onDismiss: () -> Void
    @State private var name = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category name", text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                } header: {
                    Text("Category name")
                } footer: {
                    if let msg = viewModel.categoryErrorMessage, !msg.isEmpty {
                        Text(msg)
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .macOSCompactFormContent()
            .macOSGroupedFormStyle()
            .navigationTitle("New Category")
            .inlineNavigationTitle()
            .onAppear {
                viewModel.dismissCategoryBanner()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            let didSave = await viewModel.addCategory(name: name)
                            isSaving = false
                            if didSave {
                                onDismiss()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
        }
    }
}

struct EditCategorySheet: View {
    @ObservedObject var viewModel: AdminViewModel
    let item: ProductCategoryItem
    var onDismiss: () -> Void
    @State private var name: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category name", text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                } header: {
                    Text("Category name")
                } footer: {
                    if let msg = viewModel.categoryErrorMessage, !msg.isEmpty {
                        Text(msg)
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .macOSCompactFormContent()
            .macOSGroupedFormStyle()
            .navigationTitle("Edit Category")
            .inlineNavigationTitle()
            .onAppear {
                name = item.name
                viewModel.dismissCategoryBanner()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            let didSave = await viewModel.updateCategory(item, name: name.trimmingCharacters(in: .whitespaces))
                            isSaving = false
                            if didSave {
                                onDismiss()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
        }
    }
}

struct AdminProductRow: View {
    let product: Product
    let onEdit: () -> Void
    let onToggleSoldOut: () -> Void

    private var isSampleProduct: Bool {
        product.id?.hasPrefix("sample-") ?? false
    }

    /// When stock is tracked, availability follows quantity — hide the manual flag toggle so it never contradicts "Sold Out" from inventory.
    private var usesInventoryForAvailability: Bool {
        product.stockQuantity != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onEdit) {
                HStack(alignment: .top, spacing: 12) {
                    ProductImageView(urlString: product.imageURL, placeholderName: "photo")
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(product.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if isSampleProduct {
                                Text("Sample")
                                    .font(.caption2)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppConstants.Colors.textSecondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(product.price.currencyFormatted)
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        if let q = product.stockQuantity {
                            Text("Stock: \(q)")
                                .font(.caption2)
                                .foregroundStyle(product.isLowStock ? .orange : AppConstants.Colors.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if isSampleProduct {
                    Text("Add real products above")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                } else {
                    Group {
                        if usesInventoryForAvailability {
                            if product.isSoldOutByInventory {
                                Text("Sold Out")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            } else if product.showsAdminLowStockBadge {
                                Text("Low stock")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        } else if product.isSoldOut {
                            Text("Sold Out")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(minHeight: 18, alignment: .trailing)

                    HStack(spacing: 12) {
                        Button("Edit", action: onEdit)
                            .foregroundStyle(AppConstants.Colors.accent)
                            .fixedSize()
                        if !usesInventoryForAvailability {
                            Button(product.isSoldOut ? "Mark available" : "Mark sold out", action: onToggleSoldOut)
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.accent)
                                .fixedSize()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        #if os(macOS)
        .contextMenu {
            Button("Edit", action: onEdit)
            if !usesInventoryForAvailability {
                Button(product.isSoldOut ? "Mark available" : "Mark sold out", action: onToggleSoldOut)
            }
        }
        #endif
    }
}

struct AddProductView: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var costText = ""
    @State private var category = ProductCategory.cupcakes.rawValue
    @State private var isFeatured = false
    @State private var isVegetarian = false
    @State private var stockText = ""
    @State private var lowStockText = ""
    @State private var selectedImage: PlatformImage?
    @State private var showImagePicker = false
    @State private var isSaving = false
    
    private var categoryOptions: [String] {
        viewModel.productCategoryNames.isEmpty ? ProductCategory.allCases.map(\.rawValue) : viewModel.productCategoryNames
    }
    
    private var canSaveNewProduct: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    Section {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("addProductError")
                    }
                }
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    #if os(macOS)
                    .lineLimit(2...4)
                    #else
                    .lineLimit(3...6)
                    #endif
                TextField("Price", text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("Cost per unit (optional, for margins)", text: $costText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Picker("Category", selection: $category) {
                    ForEach(categoryOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Toggle("Featured", isOn: $isFeatured)
                Toggle("Vegetarian", isOn: $isVegetarian)
                TextField("Stock (optional)", text: $stockText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                TextField("Low stock alert at (optional)", text: $lowStockText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("Product photo (shows on menu)")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Button(selectedImage == nil ? "Add photo" : "Change photo") {
                    showImagePicker = true
                }
                if selectedImage != nil {
                    Image(platformImage: selectedImage!)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: adminProductPhotoHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity)
            .macOSCompactFormContent()
            .macOSGroupedFormStyle()
            .navigationTitle("New Product")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { @MainActor in
                            guard canSaveNewProduct, !isSaving else { return }
                            isSaving = true
                            defer { isSaving = false }
                            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                            let cost = Double(costText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
                            let costOpt = (cost != nil && cost! > 0) ? cost : nil
                            let stock = Int(stockText.trimmingCharacters(in: .whitespaces))
                            let low = Int(lowStockText.trimmingCharacters(in: .whitespaces))
                            let didSave = await viewModel.addProduct(
                                name: trimmedName,
                                description: description,
                                price: price,
                                cost: costOpt,
                                category: category,
                                isFeatured: isFeatured,
                                isVegetarian: isVegetarian,
                                image: selectedImage,
                                stockQuantity: stock,
                                lowStockThreshold: low
                            )
                            if didSave {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSaveNewProduct || isSaving)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.15)
                        ProgressView("Saving…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                viewModel.dismissProductBanner()
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
}

struct EditProductView: View {
    let product: Product
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var priceText: String
    @State private var costText: String
    @State private var category: String
    @State private var isFeatured: Bool
    @State private var isSoldOut: Bool
    @State private var isVegetarian: Bool
    @State private var stockText: String
    @State private var lowStockText: String
    @State private var selectedImage: PlatformImage?
    @State private var showImagePicker = false
    @State private var showDeleteConfirm = false
    @State private var isSaving = false
    
    private var canDelete: Bool {
        guard let id = product.id else { return false }
        return !id.hasPrefix("sample-")
    }

    private var isSampleProduct: Bool {
        product.id?.hasPrefix("sample-") ?? false
    }
    
    init(product: Product, viewModel: AdminViewModel) {
        self.product = product
        self.viewModel = viewModel
        _name = State(initialValue: product.name)
        _description = State(initialValue: product.productDescription)
        _priceText = State(initialValue: String(format: "%.2f", product.price))
        _costText = State(initialValue: product.cost.map { String(format: "%.2f", $0) } ?? "")
        _category = State(initialValue: product.category)
        _isFeatured = State(initialValue: product.isFeatured)
        _isSoldOut = State(initialValue: product.isSoldOut)
        _isVegetarian = State(initialValue: product.isVegetarian)
        _stockText = State(initialValue: product.stockQuantity.map { String($0) } ?? "")
        _lowStockText = State(initialValue: product.lowStockThreshold.map { String($0) } ?? "")
    }

    private var editCategoryOptions: [String] {
        let names = viewModel.productCategoryNames.isEmpty ? ProductCategory.allCases.map(\.rawValue) : viewModel.productCategoryNames
        if names.contains(category) { return names }
        return names + [category]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    Section {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                if isSampleProduct {
                    Section {
                        Text("Sample product — changes won't save to the server. Use Add to create real products.")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    #if os(macOS)
                    .lineLimit(2...4)
                    #else
                    .lineLimit(3...6)
                    #endif
                TextField("Price", text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("Cost per unit (optional, for margins)", text: $costText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Picker("Category", selection: $category) {
                    ForEach(editCategoryOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Toggle("Featured", isOn: $isFeatured)
                Toggle("Sold out", isOn: $isSoldOut)
                Toggle("Vegetarian", isOn: $isVegetarian)
                TextField("Stock (optional)", text: $stockText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                TextField("Low stock alert at (optional)", text: $lowStockText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("Product photo (shows on menu)")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Button(selectedImage == nil ? "Change photo" : "Change photo") {
                    showImagePicker = true
                }
                if let img = selectedImage {
                    Image(platformImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: adminProductPhotoHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if product.imageURL != nil {
                    ProductImageView(urlString: product.imageURL, placeholderName: "photo")
                        .frame(maxWidth: .infinity)
                        .frame(height: adminProductPhotoHeight)
                        .clipped()
                }
                if canDelete {
                    Section {
                        Button("Remove product", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .macOSCompactFormContent()
            .macOSGroupedFormStyle()
            .navigationTitle("Edit Product")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.editingProduct = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { @MainActor in
                            guard !isSaving else { return }
                            isSaving = true
                            defer { isSaving = false }
                            var updated = product
                            updated.name = name
                            updated.productDescription = description
                            updated.price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? product.price
                            let costVal = Double(costText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
                            updated.cost = (costVal != nil && costVal! > 0) ? costVal : nil
                            updated.category = category
                            updated.isFeatured = isFeatured
                            updated.isSoldOut = isSoldOut
                            updated.isVegetarian = isVegetarian
                            updated.stockQuantity = Int(stockText.trimmingCharacters(in: .whitespaces))
                            updated.lowStockThreshold = Int(lowStockText.trimmingCharacters(in: .whitespaces))
                            if let q = updated.stockQuantity, q > 0 {
                                updated.isSoldOut = false
                            }
                            let didSave = await viewModel.updateProduct(updated, newImage: selectedImage)
                            if didSave {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.15)
                        ProgressView("Saving…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                viewModel.dismissProductBanner()
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .alert("Remove product?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { showDeleteConfirm = false }
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.deleteProduct(product)
                        dismiss()
                    }
                }
            } message: {
                Text("“\(product.name)” will be removed from the menu. This cannot be undone.")
            }
        }
    }
}

/// Single-line order row for macOS admin orders list (tile-like; new orders add as another line underneath).
private struct AdminOrderRowCompactView: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            Text(order.createdAt?.shortDateString ?? "—")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(order.customerName)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text("\(order.items.count) items · \(order.total.currencyFormatted)")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(order.status)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch order.statusEnum {
        case .completed: return .green
        case .cancelled: return .red
        case .ready: return .blue
        default: return AppConstants.Colors.accent
        }
    }
}

/// Single-line custom cake order row for macOS (matches regular order row style).
private struct AdminCustomCakeRowCompactView: View {
    let order: CustomCakeOrder

    var body: some View {
        HStack(spacing: 12) {
            Text(order.createdAt?.shortDateString ?? "—")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(order.summary)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(order.price.currencyFormatted)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Custom")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppConstants.Colors.accent.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Single-line gallery (AI design) order row for macOS (matches regular order row style).
private struct AdminGalleryOrderRowCompactView: View {
    let order: AICakeDesignOrder

    var body: some View {
        HStack(spacing: 12) {
            Text(order.createdAt?.shortDateString ?? "—")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(order.summary)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(order.price.currencyFormatted)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Gallery")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppConstants.Colors.accent.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct AdminOrdersView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAddManualOrder = false
    @State private var orderToOpenFromMessage: Order?

    private var paymentLinkSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.paymentLinkURL != nil || viewModel.paymentLinkError != nil },
            set: { if !$0 { viewModel.clearPaymentLink() } }
        )
    }

    private func tryOpenOrderFromMessage() {
        guard let id = viewModel.pendingOrderIdToOpen, !id.isEmpty else { return }
        if let order = viewModel.orders.first(where: { $0.id == id }) {
            orderToOpenFromMessage = order
        }
        viewModel.pendingOrderIdToOpen = nil
    }

    private var ordersListContent: some View {
        List {
            Section("Filter orders") {
                TextField("Search name, phone, email", text: $viewModel.adminOrderSearchText)
                    .textFieldStyle(.roundedBorder)
                Picker("Status", selection: $viewModel.adminOrderStatusFilter) {
                    Text("Any status").tag("")
                    ForEach(OrderStatus.allCases, id: \.rawValue) { s in
                        Text(s.rawValue).tag(s.rawValue)
                    }
                }
                Picker("Fulfillment", selection: $viewModel.adminOrderFulfillmentFilter) {
                    Text("Any").tag("")
                    ForEach(FulfillmentType.allCases, id: \.rawValue) { f in
                        Text(f.rawValue).tag(f.rawValue)
                    }
                }
                Toggle("Created on or after…", isOn: Binding(
                    get: { viewModel.adminOrderDateFrom != nil },
                    set: { on in
                        if on {
                            viewModel.adminOrderDateFrom = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        } else {
                            viewModel.adminOrderDateFrom = nil
                        }
                    }
                ))
                if viewModel.adminOrderDateFrom != nil {
                    DatePicker("Start date", selection: Binding(
                        get: { viewModel.adminOrderDateFrom ?? Date() },
                        set: { viewModel.adminOrderDateFrom = $0 }
                    ), displayedComponents: [.date])
                }
                Toggle("Created on or before…", isOn: Binding(
                    get: { viewModel.adminOrderDateTo != nil },
                    set: { on in
                        if on { viewModel.adminOrderDateTo = Date() }
                        else { viewModel.adminOrderDateTo = nil }
                    }
                ))
                if viewModel.adminOrderDateTo != nil {
                    DatePicker("End date", selection: Binding(
                        get: { viewModel.adminOrderDateTo ?? Date() },
                        set: { viewModel.adminOrderDateTo = $0 }
                    ), displayedComponents: [.date])
                }
                HStack {
                    Button("Apply filters") {
                        Task { await viewModel.loadOrders() }
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                    Button("Clear") {
                        viewModel.adminOrderStatusFilter = ""
                        viewModel.adminOrderFulfillmentFilter = ""
                        viewModel.adminOrderSearchText = ""
                        viewModel.adminOrderDateFrom = nil
                        viewModel.adminOrderDateTo = nil
                        Task { await viewModel.loadOrders() }
                    }
                }
                .font(.subheadline)
            }
            #if os(macOS)
            Section {
                Button {
                    showAddManualOrder = true
                } label: {
                    Label("Add order", systemImage: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
                .buttonStyle(.plain)
            }
            #endif
            Section("Orders") {
                ForEach(viewModel.orders) { order in
                    NavigationLink {
                        OrderDetailView(
                            order: order,
                            isAdmin: true,
                            onUpdateStatus: { updatedOrder, newStatus in
                                Task { await viewModel.updateOrderStatus(order: updatedOrder, status: newStatus) }
                            },
                            onMarkAsPaid: { orderId in
                                Task { await viewModel.markOrderAsPaid(orderId: orderId) }
                            },
                            onSendPaymentLink: { orderId in
                                Task { await viewModel.createPaymentLink(for: orderId) }
                            },
                            onParcelTrackingChanged: {
                                Task { await viewModel.loadOrders() }
                            }
                        )
                    } label: {
                        #if os(macOS)
                        AdminOrderRowCompactView(order: order)
                        #else
                        OrderRowView(order: order, isAdmin: true) { updatedOrder, newStatus in
                            Task { await viewModel.updateOrderStatus(order: updatedOrder, status: newStatus) }
                        } onMarkAsPaid: { orderId in
                            Task { await viewModel.markOrderAsPaid(orderId: orderId) }
                        }
                        #endif
                    }
                }
            }
            Section("Special orders – Custom cakes") {
                customCakesSection
            }
            Section("Special orders – Gallery orders") {
                galleryOrdersSection
            }
        }
    }

    var body: some View {
        NavigationStack {
            ordersListContent
            .navigationTitle("Orders")
            .onAppear { tryOpenOrderFromMessage() }
            .onChange(of: viewModel.pendingOrderIdToOpen) { _, _ in tryOpenOrderFromMessage() }
            .onChange(of: viewModel.orders.count) { _, _ in tryOpenOrderFromMessage() }
            .sheet(item: $orderToOpenFromMessage) { order in
                OrderDetailView(
                    order: order,
                    isAdmin: true,
                    onUpdateStatus: { updatedOrder, newStatus in
                        Task { await viewModel.updateOrderStatus(order: updatedOrder, status: newStatus) }
                    },
                    onMarkAsPaid: { orderId in
                        Task { await viewModel.markOrderAsPaid(orderId: orderId) }
                    },
                    onSendPaymentLink: { orderId in
                        Task { await viewModel.createPaymentLink(for: orderId) }
                    },
                    onParcelTrackingChanged: {
                        Task { await viewModel.loadOrders() }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            #if os(macOS)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Orders")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if !viewModel.orders.isEmpty {
                            Button {
                                OrderExportHelper.presentExport(orders: viewModel.orders)
                            } label: {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                            .foregroundStyle(AppConstants.Colors.accent)
                        }
                        Button("Add order") {
                            showAddManualOrder = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    HStack(spacing: 12) {
                        if !viewModel.orders.isEmpty {
                            Button {
                                OrderExportHelper.presentExport(orders: viewModel.orders)
                            } label: {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                            .foregroundStyle(AppConstants.Colors.accent)
                        }
                        Button("Add order") {
                            showAddManualOrder = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
            #endif
            .refreshable {
                await viewModel.loadOrders()
                await viewModel.loadSpecialOrders()
            }
            .sheet(isPresented: $showAddManualOrder) {
                AddManualOrderSheet(viewModel: viewModel) {
                    showAddManualOrder = false
                }
                .macOSAdminSheetSizeLarge()
            }
            .sheet(isPresented: paymentLinkSheetPresented) {
                paymentLinkSheetContent
                    .macOSAdminSheetSize()
            }
        }
    }

    @ViewBuilder
    private var customCakesSection: some View {
        if viewModel.customCakeOrders.isEmpty {
            Text("No custom cake orders")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        } else {
            ForEach(Array(viewModel.customCakeOrders.enumerated()), id: \.offset) { _, o in
                NavigationLink {
                    CustomCakeOrderDetailView(order: o)
                } label: {
                    #if os(macOS)
                    AdminCustomCakeRowCompactView(order: o)
                    #else
                    VStack(alignment: .leading, spacing: 4) {
                        Text(o.summary)
                            .font(.headline)
                        Text(o.message)
                            .font(.caption)
                            .lineLimit(2)
                        Text("\(o.price.currencyFormatted) · \(o.createdAt?.shortDateString ?? "—")")
                            .font(.caption2)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    #endif
                }
            }
        }
    }

    @ViewBuilder
    private var galleryOrdersSection: some View {
        if viewModel.aiCakeDesignOrders.isEmpty {
            Text("No gallery orders")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        } else {
            ForEach(Array(viewModel.aiCakeDesignOrders.enumerated()), id: \.offset) { _, o in
                NavigationLink {
                    AICakeDesignOrderDetailView(order: o)
                } label: {
                    #if os(macOS)
                    AdminGalleryOrderRowCompactView(order: o)
                    #else
                    VStack(alignment: .leading, spacing: 4) {
                        Text(o.summary)
                            .font(.headline)
                        Text(o.designPrompt)
                            .font(.caption)
                            .lineLimit(2)
                        Text("\(o.price.currencyFormatted) · \(o.createdAt?.shortDateString ?? "—")")
                            .font(.caption2)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    #endif
                }
            }
        }
    }

    @ViewBuilder
    private var paymentLinkSheetContent: some View {
        NavigationStack {
            Group {
                if let url = viewModel.paymentLinkURL {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Send this link to the customer to pay:")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        Text(url.absoluteString)
                            .font(.caption)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        HStack(spacing: 12) {
                            Button {
                                #if os(iOS)
                                UIPasteboard.general.string = url.absoluteString
                                #else
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                #endif
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            ShareLink(item: url, subject: Text("Payment link"), message: Text("Pay for your Guilty Pleasure Treats order"))
                        }
                    }
                    .padding()
                } else if let err = viewModel.paymentLinkError {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Could not create payment link")
                            .font(.headline)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Payment link")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.clearPaymentLink()
                    }
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }
}

/// Editable line item for manual order entry.
private struct ManualOrderLineItem: Identifiable {
    let id = UUID()
    var name: String
    var priceText: String
    var quantity: Int
    var notes: String
}

/// On macOS, form label width so all value fields align in Add order.
#if os(macOS)
private let addOrderLabelWidth: CGFloat = 130
#endif

struct AddManualOrderSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    var onDismiss: () -> Void
    #if os(macOS)
    private let rowInsets = EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
    #endif
    @State private var customerName = ""
    @State private var customerPhone = ""
    @State private var customerEmail = ""
    @State private var street = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var fulfillmentType: FulfillmentType = .pickup
    @State private var scheduledDate = Date()
    @State private var useScheduledDate = false
    @State private var lineItems: [ManualOrderLineItem] = [
        ManualOrderLineItem(name: "", priceText: "", quantity: 1, notes: "")
    ]
    @State private var isSaving = false

    private var subtotal: Double {
        lineItems.reduce(0) { sum, row in
            let price = Double(row.priceText.replacingOccurrences(of: ",", with: "")) ?? 0
            return sum + price * Double(max(0, row.quantity))
        }
    }
    private var tax: Double { subtotal * (viewModel.businessSettings?.taxRate ?? AppConstants.taxRate) }
    private var total: Double { subtotal + tax }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                addOrderContentMacOS
                #else
                addOrderContentForm
                #endif
            }
            .navigationTitle("Add order")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveOrder() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
            .onAppear {
                Task { await viewModel.loadBusinessSettings() }
            }
        }
    }

    #if os(macOS)
    private var addOrderContentMacOS: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter customer and order details. Name and phone are required.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .padding(.horizontal, 4)

                addOrderCustomerCard
                addOrderAddressCard
                addOrderFulfillmentCard
                addOrderItemsCard
                addOrderTotalCard

                PrimaryButton(
                    title: "Save order",
                    action: { Task { await saveOrder() } },
                    isLoading: isSaving,
                    disabled: !canSave
                )
                .padding(.top, 8)
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.secondary)
    }

    private var addOrderCustomerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            orderSectionLabel("Customer")
            orderLabeledField("Name", placeholder: "e.g. John Smith", text: $customerName)
            orderLabeledField("Phone", placeholder: "(555) 123-4567", text: $customerPhone)
            orderLabeledField("Email (optional)", placeholder: "email@example.com", text: $customerEmail)
                .autocorrectionDisabled()
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var addOrderAddressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            orderSectionLabel("Address (optional)")
            orderLabeledField("Street address", placeholder: "123 Main St", text: $street)
            orderLabeledField("Apt, suite, unit", placeholder: "Apt 4", text: $addressLine2)
            Group {
                orderLabeledField("City", placeholder: "City", text: $city)
                orderLabeledField("State", placeholder: "State", text: $state)
            }
            orderLabeledField("ZIP code", placeholder: "12345", text: $zip)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var addOrderFulfillmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            orderSectionLabel("Fulfillment")
            VStack(alignment: .leading, spacing: 6) {
                Text("Type")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Picker("", selection: $fulfillmentType) {
                    ForEach(FulfillmentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
            }
            Toggle("Scheduled date", isOn: $useScheduledDate)
            if useScheduledDate {
                DatePicker("Date", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var addOrderItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            orderSectionLabel("Items")
            ForEach(lineItems.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        orderLabeledField("Item name", placeholder: "e.g. Chocolate cake", text: $lineItems[index].name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if lineItems.count > 1 {
                            Button {
                                lineItems.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack(alignment: .top, spacing: 16) {
                        orderLabeledField("Price", placeholder: "0.00", text: $lineItems[index].priceText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Qty")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                            TextField("", value: $lineItems[index].quantity, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 64, alignment: .leading)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    orderLabeledField("Notes (optional)", placeholder: "Optional notes", text: $lineItems[index].notes)
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(platformSystemGrayBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button("Add line item") {
                lineItems.append(ManualOrderLineItem(name: "", priceText: "", quantity: 1, notes: ""))
            }
            .foregroundStyle(AppConstants.Colors.accent)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var addOrderTotalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            orderSectionLabel("Total")
            HStack {
                Text("Subtotal")
                Spacer()
                Text(subtotal.currencyFormatted)
            }
            .font(.subheadline)
            HStack {
                Text("Tax")
                Spacer()
                Text(tax.currencyFormatted)
            }
            .font(.subheadline)
            HStack {
                Text("Total")
                    .fontWeight(.semibold)
                Spacer()
                Text(total.currencyFormatted)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func orderSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }

    private func orderLabeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
    #endif

    private var addOrderContentForm: some View {
        Form {
            Section("Customer") {
                TextField("Name", text: $customerName)
                    .multilineTextAlignment(.leading)
                TextField("Phone", text: $customerPhone)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .multilineTextAlignment(.leading)
                TextField("Email (optional)", text: $customerEmail)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.leading)
            }
            Section("Address (optional)") {
                TextField("Street address", text: $street)
                    #if os(iOS)
                    .autocapitalization(.words)
                    #endif
                    .multilineTextAlignment(.leading)
                TextField("Apt, suite, unit", text: $addressLine2)
                    #if os(iOS)
                    .autocapitalization(.words)
                    #endif
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    TextField("City", text: $city)
                        #if os(iOS)
                        .autocapitalization(.words)
                        #endif
                        .multilineTextAlignment(.leading)
                    TextField("State", text: $state)
                        #if os(iOS)
                        .autocapitalization(.words)
                        #endif
                        .multilineTextAlignment(.leading)
                }
                TextField("ZIP code", text: $zip)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.leading)
            }
            Section("Fulfillment") {
                Picker("Type", selection: $fulfillmentType) {
                    ForEach(FulfillmentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Toggle("Scheduled date", isOn: $useScheduledDate)
                if useScheduledDate {
                    DatePicker("Date", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            Section("Items") {
                ForEach(lineItems.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("Item name", text: $lineItems[index].name)
                                .multilineTextAlignment(.leading)
                            if lineItems.count > 1 {
                                Button {
                                    lineItems.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.body)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        HStack(spacing: 12) {
                            TextField("Price", text: $lineItems[index].priceText)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.leading)
                            TextField("Qty", value: $lineItems[index].quantity, format: .number)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .frame(width: 56)
                                .multilineTextAlignment(.leading)
                        }
                        TextField("Notes (optional)", text: $lineItems[index].notes)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteLineItems)
                Button("Add line item") {
                    lineItems.append(ManualOrderLineItem(name: "", priceText: "", quantity: 1, notes: ""))
                }
                .foregroundStyle(AppConstants.Colors.accent)
            }
            Section("Total") {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text(subtotal.currencyFormatted)
                }
                HStack {
                    Text("Tax")
                    Spacer()
                    Text(tax.currencyFormatted)
                }
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(total.currencyFormatted)
                        .fontWeight(.semibold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macOSCompactFormContent()
    }

    private var canSave: Bool {
        let nameOk = !customerName.trimmingCharacters(in: .whitespaces).isEmpty
        let phoneOk = !customerPhone.trimmingCharacters(in: .whitespaces).isEmpty
        let hasItems = lineItems.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && (Double($0.priceText.replacingOccurrences(of: ",", with: "")) ?? 0) > 0 && $0.quantity > 0 }
        return nameOk && phoneOk && hasItems
    }

    private func deleteLineItems(at offsets: IndexSet) {
        lineItems.remove(atOffsets: offsets)
        if lineItems.isEmpty {
            lineItems.append(ManualOrderLineItem(name: "", priceText: "", quantity: 1, notes: ""))
        }
    }

    private func saveOrder() async {
        isSaving = true
        defer { isSaving = false }
        let items: [OrderItem] = lineItems.compactMap { row in
            let name = row.name.trimmingCharacters(in: .whitespaces)
            let price = Double(row.priceText.replacingOccurrences(of: ",", with: "")) ?? 0
            let qty = max(0, row.quantity)
            guard !name.isEmpty, price > 0, qty > 0 else { return nil }
            return OrderItem(
                id: UUID().uuidString,
                productId: "manual",
                name: name,
                price: price,
                quantity: qty,
                specialInstructions: row.notes.trimmingCharacters(in: .whitespaces)
            )
        }
        guard !items.isEmpty else { return }
        let emailTrimmed = customerEmail.trimmingCharacters(in: .whitespaces)
        let addressParts = [
            street.trimmingCharacters(in: .whitespaces),
            addressLine2.trimmingCharacters(in: .whitespaces),
            city.trimmingCharacters(in: .whitespaces),
            state.trimmingCharacters(in: .whitespaces),
            zip.trimmingCharacters(in: .whitespaces)
        ]
        let deliveryAddressStr = addressParts.filter { !$0.isEmpty }.joined(separator: "\n")
        let order = Order(
            id: nil,
            userId: nil,
            customerName: customerName.trimmingCharacters(in: .whitespaces),
            customerPhone: customerPhone.trimmingCharacters(in: .whitespaces),
            customerEmail: emailTrimmed.isEmpty ? nil : emailTrimmed,
            deliveryAddress: deliveryAddressStr.isEmpty ? nil : deliveryAddressStr,
            items: items,
            subtotal: subtotal,
            tax: tax,
            total: total,
            fulfillmentType: fulfillmentType.rawValue,
            scheduledPickupDate: useScheduledDate ? scheduledDate : nil,
            status: OrderStatus.pending.rawValue,
            stripePaymentIntentId: nil,
            manualPaidAt: nil,
            createdAt: nil,
            updatedAt: nil,
            estimatedReadyTime: nil,
            customCakeOrderIds: nil,
            aiCakeDesignIds: nil,
            promoCode: nil
        )
        await viewModel.createManualOrder(order)
        onDismiss()
    }
}

struct AdminCustomersView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAddCustomer = false
    @State private var editingSavedCustomer: SavedCustomer?
    @State private var savedCustomerToDelete: SavedCustomer?
    @State private var selectedCustomer: AdminCustomer?
    
    var body: some View {
        NavigationStack {
            List {
                #if os(macOS)
                Section {
                    Button {
                        showAddCustomer = true
                    } label: {
                        Label("Add customer", systemImage: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
                #endif
                Section("Saved customers") {
                    ForEach(viewModel.savedCustomers) { c in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name)
                                    .font(.headline)
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                                if !c.phone.isEmpty {
                                    Text(c.phone)
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                                if let e = c.email, !e.isEmpty {
                                    Text(e)
                                        .font(.caption2)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                                if let a = c.addressDisplay, !a.isEmpty {
                                    Text(a)
                                        .font(.caption2)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 8)
                            HStack(spacing: 16) {
                                Button("Edit") {
                                    editingSavedCustomer = c
                                }
                                .foregroundStyle(AppConstants.Colors.accent)
                                .fixedSize()
                                Button("Delete", role: .destructive) {
                                    savedCustomerToDelete = c
                                }
                                .fixedSize()
                            }
                            // List rows treat buttons as row chrome; without this, clicks/taps often hit the wrong control (e.g. Edit opens instead of delete confirm).
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        #if os(macOS)
                        .contextMenu {
                            Button("Edit") {
                                editingSavedCustomer = c
                            }
                            Divider()
                            Button("Delete…", role: .destructive) {
                                savedCustomerToDelete = c
                            }
                        }
                        #endif
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                savedCustomerToDelete = c
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        #endif
                    }
                }
                if !viewModel.customersEligibleForRewards.isEmpty {
                    Section("Eligible for rewards") {
                        ForEach(viewModel.customersEligibleForRewards) { customer in
                            Button {
                                selectedCustomer = customer
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(customer.displayName)
                                            .font(.headline)
                                            .foregroundStyle(AppConstants.Colors.textPrimary)
                                        Text(customer.phone)
                                            .font(.caption)
                                            .foregroundStyle(AppConstants.Colors.textSecondary)
                                        if let rewardText = customer.rewardEligibilityText {
                                            Text(rewardText)
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    Spacer()
                                    Text("\(customer.orderCount) orders")
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                    Text(customer.totalSpent.currencyFormatted)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppConstants.Colors.accent)
                                }
                            }
                        }
                    }
                }
                Section("From orders") {
                    ForEach(viewModel.customers) { customer in
                        Button {
                            selectedCustomer = customer
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(customer.displayName)
                                        .font(.headline)
                                        .foregroundStyle(AppConstants.Colors.textPrimary)
                                    Text(customer.phone)
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                    if let points = customer.points {
                                        Text("\(points) points")
                                            .font(.caption2)
                                            .foregroundStyle(AppConstants.Colors.textSecondary)
                                    }
                                }
                                Spacer()
                                Text("\(customer.orderCount) orders")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                                Text(customer.totalSpent.currencyFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppConstants.Colors.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Customers")
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Add customer") {
                        showAddCustomer = true
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showAddCustomer) {
                AddCustomerSheet(viewModel: viewModel) { showAddCustomer = false }
                    .macOSAdminSheetSize()
            }
            .sheet(item: $editingSavedCustomer) { c in
                EditCustomerSheet(viewModel: viewModel, customer: c) { editingSavedCustomer = nil }
                    .macOSAdminSheetSize()
            }
            .alert("Delete customer?", isPresented: Binding(get: { savedCustomerToDelete != nil }, set: { if !$0 { savedCustomerToDelete = nil } })) {
                Button("Cancel", role: .cancel) { savedCustomerToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let c = savedCustomerToDelete {
                        Task { await viewModel.deleteSavedCustomer(c) }
                        savedCustomerToDelete = nil
                    }
                }
            } message: {
                if let c = savedCustomerToDelete {
                    Text("“\(c.name)” will be removed from your saved list. This does not affect orders.")
                }
            }
            .sheet(item: $selectedCustomer) { customer in
                CustomerDetailSheet(
                    viewModel: viewModel,
                    customer: customer,
                    onDismiss: { selectedCustomer = nil },
                    onEdit: { saved in editingSavedCustomer = saved; selectedCustomer = nil }
                )
                .macOSAdminSheetSize()
            }
            .overlay(alignment: .top) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) { viewModel.clearMessages() }
                        .padding()
                }
                if let msg = viewModel.successMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
            }
        }
    }
}

/// Shown when tapping a customer from "From orders" — lists their orders with Done and optional Edit.
struct CustomerDetailSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    let customer: AdminCustomer
    var onDismiss: () -> Void
    var onEdit: (SavedCustomer) -> Void
    @Environment(\.dismiss) private var dismiss

    private var matchingSavedCustomer: SavedCustomer? {
        viewModel.savedCustomers.first { saved in
            normalizePhoneForMatch(saved.phone) == normalizePhoneForMatch(customer.phone)
                || saved.name.trimmingCharacters(in: .whitespaces).lowercased() == customer.displayName.trimmingCharacters(in: .whitespaces).lowercased()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let points = customer.points {
                    Section {
                        HStack {
                            Text("Loyalty Points")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                            Spacer()
                            Text("\(points)")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                        if customer.canRedeemCupcake {
                            Label("Eligible for free cupcake (100 pts)", systemImage: "gift.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if customer.canRedeemCookie {
                            Label("Eligible for free cookie (50 pts)", systemImage: "gift.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if points > 0 {
                            Text("\(50 - points) more points for free cookie")
                                .font(.caption2)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                    }
                }
                Section("Orders") {
                    ForEach(customer.orders) { order in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.createdAt?.shortDateString ?? "—")
                                .font(.caption)
                            Text(order.status)
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.accent)
                            Text("\(order.items.count) items · \(order.total.currencyFormatted)")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle(customer.displayName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
                if let saved = matchingSavedCustomer {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            onEdit(saved)
                            dismiss()
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }
}

struct AddCustomerSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    var onDismiss: () -> Void
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var street = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add a customer to your contact list. All fields below are required.")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .padding(.horizontal, 4)

                    contactSection
                    addressSection
                    notesSection

                    PrimaryButton(
                        title: "Add customer",
                        action: { Task { await saveCustomer() } },
                        isLoading: isSaving,
                        disabled: !addCustomerCanSave
                    )
                    .padding(.top, 8)
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.bottom, 24)
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("New customer")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            customerFormSectionLabel("Contact details")
            labeledField("Full name", placeholder: "e.g. Jordan Smith", text: $name)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            labeledField("Phone", placeholder: "(555) 123-4567", text: $phone)
                #if os(iOS)
                .keyboardType(.phonePad)
                #endif
            labeledField("Email", placeholder: "customer@example.com", text: $email)
                #if os(iOS)
                .keyboardType(.emailAddress)
                #endif
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            customerFormSectionLabel("Address")
            labeledField("Street address", placeholder: "e.g. 123 Main St", text: $street)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            labeledField("Apt, suite, unit (optional)", placeholder: "e.g. Apt 4B", text: $addressLine2)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            HStack(spacing: 12) {
                labeledField("City", placeholder: "City", text: $city)
                    #if os(iOS)
                .autocapitalization(.words)
                #endif
                labeledField("State", placeholder: "State", text: $state)
                    #if os(iOS)
                .autocapitalization(.words)
                #endif
            }
            labeledField("ZIP code", placeholder: "e.g. 12345", text: $zip)
                #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            customerFormSectionLabel("Notes")
            Text("Optional — dietary preferences, favorite orders, etc.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField("Add any notes about this customer", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func customerFormSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var addCustomerCanSave: Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        let p = phone.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        let st = street.trimmingCharacters(in: .whitespaces)
        let c = city.trimmingCharacters(in: .whitespaces)
        let s = state.trimmingCharacters(in: .whitespaces)
        let z = zip.trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && !p.isEmpty && !e.isEmpty && !st.isEmpty && !c.isEmpty && !s.isEmpty && !z.isEmpty
    }

    private func saveCustomer() async {
        isSaving = true
        await viewModel.addSavedCustomer(
            name: name,
            phone: phone,
            email: email.trimmingCharacters(in: .whitespaces),
            street: street.trimmingCharacters(in: .whitespaces),
            addressLine2: addressLine2.isEmpty ? nil : addressLine2.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces),
            state: state.trimmingCharacters(in: .whitespaces),
            postalCode: zip.trimmingCharacters(in: .whitespaces),
            notes: notes.isEmpty ? nil : notes
        )
        isSaving = false
        onDismiss()
    }
}

struct EditCustomerSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    let customer: SavedCustomer
    var onDismiss: () -> Void
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var street: String = ""
    @State private var addressLine2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Update this customer’s contact and address. All fields below are required.")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .padding(.horizontal, 4)

                    editContactSection
                    editAddressSection
                    editNotesSection

                    PrimaryButton(
                        title: "Save changes",
                        action: { Task { await updateCustomer() } },
                        isLoading: isSaving,
                        disabled: !editCustomerCanSave
                    )
                    .padding(.top, 8)
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.bottom, 24)
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Edit customer")
            .inlineNavigationTitle()
            .onAppear {
                name = customer.name
                phone = customer.phone
                email = customer.email ?? ""
                if let s = customer.street, !s.isEmpty {
                    street = s
                    addressLine2 = customer.addressLine2 ?? ""
                    city = customer.city ?? ""
                    state = customer.state ?? ""
                    zip = customer.postalCode ?? ""
                } else if let a = customer.address {
                    let parsed = Self.parseStoredAddress(a)
                    street = parsed.street
                    addressLine2 = parsed.addressLine2
                    city = parsed.city
                    state = parsed.state
                    zip = parsed.zip
                }
                notes = customer.notes ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }

    private var editContactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            editFormSectionLabel("Contact details")
            editLabeledField("Full name", placeholder: "e.g. Jordan Smith", text: $name)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            editLabeledField("Phone", placeholder: "(555) 123-4567", text: $phone)
                #if os(iOS)
                .keyboardType(.phonePad)
                #endif
            editLabeledField("Email", placeholder: "customer@example.com", text: $email)
                #if os(iOS)
                .keyboardType(.emailAddress)
                #endif
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var editAddressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            editFormSectionLabel("Address")
            editLabeledField("Street address", placeholder: "e.g. 123 Main St", text: $street)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            editLabeledField("Apt, suite, unit (optional)", placeholder: "e.g. Apt 4B", text: $addressLine2)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            HStack(spacing: 12) {
                editLabeledField("City", placeholder: "City", text: $city)
                    #if os(iOS)
                .autocapitalization(.words)
                #endif
                editLabeledField("State", placeholder: "State", text: $state)
                    #if os(iOS)
                .autocapitalization(.words)
                #endif
            }
            editLabeledField("ZIP code", placeholder: "e.g. 12345", text: $zip)
                #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var editNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            editFormSectionLabel("Notes")
            Text("Optional — dietary preferences, favorite orders, etc.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField("Add any notes about this customer", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func editFormSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }

    private func editLabeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var editCustomerCanSave: Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        let p = phone.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        let st = street.trimmingCharacters(in: .whitespaces)
        let c = city.trimmingCharacters(in: .whitespaces)
        let s = state.trimmingCharacters(in: .whitespaces)
        let z = zip.trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && !p.isEmpty && !e.isEmpty && !st.isEmpty && !c.isEmpty && !s.isEmpty && !z.isEmpty
    }

    private static func parseStoredAddress(_ stored: String?) -> (street: String, addressLine2: String, city: String, state: String, zip: String) {
        guard let s = stored?.trimmingCharacters(in: .whitespaces), !s.isEmpty else {
            return ("", "", "", "", "")
        }
        let parts = s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        switch parts.count {
        case 5...:
            return (parts[0], parts[1], parts[2], parts[3], parts[4])
        case 4:
            return (parts[0], "", parts[1], parts[2], parts[3])
        default:
            return (s, "", "", "", "")
        }
    }

    private func updateCustomer() async {
        isSaving = true
        await viewModel.updateSavedCustomer(
            customer,
            name: name,
            phone: phone,
            email: email.trimmingCharacters(in: .whitespaces),
            street: street.trimmingCharacters(in: .whitespaces),
            addressLine2: addressLine2.isEmpty ? nil : addressLine2.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces),
            state: state.trimmingCharacters(in: .whitespaces),
            postalCode: zip.trimmingCharacters(in: .whitespaces),
            notes: notes.isEmpty ? nil : notes
        )
        isSaving = false
        onDismiss()
    }
}

struct AdminPromotionsView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAddPromo = false
    @State private var editingPromo: Promotion?
    
    var body: some View {
        NavigationStack {
            List {
                #if os(macOS)
                Section {
                    Button {
                        showAddPromo = true
                    } label: {
                        Label("Add promo", systemImage: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
                #endif
                ForEach(viewModel.promotions, id: \.listingId) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.code)
                                .font(.headline)
                            Text("\(p.discountType) · \(p.value)")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                            if let rules = p.rewardRulesCaption {
                                Text(rules)
                                    .font(.caption2)
                                    .foregroundStyle(AppConstants.Colors.textSecondary.opacity(0.9))
                            }
                        }
                        Spacer()
                        if p.isActive {
                            Text("Active")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Button("Edit") {
                            editingPromo = p
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            if let id = p.id {
                                Task { await viewModel.deletePromotion(id: id) }
                            }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("Promotions")
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Add") {
                        showAddPromo = true
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showAddPromo) {
                AddPromotionView(viewModel: viewModel)
                    .macOSAdminSheetSizeForm()
            }
            .sheet(item: $editingPromo) { p in
                EditPromotionView(promotion: p, viewModel: viewModel)
                    .macOSAdminSheetSizeForm()
            }
        }
    }
}

struct AddPromotionView: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var discountType = PromotionDiscountType.percent.rawValue
    @State private var valueText = ""
    @State private var isActive = true
    @State private var minSubtotalText = ""
    @State private var minTotalQuantityText = ""
    @State private var firstOrderOnly = false
    
    var body: some View {
        NavigationStack {
            Form {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    Section {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    TextField("Code", text: $code)
                        .multilineTextAlignment(.leading)
                } header: {
                    Text("Code")
                }
                Section {
                    Picker("Type", selection: $discountType) {
                        ForEach(PromotionDiscountType.allCases) { t in
                            Text(t.rawValue).tag(t.rawValue)
                        }
                    }
                } header: {
                    Text("Type")
                }
                Section {
                    TextField("Value", text: $valueText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.leading)
                } header: {
                    Text("Value")
                }
                Section {
                    TextField("Minimum cart ($), optional", text: $minSubtotalText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Minimum total items, optional", text: $minTotalQuantityText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Toggle("First order only (signed-in, no prior orders)", isOn: $firstOrderOnly)
                } header: {
                    Text("Reward rules")
                } footer: {
                    Text("Leave minimums blank for no threshold. First-order offers require checkout while signed in.")
                        .font(.caption)
                }
                Section {
                    Toggle("Active", isOn: $isActive)
                } header: {
                    Text("Active")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .macOSCompactFormContent()
            .macOSGroupedFormStyle()
            .navigationTitle("New Promotion")
            .onAppear { viewModel.clearMessages() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let val = Double(valueText) ?? 0
                        let minSub: Double? = {
                            let t = minSubtotalText.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty, let d = Double(t.replacingOccurrences(of: ",", with: "")), d > 0 else { return nil }
                            return d
                        }()
                        let minQty: Int? = {
                            let t = minTotalQuantityText.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty, let i = Int(t), i > 0 else { return nil }
                            return i
                        }()
                        Task {
                            let ok = await viewModel.addPromotion(Promotion(
                                code: code,
                                discountType: discountType,
                                value: val,
                                isActive: isActive,
                                minSubtotal: minSub,
                                minTotalQuantity: minQty,
                                firstOrderOnly: firstOrderOnly
                            ))
                            if ok { dismiss() }
                        }
                    }
                    .disabled(code.isEmpty || valueText.isEmpty)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
        }
    }
}

struct EditPromotionView: View {
    let promotion: Promotion
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var discountType: String
    @State private var valueText: String
    @State private var isActive: Bool
    @State private var minSubtotalText: String
    @State private var minTotalQuantityText: String
    @State private var firstOrderOnly: Bool
    
    init(promotion: Promotion, viewModel: AdminViewModel) {
        self.promotion = promotion
        self.viewModel = viewModel
        _code = State(initialValue: promotion.code)
        _discountType = State(initialValue: promotion.discountType)
        _valueText = State(initialValue: String(format: "%.2f", promotion.value))
        _isActive = State(initialValue: promotion.isActive)
        if let m = promotion.minSubtotal, m > 0 {
            _minSubtotalText = State(initialValue: String(format: "%.2f", m))
        } else {
            _minSubtotalText = State(initialValue: "")
        }
        if let q = promotion.minTotalQuantity, q > 0 {
            _minTotalQuantityText = State(initialValue: String(q))
        } else {
            _minTotalQuantityText = State(initialValue: "")
        }
        _firstOrderOnly = State(initialValue: promotion.firstOrderOnly)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    Section {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    TextField("Code", text: $code)
                        .multilineTextAlignment(.leading)
                } header: {
                    Text("Code")
                }
                Section {
                    Picker("Type", selection: $discountType) {
                        ForEach(PromotionDiscountType.allCases) { t in
                            Text(t.rawValue).tag(t.rawValue)
                        }
                    }
                } header: {
                    Text("Type")
                }
                Section {
                    TextField("Value", text: $valueText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.leading)
                } header: {
                    Text("Value")
                }
                Section {
                    TextField("Minimum cart ($), optional", text: $minSubtotalText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Minimum total items, optional", text: $minTotalQuantityText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Toggle("First order only (signed-in, no prior orders)", isOn: $firstOrderOnly)
                } header: {
                    Text("Reward rules")
                } footer: {
                    Text("Clear minimum fields to remove thresholds. Server enforces the same rules at checkout.")
                        .font(.caption)
                }
                Section {
                    Toggle("Active", isOn: $isActive)
                } header: {
                    Text("Active")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .macOSCompactFormContent()
            .macOSGroupedFormStyle()
            .navigationTitle("Edit Promotion")
            .onAppear { viewModel.clearMessages() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let val = Double(valueText.replacingOccurrences(of: ",", with: "")) ?? promotion.value
                        let minSub: Double? = {
                            let t = minSubtotalText.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty, let d = Double(t.replacingOccurrences(of: ",", with: "")), d > 0 else { return nil }
                            return d
                        }()
                        let minQty: Int? = {
                            let t = minTotalQuantityText.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty, let i = Int(t), i > 0 else { return nil }
                            return i
                        }()
                        var p = promotion
                        p.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
                        p.discountType = discountType
                        p.value = val
                        p.isActive = isActive
                        p.minSubtotal = minSub
                        p.minTotalQuantity = minQty
                        p.firstOrderOnly = firstOrderOnly
                        Task {
                            let ok = await viewModel.updatePromotion(p)
                            if ok { dismiss() }
                        }
                    }
                    .disabled(code.isEmpty || valueText.isEmpty)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
        }
    }
}

struct AdminCustomCakeOptionsView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var sizes: [CakeSizeOption] = []
    @State private var flavors: [CakeFlavorOption] = []
    @State private var frostings: [FrostingOption] = []
    @State private var toppings: [ToppingOption] = []
    @State private var showSizeSheet = false
    @State private var showFlavorSheet = false
    @State private var showFrostingSheet = false
    @State private var showToppingSheet = false
    @State private var editingSize: CakeSizeOption?
    @State private var editingFlavor: CakeFlavorOption?
    @State private var editingFrosting: FrostingOption?
    @State private var editingTopping: ToppingOption?

    var body: some View {
        NavigationStack {
            cakeOptionsList
                .navigationTitle("Cake Options")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await viewModel.saveCustomCakeOptions(sizes: sizes, flavors: flavors, frostings: frostings, toppings: toppings)
                            }
                        }
                        .disabled(sizes.isEmpty || flavors.isEmpty || frostings.isEmpty)
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
                .onAppear {
                    if let o = viewModel.customCakeOptions {
                        sizes = o.sizes
                        flavors = o.flavors
                        frostings = o.frostings
                        toppings = o.toppings ?? []
                    }
                }
                .onChange(of: viewModel.customCakeOptions) { _, newValue in
                    if let o = newValue {
                        sizes = o.sizes
                        flavors = o.flavors
                        frostings = o.frostings
                        toppings = o.toppings ?? []
                    }
                }
                .sheet(isPresented: $showSizeSheet) { sizeSheet }
                .sheet(isPresented: $showFlavorSheet) { flavorSheet }
                .sheet(isPresented: $showFrostingSheet) { frostingSheet }
                .sheet(isPresented: $showToppingSheet) { toppingSheet }
                .overlay(alignment: .top) { messageOverlay }
        }
    }

    private var cakeOptionsList: some View {
        List {
            Section {
                Text("These options appear in the Custom Cake builder in this order: Cake Size, Cake Flavor, Frosting, Toppings (optional). Tap Save to update.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Section("Cake Size (label + price)") {
                ForEach(sizes) { size in
                    HStack {
                        Text(size.label)
                        Spacer()
                        Text(size.price.currencyFormatted)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        Button("Edit") {
                            editingSize = size
                            showSizeSheet = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            sizes.removeAll { $0.id == size.id }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button("Add size") {
                    editingSize = nil
                    showSizeSheet = true
                }
                .foregroundStyle(AppConstants.Colors.accent)
            }
            Section("Cake Flavor") {
                ForEach(flavors) { flavor in
                    HStack {
                        Text(flavor.label)
                        Spacer()
                        Button("Edit") {
                            editingFlavor = flavor
                            showFlavorSheet = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            flavors.removeAll { $0.id == flavor.id }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button("Add flavor") {
                    editingFlavor = nil
                    showFlavorSheet = true
                }
                .foregroundStyle(AppConstants.Colors.accent)
            }
            Section("Frosting") {
                ForEach(frostings) { frosting in
                    HStack {
                        Text(frosting.label)
                        Spacer()
                        Button("Edit") {
                            editingFrosting = frosting
                            showFrostingSheet = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            frostings.removeAll { $0.id == frosting.id }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button("Add frosting") {
                    editingFrosting = nil
                    showFrostingSheet = true
                }
                .foregroundStyle(AppConstants.Colors.accent)
            }
            Section("Toppings (optional) (label + price)") {
                ForEach(toppings) { topping in
                    HStack {
                        Text(topping.label)
                        Spacer()
                        Text(topping.price.currencyFormatted)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                        Button("Edit") {
                            editingTopping = topping
                            showToppingSheet = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            toppings.removeAll { $0.id == topping.id }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button("Add topping") {
                    editingTopping = nil
                    showToppingSheet = true
                }
                .foregroundStyle(AppConstants.Colors.accent)
            }
        }
    }

    private var sizeSheet: some View {
        AdminCakeSizeEditSheet(
            size: editingSize,
            onSave: { label, price in
                if let existing = editingSize, let idx = sizes.firstIndex(where: { $0.id == existing.id }) {
                    sizes[idx] = CakeSizeOption(optionId: existing.optionId, label: label, price: price, sortOrder: existing.sortOrder)
                } else {
                    sizes.append(CakeSizeOption(optionId: nil, label: label, price: price, sortOrder: sizes.count))
                }
                showSizeSheet = false
                editingSize = nil
            },
            onCancel: { showSizeSheet = false; editingSize = nil }
        )
        .macOSAdminSheetSize()
    }

    private var flavorSheet: some View {
        AdminCakeOptionEditSheet(
            title: "Flavor",
            label: editingFlavor?.label ?? "",
            onSave: { label in
                if let existing = editingFlavor, let idx = flavors.firstIndex(where: { $0.id == existing.id }) {
                    flavors[idx] = CakeFlavorOption(optionId: existing.optionId, label: label, sortOrder: existing.sortOrder)
                } else {
                    flavors.append(CakeFlavorOption(optionId: nil, label: label, sortOrder: flavors.count))
                }
                showFlavorSheet = false
                editingFlavor = nil
            },
            onCancel: { showFlavorSheet = false; editingFlavor = nil }
        )
        .macOSAdminSheetSize()
    }

    private var frostingSheet: some View {
        AdminCakeOptionEditSheet(
            title: "Frosting",
            label: editingFrosting?.label ?? "",
            onSave: { label in
                if let existing = editingFrosting, let idx = frostings.firstIndex(where: { $0.id == existing.id }) {
                    frostings[idx] = FrostingOption(optionId: existing.optionId, label: label, sortOrder: existing.sortOrder)
                } else {
                    frostings.append(FrostingOption(optionId: nil, label: label, sortOrder: frostings.count))
                }
                showFrostingSheet = false
                editingFrosting = nil
            },
            onCancel: { showFrostingSheet = false; editingFrosting = nil }
        )
        .macOSAdminSheetSize()
    }

    private var toppingSheet: some View {
        AdminCakeToppingEditSheet(
            topping: editingTopping,
            onSave: { label, price in
                if let existing = editingTopping, let idx = toppings.firstIndex(where: { $0.id == existing.id }) {
                    toppings[idx] = ToppingOption(optionId: existing.optionId, label: label, price: price, sortOrder: existing.sortOrder)
                } else {
                    toppings.append(ToppingOption(optionId: nil, label: label, price: price, sortOrder: toppings.count))
                }
                showToppingSheet = false
                editingTopping = nil
            },
            onCancel: { showToppingSheet = false; editingTopping = nil }
        )
        .macOSAdminSheetSize()
    }

    @ViewBuilder private var messageOverlay: some View {
        Group {
            if let msg = viewModel.errorMessage {
                ErrorMessageBanner(message: msg) { viewModel.clearMessages() }
                    .padding()
            }
            if let msg = viewModel.successMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(8)
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }
}

struct AdminCakeSizeEditSheet: View {
    let size: CakeSizeOption?
    let onSave: (String, Double) -> Void
    let onCancel: () -> Void
    @State private var label: String = ""
    @State private var priceText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label (e.g. 6 inch)", text: $label)
                TextField("Price", text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .macOSGroupedFormStyle()
            .macOSEditSheetPadding()
            .navigationTitle(size == nil ? "Add size" : "Edit size")
            .inlineNavigationTitle()
            .onAppear {
                label = size?.label ?? ""
                priceText = size.map { String(format: "%.2f", $0.price) } ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                        onSave(label.trimmingCharacters(in: .whitespaces), price)
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || priceText.isEmpty)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }
}

struct AdminCakeToppingEditSheet: View {
    let topping: ToppingOption?
    let onSave: (String, Double) -> Void
    let onCancel: () -> Void
    @State private var label: String = ""
    @State private var priceText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label (e.g. Fresh berries)", text: $label)
                TextField("Price", text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .macOSGroupedFormStyle()
            .macOSEditSheetPadding()
            .navigationTitle(topping == nil ? "Add topping" : "Edit topping")
            .inlineNavigationTitle()
            .onAppear {
                label = topping?.label ?? ""
                priceText = topping.map { String(format: "%.2f", $0.price) } ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                        onSave(label.trimmingCharacters(in: .whitespaces), price)
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || priceText.isEmpty)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }
}

struct AdminCakeOptionEditSheet: View {
    let title: String
    let label: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $text)
            }
            .macOSGroupedFormStyle()
            .macOSEditSheetPadding()
            .navigationTitle(title)
            .inlineNavigationTitle()
            .onAppear { text = label }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(text.trimmingCharacters(in: .whitespaces)) }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }
}

struct AdminAnalyticsView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var selectedPeriod: AnalyticsPeriod = .thisWeek

    private var ordersByDay: [(date: Date, count: Int, revenue: Double)] {
        Array(viewModel.ordersByDay(for: selectedPeriod).prefix(14))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    periodPicker
                    summaryCards
                    financialReportSection
                    trendSection
                    revenueByDaySection
                    fulfillmentSection
                    analyticsInsightsHeader
                    statusFunnelSection
                    customerMixSection
                    promoRedemptionsSection
                    tipsSection
                    customAICakeSection
                    bestSellersSection
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Analytics")
            .largeNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentPrintReport()
                    } label: {
                        Label("Print report", systemImage: "printer")
                    }
                }
            }
            .refreshable {
                await viewModel.loadOrders()
                await viewModel.loadAnalyticsSummary()
            }
            .task {
                // Orders drive all period metrics; summary is only total customer count.
                await viewModel.loadOrders()
                await viewModel.loadAnalyticsSummary()
            }
        }
    }

    /// Makes new analytics blocks easy to spot (scroll below fulfillment / revenue by day).
    private var analyticsInsightsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("More insights")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("Status mix, guest vs signed-in, promos, tips, and custom/AI cakes for the selected period.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presentPrintReport() {
        let html = viewModel.financialReportHTML(period: selectedPeriod)
        PrintHelper.presentPrint(html: html)
    }

    private var financialReportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Financial report")
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
                Button {
                    presentPrintReport()
                } label: {
                    Label("Print", systemImage: "printer")
                        .font(.subheadline)
                }
                .foregroundStyle(AppConstants.Colors.accent)
            }
            Text("Summary for \(selectedPeriod.rawValue): revenue, orders, fulfillment, status funnel, customer mix, promos, tips, custom/AI cakes, and best sellers.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revenue")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Text(viewModel.totalRevenue(for: selectedPeriod).currencyFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Orders")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Text("\(viewModel.completedOrderCount(for: selectedPeriod))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg order")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Text(viewModel.averageOrderValue(for: selectedPeriod).currencyFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppConstants.Layout.cardPadding)
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AnalyticsMetricCard(
                    title: "Revenue",
                    value: viewModel.totalRevenue(for: selectedPeriod).currencyFormatted,
                    icon: "dollarsign.circle.fill"
                )
                AnalyticsMetricCard(
                    title: "Orders",
                    value: "\(viewModel.completedOrderCount(for: selectedPeriod))",
                    icon: "bag.circle.fill"
                )
            }
            HStack(spacing: 12) {
                AnalyticsMetricCard(
                    title: "Avg order value",
                    value: viewModel.averageOrderValue(for: selectedPeriod).currencyFormatted,
                    icon: "chart.bar.fill"
                )
                AnalyticsMetricCard(
                    title: "Pending",
                    value: "\(viewModel.pendingOrderCount)",
                    icon: "clock.circle.fill"
                )
            }
            HStack(spacing: 12) {
                AnalyticsMetricCard(
                    title: "Customer accounts",
                    value: "\(viewModel.totalCustomerCount)",
                    icon: "person.2.fill"
                )
            }
        }
    }

    private var trendSection: some View {
        Group {
            if let comp = viewModel.revenueComparison(for: selectedPeriod), comp.previous > 0 {
                let pct = ((comp.current - comp.previous) / comp.previous) * 100
                HStack(spacing: 8) {
                    Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pct >= 0 ? Color.green : Color.red)
                    Text("\(pct >= 0 ? "+" : "")\(String(format: "%.0f", pct))% vs previous period")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            }
        }
    }

    private var revenueByDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue by day")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)

            if ordersByDay.isEmpty {
                Text("No orders in this period")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(AppConstants.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(ordersByDay.enumerated()), id: \.element.date) { index, day in
                        AnalyticsDayRow(
                            date: day.date,
                            orderCount: day.count,
                            revenue: day.revenue
                        )
                        if index < ordersByDay.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                        .stroke(AppConstants.Colors.textSecondary.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private var fulfillmentSection: some View {
        let mix = viewModel.fulfillmentMix(for: selectedPeriod)
        return Group {
            if !mix.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fulfillment mix")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    VStack(spacing: 8) {
                        ForEach(Array(mix.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.type)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                                Spacer()
                                Text("\(item.count) orders")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                    .background(AppConstants.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                }
            }
        }
    }

    private var statusFunnelSection: some View {
        let funnel = viewModel.statusFunnel(for: selectedPeriod)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Status funnel")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if funnel.isEmpty {
                Text("No orders in this period.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(funnel.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.status)
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var customerMixSection: some View {
        let nvr = viewModel.newVsReturning(for: selectedPeriod)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Customer mix")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("Completed orders only (not cancelled).")
                .font(.caption2)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(nvr.guestOrders)")
                        .font(.subheadline.weight(.semibold))
                    Text("Guest checkout")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(nvr.signedInOrders)")
                        .font(.subheadline.weight(.semibold))
                    Text("Signed-in")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(nvr.repeatCustomerOrders)")
                        .font(.subheadline.weight(.semibold))
                    Text("Repeat (2+ in period)")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var promoRedemptionsSection: some View {
        let promos = viewModel.promoRedemptions(for: selectedPeriod)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Promo redemptions")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if promos.isEmpty {
                Text("No promo codes on completed orders this period (or orders not loaded yet).")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(promos.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.code)
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Spacer()
                            Text("\(item.count) orders")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var tipsSection: some View {
        let tipsCents = viewModel.totalTipsCents(for: selectedPeriod)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Tips collected")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text((Double(tipsCents) / 100.0).currencyFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var customAICakeSection: some View {
        let attach = viewModel.customAICakeAttach(for: selectedPeriod)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Custom & AI cakes")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if attach.total == 0 {
                Text("No completed orders in this period.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .padding(16)
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(attach.withCustom)")
                            .font(.subheadline.weight(.semibold))
                        Text("Custom cake")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(attach.withAI)")
                            .font(.subheadline.weight(.semibold))
                        Text("AI design")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    Text("of \(attach.total) completed orders")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var bestSellersSection: some View {
        let sellers = viewModel.bestSellers(for: selectedPeriod, limit: 10)
        return Group {
            if !sellers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best sellers")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    VStack(spacing: 0) {
                        ForEach(Array(sellers.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                                    .frame(width: 20, alignment: .leading)
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("×\(item.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                                Text(item.revenue.currencyFormatted)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppConstants.Colors.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            if index < sellers.count - 1 {
                                Divider()
                                    .padding(.leading, 36)
                            }
                        }
                    }
                    .background(AppConstants.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                            .stroke(AppConstants.Colors.textSecondary.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }
}

private struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppConstants.Colors.accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                .stroke(AppConstants.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct AnalyticsDayRow: View {
    let date: Date
    let orderCount: Int
    let revenue: Double
    
    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.shortDateString
    }
    
    var body: some View {
        HStack {
            Text(dateLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Spacer()
            Text("\(orderCount) orders")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(revenue.currencyFormatted)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.accent)
        }
        .padding(.horizontal, AppConstants.Layout.cardPadding)
        .padding(.vertical, 12)
    }
}

/// Presents the system print UI for HTML content (e.g. financial report).
private enum PrintHelper {
    static func presentPrint(html: String) {
        #if os(iOS)
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "Financial Report – Guilty Pleasure Treats"
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printFormatter = formatter
        printController.present(animated: true, completionHandler: nil)
        #else
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            let textView = NSTextView(frame: view.bounds)
            textView.textStorage?.setAttributedString(attributed)
            textView.draw(view.bounds)
        }
        NSPrintOperation(view: view, printInfo: printInfo).run()
        #endif
    }
}

private enum OrderExportHelper {
    static func presentExport(orders: [Order]) {
        let csv = buildCSV(orders: orders)
        let fileName = "orders-\(ISO8601DateFormatter().string(from: Date()).prefix(10)).csv"
        #if os(iOS)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: tmp, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        let av = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let popover = av.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(av, animated: true)
        #else
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    private static func escapeCSV(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func buildCSV(orders: [Order]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        var rows: [String] = []
        let header = "Order ID,Date,Customer,Phone,Email,Status,Fulfillment,Total,Items"
        rows.append(header)
        for o in orders {
            let dateStr = o.createdAt.map { dateFormatter.string(from: $0) } ?? ""
            let itemsSummary = o.items.map { "\($0.name) ×\($0.quantity)" }.joined(separator: "; ")
            let line = [
                escapeCSV(o.id ?? ""),
                escapeCSV(dateStr),
                escapeCSV(o.customerName),
                escapeCSV(o.customerPhone),
                escapeCSV(o.customerEmail ?? ""),
                escapeCSV(o.status),
                escapeCSV(o.fulfillmentType),
                escapeCSV(String(format: "%.2f", o.total)),
                escapeCSV(itemsSummary),
            ].joined(separator: ",")
            rows.append(line)
        }
        return rows.joined(separator: "\n")
    }
}

struct AdminReviewsView: View {
    @ObservedObject var viewModel: AdminViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.reviews.isEmpty {
                    // `ContentUnavailableView` centers in the full height on macOS → huge gap under the tab bar; keep empty state in a `List` so it aligns to the top like other admin tabs.
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("No reviews yet", systemImage: "star.fill")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Text("Customer reviews will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(viewModel.reviews) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            if let rating = review.rating, rating > 0 {
                                HStack(spacing: 2) {
                                    ForEach(0..<min(rating, 5), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(AppConstants.Colors.accent)
                                    }
                                }
                            }
                            if let text = review.text, !text.isEmpty {
                                Text(text)
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                            }
                            if let name = review.authorName, !name.isEmpty {
                                Text("— \(name)")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                            if let productId = review.productId, !productId.isEmpty {
                                Text("Product: \(productId)")
                                    .font(.caption2)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Reviews")
            .inlineNavigationTitle()
            .refreshable { await viewModel.loadReviews() }
        }
    }
}

struct AdminEventsView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAddEvent = false
    @State private var eventToEdit: Event?

    private func presentNewEventSheet() {
        eventToEdit = nil
        showAddEvent = true
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.events.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("No events yet", systemImage: "calendar")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Text("Events (tastings, pop-ups) will appear here. Add one to notify customers.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(action: presentNewEventSheet) {
                                Label("Add event", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    #if os(macOS)
                    Section {
                        Button(action: presentNewEventSheet) {
                            Label("Add event", systemImage: "plus.circle.fill")
                                .font(.body)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                    ForEach(viewModel.events) { event in
                        Button {
                            eventToEdit = event
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(event.title)
                                    .font(.headline)
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                                if let desc = event.eventDescription, !desc.isEmpty {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                                if let start = event.startAt {
                                    Label(start.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                                if let loc = event.location, !loc.isEmpty {
                                    Label(loc, systemImage: "mappin.circle")
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteEvent(id: event.id) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button(action: presentNewEventSheet) {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .refreshable { await viewModel.loadEvents() }
            .sheet(isPresented: $showAddEvent) {
                AdminEventFormSheet(
                    event: nil,
                    onSave: { title, desc, start, end, imageURL, location in
                        Task {
                            await viewModel.createEvent(title: title, eventDescription: desc, startAt: start, endAt: end, imageURL: imageURL, location: location)
                            showAddEvent = false
                        }
                    },
                    onCancel: { showAddEvent = false }
                )
                .macOSAdminSheetSize()
            }
            .sheet(item: $eventToEdit) { event in
                AdminEventFormSheet(
                    event: event,
                    onSave: { title, desc, start, end, imageURL, location in
                        Task {
                            await viewModel.updateEvent(id: event.id, title: title, eventDescription: desc, startAt: start, endAt: end, imageURL: imageURL, location: location)
                            eventToEdit = nil
                        }
                    },
                    onCancel: { eventToEdit = nil }
                )
                .macOSAdminSheetSize()
            }
        }
    }
}

/// Create or edit event: title, description, start/end, photo or PDF attachment, location.
private struct AdminEventFormSheet: View {
    let event: Event?
    let onSave: (String, String?, Date?, Date?, String?, String?) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var eventDescription: String = ""
    @State private var startAt: Date = Date()
    @State private var useStartDate: Bool = true
    @State private var endAt: Date = Date()
    @State private var useEndDate: Bool = false
    @State private var imageURL: String = ""
    @State private var location: String = ""
    @State private var selectedAttachmentData: Data?
    @State private var selectedAttachmentContentType: String?
    @State private var showAttachmentPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var attachmentLabel: String {
        guard selectedAttachmentData != nil else { return "" }
        return (selectedAttachmentContentType == "application/pdf") ? "PDF attached" : "Photo attached"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                }
                Section("Description (optional)") {
                    TextEditor(text: $eventDescription)
                        .frame(minHeight: 72)
                        #if os(macOS)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        #endif
                }
                Section("Start date & time") {
                    Toggle("Set start", isOn: $useStartDate)
                    if useStartDate {
                        DatePicker("Start", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("End date & time (optional)") {
                    Toggle("Set end", isOn: $useEndDate)
                    if useEndDate {
                        DatePicker("End", selection: $endAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("Photo or PDF (optional)") {
                    if let _ = selectedAttachmentData {
                        HStack {
                            Label(attachmentLabel, systemImage: selectedAttachmentContentType == "application/pdf" ? "doc.fill" : "photo.fill")
                                .foregroundStyle(AppConstants.Colors.accent)
                            Spacer()
                            Button("Remove", role: .destructive) {
                                selectedAttachmentData = nil
                                selectedAttachmentContentType = nil
                            }
                        }
                    } else {
                        Button {
                            showAttachmentPicker = true
                        } label: {
                            Label("Add photo or PDF", systemImage: "plus.circle.fill")
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                    }
                    TextField("Or paste image URL", text: $imageURL)
                        .textContentType(.URL)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif
                }
                Section("Location (optional)") {
                    TextField("Address or venue", text: $location)
                }
                if let err = saveError {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .macOSGroupedFormStyle()
            .macOSEditSheetPadding()
            .navigationTitle(event == nil ? "New event" : "Edit event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(AppConstants.Colors.accent)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveEvent() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showAttachmentPicker) {
                EventDocumentPicker(pickedData: $selectedAttachmentData, pickedContentType: $selectedAttachmentContentType)
            }
            .onAppear {
                saveError = nil
                if let e = event {
                    title = e.title
                    eventDescription = e.eventDescription ?? ""
                    if let s = e.startAt { startAt = s; useStartDate = true } else { useStartDate = false }
                    if let s = e.endAt { endAt = s; useEndDate = true } else { useEndDate = false }
                    imageURL = e.imageURL ?? ""
                    location = e.location ?? ""
                }
            }
        }
    }

    private func saveEvent() async {
        let start = useStartDate ? startAt : nil
        let end = useEndDate ? endAt : nil
        let finalImageURL: String?
        if let data = selectedAttachmentData, let contentType = selectedAttachmentContentType, !data.isEmpty {
            isSaving = true
            saveError = nil
            defer { isSaving = false }
            let ext: String
            if contentType == "application/pdf" { ext = "pdf" }
            else if contentType == "image/png" { ext = "png" }
            else { ext = "jpg" }
            let pathname = "events/\(UUID().uuidString).\(ext)"
            do {
                finalImageURL = try await VercelService.shared.uploadImageBase64(data: data, pathname: pathname, contentType: contentType)
            } catch {
                saveError = FriendlyErrorMessage.message(for: error)
                return
            }
        } else {
            finalImageURL = imageURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : imageURL.trimmingCharacters(in: .whitespaces)
        }
        onSave(
            title.trimmingCharacters(in: .whitespaces),
            eventDescription.isEmpty ? nil : eventDescription.trimmingCharacters(in: .whitespaces),
            start,
            end,
            finalImageURL,
            location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces)
        )
    }
}

struct AdminContactMessagesView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onViewOrderFromMessage: (String) -> Void = { _ in }
    @State private var selectedMessage: ContactMessage?
    @State private var showSendMessageSheet = false

    private func applyScrollToMessageId() {
        guard let messageId = viewModel.scrollToMessageId, !messageId.isEmpty else { return }
        if let msg = viewModel.contactMessages.first(where: { $0.id == messageId }) {
            selectedMessage = msg
            if msg.readAt == nil {
                Task { await viewModel.markContactMessageRead(msg) }
            }
            viewModel.clearScrollToMessageId()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.contactMessages.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("No messages", systemImage: "envelope.open")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Text("Contact form submissions from the app will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                showSendMessageSheet = true
                            } label: {
                                Label("Send message to customers", systemImage: "paperplane.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    #if os(macOS)
                    Section {
                        Button {
                            showSendMessageSheet = true
                        } label: {
                            Label("Send message", systemImage: "paperplane.fill")
                                .font(.body)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                    ForEach(viewModel.contactMessages) { msg in
                        Button {
                            selectedMessage = msg
                            if msg.readAt == nil {
                                Task { await viewModel.markContactMessageRead(msg) }
                            }
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(msg.email)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppConstants.Colors.textPrimary)
                                    if let sub = msg.subject, !sub.isEmpty {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(AppConstants.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    if let short = msg.orderReferenceShort, let full = msg.linkedOrderId {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Label(short, systemImage: "number.square.fill")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppConstants.Colors.accent)
                                            Text(full)
                                                .font(.caption2)
                                                .monospaced()
                                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.85)
                                                .textSelection(.enabled)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Linked order, reference \(short), full identifier \(full)")
                                    }
                                    Text(msg.message)
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if msg.readAt == nil {
                                    Circle()
                                        .fill(AppConstants.Colors.accent)
                                        .frame(width: 8, height: 8)
                                }
                                if let created = msg.createdAt {
                                    Text(created.shortDateString)
                                        .font(.caption2)
                                        .foregroundStyle(AppConstants.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button {
                        showSendMessageSheet = true
                    } label: {
                        Label("Send message", systemImage: "paperplane.fill")
                    }
                }
            }
            .refreshable { await viewModel.loadContactMessages() }
            .onAppear { applyScrollToMessageId() }
            .onChange(of: viewModel.scrollToMessageId) { _, _ in applyScrollToMessageId() }
            .onChange(of: viewModel.contactMessages.count) { _, _ in applyScrollToMessageId() }
            .macOSReduceSheetTitleGap()
            #if os(macOS)
            .padding(.top, -8)
            #endif
            .sheet(item: $selectedMessage) { msg in
                ContactMessageDetailSheet(
                    viewModel: viewModel,
                    message: msg,
                    onDismiss: { selectedMessage = nil },
                    onViewOrderFromMessage: onViewOrderFromMessage
                )
                .macOSAdminSheetSize()
            }
            .sheet(isPresented: $showSendMessageSheet) {
                SendAdminMessageSheet(
                    viewModel: viewModel,
                    onDismiss: { showSendMessageSheet = false }
                )
                .macOSAdminSheetSizeForm()
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sheet for admin to send a new message to a customer (by email or user ID) or to all customers.
struct SendAdminMessageSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var bodyText = ""
    @State private var isSending = false
    @FocusState private var bodyFocused: Bool

    private var recipientFieldPlaceholder: String {
        #if os(macOS)
        "Email, user ID, or leave blank for everyone"
        #else
        "Email or user ID (leave blank for all customers)"
        #endif
    }

    private var canSend: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                sendMessageFormMacOS
                #else
                Form {
                    Section {
                        TextField(recipientFieldPlaceholder, text: $recipient)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    } header: {
                        Text("Recipient")
                    } footer: {
                        Text("Leave blank to send to all customers. Enter an email or user ID to send to one person.")
                    }
                    Section {
                        TextField("Message", text: $bodyText, axis: .vertical)
                            .lineLimit(4...12)
                            .focused($bodyFocused)
                    } header: {
                        Text("Message")
                    }
                }
                .macOSGroupedFormStyle()
                .macOSEditSheetPadding()
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Send message")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Send") {
                            sendMessage()
                        }
                        .disabled(!canSend)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSend ? AppConstants.Colors.accent : Color.secondary)
                    }
                }
            }
            .onAppear { bodyFocused = true }
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var sendMessageFormMacOS: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    TextField(recipientFieldPlaceholder, text: $recipient)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .controlSize(.large)
                    Text("Leave blank to notify all signed-in customers. Enter one email or user ID to message a single person.")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppConstants.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $bodyText)
                            .font(.body)
                            .focused($bodyFocused)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 220)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        if bodyText.isEmpty {
                            Text("Write your message here…")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.9), lineWidth: 1)
                    )
                    Text("This is sent as an in-app notification to customers.")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppConstants.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }
    #endif

    private func sendMessage() {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        let rec = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let toUserId: String? = rec.isEmpty ? nil : (rec.contains("@") ? nil : rec)
        let toUserEmail: String? = rec.isEmpty ? nil : (rec.contains("@") ? rec : nil)
        Task {
            let success = await viewModel.sendAdminMessage(toUserId: toUserId, toUserEmail: toUserEmail, body: trimmed)
            isSending = false
            if success {
                onDismiss()
                dismiss()
            }
        }
    }
}

/// Detail view for a contact message; admin can reply via email or send an in-app reply.
struct ContactMessageDetailSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    let message: ContactMessage
    var onDismiss: () -> Void
    var onViewOrderFromMessage: (String) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    @State private var isSendingReply = false
    @State private var didCopyOrderId = false

    /// Steps: Received → Read → Replied. Read from readAt. Replied not derived from model (optional future).
    private var contactMessageTrackingSteps: [TrackingStepConfig] {
        let isRead = message.readAt != nil
        return [
            TrackingStepConfig(id: 0, label: "Received", isReached: true, isCurrent: !isRead),
            TrackingStepConfig(id: 1, label: "Read", isReached: isRead, isCurrent: isRead),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TrackingStatusBarView(
                        title: "Message status",
                        subtitle: nil,
                        steps: contactMessageTrackingSteps
                    )
                    if let name = message.name, !name.isEmpty {
                        detailRow("Name", name)
                    }
                    detailRow("Email", message.email)
                    if let sub = message.subject, !sub.isEmpty {
                        detailRow("Subject", sub)
                    }
                    detailRow("Message", message.message)
                    if let created = message.createdAt {
                        detailRow("Received", created.shortDateString)
                    }
                    if let orderId = message.linkedOrderId {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Linked order")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            if let short = message.orderReferenceShort {
                                Text("Reference \(short) — use this to match the customer’s picker or a short mention in email.")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                            Text(orderId)
                                .font(.body)
                                .monospaced()
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppConstants.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            HStack(spacing: 12) {
                                Button {
                                    copyOrderIdToPasteboard(orderId)
                                    didCopyOrderId = true
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        didCopyOrderId = false
                                    }
                                } label: {
                                    Label(didCopyOrderId ? "Copied" : "Copy order ID", systemImage: didCopyOrderId ? "checkmark.circle.fill" : "doc.on.doc")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(AppConstants.Colors.accent)
                                Button {
                                    onViewOrderFromMessage(orderId)
                                    onDismiss()
                                    dismiss()
                                } label: {
                                    Label("View order in Orders", systemImage: "shippingbox")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(AppConstants.Colors.accent)
                            }
                        }
                    }

                    Divider()
                    Text("Reply in app")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text("Your reply will appear in the customer’s app under Account → Messages.")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    TextEditor(text: $replyText)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(platformSystemGrayBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        Task { await sendInAppReply() }
                    } label: {
                        if isSendingReply {
                            ProgressView()
                        } else {
                            Text("Send in-app reply")
                        }
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingReply)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Contact message")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reply via email") {
                        openReplyEmail()
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .macOSReduceSheetTitleGap()
        }
    }

    private func sendInAppReply() async {
        let body = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSendingReply = true
        defer { isSendingReply = false }
        await viewModel.replyToContactMessage(messageId: message.id, body: body)
        replyText = ""
    }

    private func copyOrderIdToPasteboard(_ id: String) {
        #if os(iOS)
        UIPasteboard.general.string = id
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(id, forType: .string)
        #endif
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openReplyEmail() {
        let rawSubject = "Re: \(message.subject ?? "Your message")"
        var bodyParts: [String] = ["Reply to: \(message.email)"]
        if let oid = message.linkedOrderId {
            bodyParts.append("")
            bodyParts.append("ORDER REFERENCE (use in Admin → Orders search / filter):")
            bodyParts.append(oid)
            if let short = message.orderReferenceShort {
                bodyParts.append("Short ref: \(short)")
            }
        }
        bodyParts.append("")
        bodyParts.append("---")
        bodyParts.append(message.message)
        let rawBody = bodyParts.joined(separator: "\n")
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = message.email
        components.queryItems = [
            URLQueryItem(name: "subject", value: rawSubject),
            URLQueryItem(name: "body", value: rawBody)
        ]
        guard let url = components.url else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - Margins (profit calculator)

struct AdminMarginsView: View {
    @ObservedObject var viewModel: AdminViewModel

    private var productsWithCost: [Product] {
        viewModel.products.filter { $0.cost != nil && ($0.cost ?? 0) > 0 }
    }

    private var totalProfitIfAllSoldOnce: Double {
        productsWithCost.reduce(0) { sum, p in
            sum + ((p.price - (p.cost ?? 0)) * 1)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if productsWithCost.isEmpty {
                        VStack(spacing: 12) {
                            Text("No cost data yet")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Text("Add a cost per unit in Edit Product for each item. Margins will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        summaryCard
                        marginsList
                    }
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.bottom, 24)
                .macOSSheetTopPadding()
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Margins")
            .inlineNavigationTitle()
            .refreshable { await viewModel.loadProducts() }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("If every item sold once")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(totalProfitIfAllSoldOnce.currencyFormatted)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(totalProfitIfAllSoldOnce >= 0 ? AppConstants.Colors.accent : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var marginsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By product")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            HStack(spacing: 12) {
                Text("Product")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Spacer(minLength: 8)
                Text("Price")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(width: 48, alignment: .trailing)
                Text("Cost")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(width: 48, alignment: .trailing)
                Text("Margin")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(width: 44, alignment: .trailing)
                Text("Profit")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            ForEach(Array(productsWithCost.enumerated()), id: \.offset) { _, product in
                marginRow(product: product)
            }
        }
    }

    private func marginRow(product: Product) -> some View {
        let cost = product.cost ?? 0
        let profit = product.price - cost
        let marginPct = product.price > 0 ? (profit / product.price) * 100 : 0
        return HStack(spacing: 12) {
            Text(product.name)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(product.price.currencyFormatted)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(cost.currencyFormatted)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text(String(format: "%.0f%%", marginPct))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(marginPct >= 0 ? .green : .red)
                .frame(width: 44, alignment: .trailing)
            Text(profit.currencyFormatted)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(profit >= 0 ? AppConstants.Colors.accent : .red)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
}

struct AdminCakeGalleryView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showAdd = false
    @State private var editingItem: GalleryCakeItem?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.cakeGalleryItems.isEmpty {
                    #if os(macOS)
                    List {
                        Section {
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add gallery photo", systemImage: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        Section {
                            Text("No items yet. Add photos of treats you've made—cakes, cookies, cupcakes, etc. Customers will see them in the app.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                    }
                    #else
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Add photos of treats you've made—cakes, cookies, cupcakes, etc. Customers will see them in the app.")
                    )
                    #endif
                } else {
                    List {
                        #if os(macOS)
                        Section {
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add gallery photo", systemImage: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        #endif
                        ForEach(viewModel.cakeGalleryItems) { item in
                            AdminGalleryRow(item: item, onEdit: { editingItem = item }, onDelete: {
                                Task { await viewModel.deleteGalleryItem(id: item.id) }
                            })
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteGalleryItem(id: item.id) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Add") { showAdd = true }
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .refreshable { await viewModel.loadCakeGallery() }
            .sheet(isPresented: $showAdd) {
                AddGalleryCakeSheet(viewModel: viewModel) { showAdd = false }
                    .macOSAdminSheetSize()
            }
            .sheet(item: $editingItem) { item in
                EditGalleryCakeSheet(viewModel: viewModel, item: item) { editingItem = nil }
                    .macOSAdminSheetSize()
            }
        }
    }
}

// MARK: - Inventory

struct AdminInventoryView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var editingProduct: Product?
    @State private var showAddProduct = false

    private var inventoryProducts: [Product] {
        viewModel.products.filter { $0.id != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if inventoryProducts.isEmpty {
                    #if os(macOS)
                    List {
                        Section {
                            Button {
                                showAddProduct = true
                            } label: {
                                Label("Add product", systemImage: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        Section {
                            Text("No products. Add products in the Products tab or add one here. Then track stock and low-stock alerts.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                    }
                    #else
                    ContentUnavailableView(
                        "No products",
                        systemImage: "shippingbox",
                        description: Text("Add products in the Products tab or tap Add below. Then track stock and low-stock alerts here.")
                    )
                    #endif
                } else {
                    List {
                        #if os(macOS)
                        Section {
                            Button {
                                showAddProduct = true
                            } label: {
                                Label("Add product", systemImage: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        #endif
                        ForEach(inventoryProducts, id: \.id) { product in
                            AdminInventoryRow(product: product) {
                                editingProduct = product
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteProduct(product) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button { editingProduct = product } label: {
                                    Label("Edit inventory", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteProduct(product) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    HStack(spacing: 12) {
                        if !inventoryProducts.isEmpty {
                            Button {
                                PrintHelper.presentPrint(html: viewModel.inventoryReportHTML())
                            } label: {
                                Label("Print report", systemImage: "printer")
                            }
                            .foregroundStyle(AppConstants.Colors.accent)
                        }
                        Button("Add") {
                            showAddProduct = true
                        }
                        .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
            .refreshable { await viewModel.loadProducts() }
            .sheet(item: $editingProduct) { product in
                EditInventorySheet(viewModel: viewModel, product: product) { editingProduct = nil }
                    .macOSAdminSheetSize()
                    .macOSEditSheetPadding()
            }
            .sheet(isPresented: $showAddProduct) {
                AddProductView(viewModel: viewModel)
                    .macOSAdminSheetSizeLarge()
            }
            .overlay(alignment: .top) {
                if let msg = viewModel.errorMessage ?? viewModel.productLoadWarning {
                    ErrorMessageBanner(message: msg) { viewModel.dismissProductBanner() }
                        .padding()
                }
                if let msg = viewModel.successMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
            }
        }
    }
}

struct AdminInventoryRow: View {
    let product: Product
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                ProductImageView(urlString: product.imageURL, placeholderName: "photo")
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text(product.category)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    HStack(spacing: 8) {
                        if let q = product.stockQuantity {
                            Text("Stock: \(q)")
                                .font(.subheadline)
                                .foregroundStyle(product.isLowStock ? .orange : AppConstants.Colors.textSecondary)
                            if let t = product.lowStockThreshold {
                                Text("(alert ≤ \(t))")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        } else {
                            Text("No tracking")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                    }
                }
                Spacer()
                if product.showsAdminLowStockBadge {
                    Text("Low stock")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                if product.isSoldOutByInventory {
                    Text("Sold out")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

struct EditInventorySheet: View {
    @ObservedObject var viewModel: AdminViewModel
    let product: Product
    var onDismiss: () -> Void
    @State private var stockText: String = ""
    @State private var lowStockText: String = ""
    @State private var trackInventory: Bool = true
    @State private var markSoldOutWhenZero: Bool = true
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                editInventoryContentMacOS
                #else
                editInventoryContentForm
                #endif
            }
            .navigationTitle("Edit inventory")
            .inlineNavigationTitle()
            .onAppear {
                trackInventory = product.stockQuantity != nil
                stockText = product.stockQuantity.map { String($0) } ?? ""
                lowStockText = product.lowStockThreshold.map { String($0) } ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .macOSEditSheetPadding()
            .macOSReduceSheetTitleGap()
        }
    }

    #if os(macOS)
    private var editInventoryContentMacOS: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Update stock levels and low-stock alerts for this product.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .padding(.horizontal, 4)

                editInventoryProductCard
                editInventoryStockCard

                PrimaryButton(
                    title: "Save",
                    action: { Task { await save() } },
                    isLoading: isSaving
                )
                .padding(.top, 8)
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.secondary)
    }

    private var editInventoryProductCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            editInventorySectionLabel("Product")
            Text(product.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConstants.Colors.textPrimary)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var editInventoryStockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            editInventorySectionLabel("Stock")
            Toggle("Track inventory", isOn: $trackInventory)
            if trackInventory {
                editInventoryLabeledField("Quantity in stock", placeholder: "0", text: $stockText)
                editInventoryLabeledField("Low stock alert at", placeholder: "0", text: $lowStockText)
                Toggle("Mark sold out when quantity is 0", isOn: $markSoldOutWhenZero)
            }
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func editInventorySectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }

    private func editInventoryLabeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
    #endif

    private var editInventoryContentForm: some View {
        Form {
            Section {
                HStack {
                    Text("Product")
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    Spacer()
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                }
            }
            Section("Stock") {
                Toggle("Track inventory", isOn: $trackInventory)
                if trackInventory {
                    HStack {
                        Text("Quantity in stock")
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Spacer()
                        TextField("0", text: $stockText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            #endif
                    }
                    HStack {
                        Text("Low stock alert at")
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        Spacer()
                        TextField("0", text: $lowStockText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            #endif
                    }
                    Toggle("Mark sold out when quantity is 0", isOn: $markSoldOutWhenZero)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macOSCompactFormContent()
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var updated = product
        if trackInventory {
            let q = Int(stockText.trimmingCharacters(in: .whitespaces))
            let t = Int(lowStockText.trimmingCharacters(in: .whitespaces))
            updated.stockQuantity = q
            updated.lowStockThreshold = t
            if let qq = q, qq > 0 {
                // Restocking must clear sold-out; otherwise UI shows "Sold out" with stock > 0.
                updated.isSoldOut = false
            } else if markSoldOutWhenZero, let qq = q, qq <= 0 {
                updated.isSoldOut = true
            }
        } else {
            updated.stockQuantity = nil
            updated.lowStockThreshold = nil
        }
        let didSave = await viewModel.updateProduct(updated, newImage: nil)
        if didSave {
            onDismiss()
        }
    }
}

// MARK: - Gallery

struct AdminGalleryRow: View {
    let item: GalleryCakeItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    if let cat = item.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    if let p = item.price {
                        Text(p.currencyFormatted)
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

struct AddGalleryCakeSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    var onDismiss: () -> Void
    @State private var selectedImage: PlatformImage?
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var categoryText = ""
    @State private var priceText = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showImagePicker = false

    var body: some View {
        NavigationStack {
            Form {
                if let err = saveError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Spacer()
                            Button("Dismiss") { saveError = nil }
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                        .listRowBackground(Color.orange.opacity(0.12))
                    }
                }
                Section("Photo") {
                    if let img = selectedImage {
                        Image(platformImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Change photo") { showImagePicker = true }
                    } else {
                        Button("Choose photo") { showImagePicker = true }
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    Button("Use test image") {
                        selectedImage = Self.makeTestGalleryImage()
                        if title.trimmingCharacters(in: .whitespaces).isEmpty {
                            title = "Test gallery item"
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
                Section("Details") {
                    TextField("Title (e.g. Chocolate birthday cake)", text: $title)
                    TextField("Category (e.g. Cake, Cookie, Cupcake)", text: $categoryText)
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Price (optional)", text: $priceText)
                        #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                }
            }
            .macOSGroupedFormStyle()
            .macOSEditSheetPadding()
            .navigationTitle("Add to gallery")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(selectedImage == nil || title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear { saveError = nil }
            .macOSReduceSheetTitleGap()
        }
    }

    /// In-memory test image so you can verify gallery add (upload + save) without picking a photo.
    private static func makeTestGalleryImage() -> PlatformImage {
        #if os(iOS)
        let size = CGSize(width: 600, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.systemTeal.withAlphaComponent(0.3).setFill()
            ctx.fill(rect)
            UIColor.systemTeal.setStroke()
            ctx.cgContext.setLineWidth(4)
            ctx.stroke(rect.insetBy(dx: 4, dy: 4))
            let text = "Gallery test"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.systemTeal
            ]
            let str = text as NSString
            let textSize = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2), withAttributes: attrs)
        }
        #else
        let size = NSSize(width: 600, height: 400)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemTeal.withAlphaComponent(0.3).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.systemTeal.setStroke()
        NSBezierPath(rect: NSRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8)).lineWidth = 4
        NSBezierPath(rect: NSRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8)).stroke()
        let text = "Gallery test" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 32),
            .foregroundColor: NSColor.systemTeal
        ]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2), withAttributes: attrs)
        image.unlockFocus()
        return image
        #endif
    }

    private func save() async {
        guard let image = selectedImage else {
            await MainActor.run { saveError = "Please choose or use a test image." }
            return
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.8), !jpeg.isEmpty else {
            await MainActor.run { saveError = "Could not create image data." }
            return
        }
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else {
            await MainActor.run { saveError = "Please enter a title." }
            return
        }
        await MainActor.run { saveError = nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let path = "gallery/\(UUID().uuidString).jpg"
            // Use base64 upload for gallery so it works on serverless (multipart body can be consumed before handler).
            let urlString = try await VercelService.shared.uploadImageBase64(data: jpeg, pathname: path)
            let desc = descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : descriptionText.trimmingCharacters(in: .whitespaces)
            let category = categoryText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : categoryText.trimmingCharacters(in: .whitespaces)
            let price = Double(priceText.trimmingCharacters(in: .whitespaces))
            try await viewModel.addGalleryItem(imageUrl: urlString, title: t, description: desc, category: category, price: price)
            await MainActor.run { onDismiss() }
        } catch {
            let message = FriendlyErrorMessage.message(for: error)
            let detail = (error as? VercelAPIError)?.message ?? error.localizedDescription
            await MainActor.run {
                saveError = message == detail || detail.isEmpty ? message : "\(message) (\(detail))"
            }
        }
    }
}

struct EditGalleryCakeSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    let item: GalleryCakeItem
    var onDismiss: () -> Void
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var categoryText: String = ""
    @State private var priceText: String = ""
    @State private var selectedImage: PlatformImage?
    @State private var showImagePicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                if let err = saveError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Spacer()
                            Button("Dismiss") { saveError = nil }
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                        .listRowBackground(Color.orange.opacity(0.12))
                    }
                }
                Section("Photo") {
                    if let img = selectedImage {
                        Image(platformImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Change photo") { showImagePicker = true }
                    } else if let urlString = item.imageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay { ProgressView() }
                            }
                        }
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Replace photo") { showImagePicker = true }
                    } else {
                        Button("Add photo") { showImagePicker = true }
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Category (e.g. Cake, Cookie, Cupcake)", text: $categoryText)
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Price (optional)", text: $priceText)
                        #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                }
            }
            .macOSGroupedFormStyle()
            .macOSEditSheetPadding()
            .navigationTitle("Edit gallery item")
            .inlineNavigationTitle()
            .onAppear {
                title = item.title
                descriptionText = item.description ?? ""
                categoryText = item.category ?? ""
                priceText = item.price.map { String($0) } ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .macOSReduceSheetTitleGap()
        }
    }

    private func save() async {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else {
            await MainActor.run { saveError = "Please enter a title." }
            return
        }
        await MainActor.run { saveError = nil }
        isSaving = true
        defer { isSaving = false }
        var newImageUrl: String? = nil
        if let image = selectedImage, let jpeg = image.jpegData(compressionQuality: 0.8), !jpeg.isEmpty {
            do {
                let path = "gallery/\(UUID().uuidString).jpg"
                newImageUrl = try await VercelService.shared.uploadImageBase64(data: jpeg, pathname: path)
            } catch {
                let message = FriendlyErrorMessage.message(for: error)
                await MainActor.run { saveError = message }
                return
            }
        }
        let desc = descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : descriptionText.trimmingCharacters(in: .whitespaces)
        let category = categoryText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : categoryText.trimmingCharacters(in: .whitespaces)
        let price = Double(priceText.trimmingCharacters(in: .whitespaces))
        await viewModel.updateGalleryItem(item, imageUrl: newImageUrl, title: t, description: desc, category: category, price: price)
        await MainActor.run { onDismiss() }
    }
}

struct AdminSettingsView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var storeHours = ""
    @State private var deliveryRadiusText = ""
    @State private var taxRateText = ""
    @State private var minimumOrderLeadTimeText = ""
    @State private var deliveryFeeText = ""
    @State private var shippingFeeText = ""
    @State private var contactEmail = ""
    @State private var contactPhone = ""
    @State private var storeName = ""
    @State private var stripePublishableKeyText = ""
    @State private var stripeSecretKeyText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                settingsContentMacOS
                #else
                settingsContentForm
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .scrollContentBackground(.hidden)
            .background(AppConstants.Colors.secondary)
            .macOSConstrainedContent()
            .navigationTitle("Business Settings")
            .largeNavigationTitle()
            .macOSReduceSheetTitleGap()
            .onAppear {
                if let s = viewModel.businessSettings {
                    storeHours = s.storeHours ?? ""
                    deliveryRadiusText = s.deliveryRadiusMiles.map { String($0) } ?? ""
                    taxRateText = String(format: "%.2f", s.taxRate)
                    minimumOrderLeadTimeText = s.minimumOrderLeadTimeHours.map { String($0) } ?? ""
                    deliveryFeeText = s.deliveryFee.map { String(format: "%.2f", $0) } ?? ""
                    shippingFeeText = s.shippingFee.map { String(format: "%.2f", $0) } ?? ""
                    contactEmail = s.contactEmail ?? ""
                    contactPhone = s.contactPhone ?? ""
                    storeName = s.storeName ?? ""
                    stripePublishableKeyText = s.stripePublishableKey ?? ""
                    stripeSecretKeyText = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveSettings() }
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .overlay(alignment: .top) {
                if let msg = viewModel.successMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppConstants.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 8)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.15)
                        ProgressView("Saving…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func saveSettings() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let tax = Double(taxRateText.replacingOccurrences(of: ",", with: "")) ?? 0.08
        let radius = Double(deliveryRadiusText.replacingOccurrences(of: ",", with: ""))
        let leadTime = Int(minimumOrderLeadTimeText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
        let deliveryFee = Double(deliveryFeeText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
        let shippingFee = Double(shippingFeeText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
        let pkTrim = stripePublishableKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let secretTrim = stripeSecretKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let settings = BusinessSettings(
            storeHours: storeHours.isEmpty ? nil : storeHours,
            deliveryRadiusMiles: radius,
            taxRate: tax,
            minimumOrderLeadTimeHours: (leadTime != nil && leadTime! > 0) ? leadTime : nil,
            contactEmail: contactEmail.isEmpty ? nil : contactEmail,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            storeName: storeName.isEmpty ? nil : storeName,
            cashAppTag: viewModel.businessSettings?.cashAppTag,
            venmoUsername: viewModel.businessSettings?.venmoUsername,
            deliveryFee: (deliveryFee != nil && deliveryFee! >= 0) ? deliveryFee : 0,
            shippingFee: (shippingFee != nil && shippingFee! >= 0) ? shippingFee : 0,
            stripePublishableKey: pkTrim.isEmpty ? nil : pkTrim,
            stripeCheckoutEnabled: viewModel.businessSettings?.stripeCheckoutEnabled ?? false,
            stripeSecretKeyConfigured: viewModel.businessSettings?.stripeSecretKeyConfigured ?? false
        )
        await viewModel.saveBusinessSettings(settings, newStripeSecretKey: secretTrim.isEmpty ? nil : secretTrim)
        stripeSecretKeyText = ""
    }

    private var stripeKeyInstructions: String {
        """
        Where to find your keys:
        1. Log in at dashboard.stripe.com
        2. Turn off “Test mode” (toggle top right) for live keys, or leave Test mode on for test keys.
        3. Go to Developers → API keys.
        4. Copy “Publishable key” (pk_…) into Publishable key above.
        5. Click “Reveal live key” (or “Reveal test key”) under “Secret key” and copy sk_… into Secret key above.

        After you Save, customers can pay with a card in the app when both keys are set (or secret is in Vercel env + publishable key is saved here or in AppConstants).
        """
    }

    #if os(macOS)
    private var settingsContentMacOS: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Store details and contact info are used across the app and at checkout. Payments are handled by Stripe.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .padding(.horizontal, 4)

                settingsStoreCard
                settingsDeliveryTaxCard
                settingsContactCard
                settingsStripeCard

                PrimaryButton(
                    title: "Save",
                    action: { Task { await saveSettings() } }
                )
                .disabled(isSaving)
                .padding(.top, 8)

                if let at = viewModel.businessSettings?.settingsLastUpdatedAt, !at.isEmpty {
                    Text("Settings audit — last saved: \(at)")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                if let uid = viewModel.businessSettings?.settingsLastUpdatedByUserId, !uid.isEmpty {
                    Text("Saved by user id: \(uid)")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
    }

    private var settingsStoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionLabel("Store information")
            settingsLabeledField("Store name", placeholder: "Guilty Pleasure Treats", text: $storeName)
            settingsLabeledField("Business hours", placeholder: "e.g. 9am–5pm", text: $storeHours)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var settingsDeliveryTaxCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionLabel("Delivery & tax")
            settingsLabeledField("Delivery radius (mi)", placeholder: "0", text: $deliveryRadiusText)
            settingsLabeledField("Delivery fee ($)", placeholder: "0", text: $deliveryFeeText)
            settingsLabeledField("Shipping fee ($)", placeholder: "0", text: $shippingFeeText)
            settingsLabeledField("Tax rate", placeholder: "0.08", text: $taxRateText)
            settingsLabeledField("Minimum order notice (hours)", placeholder: "24", text: $minimumOrderLeadTimeText)
            Text("Delivery/shipping fees in dollars. Applied at checkout when customer chooses Delivery or Shipping.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Tax rate as decimal (e.g. 0.08 for 8%). Applied at checkout.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Check your state sales tax rate to use the correct percentage.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var settingsContactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionLabel("Contact information")
            settingsLabeledField("Email", placeholder: "contact@example.com", text: $contactEmail)
                .textContentType(.emailAddress)
            settingsLabeledField("Phone", placeholder: "(555) 123-4567", text: $contactPhone)
                .textContentType(.telephoneNumber)
            Text("Shown to customers for support and order questions.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var settingsStripeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionLabel("Stripe checkout (live or test)")
            Text(stripeKeyInstructions)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            settingsSecureField("Publishable key (pk_live_… or pk_test_…)", placeholder: "pk_live_…", text: $stripePublishableKeyText)
            settingsSecureField("Secret key (sk_live_… or sk_test_…)", placeholder: viewModel.businessSettings?.stripeSecretKeyConfigured == true ? "••••••• (enter new key to replace)" : "sk_live_…", text: $stripeSecretKeyText)
            if viewModel.businessSettings?.stripeSecretKeyConfigured == true {
                Text("Secret key is saved on the server. Leave the secret field empty to keep it; enter a new key only to replace it.")
                    .font(.caption2)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Text("Optional: you can also set STRIPE_SECRET_KEY in the Vercel project environment instead of saving the secret here.")
                .font(.caption2)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func settingsSecureField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func settingsSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }

    private func settingsLabeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
    #endif

    private var settingsContentForm: some View {
        Form {
            Section {
                Text("Store details and contact info are used across the app and at checkout. Payments are handled by Stripe.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            }

            Section {
                LabeledContent("Store name") {
                    TextField("Guilty Pleasure Treats", text: $storeName)
                        #if os(iOS)
                        .multilineTextAlignment(.trailing)
                        #endif
                        .submitLabel(.next)
                }
                LabeledContent("Business hours") {
                    TextField("e.g. 9am–5pm", text: $storeHours)
                        #if os(iOS)
                        .multilineTextAlignment(.trailing)
                        #endif
                        .submitLabel(.next)
                }
            } header: {
                Text("Store information")
            }

            Section {
                LabeledContent("Delivery radius (mi)") {
                    TextField("0", text: $deliveryRadiusText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                }
                LabeledContent("Delivery fee ($)") {
                    TextField("0", text: $deliveryFeeText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                }
                LabeledContent("Shipping fee ($)") {
                    TextField("0", text: $shippingFeeText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                }
                LabeledContent("Tax rate") {
                    TextField("0.08", text: $taxRateText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                }
                LabeledContent("Minimum order notice (hours)") {
                    TextField("24", text: $minimumOrderLeadTimeText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                }
            } header: {
                Text("Delivery & tax")
            } footer: {
                Text("Delivery and shipping fees in dollars; applied at checkout when customer chooses Delivery or Shipping. Tax rate as decimal (e.g. 0.08 for 8%). Minimum order notice: customers cannot select a pickup/delivery time sooner than this many hours from now.")
            }

            Section {
                LabeledContent("Email") {
                    TextField("contact@example.com", text: $contactEmail)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .multilineTextAlignment(.trailing)
                        #endif
                        .textContentType(.emailAddress)
                }
                LabeledContent("Phone") {
                    TextField("(555) 123-4567", text: $contactPhone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                        #endif
                        .textContentType(.telephoneNumber)
                }
            } header: {
                Text("Contact information")
            } footer: {
                Text("Shown to customers for support and order questions.")
            }

            Section {
                Text(stripeKeyInstructions)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .listRowBackground(Color.clear)
                LabeledContent("Publishable key") {
                    SecureField("pk_live_… or pk_test_…", text: $stripePublishableKeyText)
                        #if os(iOS)
                        .multilineTextAlignment(.trailing)
                        #endif
                }
                LabeledContent("Secret key") {
                    SecureField(
                        viewModel.businessSettings?.stripeSecretKeyConfigured == true ? "Enter new sk_… to replace" : "sk_live_… or sk_test_…",
                        text: $stripeSecretKeyText
                    )
                    #if os(iOS)
                    .multilineTextAlignment(.trailing)
                    #endif
                }
                if viewModel.businessSettings?.stripeSecretKeyConfigured == true {
                    Text("Secret key is saved. Leave blank to keep it.")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                Text("Optional: set STRIPE_SECRET_KEY in Vercel instead of saving the secret here.")
                    .font(.caption2)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            } header: {
                Text("Stripe checkout")
            } footer: {
                Text("Keys are from Stripe Dashboard → Developers → API keys. Use live keys for real charges; test keys for testing.")
            }

            Section {
                if let at = viewModel.businessSettings?.settingsLastUpdatedAt, !at.isEmpty {
                    LabeledContent("Last saved (server)") {
                        Text(at)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                } else {
                    Text("Timestamps appear after the next save (server records who saved).")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                if let uid = viewModel.businessSettings?.settingsLastUpdatedByUserId, !uid.isEmpty {
                    LabeledContent("Saved by user id") {
                        Text(uid)
                            .font(.caption2)
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("Settings audit")
            } footer: {
                Text("Updated automatically each time an admin saves business settings.")
            }
        }
    }
}

#if os(iOS)
/// Simple image picker using UIImagePickerController.
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: PlatformImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#else
/// Mac: file-based image picker using NSOpenPanel.
struct ImagePicker: View {
    @Binding var image: PlatformImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose an image")
                .font(.headline)
            Button("Select image file...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                    image = NSImage(data: data)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel") { dismiss() }
        }
        .padding()
        .frame(minWidth: 280, minHeight: 120)
    }
}
#endif

#if os(iOS)
/// Picks a photo or PDF for event attachment. Returns file data and content type.
struct EventDocumentPicker: UIViewControllerRepresentable {
    @Binding var pickedData: Data?
    @Binding var pickedContentType: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: EventDocumentPicker
        init(_ parent: EventDocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { parent.dismiss(); return }
            guard url.startAccessingSecurityScopedResource() else {
                parent.dismiss()
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                let contentType: String
                if url.pathExtension.lowercased() == "pdf" {
                    contentType = "application/pdf"
                } else if url.pathExtension.lowercased() == "png" {
                    contentType = "image/png"
                } else {
                    contentType = "image/jpeg"
                }
                parent.pickedData = data
                parent.pickedContentType = contentType
            }
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
#else
/// Mac: pick a photo or PDF file for event attachment.
struct EventDocumentPicker: View {
    @Binding var pickedData: Data?
    @Binding var pickedContentType: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose photo or PDF")
                .font(.headline)
            Button("Select file...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .pdf]
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                    pickedData = data
                    pickedContentType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel") { dismiss() }
        }
        .padding()
        .frame(minWidth: 280, minHeight: 120)
    }
}
#endif

