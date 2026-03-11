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

router.get('/list', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.listApps({
      'fields[apps]': 'name,bundleId,sku,primaryLocale,isOrEverWasMadeForKids,contentRightsDeclaration',
      limit: req.query.limit || 100,
    });
    const apps = (result.data || []).map(a => ({
      id: a.id,
      name: a.attributes?.name,
      bundle_id: a.attributes?.bundleId,
      sku: a.attributes?.sku,
      primary_locale: a.attributes?.primaryLocale,
    }));
    res.json({ success: true, data: apps });
  } catch (err) { next(err); }
});

router.get('/:appId', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.getApp(req.params.appId);
    res.json({ success: true, data: result.data });
  } catch (err) { next(err); }
});

router.get('/:appId/builds', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.listAppBuilds(req.params.appId, {
      'fields[builds]': 'version,uploadedDate,expirationDate,expired,processingState,buildAudienceType,minOsVersion,iconAssetToken',
      limit: req.query.limit || 50,
    });
    const builds = (result.data || []).map(b => ({
      id: b.id,
      version: b.attributes?.version,
      uploaded_date: b.attributes?.uploadedDate,
      expiration_date: b.attributes?.expirationDate,
      expired: b.attributes?.expired,
      processing_state: b.attributes?.processingState,
      min_os_version: b.attributes?.minOsVersion,
    }))
      .sort((a, b) => {
        const aTime = a.uploaded_date ? new Date(a.uploaded_date).getTime() : 0;
        const bTime = b.uploaded_date ? new Date(b.uploaded_date).getTime() : 0;
        return bTime - aTime;
      });
    res.json({ success: true, data: builds });
  } catch (err) { next(err); }
});

router.get('/:appId/versions', async (req, res, next) => {
  try {
    const api = await getApi(req);
    const result = await api.listAppStoreVersions(req.params.appId, {
      'fields[appStoreVersions]': 'versionString,appStoreState,platform,releaseType,createdDate',
      limit: req.query.limit || 20,
    });
    const versions = (result.data || []).map(v => ({
      id: v.id,
      version: v.attributes?.versionString,
      state: v.attributes?.appStoreState,
      platform: v.attributes?.platform,
      release_type: v.attributes?.releaseType,
      created_date: v.attributes?.createdDate,
    }));
    res.json({ success: true, data: versions });
  } catch (err) { next(err); }
});

module.exports = router;
