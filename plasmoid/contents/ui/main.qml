import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    preferredRepresentation: Plasmoid.location === 0 ? fullRepresentation : compactRepresentation

    // 0 = NoBackground, 1 = DefaultBackground (standard Plasma values).
    // On the desktop we draw our own background rectangle, so suppress Plasma's frame.
    // On the panel the popup chrome handles it, so leave it as default.
    Plasmoid.backgroundHints: Plasmoid.location === 0 ? 0 : 1

    // ── Settings ──────────────────────────────────────────────────────────────
    property string colorSessionNormal: Plasmoid.configuration.colorSessionNormal
    property string colorWeeklyNormal:  Plasmoid.configuration.colorWeeklyNormal
    property string colorWarning:       Plasmoid.configuration.colorWarning
    property string colorCritical:      Plasmoid.configuration.colorCritical
    property string colorText:          Plasmoid.configuration.colorText

    // ── State ─────────────────────────────────────────────────────────────────
    property real   sessionPct:   0.0
    property real   weeklyPct:    0.0
    property string sessionLabel: "–%"
    property string weeklyLabel:  "–%"
    property string sessionReset: ""
    property string weeklyReset:  ""
    property string sessionResetLabel: ""
    property string weeklyResetLabel:  ""
    property bool   hasData:      false
    property bool   dataError:    false
    property bool   rateLimited:  false
    property string errorMsg:     ""

    // ── Paths ─────────────────────────────────────────────────────────────────
    readonly property string homeDir: {
        var p = Qt.resolvedUrl(".").toString()
        p = p.replace(/^file:\/\//, "")
        var idx = p.indexOf("/.local/")
        return idx > 0 ? p.substring(0, idx) : ""
    }
    readonly property string usageFile:     "file://" + homeDir + "/.local/share/cut/usage.json"
    readonly property string refreshScript: homeDir + "/.local/share/cut/cut-refresh.py"

    // ── Executable data source ────────────────────────────────────────────────
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { disconnectSource(source) }
    }

    function triggerBackendRefresh() {
        // Path is quoted to handle spaces in home directory paths
        executable.connectSource("python3 '" + root.refreshScript + "'")
        refreshDelay.restart()
    }

    Timer { id: refreshDelay; interval: 2000; repeat: false; onTriggered: root.loadData() }

    Timer {
        id: errorRetryTimer
        interval: 5000; repeat: true
        running: !root.hasData && (root.dataError || root.rateLimited)
        onTriggered: root.loadData()
    }

    // ── Colours ───────────────────────────────────────────────────────────────
    readonly property color barBg: Qt.rgba(1, 1, 1, 0.10)

    function barColor(pct, normalColor) {
        if (pct > 0.9) return colorCritical
        if (pct > 0.7) return colorWarning
        return normalColor
    }

    readonly property color barSession: barColor(sessionPct, colorSessionNormal)
    readonly property color barWeekly:  barColor(weeklyPct,  colorWeeklyNormal)
    readonly property color dimColor:   colorText

    // ── Countdown helpers ─────────────────────────────────────────────────────
    function fmtCompactSession(isoStr) {
        if (!isoStr) return ""
        var ms = new Date(isoStr) - new Date()
        if (ms <= 0) return "~0m"
        var totalMins = Math.floor(ms / 60000)
        if (totalMins <= 60) return totalMins + "m"
        return Math.floor(totalMins / 60) + "h"
    }

    function fmtCompactWeekly(isoStr) {
        if (!isoStr) return ""
        var ms = new Date(isoStr) - new Date()
        if (ms <= 0) return "~0m"
        var totalMins = Math.floor(ms / 60000)
        if (totalMins <= 60) return totalMins + "m"
        var totalHours = Math.floor(totalMins / 60)
        if (totalHours <= 24) return totalHours + "h"
        return Math.floor(totalHours / 24) + "d"
    }

    function fmtFull(isoStr) {
        if (!isoStr) return ""
        var ms = new Date(isoStr) - new Date()
        if (ms <= 0) return "Resetting soon"
        var h = Math.floor(ms / 3600000)
        var m = Math.floor((ms % 3600000) / 60000)
        return "Resets in " + h + "h " + m + "m"
    }

    // ── Data loading ──────────────────────────────────────────────────────────
    function loadData() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.usageFile, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            try {
                var obj = JSON.parse(xhr.responseText)
                if (obj.session_pct !== undefined) {
                    root.sessionPct        = obj.session_pct / 100.0
                    root.weeklyPct         = obj.weekly_pct  / 100.0
                    root.sessionLabel      = Math.round(obj.session_pct) + "%"
                    root.weeklyLabel       = Math.round(obj.weekly_pct)  + "%"
                    root.sessionReset      = obj.session_reset || ""
                    root.weeklyReset       = obj.weekly_reset  || ""
                    root.sessionResetLabel = fmtFull(obj.session_reset)
                    root.weeklyResetLabel  = fmtFull(obj.weekly_reset)
                    root.hasData           = true
                    root.dataError         = false
                    root.rateLimited       = false
                    root.errorMsg          = ""
                } else {
                    root.dataError   = true
                    root.rateLimited = (obj.error_type === "rate_limited")
                    root.errorMsg    = obj.error || "Waiting for data..."
                }
            } catch(e) {
                root.dataError   = true
                root.rateLimited = false
                root.errorMsg    = "Could not parse usage.json"
            }
        }
        xhr.send()
    }

    // ── Timers ────────────────────────────────────────────────────────────────
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.loadData()
    }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
            root.sessionResetLabel = root.fmtFull(root.sessionReset)
            root.weeklyResetLabel  = root.fmtFull(root.weeklyReset)
        }
    }

    // ── Compact view ──────────────────────────────────────────────────────────
    compactRepresentation: Item {
        // 26 (timer) + 4 + 80 (bar) + 4 + 26 (pct) = 140 content + 8 padding = 148
        Layout.preferredWidth: 148
        Layout.fillHeight: true

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            // Session row: [timer] [bar] [%]
            RowLayout {
                spacing: 4
                Text {
                    text: root.fmtCompactSession(root.sessionReset)
                    color: root.dimColor
                    font.pixelSize: 12; font.bold: true; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                }
                Item {
                    implicitWidth: 80; height: 15
                    Rectangle { anchors.fill: parent; radius: 4; color: root.barBg }
                    Rectangle {
                        width: parent.width * Math.min(root.sessionPct, 1.0)
                        height: parent.height; radius: 4; color: root.barSession
                        Behavior on width { SmoothedAnimation { duration: 500 } }
                    }
                }
                Text {
                    text: root.sessionLabel
                    color: root.dimColor
                    font.pixelSize: 12; font.bold: true; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26
                    horizontalAlignment: root.sessionLabel.length <= 2 ? Text.AlignHCenter : Text.AlignLeft
                }
            }

            // Weekly row: [timer] [bar] [%]
            RowLayout {
                spacing: 4
                Text {
                    text: root.fmtCompactWeekly(root.weeklyReset)
                    color: root.dimColor
                    font.pixelSize: 12; font.bold: true; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                }
                Item {
                    implicitWidth: 80; height: 15
                    Rectangle { anchors.fill: parent; radius: 4; color: root.barBg }
                    Rectangle {
                        width: parent.width * Math.min(root.weeklyPct, 1.0)
                        height: parent.height; radius: 4; color: root.barWeekly
                        Behavior on width { SmoothedAnimation { duration: 500 } }
                    }
                }
                Text {
                    text: root.weeklyLabel
                    color: root.dimColor
                    font.pixelSize: 12; font.bold: true; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26
                    horizontalAlignment: root.weeklyLabel.length <= 2 ? Text.AlignHCenter : Text.AlignLeft
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full / popup view ─────────────────────────────────────────────────────
    fullRepresentation: Item {
        Layout.preferredWidth:  220
        Layout.preferredHeight: 230

        // Solid opaque background for the desktop widget.
        // Not visible on the panel; Plasma's popup chrome handles that.
        Rectangle {
            anchors.fill: parent
            visible:      Plasmoid.location === 0
            color:        "#1e1e2e"
            radius:       8
        }

        ColumnLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 4

            Item { Layout.fillHeight: true }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "5-Hour Session"; color: root.dimColor; font.pixelSize: 14; font.bold: true; font.family: "Noto Serif" }
                    Item { Layout.fillWidth: true }
                    Text { text: root.sessionLabel; color: root.barSession; font.pixelSize: 14; font.bold: true; font.family: "Noto Serif" }
                }
                Item {
                    Layout.fillWidth: true; height: 11
                    Rectangle { anchors.fill: parent; radius: 5; color: root.barBg }
                    Rectangle {
                        width: parent.width * Math.min(root.sessionPct, 1.0)
                        height: parent.height; radius: 5; color: root.barSession
                        Behavior on width { SmoothedAnimation { duration: 500 } }
                    }
                }
                Text { text: root.sessionResetLabel; color: root.dimColor; font.pixelSize: 14; font.family: "Noto Serif"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 20 }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "7-Day Weekly"; color: root.dimColor; font.pixelSize: 14; font.bold: true; font.family: "Noto Serif" }
                    Item { Layout.fillWidth: true }
                    Text { text: root.weeklyLabel; color: root.barWeekly; font.pixelSize: 14; font.bold: true; font.family: "Noto Serif" }
                }
                Item {
                    Layout.fillWidth: true; height: 11
                    Rectangle { anchors.fill: parent; radius: 5; color: root.barBg }
                    Rectangle {
                        width: parent.width * Math.min(root.weeklyPct, 1.0)
                        height: parent.height; radius: 5; color: root.barWeekly
                        Behavior on width { SmoothedAnimation { duration: 500 } }
                    }
                }
                Text { text: root.weeklyResetLabel; color: root.dimColor; font.pixelSize: 14; font.family: "Noto Serif"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
            }

            Item { Layout.preferredHeight: 10 }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                sourceComponent: (!root.hasData && (root.rateLimited || root.dataError))
                    ? errorComponent : refreshComponent
            }

            Component {
                id: refreshComponent
                Button { text: "Refresh"; font.pixelSize: 10; onClicked: root.triggerBackendRefresh() }
            }

            Component {
                id: errorComponent
                Item {
                    Text {
                        anchors { left: parent.left; right: parent.right }
                        text: root.rateLimited
                              ? "Rate limited by Anthropic. Try again in ~15 minutes."
                              : root.errorMsg
                        color: "#ff5f5f"
                        font.pixelSize: 11; font.family: "Noto Serif"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Item { Layout.preferredHeight: 6 }
        }
    }
}
