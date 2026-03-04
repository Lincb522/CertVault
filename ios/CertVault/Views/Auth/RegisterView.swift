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

                    Spacer(minLength: 24)

                    registerCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    Spacer(minLength: geo.size.height * 0.05)
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
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animateIn = true
            }
        }
        .onChange(of: authVM.isLoggedIn) { loggedIn in
            if loggedIn { dismiss() }
        }
    }

    // MARK: - Header

    private var registerHeader: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

            VStack(spacing: 6) {
                Text("创建账号")
                    .font(.title.bold())
                    .foregroundStyle(Color.dsText)

                Text("注册后即可使用 CertVault")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
            }
        }
    }

    // MARK: - Register Card

    private var registerCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                inputField(icon: AppIcon.user, placeholder: "用户名") {
                    TextField("", text: $username, prompt: Text("用户名（至少 3 个字符）").foregroundColor(.dsMuted.opacity(0.6)))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Color.dsText)
                }

                inputField(icon: AppIcon.email, placeholder: "邮箱") {
                    TextField("", text: $email, prompt: Text("邮箱地址").foregroundColor(.dsMuted.opacity(0.6)))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Color.dsText)
                }

                codeField

                inputField(icon: AppIcon.lock, placeholder: "密码") {
                    SecureField("", text: $password, prompt: Text("密码（至少 6 位）").foregroundColor(.dsMuted.opacity(0.6)))
                        .textContentType(.newPassword)
                        .foregroundStyle(Color.dsText)
                }

                inputField(icon: AppIcon.lock, placeholder: "确认密码") {
                    SecureField("", text: $confirmPassword, prompt: Text("再次输入密码").foregroundColor(.dsMuted.opacity(0.6)))
                        .textContentType(.newPassword)
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

            registerButton

            loginLink
        }
        .padding(24)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    // MARK: - Code Field with Send Button

    private var codeField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                HIcon(AppIcon.code)
                    .foregroundStyle(Color.dsMuted)
                    .frame(width: 20)
                TextField("", text: $code, prompt: Text("验证码").foregroundColor(.dsMuted.opacity(0.6)))
                    .keyboardType(.numberPad)
                    .foregroundStyle(Color.dsText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.dsSurfaceLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )

            Button {
                Task { await authVM.sendCode(email: email) }
            } label: {
                Text(authVM.codeCooldown > 0 ? "\(authVM.codeCooldown)s" : "获取验证码")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [.dsAccentBlue, .dsAccentPurple],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .disabled(email.isEmpty || authVM.codeCooldown > 0 || authVM.isSendingCode)
            .opacity(email.isEmpty || authVM.codeCooldown > 0 ? 0.5 : 1)
        }
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

    // MARK: - Register Button

    private var registerButton: some View {
        Button {
            guard password == confirmPassword else {
                authVM.errorMessage = "两次密码输入不一致"
                return
            }
            Task {
                await authVM.register(username: username, email: email, code: code, password: password)
            }
        } label: {
            HStack(spacing: 8) {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("注  册")
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
        .disabled(!canRegister)
        .opacity(canRegister ? 1 : 0.5)
    }

    private var canRegister: Bool {
        !username.isEmpty && !email.isEmpty && !code.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && !authVM.isLoading
    }

    // MARK: - Login Link

    private var loginLink: some View {
        HStack(spacing: 4) {
            Text("已有账号？")
                .font(.footnote)
                .foregroundStyle(Color.dsMuted)
            Button {
                authVM.errorMessage = nil
                dismiss()
            } label: {
                Text("去登录")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.dsAccentBlue)
            }
        }
    }
}
