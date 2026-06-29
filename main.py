# -*- coding: utf-8 -*-
"""LuoguChat v7.0 — Premium Desktop Chat"""
import os, sys, json, time, re, math, uuid, traceback, webbrowser, hashlib
import requests, ssl
import websocket as ws_lib
from urllib.parse import unquote
from concurrent.futures import ThreadPoolExecutor

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
os.environ["QML_DISABLE_DISK_CACHE"] = "1"
if sys.platform == "win32":
    try: sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except: pass

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(CACHE_DIR, exist_ok=True)
CONFIG_FILE = os.path.join(BASE_DIR, "config.json")
ALLOW_FILE = os.path.join(BASE_DIR, "zhl_super_allow.txt")
AI_LOG_DIR = os.path.join(BASE_DIR, "aichat")
os.makedirs(AI_LOG_DIR, exist_ok=True)
AI_LOG_FILE = os.path.join(AI_LOG_DIR, "log.txt")

def _log_ai(tag, messages, response):
    """记录 AI 对话到 aichat/log.txt"""
    t = time.strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(AI_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"\n{'='*60}\n")
            f.write(f"[{t}] {tag}\n")
            f.write(f"{'='*60}\n")
            for msg in messages:
                role = msg.get("role", "?").upper()
                content = msg.get("content", "")
                f.write(f"[{role}] {content[:500]}\n")
            f.write(f"[ASSISTANT] {response[:1000] if response else '(empty)'}\n")
            f.write(f"{'='*60}\n\n")
    except:
        pass
LOG_DIR = os.path.join(BASE_DIR, "log")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, "debug.log")

def _log(tag, msg):
    t = time.strftime("%H:%M:%S")
    line = f"[{t}][{tag}] {msg}"
    try: print(line, flush=True)
    except: pass
    if not hasattr(_log, "_first"):
        _log._first = True
        try:
            with open(LOG_FILE, "w", encoding="utf-8") as f:
                f.write(f"=== LuoguChat v7.0 启动 {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")
        except: pass
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except: pass

def _log_req(method, url, headers=None, body=None):
    _log("REQ", f"{method} {url}")

def _log_res(url, resp, label=""):
    _log(label or "RES", f"<- {url} => {resp.status_code} | {len(resp.text)}B")

def _mask(s, n=8):
    if not s or len(s) <= n * 2: return s or ""
    return str(s)[:n] + "..." + str(s)[-n:]

def normalize_cookie(raw, uid=""):
    """将各种cookie格式统一转换为 _uid=xxx; __client_id=xxx 格式"""
    raw = raw.strip().strip(';').strip()
    if not raw: return ""

    # 提取 __client_id
    cid_match = re.search(r'__client_id=([^;]+)', raw)
    client_id = cid_match.group(1).strip() if cid_match else ""

    # 提取 _uid
    uid_match = re.search(r'_uid=(\d+)', raw)
    extracted_uid = uid_match.group(1) if uid_match else ""
    uid = extracted_uid or uid

    # 如果 raw 看起来像是纯 client_id (没有等号)
    if "=" not in raw:
        client_id = raw
    # 如果是 "key=value" 格式且只有一个组件
    elif ";" not in raw and "=" in raw:
        parts = raw.split("=", 1)
        if parts[0].strip() == "_uid":
            uid = parts[1].strip()
            client_id = client_id or uid  # fallback
        elif parts[0].strip() == "__client_id":
            client_id = parts[1].strip()
        else:
            client_id = raw

    if not client_id:
        client_id = uid or raw

    if not uid:
        uid = client_id

    result = f"_uid={uid}; __client_id={client_id}"
    return result

def has_super_allow():
    return os.path.exists(ALLOW_FILE)

# ===== 默认 AI（智谱）=====
DEFAULT_AI_KEY = "d3f58281b035422f86e8969b717fe684.l63UZdnwfJCF26uS"
DEFAULT_AI_URL = "https://open.bigmodel.cn/api/paas/v4"
DEFAULT_AI_MODEL = "glm-4-flash"
DEFAULT_SYSTEM_PROMPT = "你是我的私信管理助手。不要透露你自己的真实身份，只需要专注于判断消息重要性。如果重要请在回复中包含用户设定的关键词。"
DEFAULT_QUESTION_TEMPLATE = (
    "你是我的私信管理助手，你需要帮我判断这个信息是否是重要的。"
    "重要的定义是排除娱乐等无意义内容，重要内容包含讨论问题，紧急情况等信息，"
    "是我在上课的时候需要了解的信息。"
    "如果重要，请在回复中分析之后明确包含 {keyword} 这个子串"
    "（如果有必要就分析，可以给我提示，以 提示： 开头，"
    "。 结束的话就是你针对这个消息给我的提示，可以视情况而决定写不写），"
    "可以加入你的分析和给我的提示。如果不重要就是 不重要消息。"
    "只有重要消息，我需要尽量马上了解的你才说。"
    "如果无法判断或者不是重要信息，请勿输出 {keyword} 这个子串（不能包含这个子串）。")

