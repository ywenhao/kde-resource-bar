"""Exercise real QML hover windows and every switch combination on an isolated Qt display."""
import itertools
import os
from pathlib import Path
import time

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from PySide6.QtCore import QObject, QPoint, QPointF, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine, QJSValue
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QSignalSpy, QTest
from PySide6.QtWidgets import QApplication

ui = Path(__file__).resolve().parents[1] / "package/contents/ui"
app = QApplication(["resource-bar-test"])
engine = QQmlEngine()
component = QQmlComponent(engine)
component.setData(b'''
import QtQuick
import QtQuick.Window
import "."
Window {
    visible: true; x: 40; y: 600; width: 520; height: 140
    MetricStrip { objectName: "strip"; x: 20; y: 25; width: implicitWidth; height: 34 }
}
''', QUrl.fromLocalFile(str(ui / "PanelTest.qml")))
window = component.create()
assert window is not None, [e.toString() for e in component.errors()]


def wait(predicate, message, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        QTest.qWait(35)
    raise AssertionError(message)


def value(obj, key):
    v = obj.property(key)
    return v.toVariant() if isinstance(v, QJSValue) else v


strip = window.findChild(QObject, "strip")
monitor = strip.findChild(QObject, "resource-sampler")
popup = strip.findChild(QQuickWindow, "resource-hover-window")
assert popup is not None
panel = popup.property("mainItem")
assert isinstance(panel, QQuickItem)
tiles = {k: window.findChild(QQuickItem, "tile-" + k) for k in ("cpu", "memory", "network")}
QTest.mouseMove(window, QPoint(510, 130))
wait(lambda: (value(monitor, "cpu") or {}).get("pct") is not None, "CPU did not receive two live samples")
assert value(monitor, "memory")["total"] > 0
assert "iface" in value(monitor, "network")
for kind, tile in tiles.items():
    point = tile.mapToScene(QPointF(tile.width()/2, tile.height()/2)).toPoint()
    QTest.mouseMove(window, point)
    try:
        wait(lambda: value(strip, "hovered") == kind and popup.isVisible(), "Tooltip did not open: " + kind)
    except AssertionError:
        print("Pointer target", kind, point, "reported", strip.property("hovered"),
              [(k, t.property("pointerInside"), t.property("activeFocus"), t.position(), t.size()) for k,t in tiles.items()],
              [(w.geometry(), w.isVisible()) for w in app.topLevelWindows()])
        raise
    wait(lambda: value(monitor, "details") is not None, "No hover detail: " + kind)
    QTest.qWait(200)
    assert panel.objectName() == "detail-" + kind and panel.window() == popup
    assert panel.width() > 220 and panel.height() > 140, "Invalid tooltip geometry"
    if os.getenv("RESOURCE_BAR_TEST_IMAGES"):
        popup.grabWindow().save(str(Path(os.environ["RESOURCE_BAR_TEST_IMAGES"]) / (kind + ".png")))
    print(kind, "hover OK", round(panel.width()), round(panel.height()), flush=True)
QTest.mouseMove(window, QPoint(510, 130))
wait(lambda: not value(monitor, "detailCommand") and not popup.isVisible(), "Hover panel or its sampling remained active")
configure_requests = QSignalSpy(strip.configureRequested)

for flags in itertools.product((False, True), repeat=3):
    for key, flag in zip(("showCpu", "showMemory", "showNetwork"), flags):
        strip.setProperty(key, flag)
    QTest.qWait(40)
    assert [t.isVisible() for t in tiles.values()] == list(flags)
    assert bool(monitor.property("summaryCommand")) == any(flags)
    placeholder = window.findChild(QQuickItem, "disabled-placeholder")
    assert placeholder.isVisible() == (not any(flags))
    if not any(flags):
        point = placeholder.mapToScene(QPointF(placeholder.width()/2, placeholder.height()/2)).toPoint()
        QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point)
        assert configure_requests.count() == 1
        QTest.mouseMove(window, QPoint(510, 130))
assert value(monitor, "flags") == "cmn"
strip.setProperty("vertical", True)
QTest.qWait(50)
assert tiles["network"].y() > tiles["memory"].y() > tiles["cpu"].y()
config = QQmlComponent(engine, QUrl.fromLocalFile(str(ui / "Config.qml")))
settings = config.create()
assert settings is not None, [e.toString() for e in config.errors()]
for key in ("cfg_showCpu", "cfg_showMemory", "cfg_showNetwork"):
    for flag in (True, False):
        assert settings.setProperty(key, flag)
        assert settings.property(key) == flag
print("8 switch combinations, vertical panel, settings bindings OK", flush=True)
window.close()
