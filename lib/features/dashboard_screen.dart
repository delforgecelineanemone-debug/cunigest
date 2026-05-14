// DashboardScreen V3 — « Field-Premium »
// Logique : DashboardNotifier (dashboard_notifier.dart) — inchangée
// UI : header + KPIs CuniUI + alertes + lots + donut

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lot.dart';
import '../models/profil.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/state_providers.dart';
import '../state/app_state.dart';
import '../ui/cu_ui.dart';
import '../utils/breakpoints.dart';
import 'lapins/lapins_list_screen.dart';
import 'sante/sante_screen.dart';
import 'ventes/ventes_screen.dart';
import 'lots/lots_screen.dart';
import 'lots/lot_detail_screen.dart';
import 'routine/routine_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _refresh() async {
    await ref.read(dashboardProvider.notifier).refresh();
    ref.read(profilProvider.notifier).refresh();
    ref.read(alertesCountProvider.notifier).refresh();
    ref.read(reglagesProvider.notifier).refresh();
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) { if (mounted) _refresh(); });
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(dashboardProvider);
    final profilState = ref.watch(profilProvider);
    final reglagesState = ref.watch(reglagesProvider);
    final session = ref.watch(sessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final peutVoirFinances =
        session.peutVoirFinances || !session.isAuthenticated;

    return Scaffold(
      backgroundColor:
          isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: const CuAppBar.brand(),
      body: RefreshIndicator(
        color: CuColors.primary,
        onRefresh: _refresh,
        child: dashAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => _SkeletonDashboard(),
          error: (e, _) => _ErrorBody(onRetry: _refresh),
          data: (data) => _Body(
            data: data,
            profilState: profilState,
            reglagesState: reglagesState,
            peutVoirFinances: peutVoirFinances,
            session: session,
            navigate: _navigate,
          ),
        ),
      ),
    );
  }

}

// ── Corps principal ────────────────────────────────────────────

class _Body extends StatelessWidget {
  final DashboardData data;
  final ProfilState profilState;
  final ReglagesState reglagesState;
  final bool peutVoirFinances;
  final SessionState session;
  final void Function(Widget) navigate;

  const _Body({
    required this.data,
    required this.profilState,
    required this.reglagesState,
    required this.peutVoirFinances,
    required this.session,
    required this.navigate,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = context.hPad;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nom = session.currentUser?.nom ?? 'Cuniculteur';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header dégradé ──
          _DashHeader(nom: nom, isDark: isDark),

          const SizedBox(height: CuSpacing.lg),

          // ── KPIs ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: GridView.count(
              crossAxisCount: context.kpiColumns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: CuSpacing.md,
              mainAxisSpacing: CuSpacing.md,
              childAspectRatio: context.isWide ? 2.0 : 1.25,
              children: _buildKpis(context),
            ),
          ),

          const SizedBox(height: CuSpacing.xl),

