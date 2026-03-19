// Add this extension to your Order model. Add to Order: status, pickupTime, readyBy, tipCents, taxCents (all optional).
import Foundation

extension Order {
    /// Display label for order status.
    var statusDisplay: String {
        switch status?.lowercased() {
        case "pending": return "Pending"
        case "confirmed": return "Confirmed"
        case "in_progress": return "In progress"
        case "ready": return "Ready for pickup"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        default: return status ?? "Pending"
        }
    }

    /// Format tip for display (requires Order.tipCents).
    var tipFormatted: String? {
        guard let c = tipCents, c > 0 else { return nil }
        return String(format: "$%.2f", Double(c) / 100.0)
    }

    /// Format tax for display (requires Order.taxCents).
    var taxFormatted: String? {
        guard let c = taxCents, c > 0 else { return nil }
        return String(format: "$%.2f", Double(c) / 100.0)
    }
}
