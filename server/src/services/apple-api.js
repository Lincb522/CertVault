const jwt = require('jsonwebtoken');
const axios = require('axios');

const BASE_URL = 'https://api.appstoreconnect.apple.com/v1';

class AppleApiService {
  constructor(account) {
    this.issuerId = account.issuer_id?.trim();
    this.keyId = account.key_id?.trim();
    this.privateKey = AppleApiService.normalizePrivateKey(account.private_key);
    this._token = null;
    this._tokenExpiry = 0;
  }

  static normalizePrivateKey(key) {
    if (!key) return key;
    let k = key.trim();

    // 如果没有 PEM 头部，尝试包裹
    if (!k.includes('-----BEGIN')) {
      k = `-----BEGIN PRIVATE KEY-----\n${k}\n-----END PRIVATE KEY-----`;
    }

    // 修复可能被破坏的换行：有些存储会把 \n 变成空格或去掉
    k = k.replace(/-----BEGIN PRIVATE KEY-----\s*/, '-----BEGIN PRIVATE KEY-----\n');
    k = k.replace(/\s*-----END PRIVATE KEY-----/, '\n-----END PRIVATE KEY-----');

    // 中间内容确保每 64 字符换行
    const lines = k.split('\n');
    const header = lines[0];
    const footer = lines[lines.length - 1];
    const body = lines.slice(1, -1).join('').replace(/\s/g, '');
    const bodyLines = body.match(/.{1,64}/g) || [];

    return [header, ...bodyLines, footer].join('\n');
  }

  generateToken() {
    const now = Math.floor(Date.now() / 1000);
    if (this._token && this._tokenExpiry > now + 60) {
      return this._token;
    }

    try {
      this._token = jwt.sign({}, this.privateKey, {
        algorithm: 'ES256',
        expiresIn: '20m',
        issuer: this.issuerId,
        audience: 'appstoreconnect-v1',
        header: { alg: 'ES256', kid: this.keyId, typ: 'JWT' }
      });
      this._tokenExpiry = now + 1200;
      return this._token;
    } catch (err) {
      const msg = err.message.includes('PEM')
        ? `私钥格式错误: ${err.message}。请确认 .p8 文件内容完整且格式正确`
        : `JWT 签名失败: ${err.message}`;
      throw new Error(msg);
    }
  }

  async request(method, endpoint, data = null) {
    const token = this.generateToken();
    const config = {
      method,
      url: `${BASE_URL}${endpoint}`,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };
    if (data) config.data = data;

    try {
      const response = await axios(config);
      return response.data;
    } catch (error) {
      const errors = error.response?.data?.errors || [];
      const firstError = errors[0] || {};
      let msg = firstError.detail || firstError.title || error.message;

      if (error.response?.status === 401) {
        msg = `认证失败 (401): ${msg}。请检查: 1) Issuer ID 是否正确 2) Key ID 是否正确 3) .p8 私钥是否完整`;
      } else if (error.response?.status === 403) {
        msg = `权限不足 (403): ${msg}。请确认 API Key 拥有足够的权限`;
      }

      const err = new Error(msg);
      err.status = error.response?.status || 500;
      throw err;
    }
  }

