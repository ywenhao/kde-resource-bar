import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Format.js" as F

Item {
    id: tile
    required property string kind
    required property var monitor
    property bool vertical: false
    property bool keyDismissed: false
    readonly property bool net: kind === "network"
    readonly property bool cpuMode: kind === "cpu"
    readonly property real pct: (cpuMode ? monitor.cpu?.pct : monitor.memory?.pct) || 0
    readonly property string reading: F.percent(cpuMode ? monitor.cpu?.pct : monitor.memory?.pct)
    readonly property color accent: cpuMode ? Kirigami.Theme.linkColor : Kirigami.Theme.positiveTextColor
    readonly property bool oneLine: !vertical && height < 26
    readonly property bool pointerInside: visible && pointer.hovered
    readonly property bool keyActive: visible && activeFocus && !keyDismissed
    readonly property bool engaged: pointerInside || keyActive
    readonly property int lineSize: Math.max(9, Math.min(Math.round(Kirigami.Theme.defaultFont.pixelSize > 0
        ? Kirigami.Theme.defaultFont.pixelSize : Kirigami.Theme.defaultFont.pointSize * 4 / 3), 14,
        Math.floor((height - 2) / (oneLine ? 1 : 2)) - 1))
    objectName: "tile-" + kind
    implicitWidth: Math.ceil(net ? (oneLine ? 2.05 : 1.08) * Math.max(metrics.advanceWidth("↓ 999 MB/s"),
                                    upload.implicitWidth, download.implicitWidth) + 9
                                : oneLine ? metrics.advanceWidth("CPU 100%") + 15 : metrics.advanceWidth("100%") + 18)
    activeFocusOnTab: true
    Accessible.role: Accessible.Indicator
    Accessible.name: net ? "网速" : cpuMode ? "CPU " + reading : "内存 " + reading

    HoverHandler { id: pointer }
    onActiveFocusChanged: keyDismissed = false
    Keys.onEscapePressed: keyDismissed = true

    FontMetrics { id: metrics; font.pixelSize: 13; font.family: Kirigami.Theme.defaultFont.family }
    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.highlightColor, tile.engaged ? 0.15 : 0)
    }
    component SmallText: Text {
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: tile.lineSize
        textFormat: Text.PlainText
        color: Kirigami.Theme.textColor
        renderType: Text.QtRendering
    }
    component RateText: SmallText {
        width: tile.vertical ? tile.width : implicitWidth
        fontSizeMode: tile.vertical ? Text.HorizontalFit : Text.FixedSize
        minimumPixelSize: 1
        horizontalAlignment: Text.AlignHCenter
    }
    Row {
        visible: !tile.net
        anchors.centerIn: parent
        spacing: 4
        Rectangle {
            width: 4; height: Math.max(10, Math.min(tile.height - 6, 24))
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
            Rectangle {
                width: parent.width; anchors.bottom: parent.bottom
                height: parent.height * Math.min(100, tile.pct) / 100
                radius: 1; color: tile.accent
            }
        }
        Grid {
            anchors.verticalCenter: parent.verticalCenter
            columns: tile.oneLine ? 2 : 1
            columnSpacing: 3
            SmallText { text: tile.cpuMode ? "CPU" : "内存"; color: tile.accent; font.weight: Font.DemiBold }
            SmallText { text: tile.reading; font.weight: Font.Medium }
        }
    }
    Grid {
        visible: tile.net
        anchors.centerIn: parent
        columns: tile.oneLine ? 2 : 1
        columnSpacing: 5
        RateText { id: upload; text: "↑ " + F.networkRate(tile.monitor.network?.txRate); color: Kirigami.Theme.positiveTextColor }
        RateText { id: download; text: "↓ " + F.networkRate(tile.monitor.network?.rxRate); color: Kirigami.Theme.linkColor }
    }
}
