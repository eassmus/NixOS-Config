import Quickshell
import Quickshell.Services.UPower
import QtQuick

PopupWindow {
  id: root

  // ---- API ----
  property var anchorItem: null
  property bool open: false
  property bool pillHovered: false
  property bool popupHovered: false
  property int closeDelay: 250

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
  readonly property var bat: UPower.displayDevice
  readonly property real rateW: bat ? (bat.changeRate || 0) : 0
  readonly property bool charging: bat
    && (bat.state === UPowerDeviceState.Charging
        || bat.state === UPowerDeviceState.PendingCharge)
  readonly property bool full: bat && bat.state === UPowerDeviceState.FullyCharged

  function _rateLabel() {
    if (full) return "Idle"
    if (charging) return "Charging"
    return "Discharging"
  }
  function _rateStr() {
    if (!bat || rateW <= 0.05) return "0.0 W"
    let sign = charging ? "+" : "−"
    return sign + rateW.toFixed(1) + " W"
  }
  function _rateColor() {
    if (full) return dimColor
    if (charging) return greenColor
    if (rateW > 30) return redColor
    if (rateW > 15) return warningColor
    return pinkColor
  }
  function _timeStr() {
    if (!bat) return "--"
    let s = charging ? bat.timeToFull : bat.timeToEmpty
    if (!s || s <= 0) return "--"
    let h = Math.floor(s / 3600)
    let m = Math.floor((s % 3600) / 60)
    return h + "h " + (m < 10 ? "0" : "") + m + "m"
  }

  // ---- layout ----
  // matches NetworkPopup's vertical sizing: bg height 42, total bridge + 42 + border
  property int innerPadding: 18
  property int innerGap: 40   // space between the label and the value

  // size to the widest strings each column can show rather than the live text,
  // so a digit-count change ("9.9 W" → "10.0 W") doesn't resize (and blink) the popup
  TextMetrics { id: labelM; font.family: root.fontFamily; font.pixelSize: 22; font.bold: true; text: "Discharging" }
  TextMetrics { id: valueM; font.family: root.fontFamily; font.pixelSize: 22; font.bold: true; text: "−100.0 W" }

  color: "transparent"
  implicitWidth: Math.ceil(labelM.width + innerGap + valueM.width
                           + innerPadding * 2 + borderWidth * 2)
  implicitHeight: bridgeHeight + 42 + borderWidth * 2
  visible: open

  // Battery pill sits at the far left of the bar — left-align the popup so it
  // doesn't try to center under the pill and spill off the screen edge.
  anchor {
    item: anchorItem
    rect.x: 0
    rect.y: 0
    rect.width: root.width
    rect.height: anchorItem ? anchorItem.height : 0
    edges: Edges.Bottom
    gravity: Edges.Bottom
    margins.top: 0
  }

  HoverHandler { onHoveredChanged: root.popupHovered = hovered }

  // gradient border + bg, offset down by bridgeHeight
  Rectangle {
    id: outer
    anchors.fill: parent
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

  Text {
    id: labelTxt
    anchors.left: bg.left
    anchors.leftMargin: root.innerPadding
    anchors.verticalCenter: bg.verticalCenter
    text: root._rateLabel()
    color: root.mainColor
    font.family: root.fontFamily
    font.pixelSize: 22
    font.bold: true
  }
  Text {
    id: valueTxt
    anchors.right: bg.right
    anchors.rightMargin: root.innerPadding
    anchors.verticalCenter: bg.verticalCenter
    text: root._rateStr()
    color: root._rateColor()
    font.family: root.fontFamily
    font.pixelSize: 22
    font.bold: true
  }
}