          // ── Streak ──
          if (reglagesState.gamificationActive && profilState.streak > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, CuSpacing.md),
              child: _StreakBanner(
                profil: profilState.profil,
                onTap: () => navigate(const RoutineScreen()),
              ),
            ),

          // ── Alertes ──
          if (data.rappels.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, CuSpacing.sm),
              child: CuAlertBanner(
                message:
                    '${data.rappels.length} rappel(s) sanitaire(s) dans les 7 prochains jours',
                level: CuAlertLevel.warning,
                icon: Icons.alarm,
                actionLabel: 'Voir',
                onAction: () => navigate(const SanteScreen()),
              ),
            ),
          if (data.stocksCritiques.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, CuSpacing.sm),
              child: CuAlertBanner(
                message:
                    '${data.stocksCritiques.length} stock(s) en dessous du seuil minimum',
                level: CuAlertLevel.danger,
                icon: Icons.inventory_2_outlined,
              ),
            ),

          // ── Lots actifs ──
          if (data.lotsActifs.isNotEmpty) ...[
            _SectionHeader(
              title: 'LOTS ACTIFS',
              actionLabel: 'Voir tout',
              onAction: () => navigate(const LotsScreen()),
              hPad: hPad,
            ),
            ...data.lotsActifs.map(
              (l) => Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, CuSpacing.sm),
                child: _LotCard(
                  lot: l,
                  onTap: () => navigate(LotDetailScreen(lot: l)),
                ),
              ),
            ),
          ],

          // ── Donut répartition ──
          if (_totalCheptel(data) > 0) ...[
            _SectionHeader(
              title: 'RÉPARTITION DU CHEPTEL',
              hPad: hPad,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, CuSpacing.sm),
              child: _DonutCard(
                segments: _segmentsCheptel(data),
                total: _totalCheptel(data),
              ),
            ),
          ],

          const SizedBox(height: CuSpacing.x3l),
        ],
      ),
    );
  }

  List<Widget> _buildKpis(BuildContext context) {
    return [
      CuKpiCard(
        label: 'Lapins actifs',
        value: '${data.statsLapins['actifs'] ?? 0}',
        icon: Icons.pets,
        color: CuColors.primary,
        delta: data.naissancesMois > 0 ? '+${data.naissancesMois}' : null,
        onTap: () => navigate(const LapinsListScreen()),
      ),
      if (peutVoirFinances)
        CuKpiCard(
          label: 'Recettes / mois',
          value: _formatMontantCompact(
              (data.statsVentes['chiffre_affaires_mois'] ?? 0).toDouble()),
          icon: Icons.euro,
          color: CuColors.accentFinance,
          onTap: () => navigate(const VentesScreen()),
        )
      else
        CuKpiCard(
          label: 'Lots en cours',
          value: '${data.lotsActifs.length}',
          icon: Icons.groups,
          color: CuColors.primary,
          onTap: () => navigate(const LotsScreen()),
        ),
      CuKpiCard(
        label: 'Rappels santé (7j)',
        value: '${data.rappels.length}',
        icon: Icons.health_and_safety_outlined,
        color: data.rappels.isEmpty ? CuColors.success : CuColors.warning,
        deltaPositiveIsGood: false,
        onTap: () => navigate(const SanteScreen()),
      ),
      CuKpiCard(
        label: 'Stocks critiques',
        value: '${data.stocksCritiques.length}',
        icon: Icons.inventory_2_outlined,
        color: data.stocksCritiques.isEmpty
            ? CuColors.success
            : CuColors.accentFeed,
        deltaPositiveIsGood: false,
      ),
    ];
  }

  int _totalCheptel(DashboardData data) =>
      data.repartitionStatuts.values.fold(0, (a, b) => a + b);

  List<_Segment> _segmentsCheptel(DashboardData data) {
    const labels = {
      'actif': 'Actifs',
      'sevrage': 'Sevrage',
      'quarantaine': 'Quarantaine',
      'vendu': 'Vendus',
      'mort': 'Décédés',
    };
    const couleurs = {
      'actif': CuColors.primary,
      'sevrage': CuColors.accentRepro,
      'quarantaine': CuColors.warning,
      'vendu': CuColors.accentFinance,
      'mort': CuColors.danger,
    };
    final segs = <_Segment>[];
    for (final entry in data.repartitionStatuts.entries) {
      if (entry.value <= 0) continue;
      segs.add(_Segment(
        label: labels[entry.key] ?? entry.key,
        count: entry.value,
        color: couleurs[entry.key] ?? Colors.grey,
      ));
    }
    segs.sort((a, b) => b.count.compareTo(a.count));
    return segs;
  }
}

