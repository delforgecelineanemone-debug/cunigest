// ──────────────────────────────────────────────────────────────
// Écran : Calendrier mensuel des tâches (V2.5 — Phase 4)
// ──────────────────────────────────────────────────────────────
// Vue mensuelle de toutes les tâches actives (récurrentes +
// ponctuelles). Chaque jour avec au moins une tâche affiche un
// marqueur coloré selon la priorité maximale.
//
// Tap sur un jour → liste des tâches du jour, possibilité de
// "passer" (ajouter aux exceptions) une occurrence d'une tâche
// récurrente sans casser la série.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../database/db_helper.dart';
import '../../models/tache.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class CalendrierTachesScreen extends StatefulWidget {
  const CalendrierTachesScreen({super.key});

  @override
  State<CalendrierTachesScreen> createState() =>
      _CalendrierTachesScreenState();
}

class _CalendrierTachesScreenState extends State<CalendrierTachesScreen> {
  final db = DBHelper.instance;
  List<Tache> _taches = const [];
  bool _loading = true;

  CalendarFormat _format = CalendarFormat.month;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final taches = await db.getTachesActives();
    if (!mounted) return;
    setState(() {
      _taches = taches;
      _loading = false;
    });
  }

  /// Indique si une tâche s'applique à un jour donné.
  /// Tient compte des exceptions et du type de récurrence.
  bool _sApplique(Tache t, DateTime jour) {
    final jourStr = _isoDay(jour);
    if (t.exceptionsList.contains(jourStr)) return false;

    final creation = DateTime.tryParse(t.dateCreation);
    final jourMidnight = DateTime(jour.year, jour.month, jour.day);
    if (creation != null) {
      final creationMidnight =
          DateTime(creation.year, creation.month, creation.day);
      if (jourMidnight.isBefore(creationMidnight)) return false;
    }

    switch (t.recurrence) {
      case 'quotidien':
        return true;
      case 'hebdomadaire':
        return creation != null && jour.weekday == creation.weekday;
      case 'mensuel':
        return creation != null && jour.day == creation.day;
      case 'ponctuel':
        return t.dateEcheance == jourStr || t.dateCreation == jourStr;
      default:
        return false;
    }
  }

  List<Tache> _tachesPourJour(DateTime jour) {
    return _taches.where((t) => _sApplique(t, jour)).toList();
  }

  /// Priorité max parmi les tâches du jour (pour la couleur du marqueur).
  /// Renvoie null si aucune tâche.
  String? _prioriteMax(DateTime jour) {
    final taches = _tachesPourJour(jour);
    if (taches.isEmpty) return null;
    if (taches.any((t) => t.priorite == 'critique')) return 'critique';
    if (taches.any((t) => t.priorite == 'important')) return 'important';
    return 'normal';
  }

  Color _couleurPriorite(String p) {
    switch (p) {
      case 'critique':
        return AppTheme.error;
      case 'important':
        return AppTheme.warning;
      default:
        return AppTheme.primary;
    }
  }

  Future<void> _passerOccurrence(Tache t, DateTime jour) async {
    final jourStr = _isoDay(jour);
    final ok = await showConfirmDialog(
      context,
      title: 'Passer cette occurrence ?',
      message:
          'La tâche "${t.titre}" ne s\'affichera pas le ${_dateLisible(jour)}. '
          'La série continue normalement les autres jours.',
      confirmLabel: 'Passer',
    );
    if (!ok) return;

    final dejaExclus = t.exceptionsList;
    if (dejaExclus.contains(jourStr)) return;
    final nouvelles = [...dejaExclus, jourStr].join(',');

    final maj = t.copyWith(exceptions: nouvelles);
    await db.updateTache(maj);
    await _load();
    if (!mounted) return;
    showSuccessSnackBar(context, 'Occurrence passée');
  }

  Future<void> _reporterTache(Tache t) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reporter cette tâche ?',
      message:
          '"${t.titre}" sera mise de côté (statut "reportée") et n\'apparaîtra plus '
          'dans la routine ni dans le calendrier jusqu\'à ce qu\'elle soit réactivée.',
      confirmLabel: 'Reporter',
    );
    if (!ok) return;

    final maj = t.copyWith(statut: 'reporte');
    await db.updateTache(maj);
    await _load();
    if (!mounted) return;
    showSuccessSnackBar(context, 'Tâche reportée');
  }

  String _isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dateLisible(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final tachesJour = _tachesPourJour(_selected);

    return Scaffold(
      appBar: CuAppBar(
        title: 'Calendrier des tâches',
        emoji: '📅',
        showActions: false,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Calendrier ──
                Card(
                  margin:
                      const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TableCalendar<Tache>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focused,
                    selectedDayPredicate: (d) => isSameDay(_selected, d),
                    calendarFormat: _format,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Mois',
                      CalendarFormat.twoWeeks: '2 sem.',
                      CalendarFormat.week: 'Sem.',
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    eventLoader: _tachesPourJour,
                    headerStyle: const HeaderStyle(
                      formatButtonShowsNext: false,
                      titleCentered: true,
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markersAlignment: Alignment.bottomCenter,
                    ),
                    calendarBuilders: CalendarBuilders<Tache>(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox();
                        final pri = _prioriteMax(day);
                        if (pri == null) return const SizedBox();
                        return Container(
                          margin: const EdgeInsets.only(top: 26),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _couleurPriorite(pri),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selected = selected;
                        _focused = focused;
                      });
                    },
                    onFormatChanged: (f) => setState(() => _format = f),
                    onPageChanged: (focused) => _focused = focused,
                  ),
                ),

                // ── Liste tâches du jour sélectionné ──
                Expanded(
                  child: tachesJour.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Aucune tâche le ${_dateLisible(_selected)}.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.cuTextSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: tachesJour.length,
                          itemBuilder: (_, i) =>
                              _buildTacheTile(tachesJour[i], _selected),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTacheTile(Tache t, DateTime jour) {
    final color = _couleurPriorite(t.priorite);
    final estRecurrent = t.recurrence != 'ponctuel';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(_iconeCategorie(t.categorie), color: color, size: 18),
        ),
        title: Text(t.titre,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(
          [
            t.prioriteLabel,
            if (estRecurrent) Tache.recurrenceLabels[t.recurrence] ?? t.recurrence,
            if (t.heureRappel != null) '⏰ ${t.heureRappel}',
          ].join(' • '),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          tooltip: 'Actions',
          onSelected: (action) {
            switch (action) {
              case 'passer':
                _passerOccurrence(t, jour);
                break;
              case 'reporter':
                _reporterTache(t);
                break;
            }
          },
          itemBuilder: (_) => [
            if (estRecurrent)
              const PopupMenuItem(
                value: 'passer',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_busy, size: 18),
                  title: Text('Passer cette occurrence'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'reporter',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.pause_circle_outline, size: 18),
                title: Text('Reporter la tâche'),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconeCategorie(String c) {
    switch (c) {
      case 'nourriture':
        return Icons.restaurant;
      case 'eau':
        return Icons.water_drop;
      case 'nettoyage':
        return Icons.cleaning_services;
      case 'sante':
        return Icons.health_and_safety;
      case 'reproduction':
        return Icons.favorite;
      case 'observation':
        return Icons.visibility;
      default:
        return Icons.task_alt;
    }
  }
}
