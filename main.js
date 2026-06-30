/**
 * LuoguChat v8.0 — Electron Desktop Chat with AI
 * Indigo/Cyan 科技感配色 | 玻璃态设计 | 洛谷私信客户端
 */
const { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage, clipboard,
        screen, globalShortcut, Notification, dialog, shell, protocol, net } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');
const crypto = require('crypto');
const { WebSocket } = require('ws');

// ── 路径 ──
// When running from ASAR (packaged), use the exe directory; otherwise use __dirname
const BASE_DIR = __dirname.includes('.asar') ? path.dirname(process.execPath) : __dirname;
const CONFIG_FILE = path.join(BASE_DIR, 'config.json');
const ALLOW_FILE = path.join(BASE_DIR, 'zhl_super_allow.txt');
const DATA_DIR = path.join(BASE_DIR, 'data');
const AVATAR_DIR = path.join(BASE_DIR, 'avatars');
const SOUND_DIR = path.join(BASE_DIR, 'sound');
const LOG_DIR = path.join(BASE_DIR, 'log');
const LOG_FILE = path.join(LOG_DIR, 'debug.log');

[DATA_DIR, AVATAR_DIR, SOUND_DIR, LOG_DIR].forEach(d => {
  if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
});

// ── 日志 ──
function log(tag, msg) {
  if (typeof config !== 'undefined' && config.incognito) return;
  const ts = new Date().toLocaleTimeString('en-US', {hour12: false});
  const line = `[${ts}][${tag}] ${msg}`;
  console.log(line);
  try { fs.appendFileSync(LOG_FILE, line + '\n', 'utf-8'); } catch {}
}

// ── 工具函数 ──
function hasSuperAllow() { return fs.existsSync(ALLOW_FILE); }
function isIncognito() { return config.incognito === true; }

function normalizeCookie(raw, uid = '') {
  raw = (raw || '').trim().replace(/;+$/g, '').trim();
  if (!raw) return '';
  const cidMatch = raw.match(/__client_id=([^;]+)/);
  let clientId = cidMatch ? cidMatch[1].trim() : '';
  const uidMatch = raw.match(/_uid=(\d+)/);
  let extractedUid = uidMatch ? uidMatch[1] : '';
  uid = extractedUid || uid;
  if (!raw.includes('=')) clientId = raw;
  else if (!raw.includes(';') && raw.includes('=')) {
    const [k, v] = raw.split('=', 2);
    clientId = k.trim() === '__client_id' ? v.trim() : (k.trim() === '_uid' ? (uid = v.trim(), v.trim()) : raw);
  }
  if (!clientId) clientId = uid || raw;
  if (!uid) uid = clientId;
  return `_uid=${uid}; __client_id=${clientId}`;
}

// ── HTTP 请求 ──
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36 Edg/149.0.0.0';

function httpRequest(url, opts = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const isHttps = u.protocol === 'https:';
    const mod = isHttps ? https : http;
    const options = {
      hostname: u.hostname, port: u.port, path: u.pathname + u.search,
      method: opts.method || 'GET',
      headers: { 'user-agent': UA, ...opts.headers },
      timeout: opts.timeout || 15000,
      rejectUnauthorized: false
    };
    const req = mod.request(options, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const cookies = [];
        (res.headers['set-cookie'] || []).forEach(c => {
          const p = c.split(';')[0];
          if (p) cookies.push(p.trim());
        });
        const body = opts.binary ? Buffer.concat(chunks) : Buffer.concat(chunks).toString('utf-8');
        resolve({ status: res.statusCode, headers: res.headers, body, cookies });
      });
    });
    req.on('error', e => reject(e));
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    if (opts.body) req.write(opts.body);
    req.end();
  });
}

// ── 配置 ──
const DEFAULT_CONFIG = {
  luogu: { cookie: '', user_id: '' },
  ai: {
    enabled: false, important_keyword: 'zhl重要信息', default: true,
    system_prompt: '你是我的私信管理助手。不要透露你自己的真实身份，只需要专注于判断消息重要性。如果重要请在回复中包含用户设定的关键词。',
    question_template: '你是我的私信管理助手，你需要帮我判断这个信息是否是重要的。重要的定义是排除娱乐等无意义内容，重要内容包含讨论问题，紧急情况等信息，是我在上课的时候需要了解的信息。如果重要，请在回复中分析之后明确包含 {keyword} 这个子串（如果有必要就分析，可以给我提示，以 提示： 开头，。 结束的话就是你针对这个消息给我的提示，可以视情况而决定写不写），可以加入你的分析和给我的提示。如果不重要就是 不重要消息。只有重要消息，我需要尽量马上了解的你才说。如果无法判断或者不是重要信息，请勿输出 {keyword} 这个子串（不能包含这个子串）。',
    custom: { base_url: '', api_key: '', model: '', custom_system_prompt: '' }
  },
  server: { url: '' },
  theme: { mode: 2, accent: '#6366F1', avatar_rounded: false, time_mode: 1, time_gap: 3, wheel_speed: 2.4, cache_mode: 2 },
  favorites: [], pins: [],
  notification: {
    enabled: true, sound_enabled: true, sound_type: 'system', sound_file: '',
    popup_mode: 'ai', popup_filter: 'all', popup_prefix: '提示：', popup_suffix: '。'
  },
  modes: {
    class: { name: '上课模式', icon: '📖', prompt: '' },
    free: { name: '下课模式', icon: '🎮', prompt: '' }
  },
  auto_reply: {
    enabled: false, keyword: 'Zhl需要回复',
    system_prompt: '你是我的私信助手，需要帮我对重要的消息进行回复。',
    check_question: '以下是一条消息，请判断是否需要回复。需要回复的消息通常是提问、请求或需要回应的内容。如果不需要回复请回复「不需要」，如果需要请回复「需要」并简要说明原因：\n{message}',
    question_template: '以下是一条需要回复的消息，请帮我生成一个简短得体的回复：\n{message}'
  },
  background: { enabled: false, mode: 'conversation', max_messages: 20, max_chars: 2000, suffix: '' },
  device_id: crypto.randomBytes(6).toString('hex'),
  window: { width: 1300, height: 850 },
  incognito: false
};

