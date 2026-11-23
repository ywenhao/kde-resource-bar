# 资源监视条 · Resource Bar

一个 KDE Plasma 6 面板控件，包含 CPU、内存和网络吞吐。将鼠标移到其中一项，随即显示该项的详情；移出控件时关闭。右键控件，打开配置，在「显示项目」中逐项切换。三项默认开启，全部关闭后点击小图标可以重新配置。

| 指标 | 悬停内容 |
| --- | --- |
| CPU | 用户态与系统态最近 60 秒曲线、逻辑处理器数、CPU 温度、平均负载、运行时间和进程排行 |
| 内存 | 内存构成、可用容量、PSI 压力、交换空间与换页速率、进程内存排行 |
| 网络 | 默认接口、上传和下载速率及曲线、TCP 进程排行与其他流量 |

## 安装

[下载资源监视条安装包](https://github.com/ywenhao/kde-resource-bar/releases/latest/download/resource-bar.plasmoid)

在安装包所在目录运行以下命令，再右键 KDE 面板进入编辑模式，通过「添加部件」搜索「资源监视条」或「Resource Bar」。

```sh
kpackagetool6 -t Plasma/Applet -i ./resource-bar.plasmoid
```

更新已经安装的版本时使用 `-u`。依赖为 Plasma 6、KDE Plasma5Support、Python 3，以及随 Fedora 的 iproute 包提供的 `ip` 和 `ss`。

## 采样口径

- 启用的指标每秒读取一次本机 Linux 计数器。进程详情仅在对应面板显示期间采样，每约两秒刷新。不会安装后台服务。
- CPU 总百分比以全机为 100%，进程排行以单个逻辑处理器为 100%。内存使用量为总量减去可用量，排行按同名进程合计 RSS，共享页可能重复计入。PSI 显示最近 10 秒至少有一个任务等待内存的时间占比。
- 网络使用最低跃点数的 IPv4 默认路由，缺少时使用 IPv6。界面显示所选接口名，可能是 VPN 隧道。切换接口时重新建立速率基线。进程速率根据该接口本地地址上可见的 TCP 套接字估算；UDP、短连接、不可见进程及排行之外的流量计入「其他流量」。网卡和 TCP 采样窗口略有差异，按方向以接口总量为上限。
- 控件仅访问本机数据。未检测到默认路由或 CPU 温度传感器时显示相应空状态。

## 开发

`package/` 是完整的 Plasma Applet 包目录。修改后可在项目根目录重新打包。

```sh
(cd package && zip -q -r -FS ../resource-bar.plasmoid metadata.json contents)
python3 -B -m unittest discover -s tests -p test_metrics.py
/usr/bin/python3 -B tests/test_panel.py
```

界面测试需要 PySide6，使用 Qt 的离屏平台模拟鼠标移动。交互设计参考 [CPU Usage](https://github.com/egoist/omarchy-cpu-usage)、[Memory Usage](https://github.com/egoist/omarchy-memory-usage) 和 [Network Throughput](https://github.com/egoist/omarchy-network-throughput)。