  // ---- Devices ----
  async listDevices(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/devices${query ? '?' + query : ''}`);
  }

  async registerDevice(name, udid, platform = 'IOS') {
    return this.request('POST', '/devices', {
      data: {
        type: 'devices',
        attributes: { name, udid, platform }
      }
    });
  }

  // ---- Certificates ----
  async listCertificates(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/certificates${query ? '?' + query : ''}`);
  }

  async createCertificate(csrContent, type) {
    return this.request('POST', '/certificates', {
      data: {
        type: 'certificates',
        attributes: { csrContent, certificateType: type }
      }
    });
  }

  async revokeCertificate(certificateId) {
    return this.request('DELETE', `/certificates/${certificateId}`);
  }

  async getCertificate(certificateId) {
    return this.request('GET', `/certificates/${certificateId}`);
  }

  // ---- Bundle IDs ----
  async listBundleIds(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/bundleIds${query ? '?' + query : ''}`);
  }

  async createBundleId(identifier, name, platform = 'IOS') {
    return this.request('POST', '/bundleIds', {
      data: {
        type: 'bundleIds',
        attributes: { identifier, name, platform }
      }
    });
  }

  async deleteBundleId(bundleIdId) {
    return this.request('DELETE', `/bundleIds/${bundleIdId}`);
  }

  // ---- Capabilities ----
  async listCapabilities(bundleIdId) {
    return this.request('GET', `/bundleIds/${bundleIdId}/bundleIdCapabilities`);
  }

  async enableCapability(bundleIdId, capabilityType, settings = []) {
    if (capabilityType === 'ICLOUD' && (!settings || settings.length === 0)) {
      settings = [{
        key: 'ICLOUD_VERSION',
        options: [{ key: 'XCODE_6' }]
      }];
    }
    if (capabilityType === 'APPLE_ID_AUTH' && (!settings || settings.length === 0)) {
      settings = [{
        key: 'APPLE_ID_AUTH_APP_CONSENT',
        options: [{ key: 'PRIMARY_APP_CONSENT' }]
      }];
    }
    const data = {
      data: {
        type: 'bundleIdCapabilities',
        attributes: { capabilityType, settings },
        relationships: {
          bundleId: {
            data: { type: 'bundleIds', id: bundleIdId }
          }
        }
      }
    };
    return this.request('POST', '/bundleIdCapabilities', data);
  }

  async disableCapability(capabilityId) {
    return this.request('DELETE', `/bundleIdCapabilities/${capabilityId}`);
  }

  async updateCapability(capabilityId, capabilityType, settings = []) {
    return this.request('PATCH', `/bundleIdCapabilities/${capabilityId}`, {
      data: {
        type: 'bundleIdCapabilities',
        id: capabilityId,
        attributes: { capabilityType, settings }
      }
    });
  }

  // ---- Profiles ----
  async listProfiles(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/profiles${query ? '?' + query : ''}`);
  }

  async createProfile(name, profileType, bundleIdId, certificateIds, deviceIds = []) {
    const relationships = {
      bundleId: { data: { type: 'bundleIds', id: bundleIdId } },
      certificates: { data: certificateIds.map(id => ({ type: 'certificates', id })) }
    };
    if (deviceIds.length > 0) {
      relationships.devices = { data: deviceIds.map(id => ({ type: 'devices', id })) };
    }
    return this.request('POST', '/profiles', {
      data: {
        type: 'profiles',
        attributes: { name, profileType },
        relationships
      }
    });
  }

  async deleteProfile(profileId) {
    return this.request('DELETE', `/profiles/${profileId}`);
  }

  async getProfile(profileId) {
    return this.request('GET', `/profiles/${profileId}`);
  }

  async getProfileWithRelations(profileId) {
    return this.request('GET', `/profiles/${profileId}?include=bundleId,certificates,devices`);
  }

  async listProfilesWithRelations() {
    return this.request('GET', '/profiles?include=bundleId,certificates,devices');
  }

  // ---- Apps ----
  async listApps(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/apps${query ? '?' + query : ''}`);
  }

  async getApp(appId, include = '') {
    const q = include ? `?include=${include}` : '';
    return this.request('GET', `/apps/${appId}${q}`);
  }

  async listAppBuilds(appId, params = {}) {
    const safeParams = { ...params };
    delete safeParams.sort; // Apple /apps/{id}/builds does not support sort
    const query = new URLSearchParams(safeParams).toString();
    return this.request('GET', `/apps/${appId}/builds${query ? '?' + query : ''}`);
  }

  async listAppVersions(appId, params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/apps/${appId}/appStoreVersions${query ? '?' + query : ''}`);
  }

  // ---- Builds ----
  async listBuilds(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/builds${query ? '?' + query : ''}`);
  }

  async getBuild(buildId, include = '') {
    const q = include ? `?include=${include}` : '';
    return this.request('GET', `/builds/${buildId}${q}`);
  }

  // ---- TestFlight: Beta Testers ----
  async listBetaTesters(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/betaTesters${query ? '?' + query : ''}`);
  }

  async createBetaTester(email, firstName, lastName, betaGroupIds = []) {
    const data = {
      data: {
        type: 'betaTesters',
        attributes: { email, firstName, lastName },
      }
    };
    if (betaGroupIds.length) {
      data.data.relationships = {
        betaGroups: { data: betaGroupIds.map(id => ({ type: 'betaGroups', id })) }
      };
    }
    return this.request('POST', '/betaTesters', data);
  }

  async deleteBetaTester(testerId) {
    return this.request('DELETE', `/betaTesters/${testerId}`);
  }

  // ---- TestFlight: Beta Groups ----
  async listBetaGroups(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/betaGroups${query ? '?' + query : ''}`);
  }

  async createBetaGroup(appId, name, isInternalGroup = false) {
    return this.request('POST', '/betaGroups', {
      data: {
        type: 'betaGroups',
        attributes: { name, isInternalGroup },
        relationships: {
          app: { data: { type: 'apps', id: appId } }
        }
      }
    });
  }

  async deleteBetaGroup(groupId) {
    return this.request('DELETE', `/betaGroups/${groupId}`);
  }

  async addTesterToGroup(groupId, testerIds) {
    return this.request('POST', `/betaGroups/${groupId}/relationships/betaTesters`, {
      data: testerIds.map(id => ({ type: 'betaTesters', id }))
    });
  }

  async removeTesterFromGroup(groupId, testerIds) {
    return this.request('DELETE', `/betaGroups/${groupId}/relationships/betaTesters`, {
      data: testerIds.map(id => ({ type: 'betaTesters', id }))
    });
  }

  async addBuildToGroup(groupId, buildIds) {
    return this.request('POST', `/betaGroups/${groupId}/relationships/builds`, {
      data: buildIds.map(id => ({ type: 'builds', id }))
    });
  }

  async listGroupTesters(groupId) {
    return this.request('GET', `/betaGroups/${groupId}/betaTesters`);
  }

  async listGroupBuilds(groupId) {
    return this.request('GET', `/betaGroups/${groupId}/builds`);
  }

  // ---- TestFlight: Beta Build Localizations ----
  async listBetaBuildLocalizations(buildId) {
    return this.request('GET', `/builds/${buildId}/betaBuildLocalizations`);
  }

  async createBetaBuildLocalization(buildId, locale, whatsNew) {
    return this.request('POST', '/betaBuildLocalizations', {
      data: {
        type: 'betaBuildLocalizations',
        attributes: { locale, whatsNew },
        relationships: {
          build: { data: { type: 'builds', id: buildId } }
        }
      }
    });
  }

  async updateBetaBuildLocalization(localizationId, whatsNew) {
    return this.request('PATCH', `/betaBuildLocalizations/${localizationId}`, {
      data: {
        type: 'betaBuildLocalizations',
        id: localizationId,
        attributes: { whatsNew }
      }
    });
  }

  // ---- TestFlight: Build Beta Details ----
  async getBuildBetaDetail(buildId) {
    return this.request('GET', `/builds/${buildId}/buildBetaDetail`);
  }

  // ---- App Store Versions ----
  async listAppStoreVersions(appId, params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request('GET', `/apps/${appId}/appStoreVersions${query ? '?' + query : ''}`);
  }

  async createAppStoreVersion(appId, platform, versionString) {
    return this.request('POST', '/appStoreVersions', {
      data: {
        type: 'appStoreVersions',
        attributes: { platform, versionString },
        relationships: {
          app: { data: { type: 'apps', id: appId } }
        }
      }
    });
  }

  async getAppStoreVersion(versionId, include = '') {
    const q = include ? `?include=${include}` : '';
    return this.request('GET', `/appStoreVersions/${versionId}${q}`);
  }

  async updateAppStoreVersion(versionId, attributes = {}) {
    return this.request('PATCH', `/appStoreVersions/${versionId}`, {
      data: {
        type: 'appStoreVersions',
        id: versionId,
        attributes,
      }
    });
  }

  // ---- App Store Version Submissions ----
  async submitForReview(versionId) {
    return this.request('POST', '/appStoreVersionSubmissions', {
      data: {
        type: 'appStoreVersionSubmissions',
        relationships: {
          appStoreVersion: { data: { type: 'appStoreVersions', id: versionId } }
        }
      }
    });
  }

  // ---- App Store Version Localizations ----
  async listVersionLocalizations(versionId) {
    return this.request('GET', `/appStoreVersions/${versionId}/appStoreVersionLocalizations`);
  }

  async updateVersionLocalization(localizationId, attributes = {}) {
    return this.request('PATCH', `/appStoreVersionLocalizations/${localizationId}`, {
      data: {
        type: 'appStoreVersionLocalizations',
        id: localizationId,
        attributes,
      }
    });
  }

  // ---- App Store Version: Build Relationship ----
  async getVersionBuild(versionId) {
    return this.request('GET', `/appStoreVersions/${versionId}/build`);
  }

  async setVersionBuild(versionId, buildId) {
    return this.request('PATCH', `/appStoreVersions/${versionId}/relationships/build`, {
      data: buildId ? { type: 'builds', id: buildId } : null
    });
  }

  // ---- App Store Version: Phased Release ----
  async getVersionPhasedRelease(versionId) {
    return this.request('GET', `/appStoreVersions/${versionId}/appStoreVersionPhasedRelease`);
  }

  async createVersionPhasedRelease(versionId) {
    return this.request('POST', '/appStoreVersionPhasedReleases', {
      data: {
        type: 'appStoreVersionPhasedReleases',
        attributes: { phasedReleaseState: 'ACTIVE' },
        relationships: {
          appStoreVersion: { data: { type: 'appStoreVersions', id: versionId } }
        }
      }
    });
  }

  async deleteVersionPhasedRelease(phasedReleaseId) {
    return this.request('DELETE', `/appStoreVersionPhasedReleases/${phasedReleaseId}`);
  }

  async updateVersionPhasedRelease(phasedReleaseId, state) {
    return this.request('PATCH', `/appStoreVersionPhasedReleases/${phasedReleaseId}`, {
      data: {
        type: 'appStoreVersionPhasedReleases',
        id: phasedReleaseId,
        attributes: { phasedReleaseState: state }
      }
    });
  }

  // ---- App Infos ----
  async listAppInfos(appId) {
    return this.request('GET', `/apps/${appId}/appInfos`);
  }
}

module.exports = AppleApiService;
