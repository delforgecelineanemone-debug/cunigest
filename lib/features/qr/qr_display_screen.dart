// ──────────────────────────────────────────────────────────────
// Écran : Affichage du QR code d'un lapin
// ──────────────────────────────────────────────────────────────
// Génère un QR code au format `cunigest:lapin:<id>:<bague>` que
// l'éleveur peut imprimer et coller sur la cage du lapin.
//
// Permet aussi de partager (impression réseau, mail, etc.).
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:ui' as ui;
import 'dart:io';
import '../../models/lapin.dart';
import '../../ui/cu_ui.dart';

class QrDisplayScreen extends StatelessWidget {
  final Lapin lapin;
  final GlobalKey _qrKey = GlobalKey();

  QrDisplayScreen({super.key, required this.lapin});

  String get _qrData => 'cunigest:lapin:${lapin.id}:${lapin.numeroBague}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CuAppBar(
        title: 'QR Code',
        emoji: '📱',
        showActions: false,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _partager(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lapin.displayName,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bague : ${lapin.numeroBague}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 240,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${lapin.sexeLabel} • ${lapin.race ?? "Race inconnue"}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'CuniGest',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Imprimez ce QR code et collez-le\nsur la cage de ${lapin.displayName}',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cuTextPrimary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Partager / Imprimer'),
                onPressed: () => _partager(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _partager(BuildContext context) async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'qr_${lapin.numeroBague}.png'));
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)],
          subject: 'QR code ${lapin.displayName}',
          text: 'QR code CuniGest pour ${lapin.displayName} (${lapin.numeroBague})');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Partage impossible. Réessaye.')));
      }
    }
  }
}
