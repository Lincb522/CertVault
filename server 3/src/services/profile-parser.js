const fs = require('fs');
const { execSync } = require('child_process');
const os = require('os');

function parseProvisioningProfile(filePath) {
  if (!fs.existsSync(filePath)) return null;

  let plistXml = '';

  if (os.platform() === 'darwin') {
    try {
      plistXml = execSync(`security cms -D -i "${filePath}" 2>/dev/null`, { encoding: 'utf8' });
    } catch {
      plistXml = extractEmbeddedPlist(filePath);
    }
  } else {
    plistXml = extractEmbeddedPlist(filePath);
  }

  if (!plistXml) return null;

  return parsePlistXml(plistXml);
}

function parseProfileFromBase64(base64Content) {
  if (!base64Content) return null;
  const buf = Buffer.from(base64Content, 'base64');
  const str = buf.toString('latin1');
  const start = str.indexOf('<?xml');
  const end = str.indexOf('</plist>');
  if (start === -1 || end === -1) return null;
  const plistXml = str.substring(start, end + '</plist>'.length);
  return parsePlistXml(plistXml);
}

function parsePlistXml(plistXml) {
  return {
    devices: extractArray(plistXml, 'ProvisionedDevices'),
    name: extractString(plistXml, 'Name'),
    teamName: extractString(plistXml, 'TeamName'),
    appIdName: extractString(plistXml, 'AppIDName'),
    expirationDate: extractString(plistXml, 'ExpirationDate'),
    creationDate: extractString(plistXml, 'CreationDate'),
    uuid: extractString(plistXml, 'UUID'),
    teamIdentifier: extractFirstArrayItem(plistXml, 'TeamIdentifier'),
    applicationIdentifierPrefix: extractFirstArrayItem(plistXml, 'ApplicationIdentifierPrefix'),
    bundleIdentifier: extractBundleId(plistXml),
  };
}

function extractEmbeddedPlist(filePath) {
  const buf = fs.readFileSync(filePath);
  const str = buf.toString('latin1');
  const start = str.indexOf('<?xml');
  const end = str.indexOf('</plist>');
  if (start === -1 || end === -1) return '';
  return str.substring(start, end + '</plist>'.length);
}

function extractString(xml, key) {
  const regex = new RegExp(`<key>${key}</key>\\s*(?:<string>([^<]*)</string>|<date>([^<]*)</date>)`);
  const m = xml.match(regex);
  return m ? (m[1] || m[2] || null) : null;
}

function extractArray(xml, key) {
  const regex = new RegExp(`<key>${key}</key>\\s*<array>([\\s\\S]*?)</array>`);
  const m = xml.match(regex);
  if (!m) return [];
  const items = [];
  const itemRegex = /<string>([^<]*)<\/string>/g;
  let match;
  while ((match = itemRegex.exec(m[1])) !== null) {
    items.push(match[1]);
  }
  return items;
}

function extractFirstArrayItem(xml, key) {
  const arr = extractArray(xml, key);
  return arr.length > 0 ? arr[0] : null;
}

function extractBundleId(xml) {
  const appId = extractString(xml, 'application-identifier');
  if (appId) {
    const parts = appId.split('.');
    return parts.length > 1 ? parts.slice(1).join('.') : appId;
  }
  const entRegex = /<key>application-identifier<\/key>\s*<string>([^<]*)<\/string>/;
  const m = xml.match(entRegex);
  if (m) {
    const parts = m[1].split('.');
    return parts.length > 1 ? parts.slice(1).join('.') : m[1];
  }
  return null;
}

module.exports = { parseProvisioningProfile, parseProfileFromBase64 };
