<template>
  <div>
    <div class="page-header">
      <h1>证书管理</h1>
      <p>创建和管理 Apple 开发/发布/推送证书，支持 P12 导出和自签证书</p>
    </div>

    <el-tabs v-model="activeTab" type="border-card">
      <!-- 证书列表 -->
      <el-tab-pane name="list">
        <template #label><el-icon><Key /></el-icon> 证书列表</template>

        <div class="card-header" style="margin-bottom: 16px">
          <h3>全部证书</h3>
          <div>
            <el-button type="primary" @click="showCreateDialog = true" :disabled="!store.currentAccountId">
              <el-icon><Plus /></el-icon> 创建证书
            </el-button>
            <el-button type="success" @click="showSelfSignDialog = true">
              <el-icon><EditPen /></el-icon> 自签证书
            </el-button>
          </div>
        </div>

        <el-table :data="certificates" stripe v-loading="loading" empty-text="暂无证书">
          <el-table-column prop="name" label="名称" min-width="180">
            <template #default="{ row }">
              <span>{{ row.name }}</span>
              <el-tag v-if="row.is_remote" size="small" type="info" effect="plain" style="margin-left:6px">Apple 远程</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="type" label="类型" width="200">
            <template #default="{ row }">
              <el-tag size="small" :type="typeTagType(row)">
                {{ row.is_self_signed ? '自签证书' : certTypeLabel(row.type) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="来源" width="90" align="center">
            <template #default="{ row }">
              <el-tag size="small" :type="row.is_remote ? 'warning' : 'success'" effect="plain">
                {{ row.is_remote ? '远程' : '本地' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="expires_at" label="过期时间" width="120">
            <template #default="{ row }">
              <span :style="{ color: getExpiryColor(row.expires_at) }">
                {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
              </span>
            </template>
          </el-table-column>
          <el-table-column prop="created_at" label="创建时间" width="180">
            <template #default="{ row }">{{ formatDate(row.created_at) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="160" fixed="right">
            <template #default="{ row }">
              <el-button size="small" @click="viewCertDetail(row)">详情</el-button>
              <el-dropdown trigger="click">
                <el-button size="small">
                  更多 <el-icon style="margin-left:4px"><ArrowDown /></el-icon>
                </el-button>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item @click="downloadCert(row)">
                      <el-icon><Download /></el-icon> {{ row.p12_path || row.private_key ? '导出 P12' : '导出 CER' }}
                    </el-dropdown-item>
                    <el-dropdown-item divided @click="deleteCert(row)" style="color: var(--nask-red)">
                      <el-icon><Delete /></el-icon> {{ row.is_remote ? '撤销' : '删除' }}
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <!-- 关联关系 -->
      <el-tab-pane name="relations">
        <template #label><el-icon><Connection /></el-icon> 关联关系</template>

        <div class="card-header" style="margin-bottom: 16px">
          <h3>证书 / 描述文件 / 设备 关联总览</h3>
          <el-button type="primary" @click="fetchRelations" :loading="relationsLoading" :disabled="!store.currentAccountId">
            <el-icon><Refresh /></el-icon> 从 Apple 加载
          </el-button>
        </div>

        <div v-if="!store.currentAccountId" class="empty-state">
          <HIcon name="danger-circle" :size="48" />
          <p>请先在左侧选择一个账号</p>
        </div>

        <div v-else-if="relations.length === 0 && !relationsLoading" class="empty-state">
          <HIcon name="link" :size="48" />
          <p>点击「从 Apple 加载」查看关联关系</p>
        </div>

        <el-collapse v-else v-model="expandedRelations">
          <el-collapse-item
            v-for="profile in relations"
            :key="profile.id"
            :name="profile.id"
          >
            <template #title>
              <div class="relation-title">
                <el-tag size="small" :type="profile.state === 'ACTIVE' ? 'success' : 'danger'">
                  {{ profile.state === 'ACTIVE' ? '有效' : profile.state }}
                </el-tag>
                <strong>{{ profile.name }}</strong>
                <el-tag size="small" effect="plain" type="info">{{ profile.type }}</el-tag>
                <span class="relation-meta">
                  {{ profile.certificates.length }} 证书 / {{ profile.device_count }} 设备
                </span>
              </div>
            </template>

            <el-row :gutter="16">
              <el-col :xs="24" :sm="8">
                <h4 class="rel-section-title">Bundle ID</h4>
                <div v-if="profile.bundle" class="rel-item">
                  <div class="rel-name">{{ profile.bundle.name || '-' }}</div>
                  <code class="rel-id">{{ profile.bundle.identifier || profile.bundle.id }}</code>
                </div>
                <span v-else style="color:#909399">-</span>
              </el-col>

              <el-col :xs="24" :sm="8">
                <h4 class="rel-section-title">关联证书 ({{ profile.certificates.length }})</h4>
                <div v-for="cert in profile.certificates" :key="cert.id" class="rel-item">
                  <div class="rel-name">{{ cert.name || cert.id }}</div>
                  <div>
                    <el-tag size="small" effect="plain">{{ cert.type || '-' }}</el-tag>
                    <span v-if="cert.expires" class="rel-expires">
                      {{ new Date(cert.expires).toLocaleDateString() }}
                    </span>
                  </div>
                </div>
              </el-col>

              <el-col :xs="24" :sm="8">
                <h4 class="rel-section-title">关联设备 ({{ profile.device_count }})</h4>
                <div v-if="profile.devices.length === 0" style="color:#909399;font-size:13px">
                  无设备（App Store / Enterprise 类型）
                </div>
                <div v-for="dev in profile.devices.slice(0, 20)" :key="dev.id" class="rel-item">
                  <div class="rel-name">{{ dev.name || '-' }}</div>
                  <code class="rel-id">{{ dev.udid || dev.id }}</code>
                </div>
                <div v-if="profile.devices.length > 20" style="color:#909399;font-size:12px;margin-top:4px">
                  还有 {{ profile.devices.length - 20 }} 台设备...
                </div>
              </el-col>
            </el-row>

            <div style="margin-top:8px;color:#909399;font-size:12px">
              过期时间: {{ profile.expires ? new Date(profile.expires).toLocaleDateString() : '-' }}
            </div>
          </el-collapse-item>
        </el-collapse>
      </el-tab-pane>

      <!-- 推送证书 -->
      <el-tab-pane name="push">
        <template #label><el-icon><Bell /></el-icon> 推送证书配置</template>

        <div v-if="pushGuide" class="push-guide">
          <!-- 两种方式对比 -->
          <el-row :gutter="20" style="margin-bottom: 24px">
            <el-col :xs="24" :sm="12" v-for="method in pushGuide.methods" :key="method.id">
              <div class="method-card" :class="{ recommended: method.id === 'p8_key' }">
                <div class="method-header">
                  <h3>{{ method.name }}</h3>
                  <el-tag v-if="method.id === 'p8_key'" type="success" size="small">推荐</el-tag>
                </div>
                <p class="method-desc">{{ method.desc }}</p>

                <div class="method-section">
                  <h4>优点</h4>
                  <ul class="pros-list">
                    <li v-for="(pro, i) in method.pros" :key="i">{{ pro }}</li>
                  </ul>
                </div>

                <div class="method-section">
                  <h4>缺点</h4>
                  <ul class="cons-list">
                    <li v-for="(con, i) in method.cons" :key="i">{{ con }}</li>
                  </ul>
                </div>

                <div class="method-section">
                  <h4>配置步骤</h4>
                  <el-timeline>
                    <el-timeline-item v-for="(step, i) in method.steps" :key="i" :timestamp="`第 ${i + 1} 步`" placement="top">
                      {{ step }}
                    </el-timeline-item>
                  </el-timeline>
                </div>

                <div v-if="method.server_config" class="method-section">
                  <h4>服务端配置参数</h4>
                  <el-descriptions :column="1" border size="small">
                    <el-descriptions-item
                      v-for="(desc, key) in method.server_config"
                      :key="key"
                      :label="key"
                    >
                      {{ desc }}
                    </el-descriptions-item>
                  </el-descriptions>
                </div>

                <div v-if="method.cert_types" class="method-section">
                  <h4>证书类型说明</h4>
                  <el-descriptions :column="1" border size="small">
                    <el-descriptions-item
                      v-for="(desc, key) in method.cert_types"
                      :key="key"
                      :label="key"
                    >
                      {{ desc }}
                    </el-descriptions-item>
                  </el-descriptions>
                </div>
              </div>
            </el-col>
          </el-row>

          <!-- 推送证书 vs 签名证书 区别 -->
          <div class="content-card">
            <div class="card-header">
              <h3>推送证书 vs 签名证书的区别</h3>
            </div>
            <el-alert type="warning" :closable="false" style="margin-bottom: 16px" title="重要说明">
              推送证书 (APNs SSL) 和应用签名证书 (Development / Distribution) 是完全不同的证书，用途各异，不能混用。
            </el-alert>
            <el-table :data="certDiffData" stripe size="small" border>
              <el-table-column prop="item" label=" " width="120" />
              <el-table-column prop="push" label="推送证书 (APNs SSL)">
                <template #default="{ row }">
                  <span :style="{ color: row.pushColor || '' }">{{ row.push }}</span>
                </template>
              </el-table-column>
              <el-table-column prop="sign" label="签名证书 (Dev / Dist)">
                <template #default="{ row }">
                  <span :style="{ color: row.signColor || '' }">{{ row.sign }}</span>
                </template>
              </el-table-column>
            </el-table>
          </div>

          <!-- 推荐方案 -->
          <div class="content-card">
            <div class="card-header">
              <h3>推送配置推荐方案</h3>
            </div>
            <el-alert type="success" :closable="false" style="margin-bottom: 16px">
              <template #title>
                <strong>强烈推荐使用 .p8 Key 方式</strong> — 本工具已保存的 API Key (.p8) 可直接用于推送认证，无需额外创建推送证书。
              </template>
              <div style="margin-top: 8px; line-height: 1.8">
                你在「账号管理」中导入的 .p8 Key，只要该 Key 在 Apple Developer 中勾选了 APNs 权限，就可以直接配置到推送服务端。
                前往「账号管理」页面点击 <strong>P8 下载</strong> 按钮即可导出。
              </div>
            </el-alert>

            <el-divider content-position="left">如果你的推送服务只支持 .p12 证书</el-divider>

            <el-alert type="info" :closable="false" style="margin-bottom: 16px">
              <template #title>APNs SSL 推送证书 (.p12) 需通过 Apple Developer 网站手动创建</template>
              <div style="margin-top: 8px; line-height: 1.8">
                推送证书 (APNs SSL Certificate) 不属于 App Store Connect API 的管理范围，<strong>无法通过 API 自动创建</strong>。
                请按以下步骤在 Apple Developer 网站手动操作。
              </div>
            </el-alert>

            <el-timeline>
              <el-timeline-item type="primary" timestamp="第 1 步">
                <strong>开启推送权限</strong> — 在本工具「权限管理」中为 Bundle ID 开启 <el-tag size="small">PUSH_NOTIFICATIONS</el-tag> 权限
              </el-timeline-item>
              <el-timeline-item type="primary" timestamp="第 2 步">
                <strong>登录 Apple Developer</strong> — 访问
                <el-link type="primary" href="https://developer.apple.com/account/resources/certificates/list" target="_blank">
                  Certificates, Identifiers & Profiles
                </el-link>
              </el-timeline-item>
              <el-timeline-item type="primary" timestamp="第 3 步">
                <strong>创建证书</strong> — 点击 + 号，选择 <el-tag size="small" type="warning">Apple Push Notification service SSL</el-tag>，选择对应的 App ID
              </el-timeline-item>
              <el-timeline-item type="primary" timestamp="第 4 步">
                <strong>上传 CSR</strong> — 在 Mac 上通过钥匙串访问生成 CSR 文件并上传，或使用以下命令生成：
                <div class="code-block">
                  <code>openssl req -new -newkey rsa:2048 -nodes -keyout push_key.pem -out push.csr -subj "/CN=PushCert"</code>
                </div>
              </el-timeline-item>
              <el-timeline-item type="primary" timestamp="第 5 步">
                <strong>下载证书</strong> — 下载 .cer 证书文件
              </el-timeline-item>
              <el-timeline-item type="success" timestamp="第 6 步">
                <strong>导出 P12</strong> — 使用以下命令将私钥 + 证书合并为 .p12：
                <div class="code-block">
                  <code>openssl x509 -in aps.cer -inform DER -out push_cert.pem -outform PEM</code>
                  <br />
                  <code>openssl pkcs12 -export -in push_cert.pem -inkey push_key.pem -out push.p12</code>
                </div>
              </el-timeline-item>
              <el-timeline-item type="success" timestamp="第 7 步">
                <strong>配置到推送服务</strong> — 将 .p12 文件和密码配置到你的推送服务端
              </el-timeline-item>
            </el-timeline>
          </div>

          <!-- 常用推送服务 -->
          <div class="content-card">
            <div class="card-header">
              <h3>常用推送服务配置参考</h3>
            </div>
            <el-table :data="pushGuide.common_services" stripe size="small">
              <el-table-column prop="name" label="服务名称" width="220" />
              <el-table-column prop="config" label="配置说明" min-width="300" />
              <el-table-column label="文档" width="100" align="center">
                <template #default="{ row }">
                  <el-button size="small" link type="primary" @click="openUrl(row.url)">
                    <el-icon><Link /></el-icon> 查看
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
          </div>

          <!-- 常见问题 -->
          <div class="content-card">
            <div class="card-header">
              <h3>常见问题排查</h3>
            </div>
            <el-collapse>
              <el-collapse-item
                v-for="(item, i) in pushGuide.troubleshooting"
                :key="i"
                :title="item.issue"
              >
                <div class="troubleshoot-solution">
                  <el-icon color="#67c23a"><CircleCheckFilled /></el-icon>
                  <span>{{ item.solution }}</span>
                </div>
              </el-collapse-item>
            </el-collapse>
          </div>
        </div>

        <div v-else class="empty-state">
          <el-icon><Loading /></el-icon>
          <p>加载推送配置指南中...</p>
        </div>
      </el-tab-pane>

      <!-- 自签证书 -->
      <el-tab-pane name="selfsign">
        <template #label><el-icon><EditPen /></el-icon> 自签证书</template>

        <el-tabs v-model="selfSignTab" style="margin-top: -8px">
          <el-tab-pane label="快速自签" name="quick">
            <el-form :model="selfSignForm" label-width="100px" style="max-width: 500px">
              <el-form-item label="证书名称">
                <el-input v-model="selfSignForm.name" placeholder="Self-Signed Certificate" />
              </el-form-item>
              <el-form-item label="P12 密码">
                <el-input v-model="selfSignForm.password" placeholder="默认 123456" />
              </el-form-item>
              <el-form-item label="通用名称">
                <el-input v-model="selfSignForm.subject.commonName" placeholder="Apple Development: Self-Signed" />
              </el-form-item>
              <el-form-item label="组织">
                <el-input v-model="selfSignForm.subject.organization" placeholder="Dev" />
              </el-form-item>
              <el-form-item label="邮箱">
                <el-input v-model="selfSignForm.subject.email" placeholder="可选" />
              </el-form-item>
              <el-form-item>
                <el-button type="primary" @click="createSelfSigned" :loading="creating">生成自签证书</el-button>
              </el-form-item>
            </el-form>
          </el-tab-pane>
          <el-tab-pane label="使用已有 CA" name="ca">
            <el-form :model="selfSignForm" label-width="100px" style="max-width: 600px">
              <el-form-item label="证书名称">
                <el-input v-model="selfSignForm.name" />
              </el-form-item>
              <el-form-item label="CA 证书" required>
                <el-input v-model="selfSignForm.ca_cert" type="textarea" :rows="4" placeholder="粘贴 CA 证书 PEM" />
              </el-form-item>
              <el-form-item label="CA 私钥" required>
                <el-input v-model="selfSignForm.ca_private_key" type="textarea" :rows="4" placeholder="粘贴 CA 私钥 PEM" />
              </el-form-item>
              <el-form-item label="P12 密码">
                <el-input v-model="selfSignForm.password" placeholder="默认 123456" />
              </el-form-item>
              <el-form-item>
                <el-button type="primary" @click="createSelfSigned" :loading="creating">生成自签证书</el-button>
              </el-form-item>
            </el-form>
          </el-tab-pane>
          <el-tab-pane label="生成 CA" name="gen-ca">
            <el-form :model="caForm" label-width="100px" style="max-width: 500px">
              <el-form-item label="CA 名称">
                <el-input v-model="caForm.commonName" placeholder="Self-Signed CA" />
              </el-form-item>
              <el-form-item label="组织">
                <el-input v-model="caForm.organization" placeholder="Dev CA" />
              </el-form-item>
              <el-form-item label="有效年限">
                <el-input-number v-model="caForm.years" :min="1" :max="20" />
              </el-form-item>
              <el-form-item>
                <el-button type="warning" @click="generateCA" :loading="generatingCA">生成 CA</el-button>
              </el-form-item>
            </el-form>
            <div v-if="generatedCA" style="margin-top: 12px; max-width: 600px">
              <el-alert type="success" title="CA 已生成" :closable="false" />
              <el-input style="margin-top:8px" type="textarea" :rows="4" :model-value="generatedCA.cert" readonly />
              <el-button style="margin-top:8px" size="small" @click="copyText(generatedCA.cert)">复制 CA 证书</el-button>
              <el-button size="small" @click="copyText(generatedCA.privateKey)">复制 CA 私钥</el-button>
            </div>
          </el-tab-pane>
        </el-tabs>
      </el-tab-pane>
    </el-tabs>

    <!-- 证书详情 -->
    <el-dialog v-model="showDetailDialog" title="证书详情" width="560px" destroy-on-close>
      <div v-if="certDetail" v-loading="detailLoading">
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="证书名称" :span="2">{{ certDetail.name }}</el-descriptions-item>
          <el-descriptions-item label="证书类型">
            <el-tag size="small" :type="certDetail.is_self_signed ? 'warning' : 'primary'">
              {{ certDetail.is_self_signed ? '自签证书' : certTypeLabel(certDetail.type) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="Apple ID">
            <code v-if="certDetail.apple_id">{{ certDetail.apple_id }}</code>
            <span v-else style="color:#909399">-</span>
          </el-descriptions-item>
          <el-descriptions-item label="本地 P12">
            <el-tag size="small" :type="certDetail.has_p12 ? 'success' : 'danger'">
              {{ certDetail.has_p12 ? '有' : '无' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="私钥">
            <el-tag size="small" :type="certDetail.has_private_key ? 'success' : 'danger'">
              {{ certDetail.has_private_key ? '有' : '无' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="P12 密码" v-if="certDetail.password">
            <div style="display:flex;align-items:center;gap:6px">
              <code style="font-weight:600">{{ certDetail.password }}</code>
              <el-button size="small" text type="primary" @click="copyText(certDetail.password)">
                <el-icon><CopyDocument /></el-icon>
              </el-button>
            </div>
          </el-descriptions-item>
          <el-descriptions-item label="过期时间">
            <span :style="{ color: getExpiryColor(certDetail.expires_at) }">
              {{ certDetail.expires_at ? new Date(certDetail.expires_at).toLocaleString('zh-CN') : '-' }}
            </span>
          </el-descriptions-item>
          <el-descriptions-item label="创建时间">
            {{ certDetail.created_at ? new Date(certDetail.created_at).toLocaleString('zh-CN') : '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="所属账号" v-if="certDetail.account" :span="2">
            {{ certDetail.account.name }} (Key: {{ certDetail.account.key_id }})
          </el-descriptions-item>
        </el-descriptions>

        <div v-if="certDetail.cert_info" style="margin-top: 16px">
          <h4 style="font-size:14px;margin:0 0 8px">证书主体信息</h4>
          <el-descriptions :column="2" border size="small">
            <el-descriptions-item v-for="(val, key) in certDetail.cert_info.subject" :key="key" :label="key">
              {{ val }}
            </el-descriptions-item>
          </el-descriptions>
          <h4 style="font-size:14px;margin:12px 0 8px">签发者信息</h4>
          <el-descriptions :column="2" border size="small">
            <el-descriptions-item v-for="(val, key) in certDetail.cert_info.issuer" :key="key" :label="key">
              {{ val }}
            </el-descriptions-item>
          </el-descriptions>
          <el-descriptions :column="2" border size="small" style="margin-top:8px">
            <el-descriptions-item label="序列号">{{ certDetail.cert_info.serialNumber }}</el-descriptions-item>
            <el-descriptions-item label="有效期">
              {{ new Date(certDetail.cert_info.notBefore).toLocaleDateString() }}
              ~
              {{ new Date(certDetail.cert_info.notAfter).toLocaleDateString() }}
            </el-descriptions-item>
          </el-descriptions>
        </div>

        <el-alert v-if="!certDetail.has_p12" type="warning" :closable="false" style="margin-top: 16px">
          该证书从 Apple 同步而来，本地没有 P12 文件。如需 P12 请通过「创建证书」或「一键绑定」重新生成。
        </el-alert>
      </div>
      <template #footer>
        <el-button @click="showDetailDialog = false">关闭</el-button>
        <el-button type="primary" @click="downloadCert(certDetail)">
          <el-icon><Download /></el-icon> 下载 P12
        </el-button>
      </template>
    </el-dialog>

    <!-- 创建证书 (Apple API) -->
    <el-dialog v-model="showCreateDialog" title="创建证书" width="520px" destroy-on-close>
      <el-alert type="info" :closable="false" show-icon style="margin-bottom:16px">
        CSR 和私钥由工具内部自动生成，创建完成后直接下载 P12。
      </el-alert>
      <el-form :model="createForm" label-width="100px">
        <el-form-item label="证书类型" required>
          <el-select v-model="createForm.type" style="width: 100%">
            <el-option
              v-for="t in certTypes"
              :key="t.value"
              :label="t.label"
              :value="t.value"
            >
              <div style="display:flex; justify-content:space-between; align-items:center">
                <span>{{ t.label }}</span>
                <span style="color:#909399; font-size:12px; margin-left:12px">{{ t.desc }}</span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="证书名称">
          <el-input v-model="createForm.name" placeholder="可选，默认使用证书类型" />
        </el-form-item>
        <el-form-item label="P12 密码">
          <el-input v-model="createForm.password" placeholder="默认 123456" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="createCert" :loading="creating">创建并生成 P12</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import HIcon from '../components/HIcon.vue'
import { certApi } from '../api'
import { useAppStore } from '../stores/app'

const store = useAppStore()
const activeTab = ref('list')
const certificates = ref([])
const loading = ref(false)
const creating = ref(false)
const generatingCA = ref(false)
const showCreateDialog = ref(false)
const showDetailDialog = ref(false)
const relationsLoading = ref(false)
const relations = ref([])
const expandedRelations = ref([])
const detailLoading = ref(false)
const certDetail = ref(null)
const showSelfSignDialog = ref(false)
const selfSignTab = ref('quick')
const certTypes = ref([])
const generatedCA = ref(null)
const pushGuide = ref(null)

const certDiffData = [
  { item: '用途', push: '服务端向用户设备发送远程推送消息', sign: '签名 App 二进制包用于安装或分发', pushColor: '#409eff', signColor: '#67c23a' },
  { item: '证书类型', push: 'Apple Push Notification service SSL', sign: 'iOS Development / iOS Distribution' },
  { item: '绑定对象', push: '绑定到具体的 Bundle ID（每个 App 单独）', sign: '绑定到开发者账号（所有 App 通用）' },
  { item: '配置位置', push: '推送服务端（Firebase / 极光 / 自建服务等）', sign: 'Xcode 项目 → Signing & Capabilities' },
  { item: '有效期', push: '1 年（.p12）/ 永不过期（.p8）', sign: '1 年' },
  { item: 'API 创建', push: '不支持 — 需在 Apple Developer 网站手动创建', sign: '支持 — 本工具可一键创建', pushColor: '#f56c6c', signColor: '#67c23a' },
  { item: '推荐方式', push: '使用 .p8 Key 替代（永不过期，免维护）', sign: '通过本工具自动创建 P12', pushColor: '#e6a23c' },
]

const CERT_TYPE_MAP = {
  IOS_DEVELOPMENT: 'iOS 开发证书',
  IOS_DISTRIBUTION: 'iOS 发布证书',
  MAC_APP_DEVELOPMENT: 'macOS 开发证书',
  MAC_APP_DISTRIBUTION: 'macOS 发布证书',
  MAC_INSTALLER_DISTRIBUTION: 'macOS 安装包发布证书',
  DEVELOPER_ID_KEXT: 'Developer ID (内核扩展)',
  DEVELOPER_ID_APPLICATION: 'Developer ID (应用)',
  DEVELOPER_ID_INSTALLER: 'Developer ID (安装器)',
  SELF_SIGNED: '自签证书',
}

function certTypeLabel(type) {
  return CERT_TYPE_MAP[type] || type
}

function typeTagType(row) {
  if (row.is_self_signed) return 'warning'
  if (row.type?.includes('DISTRIBUTION') || row.type?.includes('PRODUCTION')) return 'danger'
  return 'primary'
}

function getExpiryColor(dateStr) {
  if (!dateStr) return ''
  const days = Math.ceil((new Date(dateStr) - new Date()) / (1000 * 60 * 60 * 24))
  if (days < 0) return '#f56c6c'
  if (days <= 30) return '#e6a23c'
  return ''
}

const createForm = ref({
  type: 'IOS_DEVELOPMENT', name: '', password: '123456'
})

const selfSignForm = ref({
  name: '', password: '123456', ca_cert: '', ca_private_key: '',
  subject: { commonName: '', organization: '', email: '' }
})

const caForm = ref({ commonName: 'Self-Signed CA', organization: 'Dev CA', years: 10 })

function formatDate(d) {
  return d ? new Date(d).toLocaleString('zh-CN') : '-'
}

async function fetchCerts() {
  loading.value = true
  try {
    const res = await certApi.list(store.currentAccountId || undefined)
    certificates.value = res.data || []
  } finally {
    loading.value = false
  }
}

async function fetchTypes() {
  try {
    const res = await certApi.types()
    certTypes.value = res.data || []
  } catch {}
}

async function fetchPushGuide() {
  try {
    const res = await certApi.pushGuide()
    pushGuide.value = res.data
  } catch {}
}

async function createCert(revokeAndRecreate = false) {
  creating.value = true
  try {
    const res = await certApi.create({
      account_id: store.currentAccountId,
      type: createForm.value.type,
      name: createForm.value.name,
      password: createForm.value.password,
      revoke_and_recreate: revokeAndRecreate,
    })
    ElMessage.success(res.data?.message || '证书创建成功，P12 已生成')
    showCreateDialog.value = false
    fetchCerts()
  } catch (err) {
    const resp = err.response?.data
    if (resp?.can_revoke_recreate) {
      const certList = (resp.existing_certs || []).map(c => `• ${c.name} (到期: ${c.expires?.split('T')[0] || '未知'})`).join('\n')
      try {
        await ElMessageBox.confirm(
          `${resp.message}\n\n当前已有证书:\n${certList}\n\n是否撤销最旧的一个并重新创建？`,
          '证书数量已满',
          { confirmButtonText: '撤销旧证书并创建', cancelButtonText: '取消', type: 'warning' }
        )
        await createCert(true)
      } catch {
        // user cancelled
      }
    }
  } finally {
    creating.value = false
  }
}

async function createSelfSigned() {
  creating.value = true
  try {
    const data = { ...selfSignForm.value }
    if (selfSignTab.value === 'quick') {
      delete data.ca_cert
      delete data.ca_private_key
    }
    const res = await certApi.selfSign(data)
    ElMessage.success('自签证书创建成功')
    if (res.data?.ca_cert) {
      generatedCA.value = { cert: res.data.ca_cert, privateKey: res.data.ca_private_key }
    }
    fetchCerts()
  } finally {
    creating.value = false
  }
}

async function generateCA() {
  generatingCA.value = true
  try {
    const res = await certApi.generateCA(caForm.value)
    generatedCA.value = res.data
    ElMessage.success('CA 证书已生成')
  } finally {
    generatingCA.value = false
  }
}

async function fetchRelations() {
  if (!store.currentAccountId) return
  relationsLoading.value = true
  try {
    const res = await certApi.relations(store.currentAccountId)
    relations.value = res.data || []
    if (relations.value.length > 0) expandedRelations.value = [relations.value[0].id]
  } finally {
    relationsLoading.value = false
  }
}

async function viewCertDetail(row) {
  showDetailDialog.value = true
  detailLoading.value = true
  certDetail.value = null
  try {
    const res = await certApi.detail(row.id)
    certDetail.value = res.data
  } catch {
    ElMessage.error('获取详情失败')
  } finally {
    detailLoading.value = false
  }
}

function downloadCert(row) {
  window.open(certApi.download(row.id), '_blank')
}

function downloadCer(row) {
  window.open(certApi.downloadCer(row.id), '_blank')
}

async function deleteCert(row) {
  await ElMessageBox.confirm(`确定删除证书「${row.name}」？`, '确认删除', { type: 'warning' })
  await certApi.delete(row.id)
  ElMessage.success('证书已删除')
  fetchCerts()
}

function copyText(text) {
  navigator.clipboard.writeText(text)
  ElMessage.success('已复制到剪贴板')
}

function openUrl(url) {
  window.open(url, '_blank')
}

watch(() => store.currentAccountId, fetchCerts)
onMounted(() => { fetchCerts(); fetchTypes(); fetchPushGuide() })
</script>

<style scoped>
.push-guide {
  padding: 4px 0;
}

.method-card {
  border: 1px solid var(--nask-border);
  border-radius: var(--nask-radius-sm);
  padding: 20px;
  height: 100%;
  background: var(--nask-surface-hover);
  transition: all var(--nask-transition);
}

.method-card.recommended {
  border-color: var(--nask-green);
  background: rgba(34,197,94,0.04);
}

.method-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.method-header h3 {
  font-size: 15px;
  margin: 0;
}

.method-desc {
  color: var(--nask-text-secondary);
  font-size: 13px;
  margin: 0 0 16px 0;
}

.method-section {
  margin-bottom: 16px;
}

.method-section h4 {
  font-size: 13px;
  font-weight: 600;
  margin: 0 0 8px 0;
  color: var(--nask-text);
}

.pros-list, .cons-list {
  padding-left: 18px;
  margin: 0;
  font-size: 13px;
  line-height: 1.8;
}

.pros-list li { color: var(--nask-green); }
.pros-list li::marker { content: '+ '; }
.cons-list li { color: var(--nask-red); }
.cons-list li::marker { content: '- '; }

.form-tip {
  color: var(--nask-text-muted);
  font-size: 12px;
  margin-top: 4px;
  line-height: 1.4;
}

.troubleshoot-solution {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  color: var(--nask-text);
  font-size: 14px;
  line-height: 1.6;
}

.code-block {
  background: var(--nask-surface-hover);
  border: 1px solid var(--nask-border);
  border-radius: var(--nask-radius-sm);
  padding: 10px 14px;
  margin-top: 8px;
  font-family: 'SF Mono', Monaco, Menlo, Consolas, monospace;
  font-size: 12px;
  line-height: 1.8;
  color: var(--nask-text);
  overflow-x: auto;
}

.relation-title {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  min-width: 0;
}

.relation-meta {
  color: var(--nask-text-muted);
  font-size: 12px;
  margin-left: auto;
  flex-shrink: 0;
}

.rel-section-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--nask-text);
  margin: 0 0 8px;
  padding-bottom: 6px;
  border-bottom: 1px solid var(--nask-border);
}

.rel-item {
  padding: 6px 0;
  border-bottom: 1px dashed var(--nask-border);
  font-size: 13px;
}

.rel-item:last-child { border-bottom: none; }

.rel-name {
  font-weight: 500;
  color: var(--nask-text);
  margin-bottom: 2px;
}

.rel-id {
  font-size: 11px;
  color: var(--nask-text-muted);
  font-family: monospace;
}

.rel-expires {
  color: var(--nask-text-muted);
  font-size: 11px;
  margin-left: 6px;
}
</style>
