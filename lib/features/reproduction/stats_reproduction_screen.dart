// ──────────────────────────────────────────────────────────────
// Écran : Statistiques de Reproduction
// ──────────────────────────────────────────────────────────────
// Affiche les KPI clés de l'élevage cunicole :
// - Taux de fertilité (saillies positives / palpées)
// - Prolificité moyenne (nb vivants / portée)
// - Mortalité naissance (morts-nés / total nés)
// - Mortalité pré-sevrage ((vivants - sevrés) / vivants)
// - Totaux globaux (saillies, lapereaux nés, sevrés)
//
// Ces indicateurs permettent de juger des performances reproductives
// et de comparer les générations / souches.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../utils/theme.dart';

class StatsReproductionScreen extends StatefulWidget {
  const StatsReproductionScreen({super.key});

  @override
  State<StatsReproductionScreen> createState() => _StatsReproductionScreenState();
}

class _StatsReproductionScreenState extends State<StatsReproductionScreen> {
  final db = DBHelper.instance;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await db.getStatistiquesReproduction();
    if (mounted) {
      setState(() {
        _stats = s;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Statistiques reproduction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _buildContent(),
              ),
            ),
    );
  }

  List<Widget> _buildContent() {
    final s = _stats!;
    final nbSaillies = s['nombre_saillies'] as int;

    if (nbSaillies == 0) {
      return [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Aucune saillie enregistrée.\n'
                'Les statistiques apparaîtront après votre première saillie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ];
    }

    final fertilite = s['taux_fertilite_pct'] as double?;
    final prolificite = s['prolificite_moyenne'] as double?;
    final mortaliteNaiss = (s['total_nes'] as int) > 0
        ? ((s['total_morts_naissance'] as int) / (s['total_nes'] as int)) * 100
        : null;
    final mortaliteSevrage = s['taux_mortalite_pre_sevrage_pct'] as double?;

    return [
      // ── KPI principaux ──
      const Text('Indicateurs clés',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      _kpiCard(
        titre: 'Taux de fertilité',
        valeur: fertilite != null ? '${fertilite.toStringAsFixed(1)} %' : '—',
        sousTitre: '${s['nombre_positives']} positives / ${s['nombre_positives'] + s['nombre_echecs']} palpées',
        icone: Icons.favorite,
        couleur: _couleurFertilite(fertilite),
        explication: 'Saillies confirmées (palpation +) / saillies palpées. Bon : ≥ 80 %.',
      ),

      _kpiCard(
        titre: 'Prolificité moyenne',
        valeur: prolificite != null ? prolificite.toStringAsFixed(1) : '—',
        sousTitre: 'lapereaux vivants par portée',
        icone: Icons.child_care,
        couleur: _couleurProlificite(prolificite),
        explication: 'Nombre moyen de nés vivants par mise bas. Bon : ≥ 8.',
      ),

      _kpiCard(
        titre: 'Mortalité à la naissance',
        valeur: mortaliteNaiss != null ? '${mortaliteNaiss.toStringAsFixed(1)} %' : '—',
        sousTitre: '${s['total_morts_naissance']} morts-nés / ${s['total_nes']} total nés',
        icone: Icons.sentiment_dissatisfied,
        couleur: _couleurMortalite(mortaliteNaiss, seuilOk: 10, seuilWarn: 20),
        explication: 'Morts-nés / total nés. Bon : ≤ 10 %.',
      ),

      _kpiCard(
        titre: 'Mortalité pré-sevrage',
        valeur: mortaliteSevrage != null ? '${mortaliteSevrage.toStringAsFixed(1)} %' : '—',
        sousTitre: '${(s['total_nes_vivants'] as int) - (s['total_sevres'] as int)} pertes / ${s['total_nes_vivants']} vivants',
        icone: Icons.heart_broken,
        couleur: _couleurMortalite(mortaliteSevrage, seuilOk: 10, seuilWarn: 20),
        explication: '(Vivants - sevrés) / vivants. Bon : ≤ 10 %.',
      ),

      const SizedBox(height: 20),

      // ── Totaux ──
      const Text('Totaux globaux',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ligne('Saillies enregistrées', '${s['nombre_saillies']}', Icons.favorite_outline),
              const Divider(),
              _ligne('Saillies positives', '${s['nombre_positives']}',
                  Icons.check_circle_outline, color: Colors.green),
              _ligne('Saillies en échec', '${s['nombre_echecs']}',
                  Icons.cancel_outlined, color: Colors.red),
              const Divider(),
              _ligne('Total nés', '${s['total_nes']}', Icons.egg_outlined),
              _ligne('Total nés vivants', '${s['total_nes_vivants']}',
                  Icons.pets, color: Colors.green),
              _ligne('Total morts-nés', '${s['total_morts_naissance']}',
                  Icons.cancel_outlined, color: Colors.red),
              _ligne('Total sevrés', '${s['total_sevres']}',
                  Icons.free_breakfast, color: AppTheme.primary),
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Les seuils "bon" cités sont des références pour un élevage rationnel '
                'de souches productives (ex: Hyplus, Hycole). Adaptez-les à votre type '
                'de production (race lourde, biologique, etc.).',
                style: TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _kpiCard({
    required String titre,
    required String valeur,
    required String sousTitre,
    required IconData icone,
    required Color couleur,
    required String explication,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: couleur, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(sousTitre,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text(
                  valeur,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: couleur),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              explication,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligne(String label, String valeur, IconData icone, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(valeur,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Color _couleurFertilite(double? pct) {
    if (pct == null) return Colors.grey;
    if (pct >= 80) return Colors.green;
    if (pct >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _couleurProlificite(double? n) {
    if (n == null) return Colors.grey;
    if (n >= 8) return Colors.green;
    if (n >= 6) return Colors.orange;
    return Colors.red;
  }

  Color _couleurMortalite(double? pct,
      {required double seuilOk, required double seuilWarn}) {
    if (pct == null) return Colors.grey;
    if (pct <= seuilOk) return Colors.green;
    if (pct <= seuilWarn) return Colors.orange;
    return Colors.red;
  }
}
