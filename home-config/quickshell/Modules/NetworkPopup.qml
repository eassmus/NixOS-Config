import Quickshell
import Quickshell.Networking
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

  // ---- layout (pill-sized: 42 inner + 6*2 border = 54 outer) ----
  property int innerPadding: 18

  color: "transparent"
  implicitWidth: Math.max(180, Math.ceil(headerLabel.implicitWidth + innerPadding * 2 + borderWidth * 2))
  implicitHeight: bridgeHeight + 42 + borderWidth * 2
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

  // single line: "Name | NN%" centered in the bg
  Text {
    id: headerLabel
    anchors.centerIn: bg
    text: {
      let name
      if (root.activeWifi) name = root.activeWifi.name || "(unknown)"
      else if (root.wiredConnected) name = "Ethernet"
      else name = "Disconnected"
      if (root.activeWifi) {
        return name + " | " + Math.round(root.activeWifi.signalStrength * 100) + "%"
      }
      return name
    }
    color: root.pinkColor
    font.family: root.fontFamily
    font.pixelSize: 22
    font.bold: true
  }
}
