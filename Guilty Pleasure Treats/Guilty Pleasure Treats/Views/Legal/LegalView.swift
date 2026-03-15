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
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DocumentView: View {
    let title: String
    let markdown: String

    var body: some View {
        ScrollView {
            Text(parsedMarkdown)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var parsedMarkdown: AttributedString {
        do {
            return try AttributedString(markdown: markdown)
        } catch {
            return AttributedString(markdown)
        }
    }
}
