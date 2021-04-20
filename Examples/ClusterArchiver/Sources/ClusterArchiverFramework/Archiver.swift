// swiftlint:disable unused_optional_binding
// swiftlint:disable line_length

import Flynn
import Foundation

private class FileArchiver: Actor {
    private var fileHandle: FileHandle?
    private var fileURL: URL
    private var isLocal: Bool
    private let bufferSize = 16384 * 8

    private var lzipActor: LzipActor?
    private var nextChunk = Data()

    init(file: URL,
         local: Bool) {
        fileURL = file
        isLocal = local

        super.init()

        fileHandle = try? FileHandle(forReadingFrom: file)
    }

    private func fail(_ reason: String,
                      _ returnCallback: @escaping (Bool) -> Void) {
        print("\(reason): \(fileURL)")
        lzipActor = nil
        returnCallback(false)
    }

    private func _beArchive(_ returnCallback: @escaping (Bool) -> Void) {
        guard let fileHandle = fileHandle else { return fail("FileHandle is null", returnCallback) }

        // Read the first bit from the file to know if it is compressed lzip or not
        nextChunk = fileHandle.readData(ofLength: bufferSize)
        guard nextChunk.count > 0 else { return fail("First chunk is empty", returnCallback) }

        if isLocal {
            if nextChunk.isLzipped {
                lzipActor = LocalDecompressor()
            } else {
                lzipActor = LocalCompressor()
            }
        } else {
            if nextChunk.isLzipped {
                lzipActor = RemoteDecompressor()
            } else {
                lzipActor = RemoteCompressor()
            }
        }

        processNextChunk(returnCallback)
    }

    private func processNextChunk(_ returnCallback: @escaping (Bool) -> Void) {
        guard let fileHandle = fileHandle else { return fail("FileHandle is null", returnCallback) }

        if nextChunk.count == 0 {

            if let lzipActor = lzipActor {
                lzipActor.beFinish(self) { (data) in
                    if data.count > 0 {
                        if data.isLzipped {
                            let outFile = self.fileURL.appendingPathExtension("lz")
                            if let _ = try? data.write(to: outFile) {
                                try? FileManager.default.removeItem(at: self.fileURL)
                            }
                        } else {
                            let outFile = self.fileURL.deletingPathExtension()
                            if let _ = try? data.write(to: outFile) {
                                try? FileManager.default.removeItem(at: self.fileURL)
                            }
                        }
                        returnCallback(true)
                    } else {
                        return self.fail("RemoteDecompressor finish empty data", returnCallback)
                    }
                }
                self.lzipActor = nil
            }
            return
        }

        if let lzipActor = lzipActor {
            lzipActor.beArchive(nextChunk, self) { (result) in
                guard result == true else { return self.fail("Lzip returned false", returnCallback) }
                self.processNextChunk(returnCallback)
            }
        }

        nextChunk = fileHandle.readData(ofLength: bufferSize)
    }
}

public class Archiver: Actor {

    private var files: [URL] = []
    private var maxActive: Int = 0

    private var activeLocal: Int = 0
    private var activeRemote: Int = 0
    private var completedLocal: Int = 0
    private var completedRemote: Int = 0

    private var done = false
    private let start = Date()

    @discardableResult
    public init(directory: String) {
        super.init()

        if let directoryFiles = try? FileManager.default.contentsOfDirectory(atPath: directory) {
            for filePath in directoryFiles {
                files.append(URL(fileURLWithPath: "\(directory)/\(filePath)"))
            }

            print("\(files.count) files to process")

            beArchiveMore()
        }
    }

    private func checkDone() {
        if activeLocal == 0 && activeRemote == 0 && done == false {
            done = true

            print("\(completedLocal) / \(completedRemote) files in \(abs(start.timeIntervalSinceNow))s, max concurrent \(maxActive)")
        }
    }

    private func _beArchiveMore() {

        while activeLocal < Flynn.cores {
            guard let file = files.popLast() else { return checkDone() }

            activeLocal += 1
            if (activeLocal + activeRemote) > maxActive {
                maxActive = (activeLocal + activeRemote)
            }

            let fileArchiver = FileArchiver(file: file,
                                            local: true)
            fileArchiver.beArchive(self) { (_) in
                self.activeLocal -= 1
                self.completedLocal += 1

                self.beArchiveMore()
            }
        }

        while activeRemote < Flynn.remoteCores {
            guard let file = files.popLast() else { return checkDone() }

            activeRemote += 1
            if (activeLocal + activeRemote) > maxActive {
                maxActive = (activeLocal + activeRemote)
            }

            let fileArchiver = FileArchiver(file: file,
                                            local: false)
            fileArchiver.beArchive(self) { (_) in
                self.activeRemote -= 1
                self.completedRemote += 1

                self.beArchiveMore()
            }
        }
    }
}

// MARK: - Autogenerated by FlynnLint
// Contents of file after this marker will be overwritten as needed

extension FileArchiver {

    @discardableResult
    public func beArchive(_ sender: Actor,
                          _ callback: @escaping ((Bool) -> Void)) -> Self {
        unsafeSend {
            self._beArchive { arg0 in
                sender.unsafeSend {
                    callback(arg0)
                }
            }
        }
        return self
    }

}

extension Archiver {

    @discardableResult
    public func beArchiveMore() -> Self {
        unsafeSend(_beArchiveMore)
        return self
    }

}
