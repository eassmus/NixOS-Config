import Quickshell
import Quickshell.Io
import QtQml
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

  readonly property var cpuTemp: values["k10temp:Tctl"]

  // hwmon numbering isn't stable across boots, so sensor files are found once
  // at startup; after that every poll is in-process file reads, no processes.
  property var _sensorFiles: []   // [{ key, path }]
  Process {
    running: true
    command: ["bash", "-c",
      "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); " +
      "for f in $h/temp*_input $h/fan*_input; do [ -e \"$f\" ] || continue; " +
      "b=${f%_input}; l=$(cat ${b}_label 2>/dev/null); echo \"$n:${l:-${b##*/}}|$f\"; done; done"]
    stdout: StdioCollector { onStreamFinished: {
      root._sensorFiles = this.text.trim().split("\n").map(function (l) {
        let p = l.split("|")
        return { key: p[0], path: p[1] }
      })
    } }
  }
  Instantiator {
    id: sensorFiles
    model: root._sensorFiles
    delegate: FileView { required property var modelData; path: modelData.path; blockLoading: true }
  }

  // nvidia-smi wakes a suspended dGPU, so it's only queried while the popup is
  // open and the card is already awake (same gate as get_gpu_busy.sh)
  FileView { id: dgpuPm; path: "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status"; blockLoading: true; printErrors: false }
  property real _dgpuTemp: NaN
  Process {
    id: nvidiaProc
    command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"]
    stdout: StdioCollector { onStreamFinished: root._dgpuTemp = parseFloat(this.text) }
  }

  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root._poll() }

  function _poll() {
    let vals = {}
    for (let i = 0; i < sensorFiles.count; i++) {
      let fv = sensorFiles.objectAt(i)
      fv.reload()
      let v = parseFloat(fv.text())
      if (isNaN(v)) continue
      // hwmon temps are millidegrees; fan RPM is not
      vals[fv.modelData.key] = fv.modelData.key.indexOf("fan") >= 0 ? v : v / 1000
    }
    dgpuPm.reload()
    dgpuAsleep = dgpuPm.text().trim() === "suspended"
    if (open && !dgpuAsleep) {
      nvidiaProc.running = true
      if (!isNaN(_dgpuTemp)) vals["nvidia:temp"] = _dgpuTemp
    } else {
      _dgpuTemp = NaN
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
