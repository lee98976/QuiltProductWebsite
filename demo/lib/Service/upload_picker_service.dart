import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import '../Models/upload_file_data.dart';

class UploadPickerService {
  const UploadPickerService();

  Future<UploadFileData?> pickSingleImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    return _toUploadFile(file);
  }

  Future<List<UploadFileData>> pickPostFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'],
      withData: true,
    );

    final picked =
        result?.files.map(_toUploadFile).whereType<UploadFileData>().toList() ??
        const <UploadFileData>[];

    return picked;
  }

  UploadFileData? _toUploadFile(PlatformFile? file) {
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    final mimeType =
        lookupMimeType(file.name, headerBytes: bytes) ??
        'application/octet-stream';

    return UploadFileData(
      bytes: Uint8List.fromList(bytes),
      fileName: file.name,
      mimeType: mimeType,
      sizeBytes: file.size,
    );
  }
}
