//
//  EventsView.swift
//  Guilty Pleasure Treats
//
//  List of bakery events (tastings, pop-ups, etc.).
//

import SwiftUI

struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = viewModel.errorMessage, viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load events", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text(msg)
                }
            } else if viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label("No events yet", systemImage: "calendar")
                } description: {
                    Text("Check back later for tastings, pop-ups, and more.")
                }
            } else {
                List {
                    ForEach(viewModel.events) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.title)
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            if let desc = event.eventDescription, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                            if let start = event.startAt {
                                Label(start.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                            if let loc = event.location, !loc.isEmpty {
                                Label(loc, systemImage: "mappin.circle")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Events")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
