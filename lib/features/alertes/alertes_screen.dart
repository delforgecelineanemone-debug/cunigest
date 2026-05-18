// ──────────────────────────────────────────────────────────────
// Écran : Centre de Notifications (Alertes Intelligentes)
// ──────────────────────────────────────────────────────────────
// Affiche toutes les alertes générées automatiquement :
// - Alertes de reproduction (palpation, nid, mise bas)
// - Rappels de vaccins
// - Alertes de stocks critiques
// - Tâches en retard
//
// Les alertes sont triées par priorité : critique > important > normal
// L'éleveur peut les marquer comme "traitées" une par une.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/alerte.dart';
import '../../models/lot.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../lots/lot_individualisation_screen.dart';

class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});
  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> {
  final db = DBHelper.instance;
  List<Alerte> _alertes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Générer les nouvelles alertes basées sur les données
    await db.genererAlertesReproduction();
    // Nettoyer les anciennes alertes traitées
    await db.nettoyerAlertes();
    // Charger les alertes actives
    final alertes = await db.getAlertesActives();
    if (mounted) setState(() { _alertes = alertes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final critiques = _alertes.where((a) => a.priorite == 'critique').length;
    final importantes = _alertes.where((a) => a.priorite == 'important').length;
    final normales = _alertes.where((a) => a.priorite == 'normal').length;

    return Scaffold(
      appBar: CuAppBar(
        title: 'Notifications',
        emoji: '🔔',
        showNotifications: false,
        extraActions: [
          if (_alertes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Tout marquer comme traité',
              onPressed: _toutTraiter,
            ),
        ],
      ),
      body: Column(
        children: [
          // En-tête avec compteurs
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _compteur('🔴 Urgentes', critiques, Colors.red),
                const SizedBox(width: 8),
                _compteur('🟠 Importantes', importantes, Colors.orange),
                const SizedBox(width: 8),
                _compteur('🟢 Normales', normales, Colors.green),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _alertes.isEmpty
                    ? const EmptyState(
                        message: 'Aucune alerte en cours.\nTout est sous contrôle ! ✅',
                        icon: Icons.notifications_off,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _alertes.length,
                          itemBuilder: (_, i) => _alerteCard(_alertes[i]),
                        ),
                      ),
          ),
        ],
      ).responsive(),
    );
  }

  Widget _compteur(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: count > 0
              ? color.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: count > 0
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: count > 0 ? color : Colors.grey,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: count > 0 ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _alerteCard(Alerte a) {
    final prioriteColor = {
      'critique': Colors.red,
      'important': Colors.orange,
      'normal': Colors.green,
    }[a.priorite] ?? Colors.grey;

    return Dismissible(
      key: Key('alerte_${a.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white, size: 30),
      ),
      onDismissed: (_) async {
        await db.marquerAlerteTraitee(a.id!);
        _load();
        if (mounted) showSuccessSnackBar(context, 'Alerte traitée ✅');
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: a.priorite == 'critique' ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: a.priorite == 'critique'
              ? const BorderSide(color: Colors.red, width: 1.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icône type
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: prioriteColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(a.typeIcon, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  // Titre
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.titre,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: a.priorite == 'critique' ? Colors.red.shade700 : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: prioriteColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a.prioriteLabel,
                                style: TextStyle(fontSize: 9, color: prioriteColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 11, color: context.cuTextSecondary),
                            const SizedBox(width: 3),
                            Text(
                              formatDate(a.dateAlerte),
                              style: TextStyle(fontSize: 11, color: context.cuTextSecondary),
                            ),
                            if (a.estEnRetard) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('EN RETARD', style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (a.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  a.message!,
                  style: TextStyle(fontSize: 13, color: context.cuTextPrimary),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (a.type.startsWith('sexage'))
                    TextButton.icon(
                      onPressed: () => _ouvrirIndividualisation(a),
                      icon: const Icon(Icons.label_outline, size: 16),
                      label: const Text('Individualiser →',
                          style: TextStyle(fontSize: 12)),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      await db.marquerAlerteTraitee(a.id!);
                      _load();
                      if (mounted) showSuccessSnackBar(context, 'Alerte traitée ✅');
                    },
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('C\'est fait !', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirIndividualisation(Alerte a) async {
    Lot? lot;
    if (a.referenceType == 'lot' && a.referenceId != null) {
      final repo = await db.lots;
      lot = await repo.getById(a.referenceId!);
    } else if (a.referenceType == 'saillie' && a.referenceId != null) {
      // Chercher le lot via la saillie
      final saillies = await db.getAllSaillies();
      try {
        final s = saillies.firstWhere((x) => x.id == a.referenceId);
        if (s.lotId != null) {
          final repo = await db.lots;
          lot = await repo.getById(s.lotId!);
        }
      } catch (_) {/* saillie introuvable */}
    }
    if (lot == null) {
      if (mounted) {
        showErrorSnackBar(context,
            'Lot introuvable. La saillie n\'a peut-être pas généré de lot.');
      }
      return;
    }
    if (lot.statut == 'individualise') {
      if (mounted) {
        showErrorSnackBar(context, 'Ce lot a déjà été individualisé.');
      }
      return;
    }
    if (!mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => LotIndividualisationScreen(lot: lot!)),
    );
    if (ok == true) _load();
  }

  Future<void> _toutTraiter() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tout traiter ?',
      message: 'Marquer toutes les ${_alertes.length} alertes comme traitées ?',
    );
    if (ok) {
      for (final a in _alertes) {
        await db.marquerAlerteTraitee(a.id!);
      }
      _load();
      if (mounted) showSuccessSnackBar(context, 'Toutes les alertes traitées ✅');
    }
  }
}
