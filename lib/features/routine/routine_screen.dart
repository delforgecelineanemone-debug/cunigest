// ──────────────────────────────────────────────────────────────
// Écran : Routine Quotidienne (Système Anti-Paresse)
// ──────────────────────────────────────────────────────────────
// C'est l'écran principal du système de routines.
// Il affiche :
// - La checklist des tâches du jour
// - La barre de progression (score du jour)
// - Le streak actuel
// - Les badges et le niveau de l'éleveur
//
// L'éleveur coche ses tâches au fur et à mesure de sa journée.
// Chaque tâche cochée rapporte des points et fait avancer la barre.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/tache.dart';
import '../../models/profil.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/notification_service.dart';
import 'calendrier_taches_screen.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});
  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> with SingleTickerProviderStateMixin {
  final db = DBHelper.instance;
  List<Tache> _taches = [];
  Set<int> _completees = {};
  ProfilEleveur _profil = ProfilEleveur();
  List<BadgeEleveur> _badges = [];
  bool _loading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final taches = await db.getTachesDuJour();
    final completees = await db.getTachesCompleteesAujourdhui();
    final profil = await db.getProfil();
    final badges = await db.getBadgesObtenus();
    if (mounted) {
      setState(() {
        _taches = taches;
        _completees = completees;
        _profil = profil;
        _badges = badges;
        _loading = false;
      });
    }
  }

  /// Score maximum possible aujourd'hui
  int get _scoreMax => _taches.fold(0, (sum, t) => sum + t.points);

  /// Score actuel (tâches complétées)
  int get _scoreActuel => _taches.where((t) => _completees.contains(t.id)).fold(0, (sum, t) => sum + t.points);

  /// Progression du jour (0.0 à 1.0)
  double get _progression => _scoreMax > 0 ? (_scoreActuel / _scoreMax).clamp(0.0, 1.0) : 0.0;

  /// Nombre de tâches complétées
  int get _nbCompletees => _taches.where((t) => _completees.contains(t.id)).length;

  /// Message de motivation basé sur la progression
  String get _messageMotivation {
    if (_progression >= 1.0) return '🎉 Parfait ! Toutes les tâches sont faites !';
    if (_progression >= 0.75) return '💪 Encore un petit effort, c\'est presque fini !';
    if (_progression >= 0.50) return '👍 Bonne progression, continuez !';
    if (_progression >= 0.25) return '🌱 C\'est parti, bon début !';
    return '☀️ Nouvelle journée, nouvelles routines !';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Ma Routine'),
        actions: [
          // Calendrier mensuel des tâches
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendrier',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CalendrierTachesScreen())),
          ),
          // Badge des trophées
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Mes badges',
            onPressed: _showBadges,
          ),
          // Ajouter une tâche personnalisée
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Ajouter une tâche',
            onPressed: _ajouterTache,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── En-tête : Streak + Score ──
                  _StreakCard(profil: _profil),
                  const SizedBox(height: 12),

                  // ── Barre de progression du jour ──
                  _ProgressCard(
                    nbCompletees: _nbCompletees,
                    total: _taches.length,
                    scoreActuel: _scoreActuel,
                    scoreMax: _scoreMax,
                    progression: _progression,
                    profil: _profil,
                  ),
                  const SizedBox(height: 16),

                  // ── Message de motivation ──
                  _MotivationBanner(
                    progression: _progression,
                    message: _messageMotivation,
                  ),
                  const SizedBox(height: 16),

                  // ── Checklist des tâches ──
                  const SectionHeader(title: 'Tâches du jour'),
                  const SizedBox(height: 8),
                  if (_taches.isEmpty)
                    const EmptyState(
                      message: 'Aucune tâche prévue aujourd\'hui.\nProfitez-en pour ajouter une tâche personnalisée !',
                      icon: Icons.check_circle_outline,
                    )
                  else
                    ..._taches.map((t) => _TacheItem(
                          tache: t,
                          estFait: _completees.contains(t.id),
                          onToggle: () => _toggleTache(t),
                        )),

                  const SizedBox(height: 16),

                  // ── Badges obtenus ──
                  if (_badges.isNotEmpty) ...[
                    const SectionHeader(title: 'Badges débloqués'),
                    const SizedBox(height: 8),
                    _BadgesRow(badges: _badges),
                  ],
                ],
              ),
            ),
    );
  }

  /// Toggle une tâche (complétée / non complétée)
  Future<void> _toggleTache(Tache t) async {
    final estFait = _completees.contains(t.id);
    if (estFait) {
      await db.deCompleterTache(t.id!);
      // Retirer les points
      await db.mettreAJourScore(-t.points);
    } else {
      await db.completerTache(t.id!);
      // Ajouter les points
      final profil = await db.mettreAJourScore(t.points);
      // Vérifier les badges
      final nouveaux = await db.verifierBadges();
      if (nouveaux.isNotEmpty && mounted) {
        _showBadgeUnlock(nouveaux);
        // Envoyer une notification push de félicitation
        for (final badge in nouveaux) {
          await NotificationService.instance.envoyerFelicitation(
            '🏆 Nouveau Badge !',
            'Vous avez débloqué : $badge',
          );
        }
      }
      // Mettre à jour la notification de streak
      await NotificationService.instance.rappelerStreak(profil.streakActuel);
      setState(() => _profil = profil);
    }
    await _load();
  }

  /// Popup pour montrer un nouveau badge débloqué
  void _showBadgeUnlock(List<String> badges) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🏆 Nouveau Badge !', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: badges.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(b, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center),
          )).toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Super ! 🎉'),
          ),
        ],
      ),
    );
  }

  /// Affiche tous les badges (obtenus et non obtenus)
  void _showBadges() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: Text('🏆 Mes Badges', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Text(
              '${_badges.length} / ${BadgeEleveur.tousLesBadges.length} débloqués',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...BadgeEleveur.tousLesBadges.map((bd) {
              final obtenu = _badges.any((b) => b.code == bd.code);
              return ListTile(
                leading: Text(
                  obtenu ? bd.icone : '🔒',
                  style: TextStyle(fontSize: 28, color: obtenu ? null : Colors.grey),
                ),
                title: Text(
                  bd.nom,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: obtenu ? null : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  bd.description,
                  style: TextStyle(fontSize: 12, color: obtenu ? Colors.green : Colors.grey),
                ),
                trailing: obtenu
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.lock_outline, color: Colors.grey),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Formulaire pour ajouter une tâche personnalisée (V2.4 — date d'échéance)
  Future<void> _ajouterTache() async {
    final titreCtrl = TextEditingController();
    String categorie = 'custom';
    String priorite = 'normal';
    String recurrence = 'quotidien';
    DateTime? dateEcheance;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('➕ Nouvelle tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Titre de la tâche *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categorie,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: Tache.categorieLabels.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => categorie = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priorite,
                  decoration: const InputDecoration(labelText: 'Priorité'),
                  items: const [
                    DropdownMenuItem(
                        value: 'critique',
                        child: Text('🔴 Critique (+30 pts)')),
                    DropdownMenuItem(
                        value: 'important',
                        child: Text('🟠 Important (+20 pts)')),
                    DropdownMenuItem(
                        value: 'normal', child: Text('🟢 Normal (+10 pts)')),
                  ],
                  onChanged: (v) => setDialogState(() => priorite = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: recurrence,
                  decoration: const InputDecoration(labelText: 'Récurrence'),
                  items: Tache.recurrenceLabels.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    recurrence = v!;
                    if (recurrence != 'ponctuel') dateEcheance = null;
                  }),
                ),
                if (recurrence == 'ponctuel') ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(dateEcheance == null
                        ? 'Date d\'échéance (optionnel)'
                        : '${dateEcheance!.day}/${dateEcheance!.month}/${dateEcheance!.year}'),
                    trailing: dateEcheance != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setDialogState(() => dateEcheance = null),
                          )
                        : null,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: dateEcheance ?? DateTime.now(),
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 2)),
                      );
                      if (d != null) setDialogState(() => dateEcheance = d);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Créer')),
          ],
        ),
      ),
    );

    if (ok == true && titreCtrl.text.trim().isNotEmpty) {
      await db.insertTache(Tache(
        titre: titreCtrl.text.trim(),
        categorie: categorie,
        priorite: priorite,
        recurrence: recurrence,
        estSysteme: false,
        dateEcheance: dateEcheance?.toIso8601String().substring(0, 10),
      ));
      _load();
      if (mounted) showSuccessSnackBar(context, 'Tâche ajoutée !');
    }
    titreCtrl.dispose();
  }
}

