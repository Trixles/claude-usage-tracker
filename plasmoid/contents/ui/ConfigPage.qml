import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: configPage

    // These must match the entry names in main.xml exactly.
    // Plasma binds cfg_* properties automatically to the config schema.
    property alias cfg_colorSessionNormal: sessionField.text
    property alias cfg_colorWeeklyNormal:  weeklyField.text
    property alias cfg_colorWarning:       warningField.text
    property alias cfg_colorCritical:      criticalField.text
    property alias cfg_colorText:          textField.text

    function isValidHex(s) {
        return /^#[0-9a-fA-F]{6}$/.test(s)
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Bar Colors" }

    // ── Session bar ───────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Session bar (normal):"
        spacing: 8
        TextField {
            id: sessionField
            Layout.preferredWidth: 90
            font.family: "monospace"
            placeholderText: "#rrggbb"
        }
        Rectangle {
            width: 24; height: 24; radius: 4
            color: isValidHex(sessionField.text) ? sessionField.text : "#440000"
            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
        }
    }

    // ── Weekly bar ────────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Weekly bar (normal):"
        spacing: 8
        TextField {
            id: weeklyField
            Layout.preferredWidth: 90
            font.family: "monospace"
            placeholderText: "#rrggbb"
        }
        Rectangle {
            width: 24; height: 24; radius: 4
            color: isValidHex(weeklyField.text) ? weeklyField.text : "#440000"
            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
        }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Warning Colors" }

    // ── Warning (>70%) ────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Warning color (>70%):"
        spacing: 8
        TextField {
            id: warningField
            Layout.preferredWidth: 90
            font.family: "monospace"
            placeholderText: "#rrggbb"
        }
        Rectangle {
            width: 24; height: 24; radius: 4
            color: isValidHex(warningField.text) ? warningField.text : "#440000"
            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
        }
    }

    // ── Critical (>90%) ───────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Critical color (>90%):"
        spacing: 8
        TextField {
            id: criticalField
            Layout.preferredWidth: 90
            font.family: "monospace"
            placeholderText: "#rrggbb"
        }
        Rectangle {
            width: 24; height: 24; radius: 4
            color: isValidHex(criticalField.text) ? criticalField.text : "#440000"
            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
        }
    }

    // ── Reset button ──────────────────────────────────────────────────────────
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Text Color" }

    // ── Text color ─────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Text color:"
        spacing: 8
        TextField {
            id: textField
            Layout.preferredWidth: 90
            font.family: "monospace"
            placeholderText: "#rrggbb"
        }
        Rectangle {
            width: 24; height: 24; radius: 4
            color: isValidHex(textField.text) ? textField.text : "#440000"
            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
        }
    }

    Item { Kirigami.FormData.isSection: true }

    Button {
        text: "Reset to defaults"
        onClicked: {
            cfg_colorSessionNormal = "#8fff8f"
            cfg_colorWeeklyNormal  = "#23a8fa"
            cfg_colorWarning       = "#ffaa44"
            cfg_colorCritical      = "#ff5f5f"
            cfg_colorText          = "#ffffff"
        }
    }
}
