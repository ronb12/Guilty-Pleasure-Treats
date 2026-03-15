//
//  MenuViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads products by category for Menu screen.
//

import Foundation
import Combine

@MainActor
final class MenuViewModel: ObservableObject {
    @Published var productsByCategory: [String: [Product]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebase = FirebaseService.shared
    private let categories = ProductCategory.allCases.map(\.rawValue)
    
    func loadMenu() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await firebase.fetchProducts()
            var grouped: [String: [Product]] = [:]
            for cat in categories {
                grouped[cat] = all.filter { $0.category == cat && !$0.isSoldOut }
            }
            productsByCategory = grouped
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
