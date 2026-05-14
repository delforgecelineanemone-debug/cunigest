import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static const int _thumbSize = 200;

  /// Copies a picked image to permanent app storage and generates a 200×200 thumbnail.
  /// Returns the full-size path. Thumbnail is at [thumbnailPath(result)].
  static Future<String> savePhoto(String tempPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final lapinsDir = Directory('${dir.path}/lapins');
    if (!await lapinsDir.exists()) await lapinsDir.create(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final fullPath = '${lapinsDir.path}/$ts.jpg';
    await File(tempPath).copy(fullPath);

    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        tempPath,
        minWidth: _thumbSize,
        minHeight: _thumbSize,
        quality: 75,
      );
      if (bytes != null) {
        await File(thumbnailPath(fullPath)).writeAsBytes(bytes);
      }
    } catch (_) {
      // Non-critical: list views fall back to full photo on failure
    }

    return fullPath;
  }

  /// Derives the thumbnail path from a full photo path.
  /// e.g. /lapins/1234.jpg → /lapins/1234_thumb.jpg
  static String thumbnailPath(String photoPath) {
    final dot = photoPath.lastIndexOf('.');
    if (dot < 0) return '${photoPath}_thumb';
    return '${photoPath.substring(0, dot)}_thumb${photoPath.substring(dot)}';
  }

  /// Returns the appropriate ImageProvider for list tiles.
  /// Uses the thumbnail when available, falls back to full photo.
  static ImageProvider listImageFor(String photoPath) {
    final thumb = thumbnailPath(photoPath);
    if (File(thumb).existsSync()) return FileImage(File(thumb));
    return FileImage(File(photoPath));
  }

  /// Deletes both the full photo and its thumbnail from disk.
  static Future<void> deletePhoto(String photoPath) async {
    final full = File(photoPath);
    if (await full.exists()) await full.delete();
    final thumb = File(thumbnailPath(photoPath));
    if (await thumb.exists()) await thumb.delete();
  }
}
