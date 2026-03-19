// Extension for Order: status display and formatted tax. Order.status is String; Order.tax is Double (dollars).
import Foundation

extension Order {
    /// Display label for order status.
    var statusDisplay: String {
        switch status.lowercased() {
        case "pending": return "Pending"
        case "confirmed": return "Confirmed"
        case "in_progress", "preparing": return "In progress"
        case "ready": return "Ready for pickup"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        default: return status.isEmpty ? "Pending" : status
        }
    }

    /// Format tip for display. Order has no tip field; override or add tipCents to Order if needed.
    var tipFormatted: String? {
        nil
    }

    /// Format tax for display (uses Order.tax in dollars).
    var taxFormatted: String? {
        guard tax > 0 else { return nil }
        return String(format: "$%.2f", tax)
    }
}
