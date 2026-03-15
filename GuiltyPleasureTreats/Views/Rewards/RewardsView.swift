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
            VStack(alignment: .leading, spacing: 24) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) {
                        viewModel.clearMessages()
                    }
                }
                if let msg = viewModel.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
                }
                
                if !viewModel.isSignedIn {
                    signInPrompt
                } else {
                    pointsCard
                    rewardsSection
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadPoints() }
        .refreshable { await viewModel.loadPoints() }
    }
    
    private var signInPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 50))
                .foregroundStyle(AppConstants.Colors.accent)
            Text("Sign in to earn and redeem points")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Earn 1 point for every $1 spent. Redeem for free treats!")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var pointsCard: some View {
        VStack(spacing: 8) {
            if viewModel.isLoading && viewModel.points == 0 {
                ProgressView()
            } else {
                Text("\(viewModel.points)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppConstants.Colors.accent)
                Text("points available")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available rewards")
                .font(.title2)
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

/// Single reward: name, points cost, Redeem button (disabled if not enough points).
struct RewardRowView: View {
    let reward: RewardOption
    let currentPoints: Int
    let isLoading: Bool
    let onRedeem: () -> Void
    
    var canRedeem: Bool { currentPoints >= reward.pointsRequired && !isLoading }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.name)
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Text("\(reward.pointsRequired) points")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Spacer()
            Button(action: onRedeem) {
                Text("Redeem")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(canRedeem ? .white : AppConstants.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canRedeem ? AppConstants.Colors.accent : AppConstants.Colors.textSecondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
            }
            .disabled(!canRedeem)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}
