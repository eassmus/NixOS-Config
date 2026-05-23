import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Singleton {
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
    if (rawSeconds <= 0) {
      return !UPower.onBattery ? "--:--" : "--:--";
    }
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
    command: ["bash", "-c", "head -c 2 /sys/class/thermal/thermal_zone0/temp"]
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

  // ---------- Workspace ----------
  property string workspace: "1"
  Process {
    id: wsProc
    command: ["bash", "-c", "hyprctl activeworkspace -j | grep '^    \"name\": \"' | cut -c14"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.workspace = this.text.trim() }
  }

  // ---------- Network ----------
  // status: "wifi" | "ethernet" | "disconnected"
  property string net_status: "disconnected"
  property string net_up: "   0b/s"
  property string net_down: "   0b/s"
  property string net_essid: ""
  property string net_signal: ""

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
      "  SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2);" +
      "  SIG=$(nmcli -t -f active,signal dev wifi | grep '^yes' | cut -d: -f2);" +
      "  echo \"wifi $IF $SIG $SSID\";" +
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
        root.net_signal = parts[2] || "";
        root.net_essid = parts.slice(3).join(" ");
        root._readBandwidth(parts[1]);
      } else {
        root.net_status = "disconnected";
        root.net_up = "   0b/s";
        root.net_down = "   0b/s";
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

  // ---------- Audio ----------
  property string vol: "--"
  property bool vol_muted: false
  property string mic: "--"
  property bool mic_muted: false

  Process {
    id: volProc
    command: ["bash", "-c", "pamixer --get-volume; pamixer --get-mute"]
    running: true
    stdout: StdioCollector { onStreamFinished: {
      let lines = this.text.trim().split("\n");
      root.vol = lines[0] || "--";
      root.vol_muted = (lines[1] || "false").trim() === "true";
    } }
  }
  Process {
    id: micProc
    command: ["bash", "-c", "pamixer --default-source --get-volume; pamixer --default-source --get-mute"]
    running: true
    stdout: StdioCollector { onStreamFinished: {
      let lines = this.text.trim().split("\n");
      root.mic = lines[0] || "--";
      root.mic_muted = (lines[1] || "false").trim() === "true";
    } }
  }

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
      wsProc.running = true
      netProc.running = true
      volProc.running = true
      micProc.running = true
    }
  }
}
