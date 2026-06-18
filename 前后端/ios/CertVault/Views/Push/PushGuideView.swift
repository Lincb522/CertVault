import SwiftUI
import HiconIcons

struct PushGuideView: View {
    @StateObject private var vm = PushViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("", selection: $selectedTab) {
                    Text(L10n.Push.guideMethods).tag(0)
                    Text(L10n.Push.guideServices).tag(1)
                    Text(L10n.Push.guideErrors).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                switch selectedTab {
                case 0: methodsSection
                case 1: servicesSection
                default: errorCodesSection
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        HIcon(method.id == "p8_key" ? AppIcon.pushKey : AppIcon.certificate)
                            .font(.body)
                            .foregroundStyle(method.id == "p8_key" ? Color.dsAccentBlue : Color.dsAccentOrange)
                            .frame(width: 36, height: 36)
                            .background(
                                (method.id == "p8_key" ? Color.dsAccentBlue : Color.dsAccentOrange).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(method.name ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dsText)
                            if let desc = method.desc {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
                            }
                        }
                    }

                    if let pros = method.pros, !pros.isEmpty {
                        tagSection(title: L10n.Push.guidePros, items: pros, color: .dsAccent)
                    }

                    if let cons = method.cons, !cons.isEmpty {
                        tagSection(title: L10n.Push.guideCons, items: cons, color: .dsAccentPink)
                    }

                    if let steps = method.steps, !steps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.Push.guideSteps)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dsMuted)
                            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(idx + 1)")
                                        .font(.caption2.weight(.bold).monospaced())
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.dsAccentBlue, in: Circle())
                                    Text(step)
                                        .font(.caption)
                                        .foregroundStyle(Color.dsText.opacity(0.85))
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 14)
                .padding(.horizontal, 16)
            }
        } else {
            emptyPlaceholder(L10n.Push.guideEmptyMethods)
        }
    }

    // MARK: - Services

    @ViewBuilder
    private var servicesSection: some View {
        if let services = vm.pushGuide?.common_services, !services.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(services.enumerated()), id: \.element.id) { idx, svc in
                    HStack(spacing: 12) {
                        HIcon(AppIcon.link)
                            .font(.caption)
                            .foregroundStyle(Color.dsAccentCyan)
                            .frame(width: 32, height: 32)
                            .background(Color.dsAccentCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(svc.name ?? "")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                            if let config = svc.config {
                                Text(config)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
                            }
                        }
                        Spacer()
                        if let url = svc.url, let u = URL(string: url) {
                            Link(destination: u) {
                                HIcon(AppIcon.link)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsAccentBlue)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                    if idx < services.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 16)
        } else {
            emptyPlaceholder(L10n.Push.guideEmptyServices)
        }
    }

    // MARK: - Error Codes

    @ViewBuilder
    private var errorCodesSection: some View {
        if !vm.errorCodes.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(vm.errorCodes.enumerated()), id: \.element.id) { idx, err in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(err.code ?? 0)")
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(codeColor(err.code ?? 0))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(err.reason ?? "")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dsText)
                            if let desc = err.desc {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsMuted)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)

                    if idx < vm.errorCodes.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 16)
        } else {
            emptyPlaceholder(L10n.Push.guideEmptyErrors)
        }
    }

    // MARK: - Helpers

    private func tagSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dsMuted)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .padding(.top, 5)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(Color.dsText.opacity(0.85))
                }
            }
        }
    }

    private func codeColor(_ code: Int) -> Color {
        switch code {
        case 200: return .dsAccent
        case 400...499: return .dsAccentOrange
        case 500...599: return .dsAccentPink
        default: return .dsMuted
        }
    }

    private func emptyPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.dsMuted)
            .frame(maxWidth: .infinity)
            .padding(40)
    }
}
