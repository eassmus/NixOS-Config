import Quickshell
import Quickshell.Services.Pipewire
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
  property color dimColor: "#666666"
  property real borderWidth: 6
  property real radius: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int bridgeHeight: 20

  // ---- audio state ----
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  // keep the default nodes bound so their description/nickname stay live
  PwObjectTracker {
    objects: {
      let o = []
      if (root.sink) o.push(root.sink)
      if (root.source) o.push(root.source)
      return o
    }
  }

  function _nodeName(n) {
    if (!n) return "None"
    return n.description || n.nickname || n.name || "Unknown"
  }

  // ---- layout ----
  property int innerPadding: 14
  property int rowSpacing: 10
  property int iconGap: 10

  color: "transparent"
  implicitWidth: Math.ceil(content.implicitWidth + innerPadding * 2 + borderWidth * 2)
  implicitHeight: bridgeHeight + content.implicitHeight + innerPadding * 2 + borderWidth * 2
  visible: open

  // right-align the card to the pill: the audio pills sit at the far-right of
  // the bar, so a centered popup would spill off the screen edge.
  anchor {
    item: anchorItem
    rect.x: anchorItem ? anchorItem.width - root.width : 0
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
    spacing: root.rowSpacing

    // output (sink)
    Row {
      spacing: root.iconGap
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰕾 "   // speaker
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root._nodeName(root.sink)
        color: root.pinkColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
    }

    // input (source)
    Row {
      spacing: root.iconGap
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍬 "   // microphone
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root._nodeName(root.source)
        color: root.pinkColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
    }
  }
}
