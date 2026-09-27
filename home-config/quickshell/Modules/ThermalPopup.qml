import Quickshell
import Quickshell.Io
import QtQuick

PopupCard {
  id: root

  // key = "<hwmon name>:<label, or tempN when unlabelled>"
  readonly property var tempSensors: [
    { key: "k10temp:Tctl",      name: "CPU" },
    { key: "amdgpu:edge",       name: "iGPU" },
    { key: "nvidia:temp",       name: "dGPU" },
    { key: "nvme:Composite",    name: "SSD" },
    { key: "mt7921_phy0:temp1", name: "WiFi" },
    { key: "acpitz:temp1",      name: "Board" }
  ]
  readonly property var fanSensors: [
    { key: "asus:cpu_fan", name: "CPU fan" },
    { key: "asus:gpu_fan", name: "GPU fan" }
  ]

  property var values: ({})   // key -> °C or RPM
  property var hist: ({})     // key -> last histLen samples
  property bool dgpuAsleep: false
  readonly property int histLen: 30   // × 2s poll = last minute

  // hwmon is cheap file reads, so it polls always and the history is already
  // there on open. nvidia-smi wakes a suspended dGPU, so it's only queried
  // while the popup is open and the card is already awake (same gate as the
  // bar's get_gpu_busy.sh).
  Process {
    id: sensorProc
    command: ["bash", "-c",
      "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); " +
      "for f in $h/temp*_input $h/fan*_input; do [ -e \"$f\" ] || continue; " +
      "b=${f%_input}; l=$(cat ${b}_label 2>/dev/null); echo \"$n:${l:-${b##*/}}|$(cat $f)\"; done; done; " +
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null); echo \"nvidia:status|$s\"; " +
      (root.open ? "[ \"$s\" = active ] && echo \"nvidia:temp|$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)\"" : "true")]
    stdout: StdioCollector { onStreamFinished: root._parse(this.text) }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sensorProc.running = true }

  function _parse(text) {
    let vals = {}
    let lines = text.trim().split("\n")
    for (let i = 0; i < lines.length; i++) {
      let [k, raw] = lines[i].split("|")
      if (k === "nvidia:status") { root.dgpuAsleep = raw === "suspended"; continue }
      let v = parseFloat(raw)
      if (isNaN(v)) continue
      // hwmon temps are millidegrees; nvidia-smi and fan RPM are not
      vals[k] = (k.indexOf("fan") >= 0 || k === "nvidia:temp") ? v : v / 1000
    }
    let h = Object.assign({}, root.hist)
    for (let k in vals) h[k] = (h[k] || []).concat([vals[k]]).slice(-root.histLen)
    root.values = vals
    root.hist = h
  }

  function _tempColor(t) {
    if (t >= 85) return redColor
    if (t >= 70) return warningColor
    return pinkColor
  }

  // ---- layout ----
  property int contentWidth: 560
  property int tileGap: 12
  property int tileH: 128
  property int tilePad: 10

  cardWidth: contentWidth + chrome
  cardHeight: content.implicitHeight + chrome

  component SensorTile: Rectangle {
    id: tile
    property string key
    property string name
    property bool isFan: false
    readonly property var v: root.values[key]
    readonly property var pts: root.hist[key] || []
    readonly property color valueColor: v === undefined ? root.dimColor
      : isFan ? (v === 0 ? root.dimColor : root.mainColor)
      : root._tempColor(v)

    width: (content.width - root.tileGap) / 2
    height: root.tileH
    radius: 12
    color: "#1e1e1e"

    Text {
      id: nameTxt
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: root.tilePad
      text: tile.name
      color: root.mainColor
      font.family: root.fontFamily
      font.pixelSize: 22
      font.bold: true
    }

    Text {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: root.tilePad
      text: {
        if (tile.key === "nvidia:temp" && root.dgpuAsleep) return "asleep"
        if (tile.v === undefined) return "--"
        if (tile.isFan) return tile.v === 0 ? "stopped" : tile.v + " RPM"
        return Math.round(tile.v) + " °C"
      }
      color: tile.valueColor
      font.family: root.fontFamily
      font.pixelSize: 22
      font.bold: true
    }

    // last-minute history, scaled to its own recent range
    Canvas {
      id: spark
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: nameTxt.bottom
      anchors.bottom: parent.bottom
      anchors.leftMargin: root.tilePad
      anchors.rightMargin: root.tilePad
      anchors.topMargin: 4
      anchors.bottomMargin: root.tilePad
      onPaint: {
        let ctx = getContext("2d")
        ctx.reset()
        let p = tile.pts
        if (p.length < 2) return
        // snap the range out to gridline multiples so at least two gridlines
        // always show, then pad so they don't sit on the tile edges
        let gStep = tile.isFan ? 1000 : 10
        let lo = Math.floor(Math.min(...p) / gStep) * gStep
        let hi = Math.max(Math.ceil(Math.max(...p) / gStep) * gStep, lo + gStep)
        lo -= gStep * 0.15
        hi += gStep * 0.15
        let step = width / (root.histLen - 1)
        let xs = [], ys = []
        for (let i = 0; i < p.length; i++) {
          xs.push(width - (p.length - 1 - i) * step)
          ys.push(2 + (1 - (p[i] - lo) / (hi - lo)) * (height - 4))
        }

        // gridlines on round values, labelled at the left edge
        ctx.font = "bold 12px \"" + root.fontFamily + "\""
        ctx.textBaseline = "middle"
        ctx.lineWidth = 1
        for (let gv = Math.ceil(lo / gStep) * gStep; gv <= hi; gv += gStep) {
          let gy = Math.round(2 + (1 - (gv - lo) / (hi - lo)) * (height - 4)) + 0.5
          let label = tile.isFan ? (gv / 1000) + "k" : gv + "°"
          let labelW = ctx.measureText(label).width + 6
          ctx.strokeStyle = "rgba(255,255,255,0.08)"
          ctx.beginPath()
          ctx.moveTo(labelW, gy)
          ctx.lineTo(width, gy)
          ctx.stroke()
          ctx.fillStyle = root.dimColor.toString()
          ctx.fillText(label, 0, Math.max(7, Math.min(height - 7, gy)))
        }

        let c = root.pinkColor
        let rgba = a => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"

        ctx.beginPath()
        ctx.moveTo(xs[0], height)
        for (let i = 0; i < xs.length; i++) ctx.lineTo(xs[i], ys[i])
        ctx.lineTo(xs[xs.length - 1], height)
        ctx.closePath()
        let g = ctx.createLinearGradient(0, 0, 0, height)
        g.addColorStop(0, rgba(0.35))
        g.addColorStop(1, rgba(0))
        ctx.fillStyle = g
        ctx.fill()

        ctx.beginPath()
        for (let i = 0; i < xs.length; i++) i === 0 ? ctx.moveTo(xs[i], ys[i]) : ctx.lineTo(xs[i], ys[i])
        ctx.strokeStyle = rgba(1)
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.stroke()
      }
      Connections {
        target: tile
        function onPtsChanged() { spark.requestPaint() }
      }
    }
  }

  Column {
    id: content
    width: root.contentWidth
    spacing: root.tileGap

    Grid {
      columns: 2
      spacing: root.tileGap
      Repeater {
        model: root.tempSensors
        delegate: SensorTile { required property var modelData; key: modelData.key; name: modelData.name }
      }
    }

    Rectangle { width: content.width; height: 2; color: "#2a2a2a" }

    Grid {
      columns: 2
      spacing: root.tileGap
      Repeater {
        model: root.fanSensors
        delegate: SensorTile { required property var modelData; key: modelData.key; name: modelData.name; isFan: true }
      }
    }
  }
}