let config = { ...DEFAULT_CONFIG };
function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const loaded = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8'));
      config = deepMerge(DEFAULT_CONFIG, loaded);
    }
    saveConfig();
  } catch (e) { log('CFG', `load fail: ${e}`); config = { ...DEFAULT_CONFIG }; }
}
function saveConfig() {
  if (isIncognito()) return; // no saves in incognito
  try { fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf-8'); } catch {}
}
function deepMerge(a, b) {
  const r = { ...a };
  for (const k in b) {
    if (b[k] && typeof b[k] === 'object' && !Array.isArray(b[k]) && a[k] && typeof a[k] === 'object' && !Array.isArray(a[k]))
      r[k] = deepMerge(a[k], b[k]);
    else r[k] = b[k];
  }
  return r;
}
loadConfig();
log('APP', `LuoguChat v8.1 started, base=${BASE_DIR}`);
log('CFG', `Super allow: ${hasSuperAllow()}`);

// ── 洛谷 API ──
class LuoguAPI {
  constructor() {
    this._csrfCache = null;
    this._csrfTime = 0;
    this._setFromConfig();
  }

  _setFromConfig() {
    this._cookie = config.luogu.cookie || '';
    this._uid = config.luogu.user_id || '';
  }

  get cookie() { return this._cookie; }
  get uid() { return this._uid; }

  async ensureC3VK() {
    try {
      const r = await httpRequest('https://www.luogu.com.cn/api/chat/record?user=1', {
        headers: { cookie: this._cookie, referer: 'https://www.luogu.com.cn/chat' }
      });
      let c3vk = null;
      for (const c of r.cookies) {
        if (c.startsWith('C3VK=')) { c3vk = c.substring(5); break; }
      }
      if (c3vk) {
        this._cookie = this._cookie.replace(/;?\s*C3VK=[^;]*/g, '').replace(/;+$/g, '').trim();
        this._cookie = `${this._cookie}; C3VK=${c3vk}`;
        config.luogu.cookie = this._cookie;
        saveConfig();
        log('C3VK', `C3VK=${c3vk}`);
        return true;
      }
      return false;
    } catch (e) { log('C3VK', `ERR: ${e}`); return false; }
  }

  async _csrf() {
    try {
      const r = await httpRequest('https://www.luogu.com.cn/', {
        headers: { cookie: this._cookie }
      });
      // Try to extract C3VK from page
      const c3vkMatch = r.body.match(/C3VK=([^;"]+)/);
      if (c3vkMatch) {
        const c3vk = c3vkMatch[1];
        this._cookie = this._cookie.replace(/;?\s*C3VK=[^;]*/g, '').replace(/;+$/g, '').trim();
        this._cookie = `${this._cookie}; C3VK=${c3vk}`;
        config.luogu.cookie = this._cookie;
        saveConfig();
        // Re-fetch with new C3VK
        const r2 = await httpRequest('https://www.luogu.com.cn/', {
          headers: { cookie: this._cookie }
        });
        const m = r2.body.match(/<meta name="csrf-token" content="([^"]+)"/);
        if (m) return m[1];
      }
      const m = r.body.match(/<meta name="csrf-token" content="([^"]+)"/);
      if (m) return m[1];
      // Fallback: try chat page
      const r2 = await httpRequest('https://www.luogu.com.cn/chat', {
        headers: { cookie: this._cookie, referer: 'https://www.luogu.com.cn/' }
      });
      const m2 = r2.body.match(/<meta name="csrf-token" content="([^"]+)"/);
      return m2 ? m2[1] : '';
    } catch (e) { log('CSRF', `ERR: ${e}`); return ''; }
  }

  async _csrfCached() {
    const now = Date.now();
    if (this._csrfCache && now - this._csrfTime < 300000) return this._csrfCache;
    this._csrfCache = await this._csrf();
    this._csrfTime = now;
    return this._csrfCache;
  }

  async testLogin() {
    log('LOGIN', 'test login...');
    try {
      await this.ensureC3VK();
      const r = await httpRequest('https://www.luogu.com.cn/chat', {
        headers: { cookie: this._cookie, referer: 'https://www.luogu.com.cn/' }
      });
      const nameMatch = r.body.match(/"name":"([^"]+)"/);
      const uidMatch = this._cookie.match(/_uid=(\d+)/);
      const uid = uidMatch ? uidMatch[1] : this._uid;
      if (nameMatch || uidMatch) {
        const name = nameMatch ? nameMatch[1] : `用户${uid}`;
        log('LOGIN', `OK: ${name} (${uid})`);
        return { ok: true, uid, name, error: '' };
      }
      return { ok: false, uid: '', name: '', error: 'Cookie可能已过期' };
    } catch (e) {
      return { ok: false, uid: '', name: '', error: String(e) };
    }
  }

  async getChatList() {
    log('CHAT', '获取聊天列表 (GET /chat)...');
    try {
      await this.ensureC3VK();
      const r = await httpRequest('https://www.luogu.com.cn/chat', {
        headers: {
          cookie: this._cookie,
          referer: 'https://www.luogu.com.cn/',
          accept: 'text/html,application/xhtml+xml'
        }
      });
      log('CHAT', `resp: ${r.status} ${r.body.length}B, cookies: ${r.cookies.length}`);
      // Check redirect
      if (r.status === 302 || r.status === 301) {
        log('CHAT', `redirect to: ${r.headers.location || 'unknown'}`);
      }

      // Parse _feInjection
      let data = null;
      const m1 = r.body.match(/window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)/);
      if (m1) {
        try { data = JSON.parse(decodeURIComponent(m1[1])); log('CHAT', `_feInjection parsed, keys: ${Object.keys(data).join(',')}`); } catch(e) { log('CHAT', `parse err: ${e}`); }
      }
      if (!data) {
        const m2 = r.body.match(/<script[^>]*>window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)<\/script>/);
        if (m2) {
          try { data = JSON.parse(decodeURIComponent(m2[1])); log('CHAT', `_feInjection v2 parsed`); } catch(e) { log('CHAT', `parse v2 err: ${e}`); }
        }
      }
      if (!data) { log('CHAT', 'WARN: _feInjection not found in page'); return []; }

      if (data) {
        const msgs = data.currentData?.latestMessages?.result || [];
        if (msgs.length > 0) {
          const seen = {};
          for (const msg of msgs) {
            const s = msg.sender || {};
            const r = msg.receiver || {};
            const suid = String(s.uid || '');
            let ouid, oname;
            if (suid === this._uid) {
              ouid = String(r.uid || '');
              oname = r.name || '?';
            } else {
              ouid = suid;
              oname = s.name || '?';
            }
            if (!ouid) continue;
            if (!seen[ouid]) {
              seen[ouid] = {
                uid: ouid, name: oname,
                content: msg.content || '',
                time: msg.time || 0,
                status: msg.status || 0,
                avatar: (s.avatar || r.avatar || ''),
                color: (suid !== this._uid ? s : r).color || ''
              };
            } else {
              seen[ouid].content = msg.content || '';
              seen[ouid].time = msg.time || 0;
              seen[ouid].status = msg.status || 0;
            }
          }
          const result = Object.values(seen);
          // Cache (skip in incognito)
          if (!isIncognito()) {
            try { fs.writeFileSync(path.join(DATA_DIR, '_chat_list.json'), JSON.stringify(result), 'utf-8'); } catch {}
          }
          log('CHAT', `聚合 ${result.length} 个会话, ${msgs.length}条原始消息`);
          if(result.length>0){const r0=result[0];log('CHAT',`样例 uid=${r0.uid} name=${r0.name} avatar=${(r0.avatar||'').substring(0,60)}`)}
          return result;
        }
      }
      return [];
    } catch (e) { log('CHAT', `ERR: ${e}`); return []; }
  }

  async getMessages(targetUid, page = null) {
    const key = page !== null ? page : 0;
    let url = `https://www.luogu.com.cn/api/chat/record?user=${targetUid}`;
    if (page !== null && page > 0) url += `&page=${page}`;

    const cacheFile = path.join(DATA_DIR, `msg_${targetUid}_${key}.json`);
    let cached = null;
    if (fs.existsSync(cacheFile)) {
      try { cached = JSON.parse(fs.readFileSync(cacheFile, 'utf-8')); } catch {}
    }

    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        const csrf = attempt === 1 ? (await this._csrfCached()) : (await this._csrf());
        const headers = { cookie: this._cookie, referer: 'https://www.luogu.com.cn/chat' };
        if (csrf) {
          headers['x-csrf-token'] = csrf;
          headers['x-requested-with'] = 'XMLHttpRequest';
        }
        const r = await httpRequest(url, { headers, timeout: 15000 });
        if (r.status === 200) {
          try {
            const data = JSON.parse(r.body);
            const mw = data.messages || {};
            if (typeof mw === 'object') {
              const result = mw.result || [];
              const count = mw.count || result.length;
              const perPage = mw.perPage || result.length;
              const totalPages = perPage > 0 ? Math.ceil(count / perPage) : 1;
              const currentPage = (page !== null && page > 0) ? page : totalPages;
              log('MSG', `${result.length}条 (总${count}, ${perPage}/页, ${totalPages}页, 第${currentPage}页)`);
              const ret = { messages: result, count, perPage, totalPages, currentPage };
              if (!isIncognito()) { try { fs.writeFileSync(cacheFile, JSON.stringify(ret), 'utf-8'); } catch {} }
              return ret;
            }
          } catch {
            if (attempt === 1) {
              this._csrfCache = null;
              await this.ensureC3VK();
              log('CSRF', 'JSON解析失败，刷新重试...');
              continue;
            }
          }
        }
        break;
      } catch (e) {
        if (attempt === 1) {
          this._csrfCache = null;
          await this.ensureC3VK();
          log('CSRF', `请求异常(第1次): ${e}，刷新重试...`);
          continue;
        }
        log('MSG', `最终失败: ${e}`);
      }
      break;
    }
    return cached || { messages: [], count: 0, perPage: 50, totalPages: 0 };
  }

  async sendMessage(targetId, content) {
    const csrf = await this._csrf();
    if (!csrf) { log('SEND', 'ERR: 无csrf'); return false; }
    try {
      log('SEND', `-> ${targetId}: ${content.substring(0, 30)}`);
      const r = await httpRequest('https://www.luogu.com.cn/api/chat/new', {
        method: 'POST',
        headers: {
          cookie: this._cookie, 'content-type': 'application/json',
          referer: 'https://www.luogu.com.cn/chat', 'x-csrf-token': csrf,
          'x-requested-with': 'XMLHttpRequest', origin: 'https://www.luogu.com.cn'
        },
        body: JSON.stringify({ user: parseInt(targetId), content }),
        timeout: 10000
      });
      log('SEND', `结果: status=${r.status} body=${r.body.substring(0,80)}`);
      return r.status === 200;
    } catch (e) { log('SEND', `ERR: ${e}`); return false; }
  }

  async deleteMessage(msgId) {
    const csrf = await this._csrf();
    if (!csrf) return false;
    try {
      const r = await httpRequest('https://www.luogu.com.cn/api/chat/delete', {
        method: 'POST',
        headers: {
          cookie: this._cookie, 'content-type': 'application/json',
          'x-csrf-token': csrf, 'x-requested-with': 'XMLHttpRequest',
          referer: 'https://www.luogu.com.cn/chat', origin: 'https://www.luogu.com.cn'
        },
        body: JSON.stringify({ id: parseInt(msgId) }),
        timeout: 10000
      });
      return r.status === 200;
    } catch (e) { log('DEL', `ERR: ${e}`); return false; }
  }

  async searchUsers(keyword) {
    log('SRCH', `搜索: ${keyword}`);
    try {
      const csrf = await this._csrfCached();
      const headers = { cookie: this._cookie, referer: 'https://www.luogu.com.cn/chat' };
      if (csrf) {
        headers['x-csrf-token'] = csrf;
        headers['x-requested-with'] = 'XMLHttpRequest';
      }
      const r = await httpRequest(`https://www.luogu.com.cn/api/user/search?keyword=${encodeURIComponent(keyword)}`, { headers });
      if (r.status === 200) {
        const d = JSON.parse(r.body);
        log('SRCH', `找到 ${(d.users||[]).length} 个用户`);
        return d.users || [];
      }
      log('SRCH', `状态码: ${r.status}`);
      return [];
    } catch (e) { log('SRCH', `异常: ${e}`); return []; }
  }

  async downloadAvatar(uid, force = false) {
    const local = path.join(AVATAR_DIR, `${uid}.png`);
    if (!force && fs.existsSync(local) && fs.statSync(local).size > 0) {
      log('AVATAR', `UID=${uid} 缓存命中 (${fs.statSync(local).size}B)`);
      return local;
    }
    if (isIncognito()) { log('AVATAR', `skip download in incognito`); return ''; }
    try {
      log('AVATAR', `下载头像 UID=${uid}...`);
      const url = `https://cdn.luogu.com.cn/upload/usericon/${uid}.png`;
      const r = await httpRequest(url, {
        headers: { referer: 'https://www.luogu.com.cn/', 'user-agent': UA },
        binary: true
      });
      if (r.status === 200 && r.body.length > 0) {
        fs.writeFileSync(local, r.body);
        log('AVATAR', `UID=${uid} 下载成功 (${r.body.length}B)`);
        return local;
      }
      log('AVATAR', `UID=${uid} 下载失败 code=${r.status} len=${r.body.length}`);
    } catch (e) { log('AVATAR', `UID=${uid} 异常: ${e.message}`); }
    return '';
  }
}

