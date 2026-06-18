const express = require('express');
const router = express.Router();
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount } = require('../services/account-helper');
const { getDb } = require('../config/database');
const {
  parseTesterName,
  validateTesterEmail,
  addTesterToBetaGroupAfterConnect,
} = require('../services/beta-tester-invite');

function normalizeSlug(input) {
  return (input || '').trim();
}

async function getShareContext(slug) {
  const normalizedSlug = normalizeSlug(slug);
  if (!normalizedSlug || normalizedSlug.length > 80) {
    throw Object.assign(new Error('无效的链接'), { status: 400 });
  }

  const db = getDb();
  const row = await db.prepare('SELECT * FROM tf_share_links WHERE slug = ?').get(normalizedSlug);
  if (!row) {
    throw Object.assign(new Error('链接无效或已失效'), { status: 404 });
  }

  const account = await getDecryptedAccount(row.account_id);
  if (!account) {
    throw Object.assign(new Error('关联账号不存在或已失效'), { status: 404 });
  }

  const api = new AppleApiService(account);
  const groupResult = await api.request('GET', `/betaGroups/${row.group_id}`, null, {
    'fields[betaGroups]':
      'name,isInternalGroup,publicLinkEnabled,publicLink,publicLinkLimit,publicLinkLimitEnabled,createdDate',
    include: 'app',
    'fields[apps]': 'name,bundleId',
  });

  const group = groupResult.data;
  if (!group) {
    throw Object.assign(new Error('测试组已不存在'), { status: 404 });
  }

  const appData = (groupResult.included || []).find(item => item.type === 'apps');
  return { row, api, group, appData };
}

/**
 * 无需登录：展示页面信息（应用名、测试组名）
 * GET /api/public/tf/:slug
 */
router.get('/tf/:slug', async (req, res, next) => {
  try {
    const { group, appData } = await getShareContext(req.params.slug);

    res.json({
      success: true,
      data: {
        group_name: group.attributes?.name,
        is_internal: group.attributes?.isInternalGroup,
        app_name: appData?.attributes?.name,
        bundle_id: appData?.attributes?.bundleId,
        public_link_enabled: group.attributes?.publicLinkEnabled,
        public_link: group.attributes?.publicLink || null,
        public_link_limit: group.attributes?.publicLinkLimit,
        public_link_limit_enabled: group.attributes?.publicLinkLimitEnabled,
        join_enabled: !group.attributes?.isInternalGroup,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * 无需登录：填写姓名、邮箱后加入测试组（App Store Connect）
 * POST /api/public/tf/:slug/join
 * body: { email, full_name }
 */
router.post('/tf/:slug/join', async (req, res, next) => {
  try {
    const email = (req.body?.email || '').trim();
    const hasNameInput = [
      req.body?.full_name,
      req.body?.name,
      req.body?.first_name,
      req.body?.last_name,
    ].some(value => String(value || '').trim());

    if (!email) {
      return res.status(400).json({ success: false, message: '请填写邮箱' });
    }
    if (!validateTesterEmail(email)) {
      return res.status(400).json({ success: false, message: '邮箱格式不正确' });
    }
    if (!hasNameInput) {
      return res.status(400).json({ success: false, message: '请填写姓名' });
    }

    const { api, group, appData } = await getShareContext(req.params.slug);
    if (group.attributes?.isInternalGroup) {
      return res.status(400).json({
        success: false,
        message: '当前分享的是内部测试组，不能通过公开页面报名加入',
      });
    }

    const { firstName, lastName } = parseTesterName(req.body);
    const result = await addTesterToBetaGroupAfterConnect(api, {
      email,
      groupId: group.id,
      firstName,
      lastName,
    });

    res.json({
      success: true,
      message: '提交成功，已自动加入测试组',
      data: {
        email,
        group_name: group.attributes?.name,
        app_name: appData?.attributes?.name,
        public_link_enabled: group.attributes?.publicLinkEnabled,
        public_link: group.attributes?.publicLink || null,
        invite: result,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
