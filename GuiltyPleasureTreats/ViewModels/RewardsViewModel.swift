//
//  RewardsViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads user points, lists rewards, redeems (deduct points + add free item to cart).
//

import Foundation

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var points: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let firebase = FirebaseService.shared
    private let auth = AuthService.shared
    private let cart = CartManager.shared
    
    var isSignedIn: Bool { auth.currentUser != nil }
    var availableRewards: [RewardOption] { Rewards.all }
    
    func loadPoints() async {
        guard let uid = auth.currentUser?.uid else {
            points = 0
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let profile = try await firebase.fetchUserProfile(uid: uid)
            points = profile?.points ?? 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Redeem a reward: deduct points and add the free product to cart.
    func redeem(_ reward: RewardOption) async {
        guard let uid = auth.currentUser?.uid else {
            errorMessage = "Sign in to redeem rewards."
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
            let ok = try await firebase.redeemPoints(uid: uid, points: reward.pointsRequired)
            guard ok else {
                errorMessage = "Not enough points."
                return
            }
            points -= reward.pointsRequired
            cart.add(product: reward.productToAdd, quantity: 1, specialInstructions: "")
            successMessage = "\(reward.name) added to cart!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
