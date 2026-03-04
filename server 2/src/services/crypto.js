const forge = require('node-forge');

class CryptoService {
  /**
   * Generate RSA key pair
   */
  static generateKeyPair(bits = 2048) {
    const keys = forge.pki.rsa.generateKeyPair(bits);
    return {
      privateKey: keys.privateKey,
      publicKey: keys.publicKey,
      privateKeyPem: forge.pki.privateKeyToPem(keys.privateKey),
      publicKeyPem: forge.pki.publicKeyToPem(keys.publicKey)
    };
  }

  /**
   * Create CSR (Certificate Signing Request)
   */
  static createCSR(privateKey, subject = {}) {
    const csr = forge.pki.createCertificationRequest();
    const pk = typeof privateKey === 'string'
      ? forge.pki.privateKeyFromPem(privateKey)
      : privateKey;

    csr.publicKey = forge.pki.rsa.setPublicKey(pk.n, pk.e);

    const attrs = [
      { name: 'commonName', value: subject.commonName || 'Apple Development' },
      { name: 'countryName', value: subject.country || 'CN' },
      { shortName: 'ST', value: subject.state || 'Beijing' },
      { name: 'organizationName', value: subject.organization || 'Dev' },
    ];
    if (subject.email) {
      attrs.push({ name: 'emailAddress', value: subject.email });
    }
    csr.setSubject(attrs);
    csr.sign(pk);

    return forge.pki.certificationRequestToPem(csr);
  }

  /**
   * Convert DER certificate from Apple to PEM
   */
  static derToPem(derBase64) {
    const derBytes = forge.util.decode64(derBase64);
    const asn1 = forge.asn1.fromDer(derBytes);
    const cert = forge.pki.certificateFromAsn1(asn1);
    return forge.pki.certificateToPem(cert);
  }

  /**
   * Create P12 from private key + certificate
   */
  static createP12(privateKeyPem, certPem, password = '', friendlyName = 'Apple Certificate') {
    const privateKey = typeof privateKeyPem === 'string'
      ? forge.pki.privateKeyFromPem(privateKeyPem)
      : privateKeyPem;
    const cert = typeof certPem === 'string'
      ? forge.pki.certificateFromPem(certPem)
      : certPem;

    const p12Asn1 = forge.pkcs12.toPkcs12Asn1(privateKey, [cert], password, {
      friendlyName,
      algorithm: '3des'
    });
    const p12Der = forge.asn1.toDer(p12Asn1).getBytes();
    return Buffer.from(p12Der, 'binary');
  }

  /**
   * Generate self-signed CA certificate
   */
  static generateCA(options = {}) {
    const keys = forge.pki.rsa.generateKeyPair(2048);
    const cert = forge.pki.createCertificate();

    cert.publicKey = keys.publicKey;
    cert.serialNumber = CryptoService._randomSerial();
    cert.validity.notBefore = new Date();
    cert.validity.notAfter = new Date();
    cert.validity.notAfter.setFullYear(cert.validity.notAfter.getFullYear() + (options.years || 10));

    const attrs = [
      { name: 'commonName', value: options.commonName || 'Self-Signed CA' },
      { name: 'countryName', value: options.country || 'CN' },
      { name: 'organizationName', value: options.organization || 'Dev CA' },
    ];
    cert.setSubject(attrs);
    cert.setIssuer(attrs);

    cert.setExtensions([
      { name: 'basicConstraints', cA: true, critical: true },
      { name: 'keyUsage', keyCertSign: true, cRLSign: true, critical: true },
      { name: 'subjectKeyIdentifier' }
    ]);

    cert.sign(keys.privateKey, forge.md.sha256.create());

    return {
      cert: forge.pki.certificateToPem(cert),
      privateKey: forge.pki.privateKeyToPem(keys.privateKey),
      publicKey: forge.pki.publicKeyToPem(keys.publicKey)
    };
  }

  /**
   * Issue a certificate signed by CA
   */
  static issueCertificate(caPrivateKeyPem, caCertPem, options = {}) {
    const caKey = forge.pki.privateKeyFromPem(caPrivateKeyPem);
    const caCert = forge.pki.certificateFromPem(caCertPem);

    const keys = forge.pki.rsa.generateKeyPair(2048);
    const cert = forge.pki.createCertificate();

    cert.publicKey = keys.publicKey;
    cert.serialNumber = CryptoService._randomSerial();
    cert.validity.notBefore = new Date();
    cert.validity.notAfter = new Date();
    cert.validity.notAfter.setFullYear(cert.validity.notAfter.getFullYear() + (options.years || 1));

    const subject = [
      { name: 'commonName', value: options.commonName || 'Apple Development: Self-Signed' },
      { name: 'countryName', value: options.country || 'CN' },
      { name: 'organizationName', value: options.organization || 'Dev' },
    ];
    if (options.email) {
      subject.push({ name: 'emailAddress', value: options.email });
    }
    cert.setSubject(subject);
    cert.setIssuer(caCert.subject.attributes);

    cert.setExtensions([
      { name: 'basicConstraints', cA: false },
      { name: 'keyUsage', digitalSignature: true, keyEncipherment: true },
      { name: 'extKeyUsage', codeSigning: true },
      { name: 'subjectKeyIdentifier' },
      { name: 'authorityKeyIdentifier', keyIdentifier: true }
    ]);

    cert.sign(caKey, forge.md.sha256.create());

    return {
      cert: forge.pki.certificateToPem(cert),
      privateKey: forge.pki.privateKeyToPem(keys.privateKey),
      publicKey: forge.pki.publicKeyToPem(keys.publicKey)
    };
  }

  /**
   * Parse certificate info from PEM
   */
  static parseCertInfo(certPem) {
    const cert = forge.pki.certificateFromPem(certPem);
    const subject = {};
    cert.subject.attributes.forEach(attr => {
      subject[attr.shortName || attr.name] = attr.value;
    });
    const issuer = {};
    cert.issuer.attributes.forEach(attr => {
      issuer[attr.shortName || attr.name] = attr.value;
    });
    return {
      subject,
      issuer,
      serialNumber: cert.serialNumber,
      notBefore: cert.validity.notBefore.toISOString(),
      notAfter: cert.validity.notAfter.toISOString(),
    };
  }

  static _randomSerial() {
    return Date.now().toString(16) + Math.floor(Math.random() * 0xffff).toString(16);
  }
}

module.exports = CryptoService;
