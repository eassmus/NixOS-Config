import Quickshell
import Quickshell.Io
import QtQuick

PopupWindow {
  id: root

  // ---- API ----
  property var anchorItem: null
  property bool open: false
  property bool pillHovered: false
  property bool popupHovered: false
  property int closeDelay: 0

  onPillHoveredChanged: _updateOpen()
  onPopupHoveredChanged: _updateOpen()
  function _updateOpen() {
    if (pillHovered || popupHovered) { closeTimer.stop(); open = true }
    else closeTimer.restart()
  }
  Timer { id: closeTimer; interval: root.closeDelay; repeat: false; onTriggered: root.open = false }

  // ---- styling (matches other popups) ----
  property color bgColor: "#161616"
  property color gradTop: "#e9a6fd"
  property color gradBottom: "#82aee8"
  property color mainColor: "#82aee8"
  property color pinkColor: "#e9a6fd"
  property color greenColor: "#a6e3a1"
  property color warningColor: "#f3a611"
  property color dimColor: "#666666"
  property real borderWidth: 6
  property real radius: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int bridgeHeight: 20

  // ---- nvidia-smi state ----
  property var stats: null     // { name, temp, gpuUtil, memUtil, memUsed, memTotal, power, powerLimit, fan, clkGfx, clkMem }
  property var procs: []       // [ { pid, name, util, mem } ] sorted desc by mem
  property int maxProcs: 6

  // headline stats (single CSV line, robust to parse)
  Process {
    id: statsProc
    command: ["nvidia-smi",
      "--query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,power.limit,fan.speed,clocks.current.graphics,clocks.current.memory",
      "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      onStreamFinished: {
        let p = this.text.trim().split(",").map(function (s) { return s.trim() })
        if (p.length < 11) return
        root.stats = {
          name: p[0], temp: p[1], gpuUtil: p[2], memUtil: p[3],
          memUsed: p[4], memTotal: p[5], power: p[6], powerLimit: p[7],
          fan: p[8], clkGfx: p[9], clkMem: p[10]
        }
      }
    }
  }

  // per-process stats: pmon gives both sm utilization (%) and fb VRAM (MB),
  // covering both graphics and compute apps in a single call.
  Process {
    id: procProc
    command: ["nvidia-smi", "pmon", "-c", "1", "-s", "um"]
    stdout: StdioCollector {
      onStreamFinished: { root.procs = root._parseProcs(this.text) }
    }
  }

  // parse pmon output by reading the header row to locate columns — column
  // sets differ between driver versions, so fixed offsets aren't safe.
  function _parseProcs(text) {
    let lines = text.split("\n")
    let cols = null
    let out = []
    for (let li = 0; li < lines.length; li++) {
      let raw = lines[li]
      if (raw.trim().length === 0) continue
      if (raw[0] === "#") {
        // first header row names the columns (skip the units row)
        let h = raw.replace(/^#\s*/, "").trim().split(/\s+/)
        if (cols === null && h.indexOf("pid") !== -1) {
          cols = { pid: h.indexOf("pid"), sm: h.indexOf("sm"),
                   fb: h.indexOf("fb"), cmd: h.indexOf("command") }
        }
        continue
      }
      if (!cols) continue
      let t = raw.trim().split(/\s+/)
      let pid = t[cols.pid]
      if (!/^\d+$/.test(pid)) continue
      let fb = (cols.fb >= 0) ? t[cols.fb] : "-"
      let sm = (cols.sm >= 0) ? t[cols.sm] : "-"
      // command is the final column; names are single tokens in pmon
      let name = t[t.length - 1]
      out.push({ pid: pid, name: name, util: sm,
                 utilN: /^\d+$/.test(sm) ? parseInt(sm) : -1,
                 mem: /^\d+$/.test(fb) ? parseInt(fb) : 0 })
    }
    // sort by utilization desc, tie-break on VRAM
    out.sort(function (a, b) { return (b.utilN - a.utilN) || (b.mem - a.mem) })
    return out
  }

  function _utilStr(s) { return (!s || s === "-") ? "—" : s + "%" }

  function _refresh() {
    statsProc.running = true
    procProc.running = true
  }
  onOpenChanged: if (open) _refresh()
  Timer {
    interval: 2000
    running: root.open
    repeat: true
    onTriggered: root._refresh()
  }

  // nvidia-smi prints "[N/A]" for unsupported fields (e.g. laptop GPU fan/power cap)
  function _na(x) { return (!x || x === "[N/A]") ? "N/A" : x }
  function _powerStr() {
    if (!stats) return "--"
    let d = _na(stats.power), l = _na(stats.powerLimit)
    return l === "N/A" ? d + " W" : d + " / " + l + " W"
  }

  // ---- layout ----
  property int innerPadding: 16
  property int contentWidth: 440
  property int rowH: 30
  property int utilColW: 80
  property int memColW: 120
  property int colGap: 12

  color: "transparent"
  implicitWidth: contentWidth + innerPadding * 2 + borderWidth * 2
  implicitHeight: bridgeHeight + content.implicitHeight + innerPadding * 2 + borderWidth * 2
  visible: open

  anchor {
    item: anchorItem
    edges: Edges.Bottom
    gravity: Edges.Bottom
    margins.top: 0
  }

  HoverHandler { onHoveredChanged: root.popupHovered = hovered }

  // gradient border + bg, offset down by bridgeHeight
  Rectangle {
    id: outer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.top: parent.top
    anchors.topMargin: root.bridgeHeight
    radius: root.radius
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.gradTop }
      GradientStop { position: 1.0; color: root.gradBottom }
    }
  }
  Rectangle {
    id: bg
    anchors.fill: outer
    anchors.margins: root.borderWidth
    color: root.bgColor
    radius: Math.max(0, root.radius - root.borderWidth)
  }

  Column {
    id: content
    anchors.left: bg.left
    anchors.top: bg.top
    anchors.margins: root.innerPadding
    width: root.contentWidth
    spacing: 6

    // ---- key/value stat rows ----
    Repeater {
      model: [
        { k: "Utilization", v: root.stats ? root.stats.gpuUtil + " %" : "--" },
        { k: "VRAM",        v: root.stats ? (root.stats.memUsed + " / " + root.stats.memTotal + " MiB") : "--" },
        { k: "Temperature", v: root.stats ? root.stats.temp + " °C" : "--" },
        { k: "Power",       v: root._powerStr() },
        { k: "Fan",         v: root.stats ? (root._na(root.stats.fan) === "N/A" ? "N/A" : root.stats.fan + " %") : "--" }
      ]
      delegate: Item {
        width: content.width
        height: root.rowH
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.k
          color: root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.v
          color: root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
      }
    }

    Item { width: 1; height: 6 }

    // ---- divider ----
    Rectangle {
      width: content.width
      height: 2
      color: "#2a2a2a"
    }

    Item { width: 1; height: 4 }

    // ---- process list header ----
    Item {
      width: content.width
      height: root.rowH
      Text {
        id: hUtil
        anchors.right: hMem.left
        anchors.rightMargin: root.colGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.utilColW
        horizontalAlignment: Text.AlignRight
        text: "Util"
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        id: hMem
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.memColW
        horizontalAlignment: Text.AlignRight
        text: "VRAM"
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
    }

    // ---- top processes ----
    Text {
      width: content.width
      visible: root.procs.length === 0
      text: "No GPU processes"
      color: root.dimColor
      font.family: root.fontFamily
      font.pixelSize: 22
    }

    Repeater {
      model: root.procs.slice(0, root.maxProcs)
      delegate: Item {
        width: content.width
        height: root.rowH
        Text {
          anchors.left: parent.left
          anchors.right: pUtil.left
          anchors.rightMargin: root.colGap
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.name
          color: root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          id: pUtil
          anchors.right: pMem.left
          anchors.rightMargin: root.colGap
          anchors.verticalCenter: parent.verticalCenter
          width: root.utilColW
          horizontalAlignment: Text.AlignRight
          text: root._utilStr(modelData.util)
          color: root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
        Text {
          id: pMem
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: root.memColW
          horizontalAlignment: Text.AlignRight
          text: modelData.mem + " MiB"
          color: root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
      }
    }
  }
}
