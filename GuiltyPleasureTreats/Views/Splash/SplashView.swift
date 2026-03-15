//
//  SplashView.swift
//  Guilty Pleasure Treats
//
//  Splash screen with logo and app name.
//

import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            AppConstants.Colors.secondary
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "cupcake.and.candles.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppConstants.Colors.accent)
                
                Text("Guilty Pleasure Treats")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1
                opacity = 1
            }
        }
    }
}
