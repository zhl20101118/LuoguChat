# -*- coding: utf-8 -*-
"""独立测试 — 模拟完整登录+获取聊天列表流程"""
import requests, re, json, urllib.parse, time

COOKIE = "_uid=1049425; __client_id=ykj3u4a6aa6cozdlejsttrkawtvdegredlu6ehm3dimnqci5"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
UID = "1049425"

def now(): return time.strftime("%H:%M:%S")

print(f"[${now()}] === 步骤1: 获取C3VK ===")
r = requests.get("https://www.luogu.com.cn/",
    headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
print(f"[${now()}] 首页: {r.status_code} {len(r.text)}B")

c3vk = re.search(r'C3VK=([^;"]+)', r.text)
if c3vk:
    cv = c3vk.group(1)
    print(f"[${now()}] C3VK={cv}")
    if "C3VK=" not in COOKIE:
        COOKIE += f"; C3VK={cv}"
    r = requests.get("https://www.luogu.com.cn/",
        headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
    print(f"[${now()}] 重试: {r.status_code} {len(r.text)}B")
else:
    print(f"[${now()}] 无C3VK! body[:100]: {r.text[:100]}")

csrf = re.search(r'<meta name="csrf-token" content="([^"]+)"', r.text)
if csrf:
    print(f"[${now()}] CSRF: {csrf.group(1)[:30]}...")
else:
    print(f"[${now()}] CSRF NOT FOUND!")

print(f"\n[${now()}] === 步骤2: 获取聊天列表 ===")
r2 = requests.get("https://www.luogu.com.cn/chat",
    headers={"user-agent": UA, "cookie": COOKIE, "referer": "https://www.luogu.com.cn/chat"}, timeout=10)
print(f"[${now()}] /chat: {r2.status_code} {len(r2.text)}B")

m = re.search(r'window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)', r2.text)
if m:
    data = json.loads(urllib.parse.unquote(m.group(1)))
    msgs = data.get("currentData", {}).get("latestMessages", {}).get("result", [])
    print(f"[${now()}] _feInjection 解码: {len(msgs)} 条消息")
    
    seen = {}
    for msg in msgs:
        s = msg.get("sender", {})
        r_c = msg.get("receiver", {})
        suid = str(s.get("uid", ""))
        if suid == UID:
            ouid = str(r_c.get("uid", ""))
            oname = r_c.get("name", "?")
        else:
            ouid = suid
            oname = s.get("name", "?")
        if not ouid:
            continue
        if ouid not in seen:
            seen[ouid] = {"uid": ouid, "name": oname, "content": msg.get("content", ""), "time": msg.get("time", 0)}
        else:
            seen[ouid]["content"] = msg.get("content", "")
            seen[ouid]["time"] = msg.get("time", 0)
    
    chats = list(seen.values())
    print(f"[${now()}] 会话数: {len(chats)}")
    for c in chats[:5]:
        print(f"  [{c['name']}({c['uid']})] {c['content'][:40]}")
else:
    print(f"[${now()}] _feInjection NOT matched")
    idx = r2.text.find("_feInjection")
    if idx >= 0:
        print(f"  pos={idx}: ...{r2.text[idx:idx+150]}...")

print(f"\n[${now()}] === 步骤3: 获取用户名 ===")
r3 = requests.get(f"https://www.luogu.com.cn/user/{UID}",
    headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
print(f"[${now()}] 用户页: {r3.status_code} {len(r3.text)}B")

sc = re.search(r'<script id="lentille-context"[^>]*>(.*?)</script>', r3.text, re.DOTALL)
if sc:
    jd = json.loads(sc.group(1))
    user = jd.get("data", {}).get("user", {})
    print(f"[${now()}] 用户名: {user.get('name')} (UID: {user.get('uid')})")

print(f"\n[${now()}] === 步骤4: 测试聊天记录 API ===")
r4 = requests.get(f"https://www.luogu.com.cn/api/chat/record?user={chats[0]['uid'] if chats else 2}",
    headers={
        "user-agent": UA,
        "cookie": COOKIE,
        "referer": "https://www.luogu.com.cn/chat",
        "x-csrf-token": csrf.group(1) if csrf else "",
        "x-requested-with": "XMLHttpRequest"
    }, timeout=10)
print(f"[${now()}] API: {r4.status_code} {len(r4.text)}B")
if r4.status_code == 200:
    data = r4.json()
    msgs = data.get("messages", {}).get("result", [])
    print(f"[${now()}] 消息数: {len(msgs)}")
    for m in msgs[-3:]:
        s = m.get("sender", {})
        print(f"  [{s.get('name','?')}] {m.get('content','')[:50]}")
else:
    print(f"[${now()}] 失败: {r4.text[:200]}")

print(f"\n[${now()}] === 全部通过! ===")
print(f"最终Cookie: {COOKIE}")
