import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Monet's place in the Omarchy bar. The icon opens a list of the sites and
// projects on this computer that Monet can review; pick one and Monet opens
// straight into capturing it. Every time the panel opens it also checks what
// it depends on, and says plainly what is missing and how to get it.
Panel {
  id: root
  moduleName: Model.PLUGIN_ID
  ipcTarget: "monet"

  // What was found the last time the panel looked.
  property bool looked: false
  property bool installed: true
  property var pluginMissing: []
  property var appMissing: []
  property var siteRows: []
  property var monetStatus: null
  property bool statusSeen: false
  property bool refreshing: false
  property string problem: ""
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var missing: pluginMissing.concat(appMissing)
  readonly property bool blocked: missing.some(function(item) { return item.required })
  readonly property var summary: installed ? Model.reviewSummary(monetStatus) : null
  readonly property var targets: installed ? Model.targets(summary, siteRows) : []
  readonly property int firstSiteTarget: summary ? 1 : 0
  readonly property string barState: Model.barState(monetStatus)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string helperPath: Model.pluginDirectory(Qt.resolvedUrl("monet-open"), Quickshell.env("HOME")) + "/monet-open"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Looks for the commands this plugin runs. Cheap enough to do at login, so
  // the bar icon can flag a missing dependency before the panel is opened.
  function checkDependencies() {
    if (!sweep.running) sweep.running = true
  }

  function refresh() {
    if (overviewProc.running) return
    refreshing = true
    problem = ""
    // A sweep already under way carries on into the fuller report.
    if (!sweep.running) sweep.running = true
  }

  function sweepFinished(text) {
    looked = true
    installed = Model.monetInstalled(text)
    pluginMissing = Model.missingCommands(text)
    if (!installed) {
      appMissing = []
      siteRows = []
      refreshing = false
      return
    }
    // The fuller report starts Monet's service for a moment, so it waits for
    // the panel to be opened.
    if (refreshing) overviewProc.running = true
  }

  function overviewFinished(text) {
    if (!refreshing) return
    refreshing = false
    var report = Model.overview(text)
    if (!report) {
      problem = "Monet did not answer. Open Monet once, then try again."
      return
    }
    appMissing = report.missing
    siteRows = report.rows
    if (report.status) monetStatus = report.status
    cursorIndex = Model.clampIndex(cursorIndex, targets.length)
  }

  function openMonet(args) {
    if (!installed) return
    Quickshell.execDetached(["bash", helperPath].concat(args || []))
    close()
  }

  function activateTarget(index) {
    if (targets.length === 0) return
    var target = targets[Model.clampIndex(index, targets.length)]
    if (target.kind === "continue") openMonet(Model.continueArguments(monetStatus))
    else if (target.kind === "site") openMonet(siteRows[target.index].arguments)
    else if (target.kind === "screen") openMonet(Model.PICK_SCREEN_ARGUMENTS)
    else openMonet([])
  }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = Model.clampIndex(index, targets.length)
  }

  function moveCursor(dy) {
    if (dy === 0 || targets.length === 0) return
    // The first arrow press shows the cursor where it is; the next one moves it.
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex = Model.clampIndex(cursorIndex + dy, targets.length)
  }

  function scrollItemIntoView(item) {
    if (!item) return
    Qt.callLater(function() {
      if (!item || !flick) return
      var margin = Style.space(6)
      var top = item.mapToItem(flick.contentItem, 0, 0).y
      var bottom = top + item.height
      var maxY = Math.max(0, flick.contentHeight - flick.height)
      if (top < flick.contentY + margin) flick.contentY = Math.max(0, top - margin)
      else if (bottom > flick.contentY + flick.height - margin) flick.contentY = Math.min(maxY, bottom + margin - flick.height)
    })
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    flick.contentY = 0
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: checkDependencies()

  Process {
    id: sweep
    command: ["sh", "-c", Model.dependencySweep()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.sweepFinished(text)
    }
  }

  // Monet's own dependencies, what can be reviewed, and the review in
  // progress, from one short run of the app's command.
  Process {
    id: overviewProc
    command: ["monet", "overview", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.overviewFinished(text)
    }
  }

  Timer {
    interval: 20000
    running: root.refreshing
    onTriggered: {
      overviewProc.running = false
      root.refreshing = false
      root.problem = "Monet took too long to answer. Try again."
    }
  }

  // Monet rewrites this small file whenever a review changes state, which
  // keeps the bar icon current without asking Monet anything.
  FileView {
    id: statusFile
    path: Model.statusPath(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"))
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.statusSeen = true
      root.monetStatus = Model.parseJson(statusFile.text())
    }
  }

  // The file does not exist until Monet has been used once, and a file that
  // is not there cannot be watched. Look for it now and then until it shows up.
  Timer {
    interval: 5000
    repeat: true
    running: !root.statusSeen
    onTriggered: statusFile.reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.blocked ? "Monet needs something installed" : Model.tooltip(root.monetStatus)
    iconComponent: Component {
      Item {
        MonetIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barForeground
          dotVisible: root.blocked || root.barState === "agent"
          dotColor: root.blocked ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.openMonet([])
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
      onActivateRequested: root.activateTarget(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) {
        if (key === "r" || key === "R") root.refresh()
        else if (key === "o" || key === "O") root.openMonet([])
        else if (key === "s" || key === "S") root.openMonet(Model.PICK_SCREEN_ARGUMENTS)
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Monet"
            meta: "Design review"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              MonetIcon {
                iconSize: Style.font.display
                color: root.foreground
              }
            }
          }

          // What is missing, and how to get it.
          NeedList {
            title: "MISSING"
            items: root.missing.filter(function(item) { return item.required })
          }

          NeedList {
            title: "NOT SET UP YET"
            items: root.missing.filter(function(item) { return !item.required })
          }

          PanelSeparator {
            visible: root.missing.length > 0 && root.installed
            foreground: root.foreground
          }

          // The review in progress, one press away.
          Column {
            visible: root.summary !== null
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "KEEP GOING"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            PickRow {
              width: parent.width
              targetIndex: 0
              title: root.summary ? root.summary.project : ""
              detail: root.summary ? root.summary.detail : ""
              badge: "Continue"
            }
          }

          Column {
            visible: root.installed
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "REVIEW A SITE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              textFormat: Text.PlainText
              visible: root.siteRows.length === 0
              width: parent.width
              text: root.problem !== "" ? root.problem
                : root.refreshing ? "Looking for sites on this computer..."
                : "Nothing to review yet. Start your site, or open Monet and choose a folder."
              color: root.problem !== "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Column {
              visible: root.siteRows.length > 0
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.siteRows
                PickRow {
                  required property var modelData
                  required property int index
                  width: column.width
                  targetIndex: root.firstSiteTarget + index
                  title: modelData.title
                  detail: modelData.detail
                  badge: modelData.badge
                  faded: !modelData.ready
                }
              }
            }
          }

          PanelSeparator {
            visible: root.installed
            foreground: root.foreground
          }

          // Anything on screen can be reviewed: Omarchy's own picker chooses
          // the window or the area, and Monet opens with the picture.
          PickRow {
            visible: root.installed
            width: parent.width
            targetIndex: Model.targetIndex(root.targets, "screen")
            title: "Review what is on screen"
            detail: "Click a window or drag over an area"
          }

          PickRow {
            visible: root.installed
            width: parent.width
            targetIndex: Model.targetIndex(root.targets, "open")
            title: "Open Monet"
            detail: "Review any site, page or folder"
          }

          Text {
            textFormat: Text.PlainText
            visible: root.installed
            width: parent.width
            text: "Enter reviews · S picks on screen · R looks again · O opens Monet"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // A short list of things to install or set up, each with how to do it.
  component NeedList: Column {
    id: needList

    property string title: ""
    property var items: []

    visible: items.length > 0
    width: parent ? parent.width : 0
    spacing: Style.space(8)

    PanelSectionHeader {
      text: needList.title
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Repeater {
      model: needList.items
      Column {
        id: need
        required property var modelData
        width: needList.width
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: need.modelData.label
          color: need.modelData.required ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: text !== ""
          text: need.modelData.fix
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  // One thing the cursor can land on: a site, the review in progress, or
  // opening Monet. Hover moves the same cursor the arrow keys do, so there is
  // only ever one highlight.
  component PickRow: CursorSurface {
    id: pickRow

    property int targetIndex: -1
    property string title: ""
    property string detail: ""
    property string badge: ""
    property bool faded: false

    hasCursor: root.cursorActive && root.cursorIndex === targetIndex
    foreground: root.foreground
    implicitHeight: rowBody.implicitHeight + Style.spacing.rowPaddingX
    onHasCursorChanged: if (hasCursor) root.scrollItemIntoView(pickRow)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(pickRow.targetIndex)
      onClicked: root.activateTarget(pickRow.targetIndex)
    }

    RowLayout {
      id: rowBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: pickRow.title
          color: root.foreground
          opacity: pickRow.faded ? 0.7 : 1
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: text !== ""
          text: pickRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: text !== ""
        text: pickRow.badge
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
