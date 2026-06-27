import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: win
    visible: true
    width: 1300; height: 850
    minimumWidth: 820; minimumHeight: 520
    flags: Qt.FramelessWindowHint | Qt.Window | Qt.WindowMinMaxButtonsHint
    color: "transparent"

    property int themeMode: 2
    property string acc: "#6366F1"
    property bool dark: themeMode === 1
    function clt(light, dk) { return dark ? dk : light }

    readonly property color bg1: clt("#EEF2FF","#080C1A")
    readonly property color bg2: clt("#F5F7FF","#0B1020")
    readonly property color bg3: clt("#E8EDFC","#060A16")
    readonly property color sideBg: clt("#E2E8F8","#060A14")
    readonly property color cardBg: clt("#FFFFFF","#0D1324")
    readonly property color cardBg2: clt("#F8FAFD","#0F1628")
    readonly property color text1: clt("#1A1C2E","#E4E8F4")
    readonly property color text2: clt("#5B6080","#8A94B8")
    readonly property color text3: clt("#9BA0B8","#5A6280")
    readonly property color bd1: clt("#D8DDF0","#1A2240")
    readonly property color bd2: clt("#E5EAF8","#1E2848")
    readonly property color hover: clt("#EAF0FF","#151E35")
    readonly property color select: clt("#DDE6FF","#192848")
    readonly property color accent2: "#818CF8"
    readonly property color accent3: "#A78BFA"
    readonly property color accent4: "#06B6D4"
    readonly property color green: "#10B981"
    readonly property color red: "#EF4444"
    readonly property color orange: "#F59E0B"

    function nameColor(c) {
        var m = {"Red":"#FF3B30","Orange":"#FF9500","Green":"#10B981","Blue":"#3B82F6","Brown":"#A2845E","Purple":"#8B5CF6","Gray":"#8E8E93"}
        return m[c] || text1
    }

    property string curUid: ""
    property string curName: ""
    property string curColor: ""
    property string myUid: ""
    property string myName: ""
    property string wsStat: "offline"
    property bool aiOn: false
    property int favMode: 0
    property var chatList: []
    property int listVer: 0
    property bool loading: false
    property bool useDefaultAI: true
    property string customApiUrl: ""
    property string customApiKey: ""
    property string customApiModel: ""
    property string customSysPrompt: ""
    property string sysPrompt: ""
    property string qTemplate: ""
    property var favList: []
    property var pinList: []
    property var msgs: []
    property int msgPage: -1
    property bool hasMore: false
    property bool msgLoading: false
    property bool showList: true
    property int nextLoadPage: -1
    property int serverRem: 50
    property int serverTotal: 50
    property string profUid: ""
    property string profName: ""
    property string notifSoundFile: ""
    property bool notifSoundEnabled: true
    property string notifSoundType: "system"
    property bool notifPopupEnabled: true
    property string notifPopupMode: "ai"
    property string popupPrefix: ""
    property string popupSuffix: ""
    property string keyword: "zhl重要信息"

    function toast(m) { tt.text = m; ta.restart() }
    function reloadCfg() {
        var c = JSON.parse(bridge.getConfig())
        myUid = c.luogu ? (c.luogu.user_id || "") : ""
        themeMode = c.theme ? (c.theme.mode || 2) : 2
        acc = c.theme ? (c.theme.accent || "#6366F1") : "#6366F1"
        favList = c.favorites || []
        pinList = c.pins || []
        aiOn = c.ai ? (c.ai.enabled || false) : false
        useDefaultAI = c.ai ? (c.ai.default !== false) : true
        sysPrompt = c.ai ? (c.ai.system_prompt || "") : ""
        qTemplate = c.ai ? (c.ai.question_template || "") : ""
        keyword = c.ai ? (c.ai.important_keyword || "zhl重要信息") : "zhl重要信息"
        if (c.ai && c.ai.custom) {
            customApiUrl = c.ai.custom.base_url || ""
            customApiKey = c.ai.custom.api_key || ""
            customApiModel = c.ai.custom.model || ""
            customSysPrompt = c.ai.custom.custom_system_prompt || ""
        }
        if (c.notification) {
            notifSoundEnabled = c.notification.sound_enabled !== false
            notifSoundType = c.notification.sound_type || "system"
            notifSoundFile = c.notification.sound_file || ""
            notifPopupEnabled = c.notification.enabled !== false
            notifPopupMode = c.notification.popup_mode || "ai"
            popupPrefix = c.notification.popup_prefix || ""
            popupSuffix = c.notification.popup_suffix || ""
        }
    }

    function refreshListData(j) {
        try {
            var raw = JSON.parse(j) || []
            for (var i = 0; i < raw.length; i++) {
                var u = String(raw[i].uid || (raw[i].user ? raw[i].user.uid : ""))
                if (!u) u = "unknown_" + i
                raw[i]._u = u
                raw[i]._p = pinList.indexOf(u) >= 0
            }
            var q = si.text.trim().toLowerCase()
            if (q) {
                raw = raw.filter(function(it) {
                    return (it.name || "").toLowerCase().indexOf(q) >= 0 || (it.uid || "").indexOf(q) >= 0
                })
            }
            raw.sort(function(a, b) {
                if (a._p && !b._p) return -1
                if (!a._p && b._p) return 1
                return (b.time || 0) - (a.time || 0)
            })
            chatList = raw; listVer += 1
        } catch(e) { chatList = []; listVer += 1 }
        loading = false
    }
    function refreshList() {
        loading = true
        try { var r = bridge.getChatList(); refreshListData(r) }
        catch(e) { chatList = []; listVer += 1 }
        loading = false
    }
    function loadMsgs(u, p) {
        curUid = u
        if (p < 0) { msgs = []; msgPage = -1; hasMore = false; nextLoadPage = -1 }
        bridge.getMessages(u, p)
    }
    function selUser(u, n, c) {
        if (!u) return
        curUid = u; curName = n || ("用户"+u); curColor = c || ""
        loadMsgs(u, -1); bridge.requestAvatar(u)
    }
    function sendMsg() {
        var t = mi.text.trim()
        if (!t || !curUid) return
        bridge.sendMessage(curUid, t)
        msgs.push({id:0,content:t,from_uid:myUid,sender:{},"sender.name":myName,time:Math.floor(Date.now()/1000),is_me:true})
        mi.text = ""
        Qt.callLater(function() { msgList.positionViewAtEnd() })
    }
    function tf(ts) {
        if (!ts) return ""
        var d = new Date(ts*1000)
        return ("0"+d.getHours()).slice(-2)+":"+("0"+d.getMinutes()).slice(-2)
    }
    function td(ts) {
        if (!ts) return ""
        var d = new Date(ts*1000); var n = new Date()
        if (d.toDateString()===n.toDateString()) return ""
        var y = new Date(n); y.setDate(y.getDate()-1)
        if (d.toDateString()===y.toDateString()) return "昨天"
        return (d.getMonth()+1)+"/"+d.getDate()
    }
    function tFav(uid) { var i=favList.indexOf(uid); if(i>=0)favList.splice(i,1);else favList.push(uid);us() }
    function tPin(uid) { var i=pinList.indexOf(uid); if(i>=0)pinList.splice(i,1);else pinList.push(uid);us() }
    function us() { bridge.saveConfig(JSON.stringify({favorites:favList,pins:pinList})) }
    function cycTheme() { themeMode=(themeMode+1)%3; bridge.saveConfig(JSON.stringify({theme:{mode:themeMode,accent:acc}})) }
    function showProf(u,n) { profUid=u; profName=n }
    function showPopupNotify(title,body,uid,sender) {
        notifTitle=title; notifBody=body; notifSender=sender||""; notifUid=uid||""
        notifExpanded=false; notifAnim.restart(); notifPopup.open()
    }

    Connections {
        target: bridge
        function onWsStatus(s) { wsStat = s }
        function onNewMessage(m,c,sn,su,ts) {
            if (su===curUid) { msgs.push({id:0,content:c,from_uid:su,"sender.name":sn,time:ts,is_me:false}); Qt.callLater(function(){msgList.positionViewAtEnd()}) }
            bridge.refreshChatList()
        }
        function onImportantMessage(m,c,sn,su,tip,ts) {
            if (notifPopupEnabled) showPopupNotify("来自 " + sn, tip || c, m, sn)
            if (notifSoundEnabled) {
                if (notifSoundType === "system") bridge.playSound("")
                else if (notifSoundFile) bridge.playSound(notifSoundFile)
            }
        }
        function onChatListReady(j) { refreshListData(j) }
        function onLoginTestResult(s,uid,name,e) {
            if (s) { myUid=uid; myName=name||("用户"+uid); toast("已登录: "+myName); refreshList() }
            else { toast("失败: "+(e||"登录失败")) }
        }
        function onMessagesReady(j,pg,more) {
            var d=JSON.parse(j); var newMsgs=d.messages||[]; var tp=d.totalPages||1
            if (pg<0) { msgs=newMsgs; nextLoadPage=tp-1; hasMore=tp>1&&nextLoadPage>=1; Qt.callLater(function(){msgList.positionViewAtEnd()}) }
            else { msgs=newMsgs.concat(msgs); nextLoadPage=pg-1; hasMore=nextLoadPage>=1 }
        }
        function onMessagesLoading(b) { msgLoading=b }
        function onReplySent(s,m) { toast(s?"已发送":"失败: "+(m||"")) }
        function onShowErrorPopup(msg,rid) { showError(msg,function(){
            if(rid.indexOf("msg_")===0){var p=rid.substring(4).split("_");bridge.getMessages(p[0],parseInt(p[1])||1)}
            else if(rid==="refresh")bridge.refreshChatList()
            else if(rid.indexOf("send_")===0)bridge.sendMessage(rid.substring(5),mi.text)
        })}
        function onConfigChanged() { reloadCfg() }
        function onServerSyncResult(j) { var s=JSON.parse(j); serverRem=s.remaining||0; serverTotal=s.total||0 }
        function onAvatarReady(uid,path) {}
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: 1; radius: 14; clip: true
        gradient: Gradient {
            GradientStop { position:0; color:clt("#E8EEF8","#060A16") }
            GradientStop { position:0.35; color:clt("#EEF2FD","#080D1A") }
            GradientStop { position:0.65; color:clt("#F0F4FF","#070C18") }
            GradientStop { position:1; color:clt("#E4EAF6","#050914") }
        }
        Rectangle {
            anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right
            height:1; color:clt(Qt.rgba(1,1,1,0.25),Qt.rgba(1,1,1,0.04))
        }

        RowLayout { anchors.fill:parent; spacing:0

            // ═══ LEFT SIDEBAR ═══
            Rectangle {
                Layout.preferredWidth: 60; Layout.fillHeight: true
                color: clt(sideBg,"#040810")
                Column {
                    anchors.fill:parent; topPadding: 14; bottomPadding: 12; spacing: 6
                    // 头像
                    Rectangle {
                        width:44; height:44; radius:22; anchors.horizontalCenter:parent.horizontalCenter
                        color: clt("#D8DDF0","#1E2850")
                        Image {
                            anchors.fill:parent; anchors.margins:2
                            source: myUid ? "https://cdn.luogu.com.cn/upload/usericon/" + myUid + ".png" : ""
                            fillMode: Image.PreserveAspectCrop; asynchronous:true
                            onStatusChanged: if(status===Image.Error) source=""
                        }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{if(myUid)showProf(myUid,myName)} }
                    }
                    Item { height: 10; width: 1 }
                    // 列表折叠按钮 — 精致悬浮按钮
                    Rectangle {
                        id: collapseBtn; width: 30; height: 30; radius: 15
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: collapseHover.containsMouse ? Qt.lighter(acc, 1.2) : acc
                        scale: collapseHover.containsMouse ? 1.1 : 1.0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: "≡"; font.pixelSize: 14; color: "white"; font.bold: true }
                        MouseArea { id: collapseHover; anchors.fill:parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: showList = !showList }
                    }
                    Item { Layout.fillHeight:true; width:1 }
                    // 主题
                    Rectangle {
                        width:40; height:40; radius:12; anchors.horizontalCenter:parent.horizontalCenter
                        color: "transparent"
                        Text { anchors.centerIn:parent; text: themeMode===0?"☀":(themeMode===1?"☾":"◐"); font.pixelSize:20; color:clt(text2,text3) }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true; onClicked:cycTheme() }
                    }
                    // 设置
                    Rectangle {
                        width:40; height:40; radius:12; anchors.horizontalCenter:parent.horizontalCenter
                        color: "transparent"
                        Text { anchors.centerIn:parent; text:"⚙"; font.pixelSize:22; color:clt(text2,text3) }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true; onClicked:{reloadCfg();stg.open()} }
                    }
                }
            }

            Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; color:clt(bd1,bd2) }

            // ═══ MIDDLE PANEL (可折叠) ═══
            Rectangle {
                id: midPanel
                Layout.preferredWidth: showList ? 310 : 0; Layout.fillHeight: true
                clip: true
                color: clt(cardBg,"#0A1020")
                visible: showList
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: searchBar
                    anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right
                    height: 62; color:"transparent"
                    Row { anchors.centerIn:parent; spacing: 8
                        Rectangle {
                            width: 210; height: 38; radius: 19
                            color: clt("#EEF0F8","#121830"); border.color: clt(bd1,bd2); border.width: 1
                            Row { anchors.fill:parent; leftPadding: 16; spacing: 8
                                Text { text:"⌕"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter; color: clt(text3,text3) }
                                TextInput {
                                    id: si; anchors.verticalCenter: parent.verticalCenter; width: 155
                                    font.pixelSize: 15; color: clt(text1,text1)
                                    onTextChanged: refreshList()
                                }
                            }
                        }
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: clt("#EEF0F8","#121830"); border.color: clt(bd1,bd2); border.width: 1
                            Text { anchors.centerIn:parent; text:"↻"; font.pixelSize: 20; color: clt(text2,text2) }
                            MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: bridge.refreshChatList() }
                        }
                    }
                }
                Rectangle { anchors.top:searchBar.bottom; anchors.left:parent.left; anchors.right:parent.right; height:1; color:clt(bd1,bd2) }

                ScrollView {
                    anchors.top: parent.top; anchors.topMargin: 63
                    anchors.bottom: parent.bottom; anchors.left: parent.left
                    anchors.right: parent.right; anchors.rightMargin: 3
                    clip: true
                    ScrollBar.vertical: ScrollBar{policy:ScrollBar.AsNeeded; width:4; contentItem:Rectangle{radius:2; color:clt("#C0C4D8","#3A4260"); opacity:0.35}}
                    Column {
                        id: midCol; width: parent.width; spacing: 0
                        // 加载指示器
                        Rectangle {
                            visible: loading
                            width: 140; height: 56; radius: 28; anchors.horizontalCenter: parent.horizontalCenter
                            color: clt(Qt.rgba(0.94,0.95,0.98,0.95),Qt.rgba(0.06,0.1,0.2,0.95))
                            Row { anchors.centerIn:parent; spacing: 10
                                Rectangle { width: 20; height: 20; radius: 10; anchors.verticalCenter:parent.verticalCenter; color:acc
                                    RotationAnimation on rotation{from:0;to:360;duration:800;loops:Animation.Infinite;running:loading} }
                                Text { text:"加载中..."; font.pixelSize: 15; color: clt(text1,text1); anchors.verticalCenter:parent.verticalCenter }
                            }
                        }
                        Repeater {
                            model: chatList
                            delegate: Rectangle {
                                width: parent.width; height: 74
                                color: {
                                    var u = String(modelData.uid || (modelData.user ? modelData.user.uid : ""))
                                    return curUid === u ? clt(select,"#162050") : (hvr.containsMouse ? clt(hover,"#111D38") : "transparent")
                                }
                                Rectangle {
                                    visible: curUid === String(modelData.uid || "")
                                    anchors.left:parent.left; anchors.top:parent.top; anchors.bottom:parent.bottom
                                    width: 3; color:acc; radius:1.5
                                }
                                property string uid: String(modelData.uid || "")
                                property string name: modelData.name || (modelData.user ? modelData.user.name : "") || ("用户" + uid)
                                property string last: modelData.content || ""
                                property int tm: modelData.time || 0
                                property string ucolor: modelData.color || ""
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Row {
                                    anchors.fill:parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                                    Rectangle {
                                        width: 48; height: 48; radius: 24; anchors.verticalCenter: parent.verticalCenter
                                        color: clt("#E4E8F4","#152040")
                                        Image {
                                            anchors.fill:parent; anchors.margins:1
                                            source: uid ? "https://cdn.luogu.com.cn/upload/usericon/" + uid + ".png" : ""
                                            fillMode:Image.PreserveAspectCrop; asynchronous:true
                                        }
                                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: showProf(uid,name) }
                                        Rectangle {
                                            visible: pinList.indexOf(uid) >= 0
                                            width: 18; height: 18; radius: 9
                                            x: parent.width - 14; y: parent.height - 14
                                            color: orange
                                            Text { anchors.centerIn:parent; text:"★"; font.pixelSize: 10; color:"white" }
                                        }
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter; width: 170; spacing: 4
                                        Row {
                                            spacing: 4
                                            Text { text: name; width: 110; elide:Text.ElideRight; font.pixelSize: 16; font.weight:Font.DemiBold; color:nameColor(ucolor) }
                                            Item { Layout.fillWidth:true; height:1 }
                                            Text { text: td(tm); font.pixelSize: 11; color: clt(text3,text3) }
                                        }
                                        Text {
                                            text: last.length > 24 ? last.substring(0, 24) + "…" : last
                                            font.pixelSize: 14; color: clt(text2,text2); elide:Text.ElideRight; width: 165
                                        }
                                    }
                                }
                                MouseArea {
                                    id: hvr; anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(m) {
                                        if (m.button === Qt.RightButton) { cm._u = uid; cm.popup() }
                                        else { selUser(uid, name, ucolor) }
                                    }
                                }
                                Row {
                                    anchors.right: parent.right; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                    visible: hvr.containsMouse || favList.indexOf(uid) >= 0 || pinList.indexOf(uid) >= 0
                                    Rectangle {
                                        width: 28; height: 28; radius: 8
                                        color: favList.indexOf(uid) >= 0 ? "#FDE68A" : "transparent"
                                        Text { anchors.centerIn:parent; text: favList.indexOf(uid) >= 0 ? "★" : "☆"; font.pixelSize: 13; color: favList.indexOf(uid) >= 0 ? "#D97706" : clt(text3,text3) }
                                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: tFav(uid) }
                                    }
                                    Rectangle {
                                        width: 28; height: 28; radius: 8
                                        color: pinList.indexOf(uid) >= 0 ? "#C7D2FE" : "transparent"
                                        Text { anchors.centerIn:parent; text:"◉"; font.pixelSize: 13; color: pinList.indexOf(uid) >= 0 ? "#4F46E5" : clt(text3,text3) }
                                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: tPin(uid) }
                                    }
                                }
                            }
                        }
                        Rectangle { width:parent.width; height:200; visible:chatList.length===0; color:"transparent"
                            Column { anchors.centerIn:parent; spacing:12
                                Text { anchors.horizontalCenter:parent.horizontalCenter; text:"✉"; font.pixelSize:50; color:clt(text3,text3) }
                                Text { anchors.horizontalCenter:parent.horizontalCenter; text:"暂无消息"; font.pixelSize:16; color:clt(text3,text3) }
                            }
                        }
                    }
                }
            }

            // DIVIDER
            Rectangle {
                id: midRightDiv; Layout.preferredWidth: 8; Layout.fillHeight: true
                color: "transparent"
                property real startX: 0; property real startW: 0
                // 视觉分隔线 — 居中细线
                Rectangle { anchors.centerIn:parent; width:1.5; height:parent.height; color:clt(bd1,bd2) }
                // 拖拽手柄 — 仅悬停时显示
                Rectangle {
                    anchors.centerIn: parent; width: 3; height: 50; radius: 1.5
                    color: panelDrag.containsMouse ? acc : "transparent"
                    opacity: panelDrag.containsMouse ? 0.5 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: panelDrag; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.SplitHCursor
                    drag{target:midRightDiv; axis:Drag.XAxis}
                    onPressed: function(mouse){ midRightDiv.startW=midPanel.Layout.preferredWidth; midRightDiv.startX=mouse.x }
                    onMouseXChanged: function(mouse){ if(drag.active) midPanel.Layout.preferredWidth=Math.max(180,Math.min(500,midRightDiv.startW+mouse.x-midRightDiv.startX)) }
                }
            }

            // ═══ RIGHT — CHAT PANEL ═══
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: clt(cardBg,"#090F1C")

                Column { anchors.fill:parent; spacing:0

                    Rectangle {
                        width: parent.width; height: 60; color:"transparent"
                        gradient: Gradient {
                            GradientStop{position:0;color:clt("#F4F6FC","#0C1428")}
                            GradientStop{position:1;color:clt("#EDF0F8","#080F20")}
                        }
                        Rectangle { anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:1;color:clt(bd1,bd2) }

                        MouseArea {
                            anchors.left:parent.left; anchors.right:winCtrls.left
                            anchors.top:parent.top; anchors.bottom:parent.bottom; anchors.leftMargin:16
                            property point lp
                            onPressed: function(mouse){ lp = Qt.point(mouse.x, mouse.y) }
                            onPositionChanged: function(mouse){ win.x += mouse.x - lp.x; win.y += mouse.y - lp.y }
                            onDoubleClicked: function(mouse){ if(win.visibility===Window.Maximized) win.showNormal(); else win.showMaximized() }

                            Row { anchors.verticalCenter:parent.verticalCenter; spacing:12
                                Rectangle { width:42; height:42; radius:21; color:clt("#E4E8F4","#152040")
                                    Image { anchors.fill:parent; anchors.margins:1
                                        source: curUid ? "https://cdn.luogu.com.cn/upload/usericon/" + curUid + ".png" : ""
                                        fillMode:Image.PreserveAspectCrop; asynchronous:true }
                                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                                        onClicked: { if(curUid){ tPin(curUid); toast(pinList.indexOf(curUid)>=0?"已置顶":"已取消置顶"); refreshList() } } }
                                }
                                Column { anchors.verticalCenter:parent.verticalCenter; spacing:2
                                    Row { spacing:8
                                        Text { text:curName||"选择联系人"; font.pixelSize:17; font.weight:Font.DemiBold; color:nameColor(curColor) }
                                    }
                                    Row { spacing:6
                                        Rectangle { width:8;height:8;radius:4;anchors.verticalCenter:parent.verticalCenter;color:wsStat==="connected"?green:red }
                                        Text { text:wsStat==="connected"?"在线":"离线"; font.pixelSize:12; color:clt(text3,text3) }
                                    }
                                }
                            }
                        }

                        Row {
                            id: winCtrls; anchors.right:parent.right; anchors.rightMargin:16
                            anchors.verticalCenter:parent.verticalCenter; spacing:12
                            // 加载指示器（右上角）
                            Row { visible: msgLoading; spacing: 6; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; color: acc
                                    RotationAnimation on rotation{from:0;to:360;duration:700;loops:Animation.Infinite;running:msgLoading} }
                                Text { text: "加载中"; font.pixelSize: 12; color: acc; anchors.verticalCenter: parent.verticalCenter }
                            }
                            // 刷新消息
                            Rectangle { width:18;height:18;radius:9;color:clt("#C8CDE0","#283050")
                                Text { anchors.centerIn:parent;text:"↻";font.pixelSize:11;color:clt("#5A5E78","#7880A0") }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true
                                    onClicked:{if(curUid)loadMsgs(curUid,-1)} }
                            }
                            Rectangle { width:18;height:18;radius:9;color:xmh.containsMouse?"#10B981":"#059669"
                                MouseArea { id:xmh;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true
                                    onClicked:{if(win.visibility===Window.Maximized)win.showNormal();else win.showMaximized()} }
                            }
                            Rectangle { width:18;height:18;radius:9;color:xnh.containsMouse?"#F59E0B":"#D97706"
                                MouseArea { id:xnh;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true;onClicked:win.showMinimized() }
                            }
                            Rectangle { width:18;height:18;radius:9;color:xch.containsMouse?"#EF4444":"#DC2626"
                                MouseArea { id:xch;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true;onClicked:Qt.quit() }
                            }
                        }
                    }

                    // MESSAGE LIST
                    Item {
                        id:msgArea; width:parent.width; height:parent.height - 185; clip:true

                        ListView {
                            id: msgList
                            anchors.top: parent.top; anchors.left: parent.left; anchors.leftMargin: 4
                            anchors.right: parent.right; anchors.rightMargin: 4; anchors.bottom: parent.bottom; clip:true
                            spacing: 8; topMargin: 14; bottomMargin: 14
                            model: msgs; boundsBehavior:Flickable.StopAtBounds; focus:true

                            header: Rectangle {
                                width: msgList.width - 14; height: hasMore && msgList.atYBeginning && msgs.length>0 ? 40 : 0
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                radius: 12; color:clt("#E4EAFA","#101D38"); clip:true
                                Row { anchors.centerIn:parent; spacing:8
                                    Text { text:"↑"; font.pixelSize:15; color:acc }
                                    Text { text:"加载更早的消息"; font.pixelSize:14; color:acc }
                                }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                                    onClicked:{loadMsgs(curUid,nextLoadPage)} }
                                Behavior on height{NumberAnimation{duration:180}}
                            }

                            delegate: Item {
                                id:msgRow; width: msgList.width - 14
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                height: bubble.height + 8
                                property bool im: modelData.is_me || (modelData.sender&&String(modelData.sender.uid||"")===myUid) || String(modelData.from_uid||"")===myUid
                                property string txt: (modelData.content || modelData.text || "")
                                property string msgId: String(modelData.id || 0)

                                // 对方头像
                                Rectangle { visible:!im; opacity:im?0:1; width:30;height:30;radius:15
                                    anchors.left:parent.left; anchors.leftMargin:4; y:parent.height-height-4
                                    color:clt("#DCE0F0","#1A2848"); clip:true
                                    Image { anchors.centerIn:parent; width:28; height:28
                                        source:curUid?"https://cdn.luogu.com.cn/upload/usericon/"+curUid+".png":""
                                        fillMode:Image.PreserveAspectCrop;asynchronous:true }
                                }

                                // 气泡
                                Rectangle {
                                    id: bubble
                                    property int bw: Math.min(Math.max(String(txt).length*14+52,60), parent.width-52)
                                    width: bw; height: Math.max(txtEdit.contentHeight+24, 34)
                                    x: im ? parent.width-width-8 : 40; y: 3; radius: 12
                                    color: im ? acc : clt(cardBg2,"#111D35")
                                    border.width: im?0:1; border.color: clt("#D0D6E8","#1E2E50")

                                    TextEdit {
                                        id:txtEdit; anchors.left:parent.left; anchors.leftMargin:12
                                        anchors.right:parent.right; anchors.rightMargin:12
                                        anchors.top:parent.top; anchors.topMargin:6
                                        height:contentHeight; readOnly:true; selectByMouse:true
                                        text:msgRow.txt; font.pixelSize:15; color:im?"#FFFFFF":clt(text1,text1)
                                        wrapMode:TextEdit.WordWrap; textFormat:TextEdit.PlainText
                                    }

                                    Text {
                                        anchors.right:parent.right; anchors.rightMargin:10
                                        anchors.bottom:parent.bottom; anchors.bottomMargin:3
                                        text: td(modelData.time||0) + " " + tf(modelData.time||0)
                                        font.pixelSize:10; color:im?"#ffffff50":clt(text3,text3)
                                    }

                                    // 右键菜单 — 使用 TapHandler 避免与 TextEdit 冲突
                                    TapHandler {
                                        acceptedButtons: Qt.RightButton
                                        onTapped: function(eventPoint, button){
                                            msgMenu._id = String(modelData.id || 0)
                                            msgMenu._txt = msgRow.txt
                                            msgMenu.popup()
                                        }
                                    }
                                }
                            }

                            // 空状态
                            Rectangle { anchors.centerIn:parent; visible:msgs.length===0&&!msgLoading; width:200;height:120;color:"transparent"
                                Column { anchors.centerIn:parent; spacing:14
                                    Text { anchors.horizontalCenter:parent.horizontalCenter;text:curUid?"✉":"👋";font.pixelSize:50;color:clt(text3,text3) }
                                    Text { anchors.horizontalCenter:parent.horizontalCenter;text:curUid?"发送第一条消息":"左侧选择联系人";font.pixelSize:16;color:clt(text3,text3) }
                                }
                            }

                            ScrollBar.vertical: ScrollBar{policy:ScrollBar.AsNeeded; width:5; contentItem:Rectangle{radius:3;color:clt("#A0A8C0","#404860");opacity:0.5}}
                        }
                    }

                    // 分隔线
                    Rectangle { width:parent.width; height:1; color:clt(bd1,bd2) }

                    // 输入区域
                    Rectangle {
                        id: inputArea; width:parent.width; height: 124; color:"transparent"
                        gradient: Gradient {
                            GradientStop{position:0;color:clt("#F4F6FC","#0D1324")}
                            GradientStop{position:1;color:clt("#ECF0F8","#090F1C")}
                        }
                        Column {
                            anchors.fill:parent; anchors.leftMargin:16; anchors.rightMargin:16; anchors.bottomMargin:10; spacing:8
                            Rectangle {
                                width:parent.width; height:inputArea.height-42; radius:14
                                gradient: Gradient {
                                    GradientStop{position:0;color:clt("#FFFFFF","#161E38")}
                                    GradientStop{position:1;color:clt("#F6F8FE","#101832")}
                                }
                                border.width:1; border.color:mi.activeFocus?acc:clt("#D8DDF0","#1E2E50")
                                ScrollView {
                                    anchors.fill:parent; anchors.margins:2; clip:true
                                    ScrollBar.vertical: ScrollBar{policy:ScrollBar.AsNeeded;width:8;contentItem:Rectangle{radius:4;color:clt("#A0A8C0","#404860");opacity:0.6}}
                                    TextArea {
                                        id:mi; anchors.left:parent.left; anchors.leftMargin:12
                                        anchors.right:parent.right; anchors.rightMargin:12; padding:12
                                        font.pixelSize:16; color:clt(text1,text1); enabled:curUid!==""
                                        wrapMode:TextEdit.WordWrap; selectByMouse:true
                                        placeholderText:curUid?"Ctrl+Enter 发送  Enter 换行":"请先选择联系人"
                                        background:null
                                        Keys.onPressed:function(e){if(e.key===Qt.Key_Return&&(e.modifiers&Qt.ControlModifier)){sendMsg();e.accepted=true}}
                                    }
                                }
                            }
                            Row { width:parent.width; spacing:10
                                Item { Layout.fillWidth:true;height:1 }
                                Text { anchors.verticalCenter:parent.verticalCenter; text:mi.length+" 字"; font.pixelSize:12; color:mi.length>3000?red:clt(text3,text3) }
                                Rectangle { width:72;height:34;radius:12
                                    gradient: Gradient{
                                        GradientStop{position:0;color:sbh.containsMouse?"#818CF8":acc}
                                        GradientStop{position:1;color:sbh.containsMouse?"#A78BFA":Qt.darker(acc,1.05)}
                                    }
                                    Text { anchors.centerIn:parent;text:"发送";color:"white";font.pixelSize:15;font.bold:true }
                                    MouseArea { id:sbh;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true;onClicked:sendMsg() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ CONTEXT MENUS ═══
    Menu {
        id: msgMenu; property int _id:0; property string _txt:""
        background: Rectangle{radius:12;color:clt("#FFFFFF","#111830");border.color:clt("#D8DDF0","#1E2E50");border.width:1}
        MenuItem { text:"复制"; onTriggered:{bridge.copyText(msgMenu._txt);toast("已复制")} }
        MenuItem { text:"删除此消息"; onTriggered:{
            bridge.deleteMessage(String(msgMenu._id))
            for(var i=0;i<msgs.length;i++){if(String(msgs[i].id||0)===String(msgMenu._id)){msgs.splice(i,1);break}}
            toast("已删除")
        }}
    }
    Menu {
        id: cm; property string _u:""
        MenuItem { text:"置顶/取消置顶"; onTriggered: tPin(cm._u) }
        MenuItem { text:"收藏/取消收藏"; onTriggered: tFav(cm._u) }
    }

    // ═══ PROFILE POPUP ═══
    Popup {
        id: pf; x:Math.min(parent.width-260,parent.width*0.62); y:62
        width: 250; height: 200; padding:0; modal:true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle{color:clt("#FFFFFF","#0F162A");radius:18;border.color:clt(bd1,"#1E3050");border.width:1}
        Column { anchors.centerIn:parent; spacing:12; width:190
            Rectangle { width:72;height:72;radius:36;anchors.horizontalCenter:parent.horizontalCenter;color:clt("#E4E8F4","#1A2850")
                Image { anchors.fill:parent;anchors.margins:2
                    source: profUid ? "https://cdn.luogu.com.cn/upload/usericon/" + profUid + ".png" : ""
                    fillMode:Image.PreserveAspectCrop;asynchronous:true }
            }
            Text { anchors.horizontalCenter:parent.horizontalCenter; text:profName||"未知"; font.pixelSize:17; font.bold:true; color:clt(text1,text1) }
            Text { anchors.horizontalCenter:parent.horizontalCenter; text:"UID: "+profUid; font.pixelSize:13; color:clt(text2,text2) }
            Rectangle { anchors.horizontalCenter:parent.horizontalCenter; width:130;height:34;radius:12;color:acc
                Text { anchors.centerIn:parent;text:"发消息";color:"white";font.pixelSize:14;font.bold:true }
                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{pf.close();selUser(profUid,profName)} }
            }
        }
    }

    // ═══ SETTINGS DIALOG ═══
    Popup {
        id: stg; modal:true; focus:true; closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutsideParent
        x:(win.width-width)/2; y:(win.height-height)/2
        width: Math.min(win.width-40,620); height: Math.min(win.height-40,620)
        padding:0
        background: Rectangle{color:clt("#FFFFFF","#0C1324");radius:18;border.color:clt(bd1,"#1A2C50");border.width:1}

        property string uidInput: ""
        property string clientIdInput: ""
        property string localApiUrl: ""
        property string localApiKey: ""
        property string localApiModel: ""
        property string localCustomSysPrompt: ""
        property string localKw: "zhl重要信息"
        property string localSrv: ""
        property string localSysPrompt: ""
        property string localQTemplate: ""
        property int tab: 0
        property bool localNPopup: true
        property string localNMode: "ai"
        property bool localNSound: true
        property string localNType: "system"
        property string localNFile: ""
        property string localPrefix: ""
        property string localSuffix: ""

        onOpened: {
            var c = JSON.parse(bridge.getConfig())
            uidInput = c.luogu ? (c.luogu.user_id || "") : ""
            var raw = c.luogu ? (c.luogu.cookie || "") : ""
            var cidm = raw.match(/__client_id=([^;]+)/)
            if(cidm) clientIdInput = cidm[1]
            else if(raw.indexOf("_uid=") >= 0) clientIdInput = raw.replace(/_uid=\d+;?\s*/,"").trim()
            else clientIdInput = raw

            useDefaultAI = c.ai ? (c.ai.default !== false) : true
            localKw = c.ai ? (c.ai.important_keyword || "zhl重要信息") : "zhl重要信息"
            localSysPrompt = c.ai ? (c.ai.system_prompt || "") : ""
            localQTemplate = c.ai ? (c.ai.question_template || "") : ""
            if (c.ai && c.ai.custom) {
                localApiUrl = c.ai.custom.base_url || ""
                localApiKey = c.ai.custom.api_key || ""
                localApiModel = c.ai.custom.model || ""
                localCustomSysPrompt = c.ai.custom.custom_system_prompt || ""
            }
            localSrv = c.server ? (c.server.url || "") : ""
            if (c.notification) {
                localNPopup = c.notification.enabled !== false
                localNMode = c.notification.popup_mode || "ai"
                localNSound = c.notification.sound_enabled !== false
                localNType = c.notification.sound_type || "system"
                localNFile = c.notification.sound_file || ""
                localPrefix = c.notification.popup_prefix || ""
                localSuffix = c.notification.popup_suffix || ""
            }
        }

        Column { width:parent.width; height:parent.height
            // 标题栏
            Rectangle { width:parent.width; height:50; color:"transparent"
                Row { anchors.left:parent.left; anchors.leftMargin:18; anchors.verticalCenter:parent.verticalCenter; spacing:10
                    Text { text:"⚙"; font.pixelSize:22; anchors.verticalCenter:parent.verticalCenter }
                    Text { text:"设置"; font.pixelSize:19; font.bold:true; color:clt(text1,text1); anchors.verticalCenter:parent.verticalCenter }
                }
                Rectangle { anchors.right:parent.right; anchors.rightMargin:14; anchors.verticalCenter:parent.verticalCenter
                    width:30;height:30;radius:9; color: csh.containsMouse ? red : clt("#EEF0F8","#121830")
                    Text { anchors.centerIn:parent;text:"✕";font.pixelSize:15;color:csh.containsMouse?"white":clt(text2,text2) }
                    MouseArea { id:csh;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true;onClicked:stg.close() }
                }
            }
            Rectangle { width:parent.width; height:1; color:clt(bd1,bd2) }
            // 标签栏
            Rectangle { width:parent.width; height:48; color:clt("#F2F4FC","#060C1A")
                Row { anchors.centerIn:parent; spacing:6
                    Repeater {
                        model: ["账号","AI","通知","服务器"]
                        Rectangle { width:90; height:34; radius:12
                            color: index === stg.tab ? acc : "transparent"
                            Text { anchors.centerIn:parent; text:modelData; font.pixelSize:14; color: index===stg.tab ? "white" : clt(text2,text2) }
                            MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: stg.tab=index }
                        }
                    }
                }
            }
            Rectangle { width:parent.width; height:1; color:clt(bd1,bd2) }

            // 内容区
            Flickable { id:sf; width:parent.width; height:parent.height-143; contentHeight:scol.height+24; clip:true
                Column { id:scol; width:parent.width-40; anchors.horizontalCenter:parent.horizontalCenter; spacing:14; topPadding:16

                    // ═══ TAB 0: 账号 ═══
                    Column { width:parent.width; spacing:12; visible:stg.tab===0; height:stg.tab===0?undefined:0
                        Text { text:"洛谷 UID"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                        Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:15; color:clt(text1,text1)
                                text:stg.uidInput; onTextChanged:stg.uidInput=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                        Text { text:"Cookie (client_id)"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                        Text { text:"输入 __client_id 的值，自动转标准格式 _uid=xxx; __client_id=xxx"; font.pixelSize:11; color:clt(text3,text3) }
                        Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:14; color:clt(text1,text1)
                                text:stg.clientIdInput; onTextChanged:stg.clientIdInput=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                        Row { spacing:12
                            Rectangle { width:110; height:38; radius:12; color:acc
                                Text { anchors.centerIn:parent; text:"验证登录"; color:"white"; font.pixelSize:14; font.bold:true }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:bridge.testLogin(stg.uidInput,stg.clientIdInput) }
                            }
                            Rectangle { width:90; height:38; radius:12; color:clt("#EEF0F8","#121830")
                                Text { anchors.centerIn:parent; text:"刷新C3VK"; font.pixelSize:12; color:clt(text2,text2) }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:bridge.refreshC3VK() }
                            }
                        }
                        Text { text:myUid?"已登录 UID: " + myUid:"未登录"; font.pixelSize:13; color:myUid?green:clt(text3,text3) }
                        Text { text:bridge.hasSuperAllow()?"超级权限·无限制":"标准模式"; font.pixelSize:13; color:bridge.hasSuperAllow()?orange:green }
                    }

                    // ═══ TAB 1: AI ═══
                    Column { width:parent.width; spacing:14; visible:stg.tab===1; height:stg.tab===1?undefined:0
                        // 启用开关
                        Row { spacing:12
                            Text { text:"启用 AI 判断"; font.pixelSize:15; color:clt(text1,text1); anchors.verticalCenter:parent.verticalCenter }
                            Rectangle { width:50; height:28; radius:14; anchors.verticalCenter:parent.verticalCenter; color:aiOn ? acc : clt("#CCD0E0","#283050")
                                Rectangle { width:24;height:24;radius:12;x:aiOn?24:2;anchors.verticalCenter:parent.verticalCenter;color:"white";Behavior on x{NumberAnimation{duration:150}} }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked: aiOn = !aiOn }
                            }
                        }

                        // AI 提供商选择
                        Text { text:"AI 提供商"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                        Row { spacing:8
                            Rectangle { width:(parent.width-8)/2; height:60; radius:14
                                color: useDefaultAI ? clt("#E4EAFA","#142048") : clt("#F2F4FC","#111830")
                                border.color: useDefaultAI ? acc : clt(bd1,bd2); border.width: useDefaultAI ? 2 : 1
                                Column { anchors.centerIn:parent; spacing:3
                                    Text { text:"默认"; font.pixelSize:15; font.bold:useDefaultAI; color:clt(text1,text1); anchors.horizontalCenter:parent.horizontalCenter }
                                    Text { text:"系统内置"; font.pixelSize:11; color:clt(text3,text3); anchors.horizontalCenter:parent.horizontalCenter }
                                }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked: useDefaultAI=true }
                            }
                            Rectangle { width:(parent.width-8)/2; height:60; radius:14
                                color: !useDefaultAI ? clt("#E4EAFA","#142048") : clt("#F2F4FC","#111830")
                                border.color: !useDefaultAI ? acc : clt(bd1,bd2); border.width: !useDefaultAI ? 2 : 1
                                Column { anchors.centerIn:parent; spacing:3
                                    Text { text:"自定义 API"; font.pixelSize:15; font.bold:!useDefaultAI; color:clt(text1,text1); anchors.horizontalCenter:parent.horizontalCenter }
                                    Text { text:!useDefaultAI?"已配置":"自行提供"; font.pixelSize:11; color:clt(text3,text3); anchors.horizontalCenter:parent.horizontalCenter }
                                }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked: useDefaultAI=false }
                            }
                        }

                        // 自定义 AI 配置（仅在自定义模式下显示）
                        Column { visible:!useDefaultAI; spacing:12; width:parent.width
                            Rectangle { width:parent.width; height:1; color:clt(bd1,bd2) }
                            Text { text:"API Base URL"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                            Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                                TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:14; color:clt(text1,text1)
                                    text:stg.localApiUrl; onTextChanged:stg.localApiUrl=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                            }
                            Text { text:"API Key"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                            Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                                TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:14; color:clt(text1,text1)
                                    echoMode:TextInput.Password; text:stg.localApiKey; onTextChanged:stg.localApiKey=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                            }
                            Text { text:"模型名称"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                            Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                                TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:14; color:clt(text1,text1)
                                    text:stg.localApiModel; onTextChanged:stg.localApiModel=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                            }
                            Text { text:"系统提示词 (可自定义)"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                            Rectangle { width:parent.width; height:72; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                                TextArea { anchors.fill:parent; anchors.leftMargin:12;anchors.rightMargin:12;anchors.topMargin:8;anchors.bottomMargin:8
                                    font.pixelSize:13; color:clt(text1,text1); text:stg.localCustomSysPrompt; onTextChanged:stg.localCustomSysPrompt=text
                                    wrapMode:TextEdit.WordWrap; background:null; selectByMouse:true }
                            }
                        }

                        // 检测子串
                        Text { text:"检测子串 (重要消息关键词)"; font.pixelSize:14; font.weight:Font.DemiBold; color:clt(text1,text1) }
                        Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:14; color:clt(text1,text1)
                                text:stg.localKw; onTextChanged:stg.localKw=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                    }

                    // ═══ TAB 2: 通知 ═══
                    Column { width:parent.width; spacing:12; visible:stg.tab===2; height:stg.tab===2?undefined:0
                        Row { spacing:12
                            Text { text:"启用弹窗通知"; font.pixelSize:15; color:clt(text1,text1); anchors.verticalCenter:parent.verticalCenter }
                            Rectangle { width:50;height:28;radius:14;anchors.verticalCenter:parent.verticalCenter;color:stg.localNPopup?acc:clt("#CCD0E0","#283050")
                                Rectangle { width:24;height:24;radius:12;x:stg.localNPopup?24:2;anchors.verticalCenter:parent.verticalCenter;color:"white";Behavior on x{NumberAnimation{duration:150}} }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:stg.localNPopup=!stg.localNPopup }
                            }
                        }
                        Row { spacing:12
                            Text { text:"启用提示音"; font.pixelSize:15; color:clt(text1,text1); anchors.verticalCenter:parent.verticalCenter }
                            Rectangle { width:50;height:28;radius:14;anchors.verticalCenter:parent.verticalCenter;color:stg.localNSound?acc:clt("#CCD0E0","#283050")
                                Rectangle { width:24;height:24;radius:12;x:stg.localNSound?24:2;anchors.verticalCenter:parent.verticalCenter;color:"white";Behavior on x{NumberAnimation{duration:150}} }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:stg.localNSound=!stg.localNSound }
                            }
                        }
                        Row { spacing:12
                            Text { text:"提示音类型:"; font.pixelSize:14; color:clt(text2,text2); anchors.verticalCenter:parent.verticalCenter }
                            Repeater {
                                model: ["系统", "MP3"]
                                Rectangle { width:70; height:32; radius:10
                                    color: stg.localNType === ["system","mp3"][index] ? acc : clt("#EEF0F8","#121830")
                                    Text { anchors.centerIn:parent; text:modelData; font.pixelSize:13; color:stg.localNType===["system","mp3"][index]?"white":clt(text2,text2) }
                                    MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:stg.localNType=["system","mp3"][index] }
                                }
                            }
                        }
                        Text { visible:stg.localNType==="mp3"; text:"MP3 文件路径"; font.pixelSize:13; color:clt(text2,text2) }
                        Rectangle { visible:stg.localNType==="mp3"; width:parent.width; height:40; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:13; color:clt(text1,text1)
                                text:stg.localNFile; onTextChanged:stg.localNFile=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                        Rectangle { width:parent.width; height:1; color:clt(bd1,bd2) }
                        Text { text:"弹窗模式"; font.pixelSize:14; font.bold:true; color:clt(text1,text1) }
                        Row { spacing:10
                            Repeater {
                                model: ["AI判断", "直接提示", "不提示"]
                                Rectangle { width:80; height:32; radius:10
                                    color: stg.localNMode === ["ai","direct","none"][index] ? acc : clt("#EEF0F8","#121830")
                                    Text { anchors.centerIn:parent; text:modelData; font.pixelSize:12; color:stg.localNMode===["ai","direct","none"][index]?"white":clt(text2,text2) }
                                    MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:stg.localNMode=["ai","direct","none"][index] }
                                }
                            }
                        }
                        Text { text:"弹窗前缀 (如：提示：)"; font.pixelSize:12; color:clt(text2,text2) }
                        Rectangle { width:parent.width; height:38; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:13; color:clt(text1,text1)
                                text:stg.localPrefix; onTextChanged:stg.localPrefix=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                        Text { text:"弹窗后缀 (如：。)"; font.pixelSize:12; color:clt(text2,text2) }
                        Rectangle { width:parent.width; height:38; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:13; color:clt(text1,text1)
                                text:stg.localSuffix; onTextChanged:stg.localSuffix=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                    }

                    // ═══ TAB 3: 服务器 ═══
                    Column { width:parent.width; spacing:12; visible:stg.tab===3; height:stg.tab===3?undefined:0
                        Text { text:"Worker URL"; font.pixelSize:14; color:clt(text2,text2) }
                        Rectangle { width:parent.width; height:42; radius:12; color:clt("#F2F4FC","#111830"); border.color:clt(bd1,bd2);border.width:1
                            TextInput { anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; font.pixelSize:14; color:clt(text1,text1)
                                text:stg.localSrv; onTextChanged:stg.localSrv=text; verticalAlignment:TextInput.AlignVCenter; selectByMouse:true }
                        }
                        Row { spacing:12
                            Rectangle { width:90; height:36; radius:12; color:acc
                                Text { anchors.centerIn:parent; text:"同步"; color:"white"; font.pixelSize:14; font.bold:true }
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{
                                    var s=JSON.parse(bridge.syncNow()); serverRem=s.remaining||0; serverTotal=s.total||0; toast("剩余:"+serverRem+"/"+serverTotal) }}
                            }
                        }
                        Text { text:"剩余: " + serverRem + "/" + serverTotal; font.pixelSize:14; color:clt(text2,text2) }
                    }
                }
                ScrollBar.vertical: ScrollBar{policy:ScrollBar.AsNeeded;width:6;contentItem:Rectangle{radius:3;color:clt("#A0A8C0","#404860");opacity:0.6}}
            }

            Rectangle { width:parent.width; height:1; color:clt(bd1,bd2) }
            Rectangle { width:parent.width; height:44; color:"transparent"
                Row { anchors.right:parent.right; anchors.rightMargin:16; anchors.verticalCenter:parent.verticalCenter; spacing:12
                    Rectangle { width:80;height:34;radius:12;color:clt("#EEF0F8","#121830")
                        Text { anchors.centerIn:parent; text:"取消"; font.pixelSize:14; color:clt(text2,text2) }
                        MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:stg.close() }
                    }
                    Rectangle { width:80;height:34;radius:12;color:acc
                        Text { anchors.centerIn:parent; text:"保存"; color:"white"; font.pixelSize:14; font.bold:true }
                        MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{
                            var C = {
                                luogu: { user_id: stg.uidInput, cookie: stg.clientIdInput },
                                ai: {
                                    enabled: aiOn,
                                    important_keyword: stg.localKw,
                                    default: useDefaultAI,
                                    system_prompt: stg.localSysPrompt,
                                    question_template: stg.localQTemplate,
                                    custom: {
                                        base_url: stg.localApiUrl,
                                        api_key: stg.localApiKey,
                                        model: stg.localApiModel,
                                        custom_system_prompt: stg.localCustomSysPrompt
                                    }
                                },
                                notification: {
                                    enabled: stg.localNPopup,
                                    sound_enabled: stg.localNSound,
                                    sound_type: stg.localNType,
                                    sound_file: stg.localNFile,
                                    popup_mode: stg.localNMode,
                                    popup_filter: "all",
                                    popup_prefix: stg.localPrefix,
                                    popup_suffix: stg.localSuffix
                                },
                                server: { url: stg.localSrv },
                                theme: { mode: themeMode, accent: acc }
                            }
                            bridge.saveConfig(JSON.stringify(C)); toast("设置已保存"); stg.close()
                        }}
                    }
                }
            }
        }
    }

    // ═══ ERROR DIALOG ═══
    Dialog {
        id: errDlg; modal:true; closePolicy:Popup.NoAutoClose
        x:(win.width-width)/2; y:(win.height-height)/2; width:Math.min(win.width-40,380); padding:20
        background:Rectangle{color:clt("#FFFFFF","#0C1324");radius:16;border.color:red;border.width:1}
        property string errMsg: ""; property var retryFn: null
        Column { width:parent.width; spacing:16
            Text { text:"⚠ 错误"; font.pixelSize:19; font.bold:true; color:red }
            Text { width:parent.width; text:errDlg.errMsg; font.pixelSize:14; color:clt(text1,text1); wrapMode:Text.WordWrap }
            Row { anchors.right:parent.right; spacing:12
                Rectangle { width:80;height:34;radius:10;color:clt("#EEF0F8","#121830")
                    Text { anchors.centerIn:parent;text:"重试";font.pixelSize:13;color:clt(text2,text2) }
                    MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{errDlg.close();if(errDlg.retryFn)errDlg.retryFn()} }
                }
                Rectangle { width:80;height:34;radius:10;color:red
                    Text { anchors.centerIn:parent;text:"关闭";color:"white";font.pixelSize:13 }
                    MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:errDlg.close() }
                }
            }
        }
    }
    function showError(msg,fn) { errDlg.errMsg=msg; errDlg.retryFn=fn||null; errDlg.open() }

    // ═══ TOAST ═══
    Rectangle {
        id: toastRect; visible:false; z:1100; anchors.horizontalCenter:parent.horizontalCenter; y:14
        width: tt.width + 50; height: 38; radius: 19
        color: clt(Qt.rgba(0.15,0.15,0.2,0.94),Qt.rgba(0.06,0.1,0.25,0.95))
        Text { id:tt; anchors.centerIn:parent; color:"white"; font.pixelSize:15 }
        SequentialAnimation {
            id:ta; PropertyAction{target:toastRect;property:"visible";value:true}
            PropertyAction{target:toastRect;property:"opacity";value:1}
            PauseAnimation{duration:2000}
            NumberAnimation{target:toastRect;property:"opacity";to:0;duration:300}
            PropertyAction{target:toastRect;property:"visible";value:false}
        }
    }

    // ═══ NOTIFICATION POPUP (Glass Morphism, 右下角) ═══
    property string notifTitle: ""; property string notifBody: ""
    property string notifSender: ""; property string notifUid: ""
    property bool notifExpanded: false

    Popup {
        id: notifPopup; x: win.width - 330; y: win.height - 170; width: 310
        height: notifExpanded ? Math.min(notifContent.height + 70, 400) : 100
        padding: 0; modal: false; closePolicy: Popup.NoAutoClose

        background: Rectangle {
            radius: 18; clip: true
            gradient: Gradient {
                GradientStop{position:0;color:clt(Qt.rgba(0.96,0.97,0.99,0.93),Qt.rgba(0.06,0.1,0.25,0.95))}
                GradientStop{position:1;color:clt(Qt.rgba(0.92,0.94,0.98,0.89),Qt.rgba(0.04,0.07,0.2,0.91))}
            }
            border.color: clt(Qt.rgba(0.6,0.65,1,0.25),Qt.rgba(0.3,0.4,0.8,0.2)); border.width: 1
        }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Column { id: notifOuter; anchors.centerIn:parent; width: parent.width - 24
            Row { spacing: 12; width: parent.width
                Column { spacing: 4; width: parent.width - 80
                    Text { text: notifTitle; font.pixelSize: 16; font.bold: true; color: clt(text1,text1); elide: Text.ElideRight; width: parent.width }
                    Text {
                        text: notifExpanded ? notifBody : (notifBody.length > 42 ? notifBody.substring(0, 40) + "…" : notifBody)
                        font.pixelSize: 13; color: clt(text2,text2); wrapMode: Text.WordWrap; width: parent.width
                    }
                    Column { id: notifContent; visible: notifExpanded; width: parent.width; spacing: 10; topPadding: 8
                        TextArea { id: notifBodyFull; width: parent.width; readOnly: true; text: notifBody
                            font.pixelSize: 14; color: clt(text1,text1); wrapMode: TextEdit.WordWrap; selectByMouse: true; background: null }
                        Row { spacing: 8
                            Rectangle { width: 70; height: 30; radius: 10; color: acc
                                Text { anchors.centerIn:parent; text:"回复"; color:"white"; font.pixelSize:13; font.bold:true }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                                    onClicked: { selUser(notifUid,notifSender); notifExpanded=false; notifPopup.close() } }
                            }
                            Rectangle { width: 60; height: 30; radius: 10; color: clt("#EEF0F8","#121830")
                                Text { anchors.centerIn:parent; text:"收起"; font.pixelSize:12; color:clt(text2,text2) }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: notifExpanded=false }
                            }
                        }
                    }
                }
                Column { spacing: 6
                    Rectangle { width: 30; height: 30; radius: 10; color: clt("#EEF0F8","#121830")
                        Text { anchors.centerIn:parent; text: notifExpanded ? "−" : "+"; font.pixelSize: 16; color: clt(text2,text2); font.bold: true }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: notifExpanded = !notifExpanded }
                    }
                    Rectangle { width: 30; height: 30; radius: 10; color: clt("#EEF0F8","#121830")
                        Text { anchors.centerIn:parent; text:"✕"; font.pixelSize: 13; color: clt(text2,text2) }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: { notifExpanded = false; notifPopup.close() } }
                    }
                }
            }
        }
        SequentialAnimation {
            id: notifAnim; NumberAnimation{target:notifPopup;property:"opacity";from:0;to:1;duration:350}
            PauseAnimation{duration:8000}
            NumberAnimation{target:notifPopup;property:"opacity";to:0;duration:400}
            PropertyAction{target:notifPopup;property:"visible";value:false}
        }
    }

    Component.onCompleted: {
        reloadCfg(); refreshList(); bridge.startWS(); autoRefreshTimer.start()
        Qt.callLater(function(){ bridge.refreshChatList() })
        try{ var s = JSON.parse(bridge.getServerStatus()); serverRem = s.remaining || 0; serverTotal = s.total || 0 } catch(e) {}
    }
    Timer { id: autoRefreshTimer; interval: 30000; repeat: true; onTriggered: { if(myUid) bridge.refreshChatList() } }
}
