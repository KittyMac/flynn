// swiftlint:disable unused_optional_binding
// swiftlint:disable cyclomatic_complexity

import Flynn
import Foundation

private class FileArchiver: Actor {
    private var fileHandle: FileHandle?
    private var fileURL: URL
    private let bufferSize = 16384 * 8
    private var remoteCompressor: RemoteCompressor?
    private var remoteDecompressor: RemoteDecompressor?
    private var nextChunk = Data()

    init(file: URL) {
        fileURL = file

        super.init()

        fileHandle = try? FileHandle(forReadingFrom: file)
    }

    private func fail(_ reason: String,
                      _ returnCallback: @escaping (Bool) -> Void) {
        print("\(reason): \(fileURL)")
        remoteCompressor = nil
        remoteDecompressor = nil
        returnCallback(false)
    }

    private func _beArchive(_ returnCallback: @escaping (Bool) -> Void) {
        guard let fileHandle = fileHandle else { return fail("FileHandle is null", returnCallback) }

        // Read the first bit from the file to know if it is compressed lzip or not
        nextChunk = fileHandle.readData(ofLength: bufferSize)
        guard nextChunk.count > 0 else { return fail("First chunk is empty", returnCallback) }

        if nextChunk.isLzipped {
            remoteDecompressor = RemoteDecompressor()
        } else {
            remoteCompressor = RemoteCompressor()
        }

        processNextChunk(returnCallback)
    }

    private func processNextChunk(_ returnCallback: @escaping (Bool) -> Void) {
        guard let fileHandle = fileHandle else { return fail("FileHandle is null", returnCallback) }

        if nextChunk.count == 0 {

            if let remoteDecompressor = remoteDecompressor {
                remoteDecompressor.beFinish(self) { (data) in
                    if data.count > 0 {
                        let outFile = self.fileURL.deletingPathExtension()
                        if let _ = try? data.write(to: outFile) {
                            try? FileManager.default.removeItem(at: self.fileURL)
                        }
                        returnCallback(true)
                    } else {
                        return self.fail("RemoteDecompressor finish empty data", returnCallback)
                    }
                }
                self.remoteDecompressor = nil
            } else if let remoteCompressor = remoteCompressor {
                remoteCompressor.beFinish(self) { (data) in
                    if data.count > 0 {
                        let outFile = self.fileURL.appendingPathExtension("lz")
                        if let _ = try? data.write(to: outFile) {
                            try? FileManager.default.removeItem(at: self.fileURL)
                        }
                        returnCallback(true)
                    } else {
                        return self.fail("RemoteCompressor finish empty data", returnCallback)
                    }
                }
                self.remoteCompressor = nil
            }

            return
        }

        if let remoteDecompressor = remoteDecompressor {
            remoteDecompressor.beArchive(nextChunk, self) { (result) in
                guard result == true else { return self.fail("RemoteDecompressor returned false", returnCallback) }
                self.processNextChunk(returnCallback)
            }
        } else if let remoteCompressor = remoteCompressor {
            remoteCompressor.beArchive(nextChunk, self) { (result) in
                guard result == true else { return self.fail("RemoteCompressor returned false", returnCallback) }
                self.processNextChunk(returnCallback)
            }
        }

        nextChunk = fileHandle.readData(ofLength: bufferSize)
    }
}

public class Archiver: Actor {

    private var files: [URL] = []
    private var maxActive: Int = 0
    private var active: Int = 0
    private var completed: Int = 0
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
        if active == 0 && done == false {
            done = true

            print("\(completed) files in \(abs(start.timeIntervalSinceNow))s, max concurrent \(maxActive)")
        }
    }

    private func _beArchiveMore() {

        while Flynn.remoteCores <= 0 {
            usleep(500)
        }

        while active < max(Flynn.cores, Flynn.remoteCores) {
            guard let file = files.popLast() else { return checkDone() }

            active += 1
            if active > maxActive {
                maxActive = active
            }

            let fileArchiver = FileArchiver(file: file)
            fileArchiver.beArchive(self) { (_) in
                self.active -= 1
                self.completed += 1

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
