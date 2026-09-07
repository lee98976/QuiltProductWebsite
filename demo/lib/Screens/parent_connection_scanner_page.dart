import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../Models/parent_connection_link.dart';
import '../Utility/AppSpacing.dart';
import '../Components/scanner_error_view.dart';

enum ParentConnectionScanMode { studentQr, parentRequestQr }

class ParentConnectionScannerPage extends StatefulWidget {
  const ParentConnectionScannerPage({
    this.mode = ParentConnectionScanMode.studentQr,
    super.key,
  });

  final ParentConnectionScanMode mode;

  @override
  State<ParentConnectionScannerPage> createState() =>
      _ParentConnectionScannerPageState();
}

class _ParentConnectionScannerPageState
    extends State<ParentConnectionScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _finishing = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_finishing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;

      final scannedValue = switch (widget.mode) {
        ParentConnectionScanMode.studentQr =>
          ParentConnectionLink.familyCodeFrom(value),
        ParentConnectionScanMode.parentRequestQr =>
          ParentConnectionLink.parentRequestIdFrom(value),
      };
      if (scannedValue == null) {
        if (mounted && _message == null) {
          setState(() => _message = _invalidMessage);
        }
        continue;
      }

      _finishing = true;
      await _controller.stop();
      if (mounted) Navigator.of(context).pop(scannedValue);
      return;
    }
  }

  String get _title => switch (widget.mode) {
    ParentConnectionScanMode.studentQr => 'Scan student QR',
    ParentConnectionScanMode.parentRequestQr => 'Scan guardian QR',
  };

  String get _invalidMessage => switch (widget.mode) {
    ParentConnectionScanMode.studentQr =>
      'That is not a Quilt student connection QR code.',
    ParentConnectionScanMode.parentRequestQr =>
      'That is not the pending guardian connection QR code.',
  };

  String get _helpText => switch (widget.mode) {
    ParentConnectionScanMode.studentQr =>
      'Center the student\'s Quilt connection QR code in the frame.',
    ParentConnectionScanMode.parentRequestQr =>
      'Center the guardian\'s pending connection QR code in the frame.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_title),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: buildScannerErrorView,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _message ?? _helpText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _message == null
                        ? Colors.white
                        : theme.colorScheme.errorContainer,
                    fontWeight: FontWeight.w600,
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
