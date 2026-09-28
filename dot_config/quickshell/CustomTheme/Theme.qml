pragma Singleton
import QtQuick
import Quickshell 
import Quickshell.Io 

QtObject { 
    id: root
    
    // Static properties
    readonly property string fontFamily: "Fira Sans Semibold"
    
    // The shell's accent role, `primary`/`on_primary`, is the fixed xcloud
    // green (colors.json "accent"/"on_accent", matugen custom colour `xcloud`)
    // rather than the wallpaper's primary; colors.json's own "primary"/
    // "on_primary" (still read by nvim) are skipped below so these bindings
    // stay intact.
    property color accent: "#00ff00"
    property color on_accent: "#015000"
    property color primary: accent
    property color on_primary: on_accent

    // Dynamic color properties. Defaults are the shipped palette
    // (~/.config/xcloud/colors/colors.json) so nothing flashes a different
    // palette before that file has been read.
    property color background: "#101418"
    property color error: "#ffb4ab"
    property color error_container: "#93000a"
    property color inverse_on_surface: "#2d3135"
    property color inverse_primary: "#006398"
    property color inverse_surface: "#e0e2e8"
    property color on_background: "#e0e2e8"
    property color on_error: "#690005"
    property color on_error_container: "#ffdad6"
    property color on_primary_container: "#00263f"
    property color on_primary_fixed: "#001d31"
    property color on_primary_fixed_variant: "#004b74"
    property color on_secondary: "#153349"
    property color on_secondary_container: "#c8e3ff"
    property color on_secondary_fixed: "#001d31"
    property color on_secondary_fixed_variant: "#2d4961"
    property color on_surface: "#e0e2e8"
    property color on_surface_variant: "#bfc7d1"
    property color on_tertiary: "#4c1562"
    property color on_tertiary_container: "#3f0355"
    property color on_tertiary_fixed: "#320046"
    property color on_tertiary_fixed_variant: "#652f7b"
    property color outline: "#8a919b"
    property color outline_variant: "#404850"
    property color primary_container: "#64b6f7"
    property color primary_fixed: "#cde5ff"
    property color primary_fixed_dim: "#93ccff"
    property color scrim: "#000000"
    property color secondary: "#adcae6"
    property color secondary_container: "#2d4961"
    property color secondary_fixed: "#cde5ff"
    property color secondary_fixed_dim: "#adcae6"
    property color shadow: "#000000"
    property color source_color: "#64b6f7"
    property color surface: "#101418"
    property color surface_bright: "#36393e"
    property color surface_container: "#1c2024"
    property color surface_container_high: "#272a2f"
    property color surface_container_highest: "#313539"
    property color surface_container_low: "#181c20"
    property color surface_container_lowest: "#0b0f12"
    property color surface_dim: "#101418"
    property color surface_tint: "#93ccff"
    property color surface_variant: "#404850"
    property color tertiary: "#eeb7ff"
    property color tertiary_container: "#d798ec"
    property color tertiary_fixed: "#f9d8ff"
    property color tertiary_fixed_dim: "#edb1ff"

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
                            if (root.hasOwnProperty(key) && key !== "objectName"
                                    && key !== "primary" && key !== "on_primary") {
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