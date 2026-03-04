# API 文档 — CertVault

> Base URL: `http://114.66.31.109:3006/api`

## 认证

除 `/api/health`、`/api/auth/*`、`/api/udid/*` 外，所有接口需要认证。

**两种方式（iOS 端推荐 Header）：**

```
Authorization: Bearer <token>
```

或 URL 参数（用于文件下载）：

```
?token=<token>
```

---

## 1. 认证 `/auth`

### POST `/auth/login` — 登录

```json
// Request
{ "username": "admin", "password": "admin123" }

// Response
{
  "success": true,
  "data": {
    "token": "uuid-token-string",
    "username": "admin",
    "role": "admin",
    "expires_at": "2026-03-10T12:00:00.000Z"
  }
}
```

### POST `/auth/logout` — 登出

### GET `/auth/me` — 当前用户信息

```json
// Response
{ "success": true, "data": { "username": "admin", "role": "admin" } }
```

### POST `/auth/change-password` — 修改密码

```json
// Request
{ "old_password": "old", "new_password": "new" }
```

---

## 2. 仪表盘 `/dashboard`

### GET `/dashboard` — 统计概览

```json
// Response
{
  "success": true,
  "data": {
    "stats": {
      "accounts": 1,
      "devices": 5,
      "certificates": 3,
      "certs_with_p12": 2,
      "profiles": 4,
      "bundle_ids": 3
    },
    "recent_certificates": [{ "id": "", "name": "", "type": "", "expires_at": "", "created_at": "" }],
    "recent_devices": [{ "id": "", "name": "", "udid": "", "platform": "", "created_at": "" }]
  }
}
```

---

## 3. 账号管理 `/accounts`

### GET `/accounts` — 列出所有账号

```json
// Response
{ "success": true, "data": [{ "id": "", "name": "", "issuer_id": "", "key_id": "", "created_at": "" }] }
```

### GET `/accounts/:id` — 账号详情（自动同步 Apple 远程数据）

```json
// Response
{
  "success": true,
  "data": {
    "id": "", "name": "", "issuer_id": "", "key_id": "",
    "remote_synced": true,
    "stats": { "certificates": 3, "devices": 5, "bundle_ids": 2, "profiles": 4 },
    "certificates": [...],
    "devices": [...],
    "bundle_ids": [...],
    "profiles": [...]
  }
}
```

### POST `/accounts` — 创建账号

```json
// Request
{ "name": "My Account", "issuer_id": "xxx", "key_id": "xxx", "private_key": "-----BEGIN PRIVATE KEY-----\n..." }
```

### PUT `/accounts/:id` — 更新账号

### DELETE `/accounts/:id` — 删除账号

### GET `/accounts/:id/download-p8` — 下载 P8 文件

> 返回文件流

### POST `/accounts/:id/test` — 测试 API 连接

```json
// Response
{ "success": true, "message": "API 连接成功", "data": { "issuer_id": "", "key_id": "", "certificates_found": 3 } }
```

### POST `/accounts/upload-p8` — 上传 P8 文件

> Content-Type: multipart/form-data, field: `file`

### POST `/accounts/validate-p8` — 验证 P8 内容

```json
// Request
{ "content": "-----BEGIN PRIVATE KEY-----\n..." }
```

### POST `/accounts/import-p8` — 快速导入 P8

```json
// Request
{ "name": "My Key", "issuer_id": "xxx", "key_id": "xxx", "private_key": "..." }
// 或 multipart/form-data: file + name + issuer_id + key_id
```

---

## 4. 设备管理 `/devices`

### GET `/devices?account_id=xxx` — 设备列表（自动同步 Apple）

### GET `/devices/:deviceId/detail` — 设备详情（含关联证书、描述文件）

```json
// Response
{
  "success": true,
  "data": {
    "id": "", "name": "", "udid": "", "platform": "IOS", "status": "ENABLED",
    "certificates": [{ "id": "", "name": "", "type": "", "has_p12": true, "password": "123456" }],
    "profiles": [{ "id": "", "name": "", "type": "", "has_file": true }]
  }
}
```

