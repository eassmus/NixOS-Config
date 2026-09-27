import Quickshell
import Quickshell.Io
import QtQuick

PopupCard {
  id: root

  // ---- state ----
  property var _prevCpu: ({})   // core name -> { total, idle } from previous sample
  property var cores: []        // [ { core, util } ] in cpu0..cpuN order
  property int totalUtil: 0     // overall utilization (aggregate "cpu" line)
  property real tempC: 0
  property real memUsed: 0      // GiB
  property real memTotal: 0     // GiB
  property var procs: []        // [ { name, cpu, memMiB } ] sorted desc by cpu
  property int maxProcs: 6

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

  // top processes by CPU; rss is in kB, we convert to MiB in JS.
  // We fetch a few extra rows so we can drop the helpers in our own pipeline
  // (bash/ps/head) — they spike to ~100 % momentarily and would otherwise
  // flicker into the visible list.
  Process {
    id: psProc
    command: ["bash", "-c",
      "ps -eo comm,%cpu,rss --sort=-%cpu --no-headers 2>/dev/null | head -n " + (root.maxProcs + 6)]
    stdout: StdioCollector { onStreamFinished: { root.procs = root._parseProcs(this.text) } }
  }

  // processes in our own polling pipeline — filter them from the list so
  // they don't briefly appear at the top while the sample is being taken.
  readonly property var _hiddenProcs: ({ "ps": 1, "bash": 1, "sh": 1, "head": 1, "grep": 1, "awk": 1, "sed": 1 })

  function _parseProcs(text) {
    let lines = text.split("\n")
    let out = []
    for (let i = 0; i < lines.length && out.length < root.maxProcs; i++) {
      let l = lines[i].trim()
      if (!l) continue
      let p = l.split(/\s+/)
      if (p.length < 3) continue
      let cpu = parseFloat(p[p.length - 2])
      let rss = parseInt(p[p.length - 1])
      if (isNaN(cpu) || isNaN(rss)) continue
      // name is everything except the last two fields (in case comm has spaces)
      let name = p.slice(0, p.length - 2).join(" ")
      if (root._hiddenProcs[name]) continue
      out.push({ name: name, cpu: cpu, memMiB: Math.round(rss / 1024) })
    }
    return out
  }

  function _refresh() { cpuProc.running = true; psProc.running = true }
  // sample once at startup so the core list (and thus the card height) is
  // known before the popup is ever opened
  Component.onCompleted: cpuProc.running = true
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
  property int contentWidth: 560
  property int rowH: 30
  property int coreRowH: 28
  property int coreColGap: 24
  property int cpuColW: 80
  property int memColW: 110
  property int colGap: 12

  cardWidth: contentWidth + chrome
  cardHeight: content.implicitHeight + chrome
  maxCardHeight: chrome
    + 3 * rowH + 6 + 2 + 4
    + Math.ceil(cores.length / 2) * coreRowH + 6 + 2 + 4
    + rowH + maxProcs * rowH
    + content.spacing * (10 + maxProcs)

  Column {
    id: content
    width: root.contentWidth
    spacing: 6

    // ---- headline stat rows ----
    // static rows: a Repeater over an inline array rebuilds every delegate
    // each time any value changes
    component StatRow: Item {
      property string k
      property string v
      width: content.width
      height: root.rowH
      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: k
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: v
        color: root.pinkColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
    }

    StatRow { k: "Utilization"; v: root.totalUtil + " %" }
    StatRow { k: "Temperature"; v: root.tempC > 0 ? Math.round(root.tempC) + " °C" : "--" }
    StatRow {
      k: "RAM"
      v: root.memTotal > 0
        ? (root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GiB")
        : "--"
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
      // count-driven model so the per-second array replacement only updates
      // text instead of rebuilding every core row
      Repeater {
        model: root.cores.length
        delegate: Item {
          required property int index
          property var c: root.cores[index]
          width: (content.width - root.coreColGap) / 2
          height: root.coreRowH
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: c ? "C" + c.core : ""
            color: root.mainColor
            font.family: root.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: c ? c.util + "%" : ""
            color: root.pinkColor
            font.family: root.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
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
        id: hCpu
        anchors.right: hMem.left
        anchors.rightMargin: root.colGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.cpuColW
        horizontalAlignment: Text.AlignRight
        text: "CPU"
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
        text: "MEM"
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
    }

    // ---- top processes ----
    // fixed slot pool bound to procs[index] so per-poll array replacement
    // doesn't tear down and rebuild every row
    Repeater {
      model: root.maxProcs
      delegate: Item {
        required property int index
        property var p: root.procs[index]
        visible: !!p
        width: content.width
        height: root.rowH
        Text {
          anchors.left: parent.left
          anchors.right: pCpu.left
          anchors.rightMargin: root.colGap
          anchors.verticalCenter: parent.verticalCenter
          text: p ? p.name : ""
          color: root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          id: pCpu
          anchors.right: pMem.left
          anchors.rightMargin: root.colGap
          anchors.verticalCenter: parent.verticalCenter
          width: root.cpuColW
          horizontalAlignment: Text.AlignRight
          text: p ? p.cpu.toFixed(1) + "%" : ""
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
          text: p ? p.memMiB + " MiB" : ""
          color: root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
      }
    }
  }
}
