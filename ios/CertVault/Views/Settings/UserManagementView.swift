import SwiftUI
import HiconIcons

struct UserManagementView: View {
    @StateObject private var vm = UserManagementViewModel()
    @State private var userToDelete: ManagedUser?
    @State private var userToResetPwd: ManagedUser?
    @State private var newPassword = ""
    @State private var showResetSheet = false

    var body: some View {
        Group {
            if vm.users.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: AppIcon.group,
                    title: L10n.UserMgmt.emptyTitle,
                    message: L10n.UserMgmt.emptyMessage
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.users.enumerated()), id: \.element.id) { index, user in
                            userRow(user)
                                .contextMenu { contextMenuItems(for: user) }

                            if index < vm.users.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.dsBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .pageBackground()
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle(L10n.UserMgmt.title)
        .overlay {
            if vm.isLoading && vm.users.isEmpty {
                LoadingView()
            }
        }
        .task { await vm.load() }
        .alert(L10n.UserMgmt.deleteTitle, isPresented: .init(
            get: { userToDelete != nil },
            set: { if !$0 { userToDelete = nil } }
        )) {
            Button(L10n.delete, role: .destructive) {
                if let user = userToDelete {
                    Task {
                        try? await vm.deleteUser(id: user.id)
                    }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            if let user = userToDelete {
                Text(L10n.UserMgmt.deleteMessage(user.username))
            }
        }
        .sheet(isPresented: $showResetSheet) {
            resetPasswordSheet
        }
        .alert(L10n.UserMgmt.resultTitle, isPresented: .init(
            get: { vm.successMessage != nil },
            set: { if !$0 { vm.successMessage = nil } }
        )) {
            Button(L10n.ok) {}
        } message: {
            Text(vm.successMessage ?? "")
        }
        .alert(L10n.error, isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button(L10n.ok) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func userRow(_ user: ManagedUser) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(user.role == "superadmin"
                          ? LinearGradient(colors: [.dsAccentPurple, .dsAccentPink], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [.dsAccentBlue, .dsAccentCyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Text(String(user.username.prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsText)
                    StatusBadge(
                        user.role == "superadmin" ? L10n.UserMgmt.roleSuper : L10n.UserMgmt.roleUser,
                        color: user.role == "superadmin" ? .dsAccentPurple : .dsAccentBlue
                    )
                }
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func contextMenuItems(for user: ManagedUser) -> some View {
        if user.role != "superadmin" {
            Button {
                Task {
                    let newRole = user.role == "user" ? "superadmin" : "user"
                    try? await vm.updateRole(id: user.id, role: newRole)
                }
            } label: {
                Label(
                    user.role == "user" ? NSLocalizedString("user.role.setSuper", comment: "") : NSLocalizedString("user.role.setUser", comment: ""),
                    systemImage: user.role == "user" ? "crown" : "person"
                )
            }

            Button {
                userToResetPwd = user
                newPassword = ""
                showResetSheet = true
            } label: {
                Label(L10n.UserMgmt.resetPassword, systemImage: "key")
            }

            Button(role: .destructive) {
                userToDelete = user
            } label: {
                Label(L10n.UserMgmt.deleteUser, systemImage: "trash")
            }
        }
    }

    private var resetPasswordSheet: some View {
        NavigationStack {
            Form {
                if let user = userToResetPwd {
                    Section {
                        HStack {
                            Text(NSLocalizedString("user.field.user", comment: "")).foregroundStyle(Color.dsMuted)
                            Spacer()
                            Text(user.username).foregroundStyle(Color.dsText)
                        }
                    }
                }
                Section(NSLocalizedString("user.newPassword", comment: "")) {
                    SecureField(NSLocalizedString("user.newPassword.hint", comment: ""), text: $newPassword)
                }
            }
            .navigationTitle(L10n.UserMgmt.resetPasswordTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { showResetSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.confirm) {
                        if let user = userToResetPwd {
                            Task {
                                try? await vm.resetPassword(id: user.id, newPassword: newPassword)
                                showResetSheet = false
                            }
                        }
                    }
                    .disabled(newPassword.count < 6)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - ViewModel

@MainActor
final class UserManagementViewModel: ObservableObject {
    @Published var users: [ManagedUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service = AuthService()

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await service.listUsers()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func updateRole(id: String, role: String) async throws {
        try await service.updateUserRole(id: id, role: role)
        successMessage = NSLocalizedString("user.roleUpdated", comment: "")
        await load()
    }

    func deleteUser(id: String) async throws {
        try await service.deleteUser(id: id)
        users.removeAll { $0.id == id }
        successMessage = NSLocalizedString("user.deleted", comment: "")
    }

    func resetPassword(id: String, newPassword: String) async throws {
        try await service.resetUserPassword(id: id, newPassword: newPassword)
        successMessage = NSLocalizedString("user.passwordReset", comment: "")
    }
}
