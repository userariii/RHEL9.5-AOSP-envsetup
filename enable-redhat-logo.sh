#!/bin/bash

# Set the path to the extension.js file
EXTENSION_JS_PATH="/usr/share/gnome-shell/extensions/background-logo@fedorahosted.org/extension.js"

# Backup the original extension.js file
echo "Creating a backup of the original extension.js..."
sudo cp "$EXTENSION_JS_PATH" "$EXTENSION_JS_PATH.bak"
echo "Backup created at $EXTENSION_JS_PATH.bak"

# Modify the _updateVisibility function to always show the logo
echo "Modifying the extension.js to always show the Red Hat logo..."

sudo sed -i '/_updateVisibility()/,/}/s/if (.*)/let visible = true;  \/\/ Always show the logo/' "$EXTENSION_JS_PATH"

# Reload GNOME Shell and the extension
echo "Reloading GNOME Shell and re-enabling the extension..."

# Disable and then enable the extension
gnome-extensions disable background-logo@fedorahosted.org
gnome-extensions enable background-logo@fedorahosted.org

echo "Red Hat logo overlay is now always visible! | Reboot the system for the changes"
