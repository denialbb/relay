import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "models"
import "services"

Panel {
    id: root

    moduleName: "denial.beeper-relay"
    ipcTarget: "denial.beeper-relay"
    manageIpc: false

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Component.onCompleted: {
        badgeService.initialize();
    }

    BeeperService {
        id: badgeService
        pollInterval: 15000
        previewsEnabled: false
    }

    TriageModel {
        id: badgeModel
        service: badgeService
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰍡"
        tooltipText: "Relay (Beeper)"
        active: badgeModel.unreadTotal > 0
        onPressed: function(buttonCode) {
            root.toggle();
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        padding: 0
        focusTarget: drawer
        contentWidth: panel.fittedContentWidth(Style.space(400))
        contentHeight: panel.cappedContentHeight(Style.space(drawer.drawerHeight))

        TriageDrawer {
            id: drawer
            anchors.fill: parent
            open: root.opened
            onRequestClose: function() {
                root.close();
            }
        }
    }
}
