//
//  OrderTotalsBreakdownView.swift
//  Guilty Pleasure Treats
//
//  Subtotal, optional shipping/delivery and tip, tax, total — matches server orderTotals.js.
//

import SwiftUI

/// Shows how `order.total` was calculated (items subtotal + fees + tax + tip).
struct OrderTotalsBreakdownView: View {
    let order: Order
    /// When true, uses headline weight for the total row (order detail). Confirmation uses semibold only on label.
    var emphasizeTotal: Bool = true

    private var showFulfillmentFee: Bool {
        order.fulfillmentFeeDollars > 0.004
    }

    private var showTip: Bool {
        order.tipAmountDollars > 0.004
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            totalRow(label: "Subtotal", amount: order.subtotal, isTotal: false)
            if showFulfillmentFee {
                totalRow(label: order.fulfillmentFeeLineLabel, amount: order.fulfillmentFeeDollars, isTotal: false)
            }
            totalRow(label: "Tax", amount: order.tax, isTotal: false)
            if showTip {
                totalRow(label: "Tip", amount: order.tipAmountDollars, isTotal: false)
            }
            Divider()
            totalRow(label: "Total", amount: order.total, isTotal: true)
        }
    }

    @ViewBuilder
    private func totalRow(label: String, amount: Double, isTotal: Bool) -> some View {
        HStack {
            Text(label)
                .font(isTotal ? (emphasizeTotal ? .headline : .subheadline) : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
                .foregroundStyle(isTotal ? AppConstants.Colors.textPrimary : AppConstants.Colors.textSecondary)
            Spacer()
            Text(amount.currencyFormatted)
                .font(isTotal ? (emphasizeTotal ? .headline : .subheadline) : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
                .foregroundStyle(isTotal ? AppConstants.Colors.accent : AppConstants.Colors.textPrimary)
        }
    }
}
