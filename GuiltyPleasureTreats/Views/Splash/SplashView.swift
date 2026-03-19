//
//  SplashView.swift
//  Guilty Pleasure Treats
//
//  Full-screen splash: logo and app name. Shown on launch before main UI.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color("AppSecondary")
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image("LandingLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                Text("Guilty Pleasure Treats")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("AppTextPrimary"))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

#Preview {
    SplashView()
}
