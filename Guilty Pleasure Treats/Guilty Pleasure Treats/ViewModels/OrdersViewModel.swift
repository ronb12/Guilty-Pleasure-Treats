//
//  OrdersViewModel.swift
//  Guilty Pleasure Treats
//
//  Fetches and displays user order history.
//

import Foundation
import Combine

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = VercelService.shared
    private let auth = AuthService.shared
    
    var isAdmin: Bool { auth.isAdmin }
    
    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        let signedIn = auth.currentUser != nil
        do {
            if !signedIn {
                // Signed-out users see no orders (backend also returns [] for no session)
                orders = []
                if VercelService.isConfigured {
                    errorMessage = "Sign in to see your orders."
                }
            } else if isAdmin {
                orders = try await api.fetchAllOrders()
                if orders.isEmpty { useSampleOrders() }
            } else {
                orders = try await api.fetchOrders(userId: auth.currentUser?.uid)
                if orders.isEmpty { useSampleOrders() }
            }
        } catch {
            if signedIn {
                useSampleOrders()
                if VercelService.isConfigured {
                    errorMessage = "Showing sample orders. Sign in or check your connection to load your orders."
                }
            } else {
                orders = []
            }
        }
        isLoading = false
    }

    /// Show sample orders when API returns none or fails, so the list has example data.
    private func useSampleOrders() {
        orders = SampleDataService.sampleOrders
    }
    
    /// Sample orders (id starts with "sample-") are for display only; they don't exist in the API.
    func isSampleOrder(_ order: Order) -> Bool {
        guard let id = order.id else { return false }
        return id.hasPrefix("sample-")
    }

    func updateStatus(order: Order, status: OrderStatus) async {
        guard let orderId = order.id else { return }
        if isSampleOrder(order) {
            errorMessage = nil
            return
        }
        do {
            try await api.updateOrderStatus(orderId: orderId, status: status)
            if status == .completed, let uid = order.userId, !uid.isEmpty {
                let pointsToAdd = Int(order.total)
                if pointsToAdd > 0 {
                    try? await api.addPoints(uid: uid, points: pointsToAdd)
                }
            }
            await loadOrders()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
