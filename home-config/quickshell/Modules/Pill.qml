import QtQuick

Item {
  id: root

  // ---- styling ----
  property color bgColor: "#161616"
  property color gradTop: "#e9a6fd"     // pink
  property color gradBottom: "#82aee8"  // main blue
  property real borderWidth: 6
  property real radius: 20
  property bool roundLeft: true
  property bool roundRight: true
  property real hPadding: 18
  property real lPad: hPadding
  property real rPad: hPadding

  // ---- content ----
  property string text: ""
  property color textColor: "#82aee8"
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontPx: 22
  property bool centerText: false

  // ---- interaction ----
  signal clicked()
  signal rightClicked()

  // override to size pill around custom child content instead of the label
  property real contentWidth: label.implicitWidth
  // explicit floor on pill width
  property real minWidth: 0
  // when true, the pill ratchets up its width as content grows and never shrinks
  // — handy for values that flip between widths ("70%" ↔ "Muted") without re-layout
  property bool stableWidth: false
  property real _maxSeen: 0

  implicitHeight: 42 + borderWidth * 2
  implicitWidth: {
    let want = contentWidth + lPad + rPad + borderWidth * 2
    return Math.ceil(Math.max(minWidth, stableWidth ? _maxSeen : 0, want))
  }

  onContentWidthChanged: {
    if (!stableWidth) return
    let want = contentWidth + lPad + rPad + borderWidth * 2
    if (want > _maxSeen) _maxSeen = want
  }

  // gradient border
  Rectangle {
    id: outer
    anchors.fill: parent
    topLeftRadius: root.roundLeft ? root.radius : 0
    bottomLeftRadius: root.roundLeft ? root.radius : 0
    topRightRadius: root.roundRight ? root.radius : 0
    bottomRightRadius: root.roundRight ? root.radius : 0
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.gradTop }
      GradientStop { position: 1.0; color: root.gradBottom }
    }
  }

  // inner background
  Rectangle {
    anchors.fill: outer
    anchors.leftMargin: root.roundLeft ? root.borderWidth : 0
    anchors.rightMargin: root.roundRight ? root.borderWidth : 0
    anchors.topMargin: root.borderWidth
    anchors.bottomMargin: root.borderWidth
    color: root.bgColor
    topLeftRadius: root.roundLeft ? Math.max(0, root.radius - root.borderWidth) : 0
    bottomLeftRadius: root.roundLeft ? Math.max(0, root.radius - root.borderWidth) : 0
    topRightRadius: root.roundRight ? Math.max(0, root.radius - root.borderWidth) : 0
    bottomRightRadius: root.roundRight ? Math.max(0, root.radius - root.borderWidth) : 0
  }

  Text {
    id: label
    anchors.left: root.centerText ? undefined : parent.left
    anchors.leftMargin: root.lPad + root.borderWidth
    anchors.horizontalCenter: root.centerText ? parent.horizontalCenter : undefined
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: root.fontPx
    font.bold: true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(m) {
      if (m.button === Qt.RightButton) root.rightClicked()
      else root.clicked()
    }
  }
}
