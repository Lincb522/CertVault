import SwiftUI
import HiconIcons

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var animateIn = false
    @State private var showRegister = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.10)
                    appHeader
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : -20)

                    Spacer(minLength: DS.spacing3XL)

                    loginCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    Spacer(minLength: geo.size.height * 0.08)
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
            if let saved = UserDefaults.standard.string(forKey: AppConstants.usernameKey) {
                username = saved
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animateIn = true
            }
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(authVM)
        }
    }

    private var appHeader: some View {
        VStack(spacing: DS.spacingLG) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusXL))
                .shadow(color: Color.dsBrand.opacity(0.2), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text("CertVault")
                    .font(.title.bold())
                    .foregroundStyle(Color.dsText)

                Text(L10n.Login.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
    }

    private var loginCard: some View {
        VStack(spacing: DS.spacingXL) {
            VStack(spacing: DS.spacingMD) {
                DSInputField(icon: AppIcon.user, placeholder: L10n.Login.username, text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                DSInputField(icon: AppIcon.lock, placeholder: L10n.Login.password, text: $password, isSecure: true)
                    .textContentType(.password)
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
                title: L10n.Login.submit,
                isLoading: authVM.isLoading,
                isDisabled: username.isEmpty || password.isEmpty
            ) {
                Task { await authVM.login(username: username, password: password) }
            }

            registerLink
        }
        .padding(DS.spacing2XL)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusXXL))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusXXL)
                .stroke(Color.dsBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private var registerLink: some View {
        HStack(spacing: DS.spacingXS) {
            Text(L10n.Login.noAccount)
                .font(.footnote)
                .foregroundStyle(Color.dsTextSecondary)
            Button {
                authVM.errorMessage = nil
                showRegister = true
            } label: {
                Text(L10n.Login.goRegister)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dsBrand)
            }
        }
    }
}
