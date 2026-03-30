//
//  CustomCakeOrderDetailView.swift
//  Guilty Pleasure Treats
//
//  Admin detail view for a custom cake order (special order).
//

import SwiftUI

struct CustomCakeOrderDetailView: View {
    let order: CustomCakeOrder

    /// Steps: Ordered → In order → Done. "In order" and "Done" when linked to main order (orderId set).
    private var customCakeTrackingSteps: [TrackingStepConfig] {
        let hasOrder = (order.orderId ?? "").isEmpty == false
        return [
            TrackingStepConfig(id: 0, label: "Ordered", isReached: true, isCurrent: !hasOrder),
            TrackingStepConfig(id: 1, label: "In order", isReached: hasOrder, isCurrent: false),
            TrackingStepConfig(id: 2, label: "Done", isReached: hasOrder, isCurrent: hasOrder),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                TrackingStatusBarView(
                    title: "Status",
                    subtitle: "Custom cake progress",
                    steps: customCakeTrackingSteps
                )
                detailsCard
                if !order.message.isEmpty {
                    messageCard
                }
                if let urlString = order.designImageURL, let url = URL(string: urlString) {
                    designImageCard(url: url)
                }
                totalCard
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
            .macOSSheetTopPadding()
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Custom cake · \(order.summary)")
        .inlineNavigationTitle()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(order.id.map { "Custom cake \(OrderReference.displayCode(from: $0))" } ?? "Custom cake order")
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Spacer()
            }
            if let date = order.createdAt {
                Text("Placed \(date.dateAndTimeString)")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let orderId = order.orderId, !orderId.isEmpty {
                Text("Main order: \(OrderReference.displayCode(from: orderId))")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            detailRow("Size", order.size)
            detailRow("Flavor", order.flavor)
            detailRow("Frosting", order.frosting)
            if let c = order.cakeColor?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
                detailRow("Color", c)
            }
            if let f = order.cakeFilling?.trimmingCharacters(in: .whitespacesAndNewlines), !f.isEmpty {
                detailRow("Fill", f)
            }
            if let tops = order.toppings, !tops.isEmpty {
                detailRow("Toppings", tops.joined(separator: ", "))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customer message")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text(order.message)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func designImageCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Design reference")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var totalCard: some View {
        HStack {
            Text("Total")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Spacer()
            Text(order.price.currencyFormatted)
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
}