### POST `/devices` — 注册设备

```json
// Request
{ "account_id": "xxx", "name": "iPhone 15", "udid": "xxx", "platform": "IOS" }
```

### POST `/devices/batch` — 批量注册

```json
// Request
{ "account_id": "xxx", "devices": [{ "name": "iPhone 15", "udid": "xxx", "platform": "IOS" }] }
```

### POST `/devices/auto-bindall` — 一键绑定（注册设备+创建证书+描述文件）

```json
// Request
{
  "account_id": "xxx",
  "name": "iPhone 15", "udid": "xxx", "platform": "IOS",
  "bundle_identifier": "com.example.app", "bundle_name": "My App",
  "cert_type": "IOS_DEVELOPMENT",
  "profile_type": "IOS_APP_DEVELOPMENT",
  "password": "123456"
}

// Response
{
  "success": true,
  "data": {
    "steps": ["注册设备成功", "创建证书成功", "创建 Bundle ID 成功", "创建描述文件成功"],
    "device": { ... },
    "certificate": { "id": "", "p12_path": "xxx.p12", "password": "123456" },
    "bundle_id": { ... },
    "profile": { "id": "", "profile_path": "xxx.mobileprovision" }
  }
}
```

### GET `/devices/:deviceId/resources` — 设备关联的证书和描述文件

### GET `/devices/:deviceId/download-bundle?cert_id=&profile_id=` — 打包下载 ZIP

> 返回 ZIP 文件（包含 P12 + .mobileprovision + 密码.txt）

---

## 5. 证书管理 `/certificates`

### GET `/certificates/types` — 证书类型列表

```json
// Response
{ "success": true, "data": [{ "value": "IOS_DEVELOPMENT", "label": "iOS 开发证书", "desc": "..." }] }
```

### GET `/certificates/quota?account_id=xxx` — 证书配额查询

```json
// Response
{
  "success": true,
  "data": {
    "IOS_DEVELOPMENT": { "label": "iOS 开发证书", "used": 1, "limit": 2, "available": 1 },
    "IOS_DISTRIBUTION": { "label": "iOS 发布证书", "used": 3, "limit": 3, "available": 0 }
  },
  "total_certs": 4
}
```

### GET `/certificates?account_id=xxx` — 证书列表（自动同步 Apple）

### POST `/certificates/create` — 创建证书（内置 CSR，自动生成 P12）

```json
// Request
{
  "account_id": "xxx",
  "type": "IOS_DEVELOPMENT",
  "name": "My Cert",
  "password": "123456",
  "revoke_and_recreate": false  // true = 配额已满时自动撤销旧证书并重创
}
```

### POST `/certificates/self-sign` — 创建自签证书

```json
// Request
{ "name": "Self-Signed", "password": "123456", "subject": { "commonName": "Dev", "email": "dev@test.com" } }
// 或指定 CA:
{ "name": "xxx", "password": "xxx", "ca_cert": "PEM...", "ca_private_key": "PEM...", "subject": {} }
```

### POST `/certificates/generate-ca` — 生成 CA 根证书

```json
// Request
{ "commonName": "My CA", "organization": "Org", "country": "CN", "years": 10 }
```

### GET `/certificates/:id/detail` — 证书详情

### GET `/certificates/:id/download` — 下载 P12（无私钥时自动降级下载 CER）

> 返回文件流

### GET `/certificates/:id/download-cer` — 下载 CER

> 返回文件流

### DELETE `/certificates/:id` — 删除/撤销证书

### GET `/certificates/relations?account_id=xxx` — 证书-描述文件关联关系

### GET `/certificates/push-guide` — 推送证书配置指南

---

## 6. 描述文件 `/profiles`

### GET `/profiles/types` — 描述文件类型

### GET `/profiles?account_id=xxx` — 描述文件列表

### POST `/profiles/create` — 创建描述文件

```json
// Request
{
  "account_id": "xxx",
  "name": "Dev Profile",
  "type": "IOS_APP_DEVELOPMENT",
  "bundle_id": "apple-bundle-id",
  "certificate_ids": ["cert-id"],
  "device_ids": ["device-id-1", "device-id-2"]
}
```

