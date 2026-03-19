//
//  AdminViewModel.swift
//  Guilty Pleasure Treats
//
//  Admin: products, orders, customers, special orders, promos, analytics, settings.
//

import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Combine

/// Time period for analytics filtering.
enum AnalyticsPeriod: String, CaseIterable {
    case allTime = "All time"
    case thisMonth = "This month"
    case thisWeek = "This week"

    func filter(_ orders: [Order], calendar: Calendar) -> [Order] {
        let now = Date()
        let (start, end) = dateRange(relativeTo: now, calendar: calendar)
        return orders.filter { o in
            guard let d = o.createdAt else { return false }
            return d >= start && d < end
        }
    }

    func dateRange(relativeTo now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: now).addingTimeInterval(86400)
        switch self {
        case .allTime:
            return (Date.distantPast, end)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (start, end)
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: now)
            let firstWeekday = calendar.firstWeekday
            var daysFromStart = (weekday - firstWeekday + 7) % 7
            if daysFromStart == 0 && weekday != firstWeekday { daysFromStart = 7 }
            let start = calendar.date(byAdding: .day, value: -daysFromStart, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)
        }
    }

    func previousDateRange(relativeTo now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let (start, end) = dateRange(relativeTo: now, calendar: calendar)
        let length = end.timeIntervalSince(start)
        let prevEnd = start
        let prevStart = prevEnd.addingTimeInterval(-length)
        return (prevStart, prevEnd)
    }
}

