import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / "package/contents/scripts/metrics.py"
spec = importlib.util.spec_from_file_location("metrics", source)
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)


class SamplingTest(unittest.TestCase):
    def test_default_route_metric_ipv6_and_offline(self):
        v4 = "header\nwlan0 00000000 0 0003 0 0 600 00000000\nenp3s0 00000000 0 0003 0 0 100 00000000"
        v6 = "0" * 32 + " 00 " + "0" * 32 + " 00 fe8001 00000064 0 0 00000003 wlp0"
        def tables(ipv4, ipv6):
            return patch.object(metrics, "optional", side_effect=lambda path: ipv6 if path.endswith("ipv6_route") else ipv4)
        with tables(v4, v6):
            self.assertEqual(metrics.default_interface(), "enp3s0")
        with tables("header", v6):
            self.assertEqual(metrics.default_interface(), "wlp0")
        with tables("header", ""):
            self.assertEqual(metrics.network_sample(), {"iface": "", "rx": 0, "tx": 0})

    def test_tcp_reconciliation_excludes_new_or_reused_sockets(self):
        first = {("abc", "1"): ("browser", 10, 20), ("def", "2"): ("other", 200, 100)}
        last = {("abc", "1"): ("browser", 30, 90), ("def", "2"): ("other", 1, 2),
                ("ghi", "2"): ("new socket", 1000, 2000)}
        rows, other = metrics.traffic_rows(first, last, 50, 60, 2)
        self.assertEqual(rows[0], {"name": "browser", "rx": 10, "tx": 30})
        self.assertEqual(other, {"rx": 15, "tx": 0})
        self.assertNotIn("new socket", [r["name"] for r in rows])

    def test_disabled_overview_skips_sources(self):
        with patch.object(metrics, "network_sample", side_effect=AssertionError), patch.object(metrics, "cpu_sample", side_effect=AssertionError):
            data = metrics.overview("m")
        self.assertEqual(set(data), {"time", "memory"})
        m = data["memory"]
        self.assertEqual(sum(m[k] for k in ("apps", "kernel", "free", "cache")), m["total"])
        self.assertEqual(m["total"] - m["available"], m["used"])


if __name__ == "__main__":
    unittest.main()
