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
    
    private let firebase = FirebaseService.shared
    private let auth = AuthService.shared
    
    var isAdmin: Bool { auth.isAdmin }
    
    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            if isAdmin {
                orders = try await firebase.fetchAllOrders()
            } else {
                orders = try await firebase.fetchOrders(userId: auth.currentUser?.uid)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updateStatus(order: Order, status: OrderStatus) async {
        guard let orderId = order.id else { return }
        do {
            try await firebase.updateOrderStatus(orderId: orderId, status: status)
            if status == .completed, let uid = order.userId, !uid.isEmpty {
                let pointsToAdd = Int(order.total)
                if pointsToAdd > 0 {
                    try? await firebase.addPoints(uid: uid, points: pointsToAdd)
                }
            }
            await loadOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