### GET `/profiles/:id/download` — 下载 .mobileprovision

### DELETE `/profiles/:id` — 删除描述文件

### GET `/profiles/bundle-ids?account_id=xxx` — Bundle ID 列表

### POST `/profiles/bundle-ids` — 创建 Bundle ID

```json
// Request
{ "account_id": "xxx", "identifier": "com.example.app", "name": "My App", "platform": "IOS" }
```

### DELETE `/profiles/bundle-ids/:id` — 删除 Bundle ID

---

## 7. 权限管理 `/capabilities`

### GET `/capabilities/available` — 所有可用权限和预设

### GET `/capabilities/:bundleId?account_id=xxx` — 某 Bundle ID 的权限列表

### POST `/capabilities/enable` — 开启权限

```json
// Request
{ "account_id": "xxx", "bundle_id": "apple-bundle-id", "capability_type": "PUSH_NOTIFICATIONS" }
```

### POST `/capabilities/disable` — 关闭权限

```json
// Request
{ "account_id": "xxx", "capability_id": "cap-id" }
```

### POST `/capabilities/batch-enable` — 批量开启

```json
// Request
{ "account_id": "xxx", "bundle_id": "xxx", "capability_types": ["PUSH_NOTIFICATIONS", "APP_GROUPS"] }
```

### POST `/capabilities/batch-disable` — 批量关闭

```json
// Request
{ "account_id": "xxx", "capability_ids": ["cap-id-1", "cap-id-2"] }
```

---

## 8. 推送服务 `/push`

### POST `/push/send` — 发送 APNs 推送

```json
// Request（三种认证方式任选其一）
{
  // 方式1: 使用已导入的推送密钥
  "push_key_id": "key-uuid",
  // 方式2: 使用账号的 p8
  "account_id": "xxx", "team_id": "xxx",
  // 方式3: 手动填写
  "key_id": "xxx", "team_id": "xxx", "private_key": "-----BEGIN PRIVATE KEY-----\n...",

  "device_token": "xxx",
  "bundle_id": "com.example.app",
  "title": "Hello",
  "body": "World",
  "badge": 1,
  "sound": "default",
  "sandbox": true,
  "custom_data": {}
}
```

### GET `/push/error-codes` — APNs 错误码说明

---

## 9. 推送密钥 `/push-keys`

### GET `/push-keys` — 列表
### POST `/push-keys` — 创建（支持 multipart/form-data 上传 .p8 文件）
### PUT `/push-keys/:id` — 更新
### DELETE `/push-keys/:id` — 删除
### GET `/push-keys/:id/download` — 下载 .p8 文件

---

## 10. UDID 获取 `/udid`（无需认证）

### POST `/udid/create-request` — 创建获取请求

```json
// Response
{ "success": true, "data": { "request_id": "uuid" } }
```

### GET `/udid/enroll/:requestId?host=http://xxx:3000` — 获取 .mobileconfig

> iPhone 访问此 URL 安装描述文件

### POST `/udid/callback/:requestId` — Apple 设备回调（系统自动调用）

> iPhone 安装 .mobileconfig 后 Apple 自动 POST 设备信息到此接口，返回 301 重定向到结果页。客户端无需主动调用。

### GET `/udid/result/:requestId` — 轮询 UDID 结果

```json
// Response
{
  "success": true,
  "data": { "status": "received", "udid": "xxx", "product": "iPhone15,2", "version": "17.0" }
}
```

---

## 11. 健康检查 `/healthcheck`

### GET `/healthcheck/local` — 本地证书/描述文件健康检查
### GET `/healthcheck/remote?account_id=xxx` — 远程 Apple API 连通性检查

---

## 通用响应格式

```json
// 成功
{ "success": true, "data": {}, "message": "操作成功" }

// 失败
{ "success": false, "message": "错误描述" }
```

## 错误码

| HTTP Status | 含义 |
|-------------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未认证/token 过期 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 409 | 冲突（如证书配额已满） |
| 500 | 服务器错误 |

