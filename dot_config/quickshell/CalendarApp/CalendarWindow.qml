import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.CustomTheme

// Month calendar that drops down below the bar, horizontally centered.
// X11/i3: an OverlayWindow (i3 floating window, closes on focus loss) instead
// of a layer-shell overlay; the slide is animated inside the window rather
// than via the panel margin.
OverlayWindow {
    id: root
    title: "xcloud-calendar"

    implicitWidth: 380
    implicitHeight: 380

    // Horizontally centered, just below the bar (the Hyprland version sat
    // at a 67px top margin under a 52px reserved band; the i3 dock is 60px).
    placement: function (out, w, h) {
        return { "x": out.x + (out.width - w) / 2, "y": out.y + 55 }
    }

    // --- ESCAPE KEY LISTENER ---
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isOpen) {
                root.isOpen = false
            }
        }
    }

    // --- ANIMATION LOGIC (Vertical Slide) ---
    onIsOpenChanged: {
        if (isOpen) {
            // Auto-refresh "Today" if the date changed while Quickshell was running
            let now = new Date();
            if (now.getDate() !== todayDate || now.getMonth() !== todayMonth) {
                todayDate = now.getDate()
                todayMonth = now.getMonth()
                todayYear = now.getFullYear()

                currentMonth = todayMonth
                currentYear = todayYear
                updateCalendar(currentYear, currentMonth)
            }
        }
    }

    // Keep the window mapped until the hide animation has finished.
    keepMapped: slideAnim.running

    // Vertical offset of the panel inside the window: 0 when open, slid up
    // out of the window when closed.
    property real slideOffset: isOpen ? 0 : -implicitHeight

    Behavior on slideOffset {
        NumberAnimation {
            id: slideAnim
            duration: 350
            easing.type: Easing.OutQuint
        }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { root.isOpen = !root.isOpen }
        function open(): void { root.isOpen = true }   
        function close(): void { root.isOpen = false }
        function isOpen(): bool { return root.isOpen }
    }

    // --- REUSABLE COMPONENTS ---
    component ActionIcon: Button {
        property string iconTxt: ""
        property string iconSrc: ""
        implicitWidth: 28
        implicitHeight: 28
        background: Rectangle { color: "transparent" }
        contentItem: Item {
            Text {
                anchors.centerIn: parent
                text: iconTxt
                visible: iconSrc === ""
                color: Theme.on_surface
                font.family: "monospace"
                font.pixelSize: 18
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            Image {
                anchors.centerIn: parent
                source: iconSrc
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                visible: iconSrc !== ""
                fillMode: Image.PreserveAspectFit
                layer.enabled: iconSrc !== ""
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: Theme.on_surface
                }
            }
        }
    }

    // Styled xCloud Button for the "Today" action
    component XCloudButton: Button {
        background: Rectangle {
            color: "transparent"
            border.color: Theme.primary
            border.width: 1
            radius: 8
        }
        contentItem: Text {
            text: parent.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.on_surface
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            padding: 4
            leftPadding: 10
            rightPadding: 10
        }
    }

    // --- CALENDAR LOGIC & DATA ---
    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property var dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    
    property int todayDate: new Date().getDate()
    property int todayMonth: new Date().getMonth()
    property int todayYear: new Date().getFullYear()

    ListModel { id: dayModel }
    ListModel { id: weekModel }

    Component.onCompleted: updateCalendar(currentYear, currentMonth)

    function prevMonth() {
        if (currentMonth === 0) {
            currentMonth = 11;
            currentYear--;
        } else {
            currentMonth--;
        }
        updateCalendar(currentYear, currentMonth);
    }

    function nextMonth() {
        if (currentMonth === 11) {
            currentMonth = 0;
            currentYear++;
        } else {
            currentMonth++;
        }
        updateCalendar(currentYear, currentMonth);
    }

    function updateCalendar(year, month) {
        dayModel.clear()
        weekModel.clear()

        let firstDay = new Date(year, month, 1)
        let startingDayOfWeek = firstDay.getDay() 
        let startCell = startingDayOfWeek === 0 ? 6 : startingDayOfWeek - 1

        let daysInMonth = new Date(year, month + 1, 0).getDate()
        let daysInPrevMonth = new Date(year, month, 0).getDate()

        for (let row = 0; row < 6; row++) {
            let dateInRow = new Date(year, month, 1 + (row * 7) - startCell)
            let d = new Date(Date.UTC(dateInRow.getFullYear(), dateInRow.getMonth(), dateInRow.getDate()));
            d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7));
            let yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
            let weekNo = Math.ceil(( ( (d - yearStart) / 86400000) + 1)/7);
            
            weekModel.append({ weekNumber: weekNo })
        }

        for (let i = 0; i < 42; i++) {
            if (i < startCell) {
                dayModel.append({ day: daysInPrevMonth - startCell + i + 1, isCurrentMonth: false, isToday: false })
            } else if (i >= startCell && i < startCell + daysInMonth) {
                let dayNum = i - startCell + 1
                let isTod = (dayNum === todayDate && month === todayMonth && year === todayYear)
                dayModel.append({ day: dayNum, isCurrentMonth: true, isToday: isTod })
            } else {
                dayModel.append({ day: i - startCell - daysInMonth + 1, isCurrentMonth: false, isToday: false })
            }
        }
    }

    // ==========================================
    // MAIN PANEL BACKGROUND
    // ==========================================
    Item {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 20 + root.slideOffset
        anchors.bottomMargin: 20 - root.slideOffset

        Shadow {
            id: shadow
            anchors.fill: mainBgRect
            radius: mainBgRect.radius
            blur: 15
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.4)
        }

        Rectangle {
            id: mainBgRect
            anchors.fill: parent
            radius: 10
            opacity: 0.95 // Only the background is transparent

            // Gradient border (outer)
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.on_primary }
            }

            // Background fill (inner), inset by the border thickness
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: parent.radius - anchors.margins
                color: Theme.background
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // --- HEADER: MONTH NAVIGATION & TODAY BUTTON ---
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    ActionIcon {
                        iconSrc: "../shared/icons/chevron-left.svg"
                        onClicked: prevMonth()
                    }
                    
                    Text {
                        Layout.preferredWidth: 120 
                        text: monthNames[currentMonth] + " " + currentYear
                        color: Theme.on_surface
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    ActionIcon {
                        iconSrc: "../shared/icons/chevron-right.svg"
                        onClicked: nextMonth()
                    }
                }

                // The Hyprland version has a "⤢" button here that opens the
                // calendar app from ~/.config/xcloud/settings/calendar
                // (gnome-calendar); the Debian rice ships no calendar app, so
                // it is left out.

                XCloudButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Today"

                    opacity: (currentMonth !== todayMonth || currentYear !== todayYear) ? 1.0 : 0.0
                    enabled: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                    onClicked: {
                        currentMonth = todayMonth;
                        currentYear = todayYear;
                        updateCalendar(currentYear, currentMonth);
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline_variant }

            // --- CALENDAR BODY ---
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 15

                ColumnLayout {
                    Layout.fillHeight: true
                    spacing: 5
                    
                    Text {
                        Layout.fillWidth: true
                        text: "Wk"
                        color: Theme.on_background
                        opacity: 0.5
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.bottomMargin: 5
                    }

                    Repeater {
                        model: weekModel
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: model.weekNumber
                            color: Theme.on_surface
                            opacity: 0.7
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.outline_variant }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: root.dayNames
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Theme.on_surface
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        columns: 7
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        rowSpacing: 5
                        columnSpacing: 5
                        
                        Repeater {
                            model: dayModel
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: width / 2 
                                color: model.isToday ? Theme.primary : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: model.day
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: model.isToday
                                    color: model.isToday ? Theme.background : Theme.on_background
                                    opacity: (model.isCurrentMonth || model.isToday) ? 1.0 : 0.3
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}