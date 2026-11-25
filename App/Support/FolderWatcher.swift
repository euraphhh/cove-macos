import Foundation

/// Calls `onChange` on the main queue when entries are added, removed or renamed in a folder.
/// Growth of an existing file's contents does not trigger it.
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?

    /// Fails (returns nil) when the folder can't be opened, e.g. permission not granted yet.
    init?(url: URL, onChange: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { onChange() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    deinit { source?.cancel() }
}
