import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick

PopupCard {
  id: root

  // sibling of anchorItem whose left edge the popup must not cross
  property var leftLimitItem: null
  property var sharedVars: null

  // ---- state derived from Quickshell.Networking ----
  readonly property var netDevices: Networking.devices ? Networking.devices.values : []

  // currently-connected wifi network (or null)
  readonly property var activeWifi: {
    for (let i = 0; i < netDevices.length; i++) {
      let d = netDevices[i]
      if (d.type !== DeviceType.Wifi) continue
      let nets = d.networks ? d.networks.values : []
      for (let j = 0; j < nets.length; j++) {
        if (nets[j].connected) return nets[j]
      }
    }
    return null
  }

  readonly property bool wiredConnected: {
    for (let i = 0; i < netDevices.length; i++) {
      if (netDevices[i].type === DeviceType.Wired && netDevices[i].connected) return true
    }
    return false
  }

  // visible wifi networks (excluding the active one), strongest first
  readonly property var availableWifi: {
    let nets = []
    for (let i = 0; i < netDevices.length; i++) {
      let d = netDevices[i]
      if (d.type !== DeviceType.Wifi) continue
      let dn = d.networks ? d.networks.values : []
      for (let j = 0; j < dn.length; j++) {
        if (!dn[j].connected) nets.push(dn[j])
      }
    }
    nets.sort(function(a, b) { return (b.signalStrength || 0) - (a.signalStrength || 0) })
    return nets
  }

  // enable scanning on every wifi device so availableWifi stays fresh.
  // Triggered on device add/remove, not on activeWifi — flipping scannerEnabled
  // from inside activeWifi's own change notification caused a binding loop.
  Component.onCompleted: _enableScanning()
  onNetDevicesChanged: _enableScanning()
  function _enableScanning() {
    for (let i = 0; i < netDevices.length; i++) {
      let d = netDevices[i]
      if (d.type === DeviceType.Wifi && "scannerEnabled" in d) d.scannerEnabled = true
    }
  }

  // ---- per-process bandwidth (nethogs trace mode) ----
  // nethogs needs cap_net_raw/cap_net_admin/cap_dac_read_search/cap_sys_ptrace;
  // it's wrapped in modules/security.nix so it runs without a root prompt.
  // Per-process rates are stored in bits/s so they format with the same
  // scale/labels as the pill's totals (which come from Vars.net_{up,down}_bps).
  property var procs: []       // [ { name, down, up } ] in bits/s, sorted desc by down+up
  property int maxProcs: 20
  // nethogs takes a few sampling windows before it can correlate sockets to
  // PIDs, so early parses are often empty even when there's real traffic.
  // Trust the "empty" state only after either a non-empty parse arrives or
  // we've seen enough sampling windows to be confident it's really idle.
  property int _parseCount: 0
  readonly property bool nethogsReady: procs.length > 0 || _parseCount >= 4

  onOpenChanged: if (!open) { _parseCount = 0; procs = [] }

  // nethogs runs continuously while the popup is open and prints one
  // "Refreshing:" block per -d-second window; SplitParser hands us each
  // block once the *next* one starts arriving (nethogs gives no end-of-block
  // marker), so there's an unavoidable ~2s lag before the first real data —
  // a one-shot "-c 1" spawn-per-poll was tried to avoid that lag, but it
  // doesn't reliably exit under live traffic and just produced no data at all.
  Process {
    id: nethogsProc
    command: ["nethogs", "-t", "-C", "-d", "0.4"]
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

  // nethogs -t outputs sent/recv in KB/s (kilobytes) — convert to bits/s so
  // per-process rows share the same scale and formatter as the pill totals.
  readonly property real _kbToBits: 1024 * 8

  function _parseNethogs(text) {
    let lines = text.split("\n")
    let out = []
    for (let i = 0; i < lines.length; i++) {
      let l = lines[i]
      if (!l) continue
      let t = l.split("\t")
      if (t.length < 3) continue
      let sent = parseFloat(t[1])
      let recv = parseFloat(t[2])
      if (isNaN(sent) || isNaN(recv)) continue
      if (sent === 0 && recv === 0) continue
      // id field is "path/pid/uid" — split from the right since paths
      // themselves contain slashes
      let idPart = t[0]
      let uidIdx = idPart.lastIndexOf("/")
      let rest = idPart.slice(0, uidIdx)
      let pidIdx = rest.lastIndexOf("/")
      let path = rest.slice(0, pidIdx)
      // nethogs couldn't map this connection's socket back to a pid at all
      // (common for UDP/QUIC traffic) — skip it since we can't name the row
      if (path.indexOf("unknown ") === 0) continue
      out.push({ name: root._basename(path), down: recv * root._kbToBits, up: sent * root._kbToBits })
    }
    out.sort(function (a, b) { return (b.down + b.up) - (a.down + a.up) })
    root.procs = out
    root._parseCount += 1
  }

  // Mirrors Vars._fmtBits so popup rates use the exact scale/labels as the pill.
  function _fmtBits(b) {
    let units = ["b/s", "kb/s", "Mb/s", "Gb/s"]
    let i = 0
    while (b >= 1000 && i < units.length - 1) { b /= 1000; i++ }
    if (i === 0)     return Math.round(b) + " " + units[i]
    if (b < 10)      return b.toFixed(1)  + " " + units[i]
    return Math.round(b) + " " + units[i]
  }

  // ---- layout ----
  property int contentWidth: 560
  property int rowH: 30
  property int rateColW: 90
  property int colGap: 12
  property int rateGap: 32

  cardWidth: contentWidth + chrome
  cardHeight: content.implicitHeight + chrome
  // tallest the card can get: header rows + maxProcs process rows
  maxCardHeight: chrome
    + 4 * rowH + 6 + 2 + 4 + rowH + maxProcs * rowH
    + content.spacing * (7 + maxProcs)

  // centered under the pill, but never further left than leftLimitItem
  anchor {
    rect.x: {
      if (!anchorItem) return 0
      let centered = (anchorItem.width - root.width) / 2
      if (!leftLimitItem) return centered
      return Math.max(centered, leftLimitItem.x - anchorItem.x)
    }
    rect.y: 0
    rect.width: root.width
    rect.height: anchorItem ? anchorItem.height : 0
  }

  Column {
    id: content
    width: root.contentWidth
    spacing: 6

    // ---- headline stat rows ----
    // Static rows rather than a Repeater over an inline array: an array
    // literal is a new model every time any value in it changes, which
    // destroys and recreates every delegate each tick and flickers.
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

    StatRow {
      k: "Network"
      v: root.activeWifi ? (root.activeWifi.name || "(unknown)")
       : root.wiredConnected ? "Ethernet" : "Disconnected"
    }
    StatRow {
      k: "Signal"
      v: root.activeWifi ? (Math.round(root.activeWifi.signalStrength * 100) + " %") : "--"
    }
    StatRow {
      k: "Down"
      v: root._fmtBits(root.sharedVars ? root.sharedVars.net_down_bps : 0) + " 󰇚"
    }
    StatRow {
      k: "Up"
      v: root._fmtBits(root.sharedVars ? root.sharedVars.net_up_bps : 0) + " 󰕒"
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
        id: hUp
        anchors.right: hDown.left
        anchors.rightMargin: root.rateGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.rateColW
        horizontalAlignment: Text.AlignRight
        text: "󰕒"
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        id: hDown
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.rateColW
        horizontalAlignment: Text.AlignRight
        text: "󰇚"
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
      text: root.nethogsReady ? "No active connections" : "Loading…"
      color: root.dimColor
      font.family: root.fontFamily
      font.pixelSize: 22
    }

    // Fixed pool of row slots bound to procs[index] instead of a Repeater over
    // the procs array itself — a fresh array every 0.4s nethogs tick would
    // otherwise tear down and rebuild every row.
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
          anchors.right: pUp.left
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
          id: pUp
          anchors.right: pDown.left
          anchors.rightMargin: root.rateGap
          anchors.verticalCenter: parent.verticalCenter
          width: root.rateColW
          horizontalAlignment: Text.AlignRight
          text: p ? root._fmtBits(p.up) : ""
          color: root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
        Text {
          id: pDown
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: root.rateColW
          horizontalAlignment: Text.AlignRight
          text: p ? root._fmtBits(p.down) : ""
          color: root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 22
          font.bold: true
        }
      }
    }
  }
}
