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
}

module.exports = AppleApiService;
