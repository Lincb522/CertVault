import SwiftUI
import HiconIcons

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var animateIn = false
    @State private var showRegister = false
    @State private var logoFloat = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: geo.size.height * 0.12)

                        appHeader
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : -16)

                        Spacer(minLength: DS.spacing3XL)

                        loginCard
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 16)

                        Spacer(minLength: geo.size.height * 0.10)
                    }
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: 400)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.spacing2XL)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background { AppBackground() }
            .navigationBarHidden(true)
        }
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: AppConstants.usernameKey) {
                username = saved
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView().environmentObject(authVM)
        }
    }

    // MARK: - Header

    private var appHeader: some View {
        VStack(spacing: DS.spacingLG) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                .offset(y: logoFloat ? -4 : 4)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: logoFloat)
                .onAppear { logoFloat = true }

            VStack(spacing: DS.spacingSM) {
                Text("CertVault")
                    .font(.title.bold())
                    .foregroundStyle(Color.dsText)
                Text(L10n.Login.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
    }

    // MARK: - Login Card

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
            }

            DSPrimaryButton(
                title: L10n.Login.submit,
                isLoading: authVM.isLoading,
                isDisabled: username.isEmpty || password.isEmpty
            ) {
                Task { await authVM.login(username: username, password: password) }
            }

            HStack(spacing: 4) {
                Text(L10n.Login.noAccount)
                    .font(.footnote)
                    .foregroundStyle(Color.dsTextSecondary)
                Button {
                    authVM.errorMessage = nil
                    showRegister = true
                } label: {
                    Text(L10n.Login.goRegister)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.dsBrand)
                }
            }

            agreementLinks
        }
        .padding(DS.spacing2XL)
        .cardStyle()
    }

    @State private var showTerms = false
    @State private var showPrivacy = false

    private var agreementLinks: some View {
        HStack(spacing: 4) {
            Text("登录即表示同意")
                .font(.caption2)
                .foregroundStyle(Color.dsTextTertiary)
            Button { showTerms = true } label: {
                Text("用户协议")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.dsBrand)
            }
            Text("与")
                .font(.caption2)
                .foregroundStyle(Color.dsTextTertiary)
            Button { showPrivacy = true } label: {
                Text("隐私政策")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.dsBrand)
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack { TermsOfServiceView() }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyPolicyView() }
        }
    }
}
