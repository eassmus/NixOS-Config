import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

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
  property string time

  Process {
    id: dateGet
    command: ["date", "+%I:%M %p | %A | %m-%d-%Y"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.time = this.text.trim() }
  }

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

  // ---------- CPU usage ----------
  property string cpu_usage: "--"
  Process {
    id: cpuProc
    command: ["bash", "/home/pulsar/.config/waybar/scripts/cpu_usage.sh"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.cpu_usage = this.text.trim() }
  }

  // ---------- GPU usage ----------
  property string gpu_usage: "󰢮 ---"
  Process {
    id: gpuProc
    command: ["bash", "/home/pulsar/.config/waybar/scripts/get_gpu_busy.sh"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.gpu_usage = this.text.trim() }
  }

  // ---------- Temperature ----------
  property string temp: "--"
  Process {
    id: tempProc
    command: ["bash", "-c",
      "for h in /sys/class/hwmon/hwmon*; do " +
      "[ \"$(cat \"$h/name\" 2>/dev/null)\" = k10temp ] && { " +
      "awk '{printf \"%d\", $1/1000}' \"$h/temp1_input\" 2>/dev/null; break; }; done"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.temp = this.text.trim() }
  }

  // ---------- Fan / Power profile ----------
  property string fan_mode: ""
  Process {
    id: fanProc
    command: ["bash", "-c", "asusctl profile --profile-get | tail -n 3 | head -n 1 | cut -c 19-19 | /home/pulsar/.config/waybar/scripts/fan-speed.sh"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.fan_mode = this.text.trim() }
  }

  // ---------- VPN ----------
  property string vpn_up: ""
  Process {
    id: vpnProc
    command: ["bash", "/home/pulsar/.config/waybar/scripts/vpn_up.sh"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.vpn_up = this.text.trim() }
  }

  // ---------- Network ----------
  // status: "wifi" | "ethernet" | "disconnected"
  property string net_status: "disconnected"
  property string net_up: "   0b/s"
  property string net_down: "   0b/s"
  property real net_up_bps: 0
  property real net_down_bps: 0

  property real _netLastTx: -1
  property real _netLastRx: -1
  property real _netLastT: 0

  Process {
    id: netProc
    command: ["bash", "-c",
      "if nmcli -t -f DEVICE,TYPE,STATE device | grep -q ':ethernet:connected'; then " +
      "  IF=$(nmcli -t -f DEVICE,TYPE,STATE device | grep ':ethernet:connected' | head -n1 | cut -d: -f1); " +
      "  echo \"ethernet $IF\";" +
      "elif nmcli -t -f DEVICE,TYPE,STATE device | grep -q ':wifi:connected'; then " +
      "  IF=$(nmcli -t -f DEVICE,TYPE,STATE device | grep ':wifi:connected' | head -n1 | cut -d: -f1); " +
      "  echo \"wifi $IF\";" +
      "else echo disconnected; fi"
    ]
    running: true
    stdout: StdioCollector { onStreamFinished: {
      let line = this.text.trim();
      let parts = line.split(" ");
      if (parts[0] === "ethernet") {
        root.net_status = "ethernet";
        root._readBandwidth(parts[1]);
      } else if (parts[0] === "wifi") {
        root.net_status = "wifi";
        root._readBandwidth(parts[1]);
      } else {
        root.net_status = "disconnected";
        root.net_up = "   0b/s";
        root.net_down = "   0b/s";
        root.net_up_bps = 0;
        root.net_down_bps = 0;
      }
    } }
  }

  Process {
    id: bwProc
    property string iface: ""
    command: ["bash", "-c", iface
      ? ("cat /sys/class/net/" + iface + "/statistics/tx_bytes /sys/class/net/" + iface + "/statistics/rx_bytes 2>/dev/null")
      : "echo"]
    stdout: StdioCollector { onStreamFinished: {
      let lines = this.text.trim().split("\n");
      if (lines.length < 2) return;
      let tx = parseFloat(lines[0]);
      let rx = parseFloat(lines[1]);
      let now = Date.now();
      if (root._netLastTx > 0 && root._netLastT > 0) {
        let dt = (now - root._netLastT) / 1000.0;
        if (dt > 0) {
          let upBps  = Math.max(0, (tx - root._netLastTx) * 8 / dt);
          let downBps = Math.max(0, (rx - root._netLastRx) * 8 / dt);
          root.net_up_bps   = upBps;
          root.net_down_bps = downBps;
          root.net_up   = root._fmtBits(upBps);
          root.net_down = root._fmtBits(downBps);
        }
      }
      root._netLastTx = tx;
      root._netLastRx = rx;
      root._netLastT = now;
    } }
  }

  function _readBandwidth(iface) {
    // counters are per-interface, so a wifi→ethernet switch would otherwise
    // diff two unrelated byte counts and show one bogus multi-Gb/s spike
    if (iface !== bwProc.iface) { root._netLastTx = -1; root._netLastT = 0; }
    bwProc.iface = iface;
    bwProc.running = true;
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
    onTriggered: {
      dateGet.running = true
      cpuProc.running = true
      gpuProc.running = true
      tempProc.running = true
      fanProc.running = true
      vpnProc.running = true
      netProc.running = true
    }
  }
}
