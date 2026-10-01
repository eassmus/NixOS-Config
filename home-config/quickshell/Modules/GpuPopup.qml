import Quickshell
import Quickshell.Io
import QtQuick

PopupCard {
  id: root

  // ---- nvidia-smi state ----
  property var stats: null     // { name, temp, gpuUtil, memUtil, memUsed, memTotal, power, powerLimit, fan, clkGfx, clkMem }
  property var procs: []       // [ { pid, name, mem } ] sorted desc by mem (cheap path)
  property var utilByPid: ({}) // pid -> sm% from the last (slow) pmon sample
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

  // per-process VRAM from plain `nvidia-smi`'s Processes table (~190ms). This
  // deliberately avoids `nvidia-smi pmon`, which adds per-process sm% but pays
  // for it with a ~500ms driver-wide sampling lock that stalls the compositor
  // and stutters the whole desktop each poll. VRAM alone, no lock, no hitch.
  Process {
    id: procProc
    command: ["nvidia-smi"]
    stdout: StdioCollector {
      onStreamFinished: { root.procs = root._parseProcs(this.text) }
    }
  }

  // parse the Processes table: rows look like
  //   |    0   N/A  N/A   1324   G   ...w/bin/Hyprland   2MiB |
  // i.e. gpu, GI, CI, pid, type, name(...possibly a truncated path), memory.
  function _parseProcs(text) {
    let lines = text.split("\n")
    let out = []
    for (let li = 0; li < lines.length; li++) {
      let raw = lines[li]
      // data rows are the ones carrying a memory figure
      if (raw.indexOf("MiB") < 0) continue
      let t = raw.replace(/\|/g, " ").trim().split(/\s+/)
      // find the pid: first standalone integer (gpu idx is also an int but the
      // GI/CI "N/A" columns sit between them, so the pid is the 4th token here —
      // locate it as the token right before the type letter G/C instead)
      let typeIdx = -1
      for (let k = 0; k < t.length; k++) {
        if ((t[k] === "G" || t[k] === "C" || t[k] === "C+G") && /^\d+$/.test(t[k - 1])) { typeIdx = k; break }
      }
      if (typeIdx < 0) continue
      let pid = t[typeIdx - 1]
      let mem = parseInt(t[t.length - 1])          // trailing "NNNMiB"
      if (isNaN(mem)) continue
      // name is everything between the type and the memory column; nvidia
      // truncates long paths with a leading "..." — basename either way
      let name = t.slice(typeIdx + 1, t.length - 1).join(" ")
      out.push({ pid: pid, name: root._procName(name), mem: mem })
    }
    out.sort(function (a, b) { return b.mem - a.mem })
    return out
  }

  // trim a process-table name down to something readable: drop a truncated
  // path prefix ("...") and any directories, then the nix ".foo-wrapped" dance
  function _procName(s) {
    let i = s.lastIndexOf("/")
    let b = i >= 0 ? s.slice(i + 1) : s
    if (b.charAt(0) === ".") b = b.slice(1)
    return b.replace(/-wrapped$/, "")
  }

  // per-process sm% comes ONLY from `nvidia-smi pmon`, whose ~500ms sampling
  // holds a driver-wide lock that hitches the whole desktop — so it runs on a
  // slow timer, purely to fill in the Util column by pid. The list itself is
  // still driven by the cheap VRAM path above; util shows "--" until this lands.
  Process {
    id: procUtilProc
    command: ["nvidia-smi", "pmon", "-c", "1", "-s", "u"]
    stdout: StdioCollector { onStreamFinished: { root.utilByPid = root._parseUtil(this.text) } }
  }

  function _parseUtil(text) {
    let lines = text.split("\n")
    let cols = null
    let map = ({})
    for (let li = 0; li < lines.length; li++) {
      let raw = lines[li]
      if (raw.trim().length === 0) continue
      if (raw[0] === "#") {
        // first header row names the columns; locate pid/sm (units row skipped)
        let h = raw.replace(/^#\s*/, "").trim().split(/\s+/)
        if (cols === null && h.indexOf("pid") !== -1)
          cols = { pid: h.indexOf("pid"), sm: h.indexOf("sm") }
        continue
      }
      if (!cols) continue
      let t = raw.trim().split(/\s+/)
      let pid = t[cols.pid]
      if (!/^\d+$/.test(pid)) continue
      let sm = t[cols.sm]
      map[pid] = /^\d+$/.test(sm) ? parseInt(sm) : -1
    }
    return map
  }

  function _utilStr(pid) {
    let u = root.utilByPid[pid]
    return (u === undefined || u < 0) ? "--" : u + "%"
  }

  // cheap path (headline stats + VRAM list) every 2s
  // also re-reads the AMD-only flag so SUPER+ALT+F shows up while the popup is open
  function _refresh() { statsProc.running = true; procProc.running = true; amdOnlyCheckProc.running = true }
  onOpenChanged: if (open) { _refresh(); utilKick.restart() }

  // dGPU pinned awake; state and toggle live in Vars (also right-click on the pill)
  property bool gpuPinned: false
  signal togglePin()

  // "AMD only" (on unless the allow-nvidia flag exists), shared with SUPER+ALT+F
  property bool amdOnly: true
  Process {
    id: amdOnlyCheckProc
    command: ["bash", "-c", "test -e \"$XDG_RUNTIME_DIR/gpu-allow-nvidia\""]
    onExited: function(exitCode) { root.amdOnly = exitCode !== 0 }
  }
  Process {
    id: amdOnlyToggleProc
    command: ["bash", "/home/pulsar/.config/hypr/scripts/gpu_amd_only_toggle.sh"]
    onExited: amdOnlyCheckProc.running = true
  }
  Timer {
    interval: 2000
    running: root.open
    repeat: true
    onTriggered: root._refresh()
  }

  // slow pmon: fire shortly after open (so the open frame stays smooth) and
  // then infrequently. guarded on `open` so a quick open→close can't leave a
  // pmon firing after the popup is gone.
  Timer { id: utilKick; interval: 1000; repeat: false; onTriggered: if (root.open) procUtilProc.running = true }
  Timer {
    interval: 5000
    running: root.open
    repeat: true
    onTriggered: procUtilProc.running = true
  }

  // nvidia-smi prints "[N/A]" for unsupported fields (e.g. laptop GPU fan/power cap)
  function _na(x) { return (!x || x === "[N/A]") ? "N/A" : x }
  function _powerStr() {
    if (!stats) return "--"
    let d = _na(stats.power), l = _na(stats.powerLimit)
    return l === "N/A" ? d + " W" : d + " / " + l + " W"
  }

  // ---- layout ----
  property int contentWidth: 560
  property int rowH: 30
  property int utilColW: 80
  property int memColW: 120
  property int colGap: 12

  cardWidth: contentWidth + chrome
  cardHeight: content.implicitHeight + chrome
  maxCardHeight: chrome
    + 7 * rowH + 6 + 2 + 4 + rowH + maxProcs * rowH
    + content.spacing * (10 + maxProcs)

  Column {
    id: content
    width: root.contentWidth
    spacing: 6

    // ---- key/value stat rows ----
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

    // label + switch; the whole row is clickable
    component ToggleRow: Item {
      id: tr
      property string k
      property bool checked
      signal toggled()
      width: content.width
      height: root.rowH
      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: tr.k
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 26
        radius: height / 2
        color: "#2a2a2a"
        // same blue→pink gradient as the pill borders, faded in when on
        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          opacity: tr.checked ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 150 } }
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.gradBottom }
            GradientStop { position: 1.0; color: root.gradTop }
          }
        }
        Rectangle {
          width: parent.height - 6
          height: width
          radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          x: tr.checked ? parent.width - width - 3 : 3
          color: tr.checked ? root.bgColor : root.dimColor
          Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tr.toggled()
      }
    }

    StatRow { k: "Utilization"; v: root.stats ? root.stats.gpuUtil + " %" : "--" }
    StatRow { k: "VRAM";        v: root.stats ? (root.stats.memUsed + " / " + root.stats.memTotal + " MiB") : "--" }
    StatRow { k: "Temperature"; v: root.stats ? root.stats.temp + " °C" : "--" }
    StatRow { k: "Power";       v: root._powerStr() }
    StatRow { k: "Fan";         v: root.stats ? (root._na(root.stats.fan) === "N/A" ? "N/A" : root.stats.fan + " %") : "--" }
    ToggleRow { k: "Keep awake";       checked: root.gpuPinned;  onToggled: root.togglePin() }
    ToggleRow { k: "AMD only";         checked: root.amdOnly;    onToggled: amdOnlyToggleProc.running = true }

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
          anchors.right: pUtil.left
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
          id: pUtil
          anchors.right: pMem.left
          anchors.rightMargin: root.colGap
          anchors.verticalCenter: parent.verticalCenter
          width: root.utilColW
          horizontalAlignment: Text.AlignRight
          text: p ? root._utilStr(p.pid) : ""
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
          text: p ? p.mem + " MiB" : ""
          color: root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
      }
    }
  }
}
