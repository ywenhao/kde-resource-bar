import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: strip
    property bool showCpu: true
    property bool showMemory: true
    property bool showNetwork: true
    property bool vertical: false
    property int edge: PlasmaCore.Types.BottomEdge
    property alias monitor: sampler
    signal configureRequested()

    readonly property bool anyEnabled: showCpu || showMemory || showNetwork
    readonly property Item activeTile: cpu.pointerInside ? cpu : memory.pointerInside ? memory : network.pointerInside ? network
        : cpu.keyActive ? cpu : memory.keyActive ? memory : network.keyActive ? network : null
    readonly property string hovered: activeTile ? activeTile.kind : ""
    property Item tipAnchor: null
    onActiveTileChanged: {
        // Wayland positions a new popup relative to its anchor when it opens.
        tipAnchor = null
        if (activeTile) hoverDelay.restart()
        else hoverDelay.stop()
    }
    Timer { id: hoverDelay; interval: 150; onTriggered: strip.tipAnchor = strip.activeTile }
    PlasmaCore.Dialog {
        id: popup
        objectName: "resource-hover-window"
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.ToolTip | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        outputOnly: true
        backgroundHints: PlasmaCore.Dialog.NoBackground
        location: strip.edge
        visualParent: strip.tipAnchor
        visible: strip.tipAnchor !== null && strip.tipAnchor === strip.activeTile
        mainItem: DetailPanel { kind: strip.hovered; monitor: sampler }
    }
    readonly property int tileHeight: vertical ? 33 : (height > 0 ? Math.min(42, height) : 34)
    readonly property int count: Number(showCpu) + Number(showMemory) + Number(showNetwork)
    // A new panel item is initially 0 × 0. Compute its requested size without
    // relying on Grid geometry; Grid omits children with a zero dimension.
    implicitWidth: vertical ? 50 : !count ? 24 : (showCpu ? cpu.implicitWidth : 0)
        + (showMemory ? memory.implicitWidth : 0) + (showNetwork ? network.implicitWidth : 0)
        + Math.max(0, count - 1) * Kirigami.Units.smallSpacing
    implicitHeight: vertical ? Math.max(1, count) * tileHeight + Math.max(0, count - 1) : 34
    Layout.minimumWidth: vertical ? 18 : implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: vertical ? Infinity : implicitWidth
    Layout.minimumHeight: vertical ? implicitHeight : 16
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: vertical ? implicitHeight : Infinity
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    Sampler {
        id: sampler
        showCpu: strip.showCpu
        showMemory: strip.showMemory
        showNetwork: strip.showNetwork
        detailKind: strip.hovered
    }
    Grid {
        id: layout
        anchors.centerIn: parent
        columns: strip.vertical ? 1 : 3
        spacing: strip.vertical ? 1 : Kirigami.Units.smallSpacing
        component Tile: MetricTile {
            monitor: sampler; vertical: strip.vertical
            height: strip.tileHeight
            width: strip.vertical ? strip.width : implicitWidth
        }
        Tile { id: cpu; kind: "cpu"; visible: strip.showCpu }
        Tile { id: memory; kind: "memory"; visible: strip.showMemory }
        Tile { id: network; kind: "network"; visible: strip.showNetwork }
        PlasmaCore.ToolTipArea {
            objectName: "disabled-placeholder"
            visible: !strip.anyEnabled
            location: strip.edge
            width: 24; height: strip.tileHeight
            mainText: "资源监视条"
            subText: "所有指标均已关闭。点击配置显示项目。"
            Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: "utilities-system-monitor"; opacity: 0.65 }
            MouseArea { anchors.fill: parent; onClicked: strip.configureRequested() }
        }
    }
}
