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

  property var dirChildren: ({})     // dir path -> sorted child dir paths
  property var dirCounts: ({})       // dir path -> images anywhere under it
  property var expanded: ({})        // dir path -> bool
  property string currentFolder: ""
  property var allImages: []         // [path] across every folder
  // a folder shows everything under it, subfolders included
  readonly property var images: allImages.filter(p => p.startsWith(currentFolder + "/"))
  property string currentWallpaper: ""

  // every image in a folder at any depth under wallpaperRoot; the folder tree is
  // derived from it. Runs at startup so the preloader below can start
  // decoding, and again on open to pick up new files.
  Process {
    id: listProc
    running: true
    command: ["bash", "-c",
      "find -L '" + root.wallpaperRoot + "' -mindepth 2 -type f " +
      "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
      "2>/dev/null | sort"]
    stdout: StdioCollector { onStreamFinished: {
      let imgs = this.text.trim().split("\n").filter(s => s.length > 0)
      // unchanged → leave the models alone so no tiles rebuild
      if (imgs.join("\n") === root.allImages.join("\n")) return
      let kids = {}, counts = {}
      for (let p of imgs) {
        // credit the image to its folder and every ancestor below the root
        for (let d = p.substring(0, p.lastIndexOf("/")); d.length > root.wallpaperRoot.length;) {
          counts[d] = (counts[d] || 0) + 1
          let parent = d.substring(0, d.lastIndexOf("/"))
          kids[parent] = kids[parent] || []
          if (!kids[parent].includes(d)) kids[parent].push(d)
          d = parent
        }
      }
      for (let k in kids) kids[k].sort()
      root.dirChildren = kids
      root.dirCounts = counts
      root.allImages = imgs
      if (!counts[root.currentFolder]) root.currentFolder = (kids[root.wallpaperRoot] || [""])[0]
    } }
  }

  // visible tree rows: top-level folders, plus children of expanded ones
  readonly property var treeRows: {
    let out = []
    let walk = (parent, depth) => {
      for (let d of dirChildren[parent] || []) {
        let hasKids = !!dirChildren[d]
        out.push({ path: d, name: d.substring(d.lastIndexOf("/") + 1), depth: depth, hasKids: hasKids })
        if (hasKids && expanded[d]) walk(d, depth + 1)
      }
    }
    walk(wallpaperRoot, 0)
    return out
  }

  function toggleFolder(path) {
    let e = Object.assign({}, expanded)
    e[path] = !e[path]
    expanded = e
  }

  // selecting opens a folder but never collapses it; the chevron does that
  function selectFolder(path) {
    focusPane = "tree"
    currentFolder = path
    if (!expanded[path]) toggleFolder(path)
  }

  // ---- vim keys ----
  // tree: j/k move, l expands (or enters the grid), h collapses (or goes to parent),
  //       Enter toggles a folder / enters the grid on a leaf
  // grid: hjkl move (h off the left edge returns to the tree), Enter sets the wallpaper
  property string focusPane: "tree"   // "tree" | "grid"
  property int gridIndex: 0
  readonly property int gridCols: 4
  onCurrentFolderChanged: gridIndex = 0

  function enterGrid() {
    if (!images.length) return
    focusPane = "grid"
    gridIndex = Math.max(0, images.indexOf(currentWallpaper))
    scroll.positionViewAtIndex(gridIndex, GridView.Contain)
  }

  function treeKey(key) {
    let rows = treeRows
    let i = rows.findIndex(r => r.path === currentFolder)
    let r = rows[i]
    if (!r) return false
    let target = r.path
    switch (key) {
    case Qt.Key_J: target = rows[Math.min(i + 1, rows.length - 1)].path; break
    case Qt.Key_K: target = rows[Math.max(i - 1, 0)].path; break
    case Qt.Key_L:
      if (r.hasKids && !expanded[r.path]) toggleFolder(r.path)
      else enterGrid()
      return true
    case Qt.Key_H:
      if (r.hasKids && expanded[r.path]) toggleFolder(r.path)
      else if (r.depth > 0) target = r.path.substring(0, r.path.lastIndexOf("/"))
      break
    case Qt.Key_Return:
    case Qt.Key_Enter:
      if (r.hasKids) toggleFolder(r.path)
      else enterGrid()
      return true
    default: return false
    }
    currentFolder = target
    tree.positionViewAtIndex(treeRows.findIndex(r => r.path === target), ListView.Contain)
    return true
  }

  function gridKey(key) {
    let n = images.length, c = gridCols, i = gridIndex
    switch (key) {
    case Qt.Key_H:
      if (i % c === 0) { focusPane = "tree"; return true }
      i--
      break
    case Qt.Key_L: if (i % c < c - 1 && i + 1 < n) i++; break
    case Qt.Key_J: if (Math.floor(i / c) < Math.floor((n - 1) / c)) i = Math.min(i + c, n - 1); break
    case Qt.Key_K: if (i >= c) i -= c; break
    case Qt.Key_Return:
    case Qt.Key_Enter: setWallpaper(images[i]); return true
    default: return false
    }
    gridIndex = i
    scroll.positionViewAtIndex(i, GridView.Contain)
    return true
  }

  // Holds a decoded thumbnail of every wallpaper for quickshell's lifetime.
  // The grid's tiles request the same url, size and fill mode, so Qt's pixmap
  // cache hands them these already-decoded images instead of re-reading the
  // 4K originals, and decoding happens once in the background at startup.
  Repeater {
    model: root.allImages
    delegate: Image {
      visible: false
      source: "file://" + modelData
      sourceSize.width: root.thumbW * 2
      sourceSize.height: root.thumbH * 2
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
    }
  }

  // read currently-set wallpaper to highlight the active thumbnail
  Process {
    id: readCurrentProc
    running: true
    command: ["bash", "-c",
      "sed -n 's/^\\s*path = //p' '" + root.hyprpaperConf + "' | head -1"]
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

  // pick a random image from the current folder (and its subfolders), excluding the one already set
  // so a click always visibly changes something
  function randomWallpaper() {
    let pool = images.length > 1
      ? images.filter(function (p) { return p !== root.currentWallpaper })
      : images
    if (pool.length === 0) return
    root.setWallpaper(pool[Math.floor(Math.random() * pool.length)])
  }

  onOpenChanged: if (open) {
    focusPane = "tree"
    listProc.running = true
    readCurrentProc.running = true
  }

  // ---- layout ----
  property int treeW: 280
  property int thumbW: 220
  property int thumbH: 130
  property int gridGap: 20
  // tree + 4 thumbnail columns (the grid's trailing gap is clipped, see below)
  property int contentWidth: treeW + gridGap + 4 * (thumbW + gridGap) - gridGap
  property int contentHeight: 560

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
    // gets keys while Bar's HyprlandFocusGrab holds focus on the picker
    focus: true
    Keys.onEscapePressed: root.open = false
    Keys.onPressed: function (e) {
      if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
      // arrows behave like hjkl
      let key = ({ [Qt.Key_Left]: Qt.Key_H, [Qt.Key_Down]: Qt.Key_J,
                   [Qt.Key_Up]: Qt.Key_K, [Qt.Key_Right]: Qt.Key_L })[e.key] || e.key
      e.accepted = root.focusPane === "tree" ? root.treeKey(key) : root.gridKey(key)
    }

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

    // ---- folder tree (left) ----
    ListView {
      id: tree
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      width: root.treeW
      clip: true
      spacing: 4
      boundsBehavior: Flickable.StopAtBounds
      model: root.treeRows

      delegate: Rectangle {
        property bool active: modelData.path === root.currentFolder
        property bool open: !!root.expanded[modelData.path]
        width: tree.width
        height: 34
        radius: 8
        color: active ? root.mainColor : rowHover.hovered ? "#2a2a2a" : "transparent"

        HoverHandler { id: rowHover }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.selectFolder(modelData.path)
        }

        // expand/collapse; sits above the row's MouseArea
        Text {
          id: chevron
          x: 6 + modelData.depth * 16
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          text: modelData.hasKids ? (parent.open ? "▾" : "▸") : ""
          color: parent.active ? root.bgColor : root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 16
          font.bold: true
          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            enabled: modelData.hasKids
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleFolder(modelData.path)
          }
        }
        Text {
          id: folderIcon
          anchors.left: chevron.right
          anchors.leftMargin: 2
          anchors.verticalCenter: parent.verticalCenter
          text: parent.open && modelData.hasKids ? "" : ""   // nf-fa folder_open / folder
          color: parent.active ? root.bgColor : root.pinkColor
          font.family: root.fontFamily
          font.pixelSize: 16
        }
        Text {
          anchors.left: folderIcon.right
          anchors.leftMargin: 8
          anchors.right: countLabel.left
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.name
          elide: Text.ElideRight
          color: parent.active ? root.bgColor : root.mainColor
          font.family: root.fontFamily
          font.pixelSize: 17
          font.bold: true
        }
        Text {
          id: countLabel
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: root.dirCounts[modelData.path] || 0
          color: parent.active ? root.bgColor : root.dimColor
          font.family: root.fontFamily
          font.pixelSize: 14
        }
      }
    }

    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      x: root.treeW + root.gridGap / 2 - 1
      width: 2
      color: "#2a2a2a"
    }

    // current folder path, e.g. "Art › Sky"
    Text {
      anchors.left: tree.right
      anchors.leftMargin: root.gridGap
      anchors.right: randomBtn.left
      anchors.rightMargin: 12
      anchors.verticalCenter: closeBtn.verticalCenter
      text: root.currentFolder.substring(root.wallpaperRoot.length + 1).split("/").join("  ›  ")
      elide: Text.ElideLeft
      color: root.mainColor
      font.family: root.fontFamily
      font.pixelSize: 20
      font.bold: true
    }

    // ---- image grid (lazy, top-down) ----
    // Cell carries its gap on the right/bottom; overflow the GridView past
    // the content's right/bottom edges by `gridGap` so the trailing gap of
    // the last column / last row lands in the clipped overflow — leaving
    // visible padding only *between* images, not on the outer edges.
    GridView {
      id: scroll
      anchors.top: closeBtn.bottom
      anchors.topMargin: 20
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -root.gridGap
      anchors.left: tree.right
      anchors.leftMargin: root.gridGap
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
            id: tile
            property bool active: modelData === root.currentWallpaper
            // keyboard cursor
            property bool cursor: root.focusPane === "grid" && index === root.gridIndex
            property bool ringed: active || cursor
            width: root.thumbW
            height: root.thumbH

            // outer ring — pink when active, blue for the keyboard cursor
            Rectangle {
              anchors.fill: parent
              radius: 10
              color: "transparent"
              border.color: parent.cursor ? root.mainColor : parent.active ? root.pinkColor : "transparent"
              border.width: root.borderWidth
            }

            // image holder — clipped to a rounded shape (inset inside the
            // border when ringed) so the picture corners follow the border.
            ClippingRectangle {
              anchors.fill: parent
              anchors.margins: parent.ringed ? root.borderWidth : 0
              radius: parent.ringed ? Math.max(0, 10 - root.borderWidth) : 10
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

              // filename caption on hover / keyboard cursor
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 24
                color: "#cc000000"
                visible: hoverArea.hovered || tile.cursor
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
              onClicked: {
                root.focusPane = "grid"
                root.gridIndex = index
                root.setWallpaper(modelData)
              }
            }
          }
    }
  }
}
