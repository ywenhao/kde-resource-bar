import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: chart
    property var points: []
    property bool stacked: false
    required property color firstColor
    required property color secondColor
    readonly property color gridColor: Qt.alpha(Kirigami.Theme.textColor, 0.13)
    onPointsChanged: requestPaint()
    onFirstColorChanged: requestPaint()
    onSecondColorChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        const w = width, h = height
        ctx.clearRect(0, 0, w, h)
        ctx.lineWidth = 1
        ctx.strokeStyle = gridColor
        for (let i = 0; i <= 2; i++) {
            const y = 0.5 + i * (h - 1) / 2
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
        }
        if (!points || !points.length) return
        const end = points[points.length - 1].t
        const scale = stacked ? 100 : Math.max(1, ...points.map(p => Math.max(p.a, p.b)))
        const x = p => Math.max(0, w - (end - p.t) * w / 60)
        const y = v => h - 1 - Math.min(1, v / scale) * (h - 2)
        function plot(value, color, fill) {
            ctx.beginPath()
            ctx.moveTo(x(points[0]), y(value(points[0])))
            for (const p of points) ctx.lineTo(x(p), y(value(p)))
            ctx.lineWidth = 1.6
            ctx.strokeStyle = color
            ctx.stroke()
            if (fill) {
                ctx.lineTo(w, h); ctx.lineTo(x(points[0]), h); ctx.closePath()
                ctx.fillStyle = Qt.alpha(color, 0.36)
                ctx.fill()
            }
        }
        if (stacked) {
            plot(p => p.a + p.b, secondColor, true)
            plot(p => p.a, firstColor, true)
        } else {
            plot(p => p.a, firstColor, false)
            plot(p => p.b, secondColor, false)
        }
    }
}
