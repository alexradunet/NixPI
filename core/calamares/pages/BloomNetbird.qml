/* BloomNetbird.qml — Collect NetBird setup key */
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.calamares.ui 1.0

Page {
    id: netbirdPage

    property bool isNextEnabled: true  // optional

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 480)
        spacing: 16

        Label {
            text: qsTr("NetBird VPN (optional)")
            font.bold: true
            font.pixelSize: 18
        }

        Label {
            text: qsTr("NetBird creates a secure private mesh so you can access Bloom from anywhere. "
                       "Get a setup key from app.netbird.io → Setup Keys. "
                       "Leave blank to connect manually later.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Label { text: qsTr("Setup Key") }

        TextField {
            id: keyField
            placeholderText: qsTr("Paste your NetBird setup key")
            echoMode: TextInput.Password
            Layout.fillWidth: true
            onTextChanged: Calamares.Global.storage.insert("bloom_netbird_key", text)
        }
    }
}
