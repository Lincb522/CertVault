import SwiftUI
import HiconIcons

struct CreateBundleIDView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.BundleID.identifier)
                            DSInputField(icon: AppIcon.bundleID, placeholder: "com.example.myapp", text: $identifier)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Text(L10n.BundleID.identifierHint)
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        .padding(DS.spacingLG)
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(NSLocalizedString("common.name", comment: ""))
                            DSInputField(icon: AppIcon.edit, placeholder: "My App", text: $name)
                        }
                        .padding(DS.spacingLG)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .foregroundStyle(Color.dsDanger)
                            .font(.caption)
                    }

                    DSPrimaryButton(
                        title: L10n.create,
                        isLoading: isLoading,
                        isDisabled: identifier.isEmpty || name.isEmpty
                    ) {
                        isLoading = true
                        errorMsg = nil
                        Task {
                            do {
                                try await vm.createBundleId(identifier: identifier, name: name)
                                dismiss()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(L10n.BundleID.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }
}
