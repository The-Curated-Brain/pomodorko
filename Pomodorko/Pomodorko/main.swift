import SwiftUI

// Check CLI arguments before starting the app
// This avoids initializing SwiftUI/AppKit when just sending a CLI command
if CLI.processArguments() {
    exit(0)
}

// No CLI command - start the app normally
PomodorkoApp.main()
