"""Read local Linux counters for the Plasma applet. No state files or daemon."""
import json
import os
import sys
import time

PROC = "/proc"
PAGE = os.sysconf("SC_PAGE_SIZE")
TICKS = os.sysconf("SC_CLK_TCK")
WINDOW = 0.6
LIMIT = 5


def read(path):
    with open(path, encoding="utf-8", errors="replace") as stream:
        return stream.read()


def optional(path):
    try:
        return read(path)
    except OSError:
        return ""


def cpu_sample():
    with open(f"{PROC}/stat", encoding="ascii") as stream:
        values = list(map(int, stream.readline().split()[1:9]))
    return {"user": sum(values[:2]), "system": values[2] + sum(values[5:8]),
            "total": sum(values), "cores": os.cpu_count(), "load": os.getloadavg(),
            "uptime": float(read(f"{PROC}/uptime").split()[0])}


def memory_sample():
    info = {line.split(":")[0]: int(line.split()[1]) * 1024
            for line in read(f"{PROC}/meminfo").splitlines() if line.endswith(" kB")}
    total = info["MemTotal"]
    free = min(total, info["MemFree"])
    apps = min(total - free, info["AnonPages"] + info["Shmem"])
    cache = min(total - free - apps, max(0, info["Cached"] + info.get("SReclaimable", 0) - info["Shmem"]))
    pressure = None
    for line in optional(f"{PROC}/pressure/memory").splitlines():
        if line.startswith("some "):
            pressure = float(dict(field.split("=") for field in line.split()[1:])["avg10"])
    paging = {key: int(value) * PAGE for key, value in
              (line.split() for line in optional(f"{PROC}/vmstat").splitlines() if line.startswith(("pswpin ", "pswpout ")))}
    return {"total": total, "used": total - info["MemAvailable"], "available": info["MemAvailable"],
            "apps": apps, "cache": cache, "kernel": total - free - apps - cache, "free": free,
            "swap": info["SwapTotal"] - info["SwapFree"], "swapTotal": info["SwapTotal"],
            "pressure": pressure, "pageIn": paging.get("pswpin"), "pageOut": paging.get("pswpout")}


def default_interface():
    routes = []
    for line in optional(f"{PROC}/net/route").splitlines()[1:]:
        f = line.split()
        if len(f) >= 8 and f[1] == f[7] == "00000000" and f[0] != "lo":
            flags = int(f[3], 16)
            if flags & 1 and not flags & 0x200:
                routes.append((int(f[6]), f[0]))
    if not routes:
        for line in optional(f"{PROC}/net/ipv6_route").splitlines():
            f = line.split()
            if len(f) == 10 and f[0] == "0" * 32 and f[1] == "00" and f[-1] != "lo":
                flags = int(f[8], 16)
                if flags & 1 and not flags & 0x200:
                    routes.append((int(f[5], 16), f[-1]))
    return min(routes)[1] if routes else ""


def network_sample():
    iface = default_interface()
    for line in optional(f"{PROC}/net/dev").splitlines()[2:]:
        name, data = line.rsplit(":", 1)
        if name.strip() == iface:
            fields = data.split()
            return {"iface": iface, "rx": int(fields[0]), "tx": int(fields[8])}
    return {"iface": "", "rx": 0, "tx": 0}


def processes():
    sample = {}
    me = os.getpid()
    for pid in os.listdir(PROC):
        if not pid.isdigit() or int(pid) == me:
            continue
        try:
            stat = read(f"{PROC}/{pid}/stat")
            before, tail = stat.rsplit(") ", 1)
            name = before.partition("(")[2]
            fields = tail.split()
            sample[(pid, fields[19])] = (name, int(fields[11]) + int(fields[12]), max(0, int(fields[21])) * PAGE)
        except (OSError, IndexError, ValueError):
            continue  # A process may exit during the scan.
    return sample


def temperature():
    from glob import glob
    for folder in sorted(glob("/sys/class/hwmon/hwmon*")):
        if optional(f"{folder}/name").strip() not in {"coretemp", "k10temp", "zenpower", "cpu_thermal"}:
            continue
        inputs = sorted(glob(f"{folder}/temp*_input"))
        inputs.sort(key=lambda p: not optional(p.replace("_input", "_label")).startswith(("Package", "Tctl", "Tdie")))
        for path in inputs:
            try:
                return int(read(path)) / 1000
            except (OSError, ValueError):
                continue
    return None


def top_processes(mode):
    from collections import defaultdict
    groups = defaultdict(float)
    if mode == "cpu":
        first = processes()
        start = time.monotonic()
        time.sleep(WINDOW)
        second = processes()
        scale = 100 / (TICKS * (time.monotonic() - start))
        for identity, (name, ticks, _) in second.items():
            if identity in first:
                groups[name] += max(0, ticks - first[identity][1]) * scale
    else:
        for name, _, rss in processes().values():
            groups[name] += rss
    ranked = sorted(groups.items(), key=lambda item: (-item[1], item[0]))
    return [{"name": name, "value": value} for name, value in ranked[:LIMIT] if value > 0]


