import QtQuick
import QtQuick.Controls as QQC
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_showCpu: cpu.checked
    property alias cfg_showMemory: memory.checked
    property alias cfg_showNetwork: network.checked

    Kirigami.FormLayout {
        QQC.Switch {
            id: cpu
            Kirigami.FormData.label: "任务栏指标："
            text: "CPU"
        }
        QQC.Switch { id: memory; text: "内存" }
        QQC.Switch { id: network; text: "网络" }
    }
}
