import Quickshell
import Quickshell.Services.UPower
import QtQuick

PopupCard {
  id: root

  closeDelay: 250
  innerPadding: 18

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
  property int innerGap: 40   // space between the label and the value

  // size to the widest strings each column can show rather than the live text,
  // so a digit-count change ("9.9 W" → "10.0 W") doesn't resize (and blink) the popup
  TextMetrics { id: labelM; font.family: root.fontFamily; font.pixelSize: 22; font.bold: true; text: "Discharging" }
  TextMetrics { id: valueM; font.family: root.fontFamily; font.pixelSize: 22; font.bold: true; text: "−100.0 W" }

  cardWidth: Math.ceil(labelM.width + innerGap + valueM.width + chrome)
  cardHeight: 42 + borderWidth * 2

  // Battery pill sits at the far left of the bar — left-align the popup so it
  // doesn't try to center under the pill and spill off the screen edge.
  anchor {
    rect.x: 0
    rect.y: 0
    rect.width: root.width
    rect.height: anchorItem ? anchorItem.height : 0
  }

  Text {
    id: labelTxt
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root._rateLabel()
    color: root.mainColor
    font.family: root.fontFamily
    font.pixelSize: 22
    font.bold: true
  }
  Text {
    id: valueTxt
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root._rateStr()
    color: root._rateColor()
    font.family: root.fontFamily
    font.pixelSize: 22
    font.bold: true
  }
}
