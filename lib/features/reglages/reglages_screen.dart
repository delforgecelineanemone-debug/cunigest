// ──────────────────────────────────────────────────────────────
// Écran : Réglages
// ──────────────────────────────────────────────────────────────
// Centralise les préférences de l'application :
// - Sauvegarde / restauration de la base de données
// - Activation/désactivation des notifications
// - Activation/désactivation de la gamification (streak/badges)
// - Tolérance du streak (jours de pause autorisés)
// - Heures de notifications quotidiennes
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/db_helper.dart';
import '../../models/reglages.dart';
import '../../providers/state_providers.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/seed_test_data_service.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../auth/users_screen.dart';
import '../sync/sync_screen.dart';
import 'a_propos_screen.dart';

class ReglagesScreen extends ConsumerStatefulWidget {
  const ReglagesScreen({super.key});

  @override
  ConsumerState<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends ConsumerState<ReglagesScreen> {
  final db = DBHelper.instance;
  Reglages _reglages = const Reglages();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await db.getReglages();
    if (mounted) {
      setState(() {
        _reglages = r;
        _loading = false;
      });
    }
  }

  Future<void> _save(Reglages r) async {
    await db.updateReglages(r);
    setState(() => _reglages = r);
    // Met à jour le ReglagesState (pour MaterialApp themeMode notamment)
    if (mounted) await ref.read(reglagesProvider.notifier).refresh();
    // Re-programmer les notifications selon les nouveaux réglages
    await NotificationService.instance.programmerToutes();
  }

