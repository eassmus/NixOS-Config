import QtQuick

// Rounded tile with a name, a current value and a filled line of recent
// history. Shared by the thermal and CPU popups.
Rectangle {
  id: tile

  // PopupCard supplying the palette and font
  property var theme
  property string name
  property string valueText
  property color valueColor
  property var points: []          // oldest → newest; newest sits at the right edge
  property int historyLength: 30   // samples the plot's full width represents

  // y-range: fixed when rangeMin and rangeMax are both set; otherwise the
  // points' own range snapped out to gridStep multiples (so at least two
  // gridlines always show), padded so those lines don't sit on the edges
  property real rangeMin: NaN
  property real rangeMax: NaN
  property real gridStep: 10
  // gridline label = value / gridLabelDiv + gridLabelUnit; no labels when unit is empty
  property string gridLabelUnit: ""
  property real gridLabelDiv: 1

  property int pad: 10

  radius: 12
  color: "#1e1e1e"

  onPointsChanged: plot.requestPaint()

  Text {
    id: nameTxt
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: tile.pad
    text: tile.name
    color: tile.theme.mainColor
    font.family: tile.theme.fontFamily
    font.pixelSize: 22
    font.bold: true
  }

  Text {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: tile.pad
    text: tile.valueText
    color: tile.valueColor
    font.family: tile.theme.fontFamily
    font.pixelSize: 22
    font.bold: true
  }

  Canvas {
    id: plot
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: nameTxt.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: tile.pad
    anchors.rightMargin: tile.pad
    anchors.topMargin: 4
    anchors.bottomMargin: tile.pad
    onPaint: {
      let ctx = getContext("2d")
      ctx.reset()
      let p = tile.points
      if (p.length < 2) return

      let g = tile.gridStep
      let lo = tile.rangeMin, hi = tile.rangeMax
      if (isNaN(lo) || isNaN(hi)) {
        lo = Math.floor(Math.min(...p) / g) * g
        hi = Math.max(Math.ceil(Math.max(...p) / g) * g, lo + g)
        lo -= g * 0.15
        hi += g * 0.15
      }
      let yOf = v => 2 + (1 - (Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo)) * (height - 4)

      // gridlines on round values strictly inside the range
      ctx.font = "bold 12px \"" + tile.theme.fontFamily + "\""
      ctx.textBaseline = "middle"
      ctx.lineWidth = 1
      for (let gv = Math.ceil(lo / g) * g; gv < hi; gv += g) {
        if (gv <= lo) continue
        let gy = Math.round(yOf(gv)) + 0.5
        let labelW = 0
        if (tile.gridLabelUnit) {
          let label = (gv / tile.gridLabelDiv) + tile.gridLabelUnit
          labelW = ctx.measureText(label).width + 6
          ctx.fillStyle = tile.theme.dimColor.toString()
          ctx.fillText(label, 0, Math.max(7, Math.min(height - 7, gy)))
        }
        ctx.strokeStyle = "rgba(255,255,255,0.08)"
        ctx.beginPath()
        ctx.moveTo(labelW, gy)
        ctx.lineTo(width, gy)
        ctx.stroke()
      }

      let step = width / (tile.historyLength - 1)
      let xs = [], ys = []
      for (let i = 0; i < p.length; i++) {
        xs.push(width - (p.length - 1 - i) * step)
        ys.push(yOf(p[i]))
      }

      let c = tile.theme.pinkColor
      let rgba = a => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"

      ctx.beginPath()
      ctx.moveTo(xs[0], height)
      for (let i = 0; i < xs.length; i++) ctx.lineTo(xs[i], ys[i])
      ctx.lineTo(xs[xs.length - 1], height)
      ctx.closePath()
      let fill = ctx.createLinearGradient(0, 0, 0, height)
      fill.addColorStop(0, rgba(0.35))
      fill.addColorStop(1, rgba(0))
      ctx.fillStyle = fill
      ctx.fill()

      ctx.beginPath()
      for (let i = 0; i < xs.length; i++) i === 0 ? ctx.moveTo(xs[i], ys[i]) : ctx.lineTo(xs[i], ys[i])
      ctx.strokeStyle = rgba(1)
      ctx.lineWidth = 2
      ctx.lineJoin = "round"
      ctx.stroke()
    }
  }
}
