/* BloomGit.qml — Collect git identity for .gitconfig */
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.calamares.ui 1.0

Page {
    id: gitPage

    property bool isNextEnabled: true  // all fields optional

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 480)
        spacing: 16

        Label {
            text: qsTr("Git Identity (optional)")
            font.bold: true
            font.pixelSize: 18
        }

        Label {
            text: qsTr("Set your name and email for git commits. You can change these later with git config.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        TextField {
            id: nameField
            placeholderText: qsTr("Full name (e.g. Alice Smith)")
            Layout.fillWidth: true
            onTextChanged: Calamares.Global.storage.insert("bloom_git_name", text)
        }

        TextField {
            id: emailField
            placeholderText: qsTr("Email address")
            Layout.fillWidth: true
            onTextChanged: Calamares.Global.storage.insert("bloom_git_email", text)
        }
    }
}
