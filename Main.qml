import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import QtCore
import TwainDesk
import "qml"
import "qml/components"
import "js/Helper.js" as Helper

CWindow {
    id: root

    width: 500
    height: 500
    minimumWidth: 400
    minimumHeight: 450
    title: Application.displayName
    preventClosing: Twain.scanning
    preventClosingReason: qsTr("Wait for scan to finish.")
    cornerPreference: Worker.getGlobalSettings("UI/windowPreference", CornerPreference.Round)
    padding: 10

    titleBar.content: RowLayout {
        // wrong as titleBar.content is RowLayout use Layout instead
        // anchors.verticalCenter: parent.verticalCenter // dont use anchors
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter

        // inline Component
        component CSeparator: Rectangle { width: 1; Layout.preferredHeight: Math.round(parent.height / 1.05); color: AppSettings.border }

        CButton {
            id: clearSettingsBtn
            property Dialog confirmDialog: null
            Layout.preferredHeight: 20
            Layout.preferredWidth: height
            display: AbstractButton.IconOnly
            tooltipVisible: true
            tooltipText: qsTr("Clear all settings and restore defaults (takes effect on next launch)")
            icon.source: "qrc:/assets/restore_24px.png"

            function clearAllSavedSettings(): void { Worker.clearGlobalSettings() }
            function destroyConfirmDialog(): void { if(confirmDialog) confirmDialog.destroy() }

            onReleased: {
                if(!confirmDialog) {
                    const __component = Qt.createComponent("QtQuick.Controls.FluentWinUI3", "Dialog", Component.PreferSynchronous, root.contentItem)
                    if(__component.status === Component.Ready) {
                        confirmDialog = __component.createObject(root.contentItem, {
                                                                     "anchors.centerIn": root.contentItem,
                                                                     title: qsTr("Are you sure") + "\n" + qsTr("You want to clear all settings ?"),
                                                                     "palette.window": AppSettings.background,
                                                                     modal: true,
                                                                     dim: true,
                                                                     closePolicy: Dialog.CloseOnEscape,
                                                                     visible: true,
                                                                     standardButtons: Dialog.Yes | Dialog.No,
                                                                     popupType: Popup.Item
                                                                 }) as Dialog; // Safe cast from QObject* to Dialog*
                        if(confirmDialog) {
                            // When connecting outside Component.onCompleted: disconnect first
                            // to prevent duplicate connections and multiple signal emissions.
                            confirmDialog.accepted.disconnect(clearAllSavedSettings)
                            confirmDialog.accepted.connect(clearAllSavedSettings)
                            confirmDialog.closed.disconnect(destroyConfirmDialog)
                            confirmDialog.closed.connect(destroyConfirmDialog)
                        }
                    } else {
                        console.log("Failed to create Component: ", __component.errorString())
                    }
                } else {
                    // there is no chance we get here, but just in case
                    confirmDialog.open()
                }
            }
        }

        CSeparator { }

        CComboBox {
            implicitHeight: Math.max(22, Math.min(Math.round(parent.height / 1.1), 30))
            maxWidth: 70
            model: ListModel { // order most match CornerPreference
                ListElement { name: qsTr("Default"); value: CornerPreference.Default }
                ListElement { name: qsTr("Don't Round"); value: CornerPreference.DoNotRound }
                ListElement { name: qsTr("Round"); value: CornerPreference.Round }
                ListElement { name: qsTr("Round Small"); value: CornerPreference.RoundSmall }
            }
            textRole: "name"
            valueRole: "value"
            tooltipVisible: true
            tooltipText: qsTr("Change window corner style")
            currentIndex: model?.get(root.cornerPreference)?.[valueRole] || 0
            popupPos: CComboBox.PopupPos.Bottom


            onActivated: {
                Worker.setGlobalSettings("UI/windowPreference", currentValue)
                root.cornerPreference = currentValue
            }
        }

        CSeparator { }

        CComboBox {
            id: languageBox
            property int prevValue: Worker.getGlobalSettings("UI/language", AppSettings.Language.EN)
            implicitHeight: Math.max(22, Math.min(Math.round(parent.height / 1.1), 30))
            maxWidth: 70
            textRole: "name"
            valueRole: "value"
            currentIndex: AppSettings.language
            font.capitalization: Font.MixedCase
            tooltipVisible: enabled
            tooltipText: qsTr("Change the language.")
            popupPos: CComboBox.PopupPos.Bottom

            ProgressBar {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: parent.width / 1.1
                implicitHeight: 1
                indeterminate: true
                visible: !languageBox.enabled
            }

            model: ListModel {
                ListElement { name: "English"; value: AppSettings.Language.EN }
                ListElement { name: "عربي"; value: AppSettings.Language.AR }
            }

            onActivated: {
                if(prevValue === currentValue) return
                languageBox.enabled = false
                prevValue = currentValue
                Helper.createTimer(this, 10, ()=> {
                                       Worker.clearCache()
                                       AppSettings.setLanguage(currentValue)
                                   })
                // delay 2sec before user can change lang again
                Helper.createTimer(this, 2000, ()=> languageBox.enabled = true )
            }
        }

        CSeparator { }

        CComboBox {
            id: themeBox
            implicitHeight: Math.max(22, Math.min(Math.round(parent.height / 1.1), 30))
            maxWidth: 70

            textRole: "name"
            valueRole: "value"
            enabled: !AppSettings.isHighContrast
            tooltipVisible: ((themeBox.hovered && themeBox.enabled) || (themeBox.hovered && AppSettings.isHighContrast)) && !themeBox.popup?.opened
            tooltipText: (themeBox.hovered && themeBox.enabled) ? qsTr("Change theme.") : qsTr("Changing the theme is not supported in High Contrast mode.")
            currentIndex: AppSettings.theme
            popupPos: CComboBox.PopupPos.Bottom

            toolTipMap: {
                0: qsTr("Follow operating system theme.")
            }

            iconsMap: {
                0: "qrc:/assets/operating-system_24px.png",
                1: "qrc:/assets/light-mode_24px.png",
                2: "qrc:/assets/night-mode_24px.png"
            }

            model: ListModel {
                ListElement { name: qsTr("System"); value: AppSettings.Theme.System }
                ListElement { name: qsTr("Light"); value: AppSettings.Theme.Light }
                ListElement { name: qsTr("Dark"); value: AppSettings.Theme.Dark }
            }

            onActivated: {
                AppSettings.setTheme(currentValue)
            }
        }

        CSeparator { }

    }

    Component.onCompleted: {
        if(uiSettings.splitView)
            splitView.restoreState(uiSettings.splitView)
    }

    Component.onDestruction: {
        const savedState = splitView.saveState()
        if(savedState)
            uiSettings.splitView = savedState
    }

    Settings {
        id: uiSettings
        category: "UI"
        property var splitView
        property alias directScan: directCheck.checked
    }

    Connections {
        target: Twain

        function onImageReady(path): void {
            pagesView.append(path)
        }

        function onPageProgress(current): void {
            progressLabel.text = qsTr("Scanning Page (%1)").arg(current)
        }

        function onErrorOccurred(error, isFinal): void {
            statusView.append({ status: { title: Twain.twainLastError(), text: error, icon: "qrc:/assets/error_24px.png", color: Qt.alpha("red", 0.9), time: Qt.formatTime(new Date(), "hh:mm:ss") } })

            if(isFinal) {
                scanBtn.enabled = false
            }
        }

        function onInfoAvailable(info): void {
            statusView.append({ status: { title: "", text: info, icon: "qrc:/assets/info_24px.png", color: Qt.alpha("green", 0.8), time: Qt.formatTime(new Date(), "hh:mm:ss")  } })
        }

        function onWarn(msg): void {
            statusView.append({ status: { title: "", text: msg, icon: "qrc:/assets/warning_24px.png", color: "#ba8400", time: Qt.formatTime(new Date(), "hh:mm:ss")  } })
        }

        function onScanFinished(): void {
            progressLabel.text = ""
        }

        function onDeviceEvent(event): void {
            statusView.append({ status: { title: qsTr("Event"), text: event, icon: "qrc:/assets/warning_24px.png", color: "#ba8400", time: Qt.formatTime(new Date(), "hh:mm:ss")  } })
        }
    }

    SplitView {
        id: splitView
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: optionsView.top
            bottomMargin: 5
        }
        // changes the content from (left to right, like english) to (right to left, like arabic)
        LayoutMirroring.enabled: AppSettings.isRTL
        // also make children inherit right to left if arabic selected
        LayoutMirroring.childrenInherit: true // this is false by default
        smooth: AppSettings.quality
        antialiasing: AppSettings.quality
        spacing: 15
        orientation: Qt.Vertical

        handle: Rectangle {
            id: handleDelegate
            implicitWidth: 3
            implicitHeight: 3
            radius: 10
            color: SplitHandle.pressed ? Qt.alpha(AppSettings.hovered, 0.6)
                                       : (SplitHandle.hovered ? AppSettings.hovered : "transparent")

            containmentMask: Item {
                x: (handleDelegate.width - width) / 2
                width: splitView.width
                height: 10
            }
        }

        ColumnLayout {
            SplitView.minimumWidth: 100
            SplitView.minimumHeight: pagesView.visible ? 140 : 50
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            antialiasing: AppSettings.quality

            PagesView {
                id: pagesView
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                CButton {
                    id: syncFolderBtn
                    implicitWidth: implicitContentWidth + leftPadding + rightPadding
                    implicitHeight: 24
                    spacing: 3
                    leftPadding: 4
                    rightPadding: 4
                    topPadding: 6
                    bottomPadding: 6
                    text: qsTr("Sync")
                    icon.source: "qrc:/assets/refresh_24px.png"
                    icon.width: 16
                    icon.height: 16
                    tooltipVisible: true
                    tooltipText: qsTr("Synchronize all files from the configured scans location.")
                    enabled: !loading

                    onReleased: {
                        syncFolderBtn.loading = true
                        Helper.createTimer(this, 2000, ()=> syncFolderBtn.loading = false )
                        Twain.synchronizeScansLocation()
                    }
                }

                ToolSeparator { Layout.preferredHeight: 40 }

                CheckBox {
                    id: directCheck
                    implicitWidth: implicitContentWidth + leftPadding + rightPadding
                    leftPadding: 2
                    rightPadding: 2
                    spacing: 5
                    text: qsTr("Direct")
                    enabled: !Twain.scanning
                    checkState: uiSettings.value("directScan", false) ? Qt.Checked : Qt.Unchecked

                    CToolTip {
                        visible: directCheck.hovered
                        text: qsTr("Enable direct scanning without showing the scanner UI")
                        delay: 200
                    }
                }

                CButton {
                    id: scanBtn
                    text: Twain.scanning ? qsTr("Scanning...") : Twain.isCanceling ? qsTr("Canceling...") : qsTr("Start Scan")
                    enabled: !Twain.scanning && !Twain.isCanceling && Twain.hasSources
                    tooltipVisible: true
                    tooltipText: !enabled && !Twain.hasSources ? qsTr("Please select a source bellow.") : qsTr("Start Scanning Files.")
                    loading: Twain.scanning

                    onReleased: {
                        Twain.startScan(directCheck.checked)
                    }
                }

                CButton {
                    id: cancelBtn
                    text: qsTr("Cancel")
                    enabled: Twain.scanning && !Twain.isCanceling && directCheck.checked
                    tooltipVisible: true
                    tooltipText: qsTr("Cancel Scanning Files.")
                    loading: Twain.isCanceling

                    onReleased: {
                        Twain.cancelScan()
                    }
                }

                CButton {
                    text: qsTr("Clear Photo's")
                    visible: pagesView.hasPages
                    tooltipVisible: true
                    tooltipText: qsTr("Clear All Scanned Files (from app only)")
                    onReleased: {
                        pagesView.clear()
                    }
                }
            }

            Label {
                id: progressLabel
                Layout.alignment: Qt.AlignHCenter
                padding: 3
                text: ""
                visible: text !== ""

                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 40
                    radius: 4
                    color: AppSettings.isHighContrast ? AppSettings.background : AppSettings.hovered
                    border.width: AppSettings.isHighContrast ? 1 : 0
                    border.color: AppSettings.border
                }
            }
        }

        StatusView {
            id: statusView
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 270
        }

    }

    OptionsView {
        id: optionsView
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

    }
}
