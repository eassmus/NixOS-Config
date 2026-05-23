import QtQuick

// Self-clipping text that scrolls left continuously when its content overflows
// the container width. When the text fits, it just displays normally.
Item {
  id: root

  // ---- API ----
  property string text: ""
  property color color: "#82aee8"
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontPx: 22
  property bool bold: false
  property real loopGap: 60        // blank space between repeated copies
  property int pauseMs: 1500       // pause at start of each loop
  property real pxPerSec: 40       // scroll speed
  property bool elideWhenStatic: false  // if true, non-overflowing text won't expand container

  readonly property real textWidth: label.implicitWidth
  readonly property bool overflows: label.implicitWidth > width
  readonly property real overshoot: Math.max(0, label.implicitWidth - width)

  implicitHeight: label.implicitHeight
  clip: true

  Text {
    id: label
    x: 0
    text: root.text
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.fontPx
    font.bold: root.bold
  }

  // pause, scroll forward to end, pause, snap back to start (via loop restart).
  // controlled imperatively so we can guarantee label.x = 0 whenever the text fits.
  SequentialAnimation {
    id: anim
    loops: Animation.Infinite
    // snap to start before pausing so the pause is always seen at x=0, not at the end
    PropertyAction { target: label; property: "x"; value: 0 }
    PauseAnimation { duration: root.pauseMs }
    NumberAnimation {
      target: label
      property: "x"
      from: 0
      to: -root.overshoot
      // duration scales linearly with distance → constant px/sec across rows
      duration: root.overshoot * 1000 / root.pxPerSec
    }
    PauseAnimation { duration: root.pauseMs }
  }

  function _reset() {
    anim.stop()
    label.x = 0
    if (overflows && visible) anim.start()
  }

  Component.onCompleted: _reset()
  onOverflowsChanged: _reset()
  onVisibleChanged: _reset()
  Connections {
    target: label
    // defer one tick so width/overflows have settled after the text change
    function onTextChanged() { Qt.callLater(root._reset) }
  }
}
