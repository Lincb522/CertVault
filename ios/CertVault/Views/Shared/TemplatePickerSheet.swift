import SwiftUI
import HiconIcons

// MARK: - Preset Templates

private enum PresetTemplates {

    // swiftlint:disable line_length

    static let appStore: [(name: String, whatsNew: String, desc: String?, keywords: String?)] = [
        (
            name: "常规版本更新",
            whatsNew: "【新功能】\n- 新增 xxx 功能\n- 支持 xxx\n\n【优化】\n- 优化了 xxx 的性能\n- 改善了 xxx 的体验\n\n【修复】\n- 修复了 xxx 的问题\n- 修复了部分场景下的闪退",
            desc: nil,
            keywords: nil
        ),
        (
            name: "Bug 修复版本",
            whatsNew: "本次更新修复了以下问题：\n- 修复了 xxx 功能异常的问题\n- 修复了特定条件下的崩溃\n- 修复了 xxx 显示不正确的问题\n- 提升了稳定性和性能",
            desc: nil,
            keywords: nil
        ),
        (
            name: "重大版本更新",
            whatsNew: "🎉 全新 x.0 版本！\n\n【重大更新】\n- 全新的 xxx 功能\n- 重新设计了 xxx 界面\n- 全面支持 xxx\n\n【新功能】\n- 新增 xxx\n- 新增 xxx\n\n【优化】\n- 大幅优化了性能\n- 改善了整体使用体验\n\n感谢您的支持，如有问题请通过应用内反馈联系我们。",
            desc: nil,
            keywords: nil
        ),
        (
            name: "性能优化版本",
            whatsNew: "本次更新主要优化了应用性能：\n- 启动速度提升 xx%\n- 减少了内存占用\n- 优化了列表滚动流畅度\n- 改善了网络请求效率\n- 降低了电量消耗",
            desc: nil,
            keywords: nil
        ),
        (
            name: "首次上架",
            whatsNew: "🚀 全新发布！\n\n主要功能：\n- xxx\n- xxx\n- xxx\n\n如果您喜欢这款应用，请给我们一个好评，您的支持是我们持续改进的动力！",
            desc: nil,
            keywords: nil
        ),
        (
            name: "适配新系统",
            whatsNew: "本次更新适配了 iOS xx：\n- 适配最新系统特性\n- 支持 xxx 新功能\n- 优化了在新系统上的运行表现\n- 修复了部分兼容性问题",
            desc: nil,
            keywords: nil
        ),
        (
            name: "简洁三行版",
            whatsNew: "- 新增功能和改进\n- 修复已知问题\n- 提升稳定性和性能",
            desc: nil,
            keywords: nil
        ),
        (
            name: "英文 - Regular Update",
            whatsNew: "What's New:\n- Added xxx feature\n- Improved xxx performance\n- Fixed xxx issue\n- Bug fixes and stability improvements",
            desc: nil,
            keywords: nil
        ),
        (
            name: "英文 - Major Release",
            whatsNew: "🎉 Introducing version x.0!\n\n• Redesigned xxx for a better experience\n• New xxx feature\n• Performance improvements\n• Various bug fixes\n\nWe'd love to hear your feedback!",
            desc: nil,
            keywords: nil
        ),
        (
            name: "英文 - Bug Fix",
            whatsNew: "This update includes:\n- Fixed an issue where xxx\n- Fixed a crash when xxx\n- Stability and performance improvements\n\nThank you for your feedback!",
            desc: nil,
            keywords: nil
        ),
    ]

