/* BloomMatrix.qml — Collect Matrix chat username */
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.calamares.ui 1.0

Page {
    id: matrixPage

    property bool isNextEnabled: true  // optional

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 480)
        spacing: 16

        Label {
            text: qsTr("Matrix Username (optional)")
            font.bold: true
            font.pixelSize: 18
        }

        Label {
            text: qsTr("Choose a username for your private Matrix chat account. "
                       "This is your handle on the local homeserver (e.g. @alice:bloom). "
                       "Leave blank to set this up later.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Label { text: qsTr("Username") }

        TextField {
            id: usernameField
            placeholderText: qsTr("alice")
            Layout.fillWidth: true
            validator: RegularExpressionValidator {
                regularExpression: /^[a-z][a-z0-9._-]*$|^$/
            }
            onTextChanged: Calamares.Global.storage.insert("bloom_matrix_username", text)
        }

        Label {
            text: qsTr("Lowercase letters, numbers, '.', '_', '-' only. Cannot be changed later.")
            font.pixelSize: 11
            color: "gray"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
