const express = require('express');
const router = express.Router();
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');

const ALL_CAPABILITIES = [
  { type: 'PUSH_NOTIFICATIONS', label: '推送通知', category: 'common', desc: '向用户发送远程推送消息', requirement: '需配置 APNs 证书或 Key，需要服务端支持' },
  { type: 'APPLE_ID_AUTH', label: 'Sign in with Apple', category: 'common', desc: '通过 Apple ID 登录应用', requirement: '使用第三方登录的 App 必须同时支持此功能 (App Store 审核要求)' },
  { type: 'IN_APP_PURCHASE', label: '应用内购买 (IAP)', category: 'common', desc: '在应用内销售数字内容或订阅服务', requirement: '需在 App Store Connect 中配置商品，需签署付费协议' },
  { type: 'APP_GROUPS', label: 'App Groups (应用分组)', category: 'common', desc: '在同一开发者的多个 App 或扩展之间共享数据', requirement: '需指定 Group ID (如 group.com.example.shared)' },
  { type: 'ASSOCIATED_DOMAINS', label: 'Associated Domains (关联域名)', category: 'common', desc: '支持 Universal Links、Handoff、App Clips 等', requirement: '需在服务器根目录放置 apple-app-site-association 文件' },
  { type: 'ICLOUD', label: 'iCloud', category: 'common', desc: '使用 iCloud 存储、CloudKit 数据库或 Key-Value 同步', requirement: '需选择 CloudKit 或 Key-Value 存储类型' },
  { type: 'APPLE_PAY', label: 'Apple Pay', category: 'payment', desc: '在应用内集成 Apple Pay 支付', requirement: '需注册 Merchant ID 并配置支付证书' },
  { type: 'WALLET', label: 'Wallet (钱包)', category: 'payment', desc: '创建和管理电子凭证 (登机牌、会员卡、优惠券等)', requirement: '需申请 Pass Type ID 并配置签名证书' },
  { type: 'GAME_CENTER', label: 'Game Center', category: 'media', desc: '排行榜、成就、多人游戏等社交游戏功能', requirement: '需在 App Store Connect 中配置 Game Center 功能' },
  { type: 'HEALTHKIT', label: 'HealthKit', category: 'device', desc: '访问和存储用户的健康与运动数据', requirement: '必须提供隐私政策说明，App Store 审核严格检查用途' },
  { type: 'HOMEKIT', label: 'HomeKit', category: 'device', desc: '控制智能家居配件', requirement: '需加入 MFi 计划或使用 HomeKit ADK' },
  { type: 'SIRIKIT', label: 'SiriKit', category: 'device', desc: '让 Siri 可以与你的 App 交互', requirement: '需定义支持的 Intent 类型' },
  { type: 'NFC_TAG_READING', label: 'NFC 标签读取', category: 'device', desc: '读取 NFC 标签数据 (NDEF)', requirement: '仅 iPhone 7 及以上设备支持' },
  { type: 'MAPS', label: '地图 (Maps)', category: 'media', desc: '在 Apple 地图中展示路线规划', requirement: '无特殊要求' },
  { type: 'NETWORK_EXTENSIONS', label: '网络扩展', category: 'network', desc: '自定义网络协议、VPN、内容过滤器等', requirement: '需向 Apple 申请额外授权 (entitlement request)' },
  { type: 'PERSONAL_VPN', label: 'Personal VPN', category: 'network', desc: '创建和管理 VPN 连接配置', requirement: '需向 Apple 申请额外授权' },
  { type: 'ACCESS_WIFI_INFORMATION', label: 'WiFi 信息访问', category: 'network', desc: '获取当前连接的 WiFi 网络名称 (SSID) 和 BSSID', requirement: '需开启定位权限才能获取 WiFi 信息' },
  { type: 'HOT_SPOT', label: '热点配置', category: 'network', desc: '管理 WiFi 热点配置', requirement: '需向 Apple 申请额外授权' },
  { type: 'MULTIPATH', label: 'Multipath (多路径)', category: 'network', desc: '同时使用 WiFi 和蜂窝网络传输数据提高可靠性', requirement: '需向 Apple 申请额外授权' },
  { type: 'NETWORK_CUSTOM_PROTOCOL', label: '自定义网络协议', category: 'network', desc: '实现自定义网络传输协议', requirement: '需向 Apple 申请额外授权' },
  { type: 'DATA_PROTECTION', label: '数据保护', category: 'security', desc: '对文件进行加密保护，设备锁定时数据不可访问', requirement: '需选择保护级别 (Complete / Unless Open / After First Unlock)' },
  { type: 'AUTOFILL_CREDENTIAL_PROVIDER', label: '自动填充凭证', category: 'security', desc: '作为密码管理器提供自动填充功能', requirement: '需实现 ASCredentialProviderViewController' },
  { type: 'INTER_APP_AUDIO', label: '应用间音频', category: 'media', desc: '在不同音频 App 之间传输音频流', requirement: '已在 iOS 13+ 废弃' },
  { type: 'CLASSKIT', label: 'ClassKit', category: 'media', desc: '与课堂 App 集成，用于教育场景', requirement: '需在 ClassKit Catalog 中注册上下文' },
  { type: 'WIRELESS_ACCESSORY_CONFIGURATION', label: '无线配件配置', category: 'device', desc: '配置 MFi WiFi 配件', requirement: '需加入 MFi 计划' },
  { type: 'COREMEDIA_HLS_LOW_LATENCY', label: 'HLS 低延迟', category: 'media', desc: '支持低延迟 HLS 直播流', requirement: '无特殊要求' },
  { type: 'SYSTEM_EXTENSION_INSTALL', label: '系统扩展', category: 'device', desc: '安装系统扩展 (仅 macOS)', requirement: '仅 macOS 可用，需向 Apple 申请额外授权' },
  { type: 'USER_MANAGEMENT', label: '用户管理', category: 'device', desc: '管理企业用户 (仅 MDM)', requirement: '仅 MDM 方案可用' },
  { type: 'FONT_INSTALLATION', label: '字体安装', category: 'media', desc: '在系统中安装自定义字体', requirement: '无特殊要求' },
];

