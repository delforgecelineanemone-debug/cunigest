// ──────────────────────────────────────────────────────────────
// KeyRecoveryScreen — récupération après perte de clé de chiffrement
// ──────────────────────────────────────────────────────────────
// Affiché par le splash quand `getOrCreateKey()` lève une
// [EncryptionKeyLostException] : le stockage sécurisé du téléphone
// s'est corrompu et la clé qui déchiffre la base est introuvable.
//
// On NE régénère pas une clé en silence (cela écraserait la clé
// d'origine pour toujours). On explique la situation à l'éleveur et
// on lui propose une réinitialisation propre — après quoi il pourra
// restaurer une sauvegarde .cunigest s'il en a une.
// ──────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../database/db_helper.dart';
import '../../main.dart';
import '../../services/encryption_key_service.dart';

class KeyRecoveryScreen extends StatefulWidget {
  const KeyRecoveryScreen({super.key});

  @override
  State<KeyRecoveryScreen> createState() => _KeyRecoveryScreenState();
}

class _KeyRecoveryScreenState extends State<KeyRecoveryScreen> {
  bool _resetting = false;

  Future<void> _confirmerReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser l\'application ?'),
        content: const Text(
          'Les données actuelles sont chiffrées avec une clé que ce '
          'téléphone a perdue : elles ne peuvent plus être lues.\n\n'
          'La réinitialisation repart d\'une base vide. Si tu as une '
          'sauvegarde .cunigest, tu pourras la restaurer juste après '
          'depuis Réglages → Sauvegarde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (ok == true) await _reset();
  }

  Future<void> _reset() async {
    setState(() => _resetting = true);
    try {
      // 1. Supprimer le fichier de base illisible (chiffré avec l'ancienne clé).
      try {
        final path = await DBHelper.instance.databasePath;
        await deleteDatabase(path);
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {/* fichier déjà absent */}

      // 2. Effacer la clé orpheline + le marqueur → la prochaine ouverture
      //    générera une clé neuve sur une base vide.
      await EncryptionKeyService.instance.clearForReset();
      await DBHelper.instance.resetForRestore();
    } catch (_) {/* on continue : le redémarrage repartira de zéro */}

    if (!mounted) return;
    // Relance le parcours normal depuis le splash, sur une base saine.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_reset,
                    size: 72, color: Color(0xFF1D9E75)),
                const SizedBox(height: 20),
                Text(
                  'Données protégées inaccessibles',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'La clé de sécurité de ce téléphone a été perdue '
                  '(cela arrive rarement, après une mise à jour ou un '
                  'problème système). Les données enregistrées sont '
                  'chiffrées et ne peuvent plus être ouvertes sur cet '
                  'appareil.\n\n'
                  'Bonne nouvelle : si tu as déjà exporté une sauvegarde '
                  '« .cunigest », elle n\'est pas concernée — tu pourras '
                  'la restaurer après la réinitialisation.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                if (_resetting)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _confirmerReset,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Réinitialiser l\'application'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
