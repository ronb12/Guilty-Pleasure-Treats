//
//  AICakeDesignOrderDetailView.swift
//  Guilty Pleasure Treats
//
//  Admin detail view for a gallery (AI cake design) order (special order).
//

import SwiftUI

struct AICakeDesignOrderDetailView: View {
    let order: AICakeDesignOrder

    /// Steps: Ordered → In order → Done. "In order" and "Done" when linked to main order (orderId set).
    private var aiDesignTrackingSteps: [TrackingStepConfig] {
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
                    subtitle: "AI design order progress",
                    steps: aiDesignTrackingSteps
                )
                detailsCard
                if !order.designPrompt.isEmpty {
                    promptCard
                }
                if let urlString = order.generatedImageURL, let url = URL(string: urlString) {
                    generatedImageCard(url: url)
                }
                totalCard
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
            .macOSSheetTopPadding()
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Gallery order · \(order.summary)")
        .inlineNavigationTitle()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(order.id.map { "Gallery order \(OrderReference.displayCode(from: $0))" } ?? "Gallery order")
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

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Design prompt")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text(order.designPrompt)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func generatedImageCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Generated design")
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
