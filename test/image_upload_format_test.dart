import 'package:app_mobile_sistema_alarma/core/media/image_upload_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detecta JPEG y normaliza su nombre de archivo', () {
    final format = ImageUploadFormat.detect([
      0xff,
      0xd8,
      0xff,
      0xe0,
      0x00,
      0x10,
    ]);

    expect(format, isNotNull);
    expect(format!.mediaType.mimeType, 'image/jpeg');
    expect(
      format.normalizedFileName('foto de camara.tmp'),
      'foto_de_camara.jpg',
    );
  });

  test('detecta PNG, GIF y WebP por su contenido real', () {
    final png = ImageUploadFormat.detect([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    final gif = ImageUploadFormat.detect([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
    final webp = ImageUploadFormat.detect([
      0x52,
      0x49,
      0x46,
      0x46,
      0,
      0,
      0,
      0,
      0x57,
      0x45,
      0x42,
      0x50,
    ]);

    expect(png?.mediaType.mimeType, 'image/png');
    expect(gif?.mediaType.mimeType, 'image/gif');
    expect(webp?.mediaType.mimeType, 'image/webp');
  });

  test('rechaza contenido que no corresponde a una imagen compatible', () {
    expect(ImageUploadFormat.detect('texto'.codeUnits), isNull);
    expect(ImageUploadFormat.detect(const []), isNull);
  });
}
