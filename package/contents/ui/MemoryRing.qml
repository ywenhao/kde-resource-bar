import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: ring
    property var segments: []
    property string valueText: "—"
    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"), c = width / 2, r = c - 5
            ctx.clearRect(0, 0, width, height)
            if (r <= 0) return
            ctx.lineWidth = 7
            ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.12)
            ctx.beginPath(); ctx.arc(c, height / 2, r, 0, 2*Math.PI); ctx.stroke()
            let start = -Math.PI / 2
            for (const segment of ring.segments) {
                const end = start + 2 * Math.PI * segment.part
                if (end > start + 0.012) {
                    ctx.beginPath(); ctx.strokeStyle = segment.color
                    ctx.arc(c, height / 2, r, start + 0.006, end - 0.006); ctx.stroke()
                }
                start = end
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    onSegmentsChanged: canvas.requestPaint()
    Text {
        anchors.centerIn: parent
        text: ring.valueText
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.defaultFont
    }
}
