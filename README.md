# LuoguChat v7.0

> 洛谷私信桌面客户端 — PySide6 + QML，科技感玻璃态 UI

## 功能

- **私信管理** — 洛谷私信读取/发送，WebSocket 实时推送
- **AI 重要消息检测** — 内置智谱 GLM + 自定义 OpenAI 兼容 API
- **通知弹窗** — 右下角 Glass Morphism 弹窗，AI 分析提示
- **右键操作** — 消息删除、联系人置顶/收藏
- **CF Worker 后台** — 用量管理、白名单/黑名单、Cookie 备份
- **主题切换** — 深色/浅色/跟随系统

## 项目结构

```
├── main.py              # Python 后端 (PySide6, LuoguAPI, AI, WebSocket)
├── main.qml             # QML 前端 (Glass Morphism, 科技感配色)
├── popup.py             # 通知弹窗 Widget
├── worker.js            # Cloudflare Worker (KV 存储, Admin 管理)
├── wrangler.toml        # CF Worker 配置
├── build.bat            # PyInstaller 打包脚本
├── requirements.txt     # Python 依赖
├── .gitignore
└── zhl_super_allow.txt  # 存在即无限使用
```

## 运行

```bash
pip install -r requirements.txt
python main.py
```

## 打包

```bash
build.bat
```

## CF Worker

1. 创建 Cloudflare Worker，绑定 KV 命名空间 `chat_kv`
2. 将 `wrangler.toml` 中的 `YOUR_KV_NAMESPACE_ID` 替换为实际 ID
3. 部署 `worker.js`

## 技术栈

- Python 3.8+ / PySide6
- QML (Qt Quick Controls 2.15)
- Cloudflare Workers + KV Storage
- websocket-client
- requests
