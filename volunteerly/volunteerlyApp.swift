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

    init() {
        MockData.registerAll(in: MockHTTPClient.shared)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.route {
                case .splash:     SplashView()
                case .auth:       AuthFlowView()
                case .onboarding: OnboardingView()
                case .main:       MainTabView()
                }
            }
            .environment(router)
        }
    }
}

