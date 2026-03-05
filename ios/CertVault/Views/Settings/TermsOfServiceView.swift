import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.spacingXL) {
                termsHeader

                section("一、服务概述") {
                    """
                    CertVault 是一款面向 Apple 开发者的证书管理工具，提供以下服务：
                    • Apple 开发者证书的创建、管理与下载。
                    • 测试设备的注册与管理。
                    • 描述文件（Provisioning Profile）的创建与管理。
                    • Bundle ID 管理与 Capability 配置。
                    • 推送通知测试。
                    • UDID 获取辅助。

                    本应用为自部署工具，所有数据存储在您自己的服务器上。
                    """
                }

                section("二、账户注册与使用") {
                    """
                    1. 您需要注册账户才能使用本应用。注册时请提供真实的邮箱地址。
                    2. 您有责任妥善保管账户凭证（用户名和密码），因凭证泄露导致的损失由您自行承担。
                    3. 每个账户仅供注册者本人使用，不得转让、出租或共享。
                    4. 如发现未经授权的账户使用，请立即联系管理员。
                    """
                }

                section("三、Apple 开发者凭证") {
                    """
                    1. 您导入的 Apple 开发者凭证（P8 密钥、Issuer ID、Key ID）由您自行负责其合法性和有效性。
                    2. 请确保您拥有使用这些凭证的合法授权。
                    3. 我们不对因 Apple 凭证被滥用或泄露而产生的后果承担责任。
                    4. 建议您定期更换 P8 密钥以提高安全性。
                    """
                }

                section("四、合理使用") {
                    """
                    使用本应用时，您同意：
                    • 遵守 Apple Developer Program License Agreement。
                    • 不利用本工具进行任何违法违规活动。
                    • 不尝试绕过 Apple 或本应用的安全机制。
                    • 不对本应用进行反编译、逆向工程或未授权修改。
                    • 不将本工具用于大规模自动化操作（如批量注册设备以规避限制）。
                    """
                }

                section("五、服务可用性") {
                    """
                    1. 本应用依赖 Apple Developer API，其可用性受 Apple 服务状态影响。
                    2. 我们不保证服务 100% 可用，可能因维护、升级或不可抗力导致暂时中断。
                    3. Apple API 的变更可能影响部分功能，我们将尽力及时适配。
                    """
                }

                section("六、知识产权") {
                    """
                    1. 本应用的源代码、UI 设计、图标等知识产权归开发者所有。
                    2. 购买源码授权的用户享有使用权和二次开发权，但不得用于再次销售源码本身。
                    3. 本应用使用的第三方开源组件遵循各自的开源协议。
                    """
                }

                section("七、免责声明") {
                    """
                    1. 本应用按"现状"提供，不提供任何明示或暗示的担保。
                    2. 因使用本应用导致的证书丢失、账号异常或其他损失，开发者不承担赔偿责任。
                    3. 建议您定期备份重要的证书和描述文件。
                    """
                }

                section("八、账户注销") {
                    """
                    您有权随时申请注销账户。注销后：
                    • 您的账户信息将被删除。
                    • 导入的开发者凭证将被移除。
                    • 相关的操作记录将在 30 天内清除。
                    • 此操作不可恢复，请谨慎操作。
                    """
                }

                section("九、协议修改") {
                    """
                    我们保留随时修改本协议的权利。修改后的协议将在应用内发布。如您不同意修改后的条款，请停止使用本应用并联系管理员注销账户。
                    """
                }

                section("十、联系方式") {
                    """
                    如您对本用户协议有任何疑问，请联系：
                    • 邮箱：support@zijiu522.cn
                    """
                }

                Text("最后更新日期：2025 年 3 月")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, DS.spacingMD)
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacing3XL)
        }
        .pageBackground()
        .navigationTitle("用户协议")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var termsHeader: some View {
        VStack(spacing: DS.spacingSM) {
            Text("CertVault 用户协议")
                .font(.title2.bold())
                .foregroundStyle(Color.dsText)
            Text("使用本应用即表示您同意以下条款")
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.spacingLG)
    }

    private func section(_ title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.dsText)

            Text(LocalizedStringKey(content()))
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.spacingLG)
        .cardStyle()
    }
}
