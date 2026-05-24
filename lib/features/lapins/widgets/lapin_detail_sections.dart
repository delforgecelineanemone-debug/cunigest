// ──────────────────────────────────────────────────────────────
// Sections de la fiche détaillée d'un lapin (P1.9 — découpe)
// ──────────────────────────────────────────────────────────────
// Sous-widgets de présentation extraits de lapin_detail_screen.dart
// pour ramener l'écran principal sous la barre des 300 lignes.
// Ces widgets sont purement déclaratifs : ils reçoivent des données
// + callbacks, n'accèdent jamais à la base directement.
// ──────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import '../../../models/batiment.dart';
import '../../../models/cage.dart';
import '../../../models/clapier.dart';
import '../../../models/lapin.dart';
import '../../../models/mouvement_cage.dart';
import '../../../models/pesee_lapin.dart';
import '../../../models/soin.dart';
import '../../../ui/cu_ui.dart';
import '../../../utils/theme.dart';
import '../../../widgets/growth_chart.dart';
import '../../sante/soin_form_screen.dart';

// ─────────────────────────────────────────────
// Modèle de données interne — événement de timeline
// ─────────────────────────────────────────────

class TimelineEvent {
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  TimelineEvent({
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

// ─────────────────────────────────────────────
// Cartes & sections de la fiche
// ─────────────────────────────────────────────

class LapinHeaderCard extends StatelessWidget {
  const LapinHeaderCard({super.key, required this.lapin, required this.color});
  final Lapin lapin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = lapin.photoPath != null && File(lapin.photoPath!).existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Semantics(
              image: hasPhoto,
              label: hasPhoto
                  ? 'Photo du lapin'
                  : (lapin.sexe == 'male' ? 'Lapin mâle' : 'Lapine femelle'),
              child: Hero(
                tag: 'lapin_${lapin.id}',
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      hasPhoto ? null : color.withValues(alpha: 0.15),
                  backgroundImage:
                      hasPhoto ? FileImage(File(lapin.photoPath!)) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          lapin.sexe == 'male' ? '♂' : '♀',
                          style: TextStyle(fontSize: 36, color: color),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lapin.displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(lapin.numeroBague,
                      style: TextStyle(color: context.cuTextSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    DetailBadge(label: lapin.statutLabel, color: statutColor(lapin.statut)),
                    DetailBadge(label: lapin.sexeLabel, color: color),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DelaiAttenteBanner extends StatelessWidget {
  const DelaiAttenteBanner({super.key, required this.delai});
  final Soin delai;

  @override
  Widget build(BuildContext context) {
    final fin = delai.finDelaiAttente;
    final finStr = fin != null ? formatDate(fin.toIso8601String().substring(0, 10)) : '?';
    final restant = fin != null ? fin.difference(DateTime.now()).inDays : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CuColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CuColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.medication_liquid, color: CuColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⏱️ Délai d\'attente médicament en cours',
                    style: TextStyle(fontWeight: FontWeight.bold, color: CuColors.warning)),
                Text("Jusqu'au $finStr (${restant > 0 ? '$restant jours restants' : "expire aujourd'hui"})"),
                Text('Soin : ${delai.typeSoin} le ${formatDate(delai.dateSoin)}',
                    style: TextStyle(fontSize: 12, color: context.cuTextSecondary)),
                const SizedBox(height: 4),
                const Text('Vente pour consommation INTERDITE pendant ce délai.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: CuColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.lapin, this.cage, this.clapier, this.batiment,
    required this.onCageTap,
  });
  final Lapin lapin;
  final Cage? cage;
  final Clapier? clapier;
  final Batiment? batiment;
  final VoidCallback onCageTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            InfoRow(icon: Icons.category, label: 'Race', value: lapin.race ?? 'Non renseigné'),
            InfoRow(icon: Icons.palette, label: 'Couleur', value: lapin.couleur ?? 'Non renseigné'),
            _buildCageRow(context),
            InfoRow(icon: Icons.monitor_weight, label: 'Poids',
                value: lapin.poids != null ? '${lapin.poids!.toStringAsFixed(2)} kg' : 'Non renseigné'),
            InfoRow(icon: Icons.cake, label: 'Naissance',
                value: lapin.dateNaissance != null ? formatDate(lapin.dateNaissance) : 'Non renseigné'),
            InfoRow(icon: Icons.access_time, label: 'Âge', value: lapin.ageDisplay),
            if (lapin.notes != null) ...[
              const Divider(),
              InfoRow(icon: Icons.notes, label: 'Notes', value: lapin.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCageRow(BuildContext context) {
    if (cage != null) {
      final color = cageStatutColor(cage!.statut);
      return InkWell(
        onTap: onCageTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(cageStatutIcon(cage!.statut), size: 18, color: color),
              const SizedBox(width: 10),
              Text('Cage : ', style: TextStyle(color: context.cuTextSecondary, fontSize: 13)),
              Expanded(
                child: Text(
                  '${cage!.numero} (${batiment?.nom ?? "?"} • ${clapier?.nom ?? "?"})',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                      color: color, decoration: TextDecoration.underline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      );
    }
    return InfoRow(
      icon: Icons.grid_view, label: 'Cage',
      value: lapin.cageLegacy != null && lapin.cageLegacy!.isNotEmpty
          ? '${lapin.cageLegacy} (texte libre — non liée)'
          : 'Aucune cage assignée',
    );
  }
}

class GenealogieCard extends StatelessWidget {
  const GenealogieCard({super.key, this.pere, this.mere, required this.onNavigate});
  final Lapin? pere;
  final Lapin? mere;
  final void Function(Lapin) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🌳 Généalogie',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _parentRow(context, 'Père', pere, CuColors.sexeMale, Icons.male),
            _parentRow(context, 'Mère', mere, CuColors.sexeFemelle, Icons.female),
          ],
        ),
      ),
    );
  }

  Widget _parentRow(BuildContext ctx, String label, Lapin? parent, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text('$label : ', style: TextStyle(color: ctx.cuTextSecondary, fontSize: 13)),
          Expanded(
            child: parent != null
                ? InkWell(
                    onTap: () => onNavigate(parent),
                    child: Text(
                      '${parent.displayName} (${parent.numeroBague})',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                          color: color, decoration: TextDecoration.underline),
                    ),
                  )
                : const Text('Inconnu',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class PeseesCard extends StatelessWidget {
  const PeseesCard({
    super.key,
    required this.pesees, required this.onAjouter, required this.onSupprimer,
  });
  final List<PeseeLapin> pesees;
  final VoidCallback onAjouter;
  final void Function(PeseeLapin) onSupprimer;

  /// GMQ global (g/j) sur toute la période. Null si < 2 pesées ou 0 jour.
  int? get _gmqGlobal {
    if (pesees.length < 2) return null;
    final first = pesees.first;
    final last = pesees.last;
    final days = DateTime.parse(last.datePesee)
        .difference(DateTime.parse(first.datePesee))
        .inDays;
    if (days == 0) return null;
    return ((last.poids - first.poids) * 1000 / days).round();
  }

  /// GMQ sur les 2 dernières pesées (g/j). Null si < 2 pesées ou même jour.
  int? get _gmqRecent {
    if (pesees.length < 2) return null;
    final prev = pesees[pesees.length - 2];
    final last = pesees.last;
    final days = DateTime.parse(last.datePesee)
        .difference(DateTime.parse(prev.datePesee))
        .inDays;
    if (days == 0) return null;
    return ((last.poids - prev.poids) * 1000 / days).round();
  }

  @override
  Widget build(BuildContext context) {
    final gmqG = _gmqGlobal;
    final gmqR = _gmqRecent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚖️ Pesées',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Pesée'),
                  onPressed: onAjouter,
                ),
              ],
            ),
            if (pesees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: Text('Aucune pesée enregistrée pour ce lapin.',
                        style: TextStyle(color: Colors.grey))),
              )
            else ...[
              // ── Stats GMQ ──────────────────────────────────────────
              if (gmqG != null || gmqR != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (gmqG != null)
                        StatChip(
                          label: 'GMQ global',
                          value: '$gmqG g/j',
                          color: _gmqColor(gmqG),
                        ),
                      if (gmqR != null && pesees.length >= 3)
                        StatChip(
                          label: 'GMQ récent',
                          value: '$gmqR g/j',
                          color: _gmqColor(gmqR),
                        ),
                    ],
                  ),
                ),
              // ── Courbe de croissance ───────────────────────────────
              if (pesees.length >= 2) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GrowthChart(
                    title: '📈 Croissance', unit: 'kg',
                    points: [for (final p in pesees) (DateTime.parse(p.datePesee), p.poids)],
                  ),
                ),
                const Divider(height: 12),
              ],
              // ── Liste pesées ───────────────────────────────────────
              ...pesees.reversed.take(5).map((p) {
                final idx = pesees.indexOf(p);
                final prev = idx > 0 ? pesees[idx - 1] : null;
                final delta = prev != null ? p.poids - prev.poids : null;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.scale, color: AppTheme.primary),
                  title: Text('${p.poids.toStringAsFixed(2)} kg'),
                  subtitle: Text(formatDate(p.datePesee)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (delta != null)
                        Text(
                          '${delta >= 0 ? '+' : ''}${(delta * 1000).round()} g',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: delta >= 0 ? CuColors.success : CuColors.danger,
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: CuColors.danger),
                        tooltip: 'Supprimer',
                        onPressed: () => onSupprimer(p),
                      ),
                    ],
                  ),
                );
              }),
              if (pesees.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text('+ ${pesees.length - 5} pesée(s) plus anciennes',
                      style: TextStyle(fontSize: 12, color: context.cuTextSecondary)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Code couleur GMQ : ≥30 g/j bon, ≥20 moyen, sinon faible.
  Color _gmqColor(int gmq) => gmq >= 30
      ? CuColors.success
      : gmq >= 20
          ? CuColors.warning
          : CuColors.danger;
}

class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class RentabiliteCard extends StatelessWidget {
  const RentabiliteCard({
    super.key,
    required this.lapin, required this.soins,
    required this.depenses, required this.ventes,
  });
  final Lapin lapin;
  final List<Soin> soins;
  final double depenses;
  final double ventes;

  @override
  Widget build(BuildContext context) {
    final coutSoins = soins.fold<double>(0, (s, x) => s + (x.cout ?? 0));
    final prixAchat = lapin.prixAchat ?? 0.0;
    final coutTotal = prixAchat + coutSoins + depenses;
    final marge = ventes - coutTotal;
    final aucuneDonnee = coutTotal == 0 && ventes == 0;
    final positif = marge >= 0;
    final couleur = positif ? AppTheme.primary : AppTheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.moduleFinance),
              SizedBox(width: 8),
              Text('💰 Rentabilité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            if (aucuneDonnee)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Aucun coût ni vente enregistré pour ce lapin. Renseigne le prix d\'achat (formulaire) ou impute des dépenses pour voir la rentabilité.',
                  style: TextStyle(fontSize: 12, color: context.cuTextSecondary),
                ),
              )
            else ...[
              _ligne(context, 'Prix d\'achat', prixAchat, prixAchat > 0 ? null : context.cuTextSecondary),
              _ligne(context, 'Coût des soins', coutSoins, coutSoins > 0 ? null : context.cuTextSecondary),
              _ligne(context, 'Dépenses imputées', depenses, depenses > 0 ? null : context.cuTextSecondary),
              const Divider(height: 16),
              _ligne(context, 'Coût total', coutTotal, AppTheme.moduleStock, bold: true),
              _ligne(context, 'Recettes', ventes, AppTheme.moduleFinance, bold: true),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: couleur.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(positif ? Icons.check_circle : Icons.warning_amber,
                        size: 16, color: couleur),
                    const SizedBox(width: 8),
                    const Text('Marge nette',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(formatMontant(marge),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ligne(BuildContext context, String label, double valeur, Color? color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: color ?? context.cuTextPrimary,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          ),
          Text(formatMontant(valeur),
              style: TextStyle(fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.events});
  final List<TimelineEvent> events;

  static const _maxItems = 15;

  @override
  Widget build(BuildContext context) {
    final items = events.take(_maxItems).toList();
    final reste = events.length - items.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Historique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++)
              _buildRow(context, items[i], isLast: i == items.length - 1 && reste == 0),
            if (reste > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 30),
                child: Text(
                  '+ $reste événement${reste > 1 ? "s" : ""} plus ancien${reste > 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 12, color: context.cuTextSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, TimelineEvent e, {required bool isLast}) {
    // A11y : chaque événement est annoncé d'un bloc — l'icône colorée
    // seule serait invisible pour un lecteur d'écran.
    final dateStr = formatDate(e.date.toIso8601String().substring(0, 10));
    return Semantics(
      label: '${e.title}'
          '${e.subtitle.isNotEmpty ? ", ${e.subtitle}" : ""}, $dateStr',
      excludeSemantics: true,
      child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(e.icon, size: 14, color: e.color),
              ),
              if (!isLast)
                Expanded(child: Container(
                    width: 1, color: Colors.grey.withValues(alpha: 0.25))),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (e.subtitle.isNotEmpty)
                    Text(e.subtitle,
                        style: TextStyle(fontSize: 11, color: context.cuTextSecondary)),
                  Text(formatDate(e.date.toIso8601String().substring(0, 10)),
                      style: TextStyle(fontSize: 11, color: context.cuTextSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class HistoriqueCagesSection extends StatelessWidget {
  const HistoriqueCagesSection({super.key, required this.mvts});
  final List<MouvementCage> mvts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📜 Historique des cages',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        ...mvts.take(10).map((m) {
          final isSortie = m.cageDestinationId == null;
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Icon(isSortie ? Icons.logout : Icons.move_to_inbox,
                  color: isSortie ? CuColors.timelineMouvementSortie : AppTheme.primary,
                  size: 20),
              title: Text(
                isSortie ? 'Sortie de cage'
                    : (m.cageOrigineId == null ? 'Premier placement' : 'Déplacement entre cages'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${formatDate(m.date)}${m.motif != null ? " • ${m.motif}" : ""}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class SoinsSection extends StatelessWidget {
  const SoinsSection({
    super.key,
    required this.soins, required this.lapin, required this.onRefresh,
  });
  final List<Soin> soins;
  final Lapin lapin;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏥 Soins & Vaccinations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SoinFormScreen(lapinPreselect: lapin)));
                onRefresh();
              },
            ),
          ],
        ),
        if (soins.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: Text('Aucun soin enregistré',
                      style: TextStyle(color: context.cuTextSecondary))),
            ),
          )
        else
          ...soins.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(Icons.health_and_safety,
                      color: s.rappelUrgent ? AppTheme.warning : AppTheme.primary),
                  title: Text(s.typeSoin,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${formatDate(s.dateSoin)}${s.produit != null ? " • ${s.produit}" : ""}'
                    '${s.delaiAttenteJours != null ? " • Délai ${s.delaiAttenteJours}j" : ""}',
                  ),
                  trailing: s.dateRappel != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Rappel', style: TextStyle(fontSize: 10)),
                            Text(formatDate(s.dateRappel),
                                style: TextStyle(fontSize: 12,
                                    color: s.rappelUrgent ? AppTheme.warning : Colors.grey)),
                          ],
                        )
                      : null,
                ),
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Micro-widgets réutilisables
// ─────────────────────────────────────────────

class DetailBadge extends StatelessWidget {
  const DetailBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.cuTextSecondary),
          const SizedBox(width: 10),
          Text('$label : ', style: TextStyle(color: context.cuTextSecondary, fontSize: 13)),
          Expanded(child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
