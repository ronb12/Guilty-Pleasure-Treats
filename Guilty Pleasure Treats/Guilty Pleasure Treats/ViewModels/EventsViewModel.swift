//
//  EventsViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads events for Events view.
//

import Combine
import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = VercelService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            events = try await api.fetchEvents()
        } catch {
            events = []
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
