//
//  AdminView.swift
//  Guilty Pleasure Treats
//
//  Hidden admin: products (add/edit/sold out), orders. Access via 5-tap on logo.
//

import SwiftUI

struct AdminView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AdminProductsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Products")
                }
                .tag(0)
            AdminOrdersView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Orders")
                }
                .tag(1)
        }
        .onAppear {
            Task {
                await viewModel.loadProducts()
                await viewModel.loadOrders()
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
                ForEach(viewModel.products, id: \.id) { product in
                    AdminProductRow(
                        product: product,
                        onEdit: { viewModel.editingProduct = product },
                        onToggleSoldOut: { viewModel.setSoldOut(product: product, soldOut: !product.isSoldOut) }
                    )
                }
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        showAddProduct = true
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showAddProduct) {
                AddProductView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.editingProduct) { product in
                EditProductView(product: product, viewModel: viewModel)
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

struct AdminProductRow: View {
    let product: Product
    let onEdit: () -> Void
    let onToggleSoldOut: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                Text(product.price.currencyFormatted)
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Spacer()
            if product.isSoldOut {
                Text("Sold Out")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("Edit", action: onEdit)
                .foregroundStyle(AppConstants.Colors.accent)
            Button(product.isSoldOut ? "Available" : "Sold Out", action: onToggleSoldOut)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct AddProductView: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var category = ProductCategory.cupcakes.rawValue
    @State private var isFeatured = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Price", text: $priceText)
                    .keyboardType(.decimalPad)
                Picker("Category", selection: $category) {
                    ForEach(ProductCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat.rawValue)
                    }
                }
                Toggle("Featured", isOn: $isFeatured)
                Button(selectedImage == nil ? "Add photo" : "Change photo") {
                    showImagePicker = true
                }
                if selectedImage != nil {
                    Image(uiImage: selectedImage!)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                }
            }
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                            await viewModel.addProduct(
                                name: name,
                                description: description,
                                price: price,
                                category: category,
                                isFeatured: isFeatured,
                                image: selectedImage
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || priceText.isEmpty)
                }
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
    @State private var category: String
    @State private var isFeatured: Bool
    @State private var isSoldOut: Bool
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    init(product: Product, viewModel: AdminViewModel) {
        self.product = product
        self.viewModel = viewModel
        _name = State(initialValue: product.name)
        _description = State(initialValue: product.productDescription)
        _priceText = State(initialValue: String(format: "%.2f", product.price))
        _category = State(initialValue: product.category)
        _isFeatured = State(initialValue: product.isFeatured)
        _isSoldOut = State(initialValue: product.isSoldOut)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Price", text: $priceText)
                    .keyboardType(.decimalPad)
                Picker("Category", selection: $category) {
                    ForEach(ProductCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat.rawValue)
                    }
                }
                Toggle("Featured", isOn: $isFeatured)
                Toggle("Sold out", isOn: $isSoldOut)
                Button(selectedImage == nil ? "Change photo" : "Change photo") {
                    showImagePicker = true
                }
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                }
            }
            .navigationTitle("Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.editingProduct = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            var updated = product
                            updated.name = name
                            updated.productDescription = description
                            updated.price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? product.price
                            updated.category = category
                            updated.isFeatured = isFeatured
                            updated.isSoldOut = isSoldOut
                            await viewModel.updateProduct(updated, newImage: selectedImage)
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
}

struct AdminOrdersView: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.orders) { order in
                    OrderRowView(order: order, isAdmin: true) { updatedOrder, newStatus in
                        Task {
                            await viewModel.updateOrderStatus(order: updatedOrder, status: newStatus)
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .refreshable {
                await viewModel.loadOrders()
            }
        }
    }
}

/// Simple image picker using UIImagePickerController.
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
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

