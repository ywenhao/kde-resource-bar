import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Format.js" as F

Rectangle {
    id: panel
    required property string kind
    required property var monitor
    objectName: "detail-" + kind
    readonly property var c: cpuMode && monitor.cpu || ({})
    readonly property var m: memMode && monitor.memory || ({})
    readonly property var n: netMode && monitor.network || ({})
    readonly property var detail: monitor.detailKind === kind ? monitor.details : null
    readonly property bool cpuMode: kind === "cpu"
    readonly property bool memMode: kind === "memory"
    readonly property bool netMode: kind === "network"
    readonly property bool netMatched: !!detail && detail.iface === n.iface
    readonly property color primary: Kirigami.Theme.linkColor
    readonly property color secondary: Kirigami.Theme.positiveTextColor
    readonly property color muted: Qt.alpha(Kirigami.Theme.textColor, 0.72)
    readonly property int inset: Kirigami.Units.largeSpacing
    readonly property var portions: memMode && m.total ? [
        {label: "应用", value: m.apps, part: m.apps / m.total, color: primary},
        {label: "内核及其他", value: m.kernel, part: m.kernel / m.total, color: Kirigami.Theme.neutralTextColor},
        {label: "缓存", value: m.cache, part: m.cache / m.total, color: secondary},
        {label: "空闲", value: m.free, part: m.free / m.total, color: Qt.alpha(Kirigami.Theme.textColor, 0.32)}
    ] : []
    implicitWidth: Kirigami.Units.gridUnit * 21
    implicitHeight: content.implicitHeight + inset * 2
    width: implicitWidth
    height: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    radius: Kirigami.Units.cornerRadius * 2
    color: Kirigami.Theme.backgroundColor
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.22)
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    component Caption: Text {
        color: Kirigami.Theme.textColor
        font.family: Kirigami.Theme.defaultFont.family
        textFormat: Text.PlainText
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    component Pair: RowLayout {
        property string label
        property string valueText
        Layout.fillWidth: true
        spacing: 8
        Caption { text: parent.label; color: panel.muted; Layout.fillWidth: true }
        Caption { text: parent.valueText }
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 3
        Layout.bottomMargin: 3
        color: Qt.alpha(Kirigami.Theme.textColor, 0.16)
    }
    component TrafficRow: RowLayout {
        property string label
        property string down
        property string up
        property bool heading: false
        Layout.fillWidth: true
        spacing: 5
        Caption { text: parent.label; color: parent.heading ? panel.muted : Kirigami.Theme.textColor; Layout.fillWidth: true }
        Caption { text: parent.down; color: parent.heading ? panel.muted : panel.primary; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: panel.implicitWidth * 0.24 }
        Caption { text: parent.up; color: parent.heading ? panel.muted : panel.secondary; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: panel.implicitWidth * 0.24 }
    }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: panel.inset }
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Caption {
                text: panel.cpuMode ? "CPU" : panel.memMode ? "内存" : "网络"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Caption {
                text: panel.cpuMode ? F.percent(panel.c.pct, 1) : panel.memMode
                    ? F.size(panel.m.used, 1) + " / " + F.size(panel.m.total, 1) : (panel.n.iface || "无默认路由")
                font.weight: Font.DemiBold
            }
        }
        RowLayout {
            visible: !panel.memMode
            Layout.fillWidth: true
            Caption {
                Layout.fillWidth: true
                text: panel.cpuMode ? "用户态  " + F.percent(panel.c.userPct, 1) : "↓ 下载  " + F.rate(panel.n.rxRate)
                color: panel.primary
            }
            Caption {
                text: panel.cpuMode ? "系统态  " + F.percent(panel.c.systemPct, 1) : "↑ 上传  " + F.rate(panel.n.txRate)
                color: panel.secondary
            }
        }
        HistoryGraph {
            visible: !panel.memMode
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.7
            stacked: panel.cpuMode
            points: panel.cpuMode ? panel.monitor.cpuHistory : panel.netMode ? panel.monitor.netHistory : []
            firstColor: panel.primary
            secondColor: panel.secondary
        }
        Caption {
            visible: !panel.memMode
            text: "最近 60 秒"
            color: panel.muted
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        Pair {
            visible: panel.cpuMode; label: "逻辑处理器 / 温度"
            valueText: (panel.c.cores || "—") + "  /  " + (panel.detail?.temperature != null ? Math.round(panel.detail.temperature) + " °C" : "—")
        }
        Pair {
            visible: panel.cpuMode; label: "平均负载 · 1 / 5 / 15 分钟"
            valueText: (panel.c.load || []).map(v => v.toFixed(2)).join("  /  ") || "—"
        }
        Pair { visible: panel.cpuMode; label: "运行时间"; valueText: F.uptime(panel.c.uptime) }

        RowLayout {
            visible: panel.memMode
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing * 2
            MemoryRing {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: Layout.preferredWidth
                segments: panel.portions; valueText: F.percent(panel.m.pct)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: panel.portions
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 3.5; color: modelData.color }
                        Caption { text: modelData.label; Layout.fillWidth: true }
                        Caption { text: F.size(modelData.value, 1) }
                    }
                }
            }
        }
        Pair { visible: panel.memMode; label: "可用内存"; valueText: F.size(panel.m.available, 1) }
        Pair { visible: panel.memMode; label: "内存压力 · PSI 10 秒"; valueText: F.percent(panel.m.pressure, 2) }
        Pair { visible: panel.memMode; label: "交换空间"; valueText: F.size(panel.m.swap, 1) + " / " + F.size(panel.m.swapTotal, 1) }
        Pair { visible: panel.memMode; label: "换入 / 换出"; valueText: F.rate(panel.m.inRate) + "  /  " + F.rate(panel.m.outRate) }

        Divider {}
        Caption {
            visible: !panel.netMode
            text: panel.cpuMode ? "进程 CPU · 单核 100%" : "进程内存 · RSS"
            font.weight: Font.DemiBold
        }
        Repeater {
            model: panel.netMode ? [] : panel.detail?.rows || []
            delegate: Pair {
                required property var modelData
                label: modelData.name
                valueText: panel.cpuMode ? F.percent(modelData.value, 1) : F.size(modelData.value)
            }
        }
        TrafficRow { visible: panel.netMode; label: "进程"; down: "↓ 下载"; up: "↑ 上传"; heading: true }
        Repeater {
            model: panel.netMode && panel.netMatched && panel.detail.status === "ok" ? panel.detail.rows : []
            delegate: TrafficRow {
                required property var modelData
                label: modelData.name; down: F.rate(modelData.rx); up: F.rate(modelData.tx)
            }
        }
        TrafficRow {
            visible: panel.netMode && panel.netMatched && panel.detail?.status === "ok"
            label: "其他流量"; down: F.rate(panel.detail?.other?.rx); up: F.rate(panel.detail?.other?.tx)
        }
        Caption {
            Layout.fillWidth: true
            color: panel.muted
            text: {
                if (panel.netMode && !panel.n.iface) return "等待网络连接"
                if (!panel.detail || (panel.netMode && !panel.netMatched)) return "正在采样…"
                if (panel.netMode) {
                    if (panel.detail.status === "unavailable") return "当前无法读取 TCP 进程计数"
                    if (panel.detail.status === "changing") return "正在切换网络接口…"
                    return ""
                }
                return panel.detail.rows?.length ? "" : "此采样窗口无活跃进程"
            }
            visible: text.length > 0
        }
    }
}
