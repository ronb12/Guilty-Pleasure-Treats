//
//  PrimaryButton.swift
//  Guilty Pleasure Treats
//
//  Primary CTA button with bakery styling.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var disabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? AppConstants.Colors.textSecondary.opacity(0.5) : AppConstants.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
        }
        .disabled(disabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}
