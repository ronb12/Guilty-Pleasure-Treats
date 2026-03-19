//
//  VercelService+BakeryAPI.swift
//  Guilty Pleasure Treats
//
//  Add these methods to VercelService, or ensure VercelService has post(_:body:), get(_:), put(_:body:)
//  and optionally getRaw(_:) for CSV. Base URL and auth should be handled inside VercelService.
//

import Foundation

extension VercelService {

    /// Update order status and/or pickup/ready time. POST /api/orders/update-status
    func updateOrderStatus(orderId: String, status: String?, pickupTime: Date?, readyBy: Date?) async throws {
        var body: [String: Any] = ["orderId": orderId]
        if let s = status { body["status"] = s }
        let iso = ISO8601DateFormatter()
        if let d = pickupTime { body["pickup_time"] = iso.string(from: d) }
        if let d = readyBy { body["ready_by"] = iso.string(from: d) }
        try await post("/orders/update-status", body: body)
    }

    /// Refund order (full or partial). Admin only. POST /api/stripe/refund
    func refundOrder(orderId: String, amountCents: Int? = nil, reason: String? = nil) async throws {
        var body: [String: Any] = ["orderId": orderId]
        if let a = amountCents { body["amountCents"] = a }
        if let r = reason { body["reason"] = r }
        try await post("/stripe/refund", body: body)
    }

    /// Fetch business hours and lead time. GET /api/settings/business-hours
    func fetchBusinessHours() async throws -> BusinessHoursSettings {
        try await get("/settings/business-hours")
    }

    /// Update business hours (admin). PUT /api/settings/business-hours
    func updateBusinessHours(leadTimeHours: Int?, businessHours: [String: String?]?, minOrderCents: Int?, taxRatePercent: Double?) async throws {
        var body: [String: Any] = [:]
        if let v = leadTimeHours { body["lead_time_hours"] = v }
        if let v = businessHours { body["business_hours"] = v }
        if let v = minOrderCents { body["min_order_cents"] = v }
        if let v = taxRatePercent { body["tax_rate_percent"] = v }
        try await put("/settings/business-hours", body: body)
    }

    /// Export orders as CSV. GET /api/analytics/export?from=...&to=...
    func exportOrdersCSV(from: Date? = nil, to: Date? = nil) async throws -> Data {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var query: [String] = []
        if let f = from { query.append("from=\(fmt.string(from: f))") }
        if let t = to { query.append("to=\(fmt.string(from: t))") }
        let path = "/analytics/export" + (query.isEmpty ? "" : "?" + query.joined(separator: "&"))
        return try await getRaw(path)
    }
}

// MARK: - Required VercelService API (add to VercelService if not present)
//
// func post(_ path: String, body: [String: Any]) async throws
// func put(_ path: String, body: [String: Any]) async throws
// func get<T: Decodable>(_ path: String) async throws -> T
// func getRaw(_ path: String) async throws -> Data