class Config:
    def __init__(self):
        self._data = self._defaults()
        self._load()
    def _defaults(self):
        return {
            "luogu": {"cookie": "", "user_id": ""},
            "ai": {
                "enabled": False,
                "important_keyword": "zhl重要信息",
                "default": True,
                "system_prompt": DEFAULT_SYSTEM_PROMPT,
                "question_template": DEFAULT_QUESTION_TEMPLATE,
                "custom": {"base_url": "", "api_key": "", "model": "", "custom_system_prompt": ""}
            },
            "server": {"url": ""},
            "theme": {"mode": 2, "accent": "#6366F1", "avatar_rounded": False},
            "favorites": [], "pins": [],
            "notification": {
                "enabled": True, "sound_enabled": True, "sound_type": "system",
                "sound_file": "", "popup_mode": "ai", "popup_filter": "all",
                "popup_prefix": "提示：", "popup_suffix": "。"
            },
            "modes": {
                "class": {"name": "上课模式", "icon": "", "prompt": ""},
                "free": {"name": "下课模式", "icon": "", "prompt": ""}
            },
            "auto_reply": {
                "enabled": False,
                "keyword": "Zhl需要回复",
                "system_prompt": "你是我的私信助手，需要帮我对重要的消息进行回复。",
                "check_question": "以下是一条消息，请判断是否需要回复。需要回复的消息通常是提问、请求或需要回应的内容。如果不需要回复请回复「不需要」，如果需要请回复「需要」并简要说明原因：\n{message}",
                "question_template": "以下是一条需要回复的消息，请帮我生成一个简短得体的回复：\n{message}"
            },
            "background": {
                "enabled": False,
                "mode": "history",
                "max_messages": 5,
                "suffix": ""
            },
            "device_id": uuid.uuid4().hex[:12]
        }
    def _load(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    loaded = json.load(f)
                self._deep_merge(self._data, loaded)
            except: pass
        self._save()
    def _save(self):
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self._data, f, ensure_ascii=False, indent=2)
        except: pass
    def _deep_merge(self, a, b):
        for k, v in b.items():
            if isinstance(v, dict) and isinstance(a.get(k), dict):
                self._deep_merge(a[k], v)
            else: a[k] = v
    def get(self, path, default=None):
        d = self._data
        for p in path.split("."):
            if isinstance(d, dict) and p in d: d = d[p]
            else: return default
        return d
    def set(self, path, value):
        parts = path.split(".")
        d = self._data
        for p in parts[:-1]:
            if p not in d or not isinstance(d[p], dict): d[p] = {}
            d = d[p]
        d[parts[-1]] = value
        self._save()
    def update_all(self, data):
        self._deep_merge(self._data, data)
        self._save()
    def all(self):
        return json.loads(json.dumps(self._data))

cfg = Config()

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

