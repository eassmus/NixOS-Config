import Quickshell
import Quickshell.Networking
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

  // ---- state derived from Quickshell.Networking ----
  readonly property var _devices: Networking.devices ? Networking.devices.values : []

  // currently-connected wifi network (or null)
  readonly property var activeWifi: {
    for (let i = 0; i < _devices.length; i++) {
      let d = _devices[i]
      if (d.type !== DeviceType.Wifi) continue
      let nets = d.networks ? d.networks.values : []
      for (let j = 0; j < nets.length; j++) {
        if (nets[j].connected) return nets[j]
      }
    }
    return null
  }

  readonly property bool wiredConnected: {
    for (let i = 0; i < _devices.length; i++) {
      if (_devices[i].type === DeviceType.Wired && _devices[i].connected) return true
    }
    return false
  }

  // visible wifi networks (excluding the active one), strongest first
  readonly property var availableWifi: {
    let nets = []
    for (let i = 0; i < _devices.length; i++) {
      let d = _devices[i]
      if (d.type !== DeviceType.Wifi) continue
      let dn = d.networks ? d.networks.values : []
      for (let j = 0; j < dn.length; j++) {
        if (!dn[j].connected) nets.push(dn[j])
      }
    }
    nets.sort(function(a, b) { return (b.signalStrength || 0) - (a.signalStrength || 0) })
    return nets
  }

  // enable scanning on every wifi device so availableWifi stays fresh
  Component.onCompleted: _enableScanning()
  onActiveWifiChanged: _enableScanning()
  function _enableScanning() {
    for (let i = 0; i < _devices.length; i++) {
      let d = _devices[i]
      if (d.type === DeviceType.Wifi && "scannerEnabled" in d) d.scannerEnabled = true
    }
  }

  // ---- per-process bandwidth (nethogs trace mode) ----
  // nethogs needs cap_net_raw/cap_net_admin/cap_dac_read_search/cap_sys_ptrace;
  // it's wrapped in modules/security.nix so it runs without a root prompt.
  property var procs: []       // [ { name, down, up } ] sorted desc by down+up
  property real totalDown: 0   // KB/s, summed across all processes nethogs sees
  property real totalUp: 0
  property int maxProcs: 6

  // nethogs runs continuously while the popup is open and prints one
  // "Refreshing:" block per -d-second window; SplitParser hands us each
  // block once the *next* one starts arriving (nethogs gives no end-of-block
  // marker), so there's an unavoidable ~2s lag before the first real data —
  // a one-shot "-c 1" spawn-per-poll was tried to avoid that lag, but it
  // doesn't reliably exit under live traffic and just produced no data at all.
  Process {
    id: nethogsProc
    command: ["nethogs", "-t", "-C", "-d", "1"]
    running: root.open
    stdout: SplitParser {
      splitMarker: "\nRefreshing:\n"
      onRead: function (data) { root._parseNethogs(data) }
    }
  }

  // nethogs' "-b" (basename) flag only applies to its ncurses view, not trace
  // mode (-t) — trace mode always logs the full exe path, so we shorten it
  // ourselves. Nix wraps GUI binaries as e.g. ".firefox-wrapped" behind a
  // same-named launcher script, so strip that convention too.
  function _basename(path) {
    let i = path.lastIndexOf("/")
    let b = i >= 0 ? path.slice(i + 1) : path
    if (b.charAt(0) === ".") b = b.slice(1)
    return b.replace(/-wrapped$/, "")
  }

  function _parseNethogs(text) {
    let lines = text.split("\n")
    let out = []
    let down = 0, up = 0
    for (let i = 0; i < lines.length; i++) {
      let l = lines[i]
      if (!l) continue
      let t = l.split("\t")
      if (t.length < 3) continue
      let sent = parseFloat(t[1])
      let recv = parseFloat(t[2])
      if (isNaN(sent) || isNaN(recv)) continue
      up += sent
      down += recv
      if (sent === 0 && recv === 0) continue
      // id field is "path/pid/uid" — split from the right since paths
      // themselves contain slashes
      let idPart = t[0]
      let uidIdx = idPart.lastIndexOf("/")
      let rest = idPart.slice(0, uidIdx)
      let pidIdx = rest.lastIndexOf("/")
      let path = rest.slice(0, pidIdx)
      // nethogs couldn't map this connection's socket back to a pid at all
      // (common for UDP/QUIC traffic) — nothing to name, so skip the row but
      // keep it in the totals above
      if (path.indexOf("unknown ") === 0) continue
      out.push({ name: root._basename(path), down: recv, up: sent })
    }
    out.sort(function (a, b) { return (b.down + b.up) - (a.down + a.up) })
    root.procs = out
    root.totalDown = down
    root.totalUp = up
  }

  // same unit casing as the network pill's _fmtBits (b/s, kb/s, Mb/s, Gb/s)
  function _fmtRate(kbps) {
    let v = kbps
    let units = ["kb/s", "Mb/s", "Gb/s"]
    let i = 0
    while (v >= 1000 && i < units.length - 1) { v /= 1000; i++ }
    if (i === 0 && v < 1) return Math.round(v * 1024) + " b/s"
    if (v < 10) return v.toFixed(1) + " " + units[i]
    return Math.round(v) + " " + units[i]
  }

  // ---- layout ----
  property int innerPadding: 16
  property int contentWidth: 460
  property int rowH: 30
  property int rateColW: 90
  property int colGap: 12
  property int rateGap: 32

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
        { k: "Network", v: (function () {
            if (root.activeWifi) return root.activeWifi.name || "(unknown)"
            if (root.wiredConnected) return "Ethernet"
            return "Disconnected"
          })() },
        { k: "Signal",  v: root.activeWifi ? (Math.round(root.activeWifi.signalStrength * 100) + " %") : "--" },
        { k: "Down",    v: root._fmtRate(root.totalDown) + " 󰇚" },
        { k: "Up",      v: root._fmtRate(root.totalUp) + " 󰕒" }
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
        id: hDown
        anchors.right: hUp.left
        anchors.rightMargin: root.rateGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.rateColW
        horizontalAlignment: Text.AlignRight
        text: "󰇚"
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        id: hUp
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.rateColW
        horizontalAlignment: Text.AlignRight
        text: "󰕒"
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
      text: "No active connections"
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
          anchors.right: pDown.left
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
          id: pDown
          anchors.right: pUp.left
          anchors.rightMargin: root.rateGap
          anchors.verticalCenter: parent.verticalCenter
          width: root.rateColW
          horizontalAlignment: Text.AlignRight
          text: root._fmtRate(modelData.down)
          color: root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
        Text {
          id: pUp
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: root.rateColW
          horizontalAlignment: Text.AlignRight
          text: root._fmtRate(modelData.up)
          color: root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
      }
    }
  }
}
