import 'dart:io';

import 'package:path/path.dart' as p;

class ProfilePathResolver {
  const ProfilePathResolver(this._workingDir);

  final Directory _workingDir;

  Directory get directory => Directory(p.join(_workingDir.path, "configs"));

  File file(String fileName) {
    return File(p.join(directory.path, "$fileName.json"));
  }

  File tempFile(String fileName) => file("$fileName.tmp");

  /// Runtime copy used for transport-specific candidate filtering.
  /// The downloaded subscription file is never modified.
  File runtimeFile(String fileName) => File(p.join(directory.path, "$fileName.runtime.json"));
}
