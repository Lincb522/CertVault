/**
 * TestFlight：按邮箱/姓名加入 Beta 测试组（App Store Connect API）
 */

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function parseTesterName(body) {
  const first = (body.first_name || '').trim();
  const last = (body.last_name || '').trim();
  if (first || last) return { firstName: first || 'Tester', lastName: last || '' };
  const full = (body.full_name || body.name || '').trim();
  if (!full) return { firstName: 'Tester', lastName: '' };
  const parts = full.split(/\s+/);
  if (parts.length === 1) return { firstName: parts[0], lastName: '' };
  return { firstName: parts[0], lastName: parts.slice(1).join(' ') };
}

function validateTesterEmail(email) {
  return EMAIL_REGEX.test((email || '').trim());
}

function isAlreadyAddedError(message = '') {
  const msg = String(message).toLowerCase();
  return (
    msg.includes('409') ||
    msg.includes('already') ||
    msg.includes('duplicate') ||
    msg.includes('cannot be assigned')
  );
}

async function attachTesterToGroup(api, groupId, testerId) {
  try {
    await api.addTesterToGroup(groupId, [testerId]);
  } catch (e) {
    if (!isAlreadyAddedError(e.message)) throw e;
  }
}

async function isTesterAlreadyInGroup(api, groupId, email, testerId) {
  try {
    const result = await api.listGroupTesters(groupId, { limit: 200 });
    return (result.data || []).some(t => {
      const testerEmail = (t.attributes?.email || '').toLowerCase();
      return t.id === testerId || testerEmail === email.toLowerCase();
    });
  } catch (_) {
    return false;
  }
}

async function addTesterToBetaGroupAfterConnect(api, { email, groupId, firstName, lastName }) {
  let listRes;
  try {
    listRes = await api.listBetaTesters({
      'filter[email]': email,
      'fields[betaTesters]': 'email,firstName,lastName',
      limit: 50,
    });
  } catch (e) {
    throw Object.assign(new Error(`查询测试员失败: ${e.message}`), { status: 502 });
  }
  const existing = (listRes.data || []).find(
    t => (t.attributes?.email || '').toLowerCase() === email.toLowerCase()
  );
  if (existing) {
    if (await isTesterAlreadyInGroup(api, groupId, email, existing.id)) {
      return { added: true, mode: 'already_in_group', tester_id: existing.id };
    }
    await attachTesterToGroup(api, groupId, existing.id);
    return { added: true, mode: 'existing_tester', tester_id: existing.id };
  }
  try {
    const created = await api.createBetaTester(email, firstName, lastName, [groupId]);
    return { added: true, mode: 'created', tester_id: created.data?.id };
  } catch (e) {
    const em = e.message || '';
    if (/409|already exists|duplicate|unique/i.test(em)) {
      const retry = await api.listBetaTesters({
        'filter[email]': email,
        'fields[betaTesters]': 'email,firstName,lastName',
        limit: 50,
      });
      const t2 = (retry.data || []).find(
        x => (x.attributes?.email || '').toLowerCase() === email.toLowerCase()
      );
      if (t2) {
        if (await isTesterAlreadyInGroup(api, groupId, email, t2.id)) {
          return { added: true, mode: 'already_in_group_after_conflict', tester_id: t2.id };
        }
        await attachTesterToGroup(api, groupId, t2.id);
        return { added: true, mode: 'existing_after_conflict', tester_id: t2.id };
      }
    }
    throw Object.assign(new Error(`添加测试员失败: ${em}`), { status: 502 });
  }
}

module.exports = {
  parseTesterName,
  validateTesterEmail,
  addTesterToBetaGroupAfterConnect,
};
