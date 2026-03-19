//
//  TrackingStatusBarView.swift
//  Guilty Pleasure Treats
//
//  Reusable “Ordered → … → Done” style step bar for orders and message flows.
//

import SwiftUI

/// One step in a tracking bar (label + reached/current state).
struct TrackingStepConfig: Identifiable {
    let id: Int
    let label: String
    let isReached: Bool
    let isCurrent: Bool
}

/// Horizontal step bar: circles with labels and connectors. Use for custom cake, AI design, contact message flows.
struct TrackingStatusBarView: View {
    var title: String
    var subtitle: String?
    var steps: [TrackingStepConfig]
    var accentColor: Color = AppConstants.Colors.accent
    var reachedColor: Color = .green

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            if let sub = subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(step.isReached ? (step.isCurrent ? accentColor : reachedColor) : Color.gray.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                if step.isReached {
                                    Image(systemName: step.isCurrent ? "circle.fill" : "checkmark")
                                        .font(step.isCurrent ? .system(size: 10) : .caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(step.label)
                                .font(.caption2)
                                .foregroundStyle(step.isReached ? AppConstants.Colors.textPrimary : AppConstants.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 72)
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(step.isReached && !step.isCurrent ? reachedColor.opacity(0.6) : Color.gray.opacity(0.25))
                                .frame(height: 2)
                                .padding(.top, 14)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
}
