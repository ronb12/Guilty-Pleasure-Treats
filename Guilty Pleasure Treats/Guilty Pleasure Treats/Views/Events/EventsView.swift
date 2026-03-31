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
                loadingPlaceholder
            } else if let msg = viewModel.errorMessage, viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load events", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text(msg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label("No events yet", systemImage: "calendar")
                } description: {
                    Text("Check back later for tastings, pop-ups, and more.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                eventsScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Events")
        .largeNavigationTitle()
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .macOSConstrainedContent()
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Loading events…")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tastings, pop-ups, and special dates—we’ll keep this list fresh.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.events) { event in
                        NavigationLink(value: event) {
                            EventCardView(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Card (list)

private struct EventCardView: View {
    let event: Event

    private static let cardRadius = AppConstants.Layout.cardCornerRadius

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = event.resolvedImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            AppConstants.Colors.primary.opacity(0.5)
                            ProgressView()
                        }
                        .frame(height: 140)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipped()
                    case .failure:
                        imageFallback
                            .frame(height: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
                .id(url.absoluteString)
                .frame(maxWidth: .infinity)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Self.cardRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: Self.cardRadius
                    )
                )
            }

            HStack(alignment: .top, spacing: 14) {
                if let start = event.startAt {
                    dateBadge(start: start, end: event.endAt)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let desc = event.eventDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    if let start = event.startAt {
                        Label(eventDateTimeCaption(start: start, end: event.endAt), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }

                    if let loc = event.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 4) {
                        Text("Details")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(AppConstants.Colors.accent)
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(AppConstants.Layout.cardPadding)
        }
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Self.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cardRadius)
                .stroke(AppConstants.Colors.accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private var imageFallback: some View {
        ZStack {
            AppConstants.Colors.accent.opacity(0.08)
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(AppConstants.Colors.accent.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private func dateBadge(start: Date, end: Date?) -> some View {
        let cal = Calendar.current
        let sameDay = end.map { cal.isDate($0, inSameDayAs: start) } ?? true

        return VStack(spacing: 2) {
            Text(start.formatted(.dateTime.month(.abbreviated)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppConstants.Colors.accent)
                .textCase(.uppercase)
            Text(start.formatted(.dateTime.day()))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppConstants.Colors.textPrimary)
            if let end, !sameDay {
                Text("–")
                    .font(.caption2)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                Text(end.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppConstants.Colors.accent)
                Text(end.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.textPrimary)
            }
        }
        .frame(minWidth: 52)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(AppConstants.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func eventDateTimeCaption(start: Date, end: Date?) -> String {
        let cal = Calendar.current
        if let end, !cal.isDate(end, inSameDayAs: start) {
            return "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .abbreviated, time: .shortened))"
        }
        if let end {
            return "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
        }
        return start.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Detail

struct EventDetailView: View {
    let event: Event

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let url = event.resolvedImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                AppConstants.Colors.primary.opacity(0.4)
                                ProgressView()
                            }
                            .frame(height: 220)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipped()
                        case .failure:
                            ZStack {
                                AppConstants.Colors.accent.opacity(0.08)
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(AppConstants.Colors.accent.opacity(0.5))
                            }
                            .frame(height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .id(url.absoluteString)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppConstants.Colors.textPrimary)

                    if let start = event.startAt {
                        Label(eventDetailDateCaption(start: start, end: event.endAt), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }

                    if let loc = event.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }

                    if let desc = event.eventDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Event")
        .inlineNavigationTitle()
    }

    private func eventDetailDateCaption(start: Date, end: Date?) -> String {
        let cal = Calendar.current
        if let end, !cal.isDate(end, inSameDayAs: start) {
            return "\(start.formatted(date: .long, time: .shortened)) through \(end.formatted(date: .long, time: .shortened))"
        }
        if let end {
            return "\(start.formatted(date: .long, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
        }
        return start.formatted(date: .long, time: .shortened)
    }
}

#if os(iOS)
#Preview("Events") {
    NavigationStack {
        EventsView()
    }
}
#endif
