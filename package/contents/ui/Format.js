.pragma library

function percent(value, digits) {
    return value === null || value === undefined || !isFinite(value) ? "—" : value.toFixed(digits || 0) + "%"
}

function size(value, places) {
    if (value === null || value === undefined || !isFinite(value)) return "—"
    const units = ["B", "KiB", "MiB", "GiB", "TiB"]
    let i = 0
    while (value >= 1024 && i < units.length - 1) { value /= 1024; ++i }
    const decimals = i === 0 ? 0 : (places === undefined ? (value < 10 ? 1 : 0) : places)
    return value.toFixed(decimals) + " " + units[i]
}

function rate(value) {
    return value === null || value === undefined ? "—" : size(value) + "/s"
}

function networkRate(value) {
    if (value === null || value === undefined || !isFinite(value)) return "—"
    if (value < 1000) return value.toFixed(0) + " B/s"
    const useMegabytes = value >= 1000000
    const scaled = value / (useMegabytes ? 1000000 : 1000)
    return scaled.toFixed(scaled < 10 ? 1 : 0) + (useMegabytes ? " MB/s" : " KB/s")
}

function uptime(seconds) {
    if (seconds === undefined) return "—"
    const days = Math.floor(seconds / 86400)
    const hours = Math.floor(seconds / 3600) % 24
    const minutes = Math.floor(seconds / 60) % 60
    return (days > 0 ? days + " 天 " : "") + hours + " 小时 " + minutes + " 分"
}