// ──────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final ProfilEleveur profil;
  const _StreakCard({required this.profil});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profil.streakIcon} ${profil.streakActuel} jour${profil.streakActuel > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  'Record : ${profil.meilleurStreak} jours',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(profil.niveauIcon,
                    style: const TextStyle(fontSize: 24)),
                Text(
                  'Nv. ${profil.niveau}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  profil.niveauTitre,
                  style: const TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int nbCompletees;
  final int total;
  final int scoreActuel;
  final int scoreMax;
  final double progression;
  final ProfilEleveur profil;

  const _ProgressCard({
    required this.nbCompletees,
    required this.total,
    required this.scoreActuel,
    required this.scoreMax,
    required this.progression,
    required this.profil,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$nbCompletees / $total tâches',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '$scoreActuel / $scoreMax pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color:
                        progression >= 1.0 ? Colors.green : AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progression,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progression >= 1.0 ? Colors.green : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.arrow_upward,
                    size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Niveau ${profil.niveau + 1} dans ${profil.pointsProchainNiveau - profil.pointsDansNiveau} points',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  final double progression;
  final String message;

  const _MotivationBanner(
      {required this.progression, required this.message});

  @override
  Widget build(BuildContext context) {
    final done = progression >= 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: done
            ? Colors.green.withValues(alpha: 0.1)
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done
              ? Colors.green.withValues(alpha: 0.3)
              : AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: done ? Colors.green.shade700 : AppTheme.primary,
        ),
      ),
    );
  }
}

class _TacheItem extends StatelessWidget {
  final Tache tache;
  final bool estFait;
  final VoidCallback onToggle;

  const _TacheItem({
    required this.tache,
    required this.estFait,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = tache;
    final prioriteColor = {
      'critique': Colors.red,
      'important': Colors.orange,
      'normal': Colors.green,
    }[t.priorite] ??
        Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: estFait ? Colors.green.withValues(alpha: 0.05) : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: estFait ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: estFait ? Colors.green : prioriteColor,
                    width: 2,
                  ),
                ),
                child: estFait
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.categorieIcon} ${t.titre}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration:
                            estFait ? TextDecoration.lineThrough : null,
                        color: estFait ? Colors.grey : null,
                      ),
                    ),
                    if (t.description != null)
                      Text(
                        t.description!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: prioriteColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.prioriteLabel,
                            style: TextStyle(
                                fontSize: 9, color: prioriteColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${t.points} pts',
                          style: TextStyle(
                            fontSize: 11,
                            color: estFait
                                ? Colors.green
                                : Colors.grey.shade500,
                            fontWeight: estFait
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (t.heureRappel != null)
                Text(
                  t.heureRappel!,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  final List<BadgeEleveur> badges;
  const _BadgesRow({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges
          .map((b) => Tooltip(
                message: '${b.nom} — ${b.description}',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${b.icone} ${b.nom}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
