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

router.get('/groups/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const groupResult = await api.request('GET', `/betaGroups/${req.params.id}`, null, {
      'fields[betaGroups]': 'name,isInternalGroup,publicLinkEnabled,publicLinkLimit,publicLink,publicLinkLimitEnabled,createdDate,feedbackEnabled,hasAccessToAllBuilds',
    });
    const g = groupResult.data;

    const testersResult = await api.listGroupTesters(req.params.id);
    const testers = (testersResult.data || []).map(t => ({
      id: t.id,
      email: t.attributes?.email,
      first_name: t.attributes?.firstName,
      last_name: t.attributes?.lastName,
      invite_type: t.attributes?.inviteType,
      state: t.attributes?.state,
    }));

    const buildsResult = await api.listGroupBuilds(req.params.id);
    const builds = (buildsResult.data || []).map(b => ({
      id: b.id,
      version: b.attributes?.version,
      uploaded_date: b.attributes?.uploadedDate,
      processing_state: b.attributes?.processingState,
      expired: b.attributes?.expired,
    }));

    let recruitment_criteria = null;
    try {
      const criteriaResult = await api.getBetaRecruitmentCriteria(req.params.id);
      const c = criteriaResult.data;
      if (c) {
        recruitment_criteria = {
          id: c.id,
          ...c.attributes,
        };
      }
    } catch (_) {}

    res.json({
      success: true,
      data: {
        id: g.id,
        name: g.attributes?.name,
        is_internal: g.attributes?.isInternalGroup,
        public_link_enabled: g.attributes?.publicLinkEnabled,
        public_link: g.attributes?.publicLink,
        public_link_limit: g.attributes?.publicLinkLimit,
        public_link_limit_enabled: g.attributes?.publicLinkLimitEnabled,
        feedback_enabled: g.attributes?.feedbackEnabled,
        has_access_to_all_builds: g.attributes?.hasAccessToAllBuilds,
        created_date: g.attributes?.createdDate,
        tester_count: testers.length,
        build_count: builds.length,
        testers,
        builds,
        recruitment_criteria,
      }
    });
  } catch (err) { next(err); }
});

router.put('/groups/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { name, public_link_enabled, public_link_limit, public_link_limit_enabled, feedback_enabled, has_access_to_all_builds } = req.body;
    const attributes = {};
    if (name !== undefined) attributes.name = name;
    if (public_link_enabled !== undefined) attributes.publicLinkEnabled = public_link_enabled;
    if (public_link_limit !== undefined) attributes.publicLinkLimit = public_link_limit;
    if (public_link_limit_enabled !== undefined) attributes.publicLinkLimitEnabled = public_link_limit_enabled;
    if (feedback_enabled !== undefined) attributes.feedbackEnabled = feedback_enabled;
    if (has_access_to_all_builds !== undefined) attributes.hasAccessToAllBuilds = has_access_to_all_builds;

    if (!Object.keys(attributes).length) {
      return res.status(400).json({ success: false, message: '没有需要更新的字段' });
    }

    const result = await api.updateBetaGroup(req.params.id, attributes);
    const g = result.data;
    res.json({
      success: true,
      message: '测试组设置已更新',
      data: {
        id: g.id,
        name: g.attributes?.name,
        public_link_enabled: g.attributes?.publicLinkEnabled,
        public_link: g.attributes?.publicLink,
        public_link_limit: g.attributes?.publicLinkLimit,
        feedback_enabled: g.attributes?.feedbackEnabled,
        has_access_to_all_builds: g.attributes?.hasAccessToAllBuilds,
      }
    });
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

    const betaReviewResults = [];
    for (const buildId of build_ids) {
      try {
        await api.submitForBetaReview(buildId);
        betaReviewResults.push({ buildId, submitted: true });
      } catch (e) {
        const msg = e.message || '';
        if (msg.includes('ENTITY_ERROR') || msg.includes('already') || msg.includes('CONFLICT')) {
          betaReviewResults.push({ buildId, submitted: true, note: '已提交过' });
        } else {
          betaReviewResults.push({ buildId, submitted: false, error: msg });
          console.warn(`构建 ${buildId} 提交 Beta 审核失败:`, msg);
        }
      }
    }

    res.json({ success: true, message: '构建已分发到测试分组并提交 Beta 审核', data: { beta_review: betaReviewResults } });
  } catch (err) { next(err); }
});