// ── Header dégradé ────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final String nom;
  final bool isDark;

  const _DashHeader({required this.nom, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          CuSpacing.xl, CuSpacing.xl, CuSpacing.xl, CuSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CuColors.primary,
            CuColors.primary.withValues(alpha: 0.80),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonjour 👋',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: CuSpacing.xs),
          Text(
            nom,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: CuSpacing.xs),
          Text(
            _dateLongueFr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double hPad;

  const _SectionHeader({
    required this.title,
    required this.hPad,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, CuSpacing.xl, hPad, CuSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? CuColors.textSecondaryDark
                        : CuColors.textSecondaryLight,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                '$actionLabel →',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CuColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Streak banner ──────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final ProfilEleveur profil;
  final VoidCallback onTap;

  const _StreakBanner({required this.profil, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = profil;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: CuSpacing.lg, vertical: CuSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CuColors.primary, CuColors.primary.withValues(alpha: 0.7)],
          ),
          borderRadius: CuRadius.mdAll,
        ),
        child: Row(
          children: [
            Text(p.streakIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: CuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.streakActuel} jour${p.streakActuel > 1 ? 's' : ''} de streak !',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '${p.niveauIcon} Nv. ${p.niveau} — ${p.niveauTitre}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Lot card ───────────────────────────────────────────────────

class _LotCard extends StatelessWidget {
  final Lot lot;
  final VoidCallback onTap;

  const _LotCard({required this.lot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = lot.statut == 'en_cours'
        ? CuColors.primary
        : CuColors.accentFinance;
    final dateCreation =
        DateTime.tryParse(lot.dateCreation) ?? DateTime.now();
    final jours = DateTime.now().difference(dateCreation).inDays;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: CuSpacing.lg, vertical: CuSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? CuColors.cardDark : CuColors.cardLight,
          borderRadius: CuRadius.mdAll,
          boxShadow: isDark ? CuShadows.none : CuShadows.level1,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: CuSpacing.md),
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.code,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lot.nombreInitial} lapereaux · J+$jours'
                    '${lot.cage != null ? " · ${lot.cage}" : ""}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? CuColors.textSecondaryDark
                              : CuColors.textSecondaryLight,
                        ),
                  ),
                ],
              ),
            ),
            CuBadge(
              label:
                  lot.statut == 'en_cours' ? 'Engraissement' : 'À vendre',
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Donut répartition ──────────────────────────────────────────

class _Segment {
  final String label;
  final int count;
  final Color color;
  const _Segment(
      {required this.label, required this.count, required this.color});
}

class _DonutCard extends StatelessWidget {
  final List<_Segment> segments;
  final int total;

  const _DonutCard({required this.segments, required this.total});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(CuSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? CuColors.cardDark : CuColors.cardLight,
        borderRadius: CuRadius.mdAll,
        boxShadow: isDark ? CuShadows.none : CuShadows.level1,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: segments
                        .map((s) => PieChartSectionData(
                              value: s.count.toDouble(),
                              color: s.color,
                              title: '',
                              radius: 20,
                            ))
                        .toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'lapins',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? CuColors.textSecondaryDark
                                : CuColors.textSecondaryLight,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: CuSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: segments
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: CuSpacing.sm),
                          Expanded(
                            child: Text(
                              s.label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${s.count}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading ───────────────────────────────────────────

class _SkeletonDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark ? CuColors.raisedDark : CuColors.raisedLight;
    final hPad = context.hPad;

    box(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: CuRadius.smAll,
          ),
        );

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Container(
            height: 110,
            color: CuColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: CuSpacing.lg),
          // KPI grid skeleton
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: GridView.count(
              crossAxisCount: context.kpiColumns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: CuSpacing.md,
              mainAxisSpacing: CuSpacing.md,
              childAspectRatio: 1.25,
              children: List.generate(
                4,
                (_) => Container(
                  padding: const EdgeInsets.all(CuSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark ? CuColors.cardDark : CuColors.cardLight,
                    borderRadius: CuRadius.mdAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      box(36, 36),
                      const SizedBox(height: CuSpacing.sm),
                      box(60, 20),
                      const SizedBox(height: 6),
                      box(80, 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CuSpacing.x2l),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(children: [
              box(double.infinity, 56),
              const SizedBox(height: CuSpacing.sm),
              box(double.infinity, 56),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Erreur ────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CuSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 56,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: CuSpacing.lg),
            Text('Erreur de chargement',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CuSpacing.sm),
            Text(
              'Vérifiez votre connexion ou relancez l\'application.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: CuSpacing.xl),
            CuButton(
              label: 'Réessayer',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────

String _formatMontantCompact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} k';
  return v.toStringAsFixed(0);
}

String _dateLongueFr() {
  const jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
    'Vendredi', 'Samedi', 'Dimanche',
  ];
  const mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  final n = DateTime.now();
  return '${jours[n.weekday - 1]} ${n.day} ${mois[n.month - 1]} ${n.year}';
}
