"""
研究洛谷聊天 API 响应格式
- 时间格式
- 消息排序
- 数据结构
"""
import json, os, sys, time
import requests

# 读取配置
cfg_path = os.path.join(os.path.dirname(__file__), "config.json")
if os.path.exists(cfg_path):
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
else:
    print("ERROR: config.json not found")
    sys.exit(1)

cookie = cfg.get("luogu", {}).get("cookie", "")
uid = cfg.get("luogu", {}).get("user_id", "")
if not cookie or not uid:
    print("ERROR: no cookie/uid in config.json")
    sys.exit(1)

print(f"当前用户 UID: {uid}")
print(f"Cookie 长度: {len(cookie)}")
print()

# 搜索要测试的用户或使用配置中缓存的聊天对象
# 先试 test_login
def test_login():
    url = "https://www.luogu.com.cn/chat"
    headers = {
        "cookie": cookie,
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "referer": "https://www.luogu.com.cn/"
    }
    r = requests.get(url, headers=headers, timeout=10)
    print(f"[Login] GET /chat -> {r.status_code}")
    if r.status_code != 200:
        print(f"  Body: {r.text[:300]}")
        return False
    return True

def get_chat_list():
    """从 /chat 页面提取聊天列表"""
    import re
    url = "https://www.luogu.com.cn/chat"
    headers = {
        "cookie": cookie,
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "referer": "https://www.luogu.com.cn/"
    }
    r = requests.get(url, headers=headers, timeout=10)
    print(f"[ChatList] GET /chat -> {r.status_code}")
    match = re.search(r'window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)', r.text)
    if match:
        raw = match.group(1)
        from urllib.parse import unquote
        decoded = unquote(raw)
        data = json.loads(decoded)
        msgs = data.get("currentData", {}).get("latestMessages", {}).get("result", [])
        print(f"[ChatList] 找到 {len(msgs)} 条最近消息")
        # 聚合
        users = {}
        for m in msgs:
            s = m.get("sender", {})
            r_ = m.get("receiver", {})
            suid = str(s.get("uid", ""))
            ruid = str(r_.get("uid", ""))
            other = suid if ruid == uid else ruid
            if other not in users or m.get("time", 0) > users[other].get("time", 0):
                users[other] = {
                    "uid": other,
                    "name": s.get("name") if suid == other else r_.get("name"),
                    "time": m.get("time"),
                    "content": m.get("content", "")[:50]
                }
        for u in list(users.values())[:5]:
            print(f"  uid={u['uid']} name={u['name']} time={u['time']} content={u['content'][:30]}")
        return list(users.keys())
    return []

def get_csrf():
    """获取 CSRF token"""
    url = "https://www.luogu.com.cn/api/chat/record?user=1&page=1"
    headers = {
        "cookie": cookie,
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "referer": "https://www.luogu.com.cn/chat"
    }
    r = requests.get(url, headers=headers, timeout=10)
    
    # extract C3VK from Set-Cookie
    c3vk = None
    for h in r.headers.get_all("Set-Cookie") if hasattr(r.headers, 'get_all') else r.headers.get("Set-Cookie", "").split(","):
        if "C3VK" in str(h):
            import re
            m = re.search(r'C3VK=([^;]+)', str(h))
            if m:
                c3vk = m.group(1)
                print(f"[CSRF] 获取到 C3VK: {c3vk}")
    
    # extract x-csrf-token from response
    # CSRF is typically embedded in the page or returned as header
    # Try reading the response
    try:
        data = r.json()
        print(f"[CSRF] response keys: {list(data.keys())}")
    except:
        print(f"[CSRF] raw response: {r.text[:200]}")
    
    return c3vk

def get_messages(target_uid, page=1):
    """获取聊天记录，检查原始时间格式"""
    url = f"https://www.luogu.com.cn/api/chat/record?user={target_uid}&page={page}"
    headers = {
        "cookie": cookie,
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "referer": "https://www.luogu.com.cn/chat",
        "x-requested-with": "XMLHttpRequest"
    }
    r = requests.get(url, headers=headers, timeout=10)
    print(f"[Messages] GET {url} -> {r.status_code}")
    
    if r.status_code == 200:
        data = r.json()
        print(f"[Messages] Top-level keys: {list(data.keys())}")
        
        msgs_wrapper = data.get("messages", {})
        if isinstance(msgs_wrapper, dict):
            result = msgs_wrapper.get("result", [])
            count = msgs_wrapper.get("count", len(result))
            print(f"[Messages] count={count}, result length={len(result)}")
            
            if result:
                print(f"\n--- 原始消息 (API 返回, 前5条) ---")
                for i, m in enumerate(result[:5]):
                    print(f"  [{i}] id={m.get('id')} sender={m.get('sender',{}).get('name','?')}({m.get('sender',{}).get('uid','?')}) "
                          f"time={m.get('time')} type={type(m.get('time')).__name__}")
                    print(f"       content: {m.get('content','')[:60]}")
                    print(f"       status={m.get('status')}")
                
                print(f"\n--- 时间分析 ---")
                times = [m.get('time') for m in result]
                print(f"  时间范围: {min(times)} ~ {max(times)}")
                print(f"  时间类型: {type(times[0]).__name__}")
                
                # 检查是否是 Unix 时间戳（秒）
                if isinstance(times[0], (int, float)):
                    t = times[-1]  # 最后一个（最旧的）
                    if t > 1e9 and t < 2e9:
                        print(f"  → 这是 Unix 时间戳（秒）")
                        import datetime
                        for t in times[:3]:
                            dt = datetime.datetime.fromtimestamp(t)
                            print(f"    {t} → {dt.strftime('%Y-%m-%d %H:%M:%S')}")
                    elif t > 1e12:
                        print(f"  → 这是 Unix 时间戳（毫秒）")
                
                print(f"\n--- 排序检查 ---")
                for i in range(min(3, len(result)-1)):
                    d = result[i+1].get('time', 0) - result[i].get('time', 0)
                    print(f"  [{i}]→[{i+1}] delta={d} ({'新→旧' if d >= 0 else '旧→新'})")
                
                # 保存原始数据
                cache_dir = os.path.join(os.path.dirname(__file__), "data")
                os.makedirs(cache_dir, exist_ok=True)
                debug_file = os.path.join(cache_dir, f"debug_msg_{target_uid}_{page}.json")
                with open(debug_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"\n  原始数据已保存到: {debug_file}")
            else:
                print(f"[Messages] result 为空")
        else:
            print(f"[Messages] messages 不是 dict: {type(msgs_wrapper)}")
            print(f"  data keys: {list(data.keys())[:10]}")
    else:
        print(f"[Messages] 状态码 {r.status_code}: {r.text[:300]}")

if __name__ == "__main__":
    print("=" * 60)
    print(" 洛谷聊天 API 研究")
    print("=" * 60)
    print()
    
    # 1. 测试登录
    print("[1] 测试登录状态...")
    if not test_login():
        print("登录失败，请检查 cookie")
        sys.exit(1)
    print()
    
    # 2. 获取聊天列表
    print("[2] 获取聊天列表...")
    users = get_chat_list()
    if not users:
        print("没有找到聊天对象")
        sys.exit(1)
    print()
    
    # 3. 获取第一个用户的消息
    target = users[0]
    print(f"[3] 获取 uid={target} 的消息 page=1...")
    get_messages(target, 1)
    
    if len(users) > 1:
        print()
        target2 = users[1]
        print(f"[4] 获取 uid={target2} 的消息 page=1...")
        get_messages(target2, 1)
    
    print()
    print("=" * 60)
    print(" 完成")
    print("=" * 60)
