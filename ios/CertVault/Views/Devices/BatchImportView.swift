import SwiftUI
import HiconIcons

struct BatchImportView: View {
    @ObservedObject var vm: DeviceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    if vm.accounts.count > 1 {
                        DSGroupedCard {
                            VStack(alignment: .leading, spacing: DS.spacingMD) {
                                DSSectionHeader(L10n.account)
                                Picker(L10n.select, selection: $vm.selectedAccountId) {
                                    ForEach(vm.accounts) { acc in
                                        Text(acc.displayName).tag(acc.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.dsBrand)
                            }
                            .padding(DS.spacingLG)
                        }
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.BatchImport.section)
                            TextEditor(text: $text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.dsText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .padding(DS.spacingMD)
                                .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.radiusMD)
                                        .stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5)
                                )
                            Text(L10n.BatchImport.hint)
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        .padding(DS.spacingLG)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .foregroundStyle(Color.dsDanger)
                            .font(.caption)
                    }

                    DSPrimaryButton(
                        title: L10n.import,
                        isLoading: isLoading,
                        isDisabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        doImport()
                    }
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(L10n.BatchImport.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .alert(L10n.BatchImport.successTitle, isPresented: $success) {
                Button(L10n.ok) { dismiss() }
            } message: {
                Text(L10n.BatchImport.successMessage)
            }
        }
    }

    private func doImport() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await vm.batchRegister(text: text)
                success = true
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
