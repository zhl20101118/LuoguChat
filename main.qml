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
    property bool avatarRounded: false
    property var avatarCache: ({})
    property int avatarVer: 0
    property string curAvatarSource: ""
    property bool dark: themeMode === 1
    function clt(light, dk) { return themeMode === 1 ? dk : light }

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
    property bool listRefreshing: false
    property var searchResults: []
    property bool searching: false
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
        themeMode = c.theme ? (c.theme.mode !== undefined ? c.theme.mode : 2) : 2
        acc = c.theme ? (c.theme.accent || "#6366F1") : "#6366F1"
        avatarRounded = c.theme ? (c.theme.avatar_rounded || false) : false
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
            // 批量预取所有头像
            var uids = []; for (var k = 0; k < raw.length; k++) { var uid = raw[k]._u; if (uid && !avatarCache[uid]) uids.push(uid) }
            if (uids.length > 0) bridge.prefetchAvatars(JSON.stringify(uids))
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
        curAvatarSource = avatarCache[u] || ""
        // 清除该用户的未读气泡 (status 1=unread → 2=read)
        for (var i = 0; i < chatList.length; i++) {
            if (chatList[i]._u === u) { chatList[i].status = 2; break }
        }
        listVer += 1
        loadMsgs(u, -1); bridge.requestAvatar(u)
    }
    function sendMsg() {
        var t = mi.text.trim()
        if (!t || !curUid) return
        bridge.sendMessage(curUid, t)
        // 乐观显示：立即加入带 _pending 标记的消息
        var pendingMsg = {id:0,content:t,from_uid:myUid,sender:{},"sender.name":myName,time:Math.floor(Date.now()/1000),is_me:true,_pending:true}
        msgs.push(pendingMsg)
        mi.text = ""
        Qt.callLater(function() { msgList.positionViewAtEnd() })
        // 800ms 后刷新，成功则替换为真实数据
        sendRefreshTimer.restart()
    }
    // 时间格式化 — 只显示 HH:MM
    function tf(ts) {
        if (!ts) return ""
        var d = new Date(ts*1000)
        return ("0"+d.getHours()).slice(-2)+":"+("0"+d.getMinutes()).slice(-2)
    }
    // 日期格式化 — 完整显示
    function td(ts) {
        if (!ts) return ""
        var d = new Date(ts*1000); var n = new Date()
        if (d.toDateString()===n.toDateString()) return "今天"
        var y = new Date(n); y.setDate(y.getDate()-1)
        if (d.toDateString()===y.toDateString()) return "昨天"
        return (d.getMonth()+1)+"/"+d.getDate()
    }
    // 完整日期时间 — 用于消息气泡
    function tFull(ts) {
        if (!ts) return ""
        var d = new Date(ts*1000); var n = new Date()
        var time = ("0"+d.getHours()).slice(-2)+":"+("0"+d.getMinutes()).slice(-2)
        if (d.toDateString()===n.toDateString()) return time
        var y = new Date(n); y.setDate(y.getDate()-1)
        if (d.toDateString()===y.toDateString()) return "昨天 " + time
        return (d.getMonth()+1)+"/"+d.getDate()+" "+time
    }
    function tFav(uid) { var i=favList.indexOf(uid); if(i>=0)favList.splice(i,1);else favList.push(uid);us() }
    function tPin(uid) { var i=pinList.indexOf(uid); if(i>=0)pinList.splice(i,1);else pinList.push(uid);us() }
    function us() { bridge.saveConfig(JSON.stringify({favorites:favList,pins:pinList})) }
    function cycTheme() { themeMode=(themeMode+1)%3; console.log("DEBUG cycTheme ->", themeMode, "dark=", themeMode===1); bridge.saveConfig(JSON.stringify({theme:{mode:themeMode,accent:acc}})) }
    function showProf(u,n) { profUid=u; profName=n }
    function triggerListRefresh() { listRefreshing = true; bridge.refreshChatList() }
    function doSearch() {
        var q = si.text.trim()
        if (!q) { searchResults = []; refreshList(); return }
        // 先过滤本地列表
        refreshList()
        // 然后服务端搜索
        var kw = q.substring(0, 20)
        try {
            var raw = bridge.searchUsers(kw)
            var arr = JSON.parse(raw)
            searchResults = arr || []
        } catch(e) { searchResults = [] }
    }
    function showPopupNotify(title,body,uid,sender) {
        notifTitle=title; notifBody=body; notifSender=sender||""; notifUid=uid||""
        notifExpanded=false; notifAnim.restart(); notifPopup.open()
    }

    Connections {
        target: bridge
        function onWsStatus(s) { wsStat = s }
        function onNewMessage(m,c,sn,su,ts) {
            console.log("WS_NEW:", sn, "(", su, ")", "->", c.substring(0, 40))
            if (su===curUid) { msgs.push({id:0,content:c,from_uid:su,"sender.name":sn,time:ts,is_me:false}); Qt.callLater(function(){msgList.positionViewAtEnd()}) }
            triggerListRefresh()
        }
        function onImportantMessage(m,c,sn,su,tip,ts) {
            if (notifPopupEnabled) showPopupNotify("来自 " + sn, tip || c, m, sn)
            if (notifSoundEnabled) {
                if (notifSoundType === "system") bridge.playSound("")
                else if (notifSoundFile) bridge.playSound(notifSoundFile)
            }
        }
        function onChatListReady(j) { refreshListData(j); listRefreshing = false }
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
        function onReplySent(s,m) {
            if (!s) {
                // 发送失败：删除所有 _pending 消息
                for (var i = msgs.length - 1; i >= 0; i--) { if (msgs[i]._pending) { msgs.splice(i, 1) } }
                toast("发送失败: " + (m||""))
            } else {
                toast("已发送")
            }
        }
        function onAutoReplyDone(uid, content, reply) { toast("已自动回复 " + uid + ": " + reply.substring(0, 20) + "…") }
        function onShowErrorPopup(msg,rid) { showError(msg,function(){
            if(rid.indexOf("msg_")===0){var p=rid.substring(4).split("_");bridge.getMessages(p[0],parseInt(p[1])||1)}
            else if(rid==="refresh")triggerListRefresh()
            else if(rid.indexOf("send_")===0)bridge.sendMessage(rid.substring(5),mi.text)
        })}
        function onConfigChanged() { reloadCfg() }
        function onServerSyncResult(j) { var s=JSON.parse(j); serverRem=s.remaining||0; serverTotal=s.total||0 }
        function onAvatarReady(uid, path) {
            var fileUrl = "file:///" + path
            avatarCache[uid] = fileUrl
            avatarVer += 1
            if (uid === curUid) curAvatarSource = fileUrl
        }
    }

    function getAvatar(uid) {
        if (!uid) return ""
        if (avatarCache[uid]) return avatarCache[uid]
        return "https://cdn.luogu.com.cn/upload/usericon/" + uid + ".png"
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent; anchors.margins: 2; radius: 18; clip: true
        color: clt("#EEF2FF","#080C1A")
        Rectangle {
            anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right
            height:1; color:clt(Qt.rgba(1,1,1,0.25),Qt.rgba(1,1,1,0.04))
        }

        RowLayout { anchors.fill:parent; spacing:0

            // ═══ LEFT SIDEBAR ═══
            Rectangle {
                Layout.preferredWidth: 60; Layout.fillHeight: true
                color: clt(sideBg,"#040810")
                radius: 18; clip: true

                // 上方内容
                Column {
                    anchors.top: parent.top; anchors.topMargin: 14
                    anchors.left: parent.left; anchors.right: parent.right
                    spacing: 6

                    // 头像
                    Rectangle {
                        width:44; height:44; radius:avatarRounded?10:22; anchors.horizontalCenter:parent.horizontalCenter
                        color: clt("#D8DDF0","#1E2850")
                        Image {
                            anchors.fill:parent; anchors.margins:2
                            source: getAvatar(myUid)
                            fillMode: Image.PreserveAspectCrop; asynchronous:true
                            onStatusChanged: if(status===Image.Error) source=""
                        }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{if(myUid){bridge.requestAvatar(myUid);showProf(myUid,myName)}} }
                    }
                    Item { height: 10; width: 1 }
                    // 列表折叠按钮
                    Rectangle {
                        id: collapseBtn; width: 30; height: 30; radius: 15
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: collapseHover.containsMouse ? Qt.lighter(acc, 1.2) : acc
                        scale: collapseHover.containsMouse ? 1.1 : 1.0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: showList ? "≡" : "▷"; font.pixelSize: 14; color: "white"; font.bold: true }
                        MouseArea { id: collapseHover; anchors.fill:parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: showList = !showList }
                    }
                    // 主题
                    Rectangle {
                        width:40; height:40; radius:12; anchors.horizontalCenter:parent.horizontalCenter
                        color: "transparent"
                        Text { anchors.centerIn:parent; text: themeMode===0?"☀":(themeMode===1?"☾":"◐"); font.pixelSize:20; color:clt(text2,text3) }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true; onClicked:cycTheme() }
                    }
                }

                // 底部按钮
                Column {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                    anchors.left: parent.left; anchors.right: parent.right
                    spacing: 4

                    // 设置
                    Rectangle {
                        width:40; height:40; radius:12; anchors.horizontalCenter:parent.horizontalCenter
                        color: "transparent"
                        Text { anchors.centerIn:parent; text:"⚙"; font.pixelSize:22; color:clt(text2,text3) }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true; onClicked:{reloadCfg();stg.open()} }
                    }
                    // AI 设置
                    Rectangle {
                        id: aiSideBtn
                        width:40; height:40; radius:12; anchors.horizontalCenter:parent.horizontalCenter
                        color: "transparent"
                        Text { anchors.centerIn:parent; text:"⌬"; font.pixelSize:22; color:clt(text2,text3) }
                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true; onClicked:{reloadCfg();stgAI.open()} }
                    }
                }
            }

            Rectangle { Layout.preferredWidth:4; Layout.fillHeight:true; color:clt(bd1,bd2) }

            // ═══ MIDDLE PANEL (可折叠) ═══
            Rectangle {
                id: midPanel
                Layout.preferredWidth: showList ? 310 : 0; Layout.fillHeight: true
                clip: true
                color: clt(cardBg,"#0A1020")
                radius: 16; visible: showList
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // 搜索栏
                Rectangle {
                    id: searchBar
                    anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right
                    height: 56; color:"transparent"

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                        // 搜索输入框
                        Rectangle {
                            width: parent.width - 46; height: 38; radius: 19
                            anchors.verticalCenter: parent.verticalCenter
                            color: clt("#ECEEF6","#0F1830"); border.color: clt(bd1,bd2); border.width: 1.5

                            Row {
                                anchors.fill: parent; anchors.leftMargin: 14; spacing: 8
                                Text { text: "⌕"; font.pixelSize: 17; anchors.verticalCenter: parent.verticalCenter; color: clt(text3,text3) }
                                TextInput {
                                    id: si
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 32
                                    font.pixelSize: 14; color: clt(text1,text1)
                                    selectByMouse: true
                                    clip: true
                                    onTextChanged: searchTimer.restart()
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: function(mouse) { mouse.accepted = false }
                                    }
                                }
                            }
                        }

                        // 刷新按钮
                        Rectangle {
                            width: 38; height: 38; radius: 19; anchors.verticalCenter: parent.verticalCenter
                            color: refreshHover.containsMouse ? clt("#DCE2F2","#1A2850") : clt("#ECEEF6","#0F1830")
                            border.color: clt(bd1,bd2); border.width: 1.5
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn:parent; text:"↻"; font.pixelSize: 19; color: clt(text2,text2) }
                            MouseArea { id: refreshHover; anchors.fill:parent; cursorShape:Qt.PointingHandCursor; hoverEnabled:true; onClicked: triggerListRefresh() }
                        }
                    }
                }
                Rectangle { anchors.top:searchBar.bottom; anchors.left:parent.left; anchors.right:parent.right; height:1; color:clt(bd1,bd2) }

                // 列表 — 用 ListView 替代 ScrollView+Column
                    ListView {
                        id: chatListView
                        anchors.top: searchBar.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        clip: true
                        spacing: 3
                        topMargin: 8; bottomMargin: 8
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 5000

                    // header: 加载指示器 + 搜索结果
                    header: Column {
                        width: chatListView.width
                        // 加载指示器
                        Rectangle {
                            width: parent.width; height: loading ? 44 : 0; color: "transparent"; visible: loading
                            Row { anchors.centerIn: parent; spacing: 10
                                Rectangle { width: 16; height: 16; radius: 8; color: acc
                                    RotationAnimation on rotation { from:0; to:360; duration:800; loops:Animation.Infinite; running: loading } }
                                Text { text:"加载中..."; font.pixelSize: 13; color: clt(text2,text2); anchors.verticalCenter: parent.verticalCenter }
                            }
                            Behavior on height { NumberAnimation { duration: 200 } }
                        }
                        // 搜索结果
                        Column {
                            width: parent.width; visible: searchResults.length > 0
                            Rectangle { width: parent.width; height: 1; color: clt(bd1,bd2) }
                            Rectangle { width: parent.width; height: 30; color: "transparent"
                                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14
                                    text: "搜索结果 (" + searchResults.length + ")"; font.pixelSize: 12; font.bold: true; color: acc } }
                            Repeater {
                                model: searchResults
                                delegate: Rectangle {
                                    width: parent.width; height: 46; radius: 8
                                    color: searchHvr.containsMouse ? clt(hover,"#111D38") : clt("#F0F2FA","#0D1530")
                                    Row { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 10
                                        Rectangle { width: 32; height: 32; radius: avatarRounded?8:16; anchors.verticalCenter: parent.verticalCenter; color: clt("#E4E8F4","#152040"); clip: true
                                            Image { anchors.fill: parent; anchors.margins: 1; source: getAvatar(modelData.uid); fillMode: Image.PreserveAspectCrop; asynchronous: true } }
                                        Text { text: modelData.name || ("用户"+modelData.uid); font.pixelSize: 14; color: clt(text1,text1); anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight; width: parent.width - 160 }
                                        Text { text: "UID:" + (modelData.uid || ""); font.pixelSize: 11; color: clt(text3,text3); anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea { id: searchHvr; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                        onClicked: { var uid = String(modelData.uid); var nm = modelData.name || ""; si.text = ""; searchResults = []; selUser(uid, nm) } }
                                }
                            }
                            Rectangle { width: parent.width; height: 1; color: clt(bd1,bd2) }
                        }
                    }

                    model: chatList
                    delegate: Rectangle {
                        width: chatListView.width; height: 72
                        radius: 10
                        color: {
                            var u = String(modelData.uid || (modelData.user ? modelData.user.uid : ""))
                            return curUid === u ? clt(select,"#162050") : (hvr.containsMouse ? clt(hover,"#111D38") : "transparent")
                        }
                        Rectangle {
                            visible: curUid === String(modelData.uid || "")
                            anchors.left:parent.left; anchors.top:parent.top; anchors.bottom:parent.bottom
                            anchors.leftMargin: 4
                            width: 4; color: acc; radius: 2
                        }
                        property string uid: String(modelData.uid || "")
                        property string name: modelData.name || (modelData.user ? modelData.user.name : "") || ("用户" + uid)
                        property string last: {
                            var raw = modelData.content || ""
                            // 过滤换行、特殊字符，只保留可见文字
                            return raw.replace(/\n/g, " ").replace(/\r/g, "").replace(/[\u200B-\u200D\uFEFF]/g, "").trim()
                        }
                        property int tm: modelData.time || 0
                        property string ucolor: modelData.color || ""
                        property int unread: listVer >= 0 ? (modelData.status === 1 ? 1 : 0) : 0
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10

                            // 头像
                            Rectangle {
                                width: 46; height: 46; radius: avatarRounded ? 10 : 23; anchors.verticalCenter: parent.verticalCenter
                                color: clt("#E4E8F4","#152040"); clip: true
                                Image {
                                    anchors.fill: parent; anchors.margins: 1
                                    source: avatarVer >= 0 ? getAvatar(uid) : getAvatar(uid)
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                    onStatusChanged: if(status===Image.Error) source=""
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bridge.requestAvatar(uid); showProf(uid,name) } }
                                Rectangle {
                                    visible: pinList.indexOf(uid) >= 0
                                    width: 16; height: 16; radius: 8
                                    x: parent.width - 12; y: parent.height - 12
                                    color: orange
                                    Text { anchors.centerIn: parent; text: "★"; font.pixelSize: 9; color: "white" }
                                }
                            }

                            // 中间内容
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 46 - 10 - 62 - 4; spacing: 4

                                // 名字
                                Text {
                                    text: name
                                    font.pixelSize: 15; font.weight: Font.DemiBold
                                    color: nameColor(ucolor)
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                // 最后消息预览（过滤换行）
                                Text {
                                    text: {
                                        var p = (last || "").replace(/\n/g, " ").replace(/\r/g, "").trim()
                                        return p.length > 24 ? p.substring(0, 24) + "…" : p
                                    }
                                    font.pixelSize: 13; color: clt(text2,text2)
                                    elide: Text.ElideRight; width: parent.width
                                }
                            }

                            // 右侧操作按钮
                            Row {
                                width: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                visible: hvr.containsMouse || favList.indexOf(uid) >= 0 || pinList.indexOf(uid) >= 0
                                Rectangle {
                                    width: 28; height: 28; radius: 10; color: favList.indexOf(uid) >= 0 ? "#FDE68A" : "transparent"
                                    Text { anchors.centerIn: parent; text: favList.indexOf(uid) >= 0 ? "★" : "☆"; font.pixelSize: 13; color: favList.indexOf(uid) >= 0 ? "#D97706" : clt(text3,text3) }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tFav(uid) }
                                }
                                Rectangle {
                                    width: 28; height: 28; radius: 10; color: pinList.indexOf(uid) >= 0 ? "#C7D2FE" : "transparent"
                                    Text { anchors.centerIn: parent; text: "◉"; font.pixelSize: 13; color: pinList.indexOf(uid) >= 0 ? "#4F46E5" : clt(text3,text3) }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tPin(uid) }
                                }
                            }
                        }  // end outer Row

                        // 日期 — 绝对定位在列表项最右边
                        Text {
                            id: dateText
                            text: td(tm)
                            font.pixelSize: 11; color: clt(text3, text3)
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 14
                        }

                        // 未读气泡（条数）
                        Rectangle {
                            visible: unread > 0
                            width: unread > 99 ? 28 : (unread > 9 ? 22 : 18); height: 18; radius: 9
                            color: red
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: unread > 99 ? "99+" : String(unread)
                                font.pixelSize: 10; color: "white"; font.bold: true
                            }
                        }

                        MouseArea {
                            id: hvr; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.RightButton) { cm._u = uid; cm.popup() }
                                else { selUser(uid, name, ucolor) }
                            }
                        }
                    }

                    // 空状态
                    Rectangle {
                        anchors.centerIn: parent; visible: chatList.length === 0 && !loading
                        width: 220; height: 140; color: "transparent"
                        Column { anchors.centerIn: parent; spacing: 14
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✉"; font.pixelSize: 56; color: clt(text3,text3) }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "暂无消息"; font.pixelSize: 16; color: clt(text3,text3) }
                        }
                    }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded; width: 8
                    contentItem: Rectangle { radius: 4; color: clt("#C0C4D8","#3A4260"); opacity: 0.6 }
                }
                }
            }

            // DIVIDER — 仅视觉分隔，不可拖拽
            Rectangle {
                Layout.preferredWidth: 4; Layout.fillHeight: true
                color: clt(bd1, bd2)
                visible: showList
            }

            // ═══ RIGHT — CHAT PANEL ═══
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: clt(cardBg,"#090F1C")
                radius: 18

                Column { anchors.fill:parent; spacing:0

                    // 顶部标题栏
                    Rectangle {
                        width: parent.width; height: 56; color:"transparent"
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
                                Rectangle { width:40; height:40; radius:avatarRounded?10:20; color:clt("#E4E8F4","#152040")
                                    Image { anchors.fill:parent; anchors.margins:1
                                        source: curAvatarSource || getAvatar(curUid)
                                        fillMode:Image.PreserveAspectCrop; asynchronous:true }
                                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                                        onClicked: { if(curUid){ bridge.requestAvatar(curUid) } }
                                        onDoubleClicked: { if(curUid){ tPin(curUid); toast(pinList.indexOf(curUid)>=0?"已置顶":"已取消置顶"); refreshList() } } }
                                }
                                Column { anchors.verticalCenter:parent.verticalCenter; spacing:2
                                    Row { spacing:8
                                        Text { text:curName||"选择联系人"; font.pixelSize:16; font.weight:Font.DemiBold; color:nameColor(curColor) }
                                    }
                                    Row { spacing:6
                                        Rectangle { width:8;height:8;radius:4;anchors.verticalCenter:parent.verticalCenter;color:wsStat==="connected"?green:red }
                                        Text { text:wsStat==="connected"?"在线":"离线"; font.pixelSize:11; color:clt(text3,text3) }
                                    }
                                }
                            }
                        }

                        Row {
                            id: winCtrls; anchors.right:parent.right; anchors.rightMargin:16
                            anchors.verticalCenter:parent.verticalCenter; spacing:10
                            // 列表刷新指示器（右上角）
                            Row { visible: listRefreshing; spacing: 6; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; color: orange
                                    RotationAnimation on rotation{from:0;to:360;duration:800;loops:Animation.Infinite;running:listRefreshing} }
                                Text { text: "刷新中"; font.pixelSize: 12; color: orange; anchors.verticalCenter: parent.verticalCenter }
                            }
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
                            Rectangle { width:18;height:18;radius:9;color:xmh.containsMouse?"#34D399":clt("#10B981","#10B981")
                                MouseArea { id:xmh;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true
                                    onClicked:{if(win.visibility===Window.Maximized)win.showNormal();else win.showMaximized()} }
                            }
                            Rectangle { width:18;height:18;radius:9;color:xnh.containsMouse?"#FCD34D":clt("#F59E0B","#F59E0B")
                                MouseArea { id:xnh;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true;onClicked:win.showMinimized() }
                            }
                            Rectangle { width:18;height:18;radius:9;color:xch.containsMouse?"#F87171":clt("#EF4444","#EF4444")
                                MouseArea { id:xch;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;hoverEnabled:true;onClicked:Qt.quit() }
                            }
                        }
                    }

                    // MESSAGE LIST
                    Item {
                        id:msgArea; width:parent.width; height:parent.height - 180; clip:true

                        ListView {
                            id: msgList
                            anchors.top: parent.top; anchors.left: parent.left; anchors.leftMargin: 4
                            anchors.right: parent.right; anchors.rightMargin: 4; anchors.bottom: parent.bottom; clip:true
                            spacing: 8; topMargin: 14; bottomMargin: 14
                            model: msgs; boundsBehavior:Flickable.StopAtBounds; focus:true
                            flickDeceleration: 5000

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
                                property bool im: modelData.is_me || (modelData.sender&&String(modelData.sender.uid||"")===myUid) || String(modelData.from_uid||"")===myUid
                                property string txt: (modelData.content || modelData.text || "")
                                property string msgId: String(modelData.id || 0)
                                property bool pending: modelData._pending || false
                                height: childrenRect.height + 6

                                // 黄金分割线: 左至右61.8%
                                property int maxBubbleWidth: Math.floor((parent ? parent.width : 400) * 0.618)

                                // 别人消息 — 左侧头像 + 气泡偏左
                                Row {
                                    visible: !im; anchors.left: parent.left; anchors.leftMargin: 4
                                    spacing: 8
                                    Rectangle { width:34; height:34; radius:avatarRounded?8:17
                                        color:clt("#DCE0F0","#1A2848"); clip:true
                                        Image { anchors.centerIn:parent; width:28; height:28
                                            source: curAvatarSource || getAvatar(curUid)
                                            fillMode:Image.PreserveAspectCrop;asynchronous:true }
                                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                                            onClicked: { if(curUid) bridge.requestAvatar(curUid) } }
                                    }
                                    Rectangle {
                                        property int bw: Math.min(Math.max(String(txt).length*14+50,56), msgRow.maxBubbleWidth)
                                        width: bw; height: Math.max(34, txtEditIn.contentHeight + 36); radius: 16
                                        color: clt(cardBg2,"#111D35"); border.color: clt("#D0D6E8","#1E2E50"); border.width: 1
                                        TextEdit {
                                            id:txtEditIn; anchors.left:parent.left; anchors.leftMargin:12
                                            anchors.right:parent.right; anchors.rightMargin:12
                                            anchors.top:parent.top; anchors.topMargin:10
                                            height:contentHeight; readOnly:true; selectByMouse:true
                                            text:msgRow.txt; font.pixelSize:15; color:clt(text1,text1)
                                            wrapMode:TextEdit.WordWrap; textFormat:TextEdit.PlainText
                                        }
                                        Text {
                                            anchors.right:parent.right; anchors.rightMargin:10
                                            anchors.bottom:parent.bottom; anchors.bottomMargin:6
                                            text: tFull(modelData.time||0)
                                            font.pixelSize:10; color:clt(text3,text3)
                                        }
                                        // 右键透明遮罩（必须在 TextEdit 之后，覆盖在上面）
                                        Rectangle { anchors.fill: parent; color: "transparent"
                                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton
                                                onClicked: function(mouse) {
                                                    msgMenu._id = String(modelData.id || 0); msgMenu._txt = msgRow.txt
                                                    var gp = mapToItem(null, mouse.x, mouse.y); msgMenu.x = gp.x; msgMenu.y = gp.y
                                                    msgMenu.open()
                                                }
                                            }
                                        }
                                    }
                                }

                                // 自己消息 — 气泡 + 右侧头像
                                Row {
                                    visible: im; anchors.right: parent.right; anchors.rightMargin: 4; spacing: 8
                                    Rectangle {
                                        property int bw: Math.min(Math.max(String(txt).length*14+50,56), msgRow.maxBubbleWidth)
                                        width: bw; height: Math.max(34, txtEditMe.contentHeight + 36); radius: 16
                                        color: pending ? Qt.lighter(acc, 1.3) : acc
                                        TextEdit {
                                            id:txtEditMe; anchors.left:parent.left; anchors.leftMargin:12
                                            anchors.right:parent.right; anchors.rightMargin:12
                                            anchors.top:parent.top; anchors.topMargin:10
                                            height:contentHeight; readOnly:true; selectByMouse:true
                                            text:msgRow.txt; font.pixelSize:15; color:"#FFFFFF"
                                            wrapMode:TextEdit.WordWrap; textFormat:TextEdit.PlainText
                                        }
                                        Text {
                                            anchors.right:parent.right; anchors.rightMargin:10
                                            anchors.bottom:parent.bottom; anchors.bottomMargin:6
                                            text: pending ? "发送中..." : tFull(modelData.time||0)
                                            font.pixelSize:10; color:"#ffffff60"
                                        }
                                        Rectangle { anchors.fill: parent; color: "transparent"
                                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton
                                                onClicked: function(mouse) {
                                                    msgMenu._id = String(modelData.id || 0); msgMenu._txt = msgRow.txt
                                                    var gp = mapToItem(null, mouse.x, mouse.y); msgMenu.x = gp.x; msgMenu.y = gp.y
                                                    msgMenu.open()
                                                }
                                            }
                                        }
                                    }
                                    // 自己头像
                                    Rectangle { width:34; height:34; radius:avatarRounded?8:17
                                        color:clt("#D8DDF0","#1E2850"); clip:true
                                        Image { anchors.centerIn:parent; width:28; height:28
                                            source: getAvatar(myUid)
                                            fillMode:Image.PreserveAspectCrop;asynchronous:true }
                                        MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                                            onClicked: { if(myUid) bridge.requestAvatar(myUid) } }
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

                            ScrollBar.vertical: ScrollBar{policy:ScrollBar.AsNeeded; width:8; contentItem:Rectangle{radius:4;color:clt("#A0A8C0","#404860");opacity:0.6}}
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
                                width:parent.width; height:inputArea.height-42; radius:16
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
                                Rectangle { width:72;height:34;radius:17
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
        background: Rectangle{radius:14;color:clt("#FFFFFF","#111830");border.color:clt("#D8DDF0","#1E2E50");border.width:1}
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
            Rectangle { width:72;height:72;radius:avatarRounded?14:36;anchors.horizontalCenter:parent.horizontalCenter;color:clt("#E4E8F4","#1A2850")
                Image { anchors.fill:parent;anchors.margins:2
                    source: getAvatar(profUid)
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
        property string defaultSysPrompt: "你是我的私信管理助手。不要透露你自己的真实身份，只需要专注于判断消息重要性。如果重要请在回复中包含用户设定的关键词。"
        property string defaultQTemplate: "你是我的私信管理助手，你需要帮我判断这个信息是否是重要的。重要的定义是排除娱乐等无意义内容，重要内容包含讨论问题，紧急情况等信息，是我在上课的时候需要了解的信息。如果重要，请在回复中分析之后明确包含 {keyword} 这个子串（如果有必要就分析，可以给我提示，以 提示： 开头，。 结束的话就是你针对这个消息给我的提示，可以视情况而决定写不写），可以加入你的分析和给我的提示。如果不重要就是 不重要消息。只有重要消息，我需要尽量马上了解的你才说。如果无法判断或者不是重要信息，请勿输出 {keyword} 这个子串（不能包含这个子串）。"
        property string localSysPrompt: defaultSysPrompt
        property string localQTemplate: defaultQTemplate
        property int tab: 0
        property bool localNPopup: true
        property string localNMode: "ai"
        property bool localNSound: true
        property string localNType: "system"
        property string localNFile: ""
        property string localPrefix: ""
        property string localSuffix: ""

        // 自动回复
        property bool localAREnabled: false
        property string localARKeyword: "Zhl需要回复"
        property string localARSysPrompt: "你是我的私信助手，需要帮我对重要的消息进行回复。"
        property string localARCheckQ: "以下是一条消息，请判断是否需要回复。需要回复的消息通常是提问、请求或需要回应的内容。如果不需要回复请回复「不需要」，如果需要请回复「需要」并简要说明原因：\n{message}"
        property string localARQuestion: "以下是一条需要回复的消息，请帮我生成一个简短得体的回复：\n{message}"

        // 背景设置
        property bool localBGEnabled: false
        property string localBGMode: "conversation"
        property int localBGMax: 20
        property int localBGChars: 2000
        property string localBGSuffix: ""

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
            localSysPrompt = (c.ai && c.ai.system_prompt) ? c.ai.system_prompt : stg.defaultSysPrompt
            localQTemplate = (c.ai && c.ai.question_template) ? c.ai.question_template : stg.defaultQTemplate
            if (c.ai && c.ai.custom) {
                localApiUrl = c.ai.custom.base_url || ""
                localApiKey = c.ai.custom.api_key || ""
                localApiModel = c.ai.custom.model || ""
                localCustomSysPrompt = c.ai.custom.custom_system_prompt || stg.defaultSysPrompt
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
            if (c.auto_reply) {
                localAREnabled = c.auto_reply.enabled !== false ? true : false
                localARKeyword = c.auto_reply.keyword || "Zhl需要回复"
                localARSysPrompt = c.auto_reply.system_prompt || ""
                localARQuestion = c.auto_reply.question_template || ""
                localARCheckQ = c.auto_reply.check_question || ""
            }
            if (c.background) {
                localBGEnabled = c.background.enabled || false
                localBGMode = c.background.mode || "conversation"
                localBGMax = c.background.max_messages || 20
                localBGChars = c.background.max_chars || 2000
                localBGSuffix = c.background.suffix || ""
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
            Rectangle { width:parent.width; height:50; color:clt("#F6F8FF","#080F1E")
                Row { anchors.centerIn: parent; spacing: 8
                    Repeater {
                        model: ["账号","通知","服务器","外观"]
                        Rectangle { width:86; height:36; radius:18
                            color: index === stg.tab ? acc : "transparent"
                            border.color: index === stg.tab ? "transparent" : clt(bd1,bd2)
                            border.width: index === stg.tab ? 0 : 1
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Text { anchors.centerIn:parent; text:modelData; font.pixelSize:14; font.weight: index===stg.tab ? Font.DemiBold : Font.Normal; color: index===stg.tab ? "white" : clt(text2,text2) }
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

                    // ═══ TAB 1: 通知 ═══
                    Column { width:parent.width; spacing:12; visible:stg.tab===1; height:stg.tab===1?undefined:0
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

                    // ═══ TAB 2: 服务器 ═══
                    Column { width:parent.width; spacing:12; visible:stg.tab===2; height:stg.tab===2?undefined:0
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

                    // ═══ TAB 3: 外观 ═══
                    Column { width:parent.width; spacing:14; visible:stg.tab===3; height:stg.tab===3?undefined:0
                        Text { text:"头像圆角"; font.pixelSize:15; font.weight:Font.DemiBold; color:clt(text1,text1) }
                        Text { font.pixelSize:12; color:clt(text3,text3); text:"开启后所有头像从正圆变为圆角矩形。"; wrapMode:Text.WordWrap; width:parent.width-8 }
                        Row { spacing:12
                            Rectangle { width:100; height:36; radius:12
                                color: avatarRounded ? acc : clt("#EEF0F8","#121830")
                                border.color: avatarRounded ? "transparent" : clt(bd1,bd2); border.width: avatarRounded ? 0 : 1
                                Text { anchors.centerIn:parent; text:"圆角矩形"; font.pixelSize:13; color: avatarRounded ? "white" : clt(text2,text2) }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: avatarRounded = true }
                            }
                            Rectangle { width:80; height:36; radius:12
                                color: !avatarRounded ? acc : clt("#EEF0F8","#121830")
                                border.color: !avatarRounded ? "transparent" : clt(bd1,bd2); border.width: !avatarRounded ? 0 : 1
                                Text { anchors.centerIn:parent; text:"正圆"; font.pixelSize:13; color: !avatarRounded ? "white" : clt(text2,text2) }
                                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: avatarRounded = false }
                            }
                        }
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
                                theme: { mode: themeMode, accent: acc, avatar_rounded: avatarRounded }
                            }
                            bridge.saveConfig(JSON.stringify(C)); toast("设置已保存")
                        }}
                    }
                }
            }
        }
    }

    // ═══ AI 设置面板 (独立于设置) ═══
    Popup {
        id: stgAI; modal: true; focus: true; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        width: Math.min(win.width * 0.7, 600); height: Math.min(win.height * 0.8, 620)
        x: (win.width - width) / 2; y: (win.height - height) / 2; padding: 0
        background: Rectangle { radius: 20; color: clt(cardBg, "#0C1324"); border.color: clt(bd1, bd2); border.width: 1 }
        property int aitab: 0

        Column { width: parent.width; height: parent.height
            // 标题栏
            Rectangle { width: parent.width; height: 50; color: "transparent"
                Row { anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { text: "🤖"; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "AI 设置"; font.pixelSize: 19; font.bold: true; color: clt(text1, text1); anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 9; color: caih.containsMouse ? red : clt("#EEF0F8", "#121830")
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 15; color: caih.containsMouse ? "white" : clt(text2, text2) }
                    MouseArea { id: caih; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: stgAI.close() }
                }
            }
            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }

            // 标签栏
            Rectangle { width: parent.width; height: 50; color: clt("#F6F8FF", "#080F1E")
                Row { anchors.centerIn: parent; spacing: 8
                    Repeater {
                        model: ["配置AI", "提示", "自动回复", "背景"]
                        Rectangle { width: 86; height: 36; radius: 18
                            color: index === stgAI.aitab ? acc : "transparent"
                            border.color: index === stgAI.aitab ? "transparent" : clt(bd1, bd2)
                            border.width: index === stgAI.aitab ? 0 : 1
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 14; font.weight: index === stgAI.aitab ? Font.DemiBold : Font.Normal; color: index === stgAI.aitab ? "white" : clt(text2, text2) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: stgAI.aitab = index }
                        }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }

            // 内容区
            Flickable { id: aisf; width: parent.width; height: parent.height - 103; contentHeight: aicol.height + 24; clip: true
                Column { id: aicol; width: parent.width - 32; x: 16; topPadding: 18; spacing: 14

                    // ═══ TAB 0: 配置AI ═══
                    Column { width: parent.width; spacing: 14; visible: stgAI.aitab === 0; height: stgAI.aitab === 0 ? undefined : 0
                        Text { text: "AI 提供商"; font.pixelSize: 18; font.bold: true; color: clt(text1, text1) }
                        Row { spacing: 10; width: parent.width
                            Rectangle { width: parent.width / 2 - 5; height: 72; radius: 16
                                color: useDefaultAI ? clt("#E4EAFA","#142048") : clt("#F2F4FC","#111830")
                                border.color: useDefaultAI ? acc : clt(bd1,bd2); border.width: useDefaultAI ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "默认 AI"; font.pixelSize: 16; font.bold: useDefaultAI; color: clt(text1, text1) }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: "内置模型"; font.pixelSize: 12; color: clt(text3, text3) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: useDefaultAI = true }
                            }
                            Rectangle { width: parent.width / 2 - 5; height: 72; radius: 16
                                color: !useDefaultAI ? clt("#E4EAFA","#142048") : clt("#F2F4FC","#111830")
                                border.color: !useDefaultAI ? acc : clt(bd1,bd2); border.width: !useDefaultAI ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "自定义 API"; font.pixelSize: 16; font.bold: !useDefaultAI; color: clt(text1, text1) }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: "OpenAI 兼容"; font.pixelSize: 12; color: clt(text3, text3) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: useDefaultAI = false }
                            }
                        }

                        // 默认AI说明
                        Column { visible: useDefaultAI; spacing: 8; width: parent.width
                            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                            Rectangle { width: parent.width; radius: 12; color: clt("#EEF2FF", "#0E1530"); border.color: clt(bd1, bd2); border.width: 1
                                Column { anchors.fill: parent; anchors.margins: 14; spacing: 6
                                    Row { spacing: 6
                                        Rectangle { width: 6; height: 6; radius: 3; color: acc; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "使用系统内置模型，无需额外配置 API Key"; font.pixelSize: 13; color: acc; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text { text: "系统提示词和检测模板可在「提示」标签页中配置。"; font.pixelSize: 12; color: clt(text2, text2); wrapMode: Text.WordWrap; width: parent.width - 20 }
                                }
                            }
                        }

                        // 自定义API配置
                        Column { visible: !useDefaultAI; spacing: 12; width: parent.width
                            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                            Text { text: "API Base URL"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Rectangle { width: parent.width; height: 42; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                TextInput { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; font.pixelSize: 14; color: clt(text1, text1)
                                    text: stg.localApiUrl; onTextChanged: stg.localApiUrl = text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                            }
                            Text { text: "API Key"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Rectangle { width: parent.width; height: 42; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                TextInput { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; font.pixelSize: 14; color: clt(text1, text1)
                                    echoMode: TextInput.Password; text: stg.localApiKey; onTextChanged: stg.localApiKey = text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                            }
                            Text { text: "模型名称"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Rectangle { width: parent.width; height: 42; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                TextInput { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; font.pixelSize: 14; color: clt(text1, text1)
                                    text: stg.localApiModel; onTextChanged: stg.localApiModel = text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                            }
                        }
                    }

                    // ═══ TAB 1: 提示 ═══
                    Column { width: parent.width; spacing: 14; visible: stgAI.aitab === 1; height: stgAI.aitab === 1 ? undefined : 0
                        Text { text: "提示词配置"; font.pixelSize: 18; font.bold: true; color: clt(text1, text1) }

                        // 系统提示词 — 仅自定义AI可编辑
                        Column { spacing: 10; width: parent.width
                            visible: !useDefaultAI
                            Text { text: "系统提示词"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Rectangle { width: parent.width; height: 80; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                TextArea { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                                    font.pixelSize: 13; color: clt(text1, text1); text: stg.localCustomSysPrompt
                                    onTextChanged: stg.localCustomSysPrompt = text; wrapMode: TextEdit.WordWrap; background: null; selectByMouse: true }
                            }
                            Text { font.pixelSize: 11; color: clt(text3, text3); text: "AI 的角色设定，告诉 AI 它是什么。" }
                        }
                        // 默认AI: 系统提示词只读说明
                        Rectangle { visible: useDefaultAI; width: parent.width; radius: 12; color: clt("#EEF2FF", "#0E1530"); border.color: clt(bd1, bd2); border.width: 1
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 4
                                Text { font.pixelSize: 12; color: clt(text2, text2); text: "默认模型不支持自定义系统提示词，使用内置固定值。切换至自定义 API 后可编辑。"; wrapMode: Text.WordWrap; width: parent.width - 16 }
                            }
                        }

                        // 普通提示词 — 都可用 (默认AI用localQTemplate, 自定义AI用localQTemplate)
                        Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                        Text { text: "普通提示词 (检测模板)"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                        Rectangle { width: parent.width; height: 130; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                            TextArea { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                                font.pixelSize: 13; color: clt(text1, text1); text: stg.localQTemplate
                                onTextChanged: stg.localQTemplate = text; wrapMode: TextEdit.WordWrap; background: null; selectByMouse: true }
                        }
                        Text { font.pixelSize: 11; color: clt(text3, text3); text: "检测消息重要性时发送给 AI 的模板，会自动拼接消息。用 {keyword} 代表检测子串。" }

                        // 背景提示
                        Rectangle { width: parent.width; radius: 12; color: clt("#EEF2FF", "#0E1530"); border.color: clt(bd1, bd2); border.width: 1
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 4
                                Text { font.pixelSize: 12; color: clt(text2, text2); text: "提示词模板中可用 {background} 引用对方聊天历史。详细配置请在「背景」标签页中设置。"; wrapMode: Text.WordWrap; width: parent.width - 16 }
                            }
                        }
                    }

                    // ═══ TAB 2: 自动回复 ═══
                    Column { width: parent.width; spacing: 14; visible: stgAI.aitab === 2; height: stgAI.aitab === 2 ? undefined : 0
                        Text { text: "自动回复"; font.pixelSize: 18; font.bold: true; color: clt(text1, text1) }

                        // 权限提示
                        Rectangle { width: parent.width; radius: 12; color: clt("#EEF2FF", "#0E1530"); border.color: clt(bd1, bd2); border.width: 1
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 4
                                Text { font.pixelSize: 12; color: clt(text2, text2); text: "默认模型不支持自动回复功能。仅自定义 API 或 UID 1049425 可使用。"; wrapMode: Text.WordWrap; width: parent.width - 16 }
                            }
                        }

                        // 启用开关
                        Row { spacing: 12
                            Text { text: "启用自动回复"; font.pixelSize: 15; color: clt(text1, text1); anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 50; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter; color: stg.localAREnabled ? acc : clt("#CCD0E0", "#283050")
                                Rectangle { width: 24; height: 24; radius: 12; x: stg.localAREnabled ? 24 : 2; anchors.verticalCenter: parent.verticalCenter; color: "white"; Behavior on x { NumberAnimation { duration: 150 } } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: stg.localAREnabled = !stg.localAREnabled }
                            }
                        }

                        // 触发关键词
                        Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                        Text { text: "触发关键词"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                        Rectangle { width: parent.width; height: 42; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                            TextInput { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; font.pixelSize: 14; color: clt(text1, text1)
                                text: stg.localARKeyword; onTextChanged: stg.localARKeyword = text; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true }
                        }
                        Text { font.pixelSize: 11; color: clt(text3, text3); text: "消息中包含此关键词时触发自动回复。" }

                        // 系统提示词
                        Text { text: "系统提示词"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                        Rectangle { width: parent.width; height: 72; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                            TextArea { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                                font.pixelSize: 13; color: clt(text1, text1); text: stg.localARSysPrompt; onTextChanged: stg.localARSysPrompt = text
                                wrapMode: TextEdit.WordWrap; background: null; selectByMouse: true }
                        }
                        Text { font.pixelSize: 11; color: clt(text3, text3); text: "AI 的角色设定。" }

                        // 判断问题
                        Text { text: "判断是否需要回复"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                        Rectangle { width: parent.width; height: 80; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                            TextArea { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                                font.pixelSize: 13; color: clt(text1, text1); text: stg.localARCheckQ; onTextChanged: stg.localARCheckQ = text
                                wrapMode: TextEdit.WordWrap; background: null; selectByMouse: true }
                        }
                        Text { font.pixelSize: 11; color: clt(text3, text3); text: "先询问 AI 此消息是否需要回复。若 AI 判断「需要」才继续生成回复。用 {message} 代表原始消息。" }

                        // 提问模板
                        Text { text: "回复内容模板"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                        Rectangle { width: parent.width; height: 80; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                            TextArea { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                                font.pixelSize: 13; color: clt(text1, text1); text: stg.localARQuestion; onTextChanged: stg.localARQuestion = text
                                wrapMode: TextEdit.WordWrap; background: null; selectByMouse: true }
                        }
                        Text { font.pixelSize: 11; color: clt(text3, text3); text: "若需要回复，用此模板生成回复内容。" }
                    }

                    // ═══ TAB 3: 背景 ═══
                    Column { width: parent.width; spacing: 14; visible: stgAI.aitab === 3; height: stgAI.aitab === 3 ? undefined : 0
                        Text { text: "聊天背景上下文"; font.pixelSize: 18; font.bold: true; color: clt(text1, text1) }

                        Rectangle { width: parent.width; radius: 12; color: clt("#EEF2FF", "#0E1530"); border.color: clt(bd1, bd2); border.width: 1
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 4
                                Text { font.pixelSize: 12; color: clt(text2, text2); text: "在提示词模板和自动回复模板中使用 {background} 即可引用聊天上下文。AI 会看到与此人的历史对话（含对方名字）。"; wrapMode: Text.WordWrap; width: parent.width - 16 }
                            }
                        }

                        // 启用开关
                        Row { spacing: 12
                            Text { text: "启用背景"; font.pixelSize: 15; color: clt(text1, text1); anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 50; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter; color: stg.localBGEnabled ? acc : clt("#CCD0E0", "#283050")
                                Rectangle { width: 24; height: 24; radius: 12; x: stg.localBGEnabled ? 24 : 2; anchors.verticalCenter: parent.verticalCenter; color: "white"; Behavior on x { NumberAnimation { duration: 150 } } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: stg.localBGEnabled = !stg.localBGEnabled }
                            }
                        }

                        Column { visible: stg.localBGEnabled; spacing: 12; width: parent.width
                            // 背景来源
                            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                            Text { text: "背景来源"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Row { spacing: 10
                                Repeater {
                                    model: [["conversation", "当前对话"], ["recent", "最近所有"]]
                                    Rectangle { width: 90; height: 34; radius: 12
                                        color: stg.localBGMode === modelData[0] ? acc : clt("#EEF0F8", "#121830")
                                        border.color: stg.localBGMode === modelData[0] ? "transparent" : clt(bd1, bd2); border.width: stg.localBGMode === modelData[0] ? 0 : 1
                                        Text { anchors.centerIn: parent; text: modelData[1]; font.pixelSize: 12; color: stg.localBGMode === modelData[0] ? "white" : clt(text2, text2) }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: stg.localBGMode = modelData[0] }
                                    }
                                }
                            }
                            Text { font.pixelSize: 11; color: clt(text3, text3); text: "当前对话: 仅使用已缓存的对话记录 | 最近所有: 缓存不够时逐页拉取历史（间隔 0.8s，有缓存）"; wrapMode: Text.WordWrap; width: parent.width - 8 }

                            // 限制设置
                            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                            Text { text: "限制设置"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Text { font.pixelSize: 11; color: clt(text3, text3); text: "从最新消息开始取，条数和字符数双限制，取最严格的。"; wrapMode: Text.WordWrap; width: parent.width - 8 }

                            // 条数
                            Row { spacing: 8
                                Text { text: "最大条数"; font.pixelSize: 14; color: clt(text2, text2); anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { width: 64; height: 34; radius: 10; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                    TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; font.pixelSize: 14; color: clt(text1, text1)
                                        text: stg.localBGMax; onTextChanged: stg.localBGMax = parseInt(text) || 20; verticalAlignment: TextInput.AlignVCenter
                                        validator: IntValidator { bottom: 1; top: 500 } }
                                }
                                Text { text: "条"; font.pixelSize: 14; color: clt(text2, text2); anchors.verticalCenter: parent.verticalCenter }
                            }

                            // 字符数
                            Row { spacing: 8
                                Text { text: "最大字符数"; font.pixelSize: 14; color: clt(text2, text2); anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { width: 64; height: 34; radius: 10; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                    TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; font.pixelSize: 14; color: clt(text1, text1)
                                        text: stg.localBGChars; onTextChanged: stg.localBGChars = parseInt(text) || 2000; verticalAlignment: TextInput.AlignVCenter
                                        validator: IntValidator { bottom: 100; top: 20000 } }
                                }
                                Text { text: "字"; font.pixelSize: 14; color: clt(text2, text2); anchors.verticalCenter: parent.verticalCenter }
                            }

                            // 自定义后缀
                            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
                            Text { text: "自定义后缀"; font.pixelSize: 14; font.weight: Font.DemiBold; color: clt(text1, text1) }
                            Rectangle { width: parent.width; height: 80; radius: 12; color: clt("#F2F4FC", "#111830"); border.color: clt(bd1, bd2); border.width: 1
                                TextArea { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                                    font.pixelSize: 13; color: clt(text1, text1); text: stg.localBGSuffix; onTextChanged: stg.localBGSuffix = text
                                    wrapMode: TextEdit.WordWrap; background: null; selectByMouse: true }
                            }
                            Text { font.pixelSize: 11; color: clt(text3, text3); text: "后缀附加在聊天历史末尾，用于额外指令。聊天历史格式: [对方名字]: 消息内容 | [我]: 回复内容" }
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6; contentItem: Rectangle { radius: 3; color: clt("#A0A8C0", "#404860"); opacity: 0.6 } }
            }

            // 底部保存
            Rectangle { width: parent.width; height: 1; color: clt(bd1, bd2) }
            Rectangle { width: parent.width; height: 44; color: "transparent"
                Row { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Rectangle { width: 80; height: 34; radius: 12; color: clt("#EEF0F8", "#121830")
                        Text { anchors.centerIn: parent; text: "取消"; font.pixelSize: 14; color: clt(text2, text2) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { reloadCfg(); stgAI.close() } }
                    }
                    Rectangle { width: 80; height: 34; radius: 12; color: acc
                        Text { anchors.centerIn: parent; text: "保存"; color: "white"; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                            var C = {
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
                                auto_reply: {
                                    enabled: stg.localAREnabled,
                                    keyword: stg.localARKeyword,
                                    system_prompt: stg.localARSysPrompt,
                                    check_question: stg.localARCheckQ,
                                    question_template: stg.localARQuestion
                                },
                                background: {
                                    enabled: stg.localBGEnabled,
                                    mode: stg.localBGMode,
                                    max_messages: stg.localBGMax,
                                    max_chars: stg.localBGChars,
                                    suffix: stg.localBGSuffix
                                }
                            }
                            bridge.saveConfig(JSON.stringify(C)); toast("AI 设置已保存")
                        } }
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
        Qt.callLater(function(){ triggerListRefresh() })
        try{ var s = JSON.parse(bridge.getServerStatus()); serverRem = s.remaining || 0; serverTotal = s.total || 0 } catch(e) {}
    }
    Timer { id: autoRefreshTimer; interval: 30000; repeat: true; onTriggered: { if(myUid) triggerListRefresh() } }
    Timer { id: sendRefreshTimer; interval: 800; repeat: false; onTriggered: { if(curUid) loadMsgs(curUid, -1) } }
    Timer { id: searchTimer; interval: 300; repeat: false; onTriggered: doSearch() }
}
