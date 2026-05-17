// ──────────────────────────────────────────────────────────────
// Écran : Ventes — Tableau de bord des revenus
// ──────────────────────────────────────────────────────────────
// Affiche l'historique des ventes et le chiffre d'affaires.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/vente.dart';
import '../../models/lapin.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'vente_form_screen.dart';

class VentesScreen extends StatefulWidget {
  const VentesScreen({super.key});

  @override
  State<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends State<VentesScreen> {
  final db = DBHelper.instance;
  List<Vente> _ventes = [];
  Map<int, Lapin> _lapinsMap = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 80;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (ventes, stats) = await (
      db.getAllVentes(limit: _pageSize),
      db.getStatistiquesVentes(),
    ).wait;
    final map = await db.getLapinsByIds(
      ventes.where((v) => v.lapinId != null).map((v) => v.lapinId!),
    );

    for (var v in ventes) {
      if (v.lapinId != null) {
        v.lapinNom = map[v.lapinId]?.displayName;
      }
    }

    if (mounted) {
      setState(() {
        _ventes = ventes;
        _lapinsMap = map;
        _stats = stats;
        _hasMore = ventes.length == _pageSize;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final next = await db.getAllVentes(limit: _pageSize, offset: _ventes.length);
    final map = await db.getLapinsByIds(
      next.where((v) => v.lapinId != null).map((v) => v.lapinId!),
    );
    for (var v in next) {
      if (v.lapinId != null) {
        v.lapinNom = map[v.lapinId]?.displayName;
      }
    }
    if (!mounted) return;
    setState(() {
      _lapinsMap.addAll(map);
      _ventes.addAll(next);
      _hasMore = next.length == _pageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CuAppBar(
        title: 'Ventes & Revenus',
        emoji: '💰',
        accent: CuColors.accentFinance,
      ),
      body: Column(
        children: [
          // En-tête statistiques
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: CuColors.accentFinance,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Text('Chiffre d\'affaires total', style: TextStyle(color: Colors.white70)),
                Text(
                  formatMontant(_stats['chiffre_affaires_total'] as double? ?? 0),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statBox('Ce mois-ci', formatMontant(_stats['chiffre_affaires_mois'] as double? ?? 0)),
                    Container(height: 30, width: 1, color: Colors.white30),
                    _statBox('Lapins vendus', '${_stats['nombre_total'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16),
            child: SectionHeader(title: 'Historique des ventes'),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ventes.isEmpty
                    ? EmptyState(
                        message: 'Aucune vente enregistrée.\nVotre chiffre d\'affaires vous attend !',
                        icon: Icons.point_of_sale,
                        onAction: _ajouter,
                        actionLabel: 'Enregistrer une vente',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _ventes.length + (_hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _ventes.length) {
                            _loadMore();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _venteCard(_ventes[i]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: CuColors.accentFinance,
        foregroundColor: Colors.white,
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Vente'),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _venteCard(Vente v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color.fromRGBO(180, 116, 22, 0.15),
          child: Icon(Icons.attach_money, color: CuColors.accentFinance),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                v.lapinNom != null ? 'Lapin : ${v.lapinNom}' : 'Lot de ${v.quantite} lapin(s)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              formatMontant(v.prixVente),
              style: const TextStyle(fontWeight: FontWeight.bold, color: CuColors.accentFinance, fontSize: 16),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: context.cuTextSecondary),
                const SizedBox(width: 4),
                Text(formatDate(v.dateVente)),
                const SizedBox(width: 12),
                Text(v.typeLabel, style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (v.acheteur != null && v.acheteur!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: context.cuTextSecondary),
                  const SizedBox(width: 4),
                  Text('Client: ${v.acheteur}'),
                ],
              ),
            ],
            if (v.poids != null) ...[
              const SizedBox(height: 2),
              Text('Poids total: ${v.poids} kg', style: TextStyle(color: context.cuTextSecondary, fontSize: 12)),
            ]
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () async {
            final ok = await showConfirmDialog(
              context,
              title: 'Supprimer cette vente ?',
              message: 'Attention, le lapin associé (s\'il y en a un) restera avec le statut "vendu".',
              confirmColor: AppTheme.error,
            );
            if (ok) {
              await db.deleteVente(v.id!);
              _load();
            }
          },
        ),
      ),
    );
  }

  Future<void> _ajouter() async {
    final lapins = await db.getLapinsByStatut('actif');
    final formMap = {for (final l in lapins) if (l.id != null) l.id!: l};
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VenteFormScreen(lapinsMap: formMap)));
    _load();
  }
}
