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

  // nvidia-smi wakes a suspended dGPU, so it's only queried here while the popup is
  // open and the card is already awake (same gate as get_gpu_busy.sh). While closed,
  // the graph piggybacks on the bar's own query (dgpuTemp) so it has history on open.
  FileView { id: dgpuPm; path: "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status"; blockLoading: true; printErrors: false }
  property real dgpuTemp: NaN
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
    if (!dgpuAsleep) {
      if (open) nvidiaProc.running = true
      let t = open && !isNaN(_dgpuTemp) ? _dgpuTemp : dgpuTemp
      if (!isNaN(t)) vals["nvidia:temp"] = t
    }
    if (!open || dgpuAsleep) _dgpuTemp = NaN

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

  cardWidth: contentWidth + chrome
  cardHeight: content.implicitHeight + chrome

  // last-minute history, each tile scaled to its own recent range
  component SensorTile: GraphTile {
    property string key
    property bool isFan: false
    readonly property var v: root.values[key]

    theme: root
    width: (content.width - root.tileGap) / 2
    height: root.tileH
    points: root.hist[key] || []
    historyLength: root.histLen
    gridStep: isFan ? 1000 : 10
    gridLabelDiv: isFan ? 1000 : 1
    gridLabelUnit: isFan ? "k" : "°"
    valueText: {
      if (key === "nvidia:temp" && root.dgpuAsleep) return "asleep"
      if (v === undefined) return "--"
      if (isFan) return v === 0 ? "stopped" : v + " RPM"
      return Math.round(v) + " °C"
    }
    valueColor: v === undefined ? root.dimColor
      : isFan ? (v === 0 ? root.dimColor : root.mainColor)
      : root._tempColor(v)
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
