import Quickshell
import QtQuick

PopupWindow {
  id: root

  // ---- API ----
  property var anchorItem: null
  property bool open: false
  property bool pillHovered: false
  property bool popupHovered: false
  // tiny grace period so the transition pill → bridge doesn't race the popup closed
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

  // ---- styling (matches Pill / SpotifyControls) ----
  property color bgColor: "#161616"
  property color gradTop: "#e9a6fd"
  property color gradBottom: "#82aee8"
  property color mainColor: "#82aee8"
  property color pinkColor: "#e9a6fd"
  property color dimColor: "#3a3a3a"
  property real borderWidth: 6
  property real radius: 20
  property string fontFamily: "JetBrainsMono Nerd Font"

  // invisible hover-bridge between anchor and visible card
  property int bridgeHeight: 20

  // ---- layout ----
  property int cellSize: 46
  property int gridCols: 7
  property int gridRows: 6
  property int innerPadding: 14
  property int headerH: 36
  property int weekdayH: 26

  // ---- state ----
  property var today: new Date()
  property int displayYear: today.getFullYear()
  property int displayMonth: today.getMonth() // 0–11

  function _monthName(m) {
    return ["January","February","March","April","May","June",
            "July","August","September","October","November","December"][m]
  }
  function _firstWeekday() { return new Date(displayYear, displayMonth, 1).getDay() }
  function _daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  function _prevMonth() {
    let m = displayMonth - 1, y = displayYear
    if (m < 0) { m = 11; y-- }
    displayMonth = m; displayYear = y
  }
  function _nextMonth() {
    let m = displayMonth + 1, y = displayYear
    if (m > 11) { m = 0; y++ }
    displayMonth = m; displayYear = y
  }
  function _resetToToday() {
    today = new Date()
    displayYear = today.getFullYear()
    displayMonth = today.getMonth()
  }
  onOpenChanged: if (open) _resetToToday()

  color: "transparent"
  implicitWidth: cellSize * gridCols + innerPadding * 2 + borderWidth * 2
  implicitHeight: bridgeHeight + headerH + weekdayH + cellSize * gridRows + innerPadding * 2 + borderWidth * 2
  visible: open

  anchor {
    item: anchorItem
    edges: Edges.Bottom
    gravity: Edges.Bottom
    margins.top: 0
  }

  HoverHandler {
    onHoveredChanged: root.popupHovered = hovered
  }

  // gradient border + bg, offset down by bridgeHeight so the gap stays empty
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

  Item {
    anchors.fill: bg
    anchors.margins: root.innerPadding

    // header: < Month Year >
    Item {
      id: header
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: root.headerH

      Text {
        anchors.horizontalCenter: parent.left
        anchors.horizontalCenterOffset: root.cellSize / 2
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅁"
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
        font.weight: Font.Black
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root._prevMonth()
        }
      }
      Text {
        anchors.centerIn: parent
        text: root._monthName(root.displayMonth) + " " + root.displayYear
        color: root.pinkColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root._resetToToday()
        }
      }
      Text {
        anchors.horizontalCenter: parent.right
        anchors.horizontalCenterOffset: -root.cellSize / 2
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅂"
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
        font.weight: Font.Black
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root._nextMonth()
        }
      }
    }

    // weekday labels
    Row {
      id: weekdayRow
      anchors.top: header.bottom
      anchors.topMargin: 4
      anchors.left: parent.left
      Repeater {
        model: ["S","M","T","W","T","F","S"]
        delegate: Item {
          width: root.cellSize
          height: root.weekdayH
          Text {
            anchors.centerIn: parent
            text: modelData
            color: root.mainColor
            font.family: root.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
        }
      }
    }

    // day grid
    Grid {
      anchors.top: weekdayRow.bottom
      anchors.topMargin: 2
      anchors.left: parent.left
      columns: root.gridCols
      rows: root.gridRows

      Repeater {
        model: root.gridCols * root.gridRows
        delegate: Item {
          id: cell
          width: root.cellSize
          height: root.cellSize

          property int firstWeekday: root._firstWeekday()
          property int daysInMonth: root._daysInMonth(root.displayYear, root.displayMonth)
          property int dayOffset: index - firstWeekday
          property bool inMonth: dayOffset >= 0 && dayOffset < daysInMonth
          property int dayNum: {
            if (inMonth) return dayOffset + 1
            if (dayOffset < 0) {
              let py = root.displayMonth === 0 ? root.displayYear - 1 : root.displayYear
              let pm = root.displayMonth === 0 ? 11 : root.displayMonth - 1
              return root._daysInMonth(py, pm) + dayOffset + 1
            }
            return dayOffset - daysInMonth + 1
          }
          property bool isToday: inMonth
                              && dayNum === root.today.getDate()
                              && root.displayMonth === root.today.getMonth()
                              && root.displayYear === root.today.getFullYear()

          // gradient-border squircle around today (mirrors the pill construction)
          Rectangle {
            id: todayOuter
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 2
            radius: Math.round(width * 0.35)
            visible: cell.isToday
            antialiasing: true
            gradient: Gradient {
              GradientStop { position: 0.0; color: root.gradTop }
              GradientStop { position: 1.0; color: root.gradBottom }
            }
            Rectangle {
              anchors.fill: parent
              anchors.margins: root.borderWidth
              color: root.bgColor
              radius: Math.max(0, parent.radius - root.borderWidth)
            }
          }
          Text {
            anchors.centerIn: parent
            text: cell.dayNum
            color: cell.isToday ? root.pinkColor
                 : cell.inMonth ? root.mainColor
                 : root.dimColor
            font.family: root.fontFamily
            font.pixelSize: 22
            font.bold: cell.isToday
          }
        }
      }
    }
  }
}
