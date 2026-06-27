# -*- coding: utf-8 -*-
"""获取 C3VK token 并生成 curl 命令"""
import requests, re, sys

COOKIE = "_uid=1049425; __client_id=ykj3u4a6aa6cozdlejsttrkawtvdegredlu6ehm3dimnqci5"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

print("=== 获取 C3VK token ===")

# 请求首页, 获取反爬脚本中的 C3VK
r = requests.get("https://www.luogu.com.cn/",
    headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
print(f"首页: {r.status_code} {len(r.text)}B")

c3vk = re.search(r'C3VK=([^;"]+)', r.text)
if c3vk:
    token = c3vk.group(1)
    print(f"C3VK token: {token}")
    # 替换旧 C3VK
    COOKIE = re.sub(r';?\s*C3VK=[^;]*', '', COOKIE).strip(';').strip()
    COOKIE += f"; C3VK={token}"
    
    # 用新 token 重试请求首页获取完整页面
    r2 = requests.get("https://www.luogu.com.cn/",
        headers={"user-agent": UA, "cookie": COOKIE}, timeout=10)
    print(f"重试: {r2.status_code} {len(r2.text)}B")
    
    # 从完整页面提取 CSRF token
    csrf = re.search(r'<meta name="csrf-token" content="([^"]+)"', r2.text)
    if csrf:
        print(f"CSRF: {csrf.group(1)[:30]}...")
    
    # 也打印 set-cookie 看有没有 nextversion
    for k, v in r2.headers.items():
        if k.lower() == 'set-cookie':
            print(f"Set-Cookie: {v[:80]}...")
else:
    print("未找到 C3VK! 检查反爬脚本:")
    print(r.text)
    sys.exit(1)

print()
print("=== 生成 curl 命令 ===")
print()

# 备份当前 C3VK 到 cookie 变量
curl_cookie = f"_uid=1049425; __client_id=ykj3u4a6aa6cozdlejsttrkawtvdegredlu6ehm3dimnqci5; C3VK={token}"

print(f"# C3VK={token}")
print(f'curl "https://www.luogu.com.cn/chat" \\')
print(f'  -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9" \\')
print(f'  -b "{curl_cookie}" \\')
print(f'  -H "referer: https://www.luogu.com.cn/chat" \\')
print(f'  -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"')

print()
print(f"# 聊天记录 API (需要 CSRF token)")
if csrf:
    print(f'curl "https://www.luogu.com.cn/api/chat/record?user=1059683" \\')
    print(f'  -b "{curl_cookie}" \\')
    print(f'  -H "referer: https://www.luogu.com.cn/chat" \\')
    print(f'  -H "x-csrf-token: {csrf.group(1)}" \\')
    print(f'  -H "x-requested-with: XMLHttpRequest" \\')
    print(f'  -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"')
