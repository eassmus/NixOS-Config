import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

PopupCard {
  id: root

  innerPadding: 14

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
  property int rowSpacing: 10
  property int iconGap: 10

  cardWidth: Math.ceil(content.implicitWidth + chrome)
  cardHeight: content.implicitHeight + chrome

  // right-align the card to the pill: the audio pills sit at the far-right of
  // the bar, so a centered popup would spill off the screen edge.
  anchor {
    rect.x: anchorItem ? anchorItem.width - root.width : 0
    rect.y: 0
    rect.width: root.width
    rect.height: anchorItem ? anchorItem.height : 0
  }

  Column {
    id: content
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