// ---- Beta App Review Submission ----
router.post('/builds/:id/submit-for-review', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.submitForBetaReview(req.params.id);
    res.json({ success: true, data: result.data, message: '已提交 Beta 审核' });
  } catch (err) {
    if (err.message?.includes('ENTITY_ERROR') || err.message?.includes('CONFLICT')) {
      return res.json({ success: true, message: '该构建已提交过 Beta 审核' });
    }
    next(err);
  }
});

router.get('/builds/:id/review-status', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getBetaAppReviewSubmission(req.params.id);
    const sub = result.data;
    res.json({
      success: true,
      data: sub ? {
        id: sub.id,
        beta_review_state: sub.attributes?.betaReviewState,
      } : null,
    });
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

// ---- Beta Recruitment Criteria (Device Conditions) ----
router.get('/groups/:id/criteria', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getBetaRecruitmentCriteria(req.params.id);
    const c = result.data;
    res.json({
      success: true,
      data: c ? { id: c.id, ...c.attributes } : null,
    });
  } catch (err) { next(err); }
});

router.post('/groups/:id/criteria', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const attributes = {};
    const { device_families, min_os_version, require_device_check } = req.body;
    if (device_families !== undefined) attributes.deviceFamilies = device_families;
    if (min_os_version !== undefined) attributes.minOsVersion = min_os_version;
    if (require_device_check !== undefined) attributes.requireDeviceCheck = require_device_check;

    const result = await api.createBetaRecruitmentCriteria(req.params.id, attributes);
    res.json({ success: true, data: result.data, message: '设备条件已设置' });
  } catch (err) { next(err); }
});

router.put('/groups/:id/criteria', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const existing = await api.getBetaRecruitmentCriteria(req.params.id);
    const criteriaId = existing.data?.id;
    if (!criteriaId) {
      return res.status(404).json({ success: false, message: '尚未设置设备条件，请先创建' });
    }

    const attributes = {};
    const { device_families, min_os_version, require_device_check } = req.body;
    if (device_families !== undefined) attributes.deviceFamilies = device_families;
    if (min_os_version !== undefined) attributes.minOsVersion = min_os_version;
    if (require_device_check !== undefined) attributes.requireDeviceCheck = require_device_check;

    const result = await api.updateBetaRecruitmentCriteria(criteriaId, attributes);
    res.json({ success: true, data: result.data, message: '设备条件已更新' });
  } catch (err) { next(err); }
});

router.delete('/groups/:id/criteria', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const existing = await api.getBetaRecruitmentCriteria(req.params.id);
    const criteriaId = existing.data?.id;
    if (!criteriaId) {
      return res.json({ success: true, message: '无设备条件需要删除' });
    }
    await api.deleteBetaRecruitmentCriteria(criteriaId);
    res.json({ success: true, message: '设备条件已删除' });
  } catch (err) { next(err); }
});

// ---- Builds ----
router.get('/builds', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const params = {
      'fields[builds]': 'version,uploadedDate,expirationDate,expired,processingState,minOsVersion,buildAudienceType,computedMinMacOsVersion,lsMinimumSystemVersion,iconAssetToken',
      include: 'buildBetaDetail,preReleaseVersion',
      'fields[buildBetaDetails]': 'externalBuildState,internalBuildState,autoNotifyEnabled',
      'fields[preReleaseVersions]': 'version,platform',
      limit: req.query.limit || 50,
      sort: '-uploadedDate',
    };
    if (req.query.app_id) params['filter[app]'] = req.query.app_id;
    const result = await api.listBuilds(params);
    const included = result.included || [];

    const betaDetailsMap = {};
    const preReleaseMap = {};
    for (const item of included) {
      if (item.type === 'buildBetaDetails') betaDetailsMap[item.id] = item;
      if (item.type === 'preReleaseVersions') preReleaseMap[item.id] = item;
    }

    const builds = (result.data || []).map(b => {
      const betaDetailRel = b.relationships?.buildBetaDetail?.data;
      const betaDetail = betaDetailRel ? betaDetailsMap[betaDetailRel.id] : null;
      const preRelRel = b.relationships?.preReleaseVersion?.data;
      const preRelVersion = preRelRel ? preReleaseMap[preRelRel.id] : null;

      return {
        id: b.id,
        version: b.attributes?.version,
        app_version: preRelVersion?.attributes?.version || null,
        platform: preRelVersion?.attributes?.platform || null,
        uploaded_date: b.attributes?.uploadedDate,
        expiration_date: b.attributes?.expirationDate,
        expired: b.attributes?.expired,
        processing_state: b.attributes?.processingState,
        min_os_version: b.attributes?.minOsVersion,
        build_audience_type: b.attributes?.buildAudienceType,
        icon_url: b.attributes?.iconAssetToken?.templateUrl?.replace('{w}', '64').replace('{h}', '64').replace('{f}', 'png') || null,
        external_build_state: betaDetail?.attributes?.externalBuildState || null,
        internal_build_state: betaDetail?.attributes?.internalBuildState || null,
        auto_notify_enabled: betaDetail?.attributes?.autoNotifyEnabled ?? null,
      };
    });
    res.json({ success: true, data: builds });
  } catch (err) { next(err); }
});