class LuoguAPI:
    def __init__(self):
        self._cookie = cfg.get("luogu.cookie", "")
        self._uid = cfg.get("luogu.user_id", "")
        self._csrf_cache = None
        self._csrf_time = 0

    def ensure_c3vk(self):
        try:
            url = "https://www.luogu.com.cn/api/chat/record?user=1"
            r = requests.get(url, headers={"cookie": self._cookie, "user-agent": UA, "referer": "https://www.luogu.com.cn/chat"}, timeout=10)
            c3vk = None
            for c in r.cookies:
                if c.name == "C3VK": c3vk = c.value
            if not c3vk:
                for h in r.headers.get("Set-Cookie", "").split(","):
                    for p in h.strip().split(";"):
                        if p.strip().startswith("C3VK="):
                            c3vk = p.strip().split("=", 1)[1]
                            break
                    if c3vk: break
            if c3vk:
                self._cookie = re.sub(r';?\s*C3VK=[^;]*', '', self._cookie).strip(";").strip()
                self._cookie = f"{self._cookie}; C3VK={c3vk}"
                cfg.set("luogu.cookie", self._cookie)
                _log("C3VK", f"C3VK={c3vk}")
                return True
            return False
        except Exception as e:
            _log("C3VK", f"ERR: {e}")
            return False

    def _csrf_cached(self):
        now = time.time()
        if self._csrf_cache and now - self._csrf_time < 300:
            return self._csrf_cache
        self._csrf_cache = self._csrf()
        self._csrf_time = now
        return self._csrf_cache

    def _h(self, extra=None):
        h = {"user-agent": UA, "cookie": self._cookie}
        if extra: h.update(extra)
        return h

    def _csrf(self):
        try:
            url = "https://www.luogu.com.cn/"
            r = requests.get(url, headers={"cookie": self._cookie, "user-agent": UA}, timeout=10)
            c3vk_m = re.search(r'C3VK=([^;"]+)', r.text)
            if c3vk_m:
                c3vk = c3vk_m.group(1)
                self._cookie = re.sub(r';?\s*C3VK=[^;]*', '', self._cookie).strip(";").strip()
                self._cookie = f"{self._cookie}; C3VK={c3vk}"
                cfg.set("luogu.cookie", self._cookie)
                r = requests.get(url, headers={"cookie": self._cookie, "user-agent": UA}, timeout=10)
            m = re.search(r'<meta name="csrf-token" content="([^"]+)"', r.text)
            if m: return m.group(1)
            r2 = requests.get("https://www.luogu.com.cn/chat",
                headers={"cookie": self._cookie, "user-agent": UA, "referer": "https://www.luogu.com.cn/chat"}, timeout=10)
            m2 = re.search(r'<meta name="csrf-token" content="([^"]+)"', r2.text)
            if m2: return m2.group(1)
            return ""
        except Exception as e:
            _log("CSRF", f"ERR: {e}")
            return ""

    def test_login(self):
        _log("LOGIN", "测试登录...")
        try:
            csrf = self._csrf()
            if not csrf: return False, "", "", "获取CSRF失败"
            r = requests.get("https://www.luogu.com.cn/chat",
                headers={"cookie": self._cookie, "user-agent": UA, "referer": "https://www.luogu.com.cn/"}, timeout=10)
            name_m = re.search(r'"name":"([^"]+)"', r.text)
            uid_m = re.search(r'_uid=(\d+)', self._cookie)
            if name_m or uid_m:
                uid = uid_m.group(1) if uid_m else self._uid
                name = name_m.group(1) if name_m else ("用户" + uid)
                _log("LOGIN", f"成功: {name} ({uid})")
                return True, uid, name, ""
            return False, "", "", "Cookie可能已过期"
        except Exception as e:
            return False, "", "", str(e)

    def get_chat_list(self):
        _log("CHAT", "获取聊天列表...")
        try:
            self.ensure_c3vk()
            r = requests.get("https://www.luogu.com.cn/chat",
                headers={"cookie": self._cookie, "user-agent": UA, "referer": "https://www.luogu.com.cn/"}, timeout=10)
            _log_res("https://www.luogu.com.cn/chat", r, "CHAT")
            if len(r.text) < 5000:
                _log("CHAT", "页面过小, 刷新C3VK...")
                self.ensure_c3vk()
                r = requests.get("https://www.luogu.com.cn/chat",
                    headers={"cookie": self._cookie, "user-agent": UA, "referer": "https://www.luogu.com.cn/"}, timeout=10)
                _log("CHAT", f"重试: {len(r.text)}B")

            m = re.search(r'window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)', r.text)
            if m:
                decoded = unquote(m.group(1))
                data = json.loads(decoded)
                msgs = data.get("currentData", {}).get("latestMessages", {}).get("result", [])
                if msgs:
                    seen = {}
                    for msg in msgs:
                        s = msg.get("sender", {})
                        r_ = msg.get("receiver", {})
                        suid = str(s.get("uid", ""))
                        if suid == self._uid:
                            ouid = str(r_.get("uid", ""))
                            oname = r_.get("name", "?")
                        else:
                            ouid = suid
                            oname = s.get("name", "?")
                        if not ouid: continue
                        if ouid not in seen:
                            seen[ouid] = {
                                "uid": ouid, "name": oname,
                                "content": msg.get("content", ""),
                                "time": msg.get("time", 0),
                                "status": msg.get("status", 0),
                                "avatar": s.get("avatar") or r_.get("avatar", ""),
                                "color": (s if suid != self._uid else r_).get("color", ""),
                            }
                        else:
                            seen[ouid]["content"] = msg.get("content", "")
                            seen[ouid]["time"] = msg.get("time", 0)
                            seen[ouid]["name"] = oname
                            seen[ouid]["status"] = msg.get("status", 0)
                    result = list(seen.values())
                    cl_cache = os.path.join(CACHE_DIR, "_chat_list.json")
                    try:
                        with open(cl_cache, "w", encoding="utf-8") as f:
                            json.dump(result, f, ensure_ascii=False)
                    except: pass
                    _log("CHAT", f"聚合 {len(result)} 个会话")
                    return result
            return []
        except Exception as e:
            _log("CHAT", f"ERR: {e}")
            return []

    def get_messages(self, target_uid, page=None):
        key = page if page is not None else 0
        url = f"https://www.luogu.com.cn/api/chat/record?user={target_uid}"
        if page is not None and page > 0: url += f"&page={page}"
        _log_req("GET", url)

        cache_file = os.path.join(CACHE_DIR, f"msg_{target_uid}_{key}.json")
        cached = None
        if os.path.exists(cache_file):
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached = json.load(f)
            except: pass

        try:
            csrf = self._csrf_cached()
            extra = {"referer": "https://www.luogu.com.cn/chat"}
            if csrf:
                extra["x-csrf-token"] = csrf
                extra["x-requested-with"] = "XMLHttpRequest"
            r = requests.get(url, headers=self._h(extra), timeout=15)
            _log_res(url, r, "MSG")
            if r.status_code == 200:
                data = r.json()
                mw = data.get("messages", {})
                if isinstance(mw, dict):
                    result = mw.get("result", [])
                    count = mw.get("count", len(result))
                    pp = mw.get("perPage", len(result))
                    tp = math.ceil(count / pp) if pp > 0 else 1
                    _log("RES", f"-> {len(result)}条 (总{count}, {pp}/页, {tp}页)")
                    ret = {"messages": result, "count": count, "perPage": pp, "totalPages": tp}
                    try:
                        with open(cache_file, "w", encoding="utf-8") as f:
                            json.dump(ret, f, ensure_ascii=False)
                    except: pass
                    return ret
            return cached if cached else {"messages": [], "count": 0, "perPage": 50, "totalPages": 0}
        except Exception as e:
            _log("ERR", f"get_messages: {e}")
            return cached if cached else {"messages": [], "count": 0, "perPage": 50, "totalPages": 0}

    def send_message(self, target_id, content):
        csrf = self._csrf()
        if not csrf: return False
        url = "https://www.luogu.com.cn/api/chat/new"
        body = {"user": int(target_id), "content": content}
        try:
            headers = self._h({"content-type": "application/json", "referer": "https://www.luogu.com.cn/", "x-csrf-token": csrf})
            r = requests.post(url, headers=headers, data=json.dumps(body), timeout=10)
            _log_res(url, r, "SEND")
            return r.status_code == 200
        except Exception as e:
            _log("SEND", f"ERR: {e}")
            return False

    def delete_message(self, msg_id):
        csrf = self._csrf()
        if not csrf: return False
        try:
            headers = self._h({"content-type": "application/json", "x-csrf-token": csrf, "x-requested-with": "XMLHttpRequest", "referer": "https://www.luogu.com.cn/chat", "origin": "https://www.luogu.com.cn"})
            r = requests.post("https://www.luogu.com.cn/api/chat/delete", headers=headers, data=json.dumps({"id": int(msg_id)}), timeout=10)
            _log_res("https://www.luogu.com.cn/api/chat/delete", r, "DEL")
            return r.status_code == 200
        except Exception as e:
            _log("DEL", f"ERR: {e}")
            return False

    def search_users(self, keyword):
        try:
            r = requests.get(f"https://www.luogu.com.cn/api/user/search?keyword={keyword}",
                headers={"cookie": self._cookie, "user-agent": UA, "referer": "https://www.luogu.com.cn/chat"}, timeout=10)
            if r.status_code == 200:
                d = r.json()
                return d.get("users", []) or []
            return []
        except: return []

    def download_avatar(self, uid, force=False):
        local = os.path.join(AVATAR_DIR, f"{uid}.png")
        if not force and os.path.exists(local) and os.path.getsize(local) > 0: return local
        url = f"https://cdn.luogu.com.cn/upload/usericon/{uid}.png"
        try:
            os.makedirs(AVATAR_DIR, exist_ok=True)
            r = requests.get(url, headers={"user-agent": UA, "referer": "https://www.luogu.com.cn/"}, timeout=10)
            if r.status_code == 200:
                with open(local, "wb") as f: f.write(r.content)
                return local
        except: pass
        return ""


