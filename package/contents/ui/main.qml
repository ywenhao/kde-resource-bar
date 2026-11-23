import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: applet
    readonly property bool verticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property Item currentView: onDesktop ? fullRepresentationItem : compactRepresentationItem
    readonly property real barWidth: currentView?.implicitWidth || 192
    readonly property real barHeight: currentView?.implicitHeight || 34

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    implicitWidth: barWidth
    implicitHeight: barHeight
    Layout.minimumWidth: verticalPanel ? 18 : barWidth
    Layout.preferredWidth: barWidth
    Layout.maximumWidth: verticalPanel ? Infinity : barWidth
    Layout.minimumHeight: verticalPanel ? barHeight : 16
    Layout.preferredHeight: barHeight
    Layout.maximumHeight: verticalPanel ? barHeight : Infinity
    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    component BarView: MetricStrip {
        showCpu: Plasmoid.configuration.showCpu
        showMemory: Plasmoid.configuration.showMemory
        showNetwork: Plasmoid.configuration.showNetwork
        vertical: applet.verticalPanel
        edge: Plasmoid.location
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
    }
    compactRepresentation: BarView {}
    fullRepresentation: BarView {}
}