// ── AI 助手 ──
const DEFAULT_AI_KEY = 'd3f58281b035422f86e8969b717fe684.l63UZdnwfJCF26uS';
const DEFAULT_AI_URL = 'https://open.bigmodel.cn/api/paas/v4';
const DEFAULT_AI_MODEL = 'glm-4-flash';

class AIAssistant {
  isEnabled() { return config.ai.enabled || false; }

  _getAIConfig() {
    if (config.ai.default !== false) {
      return { baseUrl: DEFAULT_AI_URL, apiKey: DEFAULT_AI_KEY, model: DEFAULT_AI_MODEL };
    }
    const c = config.ai.custom || {};
    return {
      baseUrl: c.base_url || DEFAULT_AI_URL,
      apiKey: c.api_key || '',
      model: c.model || DEFAULT_AI_MODEL
    };
  }

  async _chat(messages, model = null) {
    const { baseUrl, apiKey, model: cfgModel } = this._getAIConfig();
    const m = model || cfgModel;
    if (!apiKey) return '';
    const url = `${baseUrl.replace(/\/+$/, '')}/chat/completions`;
    try {
      const r = await httpRequest(url, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: m, messages }),
        timeout: 30000
      });
      if (r.status === 200) {
        const resp = JSON.parse(r.body);
        return resp.choices?.[0]?.message?.content || '';
      }
      log('AI', `请求失败: ${r.status} ${r.body.substring(0, 200)}`);
    } catch (e) { log('AI', `异常: ${e}`); }
    return '';
  }

  async checkImportance(message, senderName = '') {
    if (!this.isEnabled()) return { isImportant: false, analysis: '', tip: '' };
    const keyword = config.ai.important_keyword || 'zhl重要信息';
    const isDefault = config.ai.default !== false;

    let sysPrompt, qTemplate;
    if (isDefault) {
      sysPrompt = DEFAULT_CONFIG.ai.system_prompt;
      qTemplate = DEFAULT_CONFIG.ai.question_template;
    } else {
      sysPrompt = config.ai.custom?.custom_system_prompt || DEFAULT_CONFIG.ai.system_prompt;
      qTemplate = config.ai.question_template || DEFAULT_CONFIG.ai.question_template;
    }

    // Append current mode's extra prompt if configured
    const modeCfg = (config.modes || {})[currentMode || 'class'];
    if (modeCfg && modeCfg.prompt) {
      sysPrompt = (sysPrompt || '') + '\n\n' + modeCfg.prompt;
    }

    let userPrompt = qTemplate.replace(/{keyword}/g, keyword);
    if (senderName) userPrompt += `\n以下是要判断的消息（来自 ${senderName}）：${message}`;
    else userPrompt += `\n以下是要判断的消息：${message}`;

    userPrompt = userPrompt.replace(/{background}/g, '');

    const msgs = [];
    if (sysPrompt.trim()) msgs.push({ role: 'system', content: sysPrompt });
    msgs.push({ role: 'user', content: userPrompt });

    const answer = await this._chat(msgs);
    const isImportant = answer.includes(keyword);

    // Extract tip
    let tip = '';
    if (isImportant) {
      const prefix = config.notification.popup_prefix || '提示：';
      const suffix = config.notification.popup_suffix || '。';
      const tipMatch = answer.match(new RegExp(`${escapeRegex(prefix)}.*?${escapeRegex(suffix)}`));
      tip = tipMatch ? tipMatch[0] : answer;
    }

    return { isImportant, analysis: answer, tip };
  }

  async generateReply(message, background = '') {
    const arCfg = config.auto_reply || {};
    const sysPrompt = arCfg.system_prompt || '';
    const qTemplate = arCfg.question_template || '';
    const question = qTemplate.replace(/{message}/g, message).replace(/{background}/g, background);

    const msgs = [];
    if (sysPrompt.trim()) msgs.push({ role: 'system', content: sysPrompt });
    msgs.push({ role: 'user', content: question });
    return await this._chat(msgs);
  }

  async checkNeedReply(message, background = '') {
    const arCfg = config.auto_reply || {};
    const sysPrompt = arCfg.system_prompt || '';
    const checkQ = (arCfg.check_question || '')
      .replace(/{message}/g, message).replace(/{background}/g, background);

    const msgs = [];
    if (sysPrompt.trim()) msgs.push({ role: 'system', content: sysPrompt });
    msgs.push({ role: 'user', content: checkQ });
    const result = await this._chat(msgs);
    return result && !result.includes('不需要') || result.includes('需要');
  }
}

