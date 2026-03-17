/* BloomServices.qml — Select optional services */
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.calamares.ui 1.0

Page {
    id: servicesPage

    property bool isNextEnabled: true

    function updateStorage() {
        var selected = []
        if (fluffychatCheck.checked) selected.push("fluffychat")
        if (dufsCheck.checked) selected.push("dufs")
        Calamares.Global.storage.insert("bloom_services", selected.join(","))
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 480)
        spacing: 16

        Label {
            text: qsTr("Optional Services")
            font.bold: true
            font.pixelSize: 18
        }

        Label {
            text: qsTr("These services are installed on first boot. All are optional and can be added later.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        CheckBox {
            id: fluffychatCheck
            text: qsTr("Bloom Web Chat (FluffyChat) — Matrix web client over NetBird")
            onCheckedChanged: servicesPage.updateStorage()
        }

        CheckBox {
            id: dufsCheck
            text: qsTr("dufs file server — access files from any device via WebDAV")
            onCheckedChanged: servicesPage.updateStorage()
        }
    }
}
