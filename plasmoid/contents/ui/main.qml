import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    // ── State ─────────────────────────────────────────────────────────────────
    property real   sessionPct:   0.0
    property real   weeklyPct:    0.0
    property string sessionLabel: "–%"
    property string weeklyLabel:  "–%"
    property string resetLabel:   "Checking..."
    property string sessionResetLabel: ""
    property string weeklyResetLabel:  ""
    property bool   dataError:    false

    // Derive $HOME from this QML file's own path.
    // Qt.resolvedUrl(".") returns something like:
    //   file:///home/tyler/.local/share/plasma/plasmoids/com.github.cut.claudeusagetracker/contents/ui/
    // Split on /.local/ and take everything before it.
    readonly property string homeDir: {
        var p = Qt.resolvedUrl(".").toString()
        p = p.replace(/^file:\/\//, "")
        var idx = p.indexOf("/.local/")
        return idx > 0 ? p.substring(0, idx) : ""
    }
    readonly property string usageFile: "file://" + homeDir + "/.local/share/cut/usage.json"

    // ── Colours ───────────────────────────────────────────────────────────────
    readonly property color barBg:      Qt.rgba(1, 1, 1, 0.10)
    readonly property color barSession: sessionPct > 0.9 ? "#ff5f5f"
                                      : sessionPct > 0.7 ? "#ffaa44"
                                      :                    "#8fff8f"
    readonly property color barWeekly:  weeklyPct  > 0.9 ? "#ff5f5f"
                                      : weeklyPct  > 0.7 ? "#ffaa44"
                                      :                    "#23a8fa"
    readonly property color textColor:  Kirigami.Theme.textColor
    readonly property color dimColor:   Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)

    // ── Helpers ───────────────────────────────────────────────────────────────
    function fmtCountdown(isoStr) {
        var ms = new Date(isoStr) - new Date()
        if (ms <= 0) return "resetting soon"
        var h = Math.floor(ms / 3600000)
        var m = Math.floor((ms % 3600000) / 60000)
        return h + "h " + m + "m"
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
                    root.sessionPct   = obj.session_pct / 100.0
                    root.weeklyPct    = obj.weekly_pct  / 100.0
                    root.sessionLabel = Math.round(obj.session_pct) + "%"
                    root.weeklyLabel  = Math.round(obj.weekly_pct)  + "%"
                    root.resetLabel   = obj.reset_label || ""
                    root.sessionResetLabel = obj.session_reset ? "Resets in " + root.fmtCountdown(obj.session_reset) : ""
                    root.weeklyResetLabel  = obj.weekly_reset  ? "Resets in " + root.fmtCountdown(obj.weekly_reset)  : ""
                    root.dataError    = false
                } else {
                    root.dataError  = true
                    root.resetLabel = obj.error || "Waiting for data..."
                }
            } catch(e) {
                root.dataError  = true
                root.resetLabel = "Could not parse usage.json"
            }
        }
        xhr.send()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.loadData()
    }

    // ── Compact view (panel bar) ──────────────────────────────────────────────
    compactRepresentation: Item {
        Layout.preferredWidth: 132
        Layout.fillHeight: true

        ColumnLayout {
            id: compactCol
            anchors.centerIn: parent
            spacing: 4

            // Session row: 5H [bar] %
            RowLayout {
                spacing: 4
                Text {
                    text: "5H"
                    color: root.dimColor
                    font.pixelSize: 12; font.bold: true; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    Layout.fillWidth: true
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
                    font.pixelSize: 12; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Weekly row: 7D [bar] %
            RowLayout {
                spacing: 4
                Text {
                    text: "7D"
                    color: root.dimColor
                    font.pixelSize: 12; font.bold: true; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    Layout.fillWidth: true
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
                    font.pixelSize: 12; font.family: "Noto Serif"
                    Layout.alignment: Qt.AlignVCenter
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
        Layout.preferredWidth: 220
        Layout.preferredHeight: 230
        Layout.maximumWidth: 220
        Layout.maximumHeight: 230

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
                Text {
                    text: root.sessionResetLabel
                    color: root.dimColor
                    font.pixelSize: 14; font.family: "Noto Serif"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
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
                Text {
                    text: root.weeklyResetLabel
                    color: root.dimColor
                    font.pixelSize: 14; font.family: "Noto Serif"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
            }

            Item { Layout.preferredHeight: 10 }

            Button {
                text: "Refresh"
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 10
                onClicked: root.loadData()
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
