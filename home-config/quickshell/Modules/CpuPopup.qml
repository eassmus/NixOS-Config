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
  property color redColor: "#f34646"
  property color dimColor: "#666666"
  property real borderWidth: 6
  property real radius: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int bridgeHeight: 20

  // ---- state ----
  property var _prevCpu: ({})   // core name -> { total, idle } from previous sample
  property var cores: []        // [ { core, util } ] in cpu0..cpuN order
  property int totalUtil: 0     // overall utilization (aggregate "cpu" line)
  property real tempC: 0
  property real memUsed: 0      // GiB
  property real memTotal: 0     // GiB

  // one poll = /proc/stat (per-core), /proc/meminfo, and k10temp Tctl
  Process {
    id: cpuProc
    command: ["bash", "-c",
      "cat /proc/stat; echo MEM; cat /proc/meminfo; echo TEMP; " +
      "for h in /sys/class/hwmon/hwmon*; do " +
      "[ \"$(cat \"$h/name\" 2>/dev/null)\" = k10temp ] && { cat \"$h/temp1_input\" 2>/dev/null; break; }; done"]
    stdout: StdioCollector { onStreamFinished: root._parse(this.text) }
  }

  function _parse(text) {
    let lines = text.split("\n")
    let section = "STAT"
    let prev = root._prevCpu
    let next = {}
    let cores = []
    let totalUtil = 0
    let memTotalKb = 0, memAvailKb = 0
    for (let i = 0; i < lines.length; i++) {
      let l = lines[i].trim()
      if (l === "MEM") { section = "MEM"; continue }
      if (l === "TEMP") { section = "TEMP"; continue }
      if (section === "STAT") {
        let p = l.split(/\s+/)
        let name = p[0]
        // aggregate "cpu" line → overall; "cpuN" lines → per core
        if (name !== "cpu" && !/^cpu\d+$/.test(name)) continue
        let nums = p.slice(1).map(Number)
        let total = 0; for (let k = 0; k < nums.length; k++) total += nums[k]
        let idle = (nums[3] || 0) + (nums[4] || 0)   // idle + iowait
        next[name] = { total: total, idle: idle }
        let util = 0
        if (prev[name]) {
          let dt = total - prev[name].total
          let di = idle - prev[name].idle
          if (dt > 0) util = Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt)))
        }
        if (name === "cpu") totalUtil = util
        else cores.push({ core: name.replace("cpu", ""), util: util })
      } else if (section === "MEM") {
        if (l.indexOf("MemTotal") === 0) memTotalKb = parseInt(l.split(/\s+/)[1])
        else if (l.indexOf("MemAvailable") === 0) memAvailKb = parseInt(l.split(/\s+/)[1])
      } else if (section === "TEMP") {
        let v = parseInt(l)
        if (!isNaN(v)) root.tempC = v / 1000
      }
    }
    root._prevCpu = next
    root.cores = cores
    root.totalUtil = totalUtil
    if (memTotalKb > 0) {
      root.memTotal = memTotalKb / 1048576
      root.memUsed = (memTotalKb - memAvailKb) / 1048576
    }
  }

  function _refresh() { cpuProc.running = true }
  // reset the delta baseline each time we open so the first reading is honest
  onOpenChanged: if (open) { _prevCpu = ({}); _refresh() }
  Timer {
    interval: 1000
    running: root.open
    repeat: true
    onTriggered: root._refresh()
  }

  function _utilColor(u) {
    if (u >= 85) return redColor
    if (u >= 60) return warningColor
    return pinkColor
  }
  // ---- layout ----
  property int innerPadding: 16
  property int contentWidth: 380
  property int rowH: 30
  property int coreRowH: 28
  property int coreColGap: 24

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

    // ---- headline stat rows ----
    Repeater {
      model: [
        { k: "Utilization", v: root.totalUtil + " %" },
        { k: "Temperature", v: root.tempC > 0 ? Math.round(root.tempC) + " °C" : "--" },
        { k: "RAM",         v: root.memTotal > 0
            ? (root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GiB")
            : "--" }
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

    // ---- cores, two columns ----
    Grid {
      columns: 2
      columnSpacing: root.coreColGap
      rowSpacing: 0
      Repeater {
        model: root.cores
        delegate: Item {
          width: (content.width - root.coreColGap) / 2
          height: root.coreRowH
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "C" + modelData.core
            color: root.mainColor
            font.family: root.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.util + "%"
            color: root._utilColor(modelData.util)
            font.family: root.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
        }
      }
    }
  }
}
