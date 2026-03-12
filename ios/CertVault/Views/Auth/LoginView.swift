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

                    Spacer(minLength: 40)

                    loginCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    Spacer(minLength: geo.size.height * 0.08)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
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
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.dsAccentBlue.opacity(0.2), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text("CertVault")
                    .font(.title.bold())
                    .foregroundStyle(Color.dsText)

                Text(L10n.Login.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
            }
        }
    }

    private var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && !authVM.isLoading
    }

    private var loginCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    HIcon(AppIcon.user)
                        .font(.body)
                        .foregroundStyle(Color.dsMuted)
                        .frame(width: 20)
                    TextField(L10n.Login.username, text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(14)
                .glassCard(cornerRadius: 12)

                HStack(spacing: 10) {
                    HIcon(AppIcon.lock)
                        .font(.body)
                        .foregroundStyle(Color.dsMuted)
                        .frame(width: 20)
                    SecureField(L10n.Login.password, text: $password)
                        .textContentType(.password)
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }

            if let error = authVM.errorMessage {
                HStack(spacing: 6) {
                    HIcon(AppIcon.warning).font(.caption)
                    Text(error).font(.caption)
                }
                .foregroundStyle(Color.dsAccentPink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            Button {
                Task { await authVM.login(username: username, password: password) }
            } label: {
                HStack(spacing: 8) {
                    if authVM.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text(L10n.Login.submit)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(canSubmit ? Color.white : Color.dsMuted)
                .background(
                    canSubmit ? Color.dsAccentBlue : Color.dsSurfaceLight,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .disabled(!canSubmit)

            registerLink
        }
        .padding(24)
        .glassCard(cornerRadius: 24)
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text(L10n.Login.noAccount)
                .font(.footnote)
                .foregroundStyle(Color.dsMuted)
            Button {
                authVM.errorMessage = nil
                showRegister = true
            } label: {
                Text(L10n.Login.goRegister)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dsAccentBlue)
            }
        }
    }
}
