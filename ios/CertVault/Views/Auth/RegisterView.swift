import SwiftUI
import HiconIcons

struct RegisterView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var animateIn = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.06)
                    registerHeader
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : -20)

                    Spacer(minLength: DS.spacing2XL)

                    registerCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    Spacer(minLength: geo.size.height * 0.05)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.spacing2XL)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background { AppBackground() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animateIn = true
            }
        }
        .onChange(of: authVM.isLoggedIn) { loggedIn in
            if loggedIn { dismiss() }
        }
    }

    private var registerHeader: some View {
        VStack(spacing: DS.spacingLG) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
                .shadow(color: Color.dsBrand.opacity(0.2), radius: 10, y: 4)

            VStack(spacing: 6) {
                Text(L10n.Register.title)
                    .font(.title.bold())
                    .foregroundStyle(Color.dsText)

                Text(L10n.Register.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
    }

    private var registerCard: some View {
        VStack(spacing: DS.spacingLG) {
            VStack(spacing: DS.spacingMD) {
                DSInputField(icon: AppIcon.user, placeholder: L10n.Register.usernameHint, text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                DSInputField(icon: AppIcon.email, placeholder: L10n.Register.emailHint, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                codeField

                DSInputField(icon: AppIcon.lock, placeholder: L10n.Register.passwordHint, text: $password, isSecure: true)
                    .textContentType(.newPassword)

                DSInputField(icon: AppIcon.lock, placeholder: L10n.Register.confirmPasswordHint, text: $confirmPassword, isSecure: true)
                    .textContentType(.newPassword)
            }

            if let error = authVM.errorMessage {
                HStack(spacing: 6) {
                    HIcon(AppIcon.warning).font(.caption)
                    Text(error).font(.caption)
                }
                .foregroundStyle(Color.dsDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.spacingXS)
            }

            DSPrimaryButton(
                title: L10n.Register.submit,
                isLoading: authVM.isLoading,
                isDisabled: !canRegister
            ) {
                guard password == confirmPassword else {
                    authVM.errorMessage = L10n.Register.passwordMismatch
                    return
                }
                Task {
                    await authVM.register(username: username, email: email, code: code, password: password)
                }
            }

            loginLink
        }
        .padding(DS.spacing2XL)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusXXL))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusXXL)
                .stroke(Color.dsBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private var codeField: some View {
        HStack(spacing: DS.spacingSM) {
            DSInputField(icon: AppIcon.code, placeholder: L10n.Register.verifyCode, text: $code)
                .keyboardType(.numberPad)

            Button {
                Task { await authVM.sendCode(email: email) }
            } label: {
                Text(authVM.codeCooldown > 0 ? L10n.Register.codeCooldown(authVM.codeCooldown) : L10n.Register.getCode)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.spacingMD)
                    .padding(.vertical, 15)
                    .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
            }
            .disabled(email.isEmpty || authVM.codeCooldown > 0 || authVM.isSendingCode)
            .opacity(email.isEmpty || authVM.codeCooldown > 0 ? 0.5 : 1)
        }
    }

    private var canRegister: Bool {
        !username.isEmpty && !email.isEmpty && !code.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && !authVM.isLoading
    }

    private var loginLink: some View {
        HStack(spacing: DS.spacingXS) {
            Text(L10n.Register.hasAccount)
                .font(.footnote)
                .foregroundStyle(Color.dsTextSecondary)
            Button {
                authVM.errorMessage = nil
                dismiss()
            } label: {
                Text(L10n.Register.goLogin)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dsBrand)
            }
        }
    }
}
