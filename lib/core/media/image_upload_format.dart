import 'package:http_parser/http_parser.dart';

class ImageUploadFormat {
  final String subtype;
  final String extension;

  const ImageUploadFormat._(this.subtype, this.extension);

  static const jpeg = ImageUploadFormat._('jpeg', 'jpg');
  static const png = ImageUploadFormat._('png', 'png');
  static const gif = ImageUploadFormat._('gif', 'gif');
  static const webp = ImageUploadFormat._('webp', 'webp');

  MediaType get mediaType => MediaType('image', subtype);

  static ImageUploadFormat? detect(List<int> bytes) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[offset + index] != signature[index]) return false;
      }
      return true;
    }

    if (startsWith(const [0xff, 0xd8, 0xff])) return jpeg;
    if (startsWith(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return png;
    }
    if (startsWith(const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
        startsWith(const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
      return gif;
    }
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return webp;
    }

    return null;
  }

  String normalizedFileName(String originalName) {
    final leafName = originalName.split(RegExp(r'[\\/]')).last;
    final dotIndex = leafName.lastIndexOf('.');
    final rawStem = dotIndex > 0 ? leafName.substring(0, dotIndex) : leafName;
    final safeStem = rawStem
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return '${safeStem.isEmpty ? 'imagen' : safeStem}.$extension';
  }
}
