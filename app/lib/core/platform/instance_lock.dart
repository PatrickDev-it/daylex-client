import 'dart:io';

/// An OS-owned lock, released on process death. Never delete the lock file:
/// replacing its inode would allow two writers to hold different locks.
class InstanceLock {
  InstanceLock._(this._handle);
  final RandomAccessFile _handle;

  static InstanceLock acquire(Directory directory) {
    directory.createSync(recursive: true);
    final handle = File('${directory.path}/desktop.lock')
        .openSync(mode: FileMode.append);
    try {
      handle.lockSync(FileLock.exclusive);
      return InstanceLock._(handle);
    } on Object {
      handle.closeSync();
      rethrow;
    }
  }

  void release() => _handle.closeSync();
}
