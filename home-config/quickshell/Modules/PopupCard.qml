import Quickshell
import QtQuick

// Base for every bar popup: hover-driven open/close, the gradient-border card,
// and a Hyprland-style slide/fade animation. Children declared in a popup land
// inside the card's padded body.
PopupWindow {
  id: root

  // ---- API ----
  property var anchorItem: null
  property bool open: false
  property bool pillHovered: false
  property bool popupHovered: false
  property int closeDelay: 0
  // false for popups that toggle `open` themselves (click-driven)
  property bool hoverDriven: true

  // visible card size, border included. The window is always maxCardHeight
  // tall so it never resizes while mapped — resizing a mapped popup blinks.
  property real cardWidth: 0
  property real cardHeight: 0
  property real maxCardHeight: cardHeight

  // ---- styling ----
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
  property int innerPadding: 16
  readonly property int chrome: innerPadding * 2 + borderWidth * 2

  default property alias cardContent: bodyItem.data

  onPillHoveredChanged: _updateOpen()
  onPopupHoveredChanged: _updateOpen()
  function _updateOpen() {
    if (!hoverDriven) return
    if (pillHovered || popupHovered) { closeTimer.stop(); open = true }
    else closeTimer.restart()
  }
  Timer { id: closeTimer; interval: root.closeDelay; onTriggered: root.open = false }

  // ---- animation: curves and speeds mirror hypr/window.lua ----
  // windows    speed 4  → 400ms,  bezier "default" (Hyprland built-in)
  // windowsOut speed 4  → 400ms,  bezier "smoothOut"
  // fade       speed 10 → 1000ms, bezier "smoothIn"
  readonly property var _bzDefault: [0.0, 0.75, 0.15, 1.0, 1, 1]
  readonly property var _bzSmoothOut: [0.36, 0, 0.66, -0.56, 1, 1]
  readonly property var _bzSmoothIn: [0.25, 1, 0.5, 1, 1, 1]

  property real _slide: 0   // 0 = tucked under the bar, 1 = at rest
  property real _fade: 0
  // stays true through the close animation so the window unmaps after it
  property bool _mapped: false

  onOpenChanged: {
    if (open) { outAnim.stop(); _mapped = true; inAnim.restart() }
    else { inAnim.stop(); outAnim.restart() }
  }
  ParallelAnimation {
    id: inAnim
    NumberAnimation {
      target: root; property: "_slide"; to: 1; duration: 400
      easing.type: Easing.BezierSpline; easing.bezierCurve: root._bzDefault
    }
    NumberAnimation {
      target: root; property: "_fade"; to: 1; duration: 1000
      easing.type: Easing.BezierSpline; easing.bezierCurve: root._bzSmoothIn
    }
  }
  ParallelAnimation {
    id: outAnim
    NumberAnimation {
      target: root; property: "_slide"; to: 0; duration: 400
      easing.type: Easing.BezierSpline; easing.bezierCurve: root._bzSmoothOut
    }
    // fade shares the slide's 400ms so the window unmaps promptly
    NumberAnimation {
      target: root; property: "_fade"; to: 0; duration: 400
      easing.type: Easing.BezierSpline; easing.bezierCurve: root._bzSmoothIn
    }
    onFinished: if (!root.open) root._mapped = false
  }

  color: "transparent"
  implicitWidth: cardWidth
  implicitHeight: bridgeHeight + maxCardHeight
  visible: _mapped
  mask: Region { item: cardArea }

  anchor {
    item: root.anchorItem
    edges: Edges.Bottom
    gravity: Edges.Bottom
    margins.top: 0
  }

  // hover + input region: the bridge gap plus the card at rest. Collapses
  // while closing so input falls through to what's behind the leaving card
  // instead of catching it and reopening; only the pill can reopen it then.
  Item {
    id: cardArea
    width: parent.width
    height: root.open ? root.bridgeHeight + root.cardHeight : 0
    HoverHandler { onHoveredChanged: root.popupHovered = hovered }
  }

  // slides down from under the bar; the window's top edge clips it while tucked
  Item {
    width: parent.width
    height: root.cardHeight
    y: root.bridgeHeight - (1 - root._slide) * (root.bridgeHeight + root.cardHeight)
    opacity: root._fade

    Rectangle {
      id: outer
      anchors.fill: parent
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
    Item {
      id: bodyItem
      anchors.fill: bg
      anchors.margins: root.innerPadding
    }
  }
}
