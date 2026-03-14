import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Logo validation: size, format, dimensions.
/// Max 500KB, PNG/JPEG/WEBP, 64–512px.
class LogoValidation {
  LogoValidation._();

  static const int maxSizeBytes = 512 * 1024; // 500KB
  static const int minDimension = 64;
  static const int maxDimension = 512;
  static const List<String> allowedMimeTypes = [
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/webp',
  ];

  /// Validates logo bytes. Returns null if valid, error message otherwise.
  static String? validate(Uint8List bytes, {String? mimeType}) {
    if (bytes.length > maxSizeBytes) {
      return 'Logo must be under 500KB (current: ${(bytes.length / 1024).toStringAsFixed(1)}KB)';
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return 'Logo must be a valid PNG, JPEG or WEBP image';
    }
    final w = decoded.width;
    final h = decoded.height;
    if (w < minDimension || h < minDimension) {
      return 'Logo must be at least ${minDimension}x$minDimension pixels (current: ${w}x$h)';
    }
    if (w > maxDimension || h > maxDimension) {
      return 'Logo must be at most ${maxDimension}x$maxDimension pixels (current: ${w}x$h)';
    }
    return null;
  }

  /// Validates base64 string. Returns null if valid.
  static String? validateBase64(String base64) {
    try {
      final bytes = base64Decode(base64.replaceAll(RegExp(r'\s'), ''));
      return validate(Uint8List.fromList(bytes));
    } catch (_) {
      return 'Logo must be valid base64';
    }
  }
}