def local_addresses(iface):
    import ipaddress
    import subprocess
    raw = subprocess.check_output(["ip", "-j", "address", "show", "dev", iface], timeout=2)
    return {ipaddress.ip_address(a["local"]) for dev in json.loads(raw)
            for a in dev.get("addr_info", []) if a.get("family") in ("inet", "inet6")}


def socket_sample(addresses):
    import ipaddress
    import re
    import subprocess
    env = dict(os.environ, LC_ALL="C")
    text = subprocess.check_output(["ss", "-HOnteip"], env=env, text=True, errors="replace", timeout=2)
    sockets = {}
    for line in text.splitlines():
        fields = line.split(None, 5)
        if len(fields) < 6 or fields[0] != "ESTAB":
            continue
        details = fields[5]
        owner = re.search(r'users:\(\("([^"]+)",pid=(\d+)', details)
        cookie = re.search(r'\bsk:([0-9a-fA-F]+)\b', details)
        if not owner or not cookie:
            continue
        try:
            local = ipaddress.ip_address(fields[3].rsplit(":", 1)[0].strip("[]").split("%")[0])
        except ValueError:
            continue
        local = getattr(local, "ipv4_mapped", None) or local
        if local not in addresses:
            continue
        counters = dict(re.findall(r'\b(bytes_received|bytes_sent):(\d+)', details))
        sockets[(cookie[1], owner[2])] = (owner[1], int(counters.get("bytes_received", 0)), int(counters.get("bytes_sent", 0)))
    return sockets


def traffic_rows(first, last, rx, tx, seconds):
    """Reconcile matched TCP deltas with one interface, including the undisplayed traffic."""
    from collections import defaultdict
    apps = defaultdict(lambda: [0, 0])
    for key, (name, received, sent) in last.items():
        old = first.get(key)
        if old:
            apps[name][0] += max(0, received - old[1])
            apps[name][1] += max(0, sent - old[2])
    # Short sampling skew or offloading can put TCP counters ahead of the device.
    scales = [min(1, total / max(1, sum(v[i] for v in apps.values()))) for i, total in enumerate((rx, tx))]
    rows = [{"name": name, "rx": v[0] * scales[0] / seconds, "tx": v[1] * scales[1] / seconds} for name, v in apps.items()]
    rows.sort(key=lambda r: (-(r["rx"] + r["tx"]), r["name"]))
    rows = rows[:LIMIT]
    other = {"rx": max(0, rx / seconds - sum(r["rx"] for r in rows)),
             "tx": max(0, tx / seconds - sum(r["tx"] for r in rows))}
    return rows, other


def network_details():
    import subprocess
    iface = default_interface()
    if not iface:
        return {"iface": "", "status": "offline"}
    try:
        ips = local_addresses(iface)
        first = socket_sample(ips)
        start = network_sample()
        stamp = time.monotonic()
        time.sleep(WINDOW)
        last = socket_sample(ips)
        end = network_sample()
        elapsed = time.monotonic() - stamp
    except (OSError, ValueError, subprocess.SubprocessError):
        return {"iface": iface, "status": "unavailable"}
    if start["iface"] != iface or end["iface"] != iface or end["rx"] < start["rx"] or end["tx"] < start["tx"]:
        return {"iface": end["iface"], "status": "changing"}
    rows, other = traffic_rows(first, last, end["rx"] - start["rx"], end["tx"] - start["tx"], elapsed)
    return {"iface": iface, "status": "ok", "rows": rows, "other": other}


def overview(flags):
    out = {"time": time.clock_gettime(time.CLOCK_BOOTTIME)}
    for flag, key, sample in (("c", "cpu", cpu_sample), ("m", "memory", memory_sample), ("n", "network", network_sample)):
        if flag in flags:
            try:
                out[key] = sample()
            except (OSError, ValueError, KeyError, IndexError):
                out[key] = None
    return out


def main():
    mode, arg = sys.argv[1:]
    if mode == "overview":
        result = overview(arg)
    elif mode == "details" and arg == "cpu":
        result = {"rows": top_processes("cpu"), "temperature": temperature()}
    elif mode == "details" and arg == "memory":
        result = {"rows": top_processes("memory")}
    elif mode == "details" and arg == "network":
        result = network_details()
    else:
        raise SystemExit("Usage: metrics.py overview cmn | details cpu|memory|network")
    print(json.dumps(result, separators=(",", ":"), allow_nan=False))


if __name__ == "__main__":
    main()
