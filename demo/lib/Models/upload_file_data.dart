import 'dart:typed_data';

class UploadFileData {
  const UploadFileData({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
}
