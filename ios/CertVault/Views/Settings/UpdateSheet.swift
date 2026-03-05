import SwiftUI
import HiconIcons

struct UpdateSheet: View {
    @EnvironmentObject private var updateService: UpdateService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        Spacer().frame(height: DS.spacingSM)

                        ZStack {
                            Circle()
                                .fill(Color.dsBrandGradient)
                                .frame(width: 80, height: 80)
                            HIcon(AppIcon.download)
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: DS.spacingSM) {
                            Text(NSLocalizedString("update.title", comment: ""))
                                .font(.title2.bold())
                                .foregroundStyle(Color.dsText)

                            if let info = updateService.latestVersion {
                                Text("v\(info.version) (Build \(info.build ?? "1"))")
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(Color.dsTextSecondary)
                            }

                            Text(NSLocalizedString("update.currentVersion", comment: "") +
                                 " v\(updateService.currentVersion) (\(updateService.currentBuild))")
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }

                        if let changelog = updateService.latestVersion?.changelog, !changelog.isEmpty {
                            VStack(alignment: .leading, spacing: DS.spacingSM) {
                                Text(NSLocalizedString("update.changelog", comment: ""))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.dsText)
                                Text(changelog)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsTextSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(DS.spacingLG)
                            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusMD))
                            .overlay(RoundedRectangle(cornerRadius: DS.radiusMD).stroke(Color.dsBorder, lineWidth: 1))
                            .padding(.horizontal, DS.spacing2XL)
                        }
                    }
                }

                VStack(spacing: DS.spacingMD) {
                    Button { dismiss() } label: {
                        Text(NSLocalizedString("update.later", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                .padding(.bottom, DS.spacing2XL)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        HIcon(AppIcon.close).font(.body)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
