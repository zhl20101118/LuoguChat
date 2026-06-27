"""
获取与指定用户的所有私信记录，按从旧到新排列，存到 {uid}.txt
用法: python get_record.py <uid>
"""
import json, os, sys, re, math
import requests
from datetime import datetime

BASE = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(os.path.join(BASE, "config.json"), encoding="utf-8"))
COOKIE = cfg["luogu"]["cookie"]
MY_UID = cfg["luogu"]["user_id"]
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

def get_c3vk_csrf():
    """获取 C3VK 和 CSRF token"""
    r = requests.get("https://www.luogu.com.cn/api/chat/record?user=1",
        headers={"cookie": COOKIE, "user-agent": UA, "referer": "https://www.luogu.com.cn/chat"}, timeout=10)
    c3vk = None
    for c in r.cookies:
        if c.name == "C3VK":
            c3vk = c.value
    if not c3vk:
        for h in r.headers.get("Set-Cookie", "").split(","):
            for p in h.strip().split(";"):
                if p.strip().startswith("C3VK="):
                    c3vk = p.strip().split("=", 1)[1]
                    break
            if c3vk: break
    cookie = COOKIE.strip("; ") + ("; C3VK=" + c3vk if c3vk else "")

    r2 = requests.get("https://www.luogu.com.cn/",
        headers={"cookie": cookie, "user-agent": UA}, timeout=10)
    csrf = None
    m = re.search(r'<meta name="csrf-token" content="([^"]+)"', r2.text)
    if m: csrf = m.group(1)
    return cookie, csrf

def get_page(uid, cookie, csrf, page=None):
    """获取一页消息，page=None 为最新页"""
    if page is None:
        url = f"https://www.luogu.com.cn/api/chat/record?user={uid}"
    else:
        url = f"https://www.luogu.com.cn/api/chat/record?user={uid}&page={page}"
    h = {
        "cookie": cookie, "user-agent": UA,
        "referer": "https://www.luogu.com.cn/chat",
        "x-requested-with": "XMLHttpRequest"
    }
    if csrf: h["x-csrf-token"] = csrf

    r = requests.get(url, headers=h, timeout=10)
    if r.status_code != 200:
        print(f"  ERROR {r.status_code}: {r.text[:200]}")
        return None, 0, 0

    d = r.json()
    msgs = d.get("messages", {})
    if not isinstance(msgs, dict):
        return [], 0, 0
    result = msgs.get("result", [])
    count = msgs.get("count", len(result))
    per_page = msgs.get("perPage", len(result))
    return result, count, per_page

def main():
    if len(sys.argv) < 2:
        print("用法: python get_record.py <uid>")
        sys.exit(1)
    target_uid = sys.argv[1].strip()
    print(f"目标 UID: {target_uid}")
    print(f"我的 UID: {MY_UID}")

    # 登录
    print("获取 C3VK / CSRF ...")
    cookie, csrf = get_c3vk_csrf()
    if not csrf:
        print("ERROR: 无法获取 CSRF token")
        sys.exit(1)
    print(f"  CSRF 获取成功")

    # 第1步: 获取最新页 (无 page 参数)
    print("获取最新页 ...")
    last_page, total, per_page = get_page(target_uid, cookie, csrf)
    if last_page is None:
        print("ERROR: 获取消息失败")
        sys.exit(1)

    total_pages = math.ceil(total / per_page) if per_page > 0 else 1
    print(f"  总数: {total}, 每页: {per_page}, 共 {total_pages} 页")
    print(f"  最新页: {len(last_page)} 条")

    # 收集所有消息 (从旧到新)
    all_msgs = []

    # 第2步: 从 page=1 到 page=total_pages-1 依次获取 (旧→较新)
    for p in range(1, total_pages):
        print(f"获取第 {p}/{total_pages-1} 页 ...")
        page_data, _, _ = get_page(target_uid, cookie, csrf, p)
        if page_data is None:
            print(f"  WARNING: page={p} 获取失败，跳过")
            continue
        all_msgs.extend(page_data)
        print(f"  {len(page_data)} 条")

    # 最后加上最新页
    all_msgs.extend(last_page)

    # 输出
    out_file = os.path.join(BASE, f"{target_uid}.txt")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(f"=== 洛谷私信记录 ===\n")
        f.write(f"我的 UID: {MY_UID}\n")
        f.write(f"对方 UID: {target_uid}\n")
        f.write(f"总消息数: {len(all_msgs)}\n")
        f.write(f"导出时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"{'='*60}\n\n")

        for i, msg in enumerate(all_msgs, 1):
            s = msg.get("sender", {})
            r = msg.get("receiver", {})
            suid = str(s.get("uid", ""))
            sname = s.get("name", "?")
            rname = r.get("name", "?")
            ts = msg.get("time", 0)
            content = msg.get("content", "")
            dt = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S") if ts else "?"

            if suid == MY_UID:
                f.write(f"[{i}] {dt} 我 → {rname}:\n{content}\n\n")
            else:
                f.write(f"[{i}] {dt} {sname} → 我:\n{content}\n\n")

    print(f"\n完成！共 {len(all_msgs)} 条消息")
    print(f"已保存到: {out_file}")

if __name__ == "__main__":
    main()
