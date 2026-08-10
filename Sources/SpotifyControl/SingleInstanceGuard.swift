import Darwin
import Foundation

final class SingleInstanceGuard {
    private let lockURL: URL
    private var fileDescriptor: Int32 = -1

    init(identifier: String = Bundle.main.bundleIdentifier ?? "io.github.yuyatakeda.SpotifyControl") {
        let safeIdentifier = identifier.replacingOccurrences(of: "/", with: "-")
        lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeIdentifier).lock", isDirectory: false)
    }

    func acquire() -> Bool {
        guard fileDescriptor == -1 else { return true }

        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return false }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return false
        }

        fileDescriptor = descriptor
        return true
    }

    func release() {
        guard fileDescriptor >= 0 else { return }
        flock(fileDescriptor, LOCK_UN)
        Darwin.close(fileDescriptor)
        fileDescriptor = -1
    }

    deinit {
        release()
    }
}
