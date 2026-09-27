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

  // ---------- CPU usage (/proc/stat delta, "idle" = idle + iowait) ----------
  property string cpu_usage: "--"
  property var _cpuLast: null
  FileView { id: procStat; path: "/proc/stat"; blockLoading: true }
  function _sampleCpu() {
    procStat.reload()
    let f = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1, 8).map(Number)
    let idle = f[3] + f[4]
    let total = f.reduce((a, b) => a + b, 0)
    if (_cpuLast && total > _cpuLast.total) {
      let u = 1 - (idle - _cpuLast.idle) / (total - _cpuLast.total)
      cpu_usage = String(Math.round(100 * u)).padStart(2, " ")
    }
    _cpuLast = { total: total, idle: idle }
  }

  // ---------- GPU usage ----------
  // get_gpu_busy.sh gates nvidia-smi on the dGPU's runtime-PM state so the
  // card can stay suspended; polled slower since it's the costliest check
  property string gpu_usage: "󰢮 ---"
  Process {
    id: gpuProc
    command: ["bash", "/home/pulsar/.config/waybar/scripts/get_gpu_busy.sh"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.gpu_usage = this.text.trim() }
  }
  Timer { interval: 2000; running: true; repeat: true; onTriggered: gpuProc.running = true }

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