function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

// ── 服务端同步 ──
class ServerSync {
  constructor() {
    this._remaining = 50;
    this._total = 50;
    this._allowed = true;
    this._useCount = 0;
  }

  async sync() {
    if (hasSuperAllow()) {
      this._remaining = 999; this._total = 999; this._allowed = true;
      return { remaining: 999, total: 999, allowed: true };
    }
    const url = config.server?.url || '';
    if (!url) return { remaining: 50, total: 50, allowed: true };
    const uid = config.luogu?.user_id || '';
    if (!uid) return { remaining: 0, total: 0, allowed: false };

    try {
      const r = await httpRequest(`${url.replace(/\/+$/, '')}/api/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          uid, device_id: config.device_id || '',
          cookie: config.luogu?.cookie || ''
        }),
        timeout: 10000
      });
      if (r.status === 200) {
        const d = JSON.parse(r.body);
        this._remaining = d.remaining || 50;
        this._total = d.total || 50;
        this._allowed = d.allowed !== false;
        return d;
      }
    } catch {}
    return { remaining: this._remaining, total: this._total, allowed: this._allowed };
  }

  async recordUse(count = 1) {
    if (hasSuperAllow()) return { remaining: 999 };
    this._useCount += count;
    this._remaining = Math.max(0, this._remaining - count);
    const url = config.server?.url || '';
    if (url && this._useCount >= 10) {
      try {
        await httpRequest(`${url.replace(/\/+$/, '')}/api/report`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ uid: config.luogu?.user_id || '', count: this._useCount }),
          timeout: 5000
        });
        this._useCount = 0;
      } catch {}
    }
    return { remaining: this._remaining };
  }

  get remaining() { return this._remaining; }

  status() {
    return { remaining: this._remaining, total: this._total, allowed: this._allowed };
  }
}

// ── 全局实例 ──
const luogu = new LuoguAPI();
const ai = new AIAssistant();
const serverSync = new ServerSync();
let mainWin = null;
let popupWin = null;
let settingsWin = null;
let aiWin = null;
let tray = null;
let currentMode = 'class';
let wsClient = null;
let wsRunning = false;
let wsRetryCount = 0;

// ── WebSocket ──
function startWS() {
  wsRunning = true;
  connectWS();
}

function stopWS() {
  wsRunning = false;
  if (wsClient) { try { wsClient.close(); } catch {}; wsClient = null; }
}

function connectWS() {
  if (!wsRunning) return;
  const cookie = config.luogu?.cookie || '';
  const uid = config.luogu?.user_id || '';
  if (!cookie || !uid) {
    setTimeout(connectWS, 5000);
    return;
  }

  log('WS', `连接 wss://ws.luogu.com.cn/ws | uid=${uid}`);
  try {
    wsClient = new WebSocket('wss://ws.luogu.com.cn/ws', {
      headers: { Cookie: cookie },
      rejectUnauthorized: false
    });

    wsClient.on('open', () => {
      wsRetryCount = 0;
      const joinMsg = JSON.stringify({ type: 'join_channel', channel: 'chat', channel_param: uid, exclusive_key: null });
      wsClient.send(joinMsg);
      log('WS', `Connected, uid=${uid}`);
      if (mainWin) mainWin.webContents.send('ws-status', 'connected');
    });

    wsClient.on('message', async (raw) => {
      try {
        const d = JSON.parse(raw.toString());
        if (d._ws_type === 'server_broadcast') {
          const m = d.message || {};
          const s = m.sender || {};
          const content = m.content || '';
          const sUid = String(s.uid || '');
          const sName = s.name || '未知';
          const myUid = config.luogu?.user_id || '';
          if (sUid && sUid !== myUid) {
            log('WS', `<- ${sName}(${sUid}): ${content.substring(0, 40)}`);
            if (mainWin) {
              mainWin.webContents.send('new-message', sUid, content, sName, myUid, m.time || Math.floor(Date.now() / 1000));
            }

          // If popup mode is "all", show popup for every new message
          const pmode = config.notification?.popup_mode || 'ai';
          if (pmode === 'all' && config.notification?.enabled !== false) {
            showPopup(sUid, sName, content, '');
          }

          // AI check
          if (config.ai?.enabled && !hasUsedMax()) {
            const r = await ai.checkImportance(content, sName);
            if (r.isImportant) {
              if (mainWin) {
                mainWin.webContents.send('important-message', sUid, content, sName, r.tip || '');
              }
              // 弹窗 (check notification setting)
              if (config.notification?.enabled !== false) {
                showPopup(sUid, sName, content, r.tip || '');
              }
            }
            // Record AI use
              if (sUid !== '1049425' || !hasSuperAllow()) {
                serverSync.recordUse(1);
                if (mainWin) mainWin.webContents.send('server-status', JSON.stringify(serverSync.status()));
              }
            }

            // Auto reply
            const arCfg = config.auto_reply || {};
            if (arCfg.enabled && content.includes(arCfg.keyword || 'Zhl需要回复')) {
              const isCustom = config.ai.default === false;
              const uidNum = config.luogu?.user_id || '';
              if (isCustom || uidNum === '1049425') {
                const bgText = await getBackground(sUid);
                const needReply = await ai.checkNeedReply(content, bgText);
                if (needReply) {
                  const reply = await ai.generateReply(content, bgText);
                  if (reply && reply.trim()) {
                    const ok = await luogu.sendMessage(sUid, reply.trim());
                    if (mainWin) {
                      mainWin.webContents.send('auto-reply-done', sUid, content, reply.trim());
                      mainWin.webContents.send('reply-sent', ok, '');
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) { log('WS', `parse err: ${e}`); }
    });

    wsClient.on('error', (err) => {
      log('WS', `err: ${err}`);
      if (mainWin) mainWin.webContents.send('ws-status', 'error');
    });

    wsClient.on('close', (code, reason) => {
      log('WS', `closed: ${code} ${reason}`);
      if (mainWin) mainWin.webContents.send('ws-status', 'disconnected');
      wsClient = null;
      if (wsRunning) {
        const delay = Math.min(15000, 3000 * wsRetryCount);
        wsRetryCount++;
        setTimeout(connectWS, delay);
      }
    });
  } catch (e) {
    log('WS', `创建失败: ${e}`);
    if (wsRunning) setTimeout(connectWS, 5000);
  }
}

// ── 背景上下文 ──
async function getBackground(uid) {
  const bgCfg = config.background || {};
  if (!bgCfg.enabled) return '';
  try {
    const maxMsgs = bgCfg.max_messages || 20;
    const maxChars = bgCfg.max_chars || 2000;
    const myUid = config.luogu?.user_id || '';
    const data = await luogu.getMessages(uid);
    const msgs = data.messages || [];
    if (!msgs.length) return '';
    const lines = [];
    let totalChars = 0;
    for (let i = msgs.length - 1; i >= 0; i--) {
      const m = msgs[i];
      const s = m.sender || {};
      const suid = String(s.uid || '');
      const sname = s.name || '?';
      const line = suid !== myUid ? `[${sname}]: ${m.content || ''}` : `[我]: ${m.content || ''}`;
      if (lines.length >= maxMsgs || totalChars + line.length > maxChars) break;
      lines.unshift(line);
      totalChars += line.length;
    }
    return ['以下是最近的聊天记录：', ...lines].join('\n');
  } catch (e) { log('BG', `错误: ${e}`); return ''; }
}

// ── 用量检查 ──
function hasUsedMax() {
  if (hasSuperAllow()) return false;
  if (config.luogu?.user_id === '1049425') return false;
  if (!serverSync._allowed) return true;
  if (serverSync._remaining <= 0) return true;
  return false;
}

// ── 弹窗 ──
function showPopup(uid, senderName, content, tip) {
  if (popupWin && !popupWin.isDestroyed()) {
    popupWin.close();
  }

  const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;
  const popupWidth = 370;

  popupWin = new BrowserWindow({
    width: popupWidth, height: 420,
    x: sw - popupWidth - 20,
    y: sh - 440,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false
    }
  });

  // Prepare data
  const notifyData = { uid, name: senderName, content, tip };
  const hash = encodeURIComponent(JSON.stringify(notifyData));

  popupWin.loadFile(path.join(__dirname, 'notify.html'), { hash: '#' + hash });

  popupWin.on('closed', () => { popupWin = null; });
}

// ── IPC 处理 ──
function setupIPC() {
  ipcMain.handle('get-config', () => JSON.stringify(config));
  ipcMain.handle('save-config', async (e, jsonStr) => {
    try {
      const data = JSON.parse(jsonStr);
      // Cookie normalization
      const rawC = data.luogu?.cookie || '';
      const rawU = data.luogu?.user_id || '';
      if (rawC || rawU) {
        const normalized = normalizeCookie(rawC, rawU);
        data.luogu.cookie = normalized;
        const m = normalized.match(/_uid=(\d+)/);
        if (m) data.luogu.user_id = m[1];
      }
      config = deepMerge(config, data);
      saveConfig();
      luogu._setFromConfig();
      serverSync.sync();
      // Broadcast config change to main window
      if (mainWin) mainWin.webContents.send('config-updated');
      return { ok: true };
    } catch (e) { return { ok: false, error: String(e) }; }
  });

  ipcMain.handle('test-login', async (e, uid, cookie) => {
    const full = normalizeCookie(cookie, uid);
    const m = full.match(/_uid=(\d+)/);
    const extractedUid = m ? m[1] : uid;
    if (!extractedUid) return { ok: false, uid: '', name: '', error: '无法获取UID' };

    const tmp = new LuoguAPI();
    tmp._cookie = full;
    tmp._uid = extractedUid;
    const result = await tmp.testLogin();
    if (result.ok) {
      config.luogu.cookie = tmp._cookie;
      config.luogu.user_id = result.uid || extractedUid;
      saveConfig();
      luogu._setFromConfig();
      startWS();
    }
    return result;
  });

  ipcMain.handle('has-super-allow', () => hasSuperAllow());

  ipcMain.handle('toggle-incognito', () => {
    config.incognito = !config.incognito;
    saveConfig();
    return config.incognito;
  });
  ipcMain.handle('is-incognito', () => config.incognito === true);

  ipcMain.handle('refresh-chat-list', async () => {
    try {
      const data = await luogu.getChatList();
      return JSON.stringify(data);
    } catch (e) { return '[]'; }
  });

  ipcMain.handle('get-chat-list', () => {
    const cache = path.join(DATA_DIR, '_chat_list.json');
    if (fs.existsSync(cache)) {
      try { return fs.readFileSync(cache, 'utf-8'); } catch {}
    }
    return '[]';
  });

  ipcMain.handle('get-messages', async (e, targetUid, page, force) => {
    const key = page < 0 ? 0 : page;
    const cacheFile = path.join(DATA_DIR, `msg_${targetUid}_${key}.json`);

    if (page < 0) {
      // Latest page: force=false → cache only, force=true → server fetch
      if (!force && fs.existsSync(cacheFile)) {
        try {
          const cachedData = JSON.parse(fs.readFileSync(cacheFile, 'utf-8'));
          return JSON.stringify({
            messages: cachedData.messages || [], totalPages: cachedData.totalPages || 1,
            cached: true, hasMore: (cachedData.totalPages || 1) > 1
          });
        } catch {}
      }
      try {
        const data = await luogu.getMessages(targetUid, null);
        return JSON.stringify({
          messages: data.messages || [], totalPages: data.totalPages || 1,
          cached: false, hasMore: (data.totalPages || 1) > 1
        });
      } catch { return '{"messages":[],"totalPages":0}'; }
    } else {
      // Historical page: force=false → cache only, force=true → server fetch
      if (!force && fs.existsSync(cacheFile)) {
        try {
          const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf-8'));
          return JSON.stringify({
            messages: cached.messages || [], totalPages: cached.totalPages || 1,
            cached: true, hasMore: (cached.totalPages || 1) > 1 && page < (cached.totalPages || 1)
          });
        } catch {}
      }
      try {
        const data = await luogu.getMessages(targetUid, page);
        return JSON.stringify({
          messages: data.messages || [], totalPages: data.totalPages || 1,
          cached: false, hasMore: (data.totalPages || 1) > 1 && page < data.totalPages
        });
      } catch {
        if (fs.existsSync(cacheFile)) {
          try {
            const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf-8'));
            return JSON.stringify({
              messages: cached.messages || [], totalPages: cached.totalPages || 1,
              cached: true, hasMore: (cached.totalPages || 1) > 1
            });
          } catch {}
        }
        return '{"messages":[],"totalPages":0,"cached":false,"hasMore":false}';
      }
    }
  });

  ipcMain.handle('send-message', async (e, targetUid, content) => {
    try {
      const ok = await luogu.sendMessage(targetUid, content);
      return { ok, error: ok ? '' : '发送失败' };
    } catch (e) { return { ok: false, error: String(e) }; }
  });

  ipcMain.handle('delete-message', async (e, msgId) => {
    try {
      const ok = await luogu.deleteMessage(msgId);
      return { ok };
    } catch (e) { return { ok: false }; }
  });

  ipcMain.handle('search-users', async (e, keyword) => {
    try {
      const users = await luogu.searchUsers(keyword);
      return JSON.stringify(users);
    } catch { return '[]'; }
  });

  ipcMain.handle('get-avatar-path', (e, uid) => {
    const local = path.join(AVATAR_DIR, `${uid}.png`);
    if (fs.existsSync(local) && fs.statSync(local).size > 0) {
      return `file:///${local.replace(/\\/g, '/')}`;
    }
    return '';
  });

  ipcMain.handle('request-avatar', async (e, uid) => {
    const local = await luogu.downloadAvatar(uid, true);
    if (local) {
      if (mainWin) mainWin.webContents.send('avatar-ready', uid, local.replace(/\\/g, '/'));
      return `file:///${local.replace(/\\/g, '/')}`;
    }
    return '';
  });

  ipcMain.handle('prefetch-avatars', async (e, uidListJson) => {
    try {
      const uidList = JSON.parse(uidListJson);
      log('AVATAR', `预取 ${uidList.length} 个头像: ${uidList.slice(0,5).join(',')}...`);
      for (const uid of uidList) {
        const local = await luogu.downloadAvatar(uid);
        if (local && mainWin) {
          log('AVATAR', `  uid=${uid} -> ${local}`);
          mainWin.webContents.send('avatar-ready', uid, local.replace(/\\/g, '/'));
        }
      }
    } catch(e) { log('AVATAR', `预取异常: ${e}`); }
  });

  ipcMain.handle('sync-now', async () => {
    const r = await serverSync.sync();
    return JSON.stringify(r);
  });

  ipcMain.handle('get-server-status', () => JSON.stringify(serverSync.status()));

  ipcMain.handle('record-ai-use', async (e, count) => {
    if (hasSuperAllow()) return JSON.stringify({ remaining: 999 });
    if (config.luogu?.user_id === '1049425') return JSON.stringify({ remaining: 999 });
    const r = await serverSync.recordUse(count || 1);
    return JSON.stringify(r);
  });

  ipcMain.handle('set-cookie-format', (e, uid, clientId) => {
    const cookie = `_uid=${uid}; __client_id=${clientId}`;
    config.luogu.cookie = cookie;
    config.luogu.user_id = uid;
    saveConfig();
    luogu._setFromConfig();
    return cookie;
  });

  ipcMain.handle('set-current-mode', (e, mode) => {
    currentMode = mode || 'class';
    return true;
  });

  ipcMain.handle('copy-text', (e, text) => {
    clipboard.writeText(text);
  });

  ipcMain.handle('auto-login', async () => {
    if (luogu._cookie && luogu._uid) {
      await luogu.ensureC3VK();
      luogu._setFromConfig();
      startWS();
      return { ok: true, uid: luogu._uid };
    }
    return { ok: false };
  });

  ipcMain.handle('get-system-fonts', () => {
    // Return common Chinese fonts
    return JSON.stringify([
      'Microsoft YaHei', 'PingFang SC', 'SimHei', 'SimSun', 'KaiTi',
      'FangSong', 'Arial', 'Segoe UI', 'Consolas', 'SF Mono'
    ]);
  });

  ipcMain.handle('open-external', (e, url) => {
    shell.openExternal(url);
  });

  ipcMain.handle('get-app-path', () => BASE_DIR);

  ipcMain.handle('play-sound', async (e, filePath) => {
    // Use system notification sound or custom mp3
    if (filePath && fs.existsSync(filePath)) {
      try {
        const { exec } = require('child_process');
        exec(`start "" "${filePath}"`, { shell: true });
      } catch {}
    } else {
      // System beep
      try { shell.beep(); } catch {}
    }
  });

  // Window controls
  ipcMain.handle('minimize-window', () => { if (mainWin) mainWin.minimize(); });
  ipcMain.handle('maximize-window', () => {
    if (mainWin) {
      if (mainWin.isMaximized()) mainWin.unmaximize();
      else mainWin.maximize();
    }
  });
  ipcMain.handle('close-window', () => { if (mainWin) mainWin.hide(); }); // minimize to tray
  ipcMain.handle('is-maximized', () => mainWin ? mainWin.isMaximized() : false);

  // Window snap shortcuts
  ipcMain.handle('snap-left', () => {
    if (!mainWin) return;
    const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;
    mainWin.setBounds({ x: 0, y: 0, width: Math.floor(sw / 2), height: sh });
  });
  ipcMain.handle('snap-right', () => {
    if (!mainWin) return;
    const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;
    mainWin.setBounds({ x: Math.floor(sw / 2), y: 0, width: Math.floor(sw / 2), height: sh });
  });
  ipcMain.handle('snap-up', () => {
    if (mainWin) {
      if (mainWin.isMaximized()) mainWin.unmaximize();
      else mainWin.maximize();
    }
  });
  ipcMain.handle('snap-down', () => {
    if (mainWin) {
      if (mainWin.isMaximized()) mainWin.unmaximize();
      else mainWin.minimize();
    }
  });

  // Standalone settings window
  ipcMain.handle('open-settings-window', () => {
    if (settingsWin && !settingsWin.isDestroyed()) { settingsWin.focus(); return true; }
    settingsWin = new BrowserWindow({
      width: 580, height: 640, minWidth: 480, minHeight: 400,
      frame: false, backgroundColor: '#EDF0F8',
      webPreferences: { preload: path.join(__dirname, 'preload.js'),
        nodeIntegration: false, contextIsolation: true, webSecurity: false }
    });
    settingsWin.loadFile(path.join(__dirname, 'settings.html'));
    settingsWin.on('closed', () => { settingsWin = null; });
    return true;
  });

  // Standalone AI settings window
  ipcMain.handle('open-ai-settings-window', () => {
    if (aiWin && !aiWin.isDestroyed()) { aiWin.focus(); return true; }
    aiWin = new BrowserWindow({
      width: 600, height: 680, minWidth: 480, minHeight: 400,
      frame: false, backgroundColor: '#EDF0F8',
      webPreferences: { preload: path.join(__dirname, 'preload.js'),
        nodeIntegration: false, contextIsolation: true, webSecurity: false }
    });
    aiWin.loadFile(path.join(__dirname, 'ai.html'));
    aiWin.on('closed', () => { aiWin = null; });
    return true;
  });

  // Standalone chat window
  ipcMain.handle('open-chat-window', (e, uid, name) => {
    const ws = config.window?.chat_size || { w: 450, h: 600 };
    const chatWin = new BrowserWindow({
      width: ws.w || 450, height: ws.h || 600, minWidth: 350, minHeight: 300,
      frame: false, backgroundColor: '#EDF0F8', maximizable: false,
      webPreferences: { preload: path.join(__dirname, 'preload.js'),
        nodeIntegration: false, contextIsolation: true, webSecurity: false }
    });
    // Save size on resize
    chatWin.on('resize', () => {
      const [w, h] = chatWin.getSize();
      config.window = config.window || {};
      config.window.chat_size = { w, h };
    });
    chatWin.on('close', () => saveConfig());
    chatWin.loadFile(path.join(__dirname, 'chat.html'));
    chatWin.webContents.on('did-finish-load', () => {
      chatWin.webContents.send('chat-window-open', uid, name);
    });
    return true;
  });

  // Popup reply
  ipcMain.handle('popup-reply', async (e, uid, content) => {
    const ok = await luogu.sendMessage(uid, content);
    return { ok };
  });

  // Popup: focus main window and select chat
  ipcMain.handle('popup-focus-chat', (e, uid, name) => {
    if (mainWin) {
      mainWin.show();
      mainWin.focus();
      mainWin.webContents.send('focus-chat-user', uid, name);
    }
    return true;
  });

  // Popup: open small chat window and close popup
  ipcMain.handle('popup-open-chat-win', (e, uid, name) => {
    if (mainWin) {
      mainWin.webContents.send('open-chat-window-from-popup', uid, name);
    }
    return true;
  });

  // Popup: send reply
  ipcMain.handle('popup-send-reply', async (e, uid, content) => {
    const ok = await luogu.sendMessage(uid, content);
    return { ok };
  });
}

// ── 创建主窗口 ──
function createWindow() {
  const winConfig = config.window || {};
  mainWin = new BrowserWindow({
    width: winConfig.width || 1300,
    height: winConfig.height || 850,
    minWidth: 820,
    minHeight: 520,
    frame: false,
    backgroundColor: '#EDF0F8',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false
    },
    icon: path.join(BASE_DIR, 'icon.ico')
  });

  mainWin.loadFile(path.join(__dirname, 'index.html'));

  // Maximize tracking
  let isMaxed = false;
  mainWin.on('maximize', () => { isMaxed = true; if (mainWin) mainWin.webContents.send('window-maximized', true); });
  mainWin.on('unmaximize', () => { isMaxed = false; if (mainWin) mainWin.webContents.send('window-maximized', false); });

  // Double-click titlebar to maximize
  mainWin.on('resize', () => {
    if (config.window) {
      const [w, h] = mainWin.getSize();
      config.window.width = w;
      config.window.height = h;
    }
  });

  mainWin.on('close', (e) => {
    // Minimize to tray instead of closing
    if (tray) {
      e.preventDefault();
      mainWin.hide();
      return;
    }
    saveConfig();
    stopWS();
  });

  mainWin.on('closed', () => {
    mainWin = null;
    stopWS();
  });

  // 系统托盘
  try {
    // Create tray icon programmatically (works without file)
    const buf = Buffer.alloc(16 * 16 * 4);
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const i = (y * 16 + x) * 4;
        if (x >= 3 && x <= 12 && y >= 3 && y <= 12) {
          buf[i]=99;buf[i+1]=102;buf[i+2]=241;buf[i+3]=255;
        } else {
          buf[i]=30;buf[i+1]=32;buf[i+2]=56;buf[i+3]=200;
        }
      }
    }
    const trayIcon = nativeImage.createFromBuffer(buf, { width: 16, height: 16 });
    tray = new Tray(trayIcon);
    tray.setToolTip('LuoguChat — 双击打开');
    const contextMenu = Menu.buildFromTemplate([
      { label: '显示主窗口', click: () => { if (mainWin) { mainWin.show(); mainWin.focus(); } } },
      { type: 'separator' },
      { label: '退出', click: () => { stopWS(); saveConfig(); tray.destroy(); app.quit(); } }
    ]);
    tray.setContextMenu(contextMenu);
    tray.on('double-click', () => { if (mainWin) { mainWin.show(); mainWin.focus(); } });
    log('TRAY', '托盘已启动');
  } catch (e) { log('TRAY', `失败: ${e}`); }
}

// ── 应用生命周期 ──
app.whenReady().then(() => {
  // 注册自定义协议用于本地头像文件 (绕过 file:// 限制)
  protocol.handle('avatar', (request) => {
    const uid = request.url.replace('avatar://', '').replace(/\/+$/, '');
    const filePath = path.join(AVATAR_DIR, `${uid}.png`);
    if (fs.existsSync(filePath)) {
      return net.fetch(`file:///${filePath.replace(/\\/g, '/')}`);
    }
    return new Response('', { status: 404 });
  });
  setupIPC();
  createWindow();
  // Auto login
  setTimeout(async () => {
    if (luogu._cookie && luogu._uid) {
      await luogu.ensureC3VK();
      luogu._setFromConfig();
      startWS();
      if (mainWin) mainWin.webContents.send('auto-login', luogu._uid);
    }
    // Sync with server
    if (config.server?.url) {
      await serverSync.sync();
      if (mainWin) mainWin.webContents.send('server-status', JSON.stringify(serverSync.status()));
    }
  }, 1000);
});

app.on('window-all-closed', () => { /* keep running in tray */ });
app.on('before-quit', () => {
  stopWS();
  saveConfig();
});
