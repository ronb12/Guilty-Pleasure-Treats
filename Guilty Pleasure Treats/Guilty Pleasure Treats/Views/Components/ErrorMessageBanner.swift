//
//  ErrorMessageBanner.swift
//  Guilty Pleasure Treats
//

import SwiftUI

struct ErrorMessageBanner: View {
    let message: String
    let dismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Button("Dismiss", action: dismiss)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
    }
}
