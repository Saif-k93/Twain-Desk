import QtQuick
import QtQuick.Controls
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import QtCore
import TwainDesk
import "components"
import "../js/Helper.js" as Helper

CContainer {
    id: control

    title: qsTr("Settings")

    Component.onCompleted: {
        const __savedLocation = optionsSettings.value("scansLocation", "")
        if(__savedLocation.toString() !== "")
            Twain.scansLocation = __savedLocation
    }

    resources: [
        Settings {
            id: optionsSettings
            category: "Options"
        }
    ]

    Flow {
        id: flow
        // changes the content from (left to right, like english) to (right to left, like arabic)
        LayoutMirroring.enabled: AppSettings.isRTL
        // also make children inherit right to left if arabic selected
        LayoutMirroring.childrenInherit: true // this is false by default
        flow: Flow.LeftToRight
        layoutDirection: Qt.LeftToRight
        spacing: 5
        antialiasing: AppSettings.quality

        move: Transition {
            enabled: AppSettings.quality
            NumberAnimation {
                properties: "x,y"
                easing.type: Easing.OutBack
                duration: 100
            }
        }

        populate: Transition {
            enabled: AppSettings.quality
            NumberAnimation {
                properties: "x,y"
                easing.type: Easing.OutBack
                duration: 500
            }
        }

        component CSeparator: ToolSeparator {
            id: cSeparator
            topPadding: 3
            bottomPadding: 3
            antialiasing: AppSettings.quality
            contentItem: Rectangle {
                implicitWidth: cSeparator.vertical ? 1 : 24
                implicitHeight: cSeparator.vertical ? 24 : 1
                color: AppSettings.isLight ? "#33000000" : "#33FFFFFF"
            }
        }

        FolderDialog {
            id: folderDialog
            currentFolder: "file:///" + Twain.scansLocation

            onAccepted: {
                const location = selectedFolder.toString().replace("file:///", "")
                Twain.scansLocation = location
                optionsSettings.setValue("scansLocation", location)
            }
        }


        RowLayout {
            id: locationRow
            height: 25
            spacing: 5
            antialiasing: AppSettings.quality

            Label {
                Layout.fillHeight: true
                verticalAlignment: Qt.AlignVCenter
                textFormat: Text.RichText
                text: "<a href='" + Twain.scansLocation + "' style='color: " + AppSettings.link + ";'>" + qsTr("Scans Location") + "</a>"
                linkColor: AppSettings.link
                color: AppSettings.highlighted
                opacity: locationHov.hovered ? locationTap.pressed ? 0.5 : 0.8 : 1
                onLinkActivated: link => Qt.openUrlExternally(link)

                HoverHandler { id: locationHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: locationTap }

                CToolTip {
                    visible: locationHov.hovered
                    text: qsTr("Click to open") + ` (${Twain.scansLocation})`
                    delay: 150
                }
            }

            CButton {
                implicitHeight: 22
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("Change")
                display: AbstractButton.TextOnly
                tooltipVisible: true
                tooltipText: qsTr("Change scans location")

                onReleased: {
                    folderDialog.open()
                }
            }
        }

        CSeparator { }

        RowLayout {
            id: sourcesRow
            height: 25
            spacing: 5

            Text {
                height: 25
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Select a source")
                color: palette.text
                fontSizeMode: Text.Fit
            }

            CComboBox {
                id: scannersBox
                Layout.fillHeight: true
                model: Twain.scannerModel
                textRole: "productName"
                valueRole: "id"
                enabled: !Twain.scanning && !Twain.isCanceling && Twain.hasSources
                showMsg: !Twain.hasSources
                msgClosable: false
                msgType: CComboBox.Warning
                msgText: qsTr("There is no source available, make sure you installed the scanner driver.")
                msgMaxWidth: 400

                Component.onCompleted: {
                    Twain.refreshSourcesList();
                    const savedId = Number(optionsSettings.value("selectedScannerId", -1));
                    if (savedId && savedId !== -1) {
                        for (let i = 0; i < Twain.scannerModel.rowCount(); i++) {
                            const currentId = Twain.scannerModel.getData(i, valueRole)
                            if(currentId === savedId) {
                                scannersBox.currentIndex = i;
                                break;
                            }
                        }
                    } else {
                        scannersBox.currentIndex = 0;
                    }
                    Twain.selectSource(currentValue)
                    optionsSettings.setValue("selectedScannerId", currentValue)
                }

                onActivated: {
                    Twain.selectSource(currentValue)
                    optionsSettings.setValue("selectedScannerId", currentValue)
                }

                delegate: CItemDelegate {
                    required property var model
                    required property int index
                    readonly property string moreInfo:
                        qsTr("Manufacturer") + `: ${model['manufacturer']}\n` +
                        qsTr("Product Family") + `: ${model['productFamily']}\n` +
                        qsTr("Protocol Major") + `: ${model['protocolMajor']}\n` +
                        qsTr("Protocol Minor") + `: ${model['protocolMinor']}\n` +
                        qsTr("Supported Groups") + `: ${model['supportedGroups']}\n` +
                        qsTr("Version Info") + `: ${model['versionInfo']}`

                    property bool isCurrentItem: scannersBox.currentIndex === index
                    property bool isHighlighted: scannersBox.highlightedIndex === index

                    width: ListView.view.width
                    text: model[scannersBox.textRole]
                    hoverEnabled: !ListView.view.moving
                    highlighted: isCurrentItem
                    font.bold: isCurrentItem
                    font.capitalization: scannersBox.font.capitalization
                    tooltipText: moreInfo
                    tooltipVisible: true

                    onReleased: {
                        scannersBox.currentIndex = index
                        scannersBox.activated(index)
                        scannersBox.popup?.close()
                        scannersBox.forceActiveFocus()
                    }
                }
            }

            CButton {
                id: refreshBtn
                property bool isRefreshing: false
                implicitWidth: implicitContentWidth + leftPadding + rightPadding
                implicitHeight: width
                Layout.alignment: Qt.AlignVCenter
                leftPadding: 2
                rightPadding: 2
                topPadding: 4
                bottomPadding: 4
                tooltipVisible: true
                tooltipText: qsTr("Refresh Sources List.")
                display: AbstractButton.IconOnly
                icon.source: "qrc:/assets/refresh_24px.png"
                enabled: !Twain.scanning && !Twain.isCanceling
                loading: isRefreshing

                onReleased: {
                    if(isRefreshing) return
                    isRefreshing = true
                    Helper.createTimer(control, 2000, ()=> refreshBtn.isRefreshing = false)
                    Twain.refreshSourcesList()
                }
            }
        }

        CSeparator { }

        RowLayout {
            id: modeRow
            height: 25
            spacing: 5
            antialiasing: AppSettings.quality

            Text {
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Scan Mode")
                color: palette.text
                fontSizeMode: Text.Fit
            }

            CComboBox {
                id: scanModeBox
                Layout.fillHeight: true
                textRole: "name"
                valueRole: "__action"
                enabled: !Twain.scanning && !Twain.isCanceling && Twain.hasSources
                antialiasing: AppSettings.quality
                toolTipMap: {
                    0: qsTr("Use feeder if loaded.")
                }

                model: ListModel {
                    ListElement { name: qsTr("Auto"); __action: Twain.Auto }
                    ListElement { name: qsTr("Feeder"); __action: Twain.Feeder }
                    ListElement { name: qsTr("Flatbed"); __action: Twain.Flatbed }
                }

                Component.onCompleted: {
                    const savedAction = Number(optionsSettings.value("scanMode", -1));
                    if (savedAction && savedAction !== -1) {
                        for (let i = 0; i < scanModeBox.count; i++) {
                            if (scanModeBox.model.get(i)[scanModeBox.valueRole] === savedAction) {
                                scanModeBox.currentIndex = i;
                                break;
                            }
                        }
                    } else {
                        scanModeBox.currentIndex = 0;
                    }
                    Twain.scanMode = currentValue
                    optionsSettings.setValue("scanMode", currentValue)
                }

                onActivated: {
                    Twain.scanMode = currentValue
                    optionsSettings.setValue("scanMode", currentValue)
                }
            }
        }

        CSeparator { }

        RowLayout {
            id: dpiRow
            height: 25
            spacing: 5
            antialiasing: AppSettings.quality

            Text {
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                text: qsTr("DPI")
                color: palette.text
                fontSizeMode: Text.Fit

                HoverHandler { id: dpiHov; cursorShape: Qt.WhatsThisCursor }
                CToolTip {
                    visible: dpiHov.hovered && !dpiBox.popup?.opened
                    text: qsTr("DPI (dots per inch) controls how detailed the scan is.") + "\n" + qsTr("Higher DPI means sharper images but larger files and slower scanning.") + "\n" + qsTr("300 DPI is best for most documents.")
                    delay: 300
                }
            }

            CComboBox {
                id: dpiBox
                Layout.fillHeight: true
                textRole: "value"
                valueRole: textRole
                enabled: !Twain.scanning && !Twain.isCanceling && Twain.hasSources

                toolTipMap: {
                    8: qsTr("Using 1200 DPI creates very large files and increases scan time.") + "\n" + qsTr("For normal documents (300–600) DPI gives good visible quality with much smaller size.")
                }
                iconsMap: {
                    4: "qrc:/assets/star_24px.png"
                }

                model: ListModel {
                    ListElement { value: 75 }
                    ListElement { value: 150 }
                    ListElement { value: 200 }
                    ListElement { value: 240 }
                    ListElement { value: 300 }
                    ListElement { value: 400 }
                    ListElement { value: 500 }
                    ListElement { value: 600 }
                    ListElement { value: 1200 }
                }

                Component.onCompleted: {
                    const savedAction = Number(optionsSettings.value("dpi", -1));
                    if (savedAction && savedAction !== -1) {
                        for (let i = 0; i < dpiBox.count; i++) {
                            if (dpiBox.model.get(i)[dpiBox.valueRole] === savedAction) {
                                dpiBox.currentIndex = i;
                                break;
                            }
                        }
                    } else {
                        dpiBox.currentIndex = 4;
                    }
                    Twain.dpi = currentValue
                    optionsSettings.setValue("dpi", currentValue)
                }

                onActivated: {
                    Twain.dpi = currentValue
                    optionsSettings.setValue("dpi", currentValue)
                }
            }

        }

        CSeparator { }

        RowLayout {
            id: colorModeRow
            height: 25
            spacing: 5
            antialiasing: AppSettings.quality

            Text {
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Color Mode")
                color: palette.text
                fontSizeMode: Text.Fit
            }

            CComboBox {
                id: colorModeBox
                Layout.fillHeight: true
                textRole: "name"
                valueRole: "value"
                enabled: !Twain.scanning && !Twain.isCanceling && Twain.hasSources

                model: ListModel {
                    ListElement { name: qsTr("Auto Detect"); value: Twain.AutoDetect }
                    ListElement { name: qsTr("Color"); value: Twain.Color }
                    ListElement { name: qsTr("Grayscale"); value: Twain.Grayscale }
                    ListElement { name: qsTr("Black And White"); value: Twain.BlackAndWhite }
                }

                Component.onCompleted: {
                    const savedAction = Number(optionsSettings.value("colorMode", -1));
                    if (savedAction && savedAction !== -1) {
                        for (let i = 0; i < colorModeBox.count; i++) {
                            if (colorModeBox.model.get(i)[colorModeBox.valueRole] === savedAction) {
                                colorModeBox.currentIndex = i;
                                break;
                            }
                        }
                    } else {
                        colorModeBox.currentIndex = 0;
                    }
                    Twain.colorMode = currentValue
                    optionsSettings.setValue("colorMode", currentValue)
                }

                onActivated: {
                    Twain.colorMode = currentValue
                    optionsSettings.setValue("colorMode", currentValue)
                }
            }

        }

        CSeparator { }

        RowLayout {
            id: renderModeRow
            height: 25
            spacing: 5
            antialiasing: AppSettings.quality

            Text {
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Render Mode")
                color: palette.text
                fontSizeMode: Text.Fit
            }

            CComboBox {
                id: renderModeBox
                Layout.fillHeight: true
                textRole: "name"
                valueRole: "value"
                currentIndex: AppSettings.renderMode
                msgClosable: true
                msgType: CComboBox.Warning
                msgMaxWidth: 250
                msgText: qsTr("Please restart the application for the new rendering mode to take effect.")


                model: ListModel {
                    ListElement { name: qsTr("Quality"); value: AppSettings.Quality }
                    ListElement { name: qsTr("Performance"); value: AppSettings.Performance }
                }

                Component.onCompleted: {
                    optionsSettings.setValue("renderMode", currentValue)
                }

                onActivated: {
                    const isSmaeValue = (AppSettings.renderMode === currentValue)
                    optionsSettings.setValue("renderMode", currentValue)
                    if(!isSmaeValue) {
                        renderModeBox.showMsg = true
                    }
                }
            }

        }
    }
}


