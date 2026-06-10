//
//  volunteerlyApp.swift
//  volunteerly
//
//  Created by Eunkwang Shin on 3/6/2026.
//

import SwiftUI

@main
struct volunteerlyApp: App {
    @State private var router = AppRouter()
    @State private var profileStore = UserProfileStore()

    init() {
        MockData.registerAll(in: MockHTTPClient.shared)
        // Re-attach a persisted JWT so a returning user's authenticated
        // requests carry the Bearer header before any new login.
        AuthService.shared.restoreSession()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch router.route {
                case .splash:     SplashView()
                case .home:       HomeView()
                case .auth:       AuthFlowView()
                case .onboarding: WelcomeView()
                case .main:       MainTabView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.35), value: router.route)
            .keyboardDismissable()
            .environment(router)
            .environment(profileStore)
        }
    }
}
