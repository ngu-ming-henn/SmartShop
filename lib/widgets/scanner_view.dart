import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/strings.dart';

/// Camera barcode / QR scanner with a torch button and a "type code"
/// fallback for damaged labels (risk mitigation, section 14).
///
/// Single mode: the camera stops while [onCode] runs (e.g. a pushed screen)
/// and starts again when it returns. Continuous mode (counter sale): keeps
/// scanning and ignores the same code for 2 seconds.
class ScannerView extends StatefulWidget {
  const ScannerView({
    super.key,
    required this.onCode,
    this.hint,
    this.continuous = false,
  });

  final Future<void> Function(String code) onCode;
  final String? hint;
  final bool continuous;

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final _controller = MobileScannerController();
  bool _handled = false; // stop the same barcode firing many times
  String? _lastCode;
  DateTime _lastTime = DateTime(2000);

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty) return;
    await _handle(code);
  }

  Future<void> _handle(String code) async {
    if (widget.continuous) {
      final now = DateTime.now();
      if (code == _lastCode && now.difference(_lastTime).inSeconds < 2) return;
      _lastCode = code;
      _lastTime = now;
      await HapticFeedback.mediumImpact();
      await widget.onCode(code);
      return;
    }
    if (_handled) return;
    _handled = true;
    await HapticFeedback.mediumImpact();
    await _controller.stop();
    if (!mounted) return;
    await widget.onCode(code);
    if (!mounted) return; // e.g. the scanner page was closed with the result
    _handled = false; // back on this screen: scan again
    await _controller.start();
  }

  Future<void> _typeCode() async {
    final text = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Enter code')),
        content: TextField(
          controller: text,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: context.tr('Barcode, SK- code or pickup code'),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: () => Navigator.pop(ctx, text.text.trim()),
            child: Text(context.tr('OK')),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) await _handle(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _CameraError(
            message: error.errorCode == MobileScannerErrorCode.permissionDenied
                ? context.tr(
                    'Camera permission is needed to scan.\nAllow it in Settings, or type the code.',
                  )
                : context.tr(
                    'Camera not available.\nYou can still type the code.',
                  ),
          ),
        ),
        const _ScanFrame(),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: Text(
            widget.hint ??
                context.tr('Point the camera at a barcode or QR code'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 6, color: Colors.black)],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, _) {
                  final on = state.torchState == TorchState.on;
                  return IconButton.filledTonal(
                    tooltip: context.tr(on ? 'Torch off' : 'Torch on'),
                    iconSize: 28,
                    onPressed: state.torchState == TorchState.unavailable
                        ? null
                        : _controller.toggleTorch,
                    icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                  );
                },
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: _typeCode,
                icon: const Icon(Icons.keyboard),
                label: Text(context.tr('Type code')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: FractionallySizedBox(
        widthFactor: 0.7,
        child: AspectRatio(
          aspectRatio: 1.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}
