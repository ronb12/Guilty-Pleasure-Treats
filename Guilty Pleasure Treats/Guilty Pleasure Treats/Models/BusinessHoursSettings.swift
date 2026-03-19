import Foundation

/// Business hours and lead time from GET /api/settings/business-hours
struct BusinessHoursSettings: Codable {
    var leadTimeHours: Int?
    var businessHours: [String: String?]?
    var minOrderCents: Int?
    var taxRatePercent: Double?

    enum CodingKeys: String, CodingKey {
        case leadTimeHours = "lead_time_hours"
        case businessHours = "business_hours"
        case minOrderCents = "min_order_cents"
        case taxRatePercent = "tax_rate_percent"
    }
}
