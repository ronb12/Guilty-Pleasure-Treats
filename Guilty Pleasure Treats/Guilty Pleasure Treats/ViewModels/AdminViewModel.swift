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
    /// First non-empty email from this customer’s orders (checkout email).
    let email: String?
    let orderCount: Int
    let totalSpent: Double
    let orders: [Order]
    /// Loyalty points (from first order's userPoints, if available). Nil for guest customers.
    let points: Int?
    /// True when at least one order is tied to a signed-in user (`userId`).
    var hasAccount: Bool { key.hasPrefix("u:") }
}

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var orders: [Order] = []
    /// Full order list for Analytics only (always unfiltered). Separate from `orders` so Orders-tab filters and failed analytics loads never wipe charts or the orders list.
    @Published var analyticsOrders: [Order] = []
    /// Admin Orders tab: passed to API as query filters (server filters in memory on the admin list).
    @Published var adminOrderStatusFilter: String = ""
    @Published var adminOrderFulfillmentFilter: String = ""
    @Published var adminOrderSearchText: String = ""
    @Published var adminOrderDateFrom: Date? = nil
    @Published var adminOrderDateTo: Date? = nil
    /// Set when `loadOrders()` fails (decode, network, auth). Cleared on success.
    @Published var ordersLoadError: String? = nil
    @Published var businessSettings: BusinessSettings?
    @Published var promotions: [Promotion] = []
    @Published var loyaltyRewards: [LoyaltyRewardItem] = []
    @Published var customCakeOrders: [CustomCakeOrder] = []
    @Published var aiCakeDesignOrders: [AICakeDesignOrder] = []
    @Published var customCakeOptions: CustomCakeOptionsResponse?
    @Published var contactMessages: [ContactMessage] = []
    @Published var reviews: [Review] = []
    @Published var events: [Event] = []
    @Published var cakeGalleryItems: [GalleryCakeItem] = []
    @Published var productCategories: [ProductCategoryItem] = []
    @Published var savedCustomers: [SavedCustomer] = []
    @Published var totalCustomerCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    /// Product list fetch failed (sample inventory shown). Shown only on Products / Inventory tabs so other tabs aren’t spammed.
    @Published var productLoadWarning: String?
    /// Category add/update/delete failures only. Shown only on Categories tab.
    @Published var categoryErrorMessage: String?
    
    @Published var editingProduct: Product?
    @Published var newProductImage: PlatformImage?

    /// When set, Messages tab should select and show this contact message (e.g. from push tap). Cleared after applying.
    @Published var scrollToMessageId: String?

    /// When set from a contact message "View order", switch to Orders tab and present this order; cleared after opening.
    @Published var pendingOrderIdToOpen: String?

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
        products.filter { $0.showsAdminLowStockBadge }
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
            // Get points from first order that has userPoints (for signed-in customers)
            let points = orderList.compactMap { $0.userPoints }.first
            let email = orderList.compactMap { ord -> String? in
                let e = ord.customerEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return e.isEmpty ? nil : e
            }.first
            return AdminCustomer(
                key: key,
                displayName: o.customerName,
                phone: o.customerPhone,
                email: email,
                orderCount: orderList.count,
                totalSpent: total,
                orders: orderList.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) },
                points: points
            )
        }.sorted { $0.orderCount > $1.orderCount }
    }
    
    /// Customers with enough points for at least one active loyalty reward (from Admin → Loyalty rewards).
    var customersEligibleForRewards: [AdminCustomer] {
        let active = loyaltyRewards.filter { $0.isActive }
        guard let minPts = active.map(\.pointsRequired).min() else { return [] }
        return customers.filter { ($0.points ?? 0) >= minPts }
    }

    /// Short caption for the Customers list (uses `loyaltyRewards`).
    func rewardEligibilityCaption(for customer: AdminCustomer) -> String? {
        guard let p = customer.points else { return nil }
        let active = loyaltyRewards.filter { $0.isActive }.sorted { $0.pointsRequired < $1.pointsRequired }
        if active.isEmpty { return "\(p) pts" }
        let eligible = active.filter { p >= $0.pointsRequired }
        if !eligible.isEmpty {
            let names = eligible.map(\.name).joined(separator: ", ")
            return "\(p) pts — can redeem: \(names)"
        }
        if let next = active.first(where: { p < $0.pointsRequired }) {
            let gap = next.pointsRequired - p
            return "\(p) pts (need \(gap) more for \(next.name))"
        }
        return "\(p) pts"
    }

    /// Badges for customer detail (e.g. eligible reward names).
    func eligibleRewardNames(for customer: AdminCustomer) -> String? {
        guard let p = customer.points else { return nil }
        let eligible = loyaltyRewards.filter { $0.isActive && p >= $0.pointsRequired }
        if eligible.isEmpty { return nil }
        return eligible.map(\.name).joined(separator: ", ")
    }

    /// Hint when not yet eligible for the next cheapest reward.
    func nextRewardPointsHint(for customer: AdminCustomer) -> String? {
        guard let p = customer.points else { return nil }
        let active = loyaltyRewards.filter { $0.isActive }.sorted { $0.pointsRequired < $1.pointsRequired }
        guard let next = active.first(where: { p < $0.pointsRequired }) else { return nil }
        let gap = next.pointsRequired - p
        return "\(gap) more points for \(next.name)"
    }
    
    var totalRevenue: Double {
        analyticsOrders.filter { $0.statusEnum != .cancelled }.reduce(0.0) { $0 + $1.total }
    }
    
    var completedOrderCount: Int {
        analyticsOrders.filter { $0.statusEnum != .cancelled }.count
    }
    
    var ordersByDay: [(date: Date, count: Int, revenue: Double)] {
        ordersByDay(for: .allTime)
    }

    // MARK: - Analytics (period-filtered)

    /// Orders that are not cancelled, filtered by period.
    func completedOrders(in period: AnalyticsPeriod) -> [Order] {
        let list = analyticsOrders.filter { $0.statusEnum != .cancelled }
        return period.filter(list, calendar: .current)
    }

    /// Count of orders still in pipeline (Pending, Confirmed, Preparing, Ready).
    var pendingOrderCount: Int {
        analyticsOrders.filter { o in
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
        let prevOrders = analyticsOrders.filter { o in
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

    /// Status funnel: count by status for the period (completed + cancelled for full funnel).
    func statusFunnel(for period: AnalyticsPeriod) -> [(status: String, count: Int)] {
        let list = period.filter(analyticsOrders, calendar: .current)
        let grouped = Dictionary(grouping: list) { $0.status }
        return OrderStatus.allCases.map { status in
            (status: status.rawValue, count: grouped[status.rawValue]?.count ?? 0)
        }.filter { $0.count > 0 }.sorted { $0.count > $1.count }
    }

    /// New vs returning: guest orders, signed-in orders, and repeat customers (signed-in with >1 order) in period.
    func newVsReturning(for period: AnalyticsPeriod) -> (guestOrders: Int, signedInOrders: Int, repeatCustomerOrders: Int) {
        let list = completedOrders(in: period)
        var guest = 0
        var signedIn = 0
        var repeatOrders = 0
        let byUser = Dictionary(grouping: list) { $0.userId ?? "" }
        for (uid, userOrders) in byUser {
            if uid.isEmpty {
                guest += userOrders.count
            } else {
                signedIn += userOrders.count
                if userOrders.count > 1 { repeatOrders += userOrders.count }
            }
        }
        return (guest, signedIn, repeatOrders)
    }

    /// Promo redemptions in period: (code, count) sorted by count.
    func promoRedemptions(for period: AnalyticsPeriod) -> [(code: String, count: Int)] {
        let list = completedOrders(in: period).compactMap { o in (o.promoCode ?? "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let grouped = Dictionary(grouping: list) { $0.uppercased() }
        return grouped.map { (code: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
    }

    /// Total tips in period (cents).
    func totalTipsCents(for period: AnalyticsPeriod) -> Int {
        completedOrders(in: period).reduce(0) { $0 + ($1.tipCents ?? 0) }
    }

    /// Custom / AI cake attach rate: orders with custom cake IDs or AI design IDs.
    func customAICakeAttach(for period: AnalyticsPeriod) -> (withCustom: Int, withAI: Int, total: Int) {
        let list = completedOrders(in: period)
        let withCustom = list.filter { ($0.customCakeOrderIds ?? []).isEmpty == false }.count
        let withAI = list.filter { ($0.aiCakeDesignIds ?? []).isEmpty == false }.count
        return (withCustom, withAI, list.count)
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
        let funnel = statusFunnel(for: period)
        let nvr = newVsReturning(for: period)
        let promos = promoRedemptions(for: period)
        let tipsCents = totalTipsCents(for: period)
        let cakeAttach = customAICakeAttach(for: period)
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
        var funnelRows = ""
        for item in funnel {
            funnelRows += "<tr><td>\(esc(item.status))</td><td>\(item.count)</td></tr>"
        }
        var promoRows = ""
        for item in promos {
            promoRows += "<tr><td>\(esc(item.code))</td><td>\(item.count)</td></tr>"
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
        <div class="section">
        <h2>Status funnel</h2>
        <table><thead><tr><th>Status</th><th>Count</th></tr></thead><tbody>\(funnelRows)</tbody></table>
        </div>
        <div class="section">
        <h2>Customer mix</h2>
        <p>Guest: \(nvr.guestOrders) · Signed-in: \(nvr.signedInOrders) · Repeat (2+ orders): \(nvr.repeatCustomerOrders)</p>
        </div>
        <div class="section">
        <h2>Promo redemptions</h2>
        <table><thead><tr><th>Code</th><th>Orders</th></tr></thead><tbody>\(promoRows)</tbody></table>
        </div>
        <p><strong>Tips collected:</strong> \(fmt(Double(tipsCents) / 100.0))</p>
        <p><strong>Custom/AI cakes:</strong> \(cakeAttach.withCustom) orders with custom cake · \(cakeAttach.withAI) with AI design (of \(cakeAttach.total) total)</p>
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
            if p.isSoldOutByInventory {
                status = "Sold out"
            } else if p.showsAdminLowStockBadge {
                status = "Low stock"
            } else if p.stockQuantity != nil {
                status = "OK"
            } else {
                status = "No tracking"
            }
            rows += "<tr><td>\(esc(p.name))</td><td>\(esc(p.category))</td><td>\(esc(stockStr))</td><td>\(esc(thresholdStr))</td><td>\(esc(status))</td></tr>"
        }
        let lowCount = list.filter { $0.showsAdminLowStockBadge }.count
        let soldOutCount = list.filter { $0.isSoldOutByInventory }.count
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

    /// HTML for a printable customer report: everyone who appears in **From orders**, split into account vs guest checkout.
    func customerReportHTML() -> String {
        let storeName = (businessSettings?.storeName?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "Guilty Pleasure Treats"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let now = Date()
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
        let list = customers
        let withAccount = list.filter(\.hasAccount).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let guests = list.filter { !$0.hasAccount }.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        func row(_ c: AdminCustomer) -> String {
            let em = (c.email.map { esc($0) }) ?? "—"
            return "<tr><td>\(esc(c.displayName))</td><td>\(esc(c.phone))</td><td>\(em)</td><td>\(c.orderCount)</td><td>\(fmt(c.totalSpent))</td></tr>"
        }
        var accountRows = ""
        for c in withAccount { accountRows += row(c) }
        var guestRows = ""
        for c in guests { guestRows += row(c) }
        let accountEmpty = accountRows.isEmpty ? "<tr><td colspan=\"5\">None</td></tr>" : accountRows
        let guestEmpty = guestRows.isEmpty ? "<tr><td colspan=\"5\">None</td></tr>" : guestRows
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Customer Report – Guilty Pleasure Treats</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; color: #333; }
        h1 { font-size: 22px; margin-bottom: 4px; }
        .meta { color: #666; font-size: 14px; margin-bottom: 16px; }
        h2 { font-size: 16px; margin-top: 20px; margin-bottom: 8px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 12px; }
        th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
        th { background: #f5f5f5; }
        .summary p { margin: 6px 0; }
        </style>
        </head>
        <body>
        <h1>Customer report</h1>
        <p class="meta">\(esc(storeName)) · Generated \(esc(dateFormatter.string(from: now)))</p>
        <div class="summary">
        <p><strong>Customers who ordered</strong> (from your order history): \(list.count) total · \(withAccount.count) with an account · \(guests.count) guest checkout (no account)</p>
        </div>
        <h2>With an account</h2>
        <p class="meta">Signed-in customers (orders linked to a user).</p>
        <table>
        <thead><tr><th>Name</th><th>Phone</th><th>Email</th><th>Orders</th><th>Total spent</th></tr></thead>
        <tbody>\(accountEmpty)</tbody>
        </table>
        <h2>Guest checkout (no account)</h2>
        <p class="meta">Orders placed without signing in (grouped by name and phone).</p>
        <table>
        <thead><tr><th>Name</th><th>Phone</th><th>Email</th><th>Orders</th><th>Total spent</th></tr></thead>
        <tbody>\(guestEmpty)</tbody>
        </table>
        </body>
        </html>
        """
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        productLoadWarning = nil
        do {
            products = try await api.fetchProducts()
        } catch {
            products = []
            productLoadWarning = FriendlyErrorMessage.message(for: error)
        }
        isLoading = false
        if AuthService.shared.userProfile?.isAdmin == true, !lowStockProducts.isEmpty {
            NotificationService.shared.scheduleLowStockNotification(
                count: lowStockProducts.count,
                firstProductName: lowStockProducts.first?.name
            )
        }
    }

    /// Success toast on Categories tab; auto-clears after a few seconds (user can still tap Dismiss).
    private func setCategoryOperationSuccess(_ message: String) {
        successMessage = message
        let marker = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self else { return }
            if self.successMessage == marker {
                self.successMessage = nil
            }
        }
    }

    func loadProductCategories() async {
        do {
            productCategories = try await api.fetchProductCategories()
            categoryErrorMessage = nil
        } catch {
            // Fallback categories are local-only placeholders and cannot be edited/deleted server-side.
            productCategories = ProductCategory.allCases.map { ProductCategoryItem(id: "default-\($0.rawValue)", name: $0.rawValue, displayOrder: 0) }
            categoryErrorMessage = "Couldn't load categories from server. Please check your connection and refresh before editing."
        }
    }

    func addCategory(name: String, displayOrder: Int = 0) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        categoryErrorMessage = nil
        do {
            let item = try await api.addProductCategory(name: trimmed, displayOrder: displayOrder)
            productCategories.append(item)
            productCategories.sort { $0.displayOrder < $1.displayOrder }
            successMessage = "Category added."
            await loadProductCategories()
            return true
        } catch {
            categoryErrorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    func updateCategory(_ item: ProductCategoryItem, name: String? = nil, displayOrder: Int? = nil) async -> Bool {
        guard let n = name?.trimmingCharacters(in: .whitespaces), !n.isEmpty else { return false }
        if item.id.hasPrefix("default-") {
            categoryErrorMessage = "Categories are in offline fallback mode and cannot be edited. Refresh after reconnecting."
            return false
        }
        categoryErrorMessage = nil
        #if DEBUG
        print("[AdminViewModel] updateCategory start id=\(item.id) old=\(item.name) new=\(n)")
        #endif
        do {
            try await api.updateProductCategory(id: item.id, name: n, displayOrder: displayOrder ?? item.displayOrder)
            setCategoryOperationSuccess("Category updated.")
            await loadProductCategories()
            #if DEBUG
            print("[AdminViewModel] updateCategory success id=\(item.id)")
            #endif
            return true
        } catch {
            if let apiErr = error as? VercelAPIError {
                categoryErrorMessage = apiErr.supportDebugText
            } else {
                categoryErrorMessage = FriendlyErrorMessage.message(for: error)
            }
            #if DEBUG
            print("[AdminViewModel] updateCategory failed id=\(item.id) error=\(error)")
            #endif
            return false
        }
    }

    func deleteCategory(_ item: ProductCategoryItem) async {
        categoryErrorMessage = nil
        do {
            try await api.deleteProductCategory(id: item.id)
            productCategories.removeAll { $0.id == item.id }
            setCategoryOperationSuccess("Category removed.")
            await loadProductCategories()
        } catch {
            categoryErrorMessage = FriendlyErrorMessage.message(for: error)
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

    func addSavedCustomer(name: String, phone: String, email: String?, street: String?, addressLine2: String?, city: String?, state: String?, postalCode: String?, notes: String?, foodAllergies: String?) async {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        do {
            let allergyNote = foodAllergies?.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = try await api.addSavedCustomer(
                name: n,
                phone: phone.trimmingCharacters(in: .whitespaces),
                email: email?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : email,
                street: street?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : street?.trimmingCharacters(in: .whitespaces),
                addressLine2: addressLine2?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : addressLine2?.trimmingCharacters(in: .whitespaces),
                city: city?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : city?.trimmingCharacters(in: .whitespaces),
                state: state?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : state?.trimmingCharacters(in: .whitespaces),
                postalCode: postalCode?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : postalCode?.trimmingCharacters(in: .whitespaces),
                notes: notes?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : notes,
                foodAllergies: (allergyNote?.isEmpty == false) ? allergyNote : nil
            )
            savedCustomers.append(item)
            savedCustomers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            successMessage = "Customer added."
            await loadSavedCustomers()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func updateSavedCustomer(_ item: SavedCustomer, name: String?, phone: String?, email: String?, street: String?, addressLine2: String?, city: String?, state: String?, postalCode: String?, notes: String?, foodAllergies: String) async {
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
                notes: notes?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : notes,
                foodAllergies: foodAllergies
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
            ordersLoadError = nil
            orders = try await api.fetchAllOrders(
                status: adminOrderStatusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : adminOrderStatusFilter,
                fulfillmentType: adminOrderFulfillmentFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : adminOrderFulfillmentFilter,
                search: adminOrderSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : adminOrderSearchText,
                dateFrom: adminOrderDateFrom,
                dateTo: adminOrderDateTo
            )
            if let first = orders.first, let id = first.id, let createdAt = first.createdAt {
                NotificationService.shared.addNewOrderInAppIfNeeded(
                    orderId: id,
                    customerName: first.customerName,
                    total: first.total,
                    orderCreatedAt: createdAt
                )
            }
        } catch {
            orders = []
            ordersLoadError = FriendlyErrorMessage.message(for: error)
            #if DEBUG
            print("[Admin] loadOrders failed: \(error)")
            #endif
        }
    }

    /// Loads an unfiltered snapshot into `analyticsOrders` for charts. Does not modify `orders` (Orders tab).
    func loadOrdersForAnalytics() async {
        do {
            analyticsOrders = try await api.fetchAllOrders(
                status: nil,
                fulfillmentType: nil,
                search: nil,
                dateFrom: nil,
                dateTo: nil
            )
        } catch {
            analyticsOrders = []
            #if DEBUG
            print("[Admin] loadOrdersForAnalytics failed: \(error)")
            #endif
        }
    }

    /// True when any admin order list filter is active (may hide rows that exist in Neon).
    var hasActiveAdminOrderFilters: Bool {
        !adminOrderStatusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !adminOrderFulfillmentFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !adminOrderSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || adminOrderDateFrom != nil
            || adminOrderDateTo != nil
    }
    
    func addProduct(name: String, description: String, price: Double, cost: Double? = nil, category: String, isFeatured: Bool, isVegan: Bool = false, image: PlatformImage?, stockQuantity: Int? = nil, lowStockThreshold: Int? = nil, sizeOptions: [ProductSizeOption]? = nil) async -> Bool {
        let product = Product(
            name: name,
            productDescription: description,
            price: price,
            cost: cost,
            imageURL: nil,
            category: category,
            isFeatured: isFeatured,
            isSoldOut: false,
            isVegan: isVegan,
            stockQuantity: stockQuantity,
            lowStockThreshold: lowStockThreshold,
            sizeOptions: sizeOptions
        )
        do {
            let id = try await api.addProduct(product)
            if let image = image, let data = image.imageDataForAdminUpload(compressionQuality: 0.72) {
                let url = try await api.uploadProductImage(data: data, productId: id)
                var updated = product
                updated.id = id
                updated.imageURL = url
                try await api.updateProduct(updated)
            }
            successMessage = "Product added."
            await loadProducts()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }
    
    func updateProduct(_ product: Product, newImage: PlatformImage?) async -> Bool {
        if product.id?.hasPrefix("sample-") == true {
            if let idx = products.firstIndex(where: { $0.id == product.id }) {
                var updated = product
                if newImage != nil { updated.updatedAt = Date() }
                products[idx] = updated
                successMessage = "Inventory updated (demo)."
            }
            editingProduct = nil
            return true
        }
        do {
            if let img = newImage, let id = product.id, let data = img.imageDataForAdminUpload(compressionQuality: 0.72) {
                let url = try await api.uploadProductImage(data: data, productId: id)
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
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
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
        if status == .ready, order.fulfillmentEnum == .shipping, !order.hasParcelTrackingForShipping {
            errorMessage =
                "Add a carrier and tracking number before marking a shipping order ready. Open the order and tap Parcel tracking."
            return
        }
        do {
            try await api.updateOrderStatus(orderId: orderId, status: status)
            // Loyalty earn is server-side when status becomes Completed (idempotent per order).
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
            #if DEBUG
            print("[Admin] loadBusinessHours failed: \(error)")
            #endif
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
        productLoadWarning = nil
        categoryErrorMessage = nil
    }

    /// Dismiss banner on Products / Inventory without clearing category-specific errors.
    func dismissProductBanner() {
        errorMessage = nil
        productLoadWarning = nil
        successMessage = nil
    }

    /// Clears category error banner and any success toast shown on the Categories tab (`successMessage` is shared across Admin).
    func dismissCategoryBanner() {
        categoryErrorMessage = nil
        successMessage = nil
    }

    func loadContactMessages() async {
        do {
            contactMessages = try await api.fetchContactMessages()
        } catch {
            contactMessages = []
            #if DEBUG
            print("[Admin] loadContactMessages failed: \(error)")
            #endif
        }
    }

    func loadReviews() async {
        do {
            reviews = try await api.fetchReviews()
        } catch {
            reviews = []
        }
    }

    func loadEvents() async {
        do {
            events = try await api.fetchEvents(includeAllForAdmin: true)
        } catch {
            events = []
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    @discardableResult
    func createEvent(title: String, eventDescription: String?, startAt: Date?, endAt: Date?, imageURL: String?, location: String?) async -> Bool {
        errorMessage = nil
        successMessage = nil
        let event = Event(
            id: "",
            title: title,
            eventDescription: eventDescription,
            startAt: startAt,
            endAt: endAt,
            imageURL: imageURL,
            location: location,
            createdAt: nil
        )
        do {
            _ = try await api.addEvent(event)
            successMessage = "Event created. Customers will be notified."
            await loadEvents()
            return true
        } catch {
            #if DEBUG
            if let v = error as? VercelAPIError {
                print("[Events] addEvent failed: \(v.supportDebugText)")
            } else {
                print("[Events] addEvent failed: \(error)")
            }
            #endif
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    @discardableResult
    func updateEvent(id: String, title: String?, eventDescription: String?, startAt: Date?, endAt: Date?, imageURL: String?, location: String?) async -> Bool {
        errorMessage = nil
        successMessage = nil
        do {
            try await api.updateEvent(id: id, title: title, eventDescription: eventDescription, startAt: startAt, endAt: endAt, imageURL: imageURL, location: location)
            successMessage = "Event updated."
            await loadEvents()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    func deleteEvent(id: String) async {
        do {
            try await api.deleteEvent(id: id)
            successMessage = "Event removed."
            await loadEvents()
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

    /// Send a new message from admin to a customer (by id or email) or to all customers. Returns true if sent successfully.
    @discardableResult
    func sendAdminMessage(toUserId: String?, toUserEmail: String?, body: String) async -> Bool {
        do {
            try await api.sendAdminMessage(toUserId: toUserId, toUserEmail: toUserEmail, body: body)
            successMessage = "Message sent. Customers will see it in the app."
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    func loadBusinessSettings() async {
        do {
            businessSettings = try await api.fetchBusinessSettings() ?? BusinessSettings()
        } catch {
            businessSettings = BusinessSettings()
            #if DEBUG
            print("[Admin] loadBusinessSettings failed: \(error)")
            #endif
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
    
    func saveBusinessSettings(_ settings: BusinessSettings, newStripeSecretKey: String? = nil) async {
        do {
            try await api.setBusinessSettings(settings, newStripeSecretKey: newStripeSecretKey)
            await loadBusinessSettings()
            successMessage = "Settings saved."
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func loadPromotions() async {
        do {
            promotions = try await api.fetchPromotions()
        } catch {
            promotions = []
            #if DEBUG
            print("[Admin] loadPromotions failed: \(error)")
            #endif
        }
    }

    func loadLoyaltyRewards() async {
        do {
            loyaltyRewards = try await api.fetchLoyaltyRewards(includeInactive: true)
        } catch {
            loyaltyRewards = []
            #if DEBUG
            print("[Admin] loadLoyaltyRewards failed: \(error)")
            #endif
        }
    }

    @discardableResult
    func addLoyaltyReward(name: String, pointsRequired: Int, productId: String, sortOrder: Int, isActive: Bool) async -> Bool {
        do {
            _ = try await api.createLoyaltyReward(name: name, pointsRequired: pointsRequired, productId: productId, sortOrder: sortOrder, isActive: isActive)
            successMessage = "Loyalty reward added."
            await loadLoyaltyRewards()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    @discardableResult
    func updateLoyaltyReward(_ reward: LoyaltyRewardItem) async -> Bool {
        do {
            try await api.updateLoyaltyReward(reward)
            successMessage = "Loyalty reward updated."
            await loadLoyaltyRewards()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    func deleteLoyaltyReward(id: String) async {
        do {
            try await api.deleteLoyaltyReward(id: id)
            successMessage = "Loyalty reward removed."
            await loadLoyaltyRewards()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    @Published var newsletterRecipientCount: Int?

    func loadNewsletterRecipientCount() async {
        do {
            newsletterRecipientCount = try await api.fetchNewsletterRecipientCount()
        } catch {
            newsletterRecipientCount = nil
            #if DEBUG
            print("[Admin] loadNewsletterRecipientCount failed: \(error)")
            #endif
        }
    }

    @discardableResult
    func sendNewsletter(subject: String, htmlBody: String, textBody: String?, replyTo: String?) async -> Bool {
        do {
            let result = try await api.sendNewsletter(
                subject: subject,
                htmlBody: htmlBody,
                textBody: textBody,
                replyTo: replyTo
            )
            var msg = "Sent \(result.sent) email(s)."
            if result.failed > 0 { msg += " \(result.failed) failed." }
            if result.truncated {
                msg += " Some recipients were skipped (per-send limit). Raise NEWSLETTER_MAX_SENDS on the server or send again later."
            }
            if let samples = result.sampleErrors, !samples.isEmpty {
                let detail = samples.prefix(3).map { "\($0.to): \($0.message)" }.joined(separator: " · ")
                msg += " Examples: \(detail)"
            }
            successMessage = msg
            await loadNewsletterRecipientCount()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    /// Upload a Canva export (PNG/JPEG/PDF) to Vercel Blob; returns a public URL for the HTML body.
    func uploadNewsletterAsset(data: Data, filename: String, contentType: String) async throws -> String {
        let base = (filename as NSString).lastPathComponent
        let safe = base.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "", options: .regularExpression)
        let suffix = safe.isEmpty ? "file" : safe
        let path = "newsletters/\(UUID().uuidString)-\(suffix)"
        return try await api.uploadImageBase64(data: data, pathname: path, contentType: contentType)
    }

    @discardableResult
    func addPromotion(_ promotion: Promotion) async -> Bool {
        do {
            _ = try await api.addPromotion(promotion)
            successMessage = "Promotion added."
            await loadPromotions()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }

    @discardableResult
    func updatePromotion(_ promotion: Promotion) async -> Bool {
        do {
            try await api.updatePromotion(promotion)
            successMessage = "Promotion updated."
            await loadPromotions()
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
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
            customCakeOrders = []
            aiCakeDesignOrders = []
            #if DEBUG
            print("[Admin] loadSpecialOrders failed: \(error)")
            #endif
        }
    }

    func loadCustomCakeOptions() async {
        do {
            var options = try await api.fetchCustomCakeOptionsSettings()
            // When API returns empty options, use the same defaults as the Custom Cake builder so Admin shows what customers see.
            if options.sizes.isEmpty || options.flavors.isEmpty || options.frostings.isEmpty {
                let defaults = Self.defaultCakeOptionsForDisplay()
                if options.sizes.isEmpty { options.sizes = defaults.sizes }
                if options.flavors.isEmpty { options.flavors = defaults.flavors }
                if options.frostings.isEmpty { options.frostings = defaults.frostings }
                if options.toppings == nil || options.toppings?.isEmpty == true { options.toppings = defaults.toppings }
            }
            options.sizes = Self.optionsWithStableSortOrder(options.sizes) { CakeSizeOption(optionId: $0.optionId, label: $0.label, price: $0.price, sortOrder: $1) }
            options.flavors = Self.optionsWithStableSortOrder(options.flavors) { CakeFlavorOption(optionId: $0.optionId, label: $0.label, sortOrder: $1) }
            options.frostings = Self.optionsWithStableSortOrder(options.frostings) { FrostingOption(optionId: $0.optionId, label: $0.label, sortOrder: $1) }
            options.toppings = (options.toppings ?? []).enumerated().map { i, t in
                ToppingOption(optionId: t.optionId, label: t.label, price: t.price, sortOrder: t.sortOrder ?? i)
            }
            options.colors = Self.optionsWithStableSortOrder(options.colors ?? []) { CakeFlavorOption(optionId: $0.optionId, label: $0.label, sortOrder: $1) }
            options.fillings = Self.optionsWithStableSortOrder(options.fillings ?? []) { CakeFlavorOption(optionId: $0.optionId, label: $0.label, sortOrder: $1) }
            customCakeOptions = options
        } catch {
            // On error, show builder defaults so admin can still see and edit the same list as the cake maker.
            customCakeOptions = Self.defaultCakeOptionsForDisplay()
            #if DEBUG
            print("[Admin] loadCustomCakeOptions failed: \(error)")
            #endif
        }
    }

    private static func optionsWithStableSortOrder<T>(_ items: [T], map: (T, Int) -> T) -> [T] {
        items.enumerated().map { i, item in map(item, i) }
    }

    /// Same default options as CustomCakeBuilderViewModel.useEnumFallback() so Admin Cake Options matches what appears in the cake maker.
    private static func defaultCakeOptionsForDisplay() -> CustomCakeOptionsResponse {
        let sizes = CakeSize.allCases.enumerated().map { i, s in
            CakeSizeOption(optionId: nil, label: s.rawValue, price: s.price, sortOrder: i)
        }
        let flavors = CakeFlavor.allCases.enumerated().map { i, f in
            CakeFlavorOption(optionId: nil, label: f.rawValue, sortOrder: i)
        }
        let frostings = FrostingType.allCases.enumerated().map { i, f in
            FrostingOption(optionId: nil, label: f.rawValue, sortOrder: i)
        }
        let toppings = CakeTopping.allCases.enumerated().map { i, t in
            ToppingOption(optionId: nil, label: t.rawValue, price: t.price, sortOrder: i)
        }
        return CustomCakeOptionsResponse(sizes: sizes, flavors: flavors, frostings: frostings, toppings: toppings, colors: [], fillings: [])
    }

    func saveCustomCakeOptions(sizes: [CakeSizeOption], flavors: [CakeFlavorOption], frostings: [FrostingOption], toppings: [ToppingOption], colors: [CakeFlavorOption], fillings: [CakeFlavorOption]) async {
        do {
            try await api.saveCustomCakeOptions(sizes: sizes, flavors: flavors, frostings: frostings, toppings: toppings, colors: colors, fillings: fillings)
            customCakeOptions = CustomCakeOptionsResponse(sizes: sizes, flavors: flavors, frostings: frostings, toppings: toppings, colors: colors, fillings: fillings)
            successMessage = "Custom cake options saved."
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    func loadCakeGallery() async {
        do {
            cakeGalleryItems = try await api.fetchGalleryCakes()
        } catch {
            cakeGalleryItems = []
            #if DEBUG
            print("[Admin] loadCakeGallery failed: \(error)")
            #endif
        }
    }

    func addGalleryItem(imageUrl: String, title: String, description: String?, category: String?, price: Double?) async throws {
        _ = try await api.addGalleryCake(imageUrl: imageUrl, title: title, description: description, category: category, price: price)
        successMessage = "Added to gallery."
        await loadCakeGallery()
    }

    func updateGalleryItem(_ item: GalleryCakeItem, imageUrl: String? = nil, title: String, description: String?, category: String?, price: Double?) async {
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
