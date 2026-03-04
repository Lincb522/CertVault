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

                    Spacer(minLength: 32)

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
            AppLogger.ui.info("🖼️ LoginView appeared")
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

    // MARK: - Header

    private var appHeader: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

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

    // MARK: - Login Card

    private var loginCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                inputField(icon: AppIcon.user, placeholder: L10n.Login.username) {
                    TextField("", text: $username, prompt: Text(L10n.Login.username).foregroundColor(.dsMuted.opacity(0.6)))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Color.dsText)
                }

                inputField(icon: AppIcon.lock, placeholder: L10n.Login.password) {
                    SecureField("", text: $password, prompt: Text(L10n.Login.password).foregroundColor(.dsMuted.opacity(0.6)))
                        .textContentType(.password)
                        .foregroundStyle(Color.dsText)
                }
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

            loginButton

            registerLink
        }
        .padding(24)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    private func inputField<Content: View>(icon: UIImage, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            HIcon(icon)
                .foregroundStyle(Color.dsMuted)
                .frame(width: 20)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsSurfaceLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    // MARK: - Login Button

    private var loginButton: some View {
        Button {
            Task { await authVM.login(username: username, password: password) }
        } label: {
            HStack(spacing: 8) {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(L10n.Login.submit)
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [.dsAccentBlue, .dsAccentPurple],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .disabled(username.isEmpty || password.isEmpty || authVM.isLoading)
        .opacity(username.isEmpty || password.isEmpty ? 0.5 : 1)
    }

    // MARK: - Register Link

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
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.dsAccentBlue)
            }
        }
    }
}
