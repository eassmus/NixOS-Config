import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick

PopupWindow {
  id: root

  // ---- API ----
  property var anchorItem: null
  property bool open: false

  // hover-tracking
  property bool pillHovered: false
  property bool popupHovered: false
  property int closeDelay: 0

  onPillHoveredChanged: _updateOpen()
  onPopupHoveredChanged: _updateOpen()

  function _updateOpen() {
    if (pillHovered || popupHovered) {
      closeTimer.stop()
      open = true
    } else {
      closeTimer.restart()
    }
  }

  Timer {
    id: closeTimer
    interval: root.closeDelay
    repeat: false
    onTriggered: root.open = false
  }

  // pick the spotify player if present, else first available
  property var player: {
    let players = Mpris.players.values
    for (let i = 0; i < players.length; i++) {
      let p = players[i]
      if (p && p.identity && p.identity.toLowerCase().indexOf("spotify") !== -1) return p
    }
    return players.length > 0 ? players[0] : null
  }

  // Spotify AI DJ detection: it surfaces a placeholder track titled "Up Next"
  // and the artist is always "DJ <name>" (e.g. "DJ X")
  readonly property bool isDJ: {
    if (!player) return false
    let title = player.trackTitle || ""
    let artist = player.trackArtist || ""
    if (title === "Up Next") return true
    if (artist.toLowerCase().indexOf("dj ") === 0) return true
    return false
  }

  // ---- styling (matches Pill) ----
  property color bgColor: "#161616"
  property color gradTop: "#e9a6fd"
  property color gradBottom: "#82aee8"
  property color mainColor: "#82aee8"
  property color pinkColor: "#e9a6fd"
  property real borderWidth: 6
  property real radius: 20
  property string fontFamily: "JetBrainsMono Nerd Font"

  // gap between bar bottom and the visible popup top — surface extends across
  // this so the cursor stays inside the popup window while traveling down
  property int bridgeHeight: 20

  color: "transparent"
  implicitWidth: 500
  implicitHeight: 244 + bridgeHeight
  visible: open

  anchor {
    item: anchorItem
    edges: Edges.Bottom
    gravity: Edges.Bottom
    margins.top: 0
  }

  // whole-surface hover bridge (covers invisible top region + visible card)
  HoverHandler {
    onHoveredChanged: root.popupHovered = hovered
  }

  // gradient border + bg
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

  // scroll anywhere on the card to seek (5s per notch)
  MouseArea {
    anchors.fill: bg
    acceptedButtons: Qt.NoButton // let clicks pass through to inner controls
    propagateComposedEvents: true
    onWheel: function(wheel) {
      if (!root.player || !root.player.canSeek || root.player.length <= 0) return
      let stepSec = 5
      let dir = wheel.angleDelta.y > 0 ? 1 : -1
      let newPos = root.player.position + dir * stepSec
      if (newPos < 0) newPos = 0
      if (newPos > root.player.length) newPos = root.player.length
      root.player.position = newPos
    }
  }

  Item {
    anchors.fill: bg
    anchors.topMargin: 16
    anchors.leftMargin: 16
    anchors.rightMargin: 16

    Item {
      id: topSection
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: artFrame.height
      // album art (gradient border + clipped inner)
      Rectangle {
        id: artFrame
        width: 120
        height: 120
        anchors.left: parent.left
        anchors.top: parent.top
        radius: 10
        gradient: Gradient {
          GradientStop { position: 0.0; color: root.gradTop }
          GradientStop { position: 1.0; color: root.gradBottom }
        }

        ClippingRectangle {
          id: artInner
          anchors.fill: parent
          anchors.margins: root.borderWidth
          radius: Math.max(0, parent.radius - root.borderWidth)
          color: "#222"
          antialiasing: true
          layer.enabled: true
          layer.smooth: true
          layer.samples: 8

          Image {
            anchors.fill: parent
            source: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
            cache: true
            visible: status === Image.Ready && !root.isDJ
          }
          Text {
            anchors.centerIn: parent
            visible: root.isDJ || !root.player || !root.player.trackArtUrl
            color: root.isDJ ? root.pinkColor : "#555"
            text: root.isDJ ? "" : ""
            font.family: root.fontFamily
            font.pixelSize: 56
          }
        }
      }

      // right side column
      Item {
        anchors.left: artFrame.right
        anchors.leftMargin: 16
        anchors.right: topSection.right
        anchors.top: topSection.top
        anchors.bottom: topSection.bottom

        // track info — each line scrolls if it overflows the column width
        MarqueeText {
          id: title
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          text: root.player ? (root.player.trackTitle || "Nothing playing") : "No player"
          color: root.pinkColor
          fontFamily: root.fontFamily
          fontPx: 22
          bold: true
        }

        MarqueeText {
          id: artist
          anchors.top: title.bottom
          anchors.topMargin: 6
          anchors.left: parent.left
          anchors.right: parent.right
          text: root.player ? (root.player.trackArtist || "") : ""
          color: root.mainColor
          fontFamily: root.fontFamily
          fontPx: 22
          bold: true
        }

        MarqueeText {
          id: album
          anchors.top: artist.bottom
          anchors.topMargin: 2
          anchors.left: parent.left
          anchors.right: parent.right
          text: root.player ? (root.player.trackAlbum || "") : ""
          color: root.mainColor
          fontFamily: root.fontFamily
          fontPx: 22
          visible: text.length > 0
        }
      }
    }

    // progress bar above the controls
    Item {
      id: progressRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: topSection.bottom
      anchors.topMargin: 12
      height: 18

      Text {
        id: posText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: { root._tick; return root._fmtTime(root.player ? root.player.position : 0) }
        color: root.pinkColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      Text {
        id: lenText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root._fmtTime(root.player ? root.player.length : 0)
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }

      Rectangle {
        id: bar
        anchors.left: posText.right
        anchors.right: lenText.left
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        color: "#333"
        radius: height / 2
        clip: true

        // clipped progress region — width tracks playback fraction
        Item {
          id: fillClip
          height: parent.height
          width: {
            root._tick;
            if (!root.player || root.player.length <= 0) return 0
            let r = (root.player.position / root.player.length)
            return Math.max(0, Math.min(1, r)) * bar.width
          }
          clip: true

          // full-width gradient — the clip above reveals only the played portion,
          // so colors stay anchored to bar position rather than stretching
          Rectangle {
            width: bar.width
            height: parent.height
            radius: parent.height / 2
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: root.pinkColor }
              GradientStop { position: 1.0; color: root.mainColor }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.player && root.player.canSeek
          onClicked: function(m) {
            if (!root.player || root.player.length <= 0) return
            let frac = m.x / width
            root.player.position = frac * root.player.length
          }
        }
      }
    }
    // controls
    Row {
      id: controls
      anchors.top: progressRow.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 0
      anchors.topMargin: -2
      spacing: 28

      Text {
        text: "󰒮"
        color: (root.player && root.player.canGoPrevious) ? root.mainColor : "#555"
        font.family: root.fontFamily
        font.pixelSize: 50
        font.bold: true
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: root.player && root.player.canGoPrevious
          onClicked: root.player.previous()
        }
      }

      Text {
        text: (root.player && root.player.isPlaying) ? "󰏤" : "󰐊"
        color: (root.player && root.player.isPlaying) ? root.pinkColor : root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 50
        font.bold: true
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: root.player && root.player.canTogglePlaying
          onClicked: root.player.togglePlaying()
        }
      }

      Text {
        text: "󰒭"
        color: (root.player && root.player.canGoNext) ? root.mainColor : "#555"
        font.family: root.fontFamily
        font.pixelSize: 50
        font.bold: true
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: root.player && root.player.canGoNext
          onClicked: root.player.next()
        }
      }
    }

  }

  // local tick to advance the progress UI between Mpris updates
  property real _tick: 0
  Timer {
    interval: 500
    running: root.open && root.player && root.player.isPlaying
    repeat: true
    onTriggered: root._tick = Date.now()
  }

  function _fmtTime(s) {
    if (!s || s < 0) s = 0
    let total = Math.floor(s)
    let m = Math.floor(total / 60)
    let r = total % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }
}