class AIAssistant:
    """AI 助手 — 默认使用智谱 GLM，自定义兼容 OpenAI API"""

    def is_enabled(self):
        return cfg.get("ai.enabled", False)

    def is_custom(self):
        return not cfg.get("ai.default", True)

    def _get_ai_config(self):
        if cfg.get("ai.default", True):
            return DEFAULT_AI_URL, DEFAULT_AI_KEY, DEFAULT_AI_MODEL
        c = cfg.get("ai.custom", {})
        return (
            c.get("base_url", "") or DEFAULT_AI_URL,
            c.get("api_key", ""),
            c.get("model", "") or DEFAULT_AI_MODEL)

    def _chat(self, messages, model=None, log_tag="AI_CHAT"):
        base_url, api_key, model_ = self._get_ai_config()
        model = model or model_
        if not api_key: return ""
        url = f"{base_url.rstrip('/')}/chat/completions"
        try:
            r = requests.post(url, headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                json={"model": model, "messages": messages}, timeout=30)
            if r.status_code == 200:
                resp = r.json()
                choices = resp.get("choices", [])
                reply = choices[0].get("message", {}).get("content", "") if choices else ""
                _log_ai(log_tag, messages, reply)
                return reply
            else:
                _log_ai(log_tag + "_ERR", messages, r.text[:500])
        except Exception as e:
            _log_ai(log_tag + "_EXC", messages, str(e))
        return ""

    def check_importance(self, message, sender_name=""):
        if not self.is_enabled():
            return {"is_important": False, "analysis": "", "tip": ""}
        keyword = cfg.get("ai.important_keyword", "zhl重要信息")
        default_mode = cfg.get("ai.default", True)

        if default_mode:
            # 默认模式：使用内置系统提示词和检测模板（不可修改）
            sys_prompt = DEFAULT_SYSTEM_PROMPT
            q_template = DEFAULT_QUESTION_TEMPLATE
        else:
            # 自定义模式：使用用户自定义的系统提示词和检测模板
            sys_prompt = cfg.get("ai.custom.custom_system_prompt", "") or DEFAULT_SYSTEM_PROMPT
            q_template = cfg.get("ai.question_template", "") or DEFAULT_QUESTION_TEMPLATE

        user_prompt = q_template.replace("{keyword}", keyword)
        if sender_name:
            user_prompt += f"\n以下是要判断的消息（来自 {sender_name}）：{message}"
        else:
            user_prompt += f"\n以下是要判断的消息：{message}"
        # 替换 background 占位符
        bg_cfg = cfg.get("background", {})
        user_prompt = user_prompt.replace("{background}", "" if not bg_cfg.get("enabled") else "(背景功能已启用，但重要性检测暂不注入完整历史)")
        msgs = []
        if sys_prompt.strip(): msgs.append({"role": "system", "content": sys_prompt})
        msgs.append({"role": "user", "content": user_prompt})
        answer = self._chat(msgs, log_tag="IMPORTANCE")
        is_important = keyword in answer
        return {"is_important": is_important, "analysis": answer, "tip": answer if is_important else ""}


class ServerSync:
    def __init__(self):
        self._remaining = 50; self._total = 50; self._allowed = True; self._use_count = 0

    def sync(self):
        if has_super_allow():
            self._remaining = 999; self._total = 999; self._allowed = True
            return {"remaining": 999, "total": 999, "allowed": True}
        url = cfg.get("server.url", "")
        if not url: return {"remaining": 50, "total": 50, "allowed": True}
        uid = cfg.get("luogu.user_id", "")
        if not uid: return {"remaining": 0, "total": 0, "allowed": False}
        try:
            r = requests.post(f"{url.rstrip('/')}/api/sync", json={
                "uid": uid, "device_id": cfg.get("device_id", ""),
                "cookie": cfg.get("luogu.cookie", "")}, timeout=10)
            if r.status_code == 200:
                d = r.json()
                self._remaining = d.get("remaining", 50)
                self._total = d.get("total", 50)
                self._allowed = d.get("allowed", True)
                return d
        except: pass
        return {"remaining": self._remaining, "total": self._total, "allowed": self._allowed}

    def record_use(self, count=1):
        if has_super_allow(): return {"remaining": 999}
        self._use_count += count
        self._remaining = max(0, self._remaining - count)
        url = cfg.get("server.url", "")
        if url:
            try:
                requests.post(f"{url.rstrip('/')}/api/report", json={
                    "uid": cfg.get("luogu.user_id", ""), "count": self._use_count}, timeout=5)
                self._use_count = 0
            except: pass
        return {"remaining": self._remaining}

    def remaining(self): return self._remaining
    def status(self):
        return json.dumps({"remaining": self._remaining, "total": self._total, "allowed": self._allowed})


