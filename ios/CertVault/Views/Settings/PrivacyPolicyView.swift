import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.spacingXL) {
                policyHeader

                section("一、信息收集") {
                    """
                    我们仅收集提供服务所必需的信息：

                    1. **账户信息**：注册时您提供的用户名、邮箱地址。
                    2. **Apple 开发者凭证**：您主动导入的 Issuer ID、Key ID、P8 密钥文件，用于调用 Apple Developer API。
                    3. **设备信息**：应用运行所需的基本设备标识（如用于推送通知的 Device Token）。
                    4. **操作日志**：证书创建、设备注册等操作的时间戳与类型，用于展示操作历史。

                    我们**不会**收集您的通讯录、照片、位置、通话记录或其他与服务无关的个人信息。
                    """
                }

                section("二、信息存储与安全") {
                    """
                    1. 您的开发者凭证（P8 密钥）使用加密存储在您自行部署的服务器上，我们不提供公共托管服务。
                    2. 账户密码经 bcrypt 哈希处理后存储，明文密码不被保留。
                    3. 所有客户端与服务器之间的通信均通过 HTTPS 加密传输。
                    4. 本地缓存数据存储在应用沙盒内，受 iOS 系统级加密保护。
                    """
                }

                section("三、信息使用") {
                    """
                    您提供的信息仅用于以下目的：
                    • 管理 Apple 开发者证书、描述文件、设备和 Bundle ID。
                    • 发送推送通知测试。
                    • 验证账户身份和授权操作。

                    我们不会将您的信息用于广告投放、用户画像或任何与服务无关的用途。
                    """
                }

                section("四、信息共享") {
                    """
                    我们**不会**向任何第三方出售、出租或共享您的个人信息，以下情况除外：
                    • 经您明确同意。
                    • 法律法规要求或政府机关依法要求。
                    • 为保护用户或公众的人身财产安全所必需。
                    """
                }

                section("五、数据删除") {
                    """
                    您可以随时：
                    • 删除已导入的开发者账户及其关联数据。
                    • 清除本地缓存。
                    • 联系管理员注销您的账户，我们将删除所有与您相关的数据。

                    账户注销后，您的所有数据将在 30 天内从服务器中永久删除。
                    """
                }

                section("六、Cookie 与跟踪") {
                    """
                    本应用不使用 Cookie、第三方分析工具或任何广告跟踪技术。我们不参与跨应用或跨网站的用户跟踪。
                    """
                }

                section("七、未成年人保护") {
                    """
                    本应用面向具备 Apple 开发者账户的专业用户，不针对 13 岁以下儿童提供服务。如发现误收集了未成年人的信息，我们将立即删除。
                    """
                }

                section("八、政策变更") {
                    """
                    我们可能会不时更新本隐私政策。变更后的政策将在应用内发布，重大变更将通过应用通知告知您。继续使用本应用即表示您同意更新后的政策。
                    """
                }

                section("九、联系我们") {
                    """
                    如您对本隐私政策有任何疑问，请通过以下方式联系我们：
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
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var policyHeader: some View {
        VStack(spacing: DS.spacingSM) {
            Text("CertVault 隐私政策")
                .font(.title2.bold())
                .foregroundStyle(Color.dsText)
            Text("我们重视您的隐私，请仔细阅读以下内容")
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
