# -*- coding: utf-8 -*-
"""LuoguChat 精美通知弹窗 — 独立 PySide6 Widget"""
import re
from PySide6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QPoint, QRect, QSize
from PySide6.QtGui import QGuiApplication, QPainter, QBrush, QColor, QLinearGradient, QFont, QFontDatabase, QPixmap
from PySide6.QtWidgets import QWidget, QLabel, QVBoxLayout, QHBoxLayout, QGraphicsOpacityEffect, QFrame


class GlassPopup(QWidget):
    """玻璃态通知弹窗 — 右下角弹出"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint |
            Qt.Tool | Qt.SubWindow
        )
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_ShowWithoutActivating, True)
        self.setAttribute(Qt.WA_DeleteOnClose, False)

        self._opacity_effect = QGraphicsOpacityEffect(self)
        self._opacity_effect.setOpacity(1.0)
        self.setGraphicsEffect(self._opacity_effect)

        self._fade_in = QPropertyAnimation(self._opacity_effect, b"opacity")
        self._fade_in.setDuration(350)
        self._fade_in.setStartValue(0.0)
        self._fade_in.setEndValue(1.0)
        self._fade_in.setEasingCurve(QEasingCurve.OutCubic)

        self._fade_out = QPropertyAnimation(self._opacity_effect, b"opacity")
        self._fade_out.setDuration(400)
        self._fade_out.setStartValue(1.0)
        self._fade_out.setEndValue(0.0)
        self._fade_out.setEasingCurve(QEasingCurve.InCubic)
        self._fade_out.finished.connect(self.hide)

        self._dismiss_timer = QTimer(self)
        self._dismiss_timer.setSingleShot(True)
        self._dismiss_timer.timeout.connect(self._dismiss)

        self._init_ui()
        self._avatar_cache = {}

    def _init_ui(self):
        self.setFixedSize(380, 160)

        # ── 整体容器 ──
        self._frame = QFrame(self)
        self._frame.setGeometry(0, 0, 380, 160)
        self._frame.setObjectName("popupFrame")
        self._frame.setStyleSheet("""
            #popupFrame {
                background: qlineargradient(x1:0 y1:0, x2:0 y2:1,
                    stop:0 rgba(255,255,255,0.88),
                    stop:0.5 rgba(248,250,255,0.82),
                    stop:1 rgba(240,244,255,0.78));
                border: 1px solid rgba(200,210,240,0.5);
                border-radius: 20px;
            }
        """)

        # ── 左侧头像 ──
        self._avatar = QLabel(self._frame)
        self._avatar.setFixedSize(56, 56)
        self._avatar.move(20, 22)
        self._avatar.setStyleSheet("border-radius: 28px; background: #e4e8f4;")

        # ── 关闭按钮 ──
        self._close_btn = QLabel(self._frame)
        self._close_btn.setText("✕")
        self._close_btn.setFixedSize(28, 28)
        self._close_btn.move(342, 14)
        self._close_btn.setAlignment(Qt.AlignCenter)
        self._close_btn.setStyleSheet("""
            QLabel {
                color: #8890b0; font-size: 14px; font-weight: bold;
                background: rgba(220,225,240,0.6); border-radius: 14px;
            }
            QLabel:hover { background: #ef4444; color: white; }
        """)
        self._close_btn.mousePressEvent = lambda e: self._dismiss()

        # ── 展开/收起按钮 ──
        self._expand_btn = QLabel(self._frame)
        self._expand_btn.setText("+")
        self._expand_btn.setFixedSize(28, 28)
        self._expand_btn.move(342, 48)
        self._expand_btn.setAlignment(Qt.AlignCenter)
        self._expand_btn.setStyleSheet("""
            QLabel {
                color: #6b78c0; font-size: 16px; font-weight: bold;
                background: rgba(200,210,245,0.5); border-radius: 14px;
            }
            QLabel:hover { background: rgba(140,155,235,0.4); }
        """)
        self._expand_btn.mousePressEvent = self._toggle_expand

        # ── 发件人名字 ──
        self._name = QLabel(self._frame)
        self._name.setGeometry(90, 20, 240, 22)
        self._name.setStyleSheet("color: #1e2040; font-size: 15px; font-weight: 700; background: transparent;")
        self._name.setText("发件人")

        # ── 滚动头标 ──
        self._badge = QLabel(self._frame)
        self._badge.setGeometry(90, 44, 130, 18)
        self._badge.setStyleSheet("""
            color: #6366f1; font-size: 11px; font-weight: 600;
            background: rgba(99,102,241,0.08); border-radius: 6px; padding: 2px 8px;
        """)
        self._badge.setText("重要消息")

        # ── 消息预览 ──
        self._preview = QLabel(self._frame)
        self._preview.setGeometry(90, 70, 260, 42)
        self._preview.setWordWrap(True)
        self._preview.setStyleSheet("color: #4a5080; font-size: 13px; background: transparent;")

        # ── AI 提示（可展开） ──
        self._tip = QLabel(self._frame)
        self._tip.setGeometry(20, 110, 340, 0)
        self._tip.setWordWrap(True)
        self._tip.setStyleSheet("""
            color: #6366f1; font-size: 12px; font-weight: 500;
            background: rgba(99,102,241,0.06); border-radius: 10px; padding: 8px 12px;
        """)
        self._tip.hide()

        self._expanded = False
        self._base_h = 160

    def _toggle_expand(self, event):
        self._expanded = not self._expanded
        if self._expanded:
            self.setFixedSize(380, 280)
            self._frame.setGeometry(0, 0, 380, 280)
            self._expand_btn.setText("−")
            self._tip.setGeometry(18, 118, 344, 140)
            self._tip.show()
        else:
            self.setFixedSize(380, 160)
            self._frame.setGeometry(0, 0, 380, 160)
            self._expand_btn.setText("+")
            self._tip.hide()
        self._reposition()

    def show_message(self, uid, sender_name, message, avatar_url="", tip=""):
        """显示通知
        - uid: 发件人 UID
        - sender_name: 发件人名字
        - message: 消息内容
        - avatar_url: 头像 URL
        - tip: AI 分析提示（可选，如 chat.py 的 "提示：xxxxx。"）
        """
        self._name.setText(sender_name)
        self._badge.setText(f"📨 {sender_name} (UID:{uid})")

        # 消息预览（截断）
        preview = message.replace("\n", " ")
        if len(preview) > 80:
            preview = preview[:78] + "…"
        self._preview.setText(preview)

        # AI 提示
        if tip:
            # 尝试提取 chat.py 风格的 "提示：xxx。" 格式
            match = re.search(r'提示：.*?。', tip)
            self._tip.setText(match.group(0) if match else tip)
        else:
            self._tip.setText("")

        # 头像
        if avatar_url and avatar_url not in self._avatar_cache:
            try:
                import requests
                r = requests.get(avatar_url, headers={
                    "user-agent": "Mozilla/5.0", "referer": "https://www.luogu.com.cn/"
                }, timeout=5)
                if r.status_code == 200:
                    pix = QPixmap()
                    pix.loadFromData(r.content)
                    self._avatar_cache[avatar_url] = pix
            except:
                pass

        if avatar_url in self._avatar_cache:
            pix = self._avatar_cache[avatar_url]
            self._avatar.setPixmap(pix.scaled(54, 54, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        else:
            self._avatar.setText(f"  {sender_name[:2]}" if sender_name else "??")
            self._avatar.setAlignment(Qt.AlignCenter)
            self._avatar.setStyleSheet("""
                border-radius: 28px; background: linear-gradient(135deg, #c7d2fe, #a5b4fc);
                color: #4338ca; font-size: 18px; font-weight: 700;
            """)

        # 重置展开状态
        self._expanded = False
        self._expand_btn.setText("+")
        self.setFixedSize(380, 160)
        self._frame.setGeometry(0, 0, 380, 160)
        self._tip.hide()

        self._reposition()
        self._fade_in.start()
        self.show()
        self.raise_()

        # 8 秒后自动消失
        self._dismiss_timer.start(8000)

    def _reposition(self):
        """定位到屏幕右下角"""
        screen = QGuiApplication.primaryScreen()
        if screen:
            geo = screen.availableGeometry()
            x = geo.right() - self.width() - 20
            y = geo.bottom() - self.height() - 20
            self.move(x, y)

    def _dismiss(self):
        self._dismiss_timer.stop()
        self._fade_out.start()

    def mousePressEvent(self, event):
        """点击弹窗主体 → 跳转到对应聊天"""
        if event.button() == Qt.LeftButton:
            self._dismiss()
        super().mousePressEvent(event)

    def paintEvent(self, event):
        """绘制玻璃态背景 + 阴影"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)

        # 外阴影
        shadow_grad = QLinearGradient(0, 0, 0, self.height())
        shadow_grad.setColorAt(0.0, QColor(0, 0, 0, 30))
        shadow_grad.setColorAt(0.3, QColor(0, 0, 0, 15))
        shadow_grad.setColorAt(1.0, QColor(0, 0, 0, 5))

        painter.setBrush(QBrush(shadow_grad))
        painter.setPen(Qt.NoPen)
        painter.drawRoundedRect(3, 3, self.width() - 6, self.height() - 6, 20, 20)

        super().paintEvent(event)
