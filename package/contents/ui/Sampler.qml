import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root
    objectName: "resource-sampler"
    visible: false

    property bool showCpu: true
    property bool showMemory: true
    property bool showNetwork: true
    property string detailKind: ""

    property var cpu: null
    property var memory: null
    property var network: null
    property var cpuHistory: []
    property var netHistory: []
    property var details: null
    property var previous: null
    property var recent: []
    property string recentIface: ""
    readonly property string flags: (showCpu ? "c" : "") + (showMemory ? "m" : "") + (showNetwork ? "n" : "")
    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("../scripts/metrics.py").toString().replace(/^file:\/\//, ""))
    readonly property string prefix: "python3 -IS '" + scriptPath.replace(/'/g, "'\\''") + "' "
    readonly property string summaryCommand: flags.length ? prefix + "overview " + flags : ""
    readonly property string detailCommand: ["cpu","memory","network"].includes(detailKind) ? prefix + "details " + detailKind : ""

    function appendPoint(history, time, a, b) {
        return history.filter(p => time - p.t < 60).concat([{ t: time, a: a, b: b }])
    }
    function deltaRate(a, b, elapsed) {
        return a == null || b == null || b < a || elapsed <= 0 ? null : (b - a) / elapsed
    }
    function sample(raw) {
        const elapsed = previous ? raw.time - previous.time : 0
        const previousValid = elapsed > 0 && elapsed <= 5
        if (!previousValid) { cpuHistory = []; netHistory = [] }
        if (raw.cpu && showCpu) {
            const c = raw.cpu
            const old = previousValid ? previous.cpu : null
            const total = old ? c.total - old.total : 0
            const ok = total > 0 && c.user >= old.user && c.system >= old.system
            const user = ok ? 100 * (c.user - old.user) / total : null
            const system = ok ? 100 * (c.system - old.system) / total : null
            cpu = Object.assign({}, c, { userPct: user, systemPct: system, pct: ok ? Math.min(100, user + system) : null })
            if (ok) cpuHistory = appendPoint(cpuHistory, raw.time, user, system)
        } else { cpu = null; cpuHistory = [] }
        if (raw.memory && showMemory) {
            const m = raw.memory
            const old = previousValid ? previous.memory : null
            memory = Object.assign({}, m, { pct: 100 * m.used / m.total,
                inRate: old ? deltaRate(old.pageIn, m.pageIn, elapsed) : null,
                outRate: old ? deltaRate(old.pageOut, m.pageOut, elapsed) : null })
        } else { memory = null }
        if (raw.network && showNetwork) {
            const n = raw.network
            const old = previousValid ? previous.network : null
            const ok = n.iface !== "" && old && n.iface === old.iface
            const rx = ok ? deltaRate(old.rx, n.rx, elapsed) : null
            const tx = ok ? deltaRate(old.tx, n.tx, elapsed) : null
            network = Object.assign({}, n, { rxRate: rx, txRate: tx })
            if (rx !== null && tx !== null) netHistory = appendPoint(netHistory, raw.time, rx, tx)
            else netHistory = []
        } else { network = null; netHistory = [] }
        previous = raw
    }

    function networkDetail(data) {
        if (data.status !== "ok") return data
        const now = Date.now()
        const current = data.rows
        // Retain recently seen names as idle rows, without carrying over old rates.
        const seen = recentIface === data.iface ? recent.filter(r => now - r.seen < 30000) : []
        const lookup = new Map(current.map(r => [r.name, r]))
        const order = [...new Set(current.filter(r => r.rx + r.tx > 0).map(r => r.name)
            .concat(seen.map(r => r.name), current.map(r => r.name)))]
        recent = order.slice(0, 5).map(name => ({name: name, seen: lookup.has(name) ? now : seen.find(r => r.name === name).seen}))
        recentIface = data.iface
        return Object.assign({}, data, { rows: recent.map(r => lookup.get(r.name) || {name: r.name, rx: 0, tx: 0}) })
    }

    onFlagsChanged: {
        if (!showCpu) { cpu = null; cpuHistory = [] }
        if (!showMemory) memory = null
        if (!showNetwork) { network = null; netHistory = []; recent = [] }
        if (!flags) previous = null
    }
    onDetailKindChanged: details = null

    Plasma5Support.DataSource {
        engine: "executable"
        interval: 1000
        connectedSources: root.summaryCommand ? [root.summaryCommand] : []
        onNewData: (source, data) => {
            if (source !== root.summaryCommand || !data["stdout"]) return
            try { root.sample(JSON.parse(data["stdout"])) }
            catch (e) { console.warn("Resource Bar sample:", String(e)) }
        }
    }
    Plasma5Support.DataSource {
        engine: "executable"
        interval: 2200
        connectedSources: root.detailCommand ? [root.detailCommand] : []
        onNewData: (source, data) => {
            if (source !== root.detailCommand || !data["stdout"]) return
            try {
                const value = JSON.parse(data["stdout"])
                root.details = root.detailKind === "network" ? root.networkDetail(value) : value
            } catch (e) { console.warn("Resource Bar detail:", String(e)) }
        }
    }
}
