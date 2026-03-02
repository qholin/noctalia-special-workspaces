import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    visible: CompositorService.isHyprland

    z: 999

    readonly property string mainIcon: cfg.mainIcon ?? defaults.mainIcon
    readonly property string expandDirection: cfg.expandDirection ?? defaults.expandDirection
    readonly property bool isVertical: expandDirection === "up" || expandDirection === "down"

    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
    readonly property real pillSize: capsuleHeight * 0.90
    readonly property real iconSize: Style.toOdd(pillSize * 0.48)
    readonly property real pillSpacing: Style.marginXS

    readonly property var configuredWorkspaces: {
        var list = cfg.workspaces ?? defaults.workspaces;
        if (!list || !Array.isArray(list)) list = defaults.workspaces || [];
        var result = [];
        for (var i = 0; i < list.length; i++) {
            result.push({
                "name": "special:" + list[i].name,
                "shortName": list[i].name,
                "icon": list[i].icon
            });
        }
        return result;
    }

    // --- State tracking ---

    property var activeWorkspaceNames: ({})
    property string internalActiveSpecial: ""

    readonly property bool hasActiveWorkspaces: Object.keys(activeWorkspaceNames).length > 0
    readonly property bool isOnSpecial: internalActiveSpecial !== ""
    property bool manuallyExpanded: false
    readonly property bool expanded: isOnSpecial || manuallyExpanded

    onIsOnSpecialChanged: {
        if (!isOnSpecial) manuallyExpanded = false;
    }

    // --- Hyprland integration ---

    function updateActiveWorkspaces() {
        if (!CompositorService.isHyprland) {
            activeWorkspaceNames = {};
            return;
        }
        try {
            var names = {};
            var ws = Hyprland.workspaces.values;
            for (var i = 0; i < ws.length; i++) {
                if (ws[i].name && ws[i].name.startsWith("special:")) {
                    names[ws[i].name] = true;
                }
            }
            activeWorkspaceNames = names;
        } catch (e) {
            activeWorkspaceNames = {};
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                const dataParts = event.data.split(",");
                const wsName = dataParts[0];
                if (wsName && wsName.startsWith("special:")) {
                    root.internalActiveSpecial = wsName;
                } else {
                    root.internalActiveSpecial = "";
                }
            }
            if (["createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2"].includes(event.name)) {
                updateActiveWorkspaces();
            }
        }
    }

    Component.onCompleted: {
        if (CompositorService.isHyprland) {
            updateActiveWorkspaces();
            try {
                const initial = Hyprland.focusedMonitor?.specialWorkspace?.name;
                if (initial && initial.startsWith("special:")) {
                    root.internalActiveSpecial = initial;
                }
            } catch(e) {}
        }
    }

    // --- Sizing ---

    readonly property int totalPills: expanded ? 1 + configuredWorkspaces.length : 1

    readonly property real fullSize: pillSize * totalPills + pillSpacing * Math.max(0, totalPills - 1)

    implicitWidth: isVertical ? capsuleHeight : fullSize
    implicitHeight: isVertical ? fullSize : capsuleHeight

    // Background Blocker
    Rectangle {
        anchors.fill: parent
        radius: Style.radiusM
        color: root.expanded ? Color.mSurface : "transparent"

        Behavior on color { ColorAnimation { duration: 200 } }
        z: -1
    }

    Behavior on implicitWidth { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }

    opacity: hasActiveWorkspaces ? 1.0 : 0.3
    Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutQuad } }

    clip: false

    // --- Components ---

    component MainButton: Rectangle {
        width: root.pillSize
        height: root.pillSize
        radius: Style.radiusM
        color: Color.mPrimary

        NIcon {
            icon: root.mainIcon
            pointSize: root.iconSize
            applyUiScale: false
            color: Color.mOnPrimary
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, root, screen);
                    return;
                }
                if (root.expanded) {
                    if (root.isOnSpecial) {
                        Hyprland.dispatch("togglespecialworkspace");
                    }
                    root.manuallyExpanded = false;
                } else if (root.hasActiveWorkspaces) {
                    root.manuallyExpanded = true;
                }
            }
        }
    }

    component WorkspacePill: Rectangle {
        id: wsPill
        required property var modelData

        width: root.pillSize
        height: root.pillSize
        radius: Style.radiusM
        color: Color.mPrimary

        readonly property bool isActive: root.activeWorkspaceNames[modelData.name] === true
        readonly property bool isFocused: root.internalActiveSpecial === modelData.name

        opacity: isActive ? 1.0 : 0.2
        border.color: isFocused ? Color.mOnPrimary : "transparent"
        border.width: 2

        NIcon {
            icon: wsPill.modelData.icon
            pointSize: root.iconSize
            applyUiScale: false
            color: Color.mOnPrimary
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Hyprland.dispatch(`togglespecialworkspace ${wsPill.modelData.shortName}`);
            }
        }

        Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
    }

    // --- Context Menu ---

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Widget Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: function (action) {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            }
        }
    }

    // --- Layouts ---

    Row {
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: root.pillSpacing
        layoutDirection: root.expandDirection === "left" ? Qt.RightToLeft : Qt.LeftToRight
        MainButton {}
        Repeater {
            model: root.configuredWorkspaces
            WorkspacePill { visible: root.expanded }
        }
    }

    Column {
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: root.pillSpacing

        Repeater {
            model: root.configuredWorkspaces
            WorkspacePill { visible: root.expanded && root.expandDirection === "up" }
        }
        MainButton {}
        Repeater {
            model: root.configuredWorkspaces
            WorkspacePill { visible: root.expanded && root.expandDirection === "down" }
        }
    }
}
