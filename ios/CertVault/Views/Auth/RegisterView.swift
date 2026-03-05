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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case username, email, code, password, confirm }

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
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.spacing2XL)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background { AppBackground() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { animateIn = true }
        }
        .onChange(of: authVM.isLoggedIn) { loggedIn in
            if loggedIn { dismiss() }
        }
    }

    // MARK: - Header

    private var registerHeader: some View {
        VStack(spacing: DS.spacingLG) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

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

    // MARK: - Register Card

    private var registerCard: some View {
        VStack(spacing: DS.spacingLG) {
            VStack(spacing: DS.spacingMD) {
                DSInputFieldBuilder(icon: AppIcon.user, focused: focusedField == .username) {
                    TextField("", text: $username,
                              prompt: Text(L10n.Register.usernameHint).foregroundColor(.dsTextTertiary))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Color.dsText)
                        .focused($focusedField, equals: .username)
                }

                DSInputFieldBuilder(icon: AppIcon.email, focused: focusedField == .email) {
                    TextField("", text: $email,
                              prompt: Text(L10n.Register.emailHint).foregroundColor(.dsTextTertiary))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Color.dsText)
                        .focused($focusedField, equals: .email)
                }

                codeField

                DSInputFieldBuilder(icon: AppIcon.lock, focused: focusedField == .password) {
                    SecureField("", text: $password,
                                prompt: Text(L10n.Register.passwordHint).foregroundColor(.dsTextTertiary))
                        .textContentType(.newPassword)
                        .foregroundStyle(Color.dsText)
                        .focused($focusedField, equals: .password)
                }

                DSInputFieldBuilder(icon: AppIcon.lock, focused: focusedField == .confirm) {
                    SecureField("", text: $confirmPassword,
                                prompt: Text(L10n.Register.confirmPasswordHint).foregroundColor(.dsTextTertiary))
                        .textContentType(.newPassword)
                        .foregroundStyle(Color.dsText)
                        .focused($focusedField, equals: .confirm)
                }
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

            HStack(spacing: 4) {
                Text(L10n.Register.hasAccount)
                    .font(.footnote)
                    .foregroundStyle(Color.dsTextSecondary)
                Button {
                    authVM.errorMessage = nil
                    dismiss()
                } label: {
                    Text(L10n.Register.goLogin)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.dsBrand)
                }
            }
        }
        .padding(DS.spacing2XL)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusXL)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
    }

    // MARK: - Code Field

    private var codeField: some View {
        HStack(spacing: DS.spacingSM) {
            DSInputFieldBuilder(icon: AppIcon.code, focused: focusedField == .code) {
                TextField("", text: $code,
                          prompt: Text(L10n.Register.verifyCode).foregroundColor(.dsTextTertiary))
                    .keyboardType(.numberPad)
                    .foregroundStyle(Color.dsText)
                    .focused($focusedField, equals: .code)
            }

            Button {
                Task { await authVM.sendCode(email: email) }
            } label: {
                Text(authVM.codeCooldown > 0 ? L10n.Register.codeCooldown(authVM.codeCooldown) : L10n.Register.getCode)
                    .font(.footnote.weight(.medium))
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
        !username.isEmpty && !email.isEmpty && !code.isEmpty &&
        !password.isEmpty && !confirmPassword.isEmpty && !authVM.isLoading
    }
}
