import QtQuick
import QtQuick.Controls
import Quickshell
import "../"

Item {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────
    property bool loading:  true
    property int  selIndex: -1
    property string query:  ""

    readonly property var apps: DesktopEntries.applications.values

    readonly property var filtered: {
        if (loading) return []

        var q = query.toLowerCase().trim()
        if (q === "") return apps
        return apps.filter(function(a) {
            return a.name.toLowerCase().indexOf(q) !== -1
        })
    }

    onVisibleChanged: {
        if (!visible) return
        root.loading   = true
        searchInput.text = ""
        root.query     = ""
        root.selIndex  = -1
        delayTimer.restart()
        focusTimer.restart()
    }

    Timer {
        id: delayTimer
        interval: 150
        onTriggered: {
            root.loading  = false
            root.selIndex = root.filtered.length > 0 ? 0 : -1
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: searchInput.forceActiveFocus()
    }

    // ── Launch ────────────────────────────────────────────────────────────────
    function launch(entry) {
        entry.execute()
        Popups.dashboardOpen = false
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 8

        // App list container
        Item {
            width:  parent.width
            height: parent.height - searchBar.height - parent.spacing

            // Loading state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: root.loading

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰣪"; font.pixelSize: 32
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.3)

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 1500
                        running: root.loading
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "Initializing..."
                    color:          Qt.rgba(1,1,1,0.25)
                    font.pixelSize: 13
                }
            }

            // Empty / no results state
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: !root.loading && root.filtered.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.query !== "" ? "󰩄" : "󱗃"
                    font.pixelSize: 28
                    color:          Qt.rgba(1,1,1,0.18)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.query !== "" ? "No results" : "No apps found"
                    color:          Qt.rgba(1,1,1,0.25)
                    font.pixelSize: 13
                }
            }

            // App list
            ListView {
                id: appList
                anchors.fill: parent
                visible: !root.loading && root.filtered.length > 0

                // Reverted directly back to the pure array (instant updates, no glitching)
                model: root.filtered

                clip:    true
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth:  3
                        implicitHeight: 40
                        radius:         1.5
                        color:          Qt.rgba(1, 1, 1, 0.22)
                    }
                    background: Item {}
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width:  appList.width - 8
                    height: 46
                    radius: 9

                    readonly property bool isSel: root.selIndex === index

                    color: isSel
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                           : rowH.hovered ? Qt.rgba(1,1,1,0.06) : "transparent"
                    border.color: isSel
                                  ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                                  : rowH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                    border.width: 1

                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors {
                            left:   parent.left;  leftMargin:  12
                            right:  parent.right; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 12

                        // App icon
                        Item {
                            width: 28; height: 28
                            anchors.verticalCenter: parent.verticalCenter

                            Loader {
                                id: iconLoader
                                anchors.fill: parent
                                asynchronous: true
                                active: true

                                sourceComponent: Image {
                                    source: {
                                        var s = modelData.icon;
                                        // Tier 1 Fallback: Ask Quickshell for the generic Linux application icon
                                        if (!s || s.trim() === "") return "image://icon/application-x-executable";
                                        if (s.startsWith("/")) return "file://" + s;
                                        return "image://icon/" + s;
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    sourceSize.width: 28
                                    sourceSize.height: 28

                                    onStatusChanged: {
                                        if (status === Image.Error || status === Image.Null) {
                                            Qt.callLater(function() { iconLoader.active = false; });
                                        }
                                    }
                                }
                            }

                            // Tier 2 Fallback: Nerd Font Icon
                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                visible: !iconLoader.active || (iconLoader.item && iconLoader.item.status !== Image.Ready)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰀻" // Generic Nerd Font App Grid Icon
                                    font.pixelSize: 16
                                    color: Theme.active
                                }
                            }
                        }

                        // App name
                        Text {
                            width: parent.width - 28 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.name
                            font.pixelSize: 13
                            color:          isSel ? Theme.active : Theme.text
                            elide:          Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }

                    HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered:    root.selIndex = index
                        onClicked:    root.launch(modelData)
                    }
                }
            }
        }

        // Search bar
        Rectangle {
            id: searchBar
            width: parent.width; height: 44; radius: 12
            color: Qt.rgba(1,1,1,0.06)
            border.color: searchInput.activeFocus
                          ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50)
                          : Qt.rgba(1,1,1,0.12)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"; font.pixelSize: 16
                    color: searchInput.activeFocus
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
                           : Qt.rgba(1,1,1,0.35)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Item {
                    width: parent.width - 26 - parent.spacing
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:    "Search apps…"
                        color:   Qt.rgba(1,1,1,0.22)
                        font.pixelSize: 13
                        visible: searchInput.text === ""
                    }

                    TextInput {
                        id: searchInput
                        anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
                        verticalAlignment: TextInput.AlignVCenter
                        color:          Theme.text
                        font.pixelSize: 13
                        selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                        clip: true

                        // Debouncer removed: Instant 1:1 keystroke filtering
                        onTextChanged: {
                            root.query = text
                            root.selIndex = root.filtered.length > 0 ? 0 : -1
                            if (root.filtered.length > 0)
                                appList.positionViewAtIndex(0, ListView.Beginning)
                        }

                        Keys.onUpPressed: {
                            if (root.selIndex > 0) {
                                root.selIndex--
                                appList.positionViewAtIndex(root.selIndex, ListView.Contain)
                            }
                        }

                        Keys.onDownPressed: {
                            if (root.selIndex < root.filtered.length - 1) {
                                root.selIndex++
                                appList.positionViewAtIndex(root.selIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: {
                            if (root.selIndex >= 0 && root.selIndex < root.filtered.length)
                                root.launch(root.filtered[root.selIndex])
                        }

                        Keys.onEscapePressed: {
                            if (text !== "") {
                                text = ""
                            } else {
                                Popups.dashboardOpen = false
                            }
                        }
                    }
                }
            }
        }
    }
}