    static let testFlight: [(name: String, whatsNew: String)] = [
        (
            name: "功能测试",
            whatsNew: "本次构建需要测试以下内容：\n\n【新功能】\n1. xxx 功能 - 请验证基本流程是否正常\n2. xxx 功能 - 请测试各种边界情况\n\n【关注点】\n- 功能是否按预期工作\n- 界面显示是否正常\n- 是否有崩溃或异常\n\n如有问题请在 TestFlight 中提交反馈，感谢！"
        ),
        (
            name: "回归测试",
            whatsNew: "本次为回归测试版本，请重点关注：\n\n1. 核心功能是否正常（登录、xxx、xxx）\n2. 上一版本报告的问题是否修复\n3. 是否有新引入的问题\n\n测试步骤：\n- 全新安装并测试基础流程\n- 从旧版本覆盖安装测试数据迁移\n- 在不同网络环境下测试\n\n发现问题请截图反馈，感谢！"
        ),
        (
            name: "UI/界面测试",
            whatsNew: "本次更新了界面设计，请重点关注：\n\n1. 各页面布局是否正常\n2. 深色/浅色模式切换是否正常\n3. 不同机型的适配情况（刘海屏/灵动岛）\n4. 动画和交互是否流畅\n5. 文字是否有截断或重叠\n\n请在不同设备上测试并反馈问题。"
        ),
        (
            name: "性能测试",
            whatsNew: "本次重点优化了性能，请关注：\n\n1. 应用启动速度\n2. 页面切换是否流畅\n3. 列表滚动是否有卡顿\n4. 长时间使用后的内存表现\n5. 后台切换恢复是否正常\n\n如发现卡顿请记录出现的页面和操作步骤。"
        ),
        (
            name: "Bug 修复验证",
            whatsNew: "本次修复了以下问题，请帮忙验证：\n\n1. [Bug-xxx] xxx 的问题\n2. [Bug-xxx] xxx 的问题\n3. [Bug-xxx] xxx 的问题\n\n验证步骤：\n- 按照 Bug 报告中的步骤复现\n- 确认问题是否已修复\n- 检查是否有其他副作用\n\n感谢配合！"
        ),
        (
            name: "灰度发布",
            whatsNew: "本次为灰度测试版本：\n\n变更内容：\n- xxx 功能调整\n- xxx 策略变更\n\n请留意以下指标：\n- 功能是否符合预期\n- 数据展示是否准确\n- 用户流程是否顺畅\n\n如无重大问题将推送正式版。"
        ),
        (
            name: "简洁测试说明",
            whatsNew: "请测试以下内容：\n- 新功能是否正常\n- 修复的 Bug 是否解决\n- 整体稳定性"
        ),
        (
            name: "英文 - Feature Test",
            whatsNew: "Please test the following:\n\n1. New xxx feature - verify the basic flow\n2. xxx improvement - check edge cases\n\nFocus areas:\n- Does the feature work as expected?\n- Any crashes or UI issues?\n\nPlease submit feedback via TestFlight. Thanks!"
        ),
        (
            name: "英文 - Bug Fix Verification",
            whatsNew: "This build fixes the following issues:\n\n1. Fixed xxx\n2. Fixed xxx\n\nPlease verify:\n- Follow the original bug steps to reproduce\n- Confirm the issue is resolved\n- Check for any side effects\n\nThank you!"
        ),
    ]

    // swiftlint:enable line_length
}

// MARK: - Template Picker Sheet

