//
//  RewardsView.swift
//  Guilty Pleasure Treats
//
//  Loyalty rewards: current points, available rewards, redeem button.
//

import SwiftUI

struct RewardsView: View {
    @StateObject private var viewModel = RewardsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) {
                        viewModel.clearMessages()
                    }
                }
                if let msg = viewModel.successMessage {
                    successBanner(msg)
                }
                
                if !viewModel.isSignedIn {
                    signInPrompt
                } else {
                    pointsCard
                    howItWorksCard
                    rewardsSection
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(AppConstants.Colors.secondary)
        .macOSConstrainedContent()
        .navigationTitle("Rewards")
        .inlineNavigationTitle()
        .task { await viewModel.loadPoints() }
        .refreshable { await viewModel.loadPoints() }
    }
    
    private func successBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
            Text(msg)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
    }
    
    private var signInPrompt: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppConstants.Colors.accent.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "gift.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            VStack(spacing: 8) {
                Text("Sign in to earn rewards")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Earn 1 point for every $1 spent and redeem points for free treats.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    private var pointsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppConstants.Colors.accent)
                Text("Your balance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Spacer()
            }
            if viewModel.isLoading && viewModel.points == 0 {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.9)
                    Spacer()
                }
                .frame(height: 56)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.points)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text("pts")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AppConstants.Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                .stroke(AppConstants.Colors.accent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
    
    private var howItWorksCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(AppConstants.Colors.accent.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text("How it works")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Text("Earn 1 point per $1 spent. Redeem below for free items.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppConstants.Colors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
    }
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Redeem your points")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            
            ForEach(viewModel.availableRewards) { reward in
                RewardRowView(
                    reward: reward,
                    currentPoints: viewModel.points,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.redeem(reward) }
                }
            }
        }
    }
}

// MARK: - Reward row (single reward card)
struct RewardRowView: View {
    let reward: RewardOption
    let currentPoints: Int
    let isLoading: Bool
    let onRedeem: () -> Void
    
    private var canRedeem: Bool { currentPoints >= reward.pointsRequired && !isLoading }
    private var pointsNeeded: Int { max(0, reward.pointsRequired - currentPoints) }
    
    var body: some View {
        HStack(spacing: 16) {
            rewardIcon
            VStack(alignment: .leading, spacing: 6) {
                Text(reward.name)
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                HStack(spacing: 8) {
                    pointsBadge
                    if !canRedeem && pointsNeeded > 0 {
                        Text("• \(pointsNeeded) more to unlock")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 8)
            redeemButton
        }
        .padding(AppConstants.Layout.cardPadding)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
    
    private var rewardIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppConstants.Colors.accent.opacity(0.12))
                .frame(width: 52, height: 52)
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(AppConstants.Colors.accent)
        }
    }
    
    private var iconName: String {
        switch reward.productToAdd.category {
        case ProductCategory.cookies.rawValue: return "birthday.cake.fill"
        case ProductCategory.cupcakes.rawValue: return "cupcake.and.candles.fill"
        default: return "gift.fill"
        }
    }
    
    private var pointsBadge: some View {
        Text("\(reward.pointsRequired) pts")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppConstants.Colors.accent.opacity(0.12))
            .clipShape(Capsule())
    }
    
    private var redeemButton: some View {
        Button(action: onRedeem) {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white)
                } else {
                    Text("Redeem")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(canRedeem ? .white : AppConstants.Colors.textSecondary)
            .frame(minWidth: 88, minHeight: 40)
            .background(canRedeem ? AppConstants.Colors.accent : AppConstants.Colors.textSecondary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
        }
        .disabled(!canRedeem)
        .animation(.easeInOut(duration: 0.2), value: canRedeem)
    }
}
