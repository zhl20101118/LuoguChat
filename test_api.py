# -*- coding: utf-8 -*-
"""测试洛谷 API — 严格对齐 chat.py"""

import requests
import re
import json

COOKIE = "_uid=1049425; __client_id=ykj3u4a6aa6cozdlejsttrkawtvdegredlu6ehm3dimnqci5"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
UID = "1049425"

print("=" * 60)
print("1. 测试首页 — 获取 CSRF (处理 C3VK 反爬)")
print("=" * 60)

# Step 1: fetch homepage
r = requests.get("https://www.luogu.com.cn/",
    headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
print(f"首页首次: {r.status_code} {len(r.text)}B")

# C3VK 检测
c3vk = re.search(r'C3VK=([^;"]+)', r.text)
if c3vk:
    cv = c3vk.group(1)
    print(f"检测到 C3VK={cv}, 重试...")
    COOKIE += f"; C3VK={cv}"
    r = requests.get("https://www.luogu.com.cn/",
        headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
    print(f"首页重试: {r.status_code} {len(r.text)}B")

csrf = re.search(r'<meta name="csrf-token" content="([^"]+)"', r.text)
if csrf:
    token = csrf.group(1)
    print(f"CSRF: {token[:30]}...")
else:
    print("CSRF NOT FOUND!")
    exit(1)

print()
print("=" * 60)
print("2. 测试聊天记录 API")
print("=" * 60)

# 对齐 chat.py get_message()
headers = {
    "user-agent": UA,
    "cookie": COOKIE,
    "referer": "https://www.luogu.com.cn/chat"
}

url = f"https://www.luogu.com.cn/api/chat/record?user={UID}"
print(f"GET {url}")
print(f"Headers: {json.dumps(headers, ensure_ascii=False)}")

r2 = requests.get(url, headers=headers, timeout=10)
print(f"Response: {r2.status_code} {len(r2.text)}B")
print(f"Body[:500]: {r2.text[:500]}")

if r2.status_code == 200:
    try:
        data = r2.json()
        msgs = data.get("messages", {})
        if isinstance(msgs, dict):
            result = msgs.get("result", [])
            count = msgs.get("count", 0)
            print(f"\n消息数: {len(result)} / 总数: {count}")
            for i, m in enumerate(result[-5:]):
                s = m.get("sender", {})
                print(f"  [{i}] {s.get('name','?')}({s.get('uid','?')}): {m.get('content','')[:60]}")
        else:
            print(f"messages 不是 dict: {type(msgs)}")
    except Exception as e:
        print(f"JSON 解析失败: {e}")
        print(f"完整 body: {r2.text}")

print()
print("=" * 60)
print("3. 测试其他用户的聊天记录 (uid=2 测试)")
print("=" * 60)

url3 = "https://www.luogu.com.cn/api/chat/record?user=2"
print(f"GET {url3}")
r3 = requests.get(url3, headers=headers, timeout=10)
print(f"Response: {r3.status_code} {len(r3.text)}B")
if r3.status_code == 200:
    try:
        data = r3.json()
        msgs = data.get("messages", {})
        if isinstance(msgs, dict):
            result = msgs.get("result", [])
            print(f"消息数: {len(result)}")
    except:
        print(f"JSON parse error: {r3.text[:200]}")
else:
    print(f"Body: {r3.text[:300]}")

print()
print("=" * 60)
print("4. 测试用户页提取用户名")
print("=" * 60)

url4 = f"https://www.luogu.com.cn/user/{UID}"
print(f"GET {url4}")
r4 = requests.get(url4,
    headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
print(f"Response: {r4.status_code} {len(r4.text)}B")

# 方式1: 从 lentille-context JSON 提取
nm_json = re.search(r'"name":"([^"]+)"', r4.text)
# 方式2: 从 title 提取 (格式: "用户名 - 洛谷" 或 "用户名(...)")
nm_title = re.search(r'<title>([^<\-(]+)', r4.text)

print(f"JSON name: {nm_json.group(1) if nm_json else 'NOT FOUND'}")
print(f"Title name: {nm_title.group(1).strip() if nm_title else 'NOT FOUND'}")

print()
print("=" * 60)
print("5. 测试获取聊天列表 (从 /chat 页)")
print("=" * 60)

url5 = "https://www.luogu.com.cn/chat"
print(f"GET {url5}")
r5 = requests.get(url5,
    headers={"user-agent": UA, "cookie": COOKIE, "referer": "https://www.luogu.com.cn/chat"}, timeout=10)
print(f"Response: {r5.status_code} {len(r5.text)}B")

# 查找各种可能的数据注入方式
for pat in [r'__INITIAL_STATE__\s*=\s*({.*?});', r'"chats"\s*:\s*(\[.*?\])',
            r'window\.__CHAT_DATA__\s*=\s*({.*?});', r'"chatList"\s*:\s*(\[.*?\])',
            r'lentille-context.*?"chat' ]:
    m = re.search(pat, r5.text, re.DOTALL)
    if m:
        print(f"MATCH: {pat[:50]}... at pos {r5.text.find(m.group(0)[:20])}")
        print(f"Data: {m.group(0)[:200]}")
    else:
        print(f"NO MATCH: {pat[:50]}...")

# Find all script or JSON-like blocks
print("\n查找所有 script[id] 标签:")
for m in re.finditer(r'<script[^>]*id="([^"]+)"[^>]*>', r5.text):
    sid = m.group(1)
    end = r5.text.find('</script>', m.end())
    content = r5.text[m.end():end] if end > 0 else ""
    print(f"  id={sid} len={len(content)} preview={content[:80]}")

print("\n查找 _feInjection:")
idx = r5.text.find('_feInjection')
print(f"  _feInjection 位置: {idx}")
if idx >= 0:
    print(f"  上下文: {r5.text[max(0,idx-20):idx+200]}")

print("\n搜索 JSON 中的 chat 相关字段:")
for pat in ['"chat"', '"recentChats"', '"contacts"', '"conversations"', '"chatList"', '"msgList"']:
    for m in re.finditer(pat, r5.text):
        start = max(0, m.start() - 10)
        print(f"  {pat} at {m.start()}: ...{r5.text[start:m.end()+80]}...")

print("\n查找 _feConfigVersion 之后的内容:")
idx2 = r5.text.find('__feConfigVersion')
if idx2 >= 0:
    print(f"  {r5.text[idx2:idx2+500]}")

print("\n" + "=" * 60)
print("6. 修复用户名提取")
print("=" * 60)

# 从用户页正确提取: 找 "uid":1049425 后面的 "name":"xxx"
uid_pat = f'"uid":{UID}'
idx3 = r4.text.find(uid_pat)
if idx3 >= 0:
    # 在 uid 附近找 name
    snippet = r4.text[idx3:idx3+200]
    print(f"uid 附近: {snippet}")
    nm = re.search(r'"name":"([^"]+)"', snippet)
    if nm:
        print(f"用户名(uid附近): {nm.group(1)}")

# 从 lentille-context 的 user 对象中提取
sc = re.search(r'<script id="lentille-context"[^>]*>(.*?)</script>', r4.text, re.DOTALL)
if sc:
    try:
        jd = json.loads(sc.group(1))
        user = jd.get("data", {}).get("user", {})
        print(f"lentille-context user: name={user.get('name')} uid={user.get('uid')}")
    except Exception as e:
        print(f"JSON parse error: {e}")
        print(f"Content[:200]: {sc.group(1)[:200]}")

print("\n" + "=" * 60)
print("测试完成")
