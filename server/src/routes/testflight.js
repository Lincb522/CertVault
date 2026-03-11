const express = require('express');
const router = express.Router();
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');

async function getApi(req) {
  const accountId = req.query.account_id || req.body.account_id;
  if (!accountId) throw Object.assign(new Error('请选择账号'), { status: 400 });
  const allowed = await checkAccountOwnership(accountId, req.user);
  if (!allowed) throw Object.assign(new Error('无权操作此账号'), { status: 403 });
  const account = await getDecryptedAccount(accountId);
  return new AppleApiService(account);
}

// ---- Beta Groups ----
router.get('/groups', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const params = {
      'fields[betaGroups]': 'name,isInternalGroup,publicLinkEnabled,publicLinkLimit,publicLink,createdDate',
      limit: req.query.limit || 50,
    };
    if (req.query.app_id) {
      params['filter[app]'] = req.query.app_id;
    }
    const result = await api.listBetaGroups(params);
    const groups = (result.data || []).map(g => ({
      id: g.id,
      name: g.attributes?.name,
      is_internal: g.attributes?.isInternalGroup,
      public_link_enabled: g.attributes?.publicLinkEnabled,
      public_link: g.attributes?.publicLink,
      public_link_limit: g.attributes?.publicLinkLimit,
      created_date: g.attributes?.createdDate,
    }));
    res.json({ success: true, data: groups });
  } catch (err) { next(err); }
});

router.post('/groups', async (req, res, next) => {
  try {
    const { app_id, name, is_internal } = req.body;
    if (!app_id || !name) return res.status(400).json({ success: false, message: '请填写 App 和分组名称' });
    const api = await getApi(req);
    const result = await api.createBetaGroup(app_id, name, is_internal || false);
    res.json({ success: true, data: result.data, message: '分组创建成功' });
  } catch (err) { next(err); }
});

router.delete('/groups/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    await api.deleteBetaGroup(req.params.id);
    res.json({ success: true, message: '分组已删除' });
  } catch (err) { next(err); }
});

router.get('/groups/:id/testers', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.listGroupTesters(req.params.id);
    const testers = (result.data || []).map(t => ({
      id: t.id,
      email: t.attributes?.email,
      first_name: t.attributes?.firstName,
      last_name: t.attributes?.lastName,
      invite_type: t.attributes?.inviteType,
      state: t.attributes?.state,
    }));
    res.json({ success: true, data: testers });
  } catch (err) { next(err); }
});

router.post('/groups/:id/testers', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { tester_ids } = req.body;
    if (!tester_ids?.length) return res.status(400).json({ success: false, message: '请选择测试员' });
    await api.addTesterToGroup(req.params.id, tester_ids);
    res.json({ success: true, message: '测试员已添加到分组' });
  } catch (err) { next(err); }
});

router.delete('/groups/:id/testers', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { tester_ids } = req.body;
    if (!tester_ids?.length) return res.status(400).json({ success: false, message: '请选择测试员' });
    await api.removeTesterFromGroup(req.params.id, tester_ids);
    res.json({ success: true, message: '测试员已从分组移除' });
  } catch (err) { next(err); }
});

router.post('/groups/:id/builds', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { build_ids, whats_new, locale } = req.body;
    if (!build_ids?.length) return res.status(400).json({ success: false, message: '请选择构建版本' });

    if (whats_new) {
      const loc = locale || 'en-US';
      for (const buildId of build_ids) {
        try {
          const existing = await api.listBetaBuildLocalizations(buildId);
          const match = (existing.data || []).find(l => l.attributes?.locale === loc);
          if (match) {
            await api.updateBetaBuildLocalization(match.id, whats_new);
          } else {
            await api.createBetaBuildLocalization(buildId, loc, whats_new);
          }
        } catch (e) {
          console.warn(`设置构建 ${buildId} 测试内容失败:`, e.message);
        }
      }
    }

    await api.addBuildToGroup(req.params.id, build_ids);
    res.json({ success: true, message: '构建已分发到测试分组' });
  } catch (err) { next(err); }
});

