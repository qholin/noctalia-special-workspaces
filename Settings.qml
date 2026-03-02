import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string mainIcon: cfg.mainIcon ?? defaults.mainIcon
    property string expandDirection: cfg.expandDirection ?? defaults.expandDirection

    // Local mutable copy for editing
    property var workspaces: []
    property int workspacesRevision: 0

    spacing: Style.marginL

    Component.onCompleted: {
        loadWorkspaces();
    }

    function loadWorkspaces() {
        var src = cfg.workspaces ?? defaults.workspaces;
        if (!src || !Array.isArray(src)) src = [];
        var copy = [];
        for (var i = 0; i < src.length; i++) {
            copy.push({ "name": src[i].name || "", "icon": src[i].icon || "star" });
        }
        workspaces = copy;
        workspacesRevision++;
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("SpecialWorkspaces", "Cannot save settings: pluginApi is null");
            return;
        }

        var valid = [];
        for (var i = 0; i < workspaces.length; i++) {
            var name = workspaces[i].name.trim();
            if (name !== "") {
                valid.push({ "name": name, "icon": workspaces[i].icon || "star" });
            }
        }

        pluginApi.pluginSettings.mainIcon = root.mainIcon;
        pluginApi.pluginSettings.expandDirection = root.expandDirection;
        pluginApi.pluginSettings.workspaces = valid;
        pluginApi.saveSettings();
        Logger.i("SpecialWorkspaces", "Settings saved");
    }

    NText {
        text: "Special Workspaces"
        pointSize: Style.fontSizeL
        font.bold: true
    }

    NText {
        text: "Configure Hyprland special workspaces shown in the bar widget."
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    RowLayout {
        spacing: Style.marginM

        NIcon {
            Layout.alignment: Qt.AlignVCenter
            icon: root.mainIcon
            pointSize: Style.fontSizeXL
        }

        NTextInput {
            id: mainIconInput
            Layout.preferredWidth: 140
            label: "Main Button Icon"
            text: root.mainIcon
            onTextChanged: {
                if (text !== root.mainIcon) {
                    root.mainIcon = text;
                }
            }
        }

        NIconButton {
            icon: "search"
            tooltipText: "Browse icons"
            onClicked: {
                mainIconPicker.open();
            }
        }
    }

    NIconPicker {
        id: mainIconPicker
        initialIcon: root.mainIcon
        onIconSelected: function (iconName) {
            root.mainIcon = iconName;
            mainIconInput.text = iconName;
        }
    }

    NComboBox {
        Layout.fillWidth: true
        label: "Expand Direction"
        description: "Which direction the workspace pills expand from the main button."
        model: [
            { "key": "down", "name": "Down" },
            { "key": "up", "name": "Up" },
            { "key": "right", "name": "Right" },
            { "key": "left", "name": "Left" }
        ]
        currentKey: root.expandDirection
        onSelected: function (key) {
            root.expandDirection = key;
        }
        defaultValue: "down"
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Workspace list
    Repeater {
        model: {
            void root.workspacesRevision;
            return root.workspaces.length;
        }

        delegate: RowLayout {
            id: wsRow
            required property int index

            Layout.fillWidth: true
            spacing: Style.marginM

            readonly property var ws: {
                void root.workspacesRevision;
                return index >= 0 && index < root.workspaces.length ? root.workspaces[index] : null;
            }

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: wsRow.ws ? wsRow.ws.icon : "star"
                pointSize: Style.fontSizeXL
            }

            NTextInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 140
                placeholderText: "Workspace name"
                text: wsRow.ws ? wsRow.ws.name : ""
                onTextChanged: {
                    if (wsRow.ws && text !== wsRow.ws.name) {
                        root.workspaces[wsRow.index].name = text;
                    }
                }
            }

            NTextInput {
                id: iconInput
                Layout.preferredWidth: 120
                placeholderText: "Icon name"
                text: wsRow.ws ? wsRow.ws.icon : ""
                onTextChanged: {
                    if (wsRow.ws && text !== wsRow.ws.icon) {
                        root.workspaces[wsRow.index].icon = text;
                        root.workspacesRevision++;
                    }
                }

                // Re-sync text when icon is changed externally (e.g., via icon picker)
                Connections {
                    target: root
                    function onWorkspacesRevisionChanged() {
                        if (wsRow.ws && iconInput.text !== wsRow.ws.icon) {
                            iconInput.text = wsRow.ws.icon;
                        }
                    }
                }
            }

            NIconButton {
                icon: "search"
                tooltipText: "Browse icons"
                onClicked: {
                    iconPicker.activeIndex = wsRow.index;
                    iconPicker.initialIcon = wsRow.ws ? wsRow.ws.icon : "star";
                    iconPicker.query = wsRow.ws ? wsRow.ws.icon : "";
                    iconPicker.open();
                }
            }

            NIconButton {
                icon: "trash"
                tooltipText: "Remove workspace"
                onClicked: {
                    root.workspaces.splice(wsRow.index, 1);
                    root.workspacesRevision++;
                }
            }
        }
    }

    NIconPicker {
        id: iconPicker
        property int activeIndex: -1
        initialIcon: "star"
        onIconSelected: function (iconName) {
            if (activeIndex >= 0 && activeIndex < root.workspaces.length) {
                root.workspaces[activeIndex].icon = iconName;
                root.workspacesRevision++;
            }
        }
    }

    NButton {
        text: "Add Workspace"
        icon: "plus"
        onClicked: {
            root.workspaces.push({ "name": "", "icon": "star" });
            root.workspacesRevision++;
        }
    }
}
