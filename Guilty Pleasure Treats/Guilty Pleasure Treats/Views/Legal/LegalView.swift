//
//  LegalView.swift
//  Guilty Pleasure Treats
//
//  Privacy Policy and Terms of Service — list and document viewer.
//

import SwiftUI

struct LegalView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Privacy Policy") {
                    DocumentView(title: "Privacy Policy", markdown: LegalContent.privacyPolicyMarkdown)
                }
                NavigationLink("Terms of Service") {
                    DocumentView(title: "Terms of Service", markdown: LegalContent.termsOfServiceMarkdown)
                }
            } header: {
                Text("Legal")
            }
        }
        .navigationTitle("Legal")
        .inlineNavigationTitle()
    }
}

struct DocumentView: View {
    let title: String
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                accentBar
                documentCard
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.vertical, 20)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle(title)
        .inlineNavigationTitle()
    }

    private var accentBar: some View {
        Rectangle()
            .fill(AppConstants.Colors.accent)
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var documentCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            documentLabel
            Rectangle()
                .fill(AppConstants.Colors.accent.opacity(0.15))
                .frame(height: 1)
            documentBody
        }
        .padding(24)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                .stroke(AppConstants.Colors.accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var documentLabel: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(AppConstants.Colors.textSecondary)
    }

    /// Paragraphs split by double newlines, each rendered as markdown with spacing between.
    private var documentBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, block in
                if !block.isEmpty {
                    Text(attributed(for: block))
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                        .tint(AppConstants.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var paragraphs: [String] {
        let normalized = markdown
            .replacingOccurrences(of: "\\n[ \\t]*\\n", with: "\n\n", options: .regularExpression)
        return normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func attributed(for markdownBlock: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdownBlock)
        } catch {
            return AttributedString(markdownBlock)
        }
    }
}