struct TemplatePickerSheet: View {
    let type: TemplateType
    let onSelect: (SubmitTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var savedTemplates: [SubmitTemplate] = []
    @State private var editingTemplate: SubmitTemplate?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    presetSection
                    savedSection
                }
                .padding(16)
            }
            .pageBackground()
            .navigationTitle("选择模版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $editingTemplate) { tpl in
                TemplateEditorSheet(template: tpl) {
                    loadSavedTemplates()
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .onAppear { loadSavedTemplates() }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("预设模版", icon: AppIcon.sparkle, color: .dsAccentOrange)

            if type == .appStore {
                ForEach(PresetTemplates.appStore.indices, id: \.self) { i in
                    let p = PresetTemplates.appStore[i]
                    presetCard(name: p.name, preview: p.whatsNew) {
                        let tpl = SubmitTemplate(
                            name: p.name,
                            type: .appStore,
                            whatsNew: p.whatsNew,
                            desc: p.desc,
                            keywords: p.keywords
                        )
                        onSelect(tpl)
                        dismiss()
                    }
                }
            } else {
                ForEach(PresetTemplates.testFlight.indices, id: \.self) { i in
                    let p = PresetTemplates.testFlight[i]
                    presetCard(name: p.name, preview: p.whatsNew) {
                        let tpl = SubmitTemplate(
                            name: p.name,
                            type: .testFlight,
                            whatsNew: p.whatsNew
                        )
                        onSelect(tpl)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Saved Section

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !savedTemplates.isEmpty {
                sectionLabel("我的模版", icon: AppIcon.folder, color: .dsAccentPurple)
                    .padding(.top, 10)

                ForEach(savedTemplates) { template in
                    savedCard(template)
                }
            }
        }
    }

    // MARK: - Components

    private func sectionLabel(_ text: String, icon: UIImage, color: Color) -> some View {
        HStack(spacing: 6) {
            HIcon(icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dsText)
        }
        .padding(.leading, 4)
    }

    private func presetCard(name: String, preview: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.dsAccentOrange.opacity(0.1))
                            .frame(width: 36, height: 36)
                        HIcon(AppIcon.sparkle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.dsAccentOrange)
                    }
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    Text("预设")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.dsAccentOrange.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.dsAccentOrange)
                }

                Text(preview)
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func savedCard(_ template: SubmitTemplate) -> some View {
        Button {
            onSelect(template)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.dsAccentBlue.opacity(0.1))
                            .frame(width: 36, height: 36)
                        HIcon(AppIcon.docText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.dsAccentBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dsText)
                        HStack(spacing: 6) {
                            if let locale = template.locale {
                                Text(locale)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.dsAccentPurple.opacity(0.1), in: Capsule())
                                    .foregroundStyle(Color.dsAccentPurple)
                            }
                            Text(template.updatedAt.prefix(10))
                                .font(.caption2)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }

                    Spacer()

                    Menu {
                        Button { editingTemplate = template } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button(role: .destructive) { deleteTemplate(template) } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        HIcon(AppIcon.moreCircle)
                            .font(.body)
                            .foregroundStyle(Color.dsMuted)
                            .frame(width: 32, height: 32)
                    }
                }

                if let whatsNew = template.whatsNew, !whatsNew.isEmpty {
                    Text(whatsNew)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                if type == .appStore {
                    HStack(spacing: 16) {
                        if let desc = template.desc, !desc.isEmpty {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.doc).font(.system(size: 10))
                                Text("描述").font(.caption2)
                            }
                            .foregroundStyle(Color.dsAccent)
                        }
                        if let kw = template.keywords, !kw.isEmpty {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.tag).font(.system(size: 10))
                                Text("关键词").font(.caption2)
                            }
                            .foregroundStyle(Color.dsAccentOrange)
                        }
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func loadSavedTemplates() {
        savedTemplates = (try? DatabaseManager.shared.fetchTemplates(type: type)) ?? []
    }

    private func deleteTemplate(_ template: SubmitTemplate) {
        try? DatabaseManager.shared.deleteTemplate(id: template.id)
        loadSavedTemplates()
    }
}

// MARK: - Template Editor

struct TemplateEditorSheet: View {
    @State var template: SubmitTemplate
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("模版名称") {
                    TextField("名称", text: $template.name)
                }

                if template.type == .appStore {
                    Section("更新说明") {
                        TextEditor(text: Binding(
                            get: { template.whatsNew ?? "" },
                            set: { template.whatsNew = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 80)
                    }
                    Section("描述") {
                        TextEditor(text: Binding(
                            get: { template.desc ?? "" },
                            set: { template.desc = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 80)
                    }
                    Section("关键词") {
                        TextField("关键词（逗号分隔）", text: Binding(
                            get: { template.keywords ?? "" },
                            set: { template.keywords = $0.isEmpty ? nil : $0 }
                        ))
                    }
                } else {
                    Section("测试内容 (What to Test)") {
                        TextEditor(text: Binding(
                            get: { template.whatsNew ?? "" },
                            set: { template.whatsNew = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 100)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("编辑模版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        template.updatedAt = ISO8601DateFormatter().string(from: Date())
                        try? DatabaseManager.shared.saveTemplate(template)
                        onSaved()
                        dismiss()
                    }
                    .disabled(template.name.isEmpty)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
    }
}
