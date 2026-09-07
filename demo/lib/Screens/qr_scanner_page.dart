import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../Models/hall_pass.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Service/firebase_service.dart';
import '../Components/confirmation_hub.dart';
import '../Components/scanner_error_view.dart';

enum QrScannerMode { clubAttendance, hallPass, attendanceAndHallPass }

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    required this.schoolID,
    this.mode = QrScannerMode.clubAttendance,
    super.key,
  });

  final String schoolID;
  final QrScannerMode mode;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(autoStart: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue ?? barcode.displayValue;
      if (rawValue == null) continue;
      if (_canHandle(rawValue)) {
        setState(() => _isProcessing = true);
        await _processScan(rawValue);
        break;
      }
    }
  }

  bool _canHandle(String value) {
    final trimmedValue = value.trim();
    return switch (widget.mode) {
      QrScannerMode.clubAttendance => trimmedValue.startsWith(
        'quilt_club_attendance:',
      ),
      QrScannerMode.hallPass => trimmedValue.startsWith('ROOM:'),
      QrScannerMode.attendanceAndHallPass =>
        trimmedValue.startsWith('quilt_club_attendance:') ||
            trimmedValue.startsWith('EVENT:') ||
            trimmedValue.startsWith('ROOM:'),
    };
  }

  Future<void> _processScan(String data) async {
    final scanData = data.trim();
    try {
      if (scanData.startsWith('ROOM:')) {
        await _processHallPass(scanData.substring(5));
        return;
      }
      if (scanData.startsWith('EVENT:')) {
        await _processEventAttendance(scanData);
        return;
      }
      if (scanData.startsWith('quilt_club_attendance:')) {
        await _processClubAttendance(scanData);
        return;
      }
      throw Exception('Invalid QR Code format.');
    } catch (e) {
      if (mounted) {
        QuiltConfirmation.error(context, 'Failed to scan QR: $e');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processClubAttendance(String data) async {
    final parts = data.split(':');
    if (parts.length >= 3) {
      final clubId = parts[1];
      final dateStr = parts[2];

      try {
        final auth = context.read<AuthService>();
        final firebase = context.read<FirebaseService>();
        final profileNotifier = context.read<CurrentUserProfileNotifier>();
        final uid = auth.currentUser?.uid;
        if (uid == null) throw Exception('Not logged in');

        await firebase.attendClubEvent(widget.schoolID, clubId, uid);
        await profileNotifier.refresh();

        if (mounted) {
          QuiltConfirmation.success(
            context,
            'Successfully checked into club for $dateStr!',
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          QuiltConfirmation.error(context, 'Failed to check in: $e');
          setState(() => _isProcessing = false);
        }
      }
    } else {
      if (mounted) {
        QuiltConfirmation.warning(context, 'Invalid QR Code format.');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processEventAttendance(String data) async {
    final parts = data.split(':');
    if (parts.length != 3) {
      throw Exception('Invalid club event QR code.');
    }
    final auth = context.read<AuthService>();
    final firebase = context.read<FirebaseService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final uid = auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    await firebase.attendEvent(widget.schoolID, parts[1], parts[2], uid);
    await profileNotifier.refresh();
    if (!mounted) return;
    QuiltConfirmation.success(
      context,
      'Successfully checked into event! Points awarded.',
    );
    Navigator.of(context).pop();
  }

  Future<void> _processHallPass(String roomId) async {
    if (roomId.trim().isEmpty) {
      throw Exception('Invalid room QR code.');
    }
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final result = await context.read<FirebaseService>().toggleHallPass(
      widget.schoolID,
      uid,
      roomId.trim(),
    );
    if (!mounted) return;
    final message = switch (result.action) {
      HallPassScanAction.started =>
        'Hall pass started for Room ${result.roomId}.',
      HallPassScanAction.returned =>
        'Hall pass returned for Room ${result.roomId}.',
    };
    QuiltConfirmation.success(context, message);
    Navigator.of(context).pop();
  }

  String get _title {
    return switch (widget.mode) {
      QrScannerMode.clubAttendance => 'Scan Attendance QR',
      QrScannerMode.hallPass => 'Scan Hall Pass QR',
      QrScannerMode.attendanceAndHallPass => 'Scan QR Code',
    };
  }

  String get _prompt {
    return switch (widget.mode) {
      QrScannerMode.clubAttendance => 'Scan a Club Attendance QR Code',
      QrScannerMode.hallPass => 'Scan a room QR code',
      QrScannerMode.attendanceAndHallPass =>
        'Scan an attendance or room QR code',
    };
  }

  String get _processingText {
    return switch (widget.mode) {
      QrScannerMode.hallPass => 'Updating hall pass...',
      _ => 'Checking in...',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_title), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: buildScannerErrorView,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _processingText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  _prompt,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    backgroundColor: Colors.black45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
