import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

PopupCard {
  id: root

  // opened/closed by the wallpaper button, not by hover
  hoverDriven: false
  innerPadding: 20

  // ---- wallpaper state ----
  property string wallpaperRoot: "/home/pulsar/Wallpapers"
  property string hyprpaperConf: "/home/pulsar/.config/hypr/hyprpaper.conf"
  property string changeScript: "/home/pulsar/.config/hypr/scripts/change_wallpaper.sh"

  property var folders: []           // [{ name, path }]
  property string currentFolder: ""
  property var images: []            // [path]
  property string currentWallpaper: ""

  // list immediate subdirs of wallpaperRoot
  Process {
    id: listFoldersProc
    command: ["bash", "-c",
      "find -L '" + root.wallpaperRoot + "' -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort"]
    stdout: StdioCollector { onStreamFinished: {
      let dirs = this.text.trim().split("\n").filter(function (s) { return s.length > 0 })
      let mapped = dirs.map(function (d) {
        return { name: d.substring(d.lastIndexOf("/") + 1), path: d }
      })
      root.folders = mapped
      if (mapped.length > 0 && root.currentFolder === "") {
        root.currentFolder = mapped[0].path
      } else if (root.currentFolder !== "") {
        root._loadImages()
      }
    } }
  }

  // list images in currentFolder
  Process {
    id: listImagesProc
    property string folder: ""
    command: ["bash", "-c",
      "find -L '" + folder + "' -maxdepth 1 -type f " +
      "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
      "2>/dev/null | sort"]
    stdout: StdioCollector { onStreamFinished: {
      root.images = this.text.trim().split("\n").filter(function (s) { return s.length > 0 })
    } }
  }

  // read currently-set wallpaper to highlight the active thumbnail
  Process {
    id: readCurrentProc
    command: ["bash", "-c",
      "grep '^wallpaper' '" + root.hyprpaperConf + "' | head -1 | sed -E 's/^wallpaper = ,?//'"]
    stdout: StdioCollector { onStreamFinished: {
      root.currentWallpaper = this.text.trim()
    } }
  }

  Process {
    id: setWallpaperProc
    command: ["true"]
  }

  function setWallpaper(path) {
    setWallpaperProc.command = ["bash", root.changeScript, path]
    setWallpaperProc.running = true
    root.currentWallpaper = path
  }

  function _loadImages() {
    if (currentFolder === "") return
    listImagesProc.folder = currentFolder
    listImagesProc.running = true
  }

  // pick a random image from the current folder, excluding the one already set
  // so a click always visibly changes something
  function randomWallpaper() {
    let pool = images.length > 1
      ? images.filter(function (p) { return p !== root.currentWallpaper })
      : images
    if (pool.length === 0) return
    root.setWallpaper(pool[Math.floor(Math.random() * pool.length)])
  }

  onOpenChanged: if (open) {
    listFoldersProc.running = true
    readCurrentProc.running = true
  }
  onCurrentFolderChanged: _loadImages()

  // ---- layout ----
  property int contentWidth: 940
  property int contentHeight: 560
  property int thumbW: 220
  property int thumbH: 130
  property int gridGap: 20

  cardWidth: contentWidth + chrome
  cardHeight: contentHeight + chrome

  // Left-align the popup with the anchor item. The popup is centered on the
  // rect's bottom edge, so a rect that spans from the anchor's left edge to
  // anchor.left + root.width puts the popup's left edge flush with it.
  anchor {
    rect.x: 0
    rect.y: 0
    rect.width: root.width
    rect.height: anchorItem ? anchorItem.height : 0
  }

  Item {
    id: content
    anchors.fill: parent
    clip: true

    // close button (top-right)
    Rectangle {
      id: closeBtn
      anchors.right: parent.right
      anchors.top: parent.top
      width: 36
      height: 36
      radius: 18
      color: closeArea.containsMouse ? "#2a2a2a" : "transparent"
      border.color: root.mainColor
      border.width: 2
      Text {
        anchors.centerIn: parent
        text: "×"
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 22
        font.bold: true
      }
      MouseArea {
        id: closeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = false
      }
    }

    // randomize button — picks a random wallpaper from the current folder
    Rectangle {
      id: randomBtn
      anchors.right: closeBtn.left
      anchors.rightMargin: 16
      anchors.top: parent.top
      width: 36
      height: 36
      radius: 18
      enabled: root.images.length > 0
      opacity: enabled ? 1 : 0.4
      color: randomArea.containsMouse ? "#2a2a2a" : "transparent"
      border.color: root.mainColor
      border.width: 2
      Text {
        anchors.centerIn: parent
        text: ""   // nf-fa-random (shuffle arrows)
        color: root.mainColor
        font.family: root.fontFamily
        font.pixelSize: 18
        font.bold: true
      }
      MouseArea {
        id: randomArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.randomWallpaper()
      }
    }

    // ---- folder tabs (horizontally scrollable) ----
    Flickable {
      id: tabsScroll
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: randomBtn.left
      anchors.rightMargin: 12
      height: 36
      clip: true
      contentWidth: tabs.implicitWidth
      contentHeight: height
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.HorizontalFlick

      // wheel-scroll horizontally; pick up vertical wheel too so a normal
      // mouse can scroll the tab strip without a horizontal wheel.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function (wheel) {
          let dy = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y
          let step = -dy * 1.5
          let max = Math.max(0, tabsScroll.contentWidth - tabsScroll.width)
          tabsScroll.contentX = Math.max(0, Math.min(max, tabsScroll.contentX + step))
        }
      }

      Row {
        id: tabs
        height: tabsScroll.height
        spacing: 8
        Repeater {
          model: root.folders
          delegate: Rectangle {
            property bool active: modelData.path === root.currentFolder
            width: tabLabel.implicitWidth + 28
            height: tabs.height
            radius: 10
            color: active ? root.mainColor : "transparent"
            border.color: root.mainColor
            border.width: 2
            Text {
              id: tabLabel
              anchors.centerIn: parent
              text: modelData.name
              color: parent.active ? root.bgColor : root.mainColor
              font.family: root.fontFamily
              font.pixelSize: 18
              font.bold: true
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.currentFolder = modelData.path
            }
          }
        }
      }
    }

    // ---- image grid (lazy, top-down) ----
    // Cell carries its gap on the right/bottom; overflow the GridView past
    // the content's right/bottom edges by `gridGap` so the trailing gap of
    // the last column / last row lands in the clipped overflow — leaving
    // visible padding only *between* images, not on the outer edges.
    GridView {
      id: scroll
      anchors.top: tabsScroll.bottom
      anchors.topMargin: 20
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -root.gridGap
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.rightMargin: -root.gridGap
      clip: true
      cellWidth: root.thumbW + root.gridGap
      cellHeight: root.thumbH + root.gridGap
      model: root.images
      // big cacheBuffer = eagerly instantiate every delegate (no lazy loading)
      cacheBuffer: 1000000
      boundsBehavior: Flickable.StopAtBounds

      // faster wheel scroll than the default
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function (wheel) {
          let step = -wheel.angleDelta.y * 1.5
          let max = Math.max(0, scroll.contentHeight - scroll.height)
          scroll.contentY = Math.max(0, Math.min(max, scroll.contentY + step))
        }
      }

      delegate: Item {
            property bool active: modelData === root.currentWallpaper
            width: root.thumbW
            height: root.thumbH

            // outer ring — supplies the pink border when active
            Rectangle {
              anchors.fill: parent
              radius: 10
              color: "transparent"
              border.color: parent.active ? root.pinkColor : "transparent"
              border.width: root.borderWidth
            }

            // image holder — clipped to a rounded shape (inset inside the
            // border when active) so the picture corners follow the border.
            ClippingRectangle {
              anchors.fill: parent
              anchors.margins: parent.active ? root.borderWidth : 0
              radius: parent.active ? Math.max(0, 10 - root.borderWidth) : 10
              color: "#222"

              Image {
                anchors.fill: parent
                source: "file://" + modelData
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.thumbW * 2
                sourceSize.height: root.thumbH * 2
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
              }

              // filename caption fades in on hover
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 24
                color: "#cc000000"
                visible: hoverArea.hovered
                Text {
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: Text.AlignVCenter
                  text: modelData.substring(modelData.lastIndexOf("/") + 1)
                  color: "white"
                  font.family: root.fontFamily
                  font.pixelSize: 12
                  elide: Text.ElideMiddle
                }
              }
            }

            HoverHandler { id: hoverArea }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setWallpaper(modelData)
            }
          }
    }
  }
}
