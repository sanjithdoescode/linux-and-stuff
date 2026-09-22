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
    if (usageData.gemini && usageData.gemini.fiveHour) {
      text += "\nGemini: 5h " + usageData.gemini.fiveHour.remainingPercent + "% · Wk " + (usageData.gemini.weekly ? usageData.gemini.weekly.remainingPercent : 100) + "%"
    }
    if (usageData.claudeGpt && usageData.claudeGpt.fiveHour) {
      text += "\nClaude/GPT: 5h " + usageData.claudeGpt.fiveHour.remainingPercent + "% · Wk " + (usageData.claudeGpt.weekly ? usageData.claudeGpt.weekly.remainingPercent : 100) + "%"
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
    text: root.barButtonText()
    slotSize: Style.bar.iconSlot * (root.showPercentage && root.usageData && !vertical ? 2.2 : 1)
    active: root.alarming
    tooltipText: root.barTooltip()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launchCLI()
      else if (buttonCode === Qt.MiddleButton) root.refresh(true)
      else root.toggle()
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
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(660))

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
                  source: root.pluginDir + "/assets/antigravity.svg"
                  fillMode: Image.PreserveAspectFit
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
          // SECTION 1: GEMINI MODELS (5-Hour & Weekly Limits)
          // =============================================================
          Column {
            id: geminiSection
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              width: parent.width
              text: "GEMINI MODELS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              text: "Gemini 3.8 Flash · Gemini 3.7 Flash · Gemini 3.1 Pro"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }

            // Five Hour Limit Remaining for Gemini
            LimitRow {
              width: parent.width
              windowTitle: "Five Hour Limit Remaining"
              remainingFraction: root.usageData && root.usageData.gemini && root.usageData.gemini.fiveHour && root.usageData.gemini.fiveHour.remainingFraction !== undefined
                ? Number(root.usageData.gemini.fiveHour.remainingFraction) : -1.0
              remainingPercent: root.usageData && root.usageData.gemini && root.usageData.gemini.fiveHour && root.usageData.gemini.fiveHour.remainingPercent !== undefined
                ? Number(root.usageData.gemini.fiveHour.remainingPercent) : -1
              usedPercent: root.usageData && root.usageData.gemini && root.usageData.gemini.fiveHour && root.usageData.gemini.fiveHour.usedPercent !== undefined
                ? Number(root.usageData.gemini.fiveHour.usedPercent) : -1
              resetsFormatted: root.usageData && root.usageData.gemini && root.usageData.gemini.fiveHour
                ? String(root.usageData.gemini.fiveHour.resetsFormatted || "") : ""
              resetTime: root.usageData && root.usageData.gemini && root.usageData.gemini.fiveHour
                ? String(root.usageData.gemini.fiveHour.resetTime || "") : ""
            }

            Item { width: 1; height: Style.space(4) }

            // Weekly Limit Remaining for Gemini
            LimitRow {
              width: parent.width
              windowTitle: "Weekly Limit Remaining"
              remainingFraction: root.usageData && root.usageData.gemini && root.usageData.gemini.weekly && root.usageData.gemini.weekly.remainingFraction !== undefined
                ? Number(root.usageData.gemini.weekly.remainingFraction) : -1.0
              remainingPercent: root.usageData && root.usageData.gemini && root.usageData.gemini.weekly && root.usageData.gemini.weekly.remainingPercent !== undefined
                ? Number(root.usageData.gemini.weekly.remainingPercent) : -1
              usedPercent: root.usageData && root.usageData.gemini && root.usageData.gemini.weekly && root.usageData.gemini.weekly.usedPercent !== undefined
                ? Number(root.usageData.gemini.weekly.usedPercent) : -1
              resetsFormatted: root.usageData && root.usageData.gemini && root.usageData.gemini.weekly
                ? String(root.usageData.gemini.weekly.resetsFormatted || "") : ""
              resetTime: root.usageData && root.usageData.gemini && root.usageData.gemini.weekly
                ? String(root.usageData.gemini.weekly.resetTime || "") : ""
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // =============================================================
          // SECTION 2: CLAUDE & GPT MODELS (5-Hour & Weekly Limits)
          // =============================================================
          Column {
            id: claudeSection
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              width: parent.width
              text: "CLAUDE AND GPT MODELS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              text: "Claude Sonnet 4.6 · Claude Opus 4.6 · GPT-OSS 120B"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }

            // Five Hour Limit Remaining for Claude / GPT
            LimitRow {
              width: parent.width
              windowTitle: "Five Hour Limit Remaining"
              remainingFraction: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.fiveHour && root.usageData.claudeGpt.fiveHour.remainingFraction !== undefined
                ? Number(root.usageData.claudeGpt.fiveHour.remainingFraction) : -1.0
              remainingPercent: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.fiveHour && root.usageData.claudeGpt.fiveHour.remainingPercent !== undefined
                ? Number(root.usageData.claudeGpt.fiveHour.remainingPercent) : -1
              usedPercent: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.fiveHour && root.usageData.claudeGpt.fiveHour.usedPercent !== undefined
                ? Number(root.usageData.claudeGpt.fiveHour.usedPercent) : -1
              resetsFormatted: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.fiveHour
                ? String(root.usageData.claudeGpt.fiveHour.resetsFormatted || "") : ""
              resetTime: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.fiveHour
                ? String(root.usageData.claudeGpt.fiveHour.resetTime || "") : ""
            }

            Item { width: 1; height: Style.space(4) }

            // Weekly Limit Remaining for Claude / GPT
            LimitRow {
              width: parent.width
              windowTitle: "Weekly Limit Remaining"
              remainingFraction: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.weekly && root.usageData.claudeGpt.weekly.remainingFraction !== undefined
                ? Number(root.usageData.claudeGpt.weekly.remainingFraction) : -1.0
              remainingPercent: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.weekly && root.usageData.claudeGpt.weekly.remainingPercent !== undefined
                ? Number(root.usageData.claudeGpt.weekly.remainingPercent) : -1
              usedPercent: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.weekly && root.usageData.claudeGpt.weekly.usedPercent !== undefined
                ? Number(root.usageData.claudeGpt.weekly.usedPercent) : -1
              resetsFormatted: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.weekly
                ? String(root.usageData.claudeGpt.weekly.resetsFormatted || "") : ""
              resetTime: root.usageData && root.usageData.claudeGpt && root.usageData.claudeGpt.weekly
                ? String(root.usageData.claudeGpt.weekly.resetTime || "") : ""
            }
          }

          PanelSeparator {
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
    readonly property bool isLoaded: remainingFraction >= 0

    readonly property bool isAlarming: isLoaded && remainingFraction <= 0.15
    readonly property bool isWarning: isLoaded && remainingFraction <= 0.35 && !isAlarming

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
        text: row.isLoaded
          ? (row.remainingPercent + "% remaining (" + row.usedPercent + "% used)")
          : "Loading..."
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
      visible: row.isLoaded && row.resetsFormatted !== ""

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
