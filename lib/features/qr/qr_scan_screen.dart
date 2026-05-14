// ──────────────────────────────────────────────────────────────
// Écran : Scanner QR code (V2.2 — supporte lapins ET cages)
// ──────────────────────────────────────────────────────────────
// Utilise mobile_scanner pour lire un QR code CuniGest.
// Formats reconnus :
//   cunigest:lapin:<id>:<numero_bague>
//   cunigest:cage:<id>:<numero_cage>     ← V2.2 (Phase 2)
//
// Quand un QR est scanné, on ouvre la fiche correspondante.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../database/db_helper.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';
import '../cages/cage_detail_screen.dart';
import '../lapins/lapin_detail_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() => _processing = true);
    await _handleCode(code);
  }

  Future<void> _handleCode(String code) async {
    final parts = code.split(':');
    if (parts.length < 4 || parts[0] != 'cunigest') {
      if (!mounted) return;
      _showError('QR code non reconnu');
      return;
    }
    final type = parts[1];
    final id = int.tryParse(parts[2]);
    if (id == null) {
      _showError('ID invalide');
      return;
    }

    if (type == 'lapin') {
      final lapin = await DBHelper.instance.getLapinById(id);
      if (!mounted) return;
      if (lapin == null) {
        _showError('Lapin introuvable (ID $id)');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LapinDetailScreen(lapin: lapin)),
      );
    } else if (type == 'cage') {
      final repo = await DBHelper.instance.cages;
      final cage = await repo.getCageById(id);
      if (!mounted) return;
      if (cage == null) {
        _showError('Cage introuvable (ID $id)');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CageDetailScreen(cageId: cage.id!)),
      );
    } else {
      _showError('Type QR non reconnu : $type');
    }
  }

  void _showError(String msg) {
    setState(() => _processing = false);
    showErrorSnackBar(context, msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _processing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CuAppBar(
        title: 'Scanner un QR code',
        emoji: '📷',
        showActions: false,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Cadre indicatif
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Bandeau d'instruction
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Pointez la caméra vers le QR code\nd\'une cage ou d\'une fiche lapin',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
