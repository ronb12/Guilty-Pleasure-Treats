//
//  SplashView.swift
//  Guilty Pleasure Treats
//
//  Splash screen with branded logo, tagline, progress bar, and subtle motion.
//

import SwiftUI

struct SplashView: View {
    /// Match RootView splash duration so the progress bar fills in sync.
    static let splashDuration: TimeInterval = 1.4

    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var progress: CGFloat = 0
    @State private var floatOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    private var reduceMotion: Bool { accessibilityReduceMotion }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppConstants.Colors.primary.opacity(0.9),
                    AppConstants.Colors.secondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("LandingLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(y: floatOffset)
                    .accessibilityLabel("Guilty Pleasure Treats logo")

                Text("Every bite's a little indulgence")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .opacity(taglineOpacity)

                if !AppConstants.splashOwnerName.isEmpty {
                    VStack(spacing: 2) {
                        Text(AppConstants.splashOwnerName)
                            .font(Font.custom("Snell Roundhand", size: 26))
                            .foregroundStyle(AppConstants.Colors.textSecondary.opacity(0.95))
                        Text("owner")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary.opacity(0.85))
                    }
                    .opacity(taglineOpacity)
                }
            }
            .padding(.horizontal, 40)

            VStack {
                Spacer()
                progressBar
                    .padding(.horizontal, 48)
                    .padding(.bottom, 56)
            }
        }
        .onAppear {
            startEntranceAnimation()
            startProgressBar()
            if !reduceMotion {
                startFloatAnimation()
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppConstants.Colors.accent.opacity(0.2))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppConstants.Colors.accent)
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
    }

    private func startEntranceAnimation() {
        let duration: Double = reduceMotion ? 0.2 : 0.5
        withAnimation(.easeOut(duration: duration)) {
            scale = 1
            opacity = 1
        }
        withAnimation(.easeOut(duration: 0.35).delay(reduceMotion ? 0 : 0.35)) {
            taglineOpacity = 1
        }
    }

    private func startProgressBar() {
        withAnimation(.easeInOut(duration: Self.splashDuration)) {
            progress = 1
        }
    }

    private func startFloatAnimation() {
        withAnimation(
            .easeInOut(duration: 2.2)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = 5
        }
    }
}
