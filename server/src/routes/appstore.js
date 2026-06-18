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

const STATE_LABELS = {
  ACCEPTED: '已通过',
  DEVELOPER_REMOVED_FROM_SALE: '已下架',
  DEVELOPER_REJECTED: '开发者拒绝',
  IN_REVIEW: '审核中',
  INVALID_BINARY: '二进制无效',
  METADATA_REJECTED: '元数据被拒',
  PENDING_APPLE_RELEASE: '等待 Apple 发布',
  PENDING_CONTRACT: '等待合同',
  PENDING_DEVELOPER_RELEASE: '等待开发者发布',
  PREPARE_FOR_SUBMISSION: '准备提交',
  PREORDER_READY_FOR_SALE: '预售就绪',
  PROCESSING_FOR_APP_STORE: '处理中',
  READY_FOR_REVIEW: '待审核',
  READY_FOR_SALE: '已上架',
  REJECTED: '被拒绝',
  REMOVED_FROM_SALE: '已移除',
  WAITING_FOR_EXPORT_COMPLIANCE: '等待出口合规',
  WAITING_FOR_REVIEW: '等待审核',
  REPLACED_WITH_NEW_VERSION: '已被新版本替代',
  NOT_APPLICABLE: '不适用',
};

router.get('/versions', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { app_id } = req.query;
    if (!app_id) return res.status(400).json({ success: false, message: '请选择 App' });
    const result = await api.listAppStoreVersions(app_id, {
      'fields[appStoreVersions]': 'versionString,appStoreState,platform,releaseType,createdDate,appVersionState',
      limit: req.query.limit || 20,
    });
    const versions = (result.data || []).map(v => ({
      id: v.id,
      version: v.attributes?.versionString,
      state: v.attributes?.appStoreState || v.attributes?.appVersionState,
      state_label: STATE_LABELS[v.attributes?.appStoreState || v.attributes?.appVersionState] || v.attributes?.appStoreState,
      platform: v.attributes?.platform,
      release_type: v.attributes?.releaseType,
      created_date: v.attributes?.createdDate,
    }));
    res.json({ success: true, data: versions });
  } catch (err) { next(err); }
});

router.get('/versions/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getAppStoreVersion(req.params.id, 'appStoreVersionLocalizations');
    const v = result.data;
    const localizations = (result.included || [])
      .filter(i => i.type === 'appStoreVersionLocalizations')
      .map(l => ({
        id: l.id,
        locale: l.attributes?.locale,
        description: l.attributes?.description,
        keywords: l.attributes?.keywords,
        whats_new: l.attributes?.whatsNew,
        marketing_url: l.attributes?.marketingUrl,
        support_url: l.attributes?.supportUrl,
        promotional_text: l.attributes?.promotionalText,
      }));

    res.json({
      success: true,
      data: {
        id: v.id,
        version: v.attributes?.versionString,
        state: v.attributes?.appStoreState,
        state_label: STATE_LABELS[v.attributes?.appStoreState] || v.attributes?.appStoreState,
        platform: v.attributes?.platform,
        release_type: v.attributes?.releaseType,
        created_date: v.attributes?.createdDate,
        localizations,
      }
    });
  } catch (err) { next(err); }
});

router.post('/versions', async (req, res, next) => {
  try {
    const { app_id, platform, version_string } = req.body;
    if (!app_id || !version_string) return res.status(400).json({ success: false, message: '请填写 App 和版本号' });
    const api = await getApi(req);
    const result = await api.createAppStoreVersion(app_id, platform || 'IOS', version_string);
    res.json({ success: true, data: result.data, message: `版本 ${version_string} 创建成功` });
  } catch (err) { next(err); }
});

router.patch('/versions/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { release_type, earliest_release_date } = req.body;
    const attrs = {};
    if (release_type) attrs.releaseType = release_type;
    if (earliest_release_date) attrs.earliestReleaseDate = earliest_release_date;
    const result = await api.updateAppStoreVersion(req.params.id, attrs);
    res.json({ success: true, data: result.data, message: '版本已更新' });
  } catch (err) { next(err); }
});

router.post('/versions/:id/submit', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.submitForReview(req.params.id);
    res.json({ success: true, data: result.data, message: '已提交审核' });
  } catch (err) { next(err); }
});

router.get('/versions/:id/localizations', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.listVersionLocalizations(req.params.id);
    const localizations = (result.data || []).map(l => ({
      id: l.id,
      locale: l.attributes?.locale,
      description: l.attributes?.description,
      keywords: l.attributes?.keywords,
      whats_new: l.attributes?.whatsNew,
      marketing_url: l.attributes?.marketingUrl,
      support_url: l.attributes?.supportUrl,
      promotional_text: l.attributes?.promotionalText,
    }));
    res.json({ success: true, data: localizations });
  } catch (err) { next(err); }
});

// ---- Version Build Relationship ----
router.get('/versions/:id/build', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getVersionBuild(req.params.id);
    const b = result.data;
    if (!b) return res.json({ success: true, data: null });
    res.json({
      success: true,
      data: {
        id: b.id,
        version: b.attributes?.version,
        processing_state: b.attributes?.processingState,
        uploaded_date: b.attributes?.uploadedDate,
      }
    });
  } catch (err) { next(err); }
});

router.patch('/versions/:id/build', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { build_id } = req.body;
    await api.setVersionBuild(req.params.id, build_id || null);
    res.json({ success: true, message: build_id ? '已关联构建版本' : '已取消关联' });
  } catch (err) { next(err); }
});

// ---- Phased Release ----
router.get('/versions/:id/phased-release', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getVersionPhasedRelease(req.params.id);
    const pr = result.data;
    if (!pr) return res.json({ success: true, data: null });
    res.json({
      success: true,
      data: {
        id: pr.id,
        state: pr.attributes?.phasedReleaseState,
        start_date: pr.attributes?.startDate,
        current_day_number: pr.attributes?.currentDayNumber,
        total_pause_duration: pr.attributes?.totalPauseDuration,
      }
    });
  } catch (err) { next(err); }
});

router.post('/versions/:id/phased-release', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.createVersionPhasedRelease(req.params.id);
    res.json({ success: true, data: result.data, message: '已启用分阶段发布' });
  } catch (err) { next(err); }
});

router.patch('/phased-release/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { state } = req.body;
    const result = await api.updateVersionPhasedRelease(req.params.id, state);
    res.json({ success: true, data: result.data, message: '分阶段发布状态已更新' });
  } catch (err) { next(err); }
});

router.delete('/phased-release/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    await api.deleteVersionPhasedRelease(req.params.id);
    res.json({ success: true, message: '已取消分阶段发布' });
  } catch (err) { next(err); }
});

router.patch('/localizations/:id', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const { description, keywords, whats_new, marketing_url, support_url, promotional_text } = req.body;
    const attrs = {};
    if (description !== undefined) attrs.description = description;
    if (keywords !== undefined) attrs.keywords = keywords;
    if (whats_new !== undefined) attrs.whatsNew = whats_new;
    if (marketing_url !== undefined) attrs.marketingUrl = marketing_url;
    if (support_url !== undefined) attrs.supportUrl = support_url;
    if (promotional_text !== undefined) attrs.promotionalText = promotional_text;
    const result = await api.updateVersionLocalization(req.params.id, attrs);
    res.json({ success: true, data: result.data, message: '本地化信息已更新' });
  } catch (err) { next(err); }
});

module.exports = router;
