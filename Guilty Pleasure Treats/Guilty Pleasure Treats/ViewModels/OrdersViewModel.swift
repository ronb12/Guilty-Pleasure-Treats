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
            } else {
                orders = try await api.fetchOrders(userId: auth.currentUser?.uid)
            }
        } catch {
            if signedIn {
                orders = []
                if VercelService.isConfigured {
                    errorMessage = "Couldn’t load orders. Check your connection and try again."
                }
            } else {
                orders = []
            }
        }
        isLoading = false
    }
    
    /// Legacy: ids starting with `sample-` (old demo data) are ignored for API updates.
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
            // Loyalty points for completed orders are awarded once on the server (idempotent).
            await loadOrders()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
