// ──────────────────────────────────────────────────────────────
// Service : Notifications Locales (Push même app fermée)
// ──────────────────────────────────────────────────────────────
// Ce service gère les notifications sur le téléphone :
// - Rappels quotidiens (nourrir, eau, observation) à des heures
//   configurables dans les réglages
// - Alertes de reproduction (palpation, nid, mise bas) — les
//   alertes critiques sont notifiées immédiatement, les autres
//   programmées pour 8h ou immédiatement si l'heure est passée
// - Messages motivants (streaks, badges)
//
// Le fuseau horaire est détecté automatiquement depuis le système
// (plus de Paris en dur). En cas d'échec, on retombe sur UTC.
//
// Les notifications fonctionnent MÊME QUAND L'APP EST FERMÉE.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../database/db_helper.dart';

/// Service singleton de notifications.
/// Usage : `await NotificationService.instance.init()` au démarrage.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── IDs de canaux de notification ──
  static const String _channelRoutine = 'routine_channel';
  static const String _channelAlerte = 'alerte_channel';
  static const String _channelMotivation = 'motivation_channel';

  // ── Plages d'IDs pour éviter les conflits ──
  // Routines quotidiennes : 1000-1099
  // Alertes reproduction : 2000-2999
  // Motivation : 3000-3099
  static const int _baseIdRoutine = 1000;
  static const int _baseIdAlerte = 2000;
  static const int _baseIdMotivation = 3000;

  /// Initialise le service de notifications.
  /// Doit être appelé une seule fois au démarrage de l'app.
  Future<void> init() async {
    if (_initialized) return;

    // 1. Charger la base de données de fuseaux horaires
    tz_data.initializeTimeZones();

    // 2. Détecter le fuseau horaire système (Android/iOS)
    //    Fallback : UTC si la détection échoue
    String tzName = 'UTC';
    try {
      tzName = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      debugPrint('Échec détection TZ système, fallback UTC : $e');
    }
    try {
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('TZ "$tzName" introuvable, fallback UTC : $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 3. Configuration Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    // 4. Initialiser le plugin
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 5. Pré-créer les canaux Android (requis Android 8+ / API 26+)
    await _creerCanaux();

    // 6. Demander la permission (Android 13+)
    await _demanderPermission();

    _initialized = true;
  }

  /// Pré-crée les canaux de notification (Android 8+ / API 26+).
  /// Idempotent : recréer un canal existant ne le modifie pas.
  Future<void> _creerCanaux() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelRoutine,
      'Routines quotidiennes',
      description: 'Rappels quotidiens de routine d\'élevage',
      importance: Importance.defaultImportance,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelAlerte,
      'Alertes élevage',
      description: 'Alertes de reproduction et de santé',
      importance: Importance.high,
      enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelMotivation,
      'Motivation',
      description: 'Félicitations, badges et streaks',
      importance: Importance.defaultImportance,
    ));
  }

  /// Demande la permission de notifications (Android 13+ / API 33+)
  Future<void> _demanderPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  /// Callback quand l'utilisateur tape sur une notification
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapée : ${response.payload}');
  }

  // ═══════════════════════════════════════════════════════════
  // RAPPELS QUOTIDIENS (routine du matin/midi/soir)
  // ═══════════════════════════════════════════════════════════

  /// Programme les rappels quotidiens de routine selon les réglages.
  /// Si les notifications sont désactivées, annule tout.
  Future<void> programmerRappelsQuotidiens() async {
    // Annuler les anciens rappels quotidiens
    for (int i = _baseIdRoutine; i < _baseIdRoutine + 10; i++) {
      await _plugin.cancel(i);
    }

    final reglages = await DBHelper.instance.getReglages();
    if (!reglages.notificationsActives) return;

    final matin = _parseHeure(reglages.heureRappelMatin) ?? const _Heure(7, 0);
    final midi = _parseHeure(reglages.heureRappelMidi) ?? const _Heure(12, 0);
    final soir = _parseHeure(reglages.heureRappelSoir) ?? const _Heure(18, 0);

    await _programmerQuotidien(
      id: _baseIdRoutine,
      heure: matin.h,
      minute: matin.m,
      titre: '🐇 Bonjour ! Vos lapins vous attendent',
      corps: 'N\'oubliez pas de nourrir, vérifier l\'eau et observer vos lapins.',
      channel: _channelRoutine,
    );

    await _programmerQuotidien(
      id: _baseIdRoutine + 1,
      heure: midi.h,
      minute: midi.m,
      titre: '📋 Routines en attente',
      corps: 'Avez-vous complété vos tâches du matin ? Ouvrez CuniGest pour vérifier.',
      channel: _channelRoutine,
    );

    await _programmerQuotidien(
      id: _baseIdRoutine + 2,
      heure: soir.h,
      minute: soir.m,
      titre: '🌙 Bilan du jour',
      corps: 'Dernière vérification avant la nuit : eau, nourriture, observation.',
      channel: _channelRoutine,
    );
  }

  /// Programme une notification quotidienne récurrente
  Future<void> _programmerQuotidien({
    required int id,
    required int heure,
    required int minute,
    required String titre,
    required String corps,
    required String channel,
  }) async {
    final scheduledDate = _prochainHoraire(heure, minute);

    await _plugin.zonedSchedule(
      id,
      titre,
      corps,
      scheduledDate,
      _detailsNotification(channel, titre),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Répète chaque jour
      payload: 'routine',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ALERTES REPRODUCTION (palpation, nid, mise bas)
  // ═══════════════════════════════════════════════════════════

  /// Programme les notifications d'alertes depuis la base de données.
  /// Pour les alertes du jour dont l'heure cible (8h) est dépassée,
  /// envoie une notification immédiate plutôt que de la perdre.
  Future<void> programmerAlertesReproduction() async {
    // Annuler toutes les anciennes alertes de reproduction
    for (int i = _baseIdAlerte; i < _baseIdAlerte + 100; i++) {
      await _plugin.cancel(i);
    }

    final reglages = await DBHelper.instance.getReglages();
    if (!reglages.notificationsActives) return;

    try {
      final db = DBHelper.instance;
      final alertes = await db.getAlertesActives();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      int idCounter = _baseIdAlerte;
      for (final a in alertes) {
        if (idCounter >= _baseIdAlerte + 100) break; // Max 100 alertes

        final estCritique = a.priorite == 'critique';
        final estAujourdhui = a.dateAlerte == today;

        if (estCritique) {
          // Alerte critique → notification immédiate
          await _notificationImmediate(
            id: idCounter,
            titre: a.titre,
            corps: a.message ?? 'Action requise !',
            channel: _channelAlerte,
            payload: 'alerte_${a.id}',
          );
        } else {
          // Alerte non-critique : tenter à 8h ou maintenant si déjà dépassé
          final dateTime = DateTime.tryParse(a.dateAlerte);
          if (dateTime == null) {
            idCounter++;
            continue;
          }

          final scheduled = tz.TZDateTime(
            tz.local,
            dateTime.year,
            dateTime.month,
            dateTime.day,
            8,
            0,
          );
          final now = tz.TZDateTime.now(tz.local);

          if (scheduled.isAfter(now)) {
            // Programmer normalement
            await _plugin.zonedSchedule(
              idCounter,
              a.titre,
              a.message ?? 'Vérifiez cette alerte.',
              scheduled,
              _detailsNotification(_channelAlerte, a.titre),
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'alerte_${a.id}',
            );
          } else if (estAujourdhui) {
            // 8h passé mais c'est aujourd'hui → notification immédiate
            // (sinon l'alerte serait silencieusement perdue)
            await _notificationImmediate(
              id: idCounter,
              titre: a.titre,
              corps: a.message ?? 'Vérifiez cette alerte.',
              channel: _channelAlerte,
              payload: 'alerte_${a.id}',
            );
          }
          // Si la date d'alerte est dans le passé (et pas aujourd'hui),
          // on n'envoie rien — l'alerte reste visible dans l'écran Alertes.
        }
        idCounter++;
      }
    } catch (e) {
      debugPrint('Erreur programmation alertes : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // NOTIFICATIONS MOTIVANTES
  // ═══════════════════════════════════════════════════════════

  /// Envoie une notification de félicitation (nouveau badge, streak...).
  /// Respecte les réglages : silencieux si gamification désactivée
  /// ou notifications globalement désactivées.
  Future<void> envoyerFelicitation(String titre, String message) async {
    final reglages = await DBHelper.instance.getReglages();
    if (!reglages.notificationsActives || !reglages.gamificationActive) return;

    await _notificationImmediate(
      id: _baseIdMotivation + DateTime.now().millisecond % 100,
      titre: titre,
      corps: message,
      channel: _channelMotivation,
      payload: 'motivation',
    );
  }

  /// Programme la notification de rappel de streak (20h).
  /// Désactivée si la gamification est off.
  Future<void> rappelerStreak(int streakActuel) async {
    final reglages = await DBHelper.instance.getReglages();
    await _plugin.cancel(_baseIdMotivation);
    if (!reglages.notificationsActives || !reglages.gamificationActive) return;

    String message;
    if (streakActuel == 0) {
      message = 'Vous n\'avez pas encore commencé vos routines. Ouvrez CuniGest !';
    } else if (streakActuel < 7) {
      message = 'Vous avez $streakActuel jours de streak. Ne cassez pas la chaîne ! 💪';
    } else {
      message = '🔥 $streakActuel jours de streak ! Impressionnant, continuez !';
    }

    await _programmerQuotidien(
      id: _baseIdMotivation,
      heure: 20,
      minute: 0,
      titre: '${streakActuel > 0 ? "🔥" : "⚠️"} Streak : $streakActuel jour${streakActuel > 1 ? "s" : ""}',
      corps: message,
      channel: _channelMotivation,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // UTILITAIRES
  // ═══════════════════════════════════════════════════════════

  /// Envoie une notification immédiate
  Future<void> _notificationImmediate({
    required int id,
    required String titre,
    required String corps,
    required String channel,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      titre,
      corps,
      _detailsNotification(channel, titre),
      payload: payload,
    );
  }

  /// Calcule le prochain horaire pour une notification quotidienne
  tz.TZDateTime _prochainHoraire(int heure, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, heure, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Crée les détails de notification (canaux Android)
  NotificationDetails _detailsNotification(String channelId, String titre) {
    final channelName = {
      _channelRoutine: 'Routines quotidiennes',
      _channelAlerte: 'Alertes élevage',
      _channelMotivation: 'Motivation',
    }[channelId] ?? 'CuniGest';

    final importance = channelId == _channelAlerte
        ? Importance.high
        : Importance.defaultImportance;

    final priority = channelId == _channelAlerte
        ? Priority.high
        : Priority.defaultPriority;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications CuniGest — $channelName',
        importance: importance,
        priority: priority,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        enableVibration: channelId == _channelAlerte,
        playSound: true,
      ),
    );
  }

  /// Annule toutes les notifications programmées
  Future<void> annulerToutes() async {
    await _plugin.cancelAll();
  }

  /// Annule une notification par son ID
  Future<void> annuler(int id) async {
    await _plugin.cancel(id);
  }

  /// Programme toutes les notifications (appelé au démarrage et après
  /// chaque modification des réglages)
  Future<void> programmerToutes() async {
    await programmerRappelsQuotidiens();
    await programmerAlertesReproduction();
    try {
      final profil = await DBHelper.instance.getProfil();
      await rappelerStreak(profil.streakActuel);
    } catch (e) {
      debugPrint('Erreur programmation streak : $e');
    }
  }

  /// Parse "HH:MM" en _Heure
  _Heure? _parseHeure(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return _Heure(h, m);
  }
}

class _Heure {
  final int h;
  final int m;
  const _Heure(this.h, this.m);
}
