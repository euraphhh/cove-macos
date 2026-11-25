import AppKit

/// Opens a prefilled GitHub issue with app/system details.
enum Feedback {
    static func open() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let hasNotch = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
        let body = """
        **What happened / what would you like?**


        **Steps to reproduce (for bugs)**
        1.

        ---
        Cove \(version) · macOS \(os) · \(model) · \(hasNotch ? "notch" : "no notch") · \(NSScreen.screens.count) display(s)
        """
        var components = URLComponents(string: "https://github.com/euraphhh/cove-macos/issues/new")
        components?.queryItems = [URLQueryItem(name: "body", value: body)]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }

    private static var model: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}
