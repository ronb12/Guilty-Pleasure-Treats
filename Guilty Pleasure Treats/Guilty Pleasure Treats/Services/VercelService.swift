//
//  VercelService.swift
//  Guilty Pleasure Treats
//
//  Calls Vercel API (Neon Postgres + Blob) for products, orders, and image uploads.
//

import Foundation

/// Lightweight user from Vercel auth (replaces Firebase User for auth state).
struct VercelUser {
    let uid: String
    let email: String?
    let displayName: String?
    /// Saved at sign-up; used to prefill checkout.
    let phone: String?
}

final class VercelService {
    static let shared = VercelService()
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Set by AuthService when signed in. Used for Authorization header.
    var authToken: String?

    private var baseURL: URL? {
        guard let s = AppConstants.vercelBaseURLString?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        return URL(string: s.hasSuffix("/") ? String(s.dropLast()) : s)
    }

    /// Build API URL from path segments so path is e.g. /api/users/me, not /api%2Fusers%2Fme.
    private func apiURL(pathComponents: String...) -> URL? {
        guard let base = baseURL else { return nil }
        return pathComponents.reduce(base) { $0.appendingPathComponent($1) }
    }

    static var isConfigured: Bool { shared.baseURL != nil }

    private init() {
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unexpected null date")
            }
            let str = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            withFractional.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = withFractional.date(from: str) { return d }
            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]
            withoutFractional.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = withoutFractional.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(str)")
        }
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic API (for extensions e.g. VercelService+BakeryAPI)

    private func requestURL(path: String) throws -> URL {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let pathTrimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: pathTrimmed, relativeTo: base) else {
            throw VercelAPIError(message: "Invalid API path", statusCode: 0)
        }
        return url
    }

    func post(_ path: String, body: [String: Any]) async throws {
        let url = try requestURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    func put(_ path: String, body: [String: Any]) async throws {
        let url = try requestURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let url = try requestURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = authToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func getRaw(_ path: String) async throws -> Data {
        let url = try requestURL(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = authToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return data
    }

    // MARK: - Products

    func fetchProducts(category: String? = nil, featuredOnly: Bool = false) async throws -> [Product] {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        var comp = URLComponents(url: base.appendingPathComponent("api/products"), resolvingAgainstBaseURL: false)!
        var query = [URLQueryItem]()
        if let c = category, !c.isEmpty { query.append(URLQueryItem(name: "category", value: c)) }
        if featuredOnly { query.append(URLQueryItem(name: "featured", value: "true")) }
        if !query.isEmpty { comp.queryItems = query }
        var req = URLRequest(url: comp.url!)
        req.httpMethod = "GET"
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? String(data: data, encoding: .utf8) ?? "Request failed"
            throw VercelAPIError(message: msg, statusCode: http.statusCode)
        }
        do {
            return try decoder.decode([Product].self, from: data)
        } catch {
            throw VercelAPIError(message: "Invalid product data from server. Please try again.", statusCode: http.statusCode)
        }
    }

    func fetchProduct(id: String) async throws -> Product? {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/products/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        try validateResponse(http, data: data)
        return try decoder.decode(Product.self, from: data)
    }

    func addProduct(_ product: Product) async throws -> String {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/products"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [
            "name": product.name,
            "description": product.productDescription,
            "price": product.price,
            "imageURL": product.imageURL as Any,
            "category": product.category,
            "isFeatured": product.isFeatured,
            "isSoldOut": product.isSoldOut,
            "isVegetarian": product.isVegetarian,
            "stockQuantity": product.stockQuantity as Any,
            "lowStockThreshold": product.lowStockThreshold as Any,
        ]
        if let c = product.cost { body["cost"] = c }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return j?["id"] as? String ?? ""
    }

    func updateProduct(_ product: Product) async throws {
        guard let id = product.id, let base = baseURL, let token = authToken else { return }
        var req = URLRequest(url: base.appendingPathComponent("api/products/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [
            "name": product.name,
            "description": product.productDescription,
            "price": product.price,
            "imageURL": product.imageURL as Any,
            "category": product.category,
            "isFeatured": product.isFeatured,
            "isSoldOut": product.isSoldOut,
            "isVegetarian": product.isVegetarian,
            "stockQuantity": product.stockQuantity as Any,
            "lowStockThreshold": product.lowStockThreshold as Any,
        ]
        if let c = product.cost { body["cost"] = c }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    func deleteProduct(id: String) async throws {
        guard let base = baseURL, let token = authToken else { return }
        var req = URLRequest(url: base.appendingPathComponent("api/products/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func uploadProductImage(data: Data, productId: String) async throws -> String {
        return try await uploadImage(data: data, pathname: "products/\(productId).jpg")
    }

    func uploadCustomCakeDesignImage(data: Data, customCakeOrderId: String) async throws -> String {
        return try await uploadImage(data: data, pathname: "customCakeDesigns/\(customCakeOrderId).jpg")
    }

    func uploadAICakeDesignImage(data: Data, designId: String) async throws -> String {
        return try await uploadImage(data: data, pathname: "aiCakeDesigns/\(designId).jpg")
    }

    // MARK: - Orders

    func createOrder(_ order: Order, idempotencyKey: String? = nil) async throws -> OrderCreateResponse {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/orders")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            req.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        var body = orderPayload(from: order)
        if let key = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            body["idempotencyKey"] = key
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let created = try decoder.decode(OrderCreateResponse.self, from: data)
        return created
    }

    func fetchOrders(
        userId: String?,
        status: String? = nil,
        fulfillmentType: String? = nil,
        search: String? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil
    ) async throws -> [Order] {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        var comp = URLComponents(url: base.appendingPathComponent("api/orders"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem]()
        if let uid = userId, !uid.isEmpty { items.append(URLQueryItem(name: "userId", value: uid)) }
        if let s = status?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            items.append(URLQueryItem(name: "status", value: s))
        }
        if let f = fulfillmentType?.trimmingCharacters(in: .whitespacesAndNewlines), !f.isEmpty {
            items.append(URLQueryItem(name: "fulfillmentType", value: f))
        }
        if let q = search?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            items.append(URLQueryItem(name: "search", value: q))
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = dateFrom { items.append(URLQueryItem(name: "dateFrom", value: iso.string(from: d))) }
        if let d = dateTo { items.append(URLQueryItem(name: "dateTo", value: iso.string(from: d))) }
        if !items.isEmpty { comp.queryItems = items }
        var req = URLRequest(url: comp.url!)
        req.httpMethod = "GET"
        if let t = authToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return [] }
        try validateResponse(http, data: data)
        return try decoder.decode([Order].self, from: data)
    }

    func fetchAllOrders(
        status: String? = nil,
        fulfillmentType: String? = nil,
        search: String? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil
    ) async throws -> [Order] {
        try await fetchOrders(
            userId: nil,
            status: status,
            fulfillmentType: fulfillmentType,
            search: search,
            dateFrom: dateFrom,
            dateTo: dateTo
        )
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async throws {
        try await patchOrder(orderId: orderId, body: ["status": status.rawValue])
    }

    func updateOrderManualPaid(orderId: String) async throws {
        try await patchOrder(orderId: orderId, body: ["manualPaidAt": ISO8601DateFormatter().string(from: Date())])
    }

    /// Creates a Stripe Checkout payment link for the order. Admin only. Caller must be signed in with admin token.
    func createPaymentLink(orderId: String) async throws -> URL {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/stripe/create-checkout-session")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["orderId": orderId])
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let urlString = j?["url"] as? String, let linkURL = URL(string: urlString) else {
            throw VercelAPIError(message: "Invalid payment link response", statusCode: http.statusCode)
        }
        return linkURL
    }

    func updateOrderEstimatedReady(orderId: String, date: Date) async throws {
        try await patchOrder(orderId: orderId, body: ["estimatedReadyTime": ISO8601DateFormatter().string(from: date)])
    }

    private func patchOrder(orderId: String, body: [String: Any]) async throws {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/orders/\(orderId)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    // MARK: - User profile (requires auth)

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        guard authToken != nil else { return nil }
        return try await fetchUserProfileWithToken(authToken!)
    }

    func fetchUserProfileWithToken(_ token: String) async throws -> UserProfile? {
        guard let url = apiURL(pathComponents: "api", "users", "me") else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return nil }
        if http.statusCode == 401 { return nil }
        try validateResponse(http, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let uid = json?["uid"] as? String else { return nil }
        return UserProfile(
            uid: uid,
            email: json?["email"] as? String,
            displayName: json?["displayName"] as? String,
            phone: json?["phone"] as? String,
            isAdmin: (json?["isAdmin"] as? Bool) ?? false,
            points: (json?["points"] as? Int) ?? 0,
            createdAt: (json?["createdAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }

    func setUserProfile(_ profile: UserProfile) async throws {
        guard let url = apiURL(pathComponents: "api", "users", "me"), let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var patch: [String: Any] = ["displayName": profile.displayName as Any]
        if let p = profile.phone { patch["phone"] = p }
        req.httpBody = try JSONSerialization.data(withJSONObject: patch)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func addPoints(uid: String, points: Int) async throws {
        guard let _ = authToken, points > 0 else { return }
        try await patchUserMe(["addPoints": points, "targetUserId": uid])
    }

    func redeemPoints(uid: String, points: Int) async throws -> Bool {
        guard let _ = authToken, points > 0 else { return false }
        try await patchUserMe(["redeemPoints": points])
        return true
    }

    private func patchUserMe(_ body: [String: Any]) async throws {
        guard let url = apiURL(pathComponents: "api", "users", "me"), let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    // MARK: - Business settings

    /// Analytics summary (admin). Total count of customer accounts (users with is_admin = false).
    func fetchAnalyticsSummary() async throws -> Int {
        guard let url = apiURL(pathComponents: "api", "analytics", "summary"),
              let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["totalCustomers"] as? NSNumber)?.intValue ?? (json?["totalCustomers"] as? Int) ?? 0
    }

    func fetchBusinessSettings() async throws -> BusinessSettings? {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/settings/business")
        let (data, res) = try await session.data(from: url)
        guard let http = res as? HTTPURLResponse else { return nil }
        try validateResponse(http, data: data)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let j = j else { return nil }
        let leadTime = j["minimumOrderLeadTimeHours"]
        let leadTimeInt: Int? = (leadTime as? NSNumber)?.intValue ?? (leadTime as? Int)
        return BusinessSettings(
            storeHours: j["storeHours"] as? String,
            deliveryRadiusMiles: j["deliveryRadiusMiles"] as? Double,
            taxRate: (j["taxRate"] as? Double) ?? 0.08,
            minimumOrderLeadTimeHours: leadTimeInt,
            contactEmail: j["contactEmail"] as? String,
            contactPhone: j["contactPhone"] as? String,
            storeName: j["storeName"] as? String,
            cashAppTag: j["cashAppTag"] as? String,
            venmoUsername: j["venmoUsername"] as? String,
            deliveryFee: j["deliveryFee"] as? Double,
            shippingFee: j["shippingFee"] as? Double,
            settingsLastUpdatedAt: j["settingsLastUpdatedAt"] as? String,
            settingsLastUpdatedByUserId: j["settingsLastUpdatedByUserId"] as? String
        )
    }

    func setBusinessSettings(_ settings: BusinessSettings) async throws {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/settings/business")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = [
            "storeHours": settings.storeHours,
            "deliveryRadiusMiles": settings.deliveryRadiusMiles,
            "taxRate": settings.taxRate,
            "minimumOrderLeadTimeHours": settings.minimumOrderLeadTimeHours,
            "contactEmail": settings.contactEmail,
            "contactPhone": settings.contactPhone,
            "storeName": settings.storeName,
            "cashAppTag": settings.cashAppTag,
            "venmoUsername": settings.venmoUsername,
            "deliveryFee": settings.deliveryFee,
            "shippingFee": settings.shippingFee,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    // MARK: - Contact messages

    /// Submit a contact message (no auth required). orderId is optional (message about a specific order).
    func submitContactMessage(name: String?, email: String, subject: String?, message: String, userId: String?, orderId: String?) async throws {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/contact")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any?] = [
            "email": email,
            "message": message,
            "name": name,
            "subject": subject,
            "userId": userId,
        ]
        if let oid = orderId, !oid.isEmpty { body["orderId"] = oid }
        req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: String])?["error"] ?? "Failed to send message"
            throw VercelAPIError(message: msg, statusCode: http.statusCode)
        }
    }

    /// Fetch contact messages (admin only).
    func fetchContactMessages() async throws -> [ContactMessage] {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/contact")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode([ContactMessage].self, from: data)
    }

    /// Mark a contact message as read (admin only).
    func markContactMessageRead(id: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/contact/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    /// Send an in-app reply to a contact message (admin only).
    func replyToContactMessage(messageId: String, body: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/contact/\(messageId)/reply")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["body": body])
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    /// Send a new message from admin to a customer or all customers (admin only).
    /// Pass toUserId or toUserEmail to target one user; pass both nil to send to all customers.
    func sendAdminMessage(toUserId: String?, toUserEmail: String?, body: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/admin-messages")
        var payload: [String: String] = ["body": body]
        if let id = toUserId, !id.isEmpty { payload["toUserId"] = id }
        if let email = toUserEmail, !email.isEmpty { payload["toUserEmail"] = email }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }

    /// Fetch admin replies to the current user's contact messages (authenticated).
    func fetchContactReplies() async throws -> [ContactMessageReply] {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/contact/replies")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode([ContactMessageReply].self, from: data)
    }

    // MARK: - Promotions

    func fetchPromotions() async throws -> [Promotion] {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/promotions")
        let (data, res) = try await session.data(from: url)
        guard let http = res as? HTTPURLResponse else { return [] }
        try validateResponse(http, data: data)
        return try decoder.decode([Promotion].self, from: data)
    }

    func fetchPromotion(byCode code: String) async throws -> Promotion? {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let escaped = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        let url = base.appendingPathComponent("api/promotions/code/\(escaped)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        try validateResponse(http, data: data)
        return try decoder.decode(Promotion.self, from: data)
    }

    func addPromotion(_ promotion: Promotion) async throws -> String {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/promotions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "code": promotion.code,
            "discountType": promotion.discountType,
            "value": promotion.value,
            "validFrom": promotion.validFrom.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "validTo": promotion.validTo.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "isActive": promotion.isActive,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let created = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return created?["id"] as? String ?? ""
    }

    func updatePromotion(_ promotion: Promotion) async throws {
        guard let id = promotion.id, let base = baseURL, let token = authToken else { return }
        let url = base.appendingPathComponent("api/promotions/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["code": promotion.code, "discountType": promotion.discountType, "value": promotion.value, "isActive": promotion.isActive]
        if let d = promotion.validFrom { body["validFrom"] = ISO8601DateFormatter().string(from: d) }
        if let d = promotion.validTo { body["validTo"] = ISO8601DateFormatter().string(from: d) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func deletePromotion(id: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/promotions/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    // MARK: - Custom cake orders

    func saveCustomCakeOrder(_ order: CustomCakeOrder) async throws -> String {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/custom-cake-orders")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = authToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = [
            "userId": order.userId as Any,
            "size": order.size,
            "flavor": order.flavor,
            "frosting": order.frosting,
            "message": order.message,
            "designImageURL": order.designImageURL as Any,
            "price": order.price,
        ]
        if let tops = order.toppings, !tops.isEmpty { body["toppings"] = tops }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return j?["id"] as? String ?? ""
    }

    func updateCustomCakeOrder(_ order: CustomCakeOrder) async throws {
        guard let id = order.id, let base = baseURL else { return }
        let url = base.appendingPathComponent("api/custom-cake-orders/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [:]
        if let u = order.designImageURL { body["designImageURL"] = u }
        if let o = order.orderId { body["orderId"] = o }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func fetchCustomCakeOrders() async throws -> [CustomCakeOrder] {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/custom-cake-orders"))
        req.httpMethod = "GET"
        if let t = authToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return [] }
        try validateResponse(http, data: data)
        return try decoder.decode([CustomCakeOrder].self, from: data)
    }

    // MARK: - Custom cake options (builder choices: sizes, flavors, frostings)

    /// Public: fetch options for the Custom Cake Builder. Customer app uses this.
    func fetchCustomCakeOptions() async throws -> CustomCakeOptionsResponse {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/custom-cake-options")
        let (data, res) = try await session.data(from: url)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(CustomCakeOptionsResponse.self, from: data)
    }

    /// Admin: fetch options (same as public). Requires auth.
    func fetchCustomCakeOptionsSettings() async throws -> CustomCakeOptionsResponse {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/settings/custom-cake-options")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(CustomCakeOptionsResponse.self, from: data)
    }

    /// Admin: replace all sizes, flavors, frostings, toppings. Requires auth.
    func saveCustomCakeOptions(sizes: [CakeSizeOption], flavors: [CakeFlavorOption], frostings: [FrostingOption], toppings: [ToppingOption]) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/settings/custom-cake-options")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "sizes": sizes.map { ["label": $0.label, "price": $0.price, "sortOrder": $0.sortOrder as Any] },
            "flavors": flavors.map { ["label": $0.label, "sortOrder": $0.sortOrder as Any] },
            "frostings": frostings.map { ["label": $0.label, "sortOrder": $0.sortOrder as Any] },
            "toppings": toppings.map { ["label": $0.label, "price": $0.price, "sortOrder": $0.sortOrder as Any] },
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    // MARK: - AI cake designs

    func saveAICakeDesignOrder(_ order: AICakeDesignOrder) async throws -> String {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/ai-cake-designs")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = authToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = [
            "userId": order.userId as Any,
            "size": order.size,
            "flavor": order.flavor,
            "frosting": order.frosting,
            "designPrompt": order.designPrompt,
            "generatedImageURL": order.generatedImageURL as Any,
            "price": order.price,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return j?["id"] as? String ?? ""
    }

    func updateAICakeDesignOrder(_ order: AICakeDesignOrder) async throws {
        guard let id = order.id, let base = baseURL else { return }
        let url = base.appendingPathComponent("api/ai-cake-designs/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [:]
        if let u = order.generatedImageURL { body["generatedImageURL"] = u }
        if let o = order.orderId { body["orderId"] = o }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func fetchAICakeDesignOrders() async throws -> [AICakeDesignOrder] {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/ai-cake-designs"))
        req.httpMethod = "GET"
        if let t = authToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return [] }
        try validateResponse(http, data: data)
        return try decoder.decode([AICakeDesignOrder].self, from: data)
    }

    // MARK: - Product categories (owner can add/edit/delete)

    func fetchProductCategories() async throws -> [ProductCategoryItem] {
        guard let base = baseURL else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/product-categories")
        let (data, res) = try await session.data(from: url)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Request failed"
            throw VercelAPIError(message: msg, statusCode: http.statusCode)
        }
        return try decoder.decode([ProductCategoryItem].self, from: data)
    }

    func addProductCategory(name: String, displayOrder: Int = 0) async throws -> ProductCategoryItem {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/product-categories"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["name": name, "displayOrder": displayOrder]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(ProductCategoryItem.self, from: data)
    }

    func updateProductCategory(id: String, name: String? = nil, displayOrder: Int? = nil) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/product-categories/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        if let o = displayOrder { body["displayOrder"] = o }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func deleteProductCategory(id: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/product-categories/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        if http.statusCode == 400, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let msg = json["error"] {
            throw VercelAPIError(message: msg, statusCode: 400)
        }
        try validateResponse(http, data: data)
    }

    // MARK: - Saved customers (owner contact list)

    func fetchSavedCustomers() async throws -> [SavedCustomer] {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/customers"))
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode([SavedCustomer].self, from: data)
    }

    func addSavedCustomer(name: String, phone: String, email: String?, street: String?, addressLine2: String?, city: String?, state: String?, postalCode: String?, notes: String?) async throws -> SavedCustomer {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/customers"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["name": name, "phone": phone]
        if let e = email, !e.isEmpty { body["email"] = e }
        if let s = street, !s.isEmpty { body["street"] = s }
        if let a = addressLine2, !a.isEmpty { body["addressLine2"] = a }
        if let c = city, !c.isEmpty { body["city"] = c }
        if let s = state, !s.isEmpty { body["state"] = s }
        if let p = postalCode, !p.isEmpty { body["postalCode"] = p }
        if let n = notes, !n.isEmpty { body["notes"] = n }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(SavedCustomer.self, from: data)
    }

    func updateSavedCustomer(id: String, name: String?, phone: String?, email: String?, street: String?, addressLine2: String?, city: String?, state: String?, postalCode: String?, notes: String?) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/customers/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        if let p = phone { body["phone"] = p }
        if let e = email { body["email"] = e }
        if let s = street { body["street"] = s }
        if let a = addressLine2 { body["addressLine2"] = a }
        if let c = city { body["city"] = c }
        if let s = state { body["state"] = s }
        if let p = postalCode { body["postalCode"] = p }
        if let n = notes { body["notes"] = n }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func deleteSavedCustomer(id: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/customers/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    // MARK: - Cake gallery (owner showcase)

    func fetchGalleryCakes() async throws -> [GalleryCakeItem] {
        guard let url = apiURL(pathComponents: "api", "cake-gallery") else { throw VercelNotConfiguredError() }
        let (data, res) = try await session.data(from: url)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode([GalleryCakeItem].self, from: data)
    }

    func addGalleryCake(imageUrl: String, title: String, description: String?, category: String?, price: Double?) async throws -> GalleryCakeItem {
        guard let url = apiURL(pathComponents: "api", "cake-gallery"), authToken != nil else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(authToken!)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["imageUrl": imageUrl, "title": title]
        if let d = description, !d.isEmpty { body["description"] = d }
        if let c = category, !c.isEmpty { body["category"] = c }
        if let p = price { body["price"] = p }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(GalleryCakeItem.self, from: data)
    }

    func updateGalleryCake(id: String, imageUrl: String? = nil, title: String? = nil, description: String? = nil, category: String? = nil, price: Double? = nil, displayOrder: Int? = nil) async throws {
        guard let url = apiURL(pathComponents: "api", "cake-gallery", id), authToken != nil else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(authToken!)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [:]
        if let u = imageUrl { body["imageUrl"] = u }
        if let t = title { body["title"] = t }
        if let d = description { body["description"] = d }
        if let c = category { body["category"] = c }
        if let p = price { body["price"] = p }
        if let o = displayOrder { body["displayOrder"] = o }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    func deleteGalleryCake(id: String) async throws {
        guard let url = apiURL(pathComponents: "api", "cake-gallery", id), authToken != nil else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(authToken!)", forHTTPHeaderField: "Authorization")
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    // MARK: - Forgot password

    /// Request a password reset token for the given email. Returns token if account exists (in-app flow); nil if no account or Apple-only; token valid 1 hour.
    func requestPasswordReset(email: String) async throws -> String? {
        guard let url = apiURL(pathComponents: "api", "auth", "forgot-password") else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        if http.statusCode == 400 {
            let err = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Invalid request"
            throw VercelAPIError(message: err, statusCode: 400)
        }
        try validateResponse(http, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["token"] as? String
    }

    /// Set new password using a reset token from requestPasswordReset.
    func resetPassword(token: String, newPassword: String) async throws {
        guard let url = apiURL(pathComponents: "api", "auth", "reset-password") else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["token": token, "newPassword": newPassword])
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        if (400...499).contains(http.statusCode) {
            let err = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Invalid request"
            throw VercelAPIError(message: err, statusCode: http.statusCode)
        }
        try validateResponse(http, data: data)
    }

    /// Delete the current user's account and data (App Store requirement). Requires auth. Caller should sign out locally after.
    func deleteAccount() async throws {
        guard let url = apiURL(pathComponents: "api", "auth", "delete-account"),
              let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        if (400...499).contains(http.statusCode) {
            let err = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Could not delete account"
            throw VercelAPIError(message: err, statusCode: http.statusCode)
        }
        try validateResponse(http, data: data)
    }

    // MARK: - Push (admin new-order notifications)

    /// Register device token for new-order push. Admin only. Call when signed in as admin.
    func registerPushToken(deviceToken: String) async throws {
        guard let url = apiURL(pathComponents: "api", "push", "register"), let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["deviceToken": deviceToken])
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    // MARK: - Upload

    /// Upload image as multipart/form-data (recommended; avoids base64 size bloat and 4.5 MB limit).
    func uploadImage(data: Data, pathname: String? = nil) async throws -> String {
        guard let url = apiURL(pathComponents: "api", "upload") else { throw VercelNotConfiguredError() }
        let boundary = "Boundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        if let p = pathname, !p.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"pathname\"\r\n\r\n".data(using: .utf8)!)
            body.append(p.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        req.httpBody = body
        if let token = authToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (respData, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: respData)
        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        guard let urlString = json?["url"] as? String else { throw VercelAPIError(message: "No url in response") }
        return urlString
    }

    /// Upload image as JSON (base64). Use when multipart fails (e.g. on some serverless runtimes). 4.5 MB body limit.
    func uploadImageBase64(data: Data, pathname: String, contentType: String = "image/jpeg") async throws -> String {
        guard let url = apiURL(pathComponents: "api", "upload") else { throw VercelNotConfiguredError() }
        let base64 = data.base64EncodedString()
        let body: [String: Any] = ["base64": base64, "pathname": pathname, "contentType": contentType]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let token = authToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (respData, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: respData)
        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        guard let urlString = json?["url"] as? String else { throw VercelAPIError(message: "No url in response") }
        return urlString
    }

    // MARK: - Helpers

    private func validateResponse(_ http: HTTPURLResponse, data: Data) throws {
        guard (200...299).contains(http.statusCode) else {
            throw VercelAPIError.parse(http: http, data: data)
        }
    }

    private func orderPayload(from order: Order) -> [String: Any] {
        var payload: [String: Any] = [
            "userId": order.userId as Any,
            "customerName": order.customerName,
            "customerPhone": order.customerPhone,
            "items": order.items.map { item in
                [
                    "id": item.id,
                    "productId": item.productId,
                    "name": item.name,
                    "price": item.price,
                    "quantity": item.quantity,
                    "specialInstructions": item.specialInstructions,
                ] as [String: Any]
            },
            "subtotal": order.subtotal,
            "tax": order.tax,
            "total": order.total,
            "fulfillmentType": order.fulfillmentType,
            "status": order.status,
        ]
        if let e = order.customerEmail, !e.isEmpty { payload["customerEmail"] = e }
        if let a = order.deliveryAddress, !a.isEmpty { payload["deliveryAddress"] = a }
        if let d = order.scheduledPickupDate { payload["scheduledPickupDate"] = ISO8601DateFormatter().string(from: d) }
        if let s = order.stripePaymentIntentId { payload["stripePaymentIntentId"] = s }
        if let d = order.estimatedReadyTime { payload["estimatedReadyTime"] = ISO8601DateFormatter().string(from: d) }
        if let a = order.customCakeOrderIds { payload["customCakeOrderIds"] = a }
        if let a = order.aiCakeDesignIds { payload["aiCakeDesignIds"] = a }
        if let c = order.promoCode?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            payload["promoCode"] = c
        }
        return payload
    }
}

struct VercelNotConfiguredError: LocalizedError {
    var errorDescription: String? { "Vercel backend URL is not set in AppConstants.vercelBaseURLString." }
}

struct VercelAPIError: LocalizedError {
    let message: String
    var statusCode: Int?
    var requestId: String?
    /// Raw JSON (or fallback) for "Copy debug info" / support.
    var debugCopyPayload: String?
    var errorDescription: String? { message }

    /// Text to copy for support (includes request id when present).
    var supportDebugText: String {
        var lines = [message]
        if let c = statusCode { lines.append("HTTP status: \(c)") }
        if let r = requestId, !r.isEmpty { lines.append("requestId: \(r)") }
        if let raw = debugCopyPayload, !raw.isEmpty, raw != message { lines.append(raw) }
        return lines.joined(separator: "\n")
    }

    static func parse(http: HTTPURLResponse, data: Data) -> VercelAPIError {
        let raw = String(data: data, encoding: .utf8) ?? ""
        var msg = raw.isEmpty ? "Unknown error" : raw
        var requestId: String?
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let e = obj["error"] as? String, !e.isEmpty { msg = e }
            if let details = obj["details"] as? [[String: Any]] {
                for d in details {
                    if let r = d["requestId"] as? String, !r.isEmpty {
                        requestId = r
                        break
                    }
                }
            }
        }
        return VercelAPIError(message: msg, statusCode: http.statusCode, requestId: requestId, debugCopyPayload: raw.isEmpty ? nil : raw)
    }
}

struct OrderCreateResponse: Decodable {
    let id: String
    let subtotal: Double
    let tax: Double
    let total: Double
}

// MARK: - Bakery API (order status, refund, business hours, export CSV)

extension VercelService {
    /// Update order status and/or pickup/ready time. POST /api/orders/update-status
    func updateOrderStatus(orderId: String, status: String?, pickupTime: Date?, readyBy: Date?) async throws {
        var body: [String: Any] = ["orderId": orderId]
        if let s = status { body["status"] = s }
        let iso = ISO8601DateFormatter()
        if let d = pickupTime { body["pickup_time"] = iso.string(from: d) }
        if let d = readyBy { body["ready_by"] = iso.string(from: d) }
        try await post("/api/orders/update-status", body: body)
    }

    /// Refund order (full or partial). Admin only. POST /api/stripe/refund
    func refundOrder(orderId: String, amountCents: Int? = nil, reason: String? = nil) async throws {
        var body: [String: Any] = ["orderId": orderId]
        if let a = amountCents { body["amountCents"] = a }
        if let r = reason { body["reason"] = r }
        try await post("/api/stripe/refund", body: body)
    }

    /// Fetch business hours and lead time. GET /api/settings/business-hours
    func fetchBusinessHours() async throws -> BusinessHoursSettings {
        try await get("/api/settings/business-hours")
    }

    /// Update business hours (admin). PUT /api/settings/business-hours
    func updateBusinessHours(leadTimeHours: Int?, businessHours: [String: String?]?, minOrderCents: Int?, taxRatePercent: Double?) async throws {
        var body: [String: Any] = [:]
        if let v = leadTimeHours { body["lead_time_hours"] = v }
        if let v = businessHours { body["business_hours"] = v }
        if let v = minOrderCents { body["min_order_cents"] = v }
        if let v = taxRatePercent { body["tax_rate_percent"] = v }
        try await put("/api/settings/business-hours", body: body)
    }

    /// Export orders as CSV. GET /api/analytics/export?from=...&to=...
    func exportOrdersCSV(from: Date? = nil, to: Date? = nil) async throws -> Data {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var query: [String] = []
        if let f = from { query.append("from=\(fmt.string(from: f))") }
        if let t = to { query.append("to=\(fmt.string(from: t))") }
        let path = "/api/analytics/export" + (query.isEmpty ? "" : "?" + query.joined(separator: "&"))
        return try await getRaw(path)
    }

    /// Fetch events. GET /api/events. Returns empty array if endpoint missing.
    func fetchEvents() async throws -> [Event] {
        do {
            return try await get("/api/events")
        } catch {
            if (error as? VercelAPIError)?.statusCode == 404 { return [] }
            throw error
        }
    }

    /// Create event (admin). POST /api/events. Customers receive push notification.
    func createEvent(_ event: Event) async throws -> Event {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/events")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["title": event.title]
        if let d = event.eventDescription { body["description"] = d }
        if let d = event.startAt { body["start_at"] = ISO8601DateFormatter().string(from: d) }
        if let d = event.endAt { body["end_at"] = ISO8601DateFormatter().string(from: d) }
        if let u = event.imageURL { body["image_url"] = u }
        if let loc = event.location { body["location"] = loc }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
        return try decoder.decode(Event.self, from: data)
    }

    /// Update event (admin). PATCH /api/events/:id.
    func updateEvent(id: String, title: String?, eventDescription: String?, startAt: Date?, endAt: Date?, imageURL: String?, location: String?) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/events/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [:]
        if let t = title { body["title"] = t }
        if eventDescription != nil { body["description"] = eventDescription as Any }
        if startAt != nil { body["start_at"] = startAt.map { ISO8601DateFormatter().string(from: $0) } as Any }
        if endAt != nil { body["end_at"] = endAt.map { ISO8601DateFormatter().string(from: $0) } as Any }
        if imageURL != nil { body["image_url"] = imageURL as Any }
        if location != nil { body["location"] = location as Any }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    /// Delete event (admin). DELETE /api/events/:id.
    func deleteEvent(id: String) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        var req = URLRequest(url: base.appendingPathComponent("api/events/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: Data())
    }

    /// Fetch reviews. GET /api/reviews. Returns empty array if endpoint missing.
    func fetchReviews() async throws -> [Review] {
        do {
            return try await get("/api/reviews")
        } catch {
            if (error as? VercelAPIError)?.statusCode == 404 { return [] }
            throw error
        }
    }

    /// Fetch current user's review for an order (for "You rated this order" or to hide form). GET /api/reviews?orderId=xxx with auth.
    func fetchReviewForOrder(orderId: String) async throws -> Review? {
        guard let base = baseURL, let token = authToken else { return nil }
        var comp = URLComponents(url: base.appendingPathComponent("api/reviews"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "orderId", value: orderId)]
        var req = URLRequest(url: comp.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else { return nil }
        let list = try decoder.decode([Review].self, from: data)
        return list.first
    }

    /// Submit a review for a completed order (DoorDash-style). POST /api/reviews. Body: orderId, rating (1-5), text?.
    func submitReview(orderId: String, rating: Int, text: String?) async throws {
        guard let base = baseURL, let token = authToken else { throw VercelNotConfiguredError() }
        let url = base.appendingPathComponent("api/reviews")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["orderId": orderId, "rating": rating]
        if let t = text, !t.isEmpty { body["text"] = t }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw VercelAPIError(message: "Invalid response") }
        try validateResponse(http, data: data)
    }
}
