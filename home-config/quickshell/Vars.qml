import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

// Most values here come from files read in-process (FileView) or from
// Quickshell's event-driven services; only the GPU and fan-profile checks
// still spawn a process, and on slower timers.
Scope {
  id: root

  // ---------- Palette ----------
  readonly property color mainColor: "#82aee8"
  readonly property color pinkColor: "#e9a6fd"
  readonly property color greenColor: "#a6e3a1"
  readonly property color warningColor: "#f3a611"
  readonly property color redColor: "#f34646"
  readonly property color bgColor: "#161616"

  // ---------- Time ----------
  SystemClock { id: clock; precision: SystemClock.Minutes }
  readonly property string time: Qt.formatDateTime(clock.date, "hh:mm AP | dddd | MM-dd-yyyy")

  // ---------- Battery (UPower) ----------
  readonly property int bat_percent: Math.round(UPower.displayDevice.percentage * 100)
  readonly property string bat_state: {
    switch (UPower.displayDevice.state) {
      case UPowerDeviceState.Charging:         return "Charging"
      case UPowerDeviceState.Discharging:      return "Discharging"
      case UPowerDeviceState.FullyCharged:     return "Full"
      case UPowerDeviceState.Empty:            return "Empty"
      case UPowerDeviceState.PendingCharge:    return "PendingCharge"
      case UPowerDeviceState.PendingDischarge: return "PendingDischarge"
      default:                                 return "Unknown"
    }
  }
  readonly property bool bat_onac: !UPower.onBattery
  readonly property string bat_time: {
    let rawSeconds = UPower.onBattery
        ? UPower.displayDevice.timeToEmpty
        : UPower.displayDevice.timeToFull;
    if (rawSeconds <= 0) return "--:--";
    let hours = Math.floor(rawSeconds / 3600);
    let minutes = Math.floor((rawSeconds % 3600) / 60);
    let paddedMinutes = minutes < 10 ? "0" + minutes : minutes;
    return hours + ":" + paddedMinutes;
  }

  // ---------- CPU usage (/proc/stat deltas, "idle" = idle + iowait) ----------
  // overall for the bar pill, plus per-core load and a minute of per-core
  // history for the CPU popup's graphs
  property string cpu_usage: "--"
  property int cpu_total: 0
  property var cpu_cores: []       // load % per core, cpu0..cpuN
  property var cpu_core_hist: []   // per core, last cpuHistLen samples
  readonly property int cpuHistLen: 60   // 1s samples → last minute
  property var _cpuLast: ({})
  FileView { id: procStat; path: "/proc/stat"; blockLoading: true }
  function _sampleCpu() {
    procStat.reload()
    let lines = procStat.text().split("\n")
    let first = !_cpuLast.cpu
    let next = {}, utils = []
    // the aggregate "cpu" line comes first, then cpu0..cpuN
    for (let i = 0; i < lines.length && lines[i].startsWith("cpu"); i++) {
      let p = lines[i].trim().split(/\s+/)
      let f = p.slice(1, 8).map(Number)
      let cur = { idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) }
      let prev = _cpuLast[p[0]]
      next[p[0]] = cur
      utils.push(!first && prev && cur.total > prev.total
        ? Math.max(0, Math.round(100 * (1 - (cur.idle - prev.idle) / (cur.total - prev.total))))
        : 0)
    }
    _cpuLast = next
    cpu_cores = utils.slice(1)
    if (first) return
    cpu_total = utils[0]
    cpu_usage = String(utils[0]).padStart(2, " ")
    cpu_core_hist = cpu_cores.map((u, i) => (cpu_core_hist[i] || []).concat([u]).slice(-cpuHistLen))
  }

  // ---------- GPU usage ----------
  // get_gpu_busy.sh gates nvidia-smi on the dGPU's runtime-PM state so the
  // card can stay suspended; polled slower since it's the costliest check
  property string gpu_usage: "󰢮 ---"
  Process {
    id: gpuProc
    command: ["bash", "/home/pulsar/.config/waybar/scripts/get_gpu_busy.sh"]
    running: true
    stdout: StdioCollector { onStreamFinished: {
      let l = this.text.trim().split("\n")
      root.gpu_usage = l[0]
      // keeps the last reading between queries so the thermal graph fills in the
      // background without extra nvidia-smi calls
      if (l[1] === "off") root.gpu_temp = NaN
      else if (l[1]) root.gpu_temp = parseFloat(l[1])
    } }
  }
  property real gpu_temp: NaN
  Timer { interval: 2000; running: true; repeat: true; onTriggered: { gpuProc.running = true; gpuControlFile.reload() } }

  // pin the dGPU awake (DP-1 monitor hotplug, CUDA) or let it runtime-suspend;
  // power/control is group-writable via a udev rule in modules/nvidia.nix
  property bool gpu_pinned: false
  FileView {
    id: gpuControlFile
    path: "/sys/bus/pci/devices/0000:01:00.0/power/control"
    blockLoading: true
    onLoaded: root.gpu_pinned = text().trim() === "on"
  }
  Process {
    id: gpuToggleProc
    command: ["bash", "-c", "f=/sys/bus/pci/devices/0000:01:00.0/power/control; if [ \"$(<$f)\" = on ]; then echo auto; else echo on; fi > $f"]
    onExited: { gpuProc.running = true; gpuControlFile.reload() }
  }
  function toggleGpu() { gpuToggleProc.running = true }

  // ---------- Fan / Power profile ----------
  // changes on click (refreshFan) or via Fn+F5, hence the slow poll
  property string fan_mode: ""
  readonly property var _fanIcons: ({ "Quiet": "󰾆", "Balanced": "󰾅", "Performance": "󰓅" })
  Process {
    id: fanProc
    command: ["bash", "-c", "asusctl profile get 2>/dev/null | grep -oP 'Active profile:?\\s*(is\\s+)?\\K\\w+'"]
    running: true
    stdout: StdioCollector { onStreamFinished: {
      let p = this.text.trim()
      root.fan_mode = root._fanIcons[p] || p
    } }
  }
  function refreshFan() { fanProc.running = true }
  Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refreshFan() }

  // ---------- VPN ----------
  // openconnect brings up tun0; its presence is the signal
  property string vpn_up: ""
  FileView {
    id: tunFile
    path: "/sys/class/net/tun0/operstate"
    blockLoading: true
    printErrors: false
    onLoaded: root.vpn_up = ""
    onLoadFailed: root.vpn_up = ""
  }
  Timer { interval: 2000; running: true; repeat: true; onTriggered: tunFile.reload() }

  // ---------- Network ----------
  readonly property var _netDevs: Networking.devices ? Networking.devices.values : []
  // connected device, ethernet preferred over wifi
  readonly property var _netDev: {
    let wifi = null
    for (let i = 0; i < _netDevs.length; i++) {
      let d = _netDevs[i]
      if (!d.connected) continue
      if (d.type === DeviceType.Wired) return d
      if (d.type === DeviceType.Wifi && !wifi) wifi = d
    }
    return wifi
  }
  // status: "wifi" | "ethernet" | "disconnected"
  readonly property string net_status: !_netDev ? "disconnected"
    : _netDev.type === DeviceType.Wired ? "ethernet" : "wifi"
  readonly property string netIface: _netDev ? _netDev.name : ""

  property real net_up_bps: 0
  property real net_down_bps: 0
  readonly property string net_up: _fmtBits(net_up_bps)
  readonly property string net_down: _fmtBits(net_down_bps)

  property real _netLastTx: 0
  property real _netLastRx: 0
  property real _netLastT: 0
  // counters are per-interface, so a wifi→ethernet switch would otherwise
  // diff two unrelated byte counts and show one bogus multi-Gb/s spike
  onNetIfaceChanged: _netLastT = 0

  FileView { id: txFile; path: root.netIface ? "/sys/class/net/" + root.netIface + "/statistics/tx_bytes" : ""; blockLoading: true }
  FileView { id: rxFile; path: root.netIface ? "/sys/class/net/" + root.netIface + "/statistics/rx_bytes" : ""; blockLoading: true }

  function _sampleNet() {
    if (!netIface) { net_up_bps = 0; net_down_bps = 0; return }
    txFile.reload()
    rxFile.reload()
    let tx = parseFloat(txFile.text())
    let rx = parseFloat(rxFile.text())
    if (isNaN(tx) || isNaN(rx)) return
    let now = Date.now()
    if (_netLastT > 0 && now > _netLastT) {
      let dt = (now - _netLastT) / 1000
      net_up_bps = Math.max(0, (tx - _netLastTx) * 8 / dt)
      net_down_bps = Math.max(0, (rx - _netLastRx) * 8 / dt)
    }
    _netLastTx = tx
    _netLastRx = rx
    _netLastT = now
  }

  function _fmtBits(b) {
    // Match waybar's bandwidthUpBits/bandwidthDownBits formatting:
    // units {b, kb, Mb, Gb}, decimal scaling, right-aligned to width 5.
    let units = ["b/s", "kb/s", "Mb/s", "Gb/s"]
    let i = 0
    while (b >= 1000 && i < units.length - 1) { b /= 1000; i++ }
    let s
    if (i === 0)        s = Math.round(b) + units[i]
    else if (b < 10)    s = b.toFixed(1)  + units[i]
    else                s = Math.round(b) + units[i]
    while (s.length < 7) s = " " + s
    return s
  }

  // ---------- Audio (native Pipewire bindings) ----------
  // PwObjectTracker is what makes the default sink/source actually push
  // property updates into QML — without it the bindings stay stale.
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: [root.sink, root.source] }

  readonly property string vol:
    (sink && sink.ready) ? Math.round(sink.audio.volume * 100).toString() : "--"
  readonly property bool vol_muted: !!(sink && sink.ready && sink.audio.muted)
  readonly property string mic:
    (source && source.ready) ? Math.round(source.audio.volume * 100).toString() : "--"
  readonly property bool mic_muted: !!(source && source.ready && source.audio.muted)

  // ---------- Tick ----------
  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { root._sampleCpu(); root._sampleNet() }
  }
}