const COMMON_PRESETS = {
  basic: { label: '基础常用', desc: '推送 + 内购 + Sign in with Apple', types: ['PUSH_NOTIFICATIONS', 'IN_APP_PURCHASE', 'APPLE_ID_AUTH'] },
  social: { label: '社交应用', desc: '推送 + Sign in + Associated Domains + App Groups', types: ['PUSH_NOTIFICATIONS', 'APPLE_ID_AUTH', 'ASSOCIATED_DOMAINS', 'APP_GROUPS'] },
  game: { label: '游戏应用', desc: '推送 + 内购 + Game Center + Sign in + iCloud', types: ['PUSH_NOTIFICATIONS', 'IN_APP_PURCHASE', 'GAME_CENTER', 'APPLE_ID_AUTH', 'ICLOUD'] },
  enterprise: { label: '企业应用', desc: '推送 + App Groups + Associated Domains + 数据保护 + VPN', types: ['PUSH_NOTIFICATIONS', 'APP_GROUPS', 'ASSOCIATED_DOMAINS', 'DATA_PROTECTION', 'PERSONAL_VPN'] }
};

router.get('/available', (req, res) => {
  const categoriesMap = {};
  ALL_CAPABILITIES.forEach(cap => {
    if (!categoriesMap[cap.category]) categoriesMap[cap.category] = [];
    categoriesMap[cap.category].push(cap.type);
  });

  res.json({
    success: true,
    data: {
      capabilities: ALL_CAPABILITIES.map(c => ({
        type: c.type,
        name: c.label,
        category: c.category,
        description: c.desc,
        requirements: c.requirement,
      })),
      presets: Object.fromEntries(
        Object.entries(COMMON_PRESETS).map(([k, v]) => [k, v.types])
      ),
      categories: categoriesMap,
    }
  });
});

router.get('/:bundleId', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的权限' });
    }

    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const result = await api.listCapabilities(req.params.bundleId);

    const enabled = (result.data || []).map(cap => ({
      id: cap.id,
      type: cap.attributes.capabilityType,
      settings: cap.attributes.settings || []
    }));

    const enabledTypes = enabled.map(c => c.type);
    const capabilities = ALL_CAPABILITIES.map(cap => ({
      type: cap.type,
      name: cap.label,
      category: cap.category,
      description: cap.desc,
      enabled: enabledTypes.includes(cap.type),
      id: enabled.find(c => c.type === cap.type)?.id || null,
      settings: enabled.find(c => c.type === cap.type)?.settings || []
    }));

    res.json({ success: true, data: capabilities });
  } catch (err) {
    next(err);
  }
});

router.post('/enable', async (req, res, next) => {
  try {
    const { account_id, bundle_id, capability_type, settings = [] } = req.body;
    if (!account_id || !bundle_id || !capability_type) {
      return res.status(400).json({ success: false, message: '缺少必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的权限' });
    }

    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const result = await api.enableCapability(bundle_id, capability_type, settings);

    res.json({ success: true, data: result.data });
  } catch (err) {
    next(err);
  }
});

router.post('/disable', async (req, res, next) => {
  try {
    const { account_id, capability_id } = req.body;
    if (!account_id || !capability_id) {
      return res.status(400).json({ success: false, message: '缺少必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的权限' });
    }

    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    await api.disableCapability(capability_id);

    res.json({ success: true, message: '权限已关闭' });
  } catch (err) {
    next(err);
  }
});

router.post('/batch-enable', async (req, res, next) => {
  try {
    const { account_id, bundle_id, capability_types = [] } = req.body;
    if (!account_id || !bundle_id || !capability_types.length) {
      return res.status(400).json({ success: false, message: '缺少必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的权限' });
    }

    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const results = [];
    const errors = [];

    for (const type of capability_types) {
      try {
        await api.enableCapability(bundle_id, type, []);
        results.push({ type, success: true });
      } catch (err) {
        errors.push({ type, success: false, message: err.message });
      }
    }

    res.json({ success: true, data: { results, errors } });
  } catch (err) {
    next(err);
  }
});

router.post('/batch-disable', async (req, res, next) => {
  try {
    const { account_id, capability_ids = [] } = req.body;
    if (!account_id || !capability_ids.length) {
      return res.status(400).json({ success: false, message: '缺少必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的权限' });
    }

    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const results = [];
    const errors = [];

    for (const id of capability_ids) {
      try {
        await api.disableCapability(id);
        results.push({ id, success: true });
      } catch (err) {
        errors.push({ id, success: false, message: err.message });
      }
    }

    res.json({ success: true, data: { results, errors } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
