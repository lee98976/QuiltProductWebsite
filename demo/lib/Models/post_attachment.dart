enum PostAttachmentType { image, pdf, link }

class PostAttachment {
  const PostAttachment({
    required this.type,
    required this.label,
    required this.url,
    this.mimeType,
    this.sizeBytes,
    this.storagePath,
  });

  final PostAttachmentType type;
  final String label;
  final String url;
  final String? mimeType;
  final int? sizeBytes;
  final String? storagePath;

  bool get isImage => type == PostAttachmentType.image;
  bool get isPdf => type == PostAttachmentType.pdf;
  bool get isLink => type == PostAttachmentType.link;

  factory PostAttachment.fromMap(Map<String, dynamic> map) {
    return PostAttachment(
      type: _typeFromString(map['type'] as String?),
      label: map['label'] as String? ?? 'Attachment',
      url: map['url'] as String? ?? '',
      mimeType: map['mimeType'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
      storagePath: map['storagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'label': label,
      'url': url,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'storagePath': storagePath,
    };
  }

  static PostAttachmentType _typeFromString(String? raw) {
    return PostAttachmentType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => PostAttachmentType.link,
    );
  }
}