class WSManager:
    def __init__(self):
        self._ws = None; self._running = False; self._thread = None
        self._ai = AIAssistant()
        self.on_new_message = None
        self.statusChanged = None

    def restart(self):
        self.stop()
        self._running = True
        self._thread = __import__('threading').Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        if self._ws:
            try: self._ws.close()
            except: pass
            self._ws = None

    def _run(self):
        while self._running:
            try:
                cookie = cfg.get("luogu.cookie", "")
                uid = cfg.get("luogu.user_id", "")
                if not cookie or not uid:
                    time.sleep(5)
                    continue
                _log("WS", f"连接 wss://ws.luogu.com.cn/ws | uid={uid}")
                self._ws = ws_lib.WebSocketApp("wss://ws.luogu.com.cn/ws",
                    header={"Cookie": cookie},
                    on_open=self._on_open,
                    on_message=self._on_message,
                    on_error=self._on_error,
                    on_close=self._on_close)
                self._ws.run_forever(ping_interval=30, sslopt={"cert_reqs": ssl.CERT_NONE})
            except Exception as e:
                _log("WS", f"ERR: {e}")
            if self._running:
                delay = min(15, 3 * (1 if not hasattr(self, '_retry_count') else self._retry_count))
                self._retry_count = getattr(self, '_retry_count', 1) + 1
                time.sleep(delay)

    def _on_open(self, ws):
        uid = cfg.get("luogu.user_id", "")
        ws.send(json.dumps({"type": "join_channel", "channel": "chat", "channel_param": str(uid), "exclusive_key": None}))
        _log("WS", f"Connected, uid={uid}")
        self._retry_count = 1
        if self.statusChanged: self.statusChanged.emit("connected")

    def _on_message(self, ws, raw):
        try:
            d = json.loads(raw)
            if d.get('_ws_type') == 'server_broadcast':
                m = d.get('message', {})
                s = m.get('sender', {})
                content = m.get('content', '')
                s_uid = str(s.get('uid', ''))
                s_name = s.get('name', '未知')
                my_uid = cfg.get("luogu.user_id", "")
                if s_uid and s_uid != my_uid:
                    _log("WS", f"<- {s_name}({s_uid}): {_mask(content, 40)}")
                    _log("WS_DBG", f"RAW: {_mask(raw, 200)}")
                    if self.on_new_message:
                        self.on_new_message(s_uid, content, s_name, my_uid, m.get('time', int(time.time())))
        except Exception as e:
            _log("WS", f"parse err: {e}")

    def _on_error(self, ws, error):
        _log("WS", f"err: {error}")
        if self.statusChanged: self.statusChanged.emit("error")

    def _on_close(self, ws, code, reason):
        _log("WS", f"closed: {code} {reason}")
        if self.statusChanged: self.statusChanged.emit("disconnected")


from PySide6.QtCore import (QObject, Signal, Slot, Property, QUrl, Qt, QTimer,
    QThread, QAbstractNativeEventFilter, QFileInfo, QFile)
from PySide6.QtGui import QGuiApplication, QFontDatabase, QFont
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

# 精美弹窗
from popup import GlassPopup

