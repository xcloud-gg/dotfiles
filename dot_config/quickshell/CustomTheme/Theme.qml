pragma Singleton
import QtQuick
import Quickshell 
import Quickshell.Io 

QtObject { 
    id: root
    
    // Static properties
    readonly property string fontFamily: "Fira Sans Semibold"
    
    // Dynamic color properties. Defaults are the shipped palette
    // (~/.config/xcloud/colors/colors.json) so nothing flashes a different
    // palette before that file has been read.
    property color background: "#0c1609"
    property color error: "#ffb4ab"
    property color error_container: "#93000a"
    property color inverse_on_surface: "#283324"
    property color inverse_primary: "#026e00"
    property color inverse_surface: "#d9e7d0"
    property color on_background: "#d9e7d0"
    property color on_error: "#690005"
    property color on_error_container: "#ffdad6"
    property color on_primary: "#013a00"
    property color on_primary_container: "#015000"
    property color on_primary_fixed: "#002200"
    property color on_primary_fixed_variant: "#015300"
    property color on_secondary: "#013a00"
    property color on_secondary_container: "#000000"
    property color on_secondary_fixed: "#002200"
    property color on_secondary_fixed_variant: "#015300"
    property color on_surface: "#d9e7d0"
    property color on_surface_variant: "#b9ccaf"
    property color on_tertiary: "#003825"
    property color on_tertiary_container: "#004f36"
    property color on_tertiary_fixed: "#002114"
    property color on_tertiary_fixed_variant: "#005138"
    property color outline: "#84967c"
    property color outline_variant: "#3b4b35"
    property color primary: "#eaffde"
    property color primary_container: "#00ff00"
    property color primary_fixed: "#77ff61"
    property color primary_fixed_dim: "#02e600"
    property color scrim: "#000000"
    property color secondary: "#68e054"
    property color secondary_container: "#2ca720"
    property color secondary_fixed: "#84fd6d"
    property color secondary_fixed_dim: "#68e054"
    property color shadow: "#000000"
    property color source_color: "#00ff00"
    property color surface: "#0c1609"
    property color surface_bright: "#313c2c"
    property color surface_container: "#182214"
    property color surface_container_high: "#222d1e"
    property color surface_container_highest: "#2d3828"
    property color surface_container_low: "#141e10"
    property color surface_container_lowest: "#071105"
    property color surface_dim: "#0c1609"
    property color surface_tint: "#02e600"
    property color surface_variant: "#3b4b35"
    property color tertiary: "#e5ffef"
    property color tertiary_container: "#00fab3"
    property color tertiary_fixed: "#43ffbb"
    property color tertiary_fixed_dim: "#00e1a1"

    property var themeReader: Process {
        id: reader
        command: ["cat", Quickshell.env("HOME") + "/.config/xcloud/colors/colors.json"]
        
        // REQUIRED: Quickshell needs this to parse the binary stream into text
        stdout: StdioCollector {
            onStreamFinished: {
                // "this.text" contains the full output of the cat command
                var output = this.text.trim();
                
                if (output !== "") {
                    try {
                        var newColors = JSON.parse(output);
                        for (var key in newColors) {
                            if (root.hasOwnProperty(key) && key !== "objectName") {
                                root[key] = newColors[key];
                            }
                        }
                        console.log("Theme colors loaded successfully!");
                    } catch (e) {
                        console.log("Failed to parse theme JSON: " + e);
                    }
                }
            }
        }
    }

    function reloadTheme() {
        // Toggle false then true to guarantee Quickshell restarts the cat process
        reader.running = false;
        reader.running = true;
    }

    // Load the JSON colors automatically when Quickshell starts. Safe even
    // before colors.json exists (e.g. first run before matugen has ever
    // generated a theme): the process handler above already no-ops on
    // empty output.
    Component.onCompleted: reloadTheme()
}