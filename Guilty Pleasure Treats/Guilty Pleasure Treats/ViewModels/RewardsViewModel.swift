//
//  RewardsViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads user points, lists rewards, redeems (deduct points + add free item to cart).
//

import Combine
import Foundation

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var points: Int = 0
    @Published var availableRewards: [RewardOption] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let api = VercelService.shared
    private let auth = AuthService.shared
    private let cart = CartManager.shared
    
    var isSignedIn: Bool { auth.currentUser != nil }
    
    func loadPoints() async {
        guard let uid = auth.currentUser?.uid else {
            points = 0
            availableRewards = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let profileTask = api.fetchUserProfile(uid: uid)
            async let rewardsTask = api.fetchLoyaltyRewards(includeInactive: false)
            let profile = try await profileTask
            points = profile?.points ?? 0
            let items = try await rewardsTask
            availableRewards = items.compactMap { Self.rewardOption(from: $0) }
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            availableRewards = []
        }
    }
    
    private static func rewardOption(from item: LoyaltyRewardItem) -> RewardOption? {
        guard let p = item.product else { return nil }
        var free = p
        free.price = 0
        return RewardOption(
            serverId: item.id,
            name: item.name,
            pointsRequired: item.pointsRequired,
            productToAdd: free
        )
    }
    
    /// Redeem a reward: deduct points and add the free product to cart.
    func redeem(_ reward: RewardOption) async {
        guard let uid = auth.currentUser?.uid else {
            errorMessage = "Sign in to redeem rewards."
            return
        }
        guard let sid = reward.serverId, !sid.isEmpty else {
            errorMessage = "This reward is not available. Pull to refresh."
            return
        }
        guard points >= reward.pointsRequired else {
            errorMessage = "You need \(reward.pointsRequired) points. You have \(points)."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            try await api.redeemLoyaltyReward(rewardId: sid)
            let profile = try await api.fetchUserProfile(uid: uid)
            points = profile?.points ?? max(0, points - reward.pointsRequired)
            cart.add(product: reward.productToAdd, quantity: 1, specialInstructions: "")
            successMessage = "\(reward.name) added to cart!"
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