// ---- Build Detail (includes betaGroups via include) ----
router.get('/builds/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const query = new URLSearchParams({
      include: 'buildBetaDetail,betaBuildLocalizations,betaGroups',
      'fields[betaGroups]': 'name,isInternalGroup',
    }).toString();
    const result = await api.request('GET', `/builds/${req.params.id}?${query}`);
    const b = result.data;
    const included = result.included || [];
    const betaDetail = included.find(i => i.type === 'buildBetaDetails');
    const localizations = included
      .filter(i => i.type === 'betaBuildLocalizations')
      .map(l => ({
        id: l.id,
        locale: l.attributes?.locale,
        whats_new: l.attributes?.whatsNew,
      }));
    const groups = included
      .filter(i => i.type === 'betaGroups')
      .map(g => ({
        id: g.id,
        name: g.attributes?.name,
        is_internal: g.attributes?.isInternalGroup,
      }));

    res.json({
      success: true,
      data: {
        id: b.id,
        version: b.attributes?.version,
        uploaded_date: b.attributes?.uploadedDate,
        expiration_date: b.attributes?.expirationDate,
        expired: b.attributes?.expired,
        processing_state: b.attributes?.processingState,
        min_os_version: b.attributes?.minOsVersion,
        auto_notify_enabled: betaDetail?.attributes?.autoNotifyEnabled,
        external_build_state: betaDetail?.attributes?.externalBuildState,
        internal_build_state: betaDetail?.attributes?.internalBuildState,
        localizations,
        groups,
      }
    });
  } catch (err) { next(err); }
});

// ---- Build Beta Localizations ----
router.get('/builds/:id/localizations', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.listBetaBuildLocalizations(req.params.id);
    const locs = (result.data || []).map(l => ({
      id: l.id,
      locale: l.attributes?.locale,
      whats_new: l.attributes?.whatsNew,
    }));
    res.json({ success: true, data: locs });
  } catch (err) { next(err); }
});

router.put('/builds/:id/localizations', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { whats_new, locale } = req.body;
    if (!whats_new) return res.status(400).json({ success: false, message: '请填写测试内容' });
    const loc = locale || 'en-US';
    const existing = await api.listBetaBuildLocalizations(req.params.id);
    const match = (existing.data || []).find(l => l.attributes?.locale === loc);
    let result;
    if (match) {
      result = await api.updateBetaBuildLocalization(match.id, whats_new);
    } else {
      result = await api.createBetaBuildLocalization(req.params.id, loc, whats_new);
    }
    res.json({ success: true, data: result.data, message: '测试内容已更新' });
  } catch (err) { next(err); }
});

// ---- Beta Testers ----
router.get('/testers', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const params = {
      'fields[betaTesters]': 'email,firstName,lastName,inviteType,state',
      limit: req.query.limit || 100,
    };
    if (req.query.email) params['filter[email]'] = req.query.email;
    const result = await api.listBetaTesters(params);
    const testers = (result.data || []).map(t => ({
      id: t.id,
      email: t.attributes?.email,
      first_name: t.attributes?.firstName,
      last_name: t.attributes?.lastName,
      invite_type: t.attributes?.inviteType,
      state: t.attributes?.state,
    }));
    res.json({ success: true, data: testers });
  } catch (err) { next(err); }
});

router.post('/testers', async (req, res, next) => {
  try {
    const { email, first_name, last_name, group_ids } = req.body;
    if (!email) return res.status(400).json({ success: false, message: '请填写邮箱' });
    const api = await getApi(req);
    const result = await api.createBetaTester(email, first_name || '', last_name || '', group_ids || []);
    res.json({ success: true, data: result.data, message: '测试员已添加' });
  } catch (err) { next(err); }
});

router.delete('/testers/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    await api.deleteBetaTester(req.params.id);
    res.json({ success: true, message: '测试员已删除' });
  } catch (err) { next(err); }
});

// ---- Builds ----
router.get('/builds', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const params = {
      'fields[builds]': 'version,uploadedDate,expirationDate,expired,processingState,minOsVersion',
      limit: req.query.limit || 50,
      sort: '-uploadedDate',
    };
    if (req.query.app_id) params['filter[app]'] = req.query.app_id;
    const result = await api.listBuilds(params);
    const builds = (result.data || []).map(b => ({
      id: b.id,
      version: b.attributes?.version,
      uploaded_date: b.attributes?.uploadedDate,
      expiration_date: b.attributes?.expirationDate,
      expired: b.attributes?.expired,
      processing_state: b.attributes?.processingState,
      min_os_version: b.attributes?.minOsVersion,
    }));
    res.json({ success: true, data: builds });
  } catch (err) { next(err); }
});

module.exports = router;