/// Customer summary for admin (derived from orders).
struct AdminCustomer: Identifiable {
    var id: String { key }
    let key: String
    let displayName: String
    let phone: String
    let orderCount: Int
    let totalSpent: Double
    let orders: [Order]
}

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var orders: [Order] = []
    @Published var businessSettings: BusinessSettings?
    @Published var promotions: [Promotion] = []
    @Published var customCakeOrders: [CustomCakeOrder] = []
    @Published var aiCakeDesignOrders: [AICakeDesignOrder] = []
    @Published var customCakeOptions: CustomCakeOptionsResponse?
    @Published var contactMessages: [ContactMessage] = []
    @Published var cakeGalleryItems: [GalleryCakeItem] = []
    @Published var productCategories: [ProductCategoryItem] = []
    @Published var savedCustomers: [SavedCustomer] = []
    @Published var totalCustomerCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var editingProduct: Product?
    @Published var newProductImage: PlatformImage?

    /// When set, Messages tab should select and show this contact message (e.g. from push tap). Cleared after applying.
    @Published var scrollToMessageId: String?

    /// When non-nil, show payment link sheet (URL to copy/share). When error is set, show error in same sheet.
    @Published var paymentLinkURL: URL?
    @Published var paymentLinkError: String?

    /// CSV data from export orders (Admin → Export). Cleared with clearOrdersExport().
    @Published var ordersExportData: Data?

    /// Business hours / lead time / min order / tax from GET /api/settings/business-hours.
    @Published var businessHoursSettings: BusinessHoursSettings?

    private let api = VercelService.shared

    /// Products that are low in stock (stock ≤ threshold) and not sold out. Used for in-app banner and local notification.
    var lowStockProducts: [Product] {
        products.filter { $0.isLowStock && !$0.isSoldOut }
    }

    var customers: [AdminCustomer] {
        let grouped = Dictionary(grouping: orders) { o in
            let uid = o.userId ?? ""
            let name = o.customerName.trimmingCharacters(in: .whitespaces)
            let phone = o.customerPhone.trimmingCharacters(in: .whitespaces)
            if !uid.isEmpty { return "u:\(uid)" }
            return "p:\(name)|\(phone)"
        }
        return grouped.map { key, orderList in
            let o = orderList.first!
            let total = orderList.filter { $0.statusEnum != .cancelled }.reduce(0.0) { $0 + $1.total }
            return AdminCustomer(
                key: key,
                displayName: o.customerName,
                phone: o.customerPhone,
                orderCount: orderList.count,
                totalSpent: total,
                orders: orderList.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            )
        }.sorted { $0.orderCount > $1.orderCount }
    }
    
    var totalRevenue: Double {
        orders.filter { $0.statusEnum != .cancelled }.reduce(0.0) { $0 + $1.total }
    }
    
    var completedOrderCount: Int {
        orders.filter { $0.statusEnum != .cancelled }.count
    }
    
    var ordersByDay: [(date: Date, count: Int, revenue: Double)] {
        ordersByDay(for: .allTime)
    }

    // MARK: - Analytics (period-filtered)

    /// Orders that are not cancelled, filtered by period.
    func completedOrders(in period: AnalyticsPeriod) -> [Order] {
        let list = orders.filter { $0.statusEnum != .cancelled }
        return period.filter(list, calendar: .current)
    }

    /// Count of orders still in pipeline (Pending, Confirmed, Preparing, Ready).
    var pendingOrderCount: Int {
        orders.filter { o in
            guard let s = o.statusEnum else { return false }
            return s != .cancelled && s != .completed
        }.count
    }

    func totalRevenue(for period: AnalyticsPeriod) -> Double {
        completedOrders(in: period).reduce(0.0) { $0 + $1.total }
    }

    func completedOrderCount(for period: AnalyticsPeriod) -> Int {
        completedOrders(in: period).count
    }

    func ordersByDay(for period: AnalyticsPeriod) -> [(date: Date, count: Int, revenue: Double)] {
        let calendar = Calendar.current
        let list = completedOrders(in: period)
        let grouped = Dictionary(grouping: list) { calendar.startOfDay(for: $0.createdAt ?? Date()) }
        return grouped.map { date, orders in
            (date: date, count: orders.count, revenue: orders.reduce(0.0) { $0 + $1.total })
        }.sorted { $0.date > $1.date }
    }

    /// Average order value for the period; 0 if no orders.
    func averageOrderValue(for period: AnalyticsPeriod) -> Double {
        let count = completedOrderCount(for: period)
        guard count > 0 else { return 0 }
        return totalRevenue(for: period) / Double(count)
    }

    /// (this period revenue, previous period revenue) for trend. Previous is same-length period before.
    func revenueComparison(for period: AnalyticsPeriod) -> (current: Double, previous: Double)? {
        let calendar = Calendar.current
        let now = Date()
        _ = period.dateRange(relativeTo: now, calendar: calendar)
        let (prevStart, prevEnd) = period.previousDateRange(relativeTo: now, calendar: calendar)
        let current = completedOrders(in: period).reduce(0.0) { $0 + $1.total }
        let prevOrders = orders.filter { o in
            guard o.statusEnum != .cancelled, let d = o.createdAt else { return false }
            return d >= prevStart && d < prevEnd
        }
        let previous = prevOrders.reduce(0.0) { $0 + $1.total }
        return (current, previous)
    }

    /// Fulfillment type and count for the period.
    func fulfillmentMix(for period: AnalyticsPeriod) -> [(type: String, count: Int)] {
        let list = completedOrders(in: period)
        let grouped = Dictionary(grouping: list) { $0.fulfillmentType }
        return grouped.map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Top items by quantity sold in the period. (name, quantity, revenue)
    func bestSellers(for period: AnalyticsPeriod, limit: Int = 10) -> [(name: String, quantity: Int, revenue: Double)] {
        let list = completedOrders(in: period)
        var byName: [String: (quantity: Int, revenue: Double)] = [:]
        for order in list {
            for item in order.items {
                let name = item.name.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                var cur = byName[name] ?? (0, 0.0)
                cur.quantity += item.quantity
                cur.revenue += item.subtotal
                byName[name] = cur
            }
        }
        return byName.map { (name: $0.key, quantity: $0.value.quantity, revenue: $0.value.revenue) }
            .sorted { $0.quantity > $1.quantity }
            .prefix(limit)
            .map { (name: $0.name, quantity: $0.quantity, revenue: $0.revenue) }
    }

    /// HTML string for the financial report (printable). Uses current period data. Uses business store name from settings when set.
    func financialReportHTML(period: AnalyticsPeriod) -> String {
        let calendar = Calendar.current
        let now = Date()
        let (start, end) = period.dateRange(relativeTo: now, calendar: calendar)
        let storeName = (businessSettings?.storeName?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "Guilty Pleasure Treats"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let periodStartStr = dateFormatter.string(from: start)
        let periodEndStr = dateFormatter.string(from: end)
        let revenue = totalRevenue(for: period)
        let orderCount = completedOrderCount(for: period)
        let aov = averageOrderValue(for: period)
        let byDay = ordersByDay(for: period).prefix(31)
        let mix = fulfillmentMix(for: period)
        let sellers = bestSellers(for: period, limit: 15)
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = Locale.current
        func fmt(_ n: Double) -> String { currencyFormatter.string(from: NSNumber(value: n)) ?? "$0.00" }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }
        var dayRows = ""
        for day in byDay {
            let dayStr = dateFormatter.string(from: day.date)
            dayRows += "<tr><td>\(esc(dayStr))</td><td>\(day.count)</td><td>\(fmt(day.revenue))</td></tr>"
        }
        var mixRows = ""
        for item in mix {
            mixRows += "<tr><td>\(esc(item.type))</td><td>\(item.count)</td></tr>"
        }
        var sellerRows = ""
        for (idx, item) in sellers.enumerated() {
            sellerRows += "<tr><td>\(idx + 1)</td><td>\(esc(item.name))</td><td>\(item.quantity)</td><td>\(fmt(item.revenue))</td></tr>"
        }
        let trendLine: String
        if let comp = revenueComparison(for: period), comp.previous > 0 {
            let pct = ((comp.current - comp.previous) / comp.previous) * 100
            trendLine = "<p><strong>Revenue vs previous period:</strong> \(String(format: "%+.0f", pct))%</p>"
        } else {
            trendLine = ""
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Financial Report – Guilty Pleasure Treats</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; color: #333; }
        h1 { font-size: 22px; margin-bottom: 4px; }
        .period { color: #666; font-size: 14px; margin-bottom: 20px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
        th { background: #f5f5f5; }
        .section { margin-top: 24px; }
        .section h2 { font-size: 16px; margin-bottom: 8px; }
        .summary p { margin: 6px 0; }
        </style>
        </head>
        <body>
        <h1>Financial Report</h1>
        <p class="period">\(esc(storeName)) · Period: \(esc(period.rawValue)) · \(esc(periodStartStr)) – \(esc(periodEndStr))</p>
        <p class="period">Generated \(esc(dateFormatter.string(from: now)))</p>
        <div class="section summary">
        <h2>Summary</h2>
        <p><strong>Total revenue:</strong> \(fmt(revenue))</p>
        <p><strong>Orders completed:</strong> \(orderCount)</p>
        <p><strong>Average order value:</strong> \(fmt(aov))</p>
        \(trendLine)
        </div>
        <div class="section">
        <h2>Revenue by day</h2>
        <table><thead><tr><th>Date</th><th>Orders</th><th>Revenue</th></tr></thead><tbody>\(dayRows)</tbody></table>
        </div>
        <div class="section">
        <h2>Fulfillment mix</h2>
        <table><thead><tr><th>Type</th><th>Orders</th></tr></thead><tbody>\(mixRows)</tbody></table>
        </div>
        <div class="section">
        <h2>Best sellers</h2>
        <table><thead><tr><th>#</th><th>Item</th><th>Qty</th><th>Revenue</th></tr></thead><tbody>\(sellerRows)</tbody></table>
        </div>
        </body>
        </html>
        """
    }

    /// HTML string for the inventory report (printable). Lists all products with stock info. Uses business store name from settings when set.
    func inventoryReportHTML() -> String {
        let storeName = (businessSettings?.storeName?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "Guilty Pleasure Treats"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let now = Date()
        let list = products.filter { $0.id != nil }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }
        var rows = ""
        for p in list {
            let stockStr: String
            if let q = p.stockQuantity {
                stockStr = "\(q)"
            } else {
                stockStr = "—"
            }
            let thresholdStr: String
            if let t = p.lowStockThreshold {
                thresholdStr = "\(t)"
            } else {
                thresholdStr = "—"
            }
            let status: String
            if p.isSoldOut {
                status = "Sold out"
            } else if p.isLowStock {
                status = "Low stock"
            } else if p.stockQuantity != nil {
                status = "OK"
            } else {
                status = "No tracking"
            }
            rows += "<tr><td>\(esc(p.name))</td><td>\(esc(p.category))</td><td>\(esc(stockStr))</td><td>\(esc(thresholdStr))</td><td>\(esc(status))</td></tr>"
        }
        let lowCount = list.filter { $0.isLowStock && !$0.isSoldOut }.count
        let soldOutCount = list.filter(\.isSoldOut).count
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Inventory Report – Guilty Pleasure Treats</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; color: #333; }
        h1 { font-size: 22px; margin-bottom: 4px; }
        .meta { color: #666; font-size: 14px; margin-bottom: 20px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
        th { background: #f5f5f5; }
        .summary p { margin: 6px 0; }
        </style>
        </head>
        <body>
        <h1>Inventory Report</h1>
        <p class="meta">\(esc(storeName)) · Generated \(esc(dateFormatter.string(from: now)))</p>
        <div class="summary">
        <p><strong>Total products:</strong> \(list.count) · <strong>Low stock:</strong> \(lowCount) · <strong>Sold out:</strong> \(soldOutCount)</p>
        </div>
        <table>
        <thead><tr><th>Product</th><th>Category</th><th>Stock</th><th>Low-stock alert at</th><th>Status</th></tr></thead>
        <tbody>\(rows)</tbody>
        </table>
        </body>
        </html>
        """
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await api.fetchProducts()
            if products.isEmpty {
                products = Self.sampleProductsForDisplay()
            }
        } catch {
            products = Self.sampleProductsForDisplay()
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
        isLoading = false
        if AuthService.shared.userProfile?.isAdmin == true, !lowStockProducts.isEmpty {
            NotificationService.shared.scheduleLowStockNotification(
                count: lowStockProducts.count,
                firstProductName: lowStockProducts.first?.name
            )
        }
    }

    /// Same sample products as the menu fallback, so Admin Products matches what customers see when API is empty or fails.
    private static func sampleProductsForDisplay() -> [Product] {
        SampleDataService.sampleProducts.enumerated().map { index, p in
            var product = p
            product.id = "sample-\(index)"
            return product
        }
    }

    func loadProductCategories() async {
        do {
            productCategories = try await api.fetchProductCategories()
        } catch {
            productCategories = ProductCategory.allCases.map { ProductCategoryItem(id: "default-\($0.rawValue)", name: $0.rawValue, displayOrder: 0) }
        }
    }

    func addCategory(name: String, displayOrder: Int = 0) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let item = try await api.addProductCategory(name: trimmed, displayOrder: displayOrder)
            productCategories.append(item)
            productCategories.sort { $0.displayOrder < $1.displayOrder }
            successMessage = "Category added."
            await loadProductCategories()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func updateCategory(_ item: ProductCategoryItem, name: String? = nil, displayOrder: Int? = nil) async {
        guard let n = name?.trimmingCharacters(in: .whitespaces), !n.isEmpty else { return }
        do {
            try await api.updateProductCategory(id: item.id, name: n, displayOrder: displayOrder ?? item.displayOrder)
            successMessage = "Category updated."
            await loadProductCategories()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func deleteCategory(_ item: ProductCategoryItem) async {
        do {
            try await api.deleteProductCategory(id: item.id)
            productCategories.removeAll { $0.id == item.id }
            successMessage = "Category removed."
            await loadProductCategories()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    /// Category names for product picker (admin add/edit product). Uses API list or fallback to built-in.
    var productCategoryNames: [String] {
        if productCategories.isEmpty {
            return ProductCategory.allCases.map(\.rawValue)
        }
        return productCategories.sorted { $0.displayOrder < $1.displayOrder }.map(\.name)
    }

    func loadSavedCustomers() async {
        do {
            savedCustomers = try await api.fetchSavedCustomers()
        } catch {
            savedCustomers = []
        }
    }

    func addSavedCustomer(name: String, phone: String, email: String?, street: String?, addressLine2: String?, city: String?, state: String?, postalCode: String?, notes: String?) async {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        do {
            let item = try await api.addSavedCustomer(
                name: n,
                phone: phone.trimmingCharacters(in: .whitespaces),
                email: email?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : email,
                street: street?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : street?.trimmingCharacters(in: .whitespaces),
                addressLine2: addressLine2?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : addressLine2?.trimmingCharacters(in: .whitespaces),
                city: city?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : city?.trimmingCharacters(in: .whitespaces),
                state: state?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : state?.trimmingCharacters(in: .whitespaces),
                postalCode: postalCode?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : postalCode?.trimmingCharacters(in: .whitespaces),
                notes: notes?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : notes
            )
            savedCustomers.append(item)
            savedCustomers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            successMessage = "Customer added."
            await loadSavedCustomers()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func updateSavedCustomer(_ item: SavedCustomer, name: String?, phone: String?, email: String?, street: String?, addressLine2: String?, city: String?, state: String?, postalCode: String?, notes: String?) async {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
        do {
            try await api.updateSavedCustomer(
                id: item.id,
                name: name,
                phone: phone?.trimmingCharacters(in: .whitespaces),
                email: email?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : email,
                street: street?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : street?.trimmingCharacters(in: .whitespaces),
                addressLine2: addressLine2?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : addressLine2?.trimmingCharacters(in: .whitespaces),
                city: city?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : city?.trimmingCharacters(in: .whitespaces),
                state: state?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : state?.trimmingCharacters(in: .whitespaces),
                postalCode: postalCode?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : postalCode?.trimmingCharacters(in: .whitespaces),
                notes: notes?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : notes
            )
            successMessage = "Customer updated."
            await loadSavedCustomers()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func deleteSavedCustomer(_ item: SavedCustomer) async {
        do {
            try await api.deleteSavedCustomer(id: item.id)
            savedCustomers.removeAll { $0.id == item.id }
            successMessage = "Customer removed."
            await loadSavedCustomers()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func loadOrders() async {
        do {
            orders = try await api.fetchAllOrders()
            if let first = orders.first, let id = first.id, let createdAt = first.createdAt {
                NotificationService.shared.addNewOrderInAppIfNeeded(
                    orderId: id,
                    customerName: first.customerName,
                    total: first.total,
                    orderCreatedAt: createdAt
                )
            }
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func addProduct(name: String, description: String, price: Double, cost: Double? = nil, category: String, isFeatured: Bool, isVegetarian: Bool = false, image: PlatformImage?, stockQuantity: Int? = nil, lowStockThreshold: Int? = nil) async {
        let product = Product(
            name: name,
            productDescription: description,
            price: price,
            cost: cost,
            imageURL: nil,
            category: category,
            isFeatured: isFeatured,
            isSoldOut: false,
            isVegetarian: isVegetarian,
            stockQuantity: stockQuantity,
            lowStockThreshold: lowStockThreshold
        )
        do {
            let id = try await api.addProduct(product)
            if let image = image, let jpeg = image.jpegData(compressionQuality: 0.7) {
                let url = try await api.uploadProductImage(data: jpeg, productId: id)
                var updated = product
                updated.id = id
                updated.imageURL = url
                try await api.updateProduct(updated)
            }
            successMessage = "Product added."
            await loadProducts()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func updateProduct(_ product: Product, newImage: PlatformImage?) async {
        if product.id?.hasPrefix("sample-") == true {
            if let idx = products.firstIndex(where: { $0.id == product.id }) {
                var updated = product
                if newImage != nil { updated.updatedAt = Date() }
                products[idx] = updated
                successMessage = "Inventory updated (demo)."
            }
            editingProduct = nil
            return
        }
        do {
            if let img = newImage, let id = product.id, let jpeg = img.jpegData(compressionQuality: 0.7) {
                let url = try await api.uploadProductImage(data: jpeg, productId: id)
                var updated = product
                updated.imageURL = url
                updated.updatedAt = Date()
                try await api.updateProduct(updated)
            } else {
                try await api.updateProduct(product)
            }
            successMessage = "Product updated."
            await loadProducts()
            editingProduct = nil
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func deleteProduct(_ product: Product) async {
        guard let id = product.id else { return }
        if id.hasPrefix("sample-") {
            products.removeAll { $0.id == id }
            if editingProduct?.id == id { editingProduct = nil }
            successMessage = "Removed from inventory (demo)."
            return
        }
        do {
            try await api.deleteProduct(id: id)
            if editingProduct?.id == id { editingProduct = nil }
            successMessage = "Product removed."
            await loadProducts()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func setSoldOut(product: Product, soldOut: Bool) async {
        var updated = product
        updated.isSoldOut = soldOut
        do {
            try await api.updateProduct(updated)
            successMessage = soldOut ? "Marked sold out." : "Marked available."
            await loadProducts()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func updateOrderStatus(order: Order, status: OrderStatus) async {
        guard let orderId = order.id else { return }
        do {
            try await api.updateOrderStatus(orderId: orderId, status: status)
            if status == .completed, let uid = order.userId, !uid.isEmpty {
                let pointsToAdd = Int(order.total)
                if pointsToAdd > 0 {
                    try? await api.addPoints(uid: uid, points: pointsToAdd)
                }
            }
            successMessage = "Order updated."
            await loadOrders()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func markOrderAsPaid(orderId: String) async {
        do {
            try await api.updateOrderManualPaid(orderId: orderId)
            successMessage = "Marked as paid."
            await loadOrders()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func createPaymentLink(for orderId: String) async {
        paymentLinkURL = nil
        paymentLinkError = nil
        do {
            let url = try await api.createPaymentLink(orderId: orderId)
            paymentLinkURL = url
        } catch {
            paymentLinkError = error.localizedDescription
        }
    }

    func clearPaymentLink() {
        paymentLinkURL = nil
        paymentLinkError = nil
    }

    func exportOrdersCSV(from: Date, to: Date) async {
        ordersExportData = nil
        do {
            ordersExportData = try await api.exportOrdersCSV(from: from, to: to)
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func clearOrdersExport() {
        ordersExportData = nil
    }

    func loadBusinessHours() async {
        do {
            businessHoursSettings = try await api.fetchBusinessHours()
        } catch {
            businessHoursSettings = nil
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func updateBusinessHours(leadTimeHours: Int?, businessHours: [String: String?]?, minOrderCents: Int?, taxRatePercent: Double?) async {
        do {
            try await api.updateBusinessHours(leadTimeHours: leadTimeHours, businessHours: businessHours, minOrderCents: minOrderCents, taxRatePercent: taxRatePercent)
            await loadBusinessHours()
            successMessage = "Business hours saved."
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func createManualOrder(_ order: Order) async {
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await api.createOrder(order)
            successMessage = "Order added."
            await loadOrders()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func clearScrollToMessageId() {
        scrollToMessageId = nil
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func loadContactMessages() async {
        do {
            contactMessages = try await api.fetchContactMessages()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func markContactMessageRead(_ message: ContactMessage) async {
        do {
            try await api.markContactMessageRead(id: message.id)
            await loadContactMessages()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    /// Send an in-app reply to a contact message (customer will see it in app).
    func replyToContactMessage(messageId: String, body: String) async {
        do {
            try await api.replyToContactMessage(messageId: messageId, body: body)
            successMessage = "Reply sent. Customer will see it in the app."
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func loadBusinessSettings() async {
        do {
            businessSettings = try await api.fetchBusinessSettings() ?? BusinessSettings()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    /// Load analytics summary (e.g. total customer accounts). Call from Analytics tab.
    func loadAnalyticsSummary() async {
        do {
            totalCustomerCount = try await api.fetchAnalyticsSummary()
        } catch {
            totalCustomerCount = 0
        }
    }
    
    func saveBusinessSettings(_ settings: BusinessSettings) async {
        do {
            try await api.setBusinessSettings(settings)
            businessSettings = settings
            successMessage = "Settings saved."
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func loadPromotions() async {
        do {
            promotions = try await api.fetchPromotions()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func addPromotion(_ promotion: Promotion) async {
        do {
            _ = try await api.addPromotion(promotion)
            successMessage = "Promotion added."
            await loadPromotions()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func updatePromotion(_ promotion: Promotion) async {
        do {
            try await api.updatePromotion(promotion)
            successMessage = "Promotion updated."
            await loadPromotions()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func deletePromotion(id: String) async {
        do {
            try await api.deletePromotion(id: id)
            successMessage = "Promotion removed."
            await loadPromotions()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func loadSpecialOrders() async {
        do {
            async let custom = api.fetchCustomCakeOrders()
            async let ai = api.fetchAICakeDesignOrders()
            customCakeOrders = try await custom
            aiCakeDesignOrders = try await ai
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func loadCustomCakeOptions() async {
        do {
            customCakeOptions = try await api.fetchCustomCakeOptionsSettings()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func saveCustomCakeOptions(sizes: [CakeSizeOption], flavors: [CakeFlavorOption], frostings: [FrostingOption], toppings: [ToppingOption]) async {
        do {
            try await api.saveCustomCakeOptions(sizes: sizes, flavors: flavors, frostings: frostings, toppings: toppings)
            customCakeOptions = CustomCakeOptionsResponse(sizes: sizes, flavors: flavors, frostings: frostings, toppings: toppings)
            successMessage = "Custom cake options saved."
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func loadCakeGallery() async {
        do {
            cakeGalleryItems = try await api.fetchGalleryCakes()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func addGalleryItem(imageUrl: String, title: String, description: String?, category: String?, price: Double?) async throws {
        _ = try await api.addGalleryCake(imageUrl: imageUrl, title: title, description: description, category: category, price: price)
        successMessage = "Added to gallery."
        await loadCakeGallery()
    }

    func updateGalleryItem(_ item: GalleryCakeItem, imageUrl: String? = nil, title: String? = nil, description: String? = nil, category: String? = nil, price: Double? = nil) async {
        let id = item.id
        do {
            try await api.updateGalleryCake(id: id, imageUrl: imageUrl, title: title, description: description, category: category, price: price)
            successMessage = "Gallery item updated."
            await loadCakeGallery()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func deleteGalleryItem(id: String) async {
        do {
            try await api.deleteGalleryCake(id: id)
            successMessage = "Removed from gallery."
            await loadCakeGallery()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
