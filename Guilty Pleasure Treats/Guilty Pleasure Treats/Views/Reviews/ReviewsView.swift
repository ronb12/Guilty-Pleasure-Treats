//
//  ReviewsView.swift
//  Guilty Pleasure Treats
//
//  Customer reviews.
//

import SwiftUI

struct ReviewsView: View {
    @StateObject private var viewModel = ReviewsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.reviews.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = viewModel.errorMessage, viewModel.reviews.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load reviews", systemImage: "star.slash")
                } description: {
                    Text(msg)
                }
            } else if viewModel.reviews.isEmpty {
                ContentUnavailableView {
                    Label("No reviews yet", systemImage: "text.quote")
                } description: {
                    Text("Be the first to leave a review after your order!")
                }
            } else {
                List {
                    ForEach(viewModel.reviews) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            if let rating = review.rating, rating > 0 {
                                HStack(spacing: 2) {
                                    ForEach(0..<min(rating, 5), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(AppConstants.Colors.accent)
                                    }
                                }
                            }
                            if let text = review.text, !text.isEmpty {
                                Text(text)
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.textPrimary)
                            }
                            if let name = review.authorName, !name.isEmpty {
                                Text("— \(name)")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Reviews")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
