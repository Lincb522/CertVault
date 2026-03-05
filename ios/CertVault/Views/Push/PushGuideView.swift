import SwiftUI
import HiconIcons

struct PushGuideView: View {
    @StateObject private var vm = PushViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingXL) {
                Picker("", selection: $selectedTab) {
                    Text(L10n.Push.guideMethods).tag(0)
                    Text(L10n.Push.guideServices).tag(1)
                    Text(L10n.Push.guideErrors).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.spacingLG)

                switch selectedTab {
                case 0: methodsSection
                case 1: servicesSection
                default: errorCodesSection
                }
            }
            .padding(.top, DS.spacingSM)
            .padding(.bottom, DS.spacing3XL)
        }
        .pageBackground()
        .navigationTitle(L10n.Push.guideTitle)
        .overlay {
            if !vm.guideLoaded && vm.errorCodes.isEmpty {
                LoadingView()
            }
        }
        .task {
            await vm.loadPushGuide()
            await vm.loadErrorCodes()
        }
    }

    // MARK: - Methods

    @ViewBuilder
    private var methodsSection: some View {
        if let methods = vm.pushGuide?.methods {
            ForEach(methods) { method in
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    HStack(spacing: DS.spacingMD) {
                        HIcon(method.id == "p8_key" ? AppIcon.pushKey : AppIcon.certificate)
                            .font(.body)
                            .foregroundStyle(method.id == "p8_key" ? Color.dsBlue : Color.dsWarning)
                            .frame(width: DS.iconXL, height: DS.iconXL)
                            .background(
                                (method.id == "p8_key" ? Color.dsBlue : Color.dsWarning).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: DS.radiusSM)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(method.name ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dsText)
                            if let desc = method.desc {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                    }

                    if let pros = method.pros, !pros.isEmpty {
                        tagSection(title: L10n.Push.guidePros, items: pros, color: .dsSuccess)
                    }

                    if let cons = method.cons, !cons.isEmpty {
                        tagSection(title: L10n.Push.guideCons, items: cons, color: .dsDanger)
                    }

                    if let steps = method.steps, !steps.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spacingXS) {
                            Text(L10n.Push.guideSteps)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dsTextSecondary)
                            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: DS.spacingSM) {
                                    Text("\(idx + 1)")
                                        .font(.caption2.weight(.bold).monospaced())
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.dsBlue, in: Circle())
                                    Text(step)
                                        .font(.caption)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                            }
                        }
                    }
                }
                .padding(DS.spacingLG)
                .cardStyle()
                .padding(.horizontal, DS.spacingLG)
            }
        } else {
            DSEmptyState(
                icon: AppIcon.info,
                title: L10n.Push.guideEmptyMethods
            )
            .padding(.vertical, DS.spacing3XL)
        }
    }

    // MARK: - Services

    @ViewBuilder
    private var servicesSection: some View {
        if let services = vm.pushGuide?.common_services, !services.isEmpty {
            DSGroupedCard {
                ForEach(Array(services.enumerated()), id: \.element.id) { idx, svc in
                    HStack(spacing: DS.spacingMD) {
                        HIcon(AppIcon.link)
                            .font(.caption)
                            .foregroundStyle(Color.dsCyan)
                            .frame(width: DS.iconXL, height: DS.iconXL)
                            .background(Color.dsCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(svc.name ?? "")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                            if let config = svc.config {
                                Text(config)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                        Spacer()
                        if let url = svc.url, let u = URL(string: url) {
                            Link(destination: u) {
                                HIcon(AppIcon.link)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsBrand)
                            }
                        }
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)

                    if idx < services.count - 1 {
                        DSDivider(leadingPadding: DS.spacingLG + DS.iconXL + DS.spacingMD)
                    }
                }
            }
            .padding(.horizontal, DS.spacingLG)
        } else {
            DSEmptyState(
                icon: AppIcon.link,
                title: L10n.Push.guideEmptyServices
            )
            .padding(.vertical, DS.spacing3XL)
        }
    }

    // MARK: - Error Codes

    @ViewBuilder
    private var errorCodesSection: some View {
        if !vm.errorCodes.isEmpty {
            DSGroupedCard {
                ForEach(Array(vm.errorCodes.enumerated()), id: \.element.id) { idx, err in
                    HStack(alignment: .top, spacing: DS.spacingMD) {
                        Text("\(err.code ?? 0)")
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(codeColor(err.code ?? 0))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(err.reason ?? "")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dsText)
                            if let desc = err.desc {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)

                    if idx < vm.errorCodes.count - 1 {
                        DSDivider(leadingPadding: 52)
                    }
                }
            }
            .padding(.horizontal, DS.spacingLG)
        } else {
            DSEmptyState(
                icon: AppIcon.warning,
                title: L10n.Push.guideEmptyErrors
            )
            .padding(.vertical, DS.spacing3XL)
        }
    }

    // MARK: - Helpers

    private func tagSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingXS) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: DS.spacingXS) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .padding(.top, 5)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
    }

    private func codeColor(_ code: Int) -> Color {
        switch code {
        case 200: return .dsSuccess
        case 400...499: return .dsWarning
        case 500...599: return .dsDanger
        default: return .dsTextSecondary
        }
    }
}
