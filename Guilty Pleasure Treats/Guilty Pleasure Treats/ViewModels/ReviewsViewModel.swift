//
//  ReviewsViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads reviews for Reviews view.
//

import Combine
import Foundation

@MainActor
final class ReviewsViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = VercelService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            reviews = try await api.fetchReviews()
        } catch {
            reviews = []
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
