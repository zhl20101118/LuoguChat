import QtQuick 2.15
import QtQuick.Controls.Basic 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: win
    visible: true
    width: 1100
    height: 720
    minimumWidth: 860
    minimumHeight: 560
    flags: Qt.FramelessWindowHint | Qt.Window
    color: "transparent"

    // ══════════════════════════════════════
    //  THEME & COLORS (QQ-inspired palette)
    // ══════════════════════════════════════
    property string th: "light"
    property bool darkMode: false

    // Core colors - light theme (QQ NT style)
    property color cBg:        "#F5F6F7"
    property color cSidebarBg: "#EBEDF0"
    property color cListBg:    "#FFFFFF"
    property color cChatBg:    "#F5F6F7"
    property color cHeaderBg:  "#FFFFFF"
    property color cInputBg:   "#FFFFFF"

    // Accent & semantic
    property color cPrimary:   "#1677FF"       // QQ blue
    property color cPrimaryHover:"#4096FF"
    property color cPrimaryLight:"#E8F3FF"
    property color cSuccess:   "#00B42A"
    property color cWarning:   "#FF7D00"
    property color cDanger:    "#F53F3F"
    property color cInfo:      "#86909C"

    // Text colors
    property color cText1:     "#1D2129"       // primary text
    property color cText2:     "#4E5969"       // secondary
    property color cText3:     "#86909C"       // placeholder/hint
    property color cText4:     "#C9CDD4"       // disabled

    // Border & divider
    property color cBorder:    "#E5E6EB"
    property color cDivider:   "#F2F3F5"
    property color cHover:     "#F7F8FA"

    // Bubble colors
    property color cBubbleMe:  "#1677FF"
    property color cBubbleOther:"#FFFFFF"
    property color cBubbleMeText:"#FFFFFF"
    property color cBubbleOtherText:"#1D2129"

    // Background customization
    property string bgType: "solid"           // "solid" | "gradient" | "image"
    property color bgSolidColor: "#F5F6F7"
    property color bgGradientStart: "#E8EEFE"
    property color bgGradientEnd: "#F5F0F0"
    property string bgImageUrl: ""
    property real bgOpacity: 1.0

    // State properties
    property var chatList: []
    property var msgs: []
    property string curUid: ""
    property string curName: ""
    property string myUid: ""
    property string myName: ""
    property bool aiOn: false
    property string kw: "zhl重要信息"
    property string curMode: "class"
    property var modeList: []
    property string wsStat: "disconnected"
    property string svrUrl: ""
    property int svrRem: 0
    property int svrTot: 0
    property bool svrOk: true
    property bool sAllow: false
    property bool notifyOn: true
    property bool soundOn: true
    property string searchKw: ""
    property var searchResults: []
    property bool searching: false
    property string soundFile: ""
    property int navIdx: 0

    // Animation helper durations
    property int animFast: 150
    property int animNormal: 250
    property int animSlow: 400

    // ══════════════════════════════════════
    //  THEME SYSTEM (Multiple themes)
    // ══════════════════════════════════════
    property string currentTheme: "blue"
    property var themes: ({})
    
    function applyTheme(themeName) {
        if (themeName === "blue") {
            cBg = "#F5F6F7"; cSidebarBg = "#EBEDF0"; cListBg = "#FFFFFF"; cChatBg = "#F5F6F7";
            cHeaderBg = "#FFFFFF"; cInputBg = "#FFFFFF"; cPrimary = "#1677FF"; cPrimaryHover = "#4096FF";
            cPrimaryLight = "#E8F3FF"; cBubbleMe = "#1677FF"; cBubbleOther = "#FFFFFF";
            cText1 = "#1D2129"; cText2 = "#4E5969"; cText3 = "#86909C"; cText4 = "#C9CDD4";
            cBorder = "#E5E6EB"; cDivider = "#F2F3F5"; cHover = "#F7F8FA";
        } else if (themeName === "dark") {
            cBg = "#1A1A1A"; cSidebarBg = "#252525"; cListBg = "#2D2D2D"; cChatBg = "#1A1A1A";
            cHeaderBg = "#2D2D2D"; cInputBg = "#2D2D2D"; cPrimary = "#1677FF"; cPrimaryHover = "#4096FF";
            cPrimaryLight = "#1A3A5C"; cBubbleMe = "#1677FF"; cBubbleOther = "#2D2D2D";
            cText1 = "#E5E6EB"; cText2 = "#A0A0A0"; cText3 = "#6B6B6B"; cText4 = "#4A4A4A";
            cBorder = "#3A3A3A"; cDivider = "#2A2A2A"; cHover = "#353535";
        } else if (themeName === "pink") {
            cBg = "#FFF0F5"; cSidebarBg = "#FFE4E9"; cListBg = "#FFFFFF"; cChatBg = "#FFF0F5";
            cHeaderBg = "#FFFFFF"; cInputBg = "#FFFFFF"; cPrimary = "#FF6B9D"; cPrimaryHover = "#FF8FB3";
            cPrimaryLight = "#FFE4E9"; cBubbleMe = "#FF6B9D"; cBubbleOther = "#FFFFFF";
        } else if (themeName === "green") {
            cBg = "#F0FDF4"; cSidebarBg = "#E8F5E9"; cListBg = "#FFFFFF"; cChatBg = "#F0FDF4";
            cHeaderBg = "#FFFFFF"; cInputBg = "#FFFFFF"; cPrimary = "#00B42A"; cPrimaryHover = "#34D058";
            cPrimaryLight = "#E8F5E9"; cBubbleMe = "#00B42A"; cBubbleOther = "#FFFFFF";
        } else if (themeName === "purple") {
            cBg = "#F9F0FF"; cSidebarBg = "#F0E6FF"; cListBg = "#FFFFFF"; cChatBg = "#F9F0FF";
            cHeaderBg = "#FFFFFF"; cInputBg = "#FFFFFF"; cPrimary = "#8B5CF6"; cPrimaryHover = "#A78BFA";
            cPrimaryLight = "#F0E6FF"; cBubbleMe = "#8B5CF6"; cBubbleOther = "#FFFFFF";
        }
        currentTheme = themeName;
        try { bridge.setTheme(themeName); } catch(e) {}
    }
    
    function loadTheme() {
        try {
            var theme = bridge.getTheme();
            if (theme) applyTheme(theme);
        } catch(e) {}
    }



    // ══════════════════════════════════════
    //  UTILITY FUNCTIONS
    // ══════════════════════════════════════

    // 填充账号字段
    function _refillAccountFields() {
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            uidFld.text = c.luogu ? (c.luogu.user_id || "") : "";
            cookieFld.text = c.luogu ? (c.luogu.cookie || "") : "";
        } catch(e) {}
    }
        function _abg(n) {
        var cs = ["#1677FF","#F53F3F","#722ED1","#00B42A","#FF7D00","#14C9C9","#F53F3F","#3491FA","#0FC6C2","#86909C"];
        var h = 0;
        var nn = n || "";
        for (var i = 0; i < nn.length; i++) h += nn.charCodeAt(i);
        return cs[Math.abs(h) % cs.length];
    }
    function _ft(ts) {
        if (!ts) return "";
        var d = new Date(ts * 1000), now = new Date();
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, "HH:mm");
        var dayCount = Math.floor((now - d) / 86400000);
        if (dayCount === 1) return "昨天";
        if (dayCount < 7) return Qt.formatDate(d, "ddd");
        return Qt.formatDate(d, "MM-dd");
    }
    function _lc() { try { chatList = JSON.parse(bridge.getChatList() || "[]") } catch(e){} }
    function _lu() {
        try { var u = JSON.parse(bridge.getUserInfo() || "{}"); myName = u.name || ""; myUid = u.uid || "" }
        catch(e){}
    }
    function _lch() {
        if (!curUid) { msgs = []; return }
        try { var d = JSON.parse(bridge.getMessages(curUid, 1) || "{}"); msgs = d.messages || [] }
        catch(e){}
    }
    function _rf() { _lc(); _lu(); _lch(); }
    function _buildModes() {
        modeList = [];
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            var ms = (c.ai && c.ai.modes) || {};
            var ks = Object.keys(ms);
            for (var i = 0; i < ks.length; i++) {
                var m = ms[ks[i]];
                if (m) modeList.push({mid: ks[i], name: m.name || "", icon: m.icon || "", prompt: m.prompt || ""});
            }
        } catch(e){}
    }
    function _saveCfg() {
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            if (!c.ai) c.ai = {};
            c.ai.enabled = aiOn;
            c.ai.current_mode = curMode;
            c.ai.important_keyword = kw;
            if (!c.server) c.server = {};
            c.server.url = svrUrl;
            if (!c.notification) c.notification = {};
            c.notification.enabled = notifyOn;
            c.notification.sound_enabled = soundOn;
            if (soundFile) c.notification.sound_file = soundFile;
            bridge.saveConfig(JSON.stringify(c));
        } catch(e){}
    }
    function _doSend() {
        if (!curUid || !msgIn.text.trim()) return;
        bridge.sendMessage(curUid, msgIn.text.trim());
        msgs = msgs.concat([{
            id: "local_" + Date.now(),
            content: msgIn.text.trim(),
            time: Math.floor(Date.now() / 1000),
            sender_uid: myUid,
            sender_name: myName,
            is_me: true
        }]);
        msgIn.text = "";
    }
    function _doSearch() {
        if (!searchKw.trim()) { searchResults = []; return; }
        searching = true;
        try { searchResults = JSON.parse(bridge.searchUsers(searchKw.trim()) || "[]") }
        catch(e){ searchResults = []; }
        searching = false;
    }
    function _relogin() {
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            if (typeof uidFld !== "undefined") uidFld.text = (c.luogu && c.luogu.user_id) || "";
            if (typeof cookieFld !== "undefined") cookieFld.text = (c.luogu && c.luogu.cookie) || "";
        } catch(e){}
    }
    function _doprompt(k, v) {
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            if (c.ai && c.ai.modes && c.ai.modes[k]) {
                c.ai.modes[k].prompt = v;
                bridge.saveConfig(JSON.stringify(c));
            }
        } catch(e){}
    }

    Component.onCompleted: {
        _refillAccountFields();
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            aiOn = !!(c.ai && c.ai.enabled);
            curMode = (c.ai && c.ai.current_mode) || "class";
            kw = (c.ai && c.ai.important_keyword) || kw;
            svrUrl = (c.server && c.server.url) || "";
            notifyOn = !(c.notification && c.notification.enabled === false);
            soundOn = !(c.notification && c.notification.sound_enabled === false);
            soundFile = (c.notification && c.notification.sound_file) || "";
            if (c.theme === "dark") darkMode = true;
            if (c.bg) {
                if (c.bg.type) bgType = c.bg.type;
                if (c.bg.solid_color) bgSolidColor = c.bg.solid_color;
                if (c.bg.gradient_start) bgGradientStart = c.bg.gradient_start;
                if (c.bg.gradient_end) bgGradientEnd = c.bg.gradient_end;
                if (c.bg.image_url) bgImageUrl = c.bg.image_url;
            }
        } catch(e){}
        _rf();
        _buildModes();
        _relogin();
        try {
            var ss = JSON.parse(bridge.getServerStatus() || "{}");
            svrRem = ss.remaining || 0;
            svrTot = ss.total || 0;
            svrOk = ss.allowed !== false;
            sAllow = !!ss.super_allow;
        } catch(e){}
        bridge.loginTestResult.connect(function(ok, msg){
            toast.show(msg || (ok ? "登录成功" : "登录失败"));
            if (ok) { _lu(); _rf(); }
        });
        bridge.wsStatusChanged.connect(function(s){ wsStat = s });
        bridge.chatListUpdated.connect(function(){ _lc() });
        bridge.userInfoUpdated.connect(function(n, u, a){ myName = n || ""; myUid = u || "" });
        bridge.cookieInvalidPopup.connect(function(){ cookiePopup.visible = true });
        bridge.newMessage.connect(function(mid, content, sn, su, ts){
            _lc();
            if (curUid === su) _lch();
        });
        bridge.serverSyncResult.connect(function(ok, msg, rem, tot, allowed){
            svrRem = rem;
            svrTot = tot;
            svrOk = ok;
            sAllow = allowed;
        });
    }

    // ══════════════════════════════════════
    //  BACKGROUND LAYER (gradient/image)
    // ══════════════════════════════════════
    Rectangle {
        id: mainBg
        anchors.fill: parent
        opacity: bgOpacity

        // Background color/gradient based on type
        color: {
            if (bgType === "solid") return bgSolidColor;
            if (bgType === "image") return "#E8E8E8";
            // gradient - base color (will be overridden by gradient)
            return bgGradientStart;
        }

        gradient: bgType === "gradient" ? diagGradient : null

        Gradient {
            id: diagGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: bgGradientStart }
            GradientStop { position: 1.0; color: bgGradientEnd }
        }

        Image {
            id: bgImage
            anchors.fill: parent
            source: bgImageUrl !== "" ? bgImageUrl : ""
            visible: bgType === "image" && bgImageUrl !== ""
            fillMode: Image.PreserveAspectCrop
            opacity: 0.85
        }
    }

    // ══════════════════════════════════════
    //  RESIZE HANDLES (8 directions)
    // ══════════════════════════════════════
    Item {
        id: resizeHandles
        anchors.fill: parent
        z: 9999

        // Corner: bottom-right
        Rectangle {
            width: 16; height: 16
            anchors.right: parent.right; anchors.bottom: parent.bottom
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.BottomEdge | RightEdge) }
            }
        }
        // Corner: bottom-left
        Rectangle {
            width: 16; height: 16
            anchors.left: parent.left; anchors.bottom: parent.bottom
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeBDiagCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.BottomEdge | LeftEdge) }
            }
        }
        // Corner: top-right
        Rectangle {
            width: 16; height: 16
            anchors.right: parent.right; anchors.top: parent.top
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeBDiagCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.TopEdge | RightEdge) }
            }
        }
        // Corner: top-left
        Rectangle {
            width: 16; height: 16
            anchors.left: parent.left; anchors.top: parent.top
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.TopEdge | LeftEdge) }
            }
        }
        // Edge: bottom
        Rectangle {
            height: 6; anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.leftMargin: 16; anchors.rightMargin: 16
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.BottomEdge) }
            }
        }
        // Edge: top
        Rectangle {
            height: 6; anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: 16; anchors.rightMargin: 16
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.TopEdge) }
            }
        }
        // Edge: right
        Rectangle {
            width: 6; anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            anchors.topMargin: 16; anchors.bottomMargin: 16
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.RightEdge) }
            }
        }
        // Edge: left
        Rectangle {
            width: 6; anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            anchors.topMargin: 16; anchors.bottomMargin: 16
            color: "transparent"; z: 9999
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                onPressed: function(mouse){ win.startSystemResize(Qt.LeftEdge) }
            }
        }
    }

    // ══════════════════════════════════════
    //  MAIN CONTAINER (rounded card)
    // ══════════════════════════════════════
    Rectangle {
        id: rootCard
        anchors.fill: parent
        anchors.margins: 0
        radius: 12
        color: cBg
        border.color: cBorder
        border.width: 1

        // Subtle shadow effect via overlay
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.color: "#00000008"
            border.width: 1
            z: -1
        }

        // ═════════════════════════════════
        //  TITLE BAR
        // ═════════════════════════════════
        Rectangle {
            id: titleBar
            height: 38
            z: 200
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                topMargin: 0; leftMargin: 0; rightMargin: 0
            }
            color: cSidebarBg
            radius: 12
            clip: true

            // Bottom rounding fix
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 10; color: parent.color
            }

            DragHandler {
                target: null
                onActiveChanged: { if (active) win.startSystemMove() }
            }

            Row {
                x: 14; y: 0
                spacing: 8
                height: parent.height
                Repeater {
                    model: ["#FF5F57", "#FFBD2E", "#28C840"]
                    Rectangle {
                        width: 13; height: 13
                        radius: 7
                        y: (parent.height - height) / 2
                        color: modelData
                        opacity: tlBtnMa.containsMouse ? 1.0 : 0.85
                        Behavior on opacity { NumberAnimation { duration: animFast } }
                        scale: tlBtnMa.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: animFast } }
                        MouseArea {
                            id: tlBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(){
                                if (index === 0) win.close()
                                else if (index === 1) win.showMinimized()
                                else win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "LuoguChat"
                color: cText2
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.rightMargin: 10
                spacing: 4

                // AI toggle button
                Rectangle {
                    width: aiToggleBtnMa.containsMouse ? 56 : 48
                    height: 26
                    radius: 13
                    color: aiOn ? "#E8FFEC" : "transparent"
                    border.color: aiOn ? cSuccess : "transparent"
                    border.width: 1
                    Behavior on width { NumberAnimation { duration: animFast } }
                    Behavior on color { ColorAnimation { duration: animFast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 18; height: 18
                            radius: 9
                            y: (parent.parent.height - height) / 2
                            color: aiOn ? cSuccess : cText3
                            Behavior on color { ColorAnimation { duration: animFast } }
                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"  // checkmark
                                color: "white"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                visible: aiOn
                            }
                        }
                        Text {
                            text: "AI"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: aiOn ? cSuccess : cText2
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: animFast } }
                        }
                    }
                    MouseArea {
                        id: aiToggleBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function() { aiOn = !aiOn; _saveCfg() }
                    }
                }

                // Settings button
                Rectangle {
                    id: settingsBtn
                    width: settingsBtnMa.containsMouse ? 32 : 28
                    height: 26
                    radius: 6
                    color: settingsBtnMa.containsMouse ? cHover : "transparent"
                    Behavior on width { NumberAnimation { duration: animFast } }
                    Behavior on color { ColorAnimation { duration: animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: "\u2699"  // gear
                        font.pixelSize: 14
                        color: settingsBtnMa.containsMouse ? cPrimary : cText3
                        Behavior on color { ColorAnimation { duration: animFast } }
                    }
                    MouseArea {
                        id: settingsBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function() { settingsPanel.visible = true; _refillAccountFields() }
                    }
                }

                // Theme toggle
                Rectangle {
                    id: themeBtn
                    width: themeBtnMa.containsMouse ? 32 : 28
                    height: 26
                    radius: 6
                    color: themeBtnMa.containsHover ? cHover : "transparent"
                    Behavior on width { NumberAnimation { duration: animFast } }
                    Behavior on color { ColorAnimation { duration: animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: darkMode ? "\u2600" : "\u2601"  // sun / moon
                        font.pixelSize: 14
                        color: themeBtnMa.containsHover ? cPrimary : cText3
                        Behavior on color { ColorAnimation { duration: animFast } }
                    }
                    MouseArea {
                        id: themeBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        property bool containsHover: containsMouse
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function() { darkMode = !darkMode }
                    }
                }
            }
        }

        // ═════════════════════════════════
        //  BODY AREA (below title bar)
        // ═════════════════════════════════
        Item {
            id: bodyArea
            anchors {
                top: titleBar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            // ─────────────────────────────
            //  LEFT SIDEBAR (60px)
            // ─────────────────────────────
            Rectangle {
                id: sidebar
                width: 60
                z: 20
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                color: cSidebarBg

                // Right border line
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1; color: cBorder
                }

                ColumnLayout {
                    anchors { fill: parent; topMargin: 10; bottomMargin: 8 }
                    spacing: 2

                    // User avatar
                    Rectangle {
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignHCenter
                        radius: 20
                        color: _abg(myName || "L")
                        scale: avatarMa.containsMouse ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: animFast; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: myName ? myName[0] : "L"
                            color: "white"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        // Online status dot
                        Rectangle {
                            width: 12; height: 12
                            radius: 6
                            anchors { right: parent.right; bottom: parent.bottom; margins: -1 }
                            color: wsStat === "connected" ? cSuccess : cDanger
                            border.color: cSidebarBg
                            border.width: 2
                        }

                        MouseArea {
                            id: avatarMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Item { Layout.preferredHeight: 8 }

                    // Navigation items (线条图标)
                    Repeater {
                        model: ["消息", "联系人", "收藏", "文件"]
                        Rectangle {
                            Layout.preferredWidth: 46; Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignHCenter
                            radius: 10
                            color: navIdx === index ? cPrimaryLight : (navItemMa.containsMouse ? cHover : "transparent")
                            scale: navIdx === index ? 1.02 : (navItemMa.containsMouse ? 1.05 : 1.0)
                            Behavior on color { ColorAnimation { duration: animFast } }
                            Behavior on scale { NumberAnimation { duration: animFast; easing.type: Easing.OutCubic } }

                            // 线条风格图标 (Canvas 绘制)
                            Canvas {
                                id: navIcon
                                anchors.centerIn: parent
                                width: 20; height: index === 2 ? 20 : (index === 0 ? 20 : 20)
                                property color icColor: navIdx === index ? cPrimary : (navItemMa.containsMouse ? cText1 : cText3)
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.strokeStyle = icColor;
                                    ctx.lineWidth = 1.6;
                                    ctx.lineJoin = "round";
                                    ctx.lineCap = "round";
                                    if (index === 0) {
                                        // 信封 (线条)
                                        ctx.beginPath();
                                        ctx.rect(1, 3, 18, 13);
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.moveTo(1, 3);
                                        ctx.lineTo(10, 9);
                                        ctx.lineTo(19, 3);
                                        ctx.stroke();
                                    } else if (index === 1) {
                                        // 人像 (线条)
                                        ctx.beginPath();
                                        ctx.arc(10, 6, 4, 0, Math.PI * 2);
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.arc(10, 22, 7, Math.PI, 0, false);
                                        ctx.stroke();
                                    } else if (index === 2) {
                                        // 星星 (线条)
                                        var cx = 10, cy = 10, or = 7, ir = 3;
                                        ctx.beginPath();
                                        for (var i = 0; i < 5; i++) {
                                            var a = (Math.PI / 2) + (2 * Math.PI / 5) * i;
                                            var ox = cx + or * Math.cos(a);
                                            var oy = cy - or * Math.sin(a);
                                            if (i === 0) ctx.moveTo(ox, oy); else ctx.lineTo(ox, oy);
                                            a += Math.PI / 5;
                                            ox = cx + ir * Math.cos(a);
                                            oy = cy - ir * Math.sin(a);
                                            ctx.lineTo(ox, oy);
                                        }
                                        ctx.closePath();
                                        ctx.stroke();
                                    } else if (index === 3) {
                                        // 文件夹 (线条)
                                        ctx.beginPath();
                                        ctx.moveTo(1, 4);
                                        ctx.lineTo(7, 4);
                                        ctx.lineTo(11, 1);
                                        ctx.lineTo(19, 1);
                                        ctx.lineTo(19, 15);
                                        ctx.lineTo(1, 15);
                                        ctx.closePath();
                                        ctx.stroke();
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 12
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData
                                    font.pixelSize: 9
                                    color: navIdx === index ? cPrimary : cText4
                                }
                            }

                            MouseArea {
                                id: navItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function() {
                                    navIdx = index;
                                    searchResults = [];
                                    searchFld.text = "";
                                    _lc();
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Bottom area: AI quick toggle
                    Rectangle {
                        Layout.preferredWidth: 46; Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignHCenter
                        radius: 10
                        color: aiOn ? "#E8FFEC" : (aiNavMa.containsMouse ? cHover : "transparent")
                        Behavior on color { ColorAnimation { duration: animFast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "\uD83E\uDD16"  // robot
                                font.pixelSize: 18
                                color: aiOn ? cSuccess : (aiNavMa.containsHover ? cText1 : cText3)
                                Behavior on color { ColorAnimation { duration: animFast } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "AI助手"
                                font.pixelSize: 9
                                color: aiOn ? cSuccess : cText4
                            }
                        }
                        MouseArea {
                            id: aiNavMa
                            anchors.fill: parent
                            hoverEnabled: true
                            property bool containsHover: containsMouse
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function() { aiOn = !aiOn; _saveCfg() }
                        }
                    }

                    Item { Layout.preferredHeight: 4 }

                    // Settings gear at bottom
                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        radius: 8
                        color: settingsNavMa.containsMouse ? cHover : "transparent"
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "\u2630"  // menu bars
                            font.pixelSize: 18
                            color: settingsNavMa.containsMouse ? cPrimary : cText3
                            Behavior on color { ColorAnimation { duration: animFast } }
                        }
                        MouseArea {
                            id: settingsNavMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function() { settingsPanel.visible = true; _refillAccountFields() }
                        }
                    }
                }
            }

            // ─────────────────────────────
            //  MIDDLE PANEL (chat list)
            // ─────────────────────────────
            Rectangle {
                id: listPanel
                width: 280
                anchors {
                    top: parent.top; bottom: parent.bottom
                    left: sidebar.right
                }
                color: cListBg

                // Right border line
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1; color: cBorder
                }

                Column {
                    anchors.fill: parent
                    spacing: 0

                    // Search bar area
                    Rectangle {
                        width: parent.width
                        height: 58
                        color: "transparent"

                        Rectangle {
                            width: parent.width - 20
                            height: 36
                            radius: 8
                            anchors.centerIn: parent
                            color: "#F2F3F5"
                            border.color: searchFld.activeFocus ? cPrimary : "transparent"
                            border.width: searchFld.activeFocus ? 1.5 : 0
                            Behavior on border.color { ColorAnimation { duration: animFast } }

                            Row {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                                spacing: 6

                                Text {
                                    text: "\uD83D\uDD0D"  // magnifying glass
                                    font.pixelSize: 15
                                    color: cText3
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                TextField {
                                    id: searchFld
                                    width: parent.width - 30
                                    height: parent.height
                                    color: cText1
                                    font.pixelSize: 13
                                    placeholderText: "搜索联系人..."
                                    background: Rectangle { color: "transparent" }
                                    onTextChanged: {
                                        searchKw = text;
                                        if (!text.trim()) { searchResults = []; _lc() }
                                        else _doSearch()
                                    }
                                }

                                // Clear button
                                Rectangle {
                                    visible: searchFld.text !== ""
                                    width: 18; height: 18
                                    radius: 9
                                    color: cText4
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: clearSearchMa.containsMouse ? 1.0 : 0.7
                                    Behavior on opacity { NumberAnimation { duration: animFast } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u2715"  // cross
                                        color: "white"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        id: clearSearchMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() { searchFld.text = ""; searchResults = []; _lc() }
                                    }
                                }
                            }
                        }
                    }

                    // Chat list
                    ListView {
                        id: chatLv
                        width: parent.width
                        height: parent.height - 58
                        clip: true
                        spacing: 0
                        model: searchResults.length > 0 ? searchResults : chatList

                        delegate: Rectangle {
                            id: chatItemDelegate
                            required property string uid
                            required property string name
                            required property string last_message
                            required property int last_time
                            required property int unread

                            width: chatLv.width
                            height: 68
                            color: curUid === uid ? cPrimaryLight : (chatItemMa.containsMouse ? cHover : "transparent")
                            Behavior on color { ColorAnimation { duration: animFast } }

                            // Left accent bar for selected
                            Rectangle {
                                width: 4
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                color: cPrimary
                                visible: curUid === uid
                                opacity: curUid === uid ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: animNormal } }
                            }

                            Row {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
                                spacing: 12

                                // Avatar
                                Rectangle {
                                    width: 44; height: 44
                                    radius: 10
                                    color: _abg(name || "?")
                                    anchors.verticalCenter: parent.verticalCenter
                                    scale: chatItemMa.containsMouse ? 1.04 : 1.0
                                    Behavior on scale { NumberAnimation { duration: animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (name || "?")[0]
                                        color: "white"
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                    }

                                    // Unread count badge on avatar
                                    Rectangle {
                                        visible: unread > 0
                                        width: unread > 99 ? 28 : 20
                                        height: 18
                                        radius: 9
                                        color: cDanger
                                        anchors { right: parent.right; bottom: parent.bottom; margins: -4 }

                                        Text {
                                            anchors.centerIn: parent
                                            text: unread > 99 ? "99+" : String(unread)
                                            color: "white"
                                            font.pixelSize: unread > 99 ? 9 : 11
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                // Name + message info
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 56
                                    spacing: 4

                                    Row {
                                        width: parent.width
                                        spacing: 6

                                        Text {
                                            text: name || "未知用户"
                                            color: cText1
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            width: parent.width - timeTxt.width - 6
                                        }
                                        Text {
                                            id: timeTxt
                                            text: _ft(last_time)
                                            color: cText4
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 6

                                        Text {
                                            text: last_message || "暂无消息"
                                            color: curUid === uid ? cText2 : cText3
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            width: parent.width - (unreadBadge.visible ? unreadBadge.width + 6 : 0)
                                            maximumLineCount: 1
                                        }

                                        // Unread dot in row
                                        Rectangle {
                                            id: unreadBadge
                                            visible: unread > 0 && unread <= 99
                                            width: 8; height: 8
                                            radius: 4
                                            color: cDanger
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: chatItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function() {
                                    curUid = uid;
                                    curName = name || "";
                                    _lch();
                                }
                            }
                        }

                        // Empty state when no chats
                        Item {
                            visible: chatLv.count === 0
                            width: chatLv.width
                            height: chatLv.height
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                Text {
                                    text: "\uD83D\uDEAC"
                                    font.pixelSize: 40
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    text: "暂无聊天记录"
                                    font.pixelSize: 14
                                    color: cText3
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────
            //  RIGHT PANEL (chat area)
            // ─────────────────────────────
            Rectangle {
                id: chatArea
                anchors {
                    top: parent.top; bottom: parent.bottom
                    left: listPanel.right; right: parent.right
                }
                color: cChatBg

                Column {
                    anchors.fill: parent
                    spacing: 0

                    // ── Chat header ──
                    Rectangle {
                        id: chatHeader
                        width: parent.height > 0 ? parent.width : 0
                        height: 56
                        color: cHeaderBg

                        // Bottom border line
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1; color: cBorder
                        }

                        Row {
                            anchors { fill: parent; leftMargin: 18; rightMargin: 12 }
                            spacing: 12

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: curName || "选择一个聊天"
                                    color: cText1
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: wsStat === "connected" ? "在线 · 可正常收发消息" : "离线 · 请检查网络或 Cookie"
                                    color: wsStat === "connected" ? cSuccess : cText4
                                    font.pixelSize: 11
                                    visible: curUid !== ""
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                // Action buttons in header
                                Repeater {
                                    model: ["\u270F", "\uD83D\uDCC4", "\u22EE"]  // edit, doc, more dots
                                    Rectangle {
                                        width: 32; height: 32
                                        radius: 6
                                        color: headerActionMa.containsMouse ? cHover : "transparent"
                                        Behavior on color { ColorAnimation { duration: animFast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 15
                                            color: headerActionMa.containsHover ? cPrimary : cText3
                                            Behavior on color { ColorAnimation { duration: animFast } }
                                        }
                                        MouseArea {
                                            id: headerActionMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            property bool containsHover: containsMouse
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Messages area ──
                    ListView {
                        id: msgLst
                        width: parent.width
                        height: parent.height - 56 - inputArea.height
                        model: msgs
                        clip: true
                        spacing: 12
                        cacheBuffer: 2000
                        anchors.topMargin: 8

                        delegate: Item {
                            id: msgItem
                            width: msgLst.width
                            height: msgCol.height + 16
                            opacity: 1

                            Row {
                                id: msgRow
                                anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18 }
                                layoutDirection: modelData.is_me ? Qt.RightToLeft : Qt.LeftToRight
                                spacing: 10

                                // Avatar
                                Rectangle {
                                    width: 38; height: 38
                                    radius: 8
                                    color: modelData.is_me ? cPrimary : _abg(modelData.sender_name || curName || "?")
                                    anchors.top: parent.top
                                    scale: msgRowMa.containsMouse ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.sender_name || curName || "?")[0]
                                        color: "white"
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                    }
                                }

                                // Bubble column
                                Column {
                                    id: msgCol
                                    width: Math.min(bubbleRect.width, msgLst.width - 120)
                                    spacing: 4

                                    // Sender name (for others' messages only)
                                    Text {
                                        text: modelData.sender_name || ""
                                        color: cText3
                                        font.pixelSize: 11
                                        visible: !modelData.is_me
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                    }

                                    // Message bubble
                                    Rectangle {
                                        id: bubbleRect
                                        property real maxW: Math.max(200, msgLst.width - 140)
                                        // 用辅助 Text 测量自然宽度（无宽度限制时的宽度）
                                        property real naturalW: measureText.implicitWidth
                                        width: Math.min(naturalW + 28, maxW)
                                        height: bubbleContent.implicitHeight + 24
                                        radius: 12

                                        color: modelData.is_me ? cBubbleMe : cBubbleOther
                                        border.color: modelData.is_me ? "transparent" : cBorder
                                        border.width: modelData.is_me ? 0 : 1

                                        // 辅助 Text：测量自然宽度（不可见）
                                        Text {
                                            id: measureText
                                            visible: false
                                            text: modelData.content || ""
                                            font.pixelSize: 14
                                        }

                                        // 实际显示的文字（有宽度限制，自动换行）
                                        Text {
                                            id: bubbleContent
                                            anchors { fill: parent; margins: 14 }
                                            text: modelData.content || ""
                                            color: modelData.is_me ? cBubbleMeText : cBubbleOtherText
                                            font.pixelSize: 14
                                            wrapMode: Text.Wrap
                                            linkColor: cPrimary
                                        }
                                    }

                                    // Time under bubble
                                    Text {
                                        text: _ft(modelData.time)
                                        color: cText4
                                        font.pixelSize: 10
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        visible: true
                                    }
                                }
                            }

                            MouseArea {
                                id: msgRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton  // passive hover detection
                            }
                        }

                        onCountChanged: {
                            if (count > 0) positionViewAtEnd();
                        }

                        // Empty state
                        Item {
                            visible: msgLst.count === 0 && curUid === ""
                            width: msgLst.width
                            height: msgLst.height
                            Column {
                                anchors.centerIn: parent
                                spacing: 16
                                Text {
                                    text: "\uD83D\uDCAC"
                                    font.pixelSize: 56
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    text: "从左侧选择一个聊天开始对话"
                                    font.pixelSize: 14
                                    color: cText3
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    // ── Input area ──
                    Rectangle {
                        id: inputArea
                        width: parent.width
                        height: 140
                        color: "transparent"

                        Column {
                            anchors { fill: parent; topMargin: 4; bottomMargin: 10; leftMargin: 16; rightMargin: 16 }
                            spacing: 8

                            // Toolbar row
                            Row {
                                width: parent.height > 0 ? parent.width : 0
                                height: 28
                                spacing: 4

                                // Toolbar buttons with icons
                                Repeater {
                                    model: [
                                        {icon: "\u263A", tip: "表情"},
                                        {icon: "\u2702", tip: "截图"},
                                        {icon: "\uD83D\uDCC1", tip: "发送文件"},
                                        {icon: "\uD83D\uDDCF", tip: "发送图片"},
                                        {icon: "\u23ED", tip: "历史记录"}
                                    ]
                                    Rectangle {
                                        width: 30; height: 28
                                        radius: 6
                                        color: toolBtnMa.containsHover ? cHover : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.pixelSize: 15
                                            color: toolBtnMa.containsHover ? cPrimary : cText3
                                            Behavior on color { ColorAnimation { duration: animFast } }
                                        }
                                        MouseArea {
                                            id: toolBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            property bool containsHover: containsMouse
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // AI mode indicator in toolbar
                                Rectangle {
                                    visible: aiOn
                                    width: aiToolbarLabel.width + 16
                                    height: 24
                                    radius: 12
                                    color: "#E8FFEC"
                                    border.color: cSuccess
                                    border.width: 1
                                    opacity: aiOn ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: animNormal } }
                                    Text {
                                        id: aiToolbarLabel
                                        anchors.centerIn: parent
                                        text: "AI 分析已开启"
                                        font.pixelSize: 11
                                        color: cSuccess
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            // Input box
                            Rectangle {
                                width: parent.width
                                height: 64
                                radius: 10
                                color: cInputBg
                                border.color: msgIn.activeFocus ? cPrimary : cBorder
                                border.width: msgIn.activeFocus ? 1.5 : 1
                                Behavior on border.color { ColorAnimation { duration: animFast } }

                                TextArea {
                                    id: msgIn
                                    anchors { fill: parent; margins: 10 }
                                    color: cText1
                                    font.pixelSize: 14
                                    placeholderText: curUid ? "输入消息..." : "请先在左侧选择一个聊天"
                                    background: Rectangle { color: "transparent" }
                                    wrapMode: TextArea.Wrap
                                    Keys.onReturnPressed: function(event) {
                                        if (!(event.modifiers & Qt.ShiftModifier)) {
                                            event.accepted = true;
                                            _doSend();
                                        }
                                    }
                                }
                            }

                            // Send button row
                            Row {
                                width: parent.width
                                spacing: 8

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    id: sendBtn
                                    width: sendBtnMa.containsHover ? 72 : 66
                                    height: 34
                                    radius: 8
                                    color: (msgIn.text.trim() && curUid) ? cPrimary : cBorder
                                    opacity: (msgIn.text.trim() && curUid) ? 1.0 : 0.5
                                    Behavior on width { NumberAnimation { duration: animFast } }
                                    Behavior on color { ColorAnimation { duration: animFast } }
                                    Behavior on opacity { NumberAnimation { duration: animFast } }

                                    scale: sendBtnMa.pressed ? 0.95 : (sendBtnMa.containsHover ? 1.03 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "发送"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: (msgIn.text.trim() && curUid) ? "white" : cText3
                                        Behavior on color { ColorAnimation { duration: animFast } }
                                    }
                                    MouseArea {
                                        id: sendBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: _doSend()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════
    //  TOAST NOTIFICATION
    // ══════════════════════════════════════
    Rectangle {
        id: toast
        visible: false
        z: 999
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        height: 40
        radius: 20
        width: toastTxt.implicitWidth + 44
        color: "#1D2129EE"
        scale: toastAnim.running ? 0.9 : 1.0
        opacity: toastAnim.running ? 0.0 : 1.0

        Text {
            id: toastTxt
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 13
        }

        SequentialAnimation {
            id: toastAnim
            PropertyAction { target: toast; property: "visible"; value: true }
            ParallelAnimation {
                NumberAnimation { target: toast; property: "scale"; from: 0.8; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                NumberAnimation { target: toast; property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
            }
            PauseAnimation { duration: 2500 }
            ParallelAnimation {
                NumberAnimation { target: toast; property: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                NumberAnimation { target: toast; property: "scale"; from: 1.0; to: 0.9; duration: 200 }
            }
            PropertyAction { target: toast; property: "visible"; value: false }
        }

        function show(msg) {
            toastTxt.text = msg || "";
            toastAnim.restart();
        }
    }

    // ══════════════════════════════════════
    //  COOKIE INVALID POPUP
    // ══════════════════════════════════════
    Rectangle {
        id: cookiePopup
        visible: false
        z: 800
        anchors.centerIn: parent
        width: 380
        height: 190
        radius: 14
        color: "white"
        border.color: cDanger
        border.width: 2
        scale: cookiePopVisAnim.running ? 0.9 : 1.0
        opacity: cookiePopVisAnim.running ? 0.0 : 1.0

        SequentialAnimation {
            id: cookiePopVisAnim
            PropertyAction { target: cookiePopup; property: "visible"; value: true }
            ParallelAnimation {
                NumberAnimation { target: cookiePopup; property: "scale"; from: 0.85; to: 1.0; duration: 300; easing.type: Easing.OutBack }
                NumberAnimation { target: cookiePopup; property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
            }
        }

        Column {
            anchors { fill: parent; margins: 24 }
            spacing: 14

            Row {
                spacing: 10
                Rectangle {
                    width: 36; height: 36
                    radius: 10
                    color: "#FFF1F0"
                    Text {
                        anchors.centerIn: parent
                        text: "\u26A0"  // warning
                        font.pixelSize: 20
                        color: cDanger
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: "Cookie 已失效"
                        color: cDanger
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "请重新获取洛谷 Cookie 后保存。"
                        color: cText2
                        font.pixelSize: 13
                    }
                }
            }

            Row {
                spacing: 10
                Rectangle {
                    width: 110; height: 36
                    radius: 8
                    color: cPrimary
                    scale: cookieGoSetMa.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: "去设置"
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: cookieGoSetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function() { cookiePopup.visible = false; settingsPanel.visible = true; _relogin() }
                    }
                }
                Rectangle {
                    width: 80; height: 36
                    radius: 8
                    color: "transparent"
                    border.color: cBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "忽略"
                        color: cText2
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cookiePopup.visible = false
                    }
                }
            }
        }

        Timer {
            id: cookieTm
            interval: 12000
            onTriggered: cookiePopup.visible = false
        }
    }

    // ══════════════════════════════════════
    //  SETTINGS PANEL (overlay modal)
    // ══════════════════════════════════════
    Rectangle {
        id: settingsPanel
        visible: false
        z: 600
        anchors.fill: parent
        color: "#00000055"

        // Backdrop click to close
        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                var cx = mouse.x, cy = mouse.y;
                if (cx < sc.x || cx > sc.x + sc.width || cy < sc.y || cy > sc.y + sc.height)
                    settingsPanel.visible = false;
            }
        }

        // Settings card
        Rectangle {
            id: sc
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 720)
            height: Math.min(parent.height - 48, 600)
            radius: 16
            color: "white"
            border.color: cBorder
            border.width: 1
            scale: scOpenAnim.running ? 0.92 : 1.0
            opacity: scOpenAnim.running ? 0.0 : 1.0

            SequentialAnimation {
                id: scOpenAnim
                PropertyAction { target: settingsPanel; property: "visible"; value: true }
                ParallelAnimation {
                    NumberAnimation { target: sc; property: "scale"; from: 0.92; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: sc; property: "opacity"; from: 0.0; to: 1.0; duration: 220 }
                }
            }

            Column {
                anchors { fill: parent; margins: 24 }
                spacing: 14

                // Header row
                Row {
                    width: parent.width
                    height: 28
                    spacing: 8
                    Text {
                        text: "\u2699 设置"
                        color: cText1
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 30; height: 28
                        radius: 6
                        color: scCloseMa.containsHover ? cHover : "transparent"
                        Behavior on color { ColorAnimation { duration: animFast } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            font.pixelSize: 12
                            color: scCloseMa.containsHover ? cText1 : cText3
                        }
                        MouseArea {
                            id: scCloseMa
                            anchors.fill: parent
                            hoverEnabled: true
                            property bool containsHover: containsMouse
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsPanel.visible = false
                        }
                    }
                }

                // Tab bar
                Row {
                    id: sTabs
                    width: parent.height > 0 ? parent.width : 0
                    spacing: 6
                    property int curTab: 0

                    Repeater {
                        model: ["账号", "AI 助手", "通知声音", "服务器"]
                        Rectangle {
                            width: sTabsTabMa.containsHover || index === sTabs.curTab ? 78 : 70
                            height: 32
                            radius: 8
                            color: index === sTabs.curTab ? cPrimary : "transparent"
                            border.color: index === sTabs.curTab ? cPrimary : cBorder
                            border.width: index === sTabs.curTab ? 1 : 1
                            Behavior on width { NumberAnimation { duration: animFast } }
                            Behavior on color { ColorAnimation { duration: animFast } }
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: index === sTabs.curTab ? "white" : cText2
                                font.pixelSize: 12
                                font.weight: index === sTabs.curTab ? Font.DemiBold : Font.Normal
                                Behavior on color { ColorAnimation { duration: animFast } }
                            }
                            MouseArea {
                                id: sTabsTabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                property bool containsHover: containsMouse
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function() { sTabs.curTab = index; stk.currentIndex = index }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: cBorder
                }

                // Tab content stack
                StackLayout {
                    id: stk
                    width: parent.width
                    height: parent.height - 130
                    currentIndex: sTabs.curTab
                    onCurrentIndexChanged: {
                        // 切换 tab 时确保输入框可获得焦点
                    }

                    // ── Tab 0: Account ──
                    ScrollView {
                        id: tab0
                        contentWidth: availableWidth
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        Column {
                            width: tab0.availableWidth
                            spacing: 14

                            // UID field
                            Column {
                                width: parent.width
                                spacing: 5
                                Text { text: "用户 ID (UID)"; color: cText2; font.pixelSize: 12 }
                                Rectangle {
                                    width: parent.width; height: 38
                                    radius: 8
                                    color: "#F7F8FA"
                                    border.color: uidFld.activeFocus ? cPrimary : cBorder
                                    border.width: uidFld.activeFocus ? 1.5 : 1
                                    Behavior on border.color { ColorAnimation { duration: animFast } }
                                    TextField {
                                        id: uidFld
                                        anchors { fill: parent; margins: 10 }
                                        color: cText1
                                        font.pixelSize: 13
                                        placeholderText: "例如 1049425"
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }

                            // Cookie field
                            Column {
                                width: parent.width
                                spacing: 5
                                Text { text: "Cookie"; color: cText2; font.pixelSize: 12 }
                                Rectangle {
                                    width: parent.width; height: 80
                                    radius: 8
                                    color: "#F7F8FA"
                                    border.color: cookieFld.activeFocus ? cPrimary : cBorder
                                    border.width: cookieFld.activeFocus ? 1.5 : 1
                                    Behavior on border.color { ColorAnimation { duration: animFast } }
                                    TextArea {
                                        id: cookieFld
                                        anchors { fill: parent; margins: 10 }
                                        color: cText1
                                        font.pixelSize: 11
                                        wrapMode: TextArea.Wrap
                                        placeholderText: "粘贴洛谷 Cookie..."
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }

                            // Buttons row
                            Row { spacing: 10
                                Rectangle {
                                    width: 100; height: 36
                                    radius: 8
                                    color: cPrimary
                                    scale: testLoginMa.pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: animFast } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "测试登录"
                                        color: "white"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                    MouseArea {
                                        id: testLoginMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() {
                                            var c = cookieFld.text.trim();
                                            if (!c) { toast.show("请输入 Cookie"); return; }
                                            bridge.testLogin(uidFld.text.trim(), c);
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 72; height: 36
                                    radius: 8
                                    color: "transparent"
                                    border.color: cBorder
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "保存"
                                        color: cText2
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() {
                                            try {
                                                var c = JSON.parse(bridge.getConfig() || "{}");
                                                if (!c.luogu) c.luogu = {};
                                                c.luogu.cookie = cookieFld.text.trim();
                                                c.luogu.user_id = uidFld.text.trim();
                                                bridge.saveConfig(JSON.stringify(c));
                                                toast.show("已保存");
                                            } catch(e) {}
                                        }
                                    }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: cBorder }

                            // Current user info
                            Column { spacing: 6
                                Text { text: "当前登录状态"; color: cText2; font.pixelSize: 12 }
                                Text { text: "用户名: " + (myName || "未登录"); color: cText1; font.pixelSize: 13 }
                                Text { text: "UID: " + (myUid || "未知"); color: cText3; font.pixelSize: 12 }
                            }

                            Rectangle {
                                width: 140; height: 34
                                radius: 8
                                color: "transparent"
                                border.color: cBorder
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "刷新头像缓存"
                                    color: cText2
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function() { bridge.refreshAllAvatars(); toast.show("头像缓存已刷新") }
                                }
                            }
                        }
                    }

                    // ── Tab 1: AI Assistant ──
                    ScrollView {
                        id: tab1
                        contentWidth: availableWidth
                        clip: true
                        Column {
                            width: tab1.availableWidth
                            spacing: 14

                            // AI toggle row
                            Row {
                                spacing: 12
                                Text { text: "启用 AI 分析"; color: cText1; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 48; height: 26
                                    radius: 13
                                    color: aiOn ? cPrimary : cBorder
                                    Rectangle {
                                        width: 22; height: 22
                                        radius: 11
                                        color: "white"
                                        x: aiOn ? 24 : 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() { aiOn = !aiOn; _saveCfg() }
                                    }
                                }
                            }

                            // Keyword field
                            Column {
                                width: parent.width
                                spacing: 5
                                Text { text: "重要关键词"; color: cText2; font.pixelSize: 12 }
                                Rectangle {
                                    width: parent.width; height: 38
                                    radius: 8
                                    color: "#F7F8FA"
                                    border.color: kwFld.activeFocus ? cPrimary : cBorder
                                    border.width: kwFld.activeFocus ? 1.5 : 1
                                    TextField {
                                        id: kwFld
                                        anchors { fill: parent; margins: 10 }
                                        color: cText1
                                        font.pixelSize: 13
                                        text: kw
                                        background: Rectangle { color: "transparent" }
                                        onTextChanged: { kw = text; _saveCfg() }
                                    }
                                }
                            }

                            // Mode list
                            Text { text: "AI 模式配置"; color: cText2; font.pixelSize: 12 }
                            ListView {
                                id: modeLv
                                width: parent.width
                                height: 140
                                model: modeList
                                spacing: 8
                                clip: true
                                delegate: Rectangle {
                                    required property string mid
                                    required property string name
                                    required property string prompt
                                    width: modeLv.width
                                    height: 58
                                    radius: 10
                                    color: mid === curMode ? cPrimaryLight : "#FAFBFC"
                                    border.color: mid === curMode ? cPrimary : cBorder
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: animFast } }

                                    Row {
                                        anchors { fill: parent; margins: 12 }
                                        spacing: 10
                                        Column {
                                            width: parent.width - 76
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: name; color: cText1; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            TextField {
                                                width: parent.width
                                                color: cText3
                                                font.pixelSize: 11
                                                text: prompt || ""
                                                background: Rectangle { color: "transparent" }
                                                onTextChanged: _doprompt(mid, text)
                                            }
                                        }
                                        Rectangle {
                                            width: 60; height: 28
                                            radius: 6
                                            color: mid === curMode ? cPrimary : "transparent"
                                            border.color: mid === curMode ? "transparent" : cBorder
                                            border.width: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: mid === curMode ? "使用中" : "选择"
                                                color: mid === curMode ? "white" : cText2
                                                font.pixelSize: 11
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function() {
                                                    curMode = mid;
                                                    bridge.setMode(mid);
                                                    _saveCfg();
                                                    modeLv.model = modeList;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Tab 2: Notifications ──
                    ScrollView {
                        id: tab2
                        contentWidth: availableWidth
                        clip: true
                        Column {
                            width: tab2.availableWidth
                            spacing: 14

                            // Notification toggle
                            Row { spacing: 12
                                Text { text: "弹窗通知"; color: cText1; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 48; height: 26
                                    radius: 13
                                    color: notifyOn ? cPrimary : cBorder
                                    Rectangle {
                                        width: 22; height: 22; radius: 11; color: "white"
                                        x: notifyOn ? 24 : 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 180 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() { notifyOn = !notifyOn; _saveCfg() }
                                    }
                                }
                            }

                            // Sound toggle
                            Row { spacing: 12
                                Text { text: "提示音"; color: cText1; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 48; height: 26
                                    radius: 13
                                    color: soundOn ? cPrimary : cBorder
                                    Rectangle {
                                        width: 22; height: 22; radius: 11; color: "white"
                                        x: soundOn ? 24 : 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 180 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() { soundOn = !soundOn; _saveCfg() }
                                    }
                                }
                            }

                            // Sound file selector
                            Column {
                                width: parent.width
                                spacing: 5
                                Text { text: "提示音文件"; color: cText2; font.pixelSize: 12 }
                                Row {
                                    spacing: 8
                                    width: parent.width
                                    Rectangle {
                                        width: parent.width - 56
                                        height: 36
                                        radius: 8
                                        color: "#F7F8FA"
                                        border.color: cBorder
                                        border.width: 1
                                        Text {
                                            anchors { fill: parent; margins: 10 }
                                            text: soundFile || "系统默认提示音"
                                            color: soundFile ? cText1 : cText3
                                            font.pixelSize: 12
                                            elide: Text.ElideLeft
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Rectangle {
                                        width: 48; height: 36
                                        radius: 8
                                        color: cPrimary
                                        Text {
                                            anchors.centerIn: parent
                                            text: "选择"
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function() {
                                                var f = bridge.pickSoundFile();
                                                if (f) { soundFile = f; _saveCfg(); toast.show("已选择提示音") }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Tab 3: Server & Appearance ──
                    ScrollView {
                        id: tab3
                        contentWidth: availableWidth
                        clip: true
                        Column {
                            width: tab3.availableWidth
                            spacing: 14

                            // Server URL
                            Column {
                                width: parent.width
                                spacing: 5
                                Text { text: "Worker 服务器地址"; color: cText2; font.pixelSize: 12 }
                                Rectangle {
                                    width: parent.width; height: 38
                                    radius: 8
                                    color: "#F7F8FA"
                                    border.color: sUrlFld.activeFocus ? cPrimary : cBorder
                                    border.width: sUrlFld.activeFocus ? 1.5 : 1
                                    TextField {
                                        id: sUrlFld
                                        anchors { fill: parent; margins: 10 }
                                        color: cText1
                                        font.pixelSize: 13
                                        text: svrUrl
                                        placeholderText: "https://lgchat.zhl2010.ccwu.cc"
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }

                            Row { spacing: 8
                                Rectangle {
                                    width: 72; height: 36
                                    radius: 8
                                    color: cPrimary
                                    Text {
                                        anchors.centerIn: parent
                                        text: "保存"
                                        color: "white"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function() { svrUrl = sUrlFld.text.trim(); _saveCfg(); toast.show("已保存") }
                                    }
                                }
                                Rectangle {
                                    width: 72; height: 36
                                    radius: 8
                                    color: "transparent"
                                    border.color: cBorder
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "同步"
                                        color: cText2
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: bridge.forceSync
                                    }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: cBorder }

                            // Quota display
                            Column { spacing: 6
                                Text {
                                    text: "每日配额: " + svrRem + " / " + (svrTot >= 999999 ? "\u221E" : svrTot)
                                    color: svrOk ? cSuccess : cDanger
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: sAllow ? "\u2605 超级允许模式 (无限)" : (svrOk ? "正常使用中" : "已达今日上限")
                                    color: sAllow ? cWarning : cText2
                                    font.pixelSize: 12
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: cBorder }

                            // Appearance section
                            Text { text: "界面外观"; color: cText1; font.pixelSize: 14; font.weight: Font.Bold }

                            // Theme selector
                            Column {
                                width: parent.width
                                spacing: 8
                                Text { text: "主题配色"; color: cText2; font.pixelSize: 12; font.weight: Font.DemiBold }
                                Row { spacing: 10
                                    Repeater {
                                        model: ["blue", "dark", "pink", "green", "purple"]
                                        Rectangle {
                                            width: 52; height: 52
                                            radius: 12
                                            color: modelData === "blue" ? "#1677FF" :
                                                   modelData === "dark" ? "#1A1A1A" :
                                                   modelData === "pink" ? "#FF6B9D" :
                                                   modelData === "green" ? "#00B42A" : "#8B5CF6"
                                            border.width: currentTheme === modelData ? 3 : 1
                                            border.color: currentTheme === modelData ? cPrimary : cBorder
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData === "blue" ? "蓝" :
                                                       modelData === "dark" ? "暗" :
                                                       modelData === "pink" ? "粉" :
                                                       modelData === "green" ? "绿" : "紫"
                                                color: modelData === "dark" ? "white" : "white"
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: applyTheme(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            // Background type selector
                            Row { spacing: 8
                                Text { text: "背景类型:"; color: cText2; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Repeater {
                                    model: ["纯色", "渐变", "图片"]
                                    Rectangle {
                                        width: bgTypeMa.containsHover || (bgType === ("solid","gradient","image")[index]) ? 54 : 48
                                        height: 28
                                        radius: 6
                                        color: bgType === ("solid","gradient","image")[index] ? cPrimary : "transparent"
                                        border.color: bgType === ("solid","gradient","image")[index] ? cPrimary : cBorder
                                        border.width: 1
                                        Behavior on width { NumberAnimation { duration: animFast } }
                                        Behavior on color { ColorAnimation { duration: animFast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 11
                                            color: bgType === ("solid","gradient","image")[index] ? "white" : cText2
                                        }
                                        MouseArea {
                                            id: bgTypeMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function() { bgType = ("solid","gradient","image")[index]; _saveBg() }
                                        }
                                    }
                                }
                            }

                            // Solid color picker (when solid)
                            Column {
                                visible: bgType === "solid"
                                width: parent.width
                                spacing: 5
                                Text { text: "背景颜色"; color: cText2; font.pixelSize: 12 }
                                Row { spacing: 8
                                    Repeater {
                                        model: ["#F5F6F7", "#FFF7E6", "#F0FDF4", "#EFF6FF", "#FDF4FF", "#FFF0F0", "#E8F3FF", "#F5F5F5", "#1D2129"]
                                        Rectangle {
                                            width: 28; height: 28
                                            radius: 6
                                            color: modelData
                                            border.width: bgSolidColor === modelData ? 2 : 1
                                            border.color: bgSolidColor === modelData ? cPrimary : cBorder
                                            scale: bgClrMa.containsMouse ? 1.1 : 1.0
                                            Behavior on scale { NumberAnimation { duration: animFast } }
                                            MouseArea {
                                                id: bgClrMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function() { bgSolidColor = modelData; _saveBg() }
                                            }
                                        }
                                    }
                                }
                            }

                            // Gradient colors (when gradient)
                            Column {
                                visible: bgType === "gradient"
                                width: parent.width
                                spacing: 5
                                Text { text: "渐变起始色"; color: cText2; font.pixelSize: 12 }
                                Row { spacing: 8
                                    Repeater {
                                        model: ["#E8EEFE", "#FFE4E1", "#E0F7FA", "#F3E5F5", "#FFF8E1", "#E8F5E9", "#FCE4EC", "#E3F2FD"]
                                        Rectangle {
                                            width: 28; height: 28
                                            radius: 6
                                            color: modelData
                                            border.width: bgGradientStart === modelData ? 2 : 1
                                            border.color: bgGradientStart === modelData ? cPrimary : cBorder
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function() { bgGradientStart = modelData; _saveBg() }
                                            }
                                        }
                                    }
                                }
                                Text { text: "渐变结束色"; color: cText2; font.pixelSize: 12 }
                                Row { spacing: 8
                                    Repeater {
                                        model: ["#F5F0F0", "#FFF0DB", "#E0F2F1", "#FCE4EC", "#FFF9C4", "#DCEDC8", "#F8BBD0", "#BBDEFB"]
                                        Rectangle {
                                            width: 28; height: 28
                                            radius: 6
                                            color: modelData
                                            border.width: bgGradientEnd === modelData ? 2 : 1
                                            border.color: bgGradientEnd === modelData ? cPrimary : cBorder
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function() { bgGradientEnd = modelData; _saveBg() }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Save background config function
    function _saveBg() {
        try {
            var c = JSON.parse(bridge.getConfig() || "{}");
            if (!c.bg) c.bg = {};
            c.bg.type = bgType;
            c.bg.solid_color = bgSolidColor;
            c.bg.gradient_start = bgGradientStart;
            c.bg.gradient_end = bgGradientEnd;
            c.bg.image_url = bgImageUrl;
            bridge.saveConfig(JSON.stringify(c));
        } catch(e) {}
    }

    // ══════════════════════════════════════
    //  IMPORTANT MESSAGE POPUP (bottom-right)
    // ══════════════════════════════════════
            //   Important message popup (beautified) ──
        Rectangle {
            id: impPopup
            visible: false
            z: 900
            anchors { right: parent.right; bottom: parent.bottom }
            anchors.rightMargin: 20
            anchors.bottomMargin: 20
            width: 360
            height: 200
            radius: 16
            
            // Gradient background
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#FFF1F0" }
                GradientStop { position: 1.0; color: "#FFFFFF" }
            }
            
            border.color: cDanger
            border.width: 2
            
            // Shadow
            layer.enabled: true
            
            // Entrance animation
            PropertyAnimation on scale {
                id: impEnterAnim
                from: 0.8
                to: 1.0
                duration: 400
                easing.type: Easing.OutBack
            }
            
            PropertyAnimation on opacity {
                id: impOpacityAnim
                from: 0.0
                to: 1.0
                duration: 300
            }
            
            Timer {
                id: impTimer
                interval: 8000
                onTriggered: {
                    impOpacityAnim.from = 1.0;
                    impOpacityAnim.to = 0.0;
                    impOpacityAnim.start();
                    impHideTimer.start();
                }
            }
            
            Timer {
                id: impHideTimer
                interval: 300
                onTriggered: impPopup.visible = false
            }
            
            Column {
                anchors { fill: parent; margins: 20 }
                spacing: 12
                
                Row {
                    spacing: 10
                    
                    // Warning icon
                    Rectangle {
                        width: 36; height: 36
                        radius: 10
                        color: cDanger
                        
                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            color: "white"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }
                    }
                    
                    Column {
                        spacing: 4
                        Text {
                            text: "重要消息检测"
                            color: cDanger
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                        Text {
                            id: impSenderName
                            text: ""
                            color: cText2
                            font.pixelSize: 13
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Close button
                    Rectangle {
                        width: 28; height: 28
                        radius: 14
                        color: closeMa.containsMouse ? cHover : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: cText3
                            font.pixelSize: 14
                        }
                        
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                impPopup.visible = false;
                            }
                        }
                    }
                }
                
                // Message content
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 10
                    color: "#F7F8FA"
                    
                    Text {
                        id: impContent
                        anchors { fill: parent; margins: 12 }
                        text: ""
                        color: cText1
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                }
                
                // Tip text
                Text {
                    id: impTip
                    width: parent.width
                    text: ""
                    color: cDanger
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
            
            function show(mid, content, sender_name, sender_uid, analysis, tip) {
                impContent.text = content || "";
                impSenderName.text = sender_name || "";
                impTip.text = tip || "";
                impPopup.visible = true;
                impEnterAnim.start();
                impOpacityAnim.from = 0.0;
                impOpacityAnim.to = 1.0;
                impOpacityAnim.start();
                impTimer.start();
            }
        }
        
        function onImportantPopup(mid, content, sender_name, sender_uid, analysis, tip) {
            impName.text = "发件人: " + sender_name
            impContent.text = content
            impTip.text = tip || ""
            impAnim.restart()
        }
    }
}
