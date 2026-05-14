// ──────────────────────────────────────────────────────────────
// Service : Logger d'erreurs persistant (V3.0)
// ──────────────────────────────────────────────────────────────
// Capture les erreurs Flutter et Dart non attrapées et les écrit
// dans un fichier local rotatif (~500 KB max).
// Consultable depuis Réglages → "Voir les logs".
//
// Usage :
//   ErrorLoggerService.instance.log('Contexte', error, stack);
//   final logs = await ErrorLoggerService.instance.readLogs();
// ──────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ErrorLoggerService {
  static final ErrorLoggerService instance = ErrorLoggerService._();
  ErrorLoggerService._();

  static const int _maxSizeBytes = 500 * 1024; // 500 KB
  static const String _fileName = 'cunigest_errors.log';

  File? _logFile;

  /// Initialise le chemin du fichier de log.
  /// Doit être appelé après WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File(p.join(dir.path, _fileName));
    } catch (e) {
      debugPrint('ErrorLogger init échoué : $e');
    }
  }

  /// Enregistre une erreur avec contexte, timestamp et stack trace.
  Future<void> log(String context, Object error, [StackTrace? stack]) async {
    final file = _logFile;
    if (file == null) return;

    try {
      final now = DateTime.now().toIso8601String();
      final entry = StringBuffer()
        ..writeln('═══ $now ═══')
        ..writeln('[$context] $error');
      if (stack != null) {
        // Ne garder que les 8 premières lignes de stack pour la lisibilité
        final lines = stack.toString().split('\n');
        final truncated = lines.take(8).join('\n');
        entry.writeln(truncated);
        if (lines.length > 8) entry.writeln('  ... (${lines.length - 8} lignes supplémentaires)');
      }
      entry.writeln();

      await file.writeAsString(
        entry.toString(),
        mode: FileMode.append,
        flush: true,
      );

      // Rotation : si le fichier dépasse la taille max, on garde la moitié la plus récente
      await _rotateIfNeeded(file);
    } catch (e) {
      debugPrint('ErrorLogger write échoué : $e');
    }
  }

  /// Lit le contenu du fichier de log (dernières entrées en premier).
  Future<String> readLogs() async {
    final file = _logFile;
    if (file == null || !await file.exists()) {
      return 'Aucun log enregistré.';
    }
    try {
      return await file.readAsString();
    } catch (e) {
      return 'Erreur de lecture des logs : $e';
    }
  }

  /// Supprime le fichier de log.
  Future<void> clearLogs() async {
    final file = _logFile;
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('ErrorLogger clear échoué : $e');
    }
  }

  /// Taille actuelle du fichier de log en octets.
  Future<int> logSize() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return 0;
    return file.length();
  }

  /// Rotation : si le fichier dépasse _maxSizeBytes, on ne garde
  /// que la seconde moitié (la plus récente).
  Future<void> _rotateIfNeeded(File file) async {
    try {
      final size = await file.length();
      if (size <= _maxSizeBytes) return;

      final content = await file.readAsString();
      final half = content.length ~/ 2;
      // Trouver le début de la prochaine entrée après le milieu
      final nextEntry = content.indexOf('═══', half);
      if (nextEntry < 0) return;

      await file.writeAsString(
        content.substring(nextEntry),
        mode: FileMode.write,
        flush: true,
      );
    } catch (_) {
      // Rotation non critique — on continue
    }
  }
}
