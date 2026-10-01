import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Modules"

Scope {
  id: root

  Vars { id: vars }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData
        color: "transparent"
        anchors { top: true; left: true; right: true }
        implicitHeight: 74

        // Sit on the `bottom` layer instead of the default `top`. Layer-shell
        // orders surfaces background < bottom < normal windows < top < overlay,
        // so on `top` nothing can ever draw over the bar — including a
        // popped-out video. The exclusive zone still reserves the bar's strip
        // regardless of layer, so tiled windows are laid out below it as
        // before; only floating windows (PiP), which can be positioned freely,
        // are now able to sit over the bar.
        WlrLayershell.layer: WlrLayer.Bottom

        // invisible full-bar item used as an anchor target for popups that need
        // to position themselves relative to the bar / screen (PopupWindow.anchor
        // requires an Item, and PanelWindow itself is a Window).
        Item {
          id: panelArea
          anchors.fill: parent
          z: -1
        }

        // -- helper processes --
        Process { id: kittyBtop;   command: ["kitty", "-e", "btop"] }
        Process { id: kittyNvtop;  command: ["kitty", "-e", "nvtop"] }
        Process { id: nmtuiLaunch; command: ["kitty", "-e", "nmtui"] }
        Process { id: batLogout;   command: ["wlogout"] }
        Process { id: fanCycle; onExited: vars.refreshFan() }
        // Native Pipewire helpers — no subprocess round-trip, no polling lag.
        function _toggleVol() {
          let n = Pipewire.defaultAudioSink
          if (n && n.ready) n.audio.muted = !n.audio.muted
        }
        function _toggleMic() {
          let n = Pipewire.defaultAudioSource
          if (n && n.ready) n.audio.muted = !n.audio.muted
        }
        function _bumpVol(dir) {
          let n = Pipewire.defaultAudioSink
          if (!n || !n.ready) return
          n.audio.muted = false
          n.audio.volume = Math.max(0, Math.min(1, n.audio.volume + dir * 0.01))
        }
        function _bumpMic(dir) {
          let n = Pipewire.defaultAudioSource
          if (!n || !n.ready) return
          n.audio.muted = false
          n.audio.volume = Math.max(0, Math.min(1, n.audio.volume + dir * 0.01))
        }

        // ---------------- LEFT ----------------
        Row {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.topMargin: 20
          anchors.leftMargin: 20
          spacing: 20

          // Battery
          Pill {
            id: batteryPill

            HoverHandler {
              onHoveredChanged: batteryPopup.pillHovered = hovered
            }

            text: {
              let s = vars.bat_state
              if (s === "Full") return "󰚥"
              if (s === "Empty") return "Goodbye"
              if (s === "Unknown") return "Unknown"
              let icon = (s === "Charging" || s === "PendingCharge") ? "" : ""
              return icon + " " + vars.bat_percent + "% | " + vars.bat_time
            }
            textColor: {
              if (vars.bat_state === "Charging" || vars.bat_state === "PendingCharge") return vars.greenColor
              if (vars.bat_percent <= 10) return vars.redColor
              if (vars.bat_percent <= 20) return vars.warningColor
              return vars.greenColor
            }
            onClicked: batLogout.running = true
          }

          // Network
          Pill {
            id: networkPill

            // bar/text approach: a small staircase signal-bars graphic in front of
            // the bandwidth text. Non-wifi states fall back to a glyph icon.
            text: ""
            lPad: 14
            rPad: 14

            property real iconW: 18
            property real iconGap: 12

            // signal strength 0..1; 0 when not on wifi
            property real wifiSignal: networkPopup.activeWifi ? networkPopup.activeWifi.signalStrength : 0

            contentWidth: iconW + iconGap + bwText.implicitWidth

            HoverHandler {
              onHoveredChanged: networkPopup.pillHovered = hovered
            }

            // ---------- left: bars graphic or glyph icon ----------
            Item {
              id: iconArea
              width: networkPill.iconW
              height: 20
              anchors.left: parent.left
              anchors.leftMargin: networkPill.borderWidth + networkPill.lPad
              anchors.verticalCenter: parent.verticalCenter

              // round to nearest 25% step with a floor of 1 lit bar while connected.
              // thresholds: 0–37 → 1 bar, 38–62 → 2, 63–87 → 3, 88–100 → 4.
              property int litBars: {
                if (vars.net_status !== "wifi") return 0
                let pct = networkPill.wifiSignal * 100
                return Math.max(1, Math.min(4, Math.round(pct / 25)))
              }

              // staircase: 4 vertical bars, bottom-aligned, increasing in height
              Row {
                anchors.fill: parent
                spacing: 2
                visible: vars.net_status === "wifi"
                Repeater {
                  model: 4
                  delegate: Item {
                    width: 4
                    height: parent.height
                    Rectangle {
                      anchors.bottom: parent.bottom
                      width: parent.width
                      height: 6 + index * 5   // 4, 8, 12, 16
                      radius: 1
                      antialiasing: true
                      property bool on: index < iconArea.litBars
                      color: on ? vars.greenColor : "#444"
                    }
                  }
                }
              }

              // fallback glyph for non-wifi states
              Text {
                anchors.centerIn: parent
                visible: vars.net_status !== "wifi"
                text: vars.net_status === "ethernet" ? "󰈁" : "󱘖"
                color: vars.net_status === "disconnected" ? vars.redColor : vars.greenColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                font.bold: true
              }
            }

            // ---------- right: bandwidth text (hidden when disconnected) ----------
            Text {
              id: bwText
              anchors.left: iconArea.right
              anchors.leftMargin: networkPill.iconGap
              anchors.verticalCenter: parent.verticalCenter
              text: vars.net_status === "disconnected" ? ""
                  : ("| " + vars.net_up + " 󰕒 | " + vars.net_down + " 󰇚 ")
              color: vars.net_status === "disconnected" ? vars.redColor
                   : (vars.net_status === "wifi" || vars.net_status === "ethernet") ? vars.greenColor
                   : vars.warningColor
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 22
              font.bold: true
            }

            onClicked: nmtuiLaunch.running = true
          }

          // Workspace group
          // Workspace pill: arrows + 10 clickable dots (Hyprland-driven)
          Pill {
            id: workspacePill
            lPad: 12
            rPad: 12

            HoverHandler {
              onHoveredChanged: wallpaperButton.pillHovered = hovered
            }

            property int wsCount: 10
            property int dotSize: 12
            property int dotSpacing: 10
            property real currentDotHeight: dotSize * 1.9


            contentWidth: wsCount * dotSize + (wsCount - 1) * dotSpacing

            // Hyprland 0.55+ evaluates dispatch strings as Lua
            function focusWs(ws) {
              Hyprland.dispatch('hl.dsp.focus({ workspace = "' + ws + '" })')
            }

            // dots, centered; scroll up = +1 ws, scroll down = -1 ws
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.NoButton
              onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0) workspacePill.focusWs("+1")
                else if (wheel.angleDelta.y < 0) workspacePill.focusWs("-1")
              }
            }

            Row {
              anchors.centerIn: parent
              spacing: workspacePill.dotSpacing

              Repeater {
                model: workspacePill.wsCount
                delegate: Item {
                  id: wsItem
                  property int wsId: index + 1
                  property bool current: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                  property bool occupied: {
                    let ws = Hyprland.workspaces.values.find(w => w.id === wsId)
                    return !!ws && ws.toplevels.values.length > 0
                  }
                  width: workspacePill.dotSize
                  // wrapper is always tall enough for the extended dot so the row's
                  // overall height (and vertical centering) stays stable
                  height: workspacePill.currentDotHeight

                  Rectangle {
                    anchors.centerIn: parent
                    width: workspacePill.dotSize
                    height: wsItem.current ? workspacePill.currentDotHeight : workspacePill.dotSize
                    radius: width / 2  // capsule when tall, circle when square
                    antialiasing: true
                    color: wsItem.occupied ? vars.pinkColor : vars.mainColor
                    Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: workspacePill.focusWs(wsItem.wsId)
                    }
                  }
                }
              }
            }

          }
          // VPN
          Pill {
            visible: vars.vpn_up.length > 0
            text: vars.vpn_up
            textColor: vars.greenColor
            rPad: 16
          }

        }

        // ---------------- CENTER ----------------
        Pill {
          id: clockPill
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 20
          text: vars.time
          textColor: vars.pinkColor

          HoverHandler {
            onHoveredChanged: calendarPopup.pillHovered = hovered
          }
        }

        SpotifyControls {
          id: spotifyPopup
          anchorItem: spotifyTrack
        }

        CalendarPopup {
          id: calendarPopup
          anchorItem: clockPill
        }

        NetworkPopup {
          id: networkPopup
          anchorItem: networkPill
          leftLimitItem: batteryPill
          sharedVars: vars
        }

        AudioPopup {
          id: audioPopup
          anchorItem: audioGroup
        }

        GpuPopup {
          id: gpuPopup
          anchorItem: gpuPill
          gpuPinned: vars.gpu_pinned
          onTogglePin: vars.toggleGpu()
        }

        CpuPopup {
          id: cpuPopup
          anchorItem: cpuPill
          sharedVars: vars
        }

        // shared by the temp and fan pills
        ThermalPopup {
          id: thermalPopup
          anchorItem: tempPill
          pillHovered: tempHover.hovered || fanHover.hovered
          dgpuTemp: vars.gpu_temp
        }

        WallpaperPicker {
          id: wallpaperPicker
          anchorItem: workspacePill
        }

        // Gives the picker keyboard focus so Escape closes it. The grab ends on
        // any click outside these windows, which closes the picker too; the
        // button is included so clicking it still toggles instead.
        HyprlandFocusGrab {
          windows: [wallpaperPicker, wallpaperButton]
          active: wallpaperPicker.open
          onCleared: wallpaperPicker.open = false
        }

        BatteryPopup {
          id: batteryPopup
          anchorItem: batteryPill
        }

        // Hover-revealed button under the workspaces pill that opens the wallpaper picker.
        // Sized + styled to match the other hover popups: gradient border, 42px
        // inner height, 20px bridge, default centered placement under the pill.
        PopupCard {
          id: wallpaperButton
          anchorItem: workspacePill
          closeDelay: 250
          innerPadding: 0
          cardWidth: iconLabel.implicitWidth + 18 * 2 + borderWidth * 2
          cardHeight: 42 + borderWidth * 2

          // left-aligned with the workspaces pill's left edge
          anchor {
            rect.x: 0
            rect.y: 0
            rect.width: wallpaperButton.width
            rect.height: workspacePill.height
          }

          Item {
            anchors.fill: parent

            Text {
              id: iconLabel
              anchors.centerIn: parent
              text: "󰋩"
              color: vars.pinkColor
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 22
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: wallpaperPicker.open = !wallpaperPicker.open
            }
          }
        }

        // ---------------- RIGHT ----------------
        Row {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: 20
          anchors.rightMargin: 20
          spacing: 20

          // Spotify track pill (album art + scrolling title)
          Pill {
            id: spotifyTrack
            visible: spotifyPopup.player !== null
            property var player: spotifyPopup.player
            property real artSize: 28
            property real maxTextWidth: 200
            property real artGap: 8

            text: ""
            lPad: 8
            rPad: 14
            contentWidth: artSize + artGap + maxTextWidth

            onClicked: {
              if (spotifyPopup.player && spotifyPopup.player.canGoNext) spotifyPopup.player.next()
            }
            onRightClicked: {
              if (spotifyPopup.player && spotifyPopup.player.canGoPrevious) spotifyPopup.player.previous()
            }

            ClippingRectangle {
              id: spotArt
              width: spotifyTrack.artSize
              height: spotifyTrack.artSize
              anchors.left: parent.left
              anchors.leftMargin: spotifyTrack.borderWidth + spotifyTrack.lPad
              anchors.verticalCenter: parent.verticalCenter
              radius: 6
              color: "#222"
              antialiasing: true
              layer.enabled: true
              layer.smooth: true
              layer.samples: 8

              Image {
                anchors.fill: parent
                source: (spotifyTrack.player && spotifyTrack.player.trackArtUrl) ? spotifyTrack.player.trackArtUrl : ""
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
                visible: status === Image.Ready && !spotifyPopup.isDJ
              }
              Text {
                anchors.centerIn: parent
                visible: spotifyPopup.isDJ || !spotifyTrack.player || !spotifyTrack.player.trackArtUrl
                color: spotifyPopup.isDJ ? vars.pinkColor : "#555"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: spotifyPopup.isDJ ? 22 : 18
                text: spotifyPopup.isDJ ? "" : ""
              }
            }

            Item {
              id: spotTextContainer
              anchors.left: spotArt.right
              anchors.leftMargin: spotifyTrack.artGap
              anchors.verticalCenter: parent.verticalCenter
              width: spotifyTrack.maxTextWidth
              height: spotLabel.implicitHeight

              Text {
                id: spotLabel
                anchors.fill: parent
                text: spotifyTrack.player ? (spotifyTrack.player.trackTitle || "Nothing playing") : "No player"
                color: vars.mainColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }

            HoverHandler {
              onHoveredChanged: spotifyPopup.pillHovered = hovered
            }
          }

          // CPU / GPU / Temp / Fan group
          Row {
            spacing: -14
            Pill {
              id: cpuPill
              roundLeft: true; roundRight: false
              text: " " + vars.cpu_usage + "%"
              textColor: vars.mainColor
              onClicked: kittyBtop.running = true

              HoverHandler {
                onHoveredChanged: cpuPopup.pillHovered = hovered
              }
            }
            Pill {
              id: gpuPill
              roundLeft: false; roundRight: false
              text: vars.gpu_usage
              textColor: vars.mainColor
              // sized to the widest state so the pill never resizes as the text changes
              contentWidth: Math.ceil(gpuWidest.advanceWidth)
              centerText: true
              TextMetrics {
                id: gpuWidest
                text: "󰢮 󰒲 99%"
                font.family: gpuPill.fontFamily
                font.pixelSize: gpuPill.fontPx
                font.bold: true
              }
              onClicked: kittyNvtop.running = true
              onRightClicked: vars.toggleGpu()

              HoverHandler {
                onHoveredChanged: gpuPopup.pillHovered = hovered
              }
            }
            Pill {
              id: tempPill
              HoverHandler { id: tempHover }
              roundLeft: false; roundRight: false
              text: " " + (thermalPopup.cpuTemp !== undefined ? Math.round(thermalPopup.cpuTemp) : "--")
              textColor: vars.mainColor
              onClicked: kittyBtop.running = true
            }
            Pill {
              HoverHandler { id: fanHover }
              roundLeft: false; roundRight: true
              text: vars.fan_mode + " "
              textColor: vars.mainColor
              onClicked: { fanCycle.command = ["asusctl","profile","next"]; fanCycle.running = true }
              onRightClicked: { fanCycle.command = ["bash","-c","asusctl profile next && asusctl profile next"]; fanCycle.running = true }
            }
          }

          // Audio: volume + mic
          Row {
            id: audioGroup
            spacing: -2

            HoverHandler {
              onHoveredChanged: audioPopup.pillHovered = hovered
            }

            Pill {
              roundLeft: true; roundRight: false
              text: vars.vol_muted ? " Muted" : (" " + ("" + vars.vol).padStart(3, " ") + "% ")
              textColor: vars.pinkColor
              onClicked: _toggleVol()
              onScrolled: dir => _bumpVol(dir)
            }
            Pill {
              roundLeft: false; roundRight: true
              text: vars.mic_muted ? " Muted" : (" " + ("" + vars.mic).padStart(3, " ") + "% ")
              textColor: vars.pinkColor
              onClicked: _toggleMic()
              onScrolled: dir => _bumpMic(dir)
            }
          }
        }
      }
    }
  }
}