---

## 推送服务接入指南

CertVault 提供 APNs 推送代发服务，其他应用无需自建推送后端，直接调用 API 即可向 iOS 设备发送远程推送。

### 推送服务地址

```
http://114.66.31.109:3006/api/push/send
```

### 前置条件

1. 在 CertVault 管理后台注册账号并登录
2. 在「推送密钥」页面导入 .p8 推送密钥（Key ID + Team ID）
3. 目标 App 已在真机上注册推送并获取 Device Token

### 第一步：获取认证 Token

```bash
curl -X POST http://114.66.31.109:3006/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}'
```

响应：

```json
{
  "success": true,
  "data": {
    "token": "xxxxxxxxxxxxxxxx",
    "user": { "id": "...", "username": "...", "role": "user" }
  }
}
```

### 第二步：目标 App 注册推送

在目标 App 的 AppDelegate 中获取 Device Token：

```swift
// Swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    print("Device Token: \(token)")
    // 保存这个 token，发送推送时需要用到
}
```

```objc
// Objective-C
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    const unsigned char *bytes = (const unsigned char *)deviceToken.bytes;
    NSMutableString *token = [NSMutableString string];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [token appendFormat:@"%02x", bytes[i]];
    }
    NSLog(@"Device Token: %@", token);
}
```

### 第三步：发送推送

```bash
curl -X POST http://114.66.31.109:3006/api/push/send \
  -H "Authorization: Bearer <your_auth_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "push_key_id": "<CertVault中的推送密钥ID>",
    "device_token": "<64位十六进制DeviceToken>",
    "bundle_id": "com.example.yourapp",
    "title": "消息标题",
    "body": "消息内容",
    "badge": 1,
    "sound": "default",
    "sandbox": true,
    "custom_data": {
      "type": "order",
      "order_id": "12345"
    }
  }'
```

### 请求参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| push_key_id | string | 三选一 | CertVault 推送密钥 ID |
| account_id | string | 三选一 | CertVault 账号 ID（需配合 team_id） |
| key_id + team_id + private_key | string | 三选一 | 手动传入密钥信息 |
| device_token | string | 是 | 目标设备 Token（64 位十六进制） |
| bundle_id | string | 是 | 目标 App 的 Bundle Identifier |
| title | string | 是 | 推送标题 |
| body | string | 否 | 推送正文 |
| badge | number | 否 | 角标数字 |
| sound | string | 否 | 提示音，默认 `default` |
| sandbox | boolean | 否 | `true` 沙盒环境，`false` 生产环境，默认 `true` |
| custom_data | object | 否 | 自定义数据，会合并到推送 payload 中 |

### 响应示例

成功：

```json
{
  "success": true,
  "message": "推送发送成功",
  "data": { "apns_id": "550e8400-e29b-41d4-a716-446655440000", "status": 200 }
}
```

失败：

```json
{
  "success": false,
  "message": "推送失败: BadDeviceToken",
  "data": { "status": 400, "reason": "BadDeviceToken" }
}
```

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| InvalidProviderToken | JWT 签名失败 | 检查 Key ID 和 Team ID 是否正确（Team ID 是 10 位，不是 Issuer ID） |
| BadDeviceToken | Token 格式无效 | 确认是 64 位十六进制字符串，真机获取 |
| DeviceTokenNotForTopic | Token 与 Bundle ID 不匹配 | 确认 Device Token 对应的 App 的 Bundle ID |
| Unregistered | 设备已注销 | 用户可能卸载了 App，停止向该 Token 推送 |
| BadMessageId | apns-id 格式错误 | 服务端问题，升级到最新版本 |

### 环境说明

| 环境 | sandbox 值 | 适用场景 |
|------|-----------|---------|
| 沙盒 | `true` | Xcode 开发调试、TestFlight 测试 |
| 生产 | `false` | App Store 正式版 |

> 一个 .p8 推送密钥可以给同一开发者账号下的所有 App 发送推送，无需为每个 App 单独创建。
