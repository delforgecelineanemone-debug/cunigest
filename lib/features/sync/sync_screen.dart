// ──────────────────────────────────────────────────────────────
// Écran : Sauvegarde cloud (V2.6 — auto + compte unique)
// ──────────────────────────────────────────────────────────────
// Plus de bouton "Activer la sync" : la sauvegarde est automatique
// dès que le compte est créé. Cet écran ne sert qu'à :
//   - voir le statut (compte lié ou non, dernière sauvegarde)
//   - lancer une sauvegarde manuelle
//   - se déconnecter (efface les tokens locaux, garde le compte)
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/sync_entry.dart';
import '../../services/account_service.dart';
import '../../services/data_bus.dart';
import '../../services/sync_service.dart';
import '../../utils/reactive_state_mixin.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen>
    with ReactiveStateMixin<SyncScreen> {
  SyncConfig _config = const SyncConfig();
  int _enAttente = 0;
  int _conflictCount = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  List<String> get watchedTopics =>
      const [DataTopics.syncConfig, DataTopics.syncQueue];

  @override
  Future<void> onReactiveRefresh() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await DBHelper.instance.sync;
    final cfg = await repo.getConfig();
    final pending = await repo.countPending();
    final conflicts = await repo.countConflicts();
    if (mounted) {
      setState(() {
        _config = cfg;
        _enAttente = pending;
        _conflictCount = conflicts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CuAppBar(title: 'Sauvegarde cloud', emoji: '☁️', showActions: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusCard(),
                const SizedBox(height: 12),
                if (_conflictCount > 0) ...[
                  _conflictsCard(),
                  const SizedBox(height: 12),
                ],
                _actionsCard(),
                const SizedBox(height: 12),
                _infoCard(),
                const SizedBox(height: 16),
              ],
            ).responsive(),
    );
  }

  Widget _statusCard() {
    final hasAccount = _config.hasLocalAccount;
    final cloudLinked = _config.isCloudLinked;

    final IconData icon;
    final Color color;
    final String label;
    final String sousLabel;

    if (!hasAccount) {
      icon = Icons.error_outline;
      color = Colors.red;
      label = 'Aucun compte';
      sousLabel = 'Crée un compte au démarrage de l\'app';
    } else if (!cloudLinked) {
      icon = Icons.cloud_off;
      color = Colors.orange;
      label = 'Sauvegarde en attente';
      sousLabel = 'Connecte-toi à internet pour activer la sauvegarde';
    } else {
      icon = Icons.cloud_done;
      color = Colors.green;
      label = 'Sauvegarde active';
      sousLabel = _config.lastSyncAt != null
          ? 'Dernière sauvegarde : ${_formaterDate(_config.lastSyncAt!)}'
          : 'Pas encore sauvegardé';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(sousLabel,
                          style: TextStyle(
                              fontSize: 12, color: context.cuTextSecondary)),
                      if (_config.email != null && _config.email!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(_config.email!,
                            style: TextStyle(
                                fontSize: 11, color: context.cuTextSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_enAttente > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.upload, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '$_enAttente modification${_enAttente > 1 ? "s" : ""} pas encore sauvegardée${_enAttente > 1 ? "s" : ""}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync),
              title: const Text('Sauvegarder maintenant'),
              subtitle: const Text(
                'Force une sauvegarde immédiate (sinon automatique).',
                style: TextStyle(fontSize: 12),
              ),
              trailing: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _busy ? null : _sauvegarderMaintenant,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_upload, color: Colors.blue),
              title: const Text('Pousser tout le cheptel local'),
              subtitle: const Text(
                'Ajoute toutes tes données locales déjà créées à la file '
                'de sauvegarde — utile au premier branchement cloud.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _busy ? null : _pousserToutLeCheptel,
            ),
            if (_config.isCloudLinked) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_off, color: Colors.orange),
                title: const Text('Délier ce téléphone',
                    style: TextStyle(color: Colors.orange)),
                subtitle: const Text(
                  'Les sauvegardes ne seront plus envoyées tant que tu '
                  'ne te reconnectes pas.',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: _busy ? null : _delier,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte d'alerte affichée seulement si des conflits multi-device ont
  /// été enregistrés. Cliquable → ouvre le détail (liste + effacer).
  Widget _conflictsCard() {
    final n = _conflictCount;
    return Card(
      color: CuColors.warning.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: CuColors.warning.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        leading: const Icon(Icons.merge_type, color: CuColors.warning),
        title: Text('$n conflit${n > 1 ? "s" : ""} multi-appareil${n > 1 ? "s" : ""}'),
        subtitle: const Text(
          'Des modifications faites sur un autre téléphone ont remplacé les '
          'tiennes. Appuie pour voir lesquelles.',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showConflictsSheet,
      ),
    );
  }

  /// Bottom sheet listant les 20 derniers conflits et permettant de vider
  /// le journal.
  Future<void> _showConflictsSheet() async {
    final repo = await DBHelper.instance.sync;
    final conflicts = await repo.getRecentConflicts(limit: 20);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.merge_type, color: CuColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conflits multi-appareil',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await repo.clearConflicts();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) _load();
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Effacer'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Une ligne = une fiche modifiée sur un autre téléphone qui a '
                'écrasé ta version locale (la plus ancienne perd).',
                style: TextStyle(
                    fontSize: 12, color: context.cuTextSecondary),
              ),
              const Divider(height: 24),
              if (conflicts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Aucun conflit récent.')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scroll,
                    itemCount: conflicts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = conflicts[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 20),
                        title: Text('${c.tableName} #${c.rowId}'),
                        subtitle: Text(
                          'Local : ${_formaterDateCourte(c.localUpdatedAt)}\n'
                          'Reçu  : ${_formaterDateCourte(c.remoteUpdatedAt)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          _formaterDateCourte(c.detectedAt),
                          style: TextStyle(
                              fontSize: 10, color: context.cuTextSecondary),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formaterDateCourte(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À savoir',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            '• Toutes tes modifications sont sauvegardées automatiquement '
            'dès que tu as du réseau.\n'
            '• L\'app marche entièrement sans internet : tu peux saisir, '
            'consulter, modifier hors-ligne.\n'
            '• Si tu réinstalles l\'app, tu retrouves tes données en te '
            'reconnectant avec le même email et mot de passe.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────

  Future<void> _sauvegarderMaintenant() async {
    setState(() => _busy = true);
    final report = await SyncService.instance.synchroniser();
    if (!mounted) return;
    setState(() => _busy = false);
    _load();
    if (report.success) {
      showSuccessSnackBar(
          context, report.message ?? 'Sauvegarde terminée');
    } else {
      showErrorSnackBar(
          context, report.message ?? 'Sauvegarde impossible');
    }
  }

  /// Pousse TOUT l'élevage local vers le cloud (cheptel + ventes + finances
  /// + cages + pesées…). Modale premium avec progression en temps réel.
  Future<void> _pousserToutLeCheptel() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sauvegarder toutes mes données ?',
      message: 'Toutes tes données locales seront envoyées sur le cloud :\n\n'
          '• Cheptel (lapins, généalogie)\n'
          '• Reproduction (saillies, mises bas)\n'
          '• Santé (soins, vaccins)\n'
          '• Ventes & dépenses\n'
          '• Lots, pesées & distributions\n'
          '• Cages, bâtiments & clapiers\n\n'
          'Tu peux le refaire à tout moment sans risque.',
      confirmLabel: 'Tout sauvegarder',
      cancelLabel: 'Annuler',
    );
    if (!ok || !mounted) return;

    // 1. On enqueue tout en arrière-plan AVANT d'afficher la modale.
    //    `forceAll: true` → re-pousse même les rows déjà connues de la
    //    sync_queue (cas typique : changement d'utilisateur cloud).
    // _busy reste true jusqu'à la fin complète de la sync (modale comprise)
    // pour éviter tout tap concurrent sur "Sauvegarder maintenant".
    setState(() => _busy = true);
    final added =
        await SyncService.instance.enqueueAllExistingRows(forceAll: true);
    if (!mounted) {
      setState(() => _busy = false);
      return;
    }

    if (added == 0) {
      _load();
      // Pas de nouveau à pousser → on lance quand même une sync (pour le pull
      // + vider la queue si éléments en attente).
      final modalResult = await _showProgressModal();
      _load();
      setState(() => _busy = false);
      if (!mounted) return;
      if (modalResult?.success ?? false) {
        showSuccessSnackBar(context, 'Tout est à jour ✓');
      }
      return;
    }

    // 2. Ouvre la modale de progression et lance la sync.
    final report = await _showProgressModal();
    _load();
    setState(() => _busy = false);
    if (!mounted) return;
    if (report == null) return; // dismissed
    if (report.success) {
      showSuccessSnackBar(context,
          'Sauvegarde complète : ${report.pushed} élément${report.pushed > 1 ? "s" : ""} envoyé${report.pushed > 1 ? "s" : ""}.');
    } else {
      showErrorSnackBar(context,
          report.message ?? 'Sauvegarde partielle. Réessaye dans un moment.');
    }
  }

  /// Affiche une modale non-dismissible avec progression en temps réel.
  /// Lance la sync et retourne son résultat à la fermeture.
  Future<SyncReport?> _showProgressModal() async {
    final progressNotifier = ValueNotifier<SyncProgress>(
      const SyncProgress(
        phase: 'preparing',
        processed: 0,
        total: 0,
        message: 'Préparation…',
      ),
    );
    // Capturé AVANT l'await pour rester valide si le widget est unmounted
    // pendant la sync (le NavigatorState outlive le State de cet écran).
    final nav = Navigator.of(context, rootNavigator: true);
    SyncReport? finalReport;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.blue),
              SizedBox(width: 12),
              Text('Sauvegarde en cours'),
            ],
          ),
          content: ValueListenableBuilder<SyncProgress>(
            valueListenable: progressNotifier,
            builder: (_, progress, __) {
              return SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(progress.message,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    if (progress.fraction != null)
                      LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                      )
                    else
                      const LinearProgressIndicator(minHeight: 6),
                    if (progress.total > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${progress.processed} / ${progress.total}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    finalReport = await SyncService.instance.synchroniser(
      onProgress: (p) {
        progressNotifier.value = p;
      },
    );

    if (nav.mounted && nav.canPop()) nav.pop();
    progressNotifier.dispose();
    return finalReport;
  }

  Future<void> _delier() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Délier ce téléphone ?',
      message: 'Tes données locales restent intactes. Tu pourras te '
          'reconnecter plus tard pour relier ce téléphone à ton compte.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await SyncService.instance.signOut();
    // Note : on ne supprime pas le compte local — l'utilisateur peut
    // toujours utiliser l'app offline. Au prochain démarrage, il devra
    // saisir son mot de passe (login normal).
    if (!mounted) return;
    setState(() => _busy = false);
    _load();
    showSuccessSnackBar(context, 'Téléphone délié');
    // Tenter de relier silencieusement à la prochaine occasion.
    // unawaited : le résultat n'a pas besoin d'être attendu, l'écran sera
    // rafraîchi lors du prochain pull.
    unawaited(AccountService.instance.tenterLienCloud());
  }

  String _formaterDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso.substring(0, 16).replaceAll('T', ' ');
    }
  }
}
