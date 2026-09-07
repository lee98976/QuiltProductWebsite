import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Widget buildScannerErrorView(
  BuildContext context,
  MobileScannerException error,
) {
  final permissionDenied =
      error.errorCode == MobileScannerErrorCode.permissionDenied;
  final message = permissionDenied
      ? 'Camera access was not granted. You can leave this screen and continue using the rest of Quilt.'
      : 'The camera is unavailable right now. Close this screen and try again.';

  return ColoredBox(
    color: Colors.black,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.camera_alt_outlined,
                size: 52,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                permissionDenied
                    ? 'Camera access declined'
                    : 'Camera unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
