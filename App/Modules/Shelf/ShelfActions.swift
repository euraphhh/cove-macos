import AppKit
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Things you can do with an item on the Shelf (right-click menu).
enum ShelfAction: String, CaseIterable, Identifiable {
    case copyText, convertPNG, convertJPEG, compress, airDrop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copyText: String(localized: "Copy Text (OCR)")
        case .convertPNG: String(localized: "Convert to PNG")
        case .convertJPEG: String(localized: "Convert to JPEG")
        case .compress: String(localized: "Compress to Zip")
        case .airDrop: String(localized: "AirDrop…")
        }
    }

    var symbol: String {
        switch self {
        case .copyText: "text.viewfinder"
        case .convertPNG, .convertJPEG: "photo"
        case .compress: "doc.zipper"
        case .airDrop: "square.and.arrow.up"
        }
    }
}

enum ShelfActionResult {
    case file(URL)
    case text(String)
    /// The action ran but found nothing (no text in the image).
    case nothing
}

enum ShelfActionError: Error {
    case unreadable, writeFailed, zipFailed
}

/// The work behind the actions. Pure functions over files, so they can be tested without UI.
enum ShelfActions {
    static func available(for item: ShelfItem) -> [ShelfAction] {
        guard let url = item.fileURL else { return [.airDrop] }
        var list: [ShelfAction] = []
        if isImage(url) {
            list.append(.copyText)
            let ext = url.pathExtension.lowercased()
            if ext != "png" { list.append(.convertPNG) }
            if ext != "jpg" && ext != "jpeg" { list.append(.convertJPEG) }
        }
        list += [.compress, .airDrop]
        return list
    }

    static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    /// Runs a file based action. Blocking: call it off the main thread.
    static func run(_ action: ShelfAction, on url: URL, in directory: URL) throws -> ShelfActionResult {
        switch action {
        case .copyText:
            let text = try recognizeText(in: url)
            return text.isEmpty ? .nothing : .text(text)
        case .convertPNG:
            return .file(try convertImage(at: url, to: .png, in: directory))
        case .convertJPEG:
            return .file(try convertImage(at: url, to: .jpeg, in: directory))
        case .compress:
            return .file(try zip(url, in: directory))
        case .airDrop:
            return .nothing // handled on the main thread by ShelfModule
        }
    }

    /// On-device text recognition (Vision), one line per recognized block.
    static func recognizeText(in url: URL) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(url: url).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    static func convertImage(at url: URL, to type: UTType, in directory: URL) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw ShelfActionError.unreadable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = url.deletingPathExtension().lastPathComponent
        let output = uniqueURL(name: name, ext: type.preferredFilenameExtension ?? "img", in: directory)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ShelfActionError.writeFailed
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ShelfActionError.writeFailed }
        return output
    }

    /// Zips a file or folder with `ditto`, the same way Finder's "Compress" does.
    static func zip(_ url: URL, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let output = uniqueURL(name: url.deletingPathExtension().lastPathComponent, ext: "zip", in: directory)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, output.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ShelfActionError.zipFailed }
        return output
    }

    /// `name.ext`, or `name 2.ext`, `name 3.ext`… when that already exists.
    static func uniqueURL(name: String, ext: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(name).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}
