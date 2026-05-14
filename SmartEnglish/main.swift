import Cocoa
import InputMethodKit

let connectionName = "com.songhuiming.inputmethod.SmartEnglish_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

let app = NSApplication.shared
app.run()
