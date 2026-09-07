import 'package:cloud_firestore/cloud_firestore.dart';

/// Prevents accidental network access from actions outside the guided preview.
/// Supported reads return local sample data directly in FirebaseService.
class PreviewDatabase implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('This action is not available in the sample preview.');
}