// ==================== 测试条件设置 ====================

// Beta App Review Detail (app-level: 联系人、登录信息、备注)
router.get('/apps/:appId/review-info', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getBetaAppReviewDetail(req.params.appId);
    const d = result.data;
    res.json({
      success: true,
      data: d ? {
        id: d.id,
        contact_email: d.attributes?.contactEmail,
        contact_first_name: d.attributes?.contactFirstName,
        contact_last_name: d.attributes?.contactLastName,
        contact_phone: d.attributes?.contactPhone,
        demo_account_name: d.attributes?.demoAccountName,
        demo_account_password: d.attributes?.demoAccountPassword,
        demo_account_required: d.attributes?.demoAccountRequired,
        notes: d.attributes?.notes,
      } : null,
    });
  } catch (err) { next(err); }
});

router.put('/apps/:appId/review-info', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const existing = await api.getBetaAppReviewDetail(req.params.appId);
    const detailId = existing.data?.id;
    if (!detailId) return res.status(404).json({ success: false, message: 'Beta 审核信息不存在' });

    const { contact_email, contact_first_name, contact_last_name, contact_phone,
            demo_account_name, demo_account_password, demo_account_required, notes } = req.body;
    const attributes = {};
    if (contact_email !== undefined) attributes.contactEmail = contact_email;
    if (contact_first_name !== undefined) attributes.contactFirstName = contact_first_name;
    if (contact_last_name !== undefined) attributes.contactLastName = contact_last_name;
    if (contact_phone !== undefined) attributes.contactPhone = contact_phone;
    if (demo_account_name !== undefined) attributes.demoAccountName = demo_account_name;
    if (demo_account_password !== undefined) attributes.demoAccountPassword = demo_account_password;
    if (demo_account_required !== undefined) attributes.demoAccountRequired = demo_account_required;
    if (notes !== undefined) attributes.notes = notes;

    const result = await api.updateBetaAppReviewDetail(detailId, attributes);
    res.json({ success: true, message: 'Beta 审核信息已更新', data: result.data });
  } catch (err) { next(err); }
});

// Beta License Agreement
router.get('/apps/:appId/license', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getBetaLicenseAgreement(req.params.appId);
    const d = result.data;
    res.json({
      success: true,
      data: d ? {
        id: d.id,
        agreement_text: d.attributes?.agreementText,
      } : null,
    });
  } catch (err) { next(err); }
});

router.put('/apps/:appId/license', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const existing = await api.getBetaLicenseAgreement(req.params.appId);
    const agreementId = existing.data?.id;
    if (!agreementId) return res.status(404).json({ success: false, message: 'Beta 许可协议不存在' });

    const { agreement_text } = req.body;
    if (!agreement_text) return res.status(400).json({ success: false, message: '请填写协议内容' });

    const result = await api.updateBetaLicenseAgreement(agreementId, agreement_text);
    res.json({ success: true, message: 'Beta 许可协议已更新', data: result.data });
  } catch (err) { next(err); }
});

// Build Beta Detail (auto-notify, etc.)
router.put('/builds/:id/beta-detail', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const betaDetailResult = await api.getBuildBetaDetail(req.params.id);
    const betaDetailId = betaDetailResult.data?.id;
    if (!betaDetailId) return res.status(404).json({ success: false, message: '构建 Beta 详情不存在' });

    const { auto_notify_enabled } = req.body;
    const attributes = {};
    if (auto_notify_enabled !== undefined) attributes.autoNotifyEnabled = auto_notify_enabled;

    const result = await api.updateBuildBetaDetail(betaDetailId, attributes);
    res.json({ success: true, message: '构建测试设置已更新', data: result.data });
  } catch (err) { next(err); }
});

module.exports = router;
