import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../Models/hall_pass.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Service/firebase_service.dart';
import 'confirmation_hub.dart';
import 'scanner_error_view.dart';

/// Implementation of Mobile Scanner example with simple configuration
class MobileScannerSimple extends StatefulWidget {
  const MobileScannerSimple({super.key});

  @override
  State<MobileScannerSimple> createState() => _MobileScannerSimpleState();
}

class _MobileScannerSimpleState extends State<MobileScannerSimple> {
  Barcode? _barcode;
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();

    // Do NOT start camera immediately
    _controller = MobileScannerController(autoStart: false);

    // Start camera after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.start();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _barcodePreview(Barcode? value) {
    if (value == null) {
      return const Text(
        'Scan something!',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.displayValue ?? 'No display value.',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  bool _processing = false;

  Future<void> _handleBarcode(BarcodeCapture barcodes) async {
    if (!mounted || _processing) return;

    final barcode = barcodes.barcodes.firstOrNull;
    if (barcode == null || barcode.displayValue == null) return;

    final value = barcode.displayValue!;
    setState(() {
      _barcode = barcode;
    });

    if (value.startsWith('EVENT:') || value.startsWith('ROOM:')) {
      _processing = true;
      final firebase = context.read<FirebaseService>();
      final auth = context.read<AuthService>();
      final profileN = context.read<CurrentUserProfileNotifier>();
      final uid = auth.currentUser?.uid;
      final schoolID = profileN.profile?.schoolID;

      if (uid == null || schoolID == null || schoolID.isEmpty) {
        if (mounted) {
          QuiltConfirmation.warning(
            context,
            'Your profile is not connected to a school yet.',
          );
        }
        _processing = false;
        return;
      }

      try {
        if (value.startsWith('EVENT:')) {
          final parts = value.split(':');
          if (parts.length != 3) {
            throw Exception('Invalid club event QR code.');
          }
          final clubId = parts[1];
          final eventId = parts[2];
          await firebase.attendEvent(schoolID, clubId, eventId, uid);
          await profileN.refresh();
          if (mounted) {
            QuiltConfirmation.success(
              context,
              'Successfully checked into event! Points awarded.',
            );
            Navigator.of(context).pop();
          }
        } else if (value.startsWith('ROOM:')) {
          final roomId = value.substring(5);
          final result = await firebase.toggleHallPass(schoolID, uid, roomId);
          final message = switch (result.action) {
            HallPassScanAction.started =>
              'Hall pass started for Room ${result.roomId}.',
            HallPassScanAction.returned =>
              'Hall pass returned for Room ${result.roomId}.',
          };
          if (mounted) {
            QuiltConfirmation.success(context, message);
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (mounted) {
          QuiltConfirmation.error(context, e.toString());
        }
        _processing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _handleBarcode,
          errorBuilder: buildScannerErrorView,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 100,
            color: const Color.fromRGBO(0, 0, 0, 0.4),
            child: Center(child: _barcodePreview(_barcode)),
          ),
        ),
      ],
    );
  }
}
