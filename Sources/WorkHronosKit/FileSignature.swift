import Foundation

/// Potpis fajla za detekciju eksternih izmena (Dropbox zamenjuje fajl rename-om → novi inode).
public struct FileSignature: Equatable {
    public let inode: UInt64
    public let size: UInt64
    public let mtime: TimeInterval

    public static func of(path: String) -> FileSignature? {
        var st = stat()
        guard stat(path, &st) == 0 else { return nil }
        return FileSignature(
            inode: UInt64(st.st_ino),
            size: UInt64(st.st_size),
            mtime: TimeInterval(st.st_mtimespec.tv_sec) + TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000
        )
    }
}
