/// What the writers need to know about an image's bytes before they embed them: its format and pixel size.
library;

import 'dart:typed_data';

/// The raster formats a document file can carry as they are (no re-encoding: the lawyer's bytes go in untouched).
enum ImageFormat {
  png('image/png', 'png'),
  jpeg('image/jpeg', 'jpg'),
  gif('image/gif', 'gif');

  const ImageFormat(this.mime, this.extension);

  final String mime;
  final String extension;
}

class ImageHeader {
  const ImageHeader(this.format, this.width, this.height);

  final ImageFormat format;
  final int width;
  final int height;
}

/// Reads the format and the pixel size from the header of [b], or null when it is not a PNG, JPEG or GIF
/// (a WebP or a damaged file is not embedded: the writers name it as a placeholder instead).
ImageHeader? sniffImage(Uint8List b) {
  int be16(int i) => (b[i] << 8) | b[i + 1];
  int be32(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

  // PNG: signature, then IHDR with the size first.
  if (b.length >= 24 &&
      b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
      b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A &&
      b[12] == 0x49 && b[13] == 0x48 && b[14] == 0x44 && b[15] == 0x52) {
    final w = be32(16), h = be32(20);
    return w > 0 && h > 0 ? ImageHeader(ImageFormat.png, w, h) : null;
  }

  // GIF: "GIF87a" or "GIF89a", then the logical screen size, little endian.
  if (b.length >= 10 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38 && (b[4] == 0x37 || b[4] == 0x39) && b[5] == 0x61) {
    final w = b[6] | (b[7] << 8), h = b[8] | (b[9] << 8);
    return w > 0 && h > 0 ? ImageHeader(ImageFormat.gif, w, h) : null;
  }

  // JPEG: walk the marker segments up to the first start-of-frame, which carries the size.
  if (b.length >= 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 3 < b.length) {
      if (b[i] != 0xFF) return null;
      while (i < b.length && b[i] == 0xFF) {
        i++;
      }
      if (i >= b.length) return null;
      final marker = b[i++];
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;
      if (marker == 0xD9 || marker == 0xDA) return null;
      if (i + 1 >= b.length) return null;
      final length = be16(i);
      final isFrame = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
      if (isFrame) {
        if (i + 6 >= b.length) return null;
        final h = be16(i + 3), w = be16(i + 5);
        return w > 0 && h > 0 ? ImageHeader(ImageFormat.jpeg, w, h) : null;
      }
      i += length;
    }
  }
  return null;
}
