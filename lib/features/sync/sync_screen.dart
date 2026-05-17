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
import '../../services/sync_service.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  SyncConfig _config = const SyncConfig();
  int _enAttente = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await DBHelper.instance.sync;
    final cfg = await repo.getConfig();
    final pending = await repo.countPending();
    if (mounted) {
      setState(() {
        _config = cfg;
        _enAttente = pending;
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
                _actionsCard(),
                const SizedBox(height: 12),
                _infoCard(),
                const SizedBox(height: 16),
              ],
            ),
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
    // Tenter de relier silencieusement à la prochaine occasion
    AccountService.instance.tenterLienCloud();
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