class BackendBridge(QObject):
    loginTestResult = Signal(bool, str, str, str)
    configChanged = Signal()
    wsStatus = Signal(str)
    newMessage = Signal(str, str, str, str, int)
    importantMessage = Signal(str, str, str, str, str, str)
    chatListReady = Signal(str)
    messagesReady = Signal(str, int, bool)
    messagesLoading = Signal(bool)
    searchResult = Signal(str)
    avatarReady = Signal(str, str)
    serverSyncResult = Signal(str)
    replySent = Signal(bool, str)
    autoReplyDone = Signal(str, str, str)  # uid, content, reply
    userProfileReady = Signal(str, str)
    showErrorPopup = Signal(str, str)
    fontReady = Signal(str)
    soundFinished = Signal()

    def __init__(self):
        super().__init__()
        self.luogu = LuoguAPI()
        self.ws = WSManager()
        self._ai = AIAssistant()
        self.ws.statusChanged = self.wsStatus
        self.ws.on_new_message = self._on_ws_message
        self._pool = ThreadPoolExecutor(max_workers=8, thread_name_prefix="luogu")
        self._known_uids = set()
        self._sound_process = None
        self._popup = None  # 延迟初始化（在 QApplication 启动后）

    def _on_ws_message(self, s_uid, content, s_name, my_uid, ts):
        self.newMessage.emit(s_uid, content, s_name, my_uid, ts)
        # AI check
        if cfg.get("ai.enabled", False):
            def _check():
                ai = AIAssistant()
                r = ai.check_importance(content, s_name)
                if r["is_important"]:
                    self.importantMessage.emit(s_uid, content, s_name, my_uid, str(r.get("tip", "")), str(ts))
                    # 显示精美 Python 弹窗
                    if self._popup is None:
                        self._popup = GlassPopup()
                    avatar_url = f"https://cdn.luogu.com.cn/upload/usericon/{s_uid}.png"
                    QTimer.singleShot(0, lambda: self._popup.show_message(
                        s_uid, s_name, content, avatar_url, r.get("tip", "")))
            self._pool.submit(_check)

        # 自动回复检测
        ar_cfg = cfg.get("auto_reply", {})
        if ar_cfg.get("enabled", False):
            ar_keyword = ar_cfg.get("keyword", "Zhl需要回复")
            if ar_keyword in content:
                _log("AUTO_REPLY", f"检测到自动回复关键词, uid={s_uid}")
                def _auto_reply():
                    self._do_auto_reply(s_uid, content, s_name, my_uid, ar_cfg)
                self._pool.submit(_auto_reply)

    def _do_auto_reply(self, target_uid, content, sender_name, my_uid, ar_cfg):
        """执行自动回复：先问 AI 是否需要回复，若需要则生成回复并发送"""
        my_id = cfg.get("luogu.user_id", "")
        is_custom_ai = not cfg.get("ai.default", True)
        if not is_custom_ai and my_id != "1049425":
            _log("AUTO_REPLY", f"非自定义AI且uid非1049425，跳过: uid={my_id}")
            return

        ai = AIAssistant()
        sys_prompt = ar_cfg.get("system_prompt", "")
        bg_text = self._get_background(target_uid)

        # Step 1: 问 AI 是否需要回复
        check_q = ar_cfg.get("check_question", "")
        if not check_q:
            check_q = "以下是一条消息，请判断是否需要回复。如果不需要回复请回复「不需要」，如果需要请回复「需要」：\n{message}"
        check_question = check_q.replace("{message}", content).replace("{background}", bg_text)
        msgs1 = []
        if sys_prompt.strip():
            msgs1.append({"role": "system", "content": sys_prompt})
        msgs1.append({"role": "user", "content": check_question})

        _log("AUTO_REPLY", "Step1: 判断是否需要回复...")
        check_result = ai._chat(msgs1, log_tag="AUTO_CHECK")
        if not check_result or "不需要" in check_result and "需要" not in check_result.replace("不需要", ""):
            _log("AUTO_REPLY", f"AI判断不需要回复: {check_result[:80] if check_result else 'empty'}")
            return

        # Step 2: 生成回复
        q_template = ar_cfg.get("question_template", "")
        question = q_template.replace("{message}", content).replace("{background}", bg_text)
        msgs2 = []
        if sys_prompt.strip():
            msgs2.append({"role": "system", "content": sys_prompt})
        msgs2.append({"role": "user", "content": question})

        _log("AUTO_REPLY", "Step2: 生成回复中...")
        reply = ai._chat(msgs2, log_tag="AUTO_REPLY")
        if reply and reply.strip():
            _log("AUTO_REPLY", f"AI回复: {reply[:80]}")
            ok = self.luogu.send_message(target_uid, reply.strip())
            if ok:
                self.replySent.emit(True, "")
                self.autoReplyDone.emit(target_uid, content, reply.strip())
                _log("AUTO_REPLY", f"回复已发送 -> {target_uid}")
            else:
                _log("AUTO_REPLY", "发送失败")
                self.replySent.emit(False, "自动回复发送失败")
        else:
            _log("AUTO_REPLY", "AI未生成回复")

    def _format_msg(self, m, my_uid):
        """格式化单条消息为一行文本（不含换行）"""
        sender = m.get("sender", {})
        sname = sender.get("name", "?")
        suid = str(sender.get("uid", ""))
        mc = m.get("content", "")
        return f"[{sname}]: {mc}" if suid != my_uid else f"[我]: {mc}"

    def _trim_msgs(self, msgs, max_msgs, max_chars, my_uid):
        """从消息列表末尾（最新）向前取，直到达到条数或字符数限制"""
        lines = []
        total_chars = 0
        for m in reversed(msgs):
            line = self._format_msg(m, my_uid)
            if len(lines) >= max_msgs or total_chars + len(line) > max_chars:
                break
            lines.append(line)
            total_chars += len(line)
        lines.reverse()  # 恢复时间正序
        return lines, total_chars

    def _get_background(self, uid):
        """获取聊天背景上下文。

        模式:
          conversation — 仅使用当前已缓存的对话记录，不额外请求
          recent      — 从最新页开始逐页向洛谷请求更早记录，直到达到限制或第一页
                       请求间隔 0.8s；每页结果独立缓存到 data/ 目录。"""
        bg_cfg = cfg.get("background", {})
        if not bg_cfg.get("enabled", False):
            return ""
        try:
            bg_mode = bg_cfg.get("mode", "conversation")
            max_msgs = bg_cfg.get("max_messages", 20)
            max_chars = bg_cfg.get("max_chars", 2000)
            suffix = bg_cfg.get("suffix", "")
            my_uid = cfg.get("luogu.user_id", "")

            if bg_mode == "conversation":
                # 当前对话：仅用缓存的最新一页
                data = self.luogu.get_messages(uid)
                msgs = data.get("messages", [])
                if not msgs:
                    return ""
                recent_lines, total_chars = self._trim_msgs(msgs, max_msgs, max_chars, my_uid)
                _log("BG", f"[当前对话] {len(recent_lines)}条/{total_chars}字 uid={uid}")
            else:
                # 最近所有：逐页向洛谷请求直到达到限制或第一页
                all_msgs = []       # 时间正序（旧→新），跨页
                total_pages = None
                page = 0

                while True:
                    data = self.luogu.get_messages(uid, page if page > 0 else None)
                    msgs = data.get("messages", [])
                    if not msgs:
                        break

                    if total_pages is None:
                        total_pages = data.get("totalPages", 1)

                    all_msgs = msgs + all_msgs
                    _log("BG", f"[最近所有] 已拉取第{page}页({len(msgs)}条) uid={uid}，累计{len(all_msgs)}条")

                    current_chars = sum(len(self._format_msg(m, my_uid)) for m in all_msgs)
                    if len(all_msgs) >= max_msgs or current_chars >= max_chars:
                        _log("BG", f"[最近所有] 已达限制: {len(all_msgs)}条/{current_chars}字")
                        break
                    if total_pages is not None and page + 1 >= total_pages:
                        _log("BG", f"[最近所有] 已到末页({total_pages}页)")
                        break
                    page += 1
                    time.sleep(0.8)

                if not all_msgs:
                    return ""
                recent_lines, total_chars = self._trim_msgs(all_msgs, max_msgs, max_chars, my_uid)
                _log("BG", f"[最近所有] 最终: {len(recent_lines)}条/{total_chars}字 uid={uid}")

            lines = ["以下是最近的聊天记录："] + recent_lines
            result = "\n".join(lines)
            if suffix.strip():
                result += "\n" + suffix.strip()
            return result
        except Exception as e:
            _log("BG", f"获取背景失败: {e}")
            return ""

    @Slot(result=str)
    def getConfig(self):
        return json.dumps(cfg.all(), ensure_ascii=False)

    @Slot(str)
    def saveConfig(self, json_str):
        try:
            data = json.loads(json_str)
            # Cookie normalization
            raw_c = data.get("luogu", {}).get("cookie", "")
            raw_u = data.get("luogu", {}).get("user_id", "")
            if raw_c or raw_u:
                normalized = normalize_cookie(raw_c, raw_u)
                data["luogu"]["cookie"] = normalized
                m = re.search(r'_uid=(\d+)', normalized)
                if m:
                    data["luogu"]["user_id"] = m.group(1)
            cfg.update_all(data)
            if data.get("server", {}).get("url"):
                server.sync()
            self.configChanged.emit()
            _log("CFG", "配置已保存")
        except Exception as e:
            _log("CFG", f"save error: {e}")

    @Slot(str, str)
    def testLogin(self, uid, cookie):
        uid, cookie = (uid or "").strip(), (cookie or "").strip()
        if not cookie and not uid:
            self.loginTestResult.emit(False, "", "", "请输入 UID 和 Cookie")
            return
        full = normalize_cookie(cookie, uid)
        m = re.search(r'_uid=(\d+)', full)
        uid = m.group(1) if m else uid
        if not uid:
            self.loginTestResult.emit(False, uid, "", "无法获取UID，请检查输入")
            return
        def _do():
            tmp = LuoguAPI()
            tmp._cookie = full; tmp._uid = uid
            ok, rid, name, err = tmp.test_login()
            if ok:
                cfg.set("luogu.cookie", tmp._cookie)
                cfg.set("luogu.user_id", rid or uid)
                self.luogu = LuoguAPI()
                self.ws.restart()
                self.loginTestResult.emit(True, rid or uid, name, "")
            else:
                self.loginTestResult.emit(False, uid, "", err or "Cookie无效")
        self._pool.submit(_do)

    @Slot(result=bool)
    def hasSuperAllow(self):
        return has_super_allow()

    @Slot(result=str)
    def getFontList(self):
        """获取系统字体列表"""
        try:
            fonts = QFontDatabase.families()
            return json.dumps(fonts, ensure_ascii=False)
        except: return "[]"

    @Slot(str, str)
    def sendMessage(self, target_uid, content):
        if not target_uid or not content:
            self.replySent.emit(False, "参数不完整")
            return
        def _do():
            try:
                ok = self.luogu.send_message(target_uid, content)
                self.replySent.emit(ok, "" if ok else "发送失败")
            except Exception as e:
                _log("SEND", f"error: {e}")
                self.replySent.emit(False, f"发送失败: {str(e)[:50]}")
                self.showErrorPopup.emit(f"发送失败: {str(e)[:100]}", f"send_{target_uid}")
        self._pool.submit(_do)

    @Slot()
    def refreshChatList(self):
        def _do():
            try:
                data = self.luogu.get_chat_list()
                self.chatListReady.emit(json.dumps(data, ensure_ascii=False))
                _log("BRIDGE", f"chatList: {len(data)}")
            except Exception as e:
                _log("BRIDGE", f"chatList err: {e}")
                self.showErrorPopup.emit(f"刷新失败: {e}", "refresh")
        self._pool.submit(_do)

    @Slot()
    def autoLogin(self):
        if self.luogu._cookie and self.luogu._uid:
            _log("AUTO", "自动登录...")
            def _do():
                if self.luogu.ensure_c3vk():
                    self.luogu = LuoguAPI()
                    self.ws.restart()
                    self.loginTestResult.emit(True, self.luogu._uid, "", "")
            self._pool.submit(_do)

    @Slot(result=str)
    def getChatList(self):
        cl_cache = os.path.join(CACHE_DIR, "_chat_list.json")
        if os.path.exists(cl_cache):
            try:
                with open(cl_cache, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return json.dumps(data, ensure_ascii=False)
            except: pass
        return "[]"

    @Slot(str, int)
    def getMessages(self, target_uid, page=-1):
        key = 0 if page < 0 else page
        cache_file = os.path.join(CACHE_DIR, f"msg_{target_uid}_{key}.json")
        if os.path.exists(cache_file) and page < 0:
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                msgs = cached.get("messages", [])
                tp = cached.get("totalPages", 1)
                result = json.dumps({"messages": msgs, "count": len(msgs), "totalPages": tp, "cached": True}, ensure_ascii=False)
                self.messagesReady.emit(result, page, tp > 1)
            except: pass
        self.messagesLoading.emit(True)
        def _do():
            try:
                p = None if page < 0 else page
                data = self.luogu.get_messages(target_uid, p)
                msgs = data.get("messages", [])
                tp = data.get("totalPages", 1)
                result = json.dumps({"messages": msgs, "count": data.get("count", 0), "totalPages": tp, "cached": False}, ensure_ascii=False)
                self.messagesReady.emit(result, page, tp > 1 and page < tp - 1)
            except Exception as e:
                _log("BRIDGE", f"getMessages err: {e}")
                self.showErrorPopup.emit(f"获取消息失败: {e}", f"msg_{target_uid}_{page}")
            finally:
                self.messagesLoading.emit(False)
        self._pool.submit(_do)

    @Slot(str)
    def requestAvatar(self, uid):
        """单人头像下载（点击对话时调用，强制刷新）"""
        def _do():
            local = self.luogu.download_avatar(uid, force=True)
            if local: self.avatarReady.emit(uid, local.replace("\\", "/"))
        self._pool.submit(_do)

    @Slot(str)
    def prefetchAvatars(self, uid_list_json):
        """批量预取头像（列表加载后调用），逐个下载并推送缓存"""
        try:
            uid_list = json.loads(uid_list_json)
        except:
            return
        if not uid_list:
            return
        def _do():
            for uid in uid_list:
                local = self.luogu.download_avatar(uid)
                if local:
                    self.avatarReady.emit(uid, local.replace("\\", "/"))
        self._pool.submit(_do)

    @Slot(str, result=str)
    def searchUsers(self, keyword):
        try: return json.dumps(self.luogu.search_users(keyword), ensure_ascii=False)
        except: return "[]"

    @Slot(result=str)
    def syncNow(self):
        r = server.sync()
        return json.dumps(r)

    @Slot(result=str)
    def getServerStatus(self):
        return server.status()

    @Slot(str, result=bool)
    def deleteMessage(self, msg_id):
        return self.luogu.delete_message(msg_id)

    @Slot(str)
    def copyText(self, text):
        QGuiApplication.clipboard().setText(text)

    @Slot(str)
    def playSound(self, file_path):
        """播放 MP3 提示音"""
        try:
            from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
            from PySide6.QtCore import QUrl
            self._player = QMediaPlayer()
            self._audio_out = QAudioOutput()
            self._player.setAudioOutput(self._audio_out)
            self._player.setSource(QUrl.fromLocalFile(file_path))
            self._audio_out.setVolume(0.8)
            self._player.play()
        except Exception as e:
            _log("SOUND", f"play error: {e}")

    @Slot(result=str)
    def getAvatarPath(self, uid):
        local = os.path.join(AVATAR_DIR, f"{uid}.png")
        if os.path.exists(local) and os.path.getsize(local) > 0:
            return local.replace("\\", "/")
        return ""

    @Slot()
    def startWS(self):
        self.ws.restart()

    @Slot(str, str)
    def setCookieFormat(self, uid, client_id):
        """将 UID 和 client_id 格式化为标准 cookie"""
        cookie = f"_uid={uid}; __client_id={client_id}"
        cfg.set("luogu.cookie", cookie)
        cfg.set("luogu.user_id", uid)
        self.luogu = LuoguAPI()
        return cookie

    @Slot()
    def refreshC3VK(self):
        def _do():
            ok = self.luogu.ensure_c3vk()
            if ok:
                self.luogu = LuoguAPI()
                self.configChanged.emit()
        self._pool.submit(_do)


class WindowEventFilter(QAbstractNativeEventFilter):
    def __init__(self, hwnd, border=7):
        super().__init__()
        self._hwnd = hwnd
        self._b = border
    def nativeEventFilter(self, event_type, message):
        if event_type != b"windows_generic_MSG": return False, 0
        import ctypes
        from ctypes import wintypes
        msg = ctypes.cast(message.__int__(), ctypes.POINTER(wintypes.MSG)).contents
        if msg.message == 0x0083: return True, 0
        if msg.message == 0x0084:
            x = msg.lParam & 0xFFFF
            y = (msg.lParam >> 16) & 0xFFFF
            user32 = ctypes.windll.user32
            r = wintypes.RECT()
            user32.GetWindowRect(self._hwnd, ctypes.byref(r))
            l, rt = x - r.left, r.right - x
            t, b = y - r.top, r.bottom - y
            if l < self._b and t < self._b: hit = 13
            elif rt < self._b and t < self._b: hit = 14
            elif l < self._b and b < self._b: hit = 16
            elif rt < self._b and b < self._b: hit = 17
            elif l < self._b: hit = 10
            elif rt < self._b: hit = 11
            elif t < self._b: hit = 12
            elif b < self._b: hit = 15
            else: hit = 1
            if hit != 1: return True, hit
        return False, 0


server = ServerSync()

def main():
    QApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    app = QApplication(sys.argv)

    engine = QQmlApplicationEngine()
    bridge = BackendBridge()
    engine.rootContext().setContextProperty("bridge", bridge)

    qml_path = os.path.join(BASE_DIR, "main.qml")
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        _log("FATAL", "QML failed to load!")
        sys.exit(1)

    _log("QML", f"QML loaded: {qml_path}")
    _log("APP", f"Super allow: {has_super_allow()}")

    root_objects = engine.rootObjects()
    if root_objects:
        win = root_objects[0]
        win.show()
        from PySide6.QtGui import QWindow
        if isinstance(win, QWindow):
            hwnd = int(win.winId())
            app.installNativeEventFilter(WindowEventFilter(hwnd))

    bridge.autoLogin()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
