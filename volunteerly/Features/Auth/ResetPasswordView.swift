//
//  ResetPasswordView.swift
//  volunteerly
//
//  Created by Tevai Clavel on 4/6/2026.
//

import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var didSend = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if didSend {
                    confirmation
                } else {
                    form
                    submitButton
                }
                backToLogin
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(didSend ? "Check your inbox" : "Forgot password?")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(didSend
                 ? "We've sent a reset link to \(email). Follow the instructions in the email to set a new password."
                 : "Enter the email associated with your account and we'll send you a link to reset your password.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeled("Email") {
                pillField(icon: "envelope") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Send Reset Link").font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(isSubmitting || !isValidEmail)
        .opacity(isValidEmail ? 1 : 0.6)
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.success)
                Text("Reset link sent")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 1)
            )

            Button {
                didSend = false
            } label: {
                Text("Resend link")
                    .font(.headline)
                    .foregroundStyle(Theme.forest)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.forest, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    private var backToLogin: some View {
        HStack(spacing: 4) {
            Text("Remembered your password?")
                .foregroundStyle(Theme.textSecondary)
            Button("Log In") { dismiss() }
                .foregroundStyle(Theme.forest)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Helpers

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    private func pillField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.textSecondary)
            content()
                .font(.body)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: Actions

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        try? await Task.sleep(nanoseconds: 600_000_000)
        didSend = true
    }
}

#Preview {
    NavigationStack { ResetPasswordView() }
}
