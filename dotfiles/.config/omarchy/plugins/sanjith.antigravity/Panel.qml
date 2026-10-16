import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "sanjith.antigravity"
  ipcTarget: "sanjith.antigravity"
  manageIpc: false

  // Explicit plugin directory path to avoid any resolution issues
  readonly property string pluginDir: "/home/sanjith/.config/omarchy/plugins/sanjith.antigravity"

  // Theme colors smoothly resolved from Omarchy's central theme singleton
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color surface: Color.popups.background
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool showPercentage: setting("showPercentage", true) === true
  readonly property int refreshIntervalSec: setting("refreshIntervalSec", 60)
  readonly property string barIconStyle: setting("barIconStyle", "monochrome")

  // Dynamically resolve the optimal icon based on theme luminance or user style preference
  readonly property string barIconSource: {
    if (root.barIconStyle === "color") {
      return root.pluginDir + "/assets/Google-Antigravity-Icon-Full-Color.png"
    }
    var bg = (root.bar && root.bar.background) ? root.bar.background : Color.background
    var lum = (0.2126 * bg.r) + (0.7152 * bg.g) + (0.0722 * bg.b)
    return root.pluginDir + (lum >= 0.5 ? "/assets/antigravity-light.svg" : "/assets/antigravity.svg")
  }

  property var usageData: null
  property bool loading: false
  property string errorMessage: ""
  property double nowMs: Date.now()
  property bool cursorActive: false

  // Check if any limit is below 15% remaining (alarming threshold)
  readonly property bool alarming: {
    if (!usageData || usageData.lowestRemaining === undefined) return false
    return Number(usageData.lowestRemaining) <= 0.15
  }

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function refresh(force) {
    if (loading) return
    loading = true
    if (force) {
      statusProc.command = ["python3", root.pluginDir + "/get_usage.py", "--force"]
    } else {
      statusProc.command = ["python3", root.pluginDir + "/get_usage.py"]
    }
    statusProc.running = true
  }

  function launchCLI() {
    if (root.bar) {
      root.bar.run("omarchy-launch-tui --app-id=org.omarchy.agent agy")
    }
    root.close()
  }

  function launchNeovimSidebar() {
    if (root.bar) {
      root.bar.run("omarchy-launch-tui nvim +Antigravity")
    }
    root.close()
  }

  function barButtonText() {
    var glyph = "󰚩"
    if (root.showPercentage && root.usageData && root.usageData.lowestRemainingPercent !== undefined && !button.vertical) {
      return root.usageData.lowestRemainingPercent + "% " + glyph
    }
    return glyph
  }

  function barTooltip() {
    if (!usageData) return "Google Antigravity\nClick to view limits"
    var text = "Google Antigravity (" + (usageData.activeModel || "Gemini") + ")"
    if (usageData.groups && usageData.groups.length > 0) {
      for (var i = 0; i < usageData.groups.length; i++) {
        var g = usageData.groups[i]
        var name = g.displayName || "Models"
        var shortName = name.replace(/ models/i, "")
        var line = "\n" + shortName + ":"
        if (g.fiveHour && g.fiveHour.remainingPercent !== undefined) {
          line += " 5h " + g.fiveHour.remainingPercent + "%"
        }
        if (g.weekly && g.weekly.remainingPercent !== undefined) {
          line += " · Wk " + (g.weekly.isUnlimited ? "∞" : (g.weekly.remainingPercent + "%"))
        }
        text += line
      }
    } else {
      if (usageData.gemini && usageData.gemini.fiveHour) {
        text += "\nGemini: 5h " + usageData.gemini.fiveHour.remainingPercent + "% · Wk " + (usageData.gemini.weekly ? (usageData.gemini.weekly.isUnlimited ? "∞" : usageData.gemini.weekly.remainingPercent + "%") : "100%")
      }
      if (usageData.claudeGpt && usageData.claudeGpt.fiveHour) {
        text += "\nClaude/GPT: 5h " + usageData.claudeGpt.fiveHour.remainingPercent + "% · Wk " + (usageData.claudeGpt.weekly ? usageData.claudeGpt.weekly.remainingPercent + "%" : "100%")
      }
    }
    if (usageData.tokenUsage && usageData.tokenUsage.today && usageData.tokenUsage.today.totalFormatted !== "0") {
      text += "\nTokens today: " + usageData.tokenUsage.today.totalFormatted + " (all-time: " + (usageData.tokenUsage.allTime ? usageData.tokenUsage.allTime.totalFormatted : "0") + ")"
    }
    return text
  }

  // Auto-refresh when panel opens
  onOpenedChanged: {
    if (opened) {
      nowMs = Date.now()
      refresh(false)
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Component.onCompleted: {
    refresh(false)
  }

  // Periodic refresh timer
  Timer {
    interval: Math.max(15, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh(false)
  }

  // Live countdown timer while open
  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Process {
    id: statusProc
    command: ["python3", root.pluginDir + "/get_usage.py"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        try {
          var parsed = JSON.parse(text)
          if (parsed && parsed.ready) {
            root.usageData = parsed
            root.errorMessage = ""
          } else {
            root.errorMessage = (parsed && parsed.error) ? parsed.error : "Could not load usage"
          }
        } catch (e) {
          root.errorMessage = "Failed to parse usage data: " + e
        }
      }
    }
    onExited: function(code) {
      root.loading = false
      if (code !== 0 && !root.usageData) {
        root.errorMessage = "Usage collector failed (exit " + code + ")"
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(true); return "ok" }
    function getUsage(): string { return JSON.stringify(root.usageData) }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ----------------------------------------------------------- Bar Button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot * (root.showPercentage && root.usageData && !vertical ? 2.3 : 1)
    opticalSize: root.showPercentage && root.usageData && !vertical ? slotSize : Style.bar.iconCanvas
    active: root.alarming
    tooltipText: root.barTooltip()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launchCLI()
      else if (buttonCode === Qt.MiddleButton) root.refresh(true)
      else root.toggle()
    }

    iconComponent: Component {
      Row {
        id: barRow
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          id: percentLabel
          anchors.verticalCenter: parent.verticalCenter
          visible: root.showPercentage && root.usageData && root.usageData.lowestRemainingPercent !== undefined && !button.vertical
          text: (root.usageData && root.usageData.lowestRemainingPercent !== undefined)
            ? (root.usageData.lowestRemainingPercent + "%")
            : ""
          color: root.alarming ? root.urgent : (button.active && button.useActiveColor ? button.activeColor : root.foreground)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Image {
          id: barIcon
          anchors.verticalCenter: parent.verticalCenter
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          source: root.barIconSource
          fillMode: Image.PreserveAspectFit
          mipmap: true
          smooth: true
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: barIcon.status !== Image.Ready
          text: "󰚩"
          color: root.alarming ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.bar.iconFont
        }
      }
    }
  }

  // --------------------------------------------------------- Keyboard Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          panelFlick.contentY = root.clamp(
            panelFlick.contentY + dy * Style.space(60),
            0,
            Math.max(0, panelFlick.contentHeight - panelFlick.height)
          )
        }
      }
      onActivateRequested: root.refresh(true)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh(true)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: panelFlick.width
          spacing: Style.space(12)

          // ------------------------------------------------------ Hero
          PanelHero {
            id: hero
            width: parent.width
            title: "Google Antigravity"
            meta: root.usageData ? (root.usageData.tierLabel + " Plan · " + root.usageData.userEmail) : "Checking limits..."
            detail: root.usageData && root.usageData.lowestRemainingPercent !== undefined
              ? (root.usageData.lowestRemainingPercent + "% quota")
              : ""
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroIcon
                  anchors.fill: parent
                  source: root.pluginDir + "/assets/Google-Antigravity-Icon-Full-Color.png"
                  fillMode: Image.PreserveAspectFit
                  mipmap: true
                  smooth: true
                }

                Text {
                  anchors.centerIn: parent
                  visible: heroIcon.status !== Image.Ready
                  text: "󰚩"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }
          }

          // ------------------------------------------------ Active Model Chip
          BorderSurface {
            width: parent.width
            implicitHeight: modelRow.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: root.alpha(root.foreground, 0.04)
            borderSpec: Border.controlSpec("normal", root.dim, Color.accent)

            Row {
              id: modelRow
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: "Active Model:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.usageData ? root.usageData.activeModel : "Gemini 3.8 Flash (Medium)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // --------------------------------------------- Token Consumption Card
          BorderSurface {
            visible: root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.today
            width: parent.width
            implicitHeight: tokenSummaryCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.alpha(root.foreground, 0.04)
            borderSpec: Border.controlSpec("normal", root.alpha(root.dim, 0.35), Color.accent)

            Column {
              id: tokenSummaryCol
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(5)

              Item {
                width: parent.width
                implicitHeight: Math.max(tknHeaderRow.implicitHeight, tknTodayVal.implicitHeight)

                Row {
                  id: tknHeaderRow
                  spacing: Style.space(6)
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: "󰠮"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "Token Consumption"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Text {
                  id: tknTodayVal
                  text: root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.today
                    ? (root.usageData.tokenUsage.today.totalFormatted + " burned today")
                    : ""
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: "Prompt: " + (root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.today ? root.usageData.tokenUsage.today.inputFormatted : "0")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: "·"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: "Output: " + (root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.today ? root.usageData.tokenUsage.today.outputFormatted : "0")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: "·"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: "Cache: " + (root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.today ? root.usageData.tokenUsage.today.cacheFormatted : "0")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: "·"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: "All-time: " + (root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.allTime ? root.usageData.tokenUsage.allTime.totalFormatted : "0")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }
          }

          // ------------------------------------------------ Action Buttons
          Row {
            width: parent.width
            spacing: Style.spacing.md

            readonly property real cellWidth: (width - spacing) / 2

            Button {
              width: parent.cellWidth
              text: root.loading ? "Refreshing..." : "Refresh"
              iconText: root.loading ? "󰑐" : "󰑓"
              iconSpinning: root.loading
              bordered: true
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.refresh(true)
            }

            Button {
              width: parent.cellWidth
              text: "Launch CLI"
              iconText: "󰞷"
              bordered: true
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.launchCLI()
            }
          }

          // ------------------------------------------------ Error State
          BorderSurface {
            visible: root.errorMessage !== ""
            width: parent.width
            implicitHeight: errorText.implicitHeight + Style.space(20)
            radius: Style.cornerRadius
            color: root.alpha(root.urgent, 0.1)
            borderSpec: Border.controlSpec("normal", root.urgent, root.urgent)

            Text {
              id: errorText
              anchors.fill: parent
              anchors.margins: Style.space(10)
              text: root.errorMessage
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // =============================================================
          // DYNAMIC MODEL GROUPS & RATE LIMITS
          // =============================================================
          Repeater {
            model: (root.usageData && root.usageData.groups && root.usageData.groups.length > 0)
              ? root.usageData.groups
              : [
                  (root.usageData && root.usageData.gemini) ? root.usageData.gemini : ({ displayName: "GEMINI MODELS" }),
                  (root.usageData && root.usageData.claudeGpt) ? root.usageData.claudeGpt : ({ displayName: "CLAUDE AND GPT MODELS" })
                ]

            delegate: Column {
              id: groupCol
              width: parent.width
              spacing: Style.space(10)
              required property var modelData
              required property int index

              PanelSeparator {
                visible: index > 0
                foreground: root.foreground
              }

              PanelSectionHeader {
                width: parent.width
                text: (modelData.displayName || "MODELS").toUpperCase()
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                text: modelData.modelsSummary || modelData.models || ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
                visible: text !== ""
              }

              // Five Hour Limit Remaining
              LimitRow {
                visible: modelData.fiveHour && (modelData.fiveHour.remainingFraction !== undefined || modelData.fiveHour.remainingPercent !== undefined)
                width: parent.width
                windowTitle: (modelData.fiveHour && modelData.fiveHour.displayName) ? modelData.fiveHour.displayName : "Five Hour Limit Remaining"
                remainingFraction: modelData.fiveHour && modelData.fiveHour.remainingFraction !== undefined
                  ? Number(modelData.fiveHour.remainingFraction) : -1.0
                remainingPercent: modelData.fiveHour && modelData.fiveHour.remainingPercent !== undefined
                  ? Number(modelData.fiveHour.remainingPercent) : -1
                usedPercent: modelData.fiveHour && modelData.fiveHour.usedPercent !== undefined
                  ? Number(modelData.fiveHour.usedPercent) : -1
                resetsFormatted: modelData.fiveHour ? String(modelData.fiveHour.resetsFormatted || "") : ""
                resetTime: modelData.fiveHour ? String(modelData.fiveHour.resetTime || "") : ""
                isUnlimited: modelData.fiveHour ? !!modelData.fiveHour.isUnlimited : false
              }

              Item {
                width: 1
                height: Style.space(4)
                visible: modelData.fiveHour && modelData.weekly
              }

              // Weekly Limit Remaining
              LimitRow {
                visible: modelData.weekly && (modelData.weekly.remainingFraction !== undefined || modelData.weekly.remainingPercent !== undefined)
                width: parent.width
                windowTitle: (modelData.weekly && modelData.weekly.displayName) ? modelData.weekly.displayName : "Weekly Limit Remaining"
                remainingFraction: modelData.weekly && modelData.weekly.remainingFraction !== undefined
                  ? Number(modelData.weekly.remainingFraction) : -1.0
                remainingPercent: modelData.weekly && modelData.weekly.remainingPercent !== undefined
                  ? Number(modelData.weekly.remainingPercent) : -1
                usedPercent: modelData.weekly && modelData.weekly.usedPercent !== undefined
                  ? Number(modelData.weekly.usedPercent) : -1
                resetsFormatted: modelData.weekly ? String(modelData.weekly.resetsFormatted || "") : ""
                resetTime: modelData.weekly ? String(modelData.weekly.resetTime || "") : ""
                isUnlimited: modelData.weekly ? !!modelData.weekly.isUnlimited : false
              }

              // Model Badges in this group
              Flow {
                width: parent.width
                spacing: Style.space(6)
                visible: modelData.modelsList && modelData.modelsList.length > 0

                Repeater {
                  model: modelData.modelsList
                  delegate: BorderSurface {
                    id: chip
                    required property var modelData
                    radius: Style.cornerRadius
                    implicitHeight: chipRow.implicitHeight + Style.space(6)
                    implicitWidth: chipRow.implicitWidth + Style.space(12)
                    color: modelData.isActive ? root.alpha(Color.accent, 0.15) : root.alpha(root.foreground, 0.04)
                    borderSpec: Border.controlSpec("normal", modelData.isActive ? Color.accent : root.alpha(root.dim, 0.35), Color.accent)

                    Row {
                      id: chipRow
                      anchors.centerIn: parent
                      spacing: Style.space(6)

                      Text {
                        text: {
                          var t = modelData.displayName || modelData.id
                          if (modelData.tokens && modelData.tokens.totalTokens > 0) {
                            t += " (" + modelData.tokens.totalFormatted + ")"
                          }
                          return t
                        }
                        color: modelData.isActive ? Color.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: modelData.isActive
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Rectangle {
                        visible: modelData.isActive
                        width: Style.space(6)
                        height: Style.space(6)
                        radius: width / 2
                        color: Color.accent
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // =============================================================
          // SECTION 2.5: TOKEN CONSUMPTION HISTORY
          // =============================================================
          Column {
            visible: root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.history && root.usageData.tokenUsage.history.length > 0
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "TOKEN USAGE HISTORY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              text: "Daily tokens consumed across recent active sessions"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              width: parent.width
            }

            Repeater {
              model: root.usageData && root.usageData.tokenUsage ? root.usageData.tokenUsage.history : []
              delegate: Column {
                id: histCol
                required property var modelData
                required property int index
                width: parent.width
                spacing: Style.space(3)
                topPadding: Style.space(2)
                bottomPadding: Style.space(2)

                Item {
                  width: parent.width
                  implicitHeight: Math.max(lblHistDate.implicitHeight, lblHistTotal.implicitHeight)

                  Text {
                    id: lblHistDate
                    text: modelData.label || modelData.date
                    color: modelData.label === "Today" ? Color.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: modelData.label === "Today"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    id: lblHistTotal
                    text: modelData.totalFormatted + " tokens (" + modelData.steps + " turns)"
                    color: modelData.label === "Today" ? Color.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: modelData.label === "Today"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Daily relative usage meter
                Item {
                  width: parent.width
                  implicitHeight: Style.space(4)

                  Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.track
                  }

                  Rectangle {
                    anchors.left: parent.left
                    height: parent.height
                    radius: height / 2
                    width: parent.width * Math.max(0.04, Math.min(1.0, Number(modelData.barFraction || 0)))
                    color: modelData.label === "Today" ? Color.accent : root.dim
                  }
                }

                Text {
                  text: "Prompt: " + modelData.inputFormatted + " · Output: " + modelData.outputFormatted + " · Cache: " + modelData.cacheFormatted
                  color: root.alpha(root.dim, 0.75)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          PanelSeparator {
            visible: root.usageData && root.usageData.tokenUsage && root.usageData.tokenUsage.history && root.usageData.tokenUsage.history.length > 0
            foreground: root.foreground
          }

          // =============================================================
          // SECTION 3: RECENT LOCAL ACTIVITY
          // =============================================================
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "RECENT ACTIVITY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "Local Conversations:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                text: root.usageData && root.usageData.localStats
                  ? String(root.usageData.localStats.totalConversations) : "0"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Text {
              visible: root.usageData && root.usageData.localStats && root.usageData.localStats.lastTitle !== ""
              text: "Latest: " + (root.usageData ? root.usageData.localStats.lastTitle : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // ------------------------------------------------ Footer Notes
          Text {
            width: parent.width
            topPadding: Style.space(8)
            text: "Quota is shared within each model group and regenerates on a rolling basis. Press [r] to refresh or [Esc] to close."
            color: root.alpha(root.foreground, 0.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // =============================================================
  // COMPONENT: LimitRow
  // =============================================================
  component LimitRow: Column {
    id: row
    property string windowTitle: ""
    property real remainingFraction: -1.0
    property int remainingPercent: -1
    property int usedPercent: -1
    property string resetsFormatted: ""
    property string resetTime: ""
    property bool isUnlimited: false
    readonly property bool isLoaded: remainingFraction >= 0

    readonly property bool isAlarming: isLoaded && !isUnlimited && remainingFraction <= 0.15
    readonly property bool isWarning: isLoaded && !isUnlimited && remainingFraction <= 0.35 && !isAlarming

    width: parent ? parent.width : implicitWidth
    spacing: Style.space(4)

    // Top Header: Label on left, % values on right
    Item {
      width: parent.width
      implicitHeight: Math.max(lblTitle.implicitHeight, lblValues.implicitHeight)

      Text {
        id: lblTitle
        text: row.windowTitle
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: lblValues
        textFormat: Text.PlainText
        text: {
          if (!row.isLoaded) return "Loading..."
          if (row.isUnlimited) return "Unlimited (No weekly cap)"
          return row.remainingPercent + "% remaining (" + row.usedPercent + "% used)"
        }
        color: !row.isLoaded ? root.dim : (row.isAlarming ? root.urgent : (row.isWarning ? root.foreground : Color.accent))
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Progress Bar Meter
    Item {
      width: parent.width
      implicitHeight: Style.space(7)

      Rectangle {
        id: trackRect
        anchors.fill: parent
        radius: height / 2
        color: root.track
      }

      Rectangle {
        anchors.left: trackRect.left
        anchors.verticalCenter: trackRect.verticalCenter
        height: trackRect.height
        radius: trackRect.radius
        width: trackRect.width * (row.isLoaded ? root.clamp(row.remainingFraction, 0, 1) : 0)
        color: row.isAlarming ? root.urgent : (row.isWarning ? Qt.lighter(Color.accent, 1.2) : Color.accent)

        Behavior on width {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
      }
    }

    // Reset Countdown Info
    Row {
      width: parent.width
      spacing: Style.space(6)
      visible: row.isLoaded && !row.isUnlimited && row.resetsFormatted !== ""

      Text {
        text: "󱎫"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: "Resets in " + row.resetsFormatted
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