  Future<void> _choisirTheme() async {
    final choix = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Apparence'),
        children: kThemeModes
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, m),
                  child: Row(
                    children: [
                      Icon(
                        m == 'dark'
                            ? Icons.dark_mode
                            : m == 'light'
                                ? Icons.light_mode
                                : Icons.brightness_auto,
                      ),
                      const SizedBox(width: 12),
                      Text(themeModeLabel(m)),
                      if (_reglages.themeMode == m) ...[
                        const Spacer(),
                        const Icon(Icons.check, color: AppTheme.primary),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (choix != null) await _save(_reglages.copyWith(themeMode: choix));
  }

  Future<void> _choisirDevise() async {
    final choix = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Devise'),
        children: kDevises
            .map((d) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, d),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined),
                      const SizedBox(width: 12),
                      Text(d),
                      if (_reglages.devise == d) ...[
                        const Spacer(),
                        const Icon(Icons.check, color: AppTheme.primary),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (choix != null) await _save(_reglages.copyWith(devise: choix));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final estAdmin = session.isAdmin || !session.isAuthenticated;

    return Scaffold(
      appBar: const CuAppBar(
        title: 'Réglages',
        emoji: '⚙️',
        showSettings: false,
        accent: CuColors.accentAdmin,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ── Section Sauvegarde ──
                _sectionTitle('💾 Sauvegarde des données'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.save_alt, color: AppTheme.primary),
                        title: const Text('Créer une sauvegarde'),
                        subtitle: const Text('Exporter votre base de données'),
                        trailing: _busy
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right),
                        onTap: _busy ? null : _exporter,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.share, color: AppTheme.primary),
                        title: const Text('Sauvegarder & partager'),
                        subtitle: const Text('Chiffré par mot de passe — portable sur tout appareil'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : _exporterEtPartager,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.folder_open, color: Colors.orange),
                        title: const Text('Restaurer une sauvegarde'),
                        subtitle: const Text('Remplace les données actuelles !'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : _restaurer,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: const Text('Mes sauvegardes locales'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : _voirSauvegardes,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // ── Section Apparence (V2.3) ──
                _sectionTitle('🎨 Apparence'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          _reglages.themeMode == 'dark'
                              ? Icons.dark_mode
                              : _reglages.themeMode == 'light'
                                  ? Icons.light_mode
                                  : Icons.brightness_auto,
                          color: AppTheme.primary,
                        ),
                        title: const Text('Thème'),
                        subtitle: Text(themeModeLabel(_reglages.themeMode)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _choisirTheme,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.payments_outlined, color: AppTheme.primary),
                        title: const Text('Devise'),
                        subtitle: Text(_reglages.devise),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _choisirDevise,
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        secondary: const Icon(Icons.wb_sunny, color: Color(0xFFF59E0B)),
                        title: const Text('Mode soleil ☀️'),
                        subtitle: const Text('Texte +25 % · Thème clair forcé (terrain)'),
                        value: _reglages.modeSoleil,
                        onChanged: (v) =>
                            _save(_reglages.copyWith(modeSoleil: v)),
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        secondary: const Icon(Icons.back_hand_outlined, color: Color(0xFF546E7A)),
                        title: const Text('Mode gants 🧤'),
                        subtitle: const Text('Boutons et icônes agrandis +15 % (gants de travail)'),
                        value: _reglages.modeGants,
                        onChanged: (v) =>
                            _save(_reglages.copyWith(modeGants: v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // ── Section Notifications ──
                _sectionTitle('🔔 Notifications'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Notifications activées'),
                        subtitle: const Text(
                            'Rappels quotidiens et alertes de reproduction'),
                        value: _reglages.notificationsActives,
                        onChanged: (v) =>
                            _save(_reglages.copyWith(notificationsActives: v)),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.wb_sunny_outlined),
                        title: const Text('Rappel matin'),
                        subtitle: Text(_reglages.heureRappelMatin),
                        enabled: _reglages.notificationsActives,
                        onTap: _reglages.notificationsActives
                            ? () => _changerHeure('matin')
                            : null,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.lunch_dining),
                        title: const Text('Rappel midi'),
                        subtitle: Text(_reglages.heureRappelMidi),
                        enabled: _reglages.notificationsActives,
                        onTap: _reglages.notificationsActives
                            ? () => _changerHeure('midi')
                            : null,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.nightlight_outlined),
                        title: const Text('Rappel soir'),
                        subtitle: Text(_reglages.heureRappelSoir),
                        enabled: _reglages.notificationsActives,
                        onTap: _reglages.notificationsActives
                            ? () => _changerHeure('soir')
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // ── Section Gamification ──
                _sectionTitle('🎮 Gamification'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Activer le système de routine'),
                        subtitle: const Text(
                            'Streaks, badges, niveaux, points. Décochez si vous '
                            'préférez une interface professionnelle sobre.'),
                        value: _reglages.gamificationActive,
                        onChanged: (v) =>
                            _save(_reglages.copyWith(gamificationActive: v)),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Tolérance du streak'),
                        subtitle: Text(
                            '${_reglages.toleranceStreakJours} jour${_reglages.toleranceStreakJours > 1 ? "s" : ""} de pause autorisé${_reglages.toleranceStreakJours > 1 ? "s" : ""} sans casser le streak'),
                        enabled: _reglages.gamificationActive,
                        onTap: _reglages.gamificationActive ? _changerTolerance : null,
                      ),
                    ],
                  ),
                ),

                if (estAdmin) ...[
                  const SizedBox(height: 16),
                  // ── Section V2 : utilisateurs et cloud (admin uniquement) ──
                  _sectionTitle('🚀 Avancé (V2)'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.people, color: AppTheme.primary),
                          title: const Text('Utilisateurs & rôles'),
                          subtitle: const Text('Multi-utilisateur avec PIN'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const UsersScreen()));
                          },
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.cloud_sync, color: Color(0xFF0277BD)),
                          title: const Text('Sauvegarde cloud'),
                          subtitle: const Text('Statut et options de sauvegarde'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SyncScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // ── Section À propos ──
                _sectionTitle('🧪 Test & développement'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.science_outlined,
                        color: Colors.deepPurple),
                    title: const Text('Insérer des données de test'),
                    subtitle: const Text(
                        '12 lapins variés + cages + saillies + lots + ventes pour tester l\'app'),
                    trailing: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _insererDonneesTest,
                  ),
                ),
                const SizedBox(height: 16),

                _sectionTitle('ℹ️ À propos'),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.eco),
                        title: Text('CuniGest'),
                        subtitle: Text('Version 2.5.0 — Gestion cunicole pro'),
                      ),
                      const Divider(height: 0),
                      const ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Données 100 % locales'),
                        subtitle: Text(
                            'Aucune donnée n\'est envoyée sur internet. Pensez à sauvegarder régulièrement !'),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Confidentialité & licences'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AProposScreen()));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700)),
      );

  Future<void> _exporter() async {
    setState(() => _busy = true);
    final r = await BackupService.instance.exporter();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.success) {
      showSuccessSnackBar(context, r.message ?? 'Sauvegarde créée');
    } else {
      showErrorSnackBar(context, r.message ?? 'Échec');
    }
  }

  Future<void> _insererDonneesTest() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Insérer des données de test ?',
      message:
          'Cette action ajoute 12 lapins, des cages, des saillies, des lots, '
          'des ventes et des dépenses fictifs pour tester l\'application.\n\n'
          'Idempotent : si déjà inséré, rien ne sera ajouté.',
      confirmLabel: 'Insérer',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final msg = await SeedTestDataService.seed();
      if (!mounted) return;
      setState(() => _busy = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Données de test'),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, 'Erreur insertion : $e');
    }
  }

  Future<void> _exporterEtPartager() async {
    final motDePasse = await _demanderMotDePasse(confirmNeeded: true);
    if (motDePasse == null || !mounted) return;

    setState(() => _busy = true);
    final r = await BackupService.instance.exporterEtPartagerChiffre(motDePasse);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.success) {
      showErrorSnackBar(context, r.message ?? 'Échec');
    } else {
      showSuccessSnackBar(context, r.message ?? 'Sauvegarde partagée');
    }
  }

  Future<void> _restaurer() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Restaurer une sauvegarde ?',
      message:
          'Les données ACTUELLES seront REMPLACÉES par celles de la sauvegarde.\n\n'
          'Une copie de sécurité de la base courante sera créée automatiquement.',
      confirmLabel: 'Continuer',
      confirmColor: Colors.orange,
    );
    if (!ok || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir une sauvegarde CuniGest (.db ou .cunigest)',
      type: FileType.any,
    );
    if (picked == null || picked.files.isEmpty || picked.files.first.path == null) {
      return;
    }

    final filePath = picked.files.first.path!;

    // Auto-détecter le format et demander le mot de passe si .cunigest
    String? motDePasse;
    final estChiffre = await BackupService.instance.estFormatChiffre(filePath);
    if (estChiffre) {
      if (!mounted) return;
      motDePasse = await _demanderMotDePasse(confirmNeeded: false);
      if (motDePasse == null || !mounted) return;
    }

    setState(() => _busy = true);
    final result = await BackupService.instance.restaurer(filePath, motDePasse: motDePasse);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.success) {
      showSuccessSnackBar(context, result.message ?? 'Restauration réussie');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      showErrorSnackBar(context, result.message ?? 'Échec');
    }
  }

  /// Dialog de saisie du mot de passe pour le backup chiffré.
  /// [confirmNeeded] : true = exporte (2 champs), false = restaure (1 champ).
  Future<String?> _demanderMotDePasse({required bool confirmNeeded}) async {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmNeeded ? 'Protéger la sauvegarde' : 'Déverrouiller la sauvegarde'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirmNeeded)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Choisissez un mot de passe. Vous en aurez besoin pour restaurer cette sauvegarde.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              TextFormField(
                controller: ctrl1,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              if (confirmNeeded) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: ctrl2,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v != ctrl1.text)
                      ? 'Les mots de passe ne correspondent pas'
                      : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl1.text);
              }
            },
            child: Text(confirmNeeded ? 'Chiffrer' : 'Restaurer'),
          ),
        ],
      ),
    );

    ctrl1.dispose();
    ctrl2.dispose();
    return result;
  }

  Future<void> _voirSauvegardes() async {
    final files = await BackupService.instance.listerSauvegardes();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            const Center(
                child: Text('Sauvegardes locales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            if (files.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Aucune sauvegarde locale.',
                    style: TextStyle(color: Colors.grey)),
              ))
            else
              ...files.map((f) {
                final name = f.path.split('/').last.split('\\').last;
                final size = (f.lengthSync() / 1024).toStringAsFixed(1);
                final date = f.statSync().modified;
                final isCunigest = name.endsWith('.cunigest');
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isCunigest ? Icons.lock_outline : Icons.folder_zip,
                      color: isCunigest ? Colors.teal : AppTheme.primary,
                    ),
                    title: Text(name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('$size Ko — ${date.day}/${date.month}/${date.year} ${date.hour}h${date.minute.toString().padLeft(2, '0')}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        // Capture Navigator AVANT l'await pour éviter
                        // l'usage de BuildContext post-async.
                        final navigator = Navigator.of(context);
                        final confirm = await showConfirmDialog(context,
                            title: 'Supprimer cette sauvegarde ?',
                            message: name,
                            confirmColor: AppTheme.error);
                        if (!confirm) return;
                        await BackupService.instance.supprimerSauvegarde(f.path);
                        navigator.pop();
                        _voirSauvegardes();
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _changerHeure(String moment) async {
    String current;
    switch (moment) {
      case 'matin':
        current = _reglages.heureRappelMatin;
        break;
      case 'midi':
        current = _reglages.heureRappelMidi;
        break;
      default:
        current = _reglages.heureRappelSoir;
    }
    final parts = current.split(':');
    final h = int.tryParse(parts[0]) ?? 7;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (picked == null) return;
    final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

    Reglages updated;
    switch (moment) {
      case 'matin':
        updated = _reglages.copyWith(heureRappelMatin: str);
        break;
      case 'midi':
        updated = _reglages.copyWith(heureRappelMidi: str);
        break;
      default:
        updated = _reglages.copyWith(heureRappelSoir: str);
    }
    await _save(updated);
  }

  Future<void> _changerTolerance() async {
    final choisi = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Tolérance du streak'),
        children: [
          for (final n in [0, 1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, n),
              child: Text(n == 0
                  ? 'Aucune (streak strict)'
                  : '$n jour${n > 1 ? "s" : ""} de pause autorisé${n > 1 ? "s" : ""}'),
            ),
        ],
      ),
    );
    if (choisi == null) return;
    await _save(_reglages.copyWith(toleranceStreakJours: choisi));
  }
}
