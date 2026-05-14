// Écran : Alimentation & Stocks
// Affiche l'inventaire des aliments, avec alertes de niveau bas

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/stock.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'stock_form_screen.dart';

class AlimentationScreen extends StatefulWidget {
  const AlimentationScreen({super.key});

  @override
  State<AlimentationScreen> createState() => _AlimentationScreenState();
}

class _AlimentationScreenState extends State<AlimentationScreen> {
  final db = DBHelper.instance;
  List<Stock> _stocks = [];
  bool _loading = true;
  String _filtre = 'tous';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stocks = await db.getAllStocks();
    if (mounted) setState(() { _stocks = stocks; _loading = false; });
  }

  List<Stock> get _filtered {
    if (_filtre == 'critique') return _stocks.where((s) => s.estCritique).toList();
    if (_filtre == 'expire') return _stocks.where((s) => s.estExpire).toList();
    return _stocks;
  }

  Map<String, List<Stock>> get _groupedByType {
    final map = <String, List<Stock>>{};
    for (final s in _filtered) {
      map.putIfAbsent(s.typeAliment, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final critiques = _stocks.where((s) => s.estCritique).length;
    return Scaffold(
      appBar: CuAppBar(
        title: 'Alimentation & Stocks',
        emoji: '🌾',
        accent: CuColors.accentFeed,
        extraActions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (v) => setState(() => _filtre = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tous', child: Text('Tous les stocks')),
              PopupMenuItem(value: 'critique', child: Text('⚠️ Stocks critiques')),
              PopupMenuItem(value: 'expire', child: Text('❌ Expirés')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Résumé
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _miniStat('Total', _stocks.length, AppTheme.primary),
                const SizedBox(width: 8),
                _miniStat('Critiques', critiques, critiques > 0 ? AppTheme.error : Colors.green),
                const SizedBox(width: 8),
                _miniStat('Expirés', _stocks.where((s) => s.estExpire).length, AppTheme.warning),
              ],
            ),
          ),
          if (critiques > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AlertBanner(
                message: '$critiques produit(s) en dessous du seuil minimum !',
                color: AppTheme.error,
                icon: Icons.warning,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        message: 'Aucun stock enregistré.\nAjoutez vos premiers aliments !',
                        icon: Icons.inventory_2,
                        onAction: _ajouter,
                        actionLabel: 'Ajouter un stock',
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _groupedByType.entries.map((entry) => _groupSection(entry.key, entry.value)).toList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Stock'),
      ),
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _groupSection(String type, List<Stock> stocks) {
    final icons = {
      'Granulés': Icons.grain,
      'Foin': Icons.grass,
      'Paille': Icons.spa,
      'Légumes': Icons.eco,
      'Complément minéral': Icons.science,
      'Médicament': Icons.medication,
      'Autre': Icons.category,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icons[type] ?? Icons.inventory, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
        ...stocks.map((s) => _stockCard(s)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stockCard(Stock s) {
    final pctage = s.quantiteMin > 0 ? (s.quantite / s.quantiteMin).clamp(0.0, 3.0) : 1.0;
    final color = s.estCritique ? AppTheme.error : (pctage < 1.5 ? AppTheme.warning : AppTheme.primary);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.produit, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (s.estCritique)
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                if (s.estExpire)
                  const Icon(Icons.event_busy, color: Colors.orange, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${s.quantite} ${s.unite}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                          if (s.quantiteMin > 0)
                            Text(' / min ${s.quantiteMin} ${s.unite}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pctage / 3).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                      tooltip: 'Consommer',
                      onPressed: () => _consommer(s),
                    ),
                    const Text('Utiliser', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            if (s.fournisseur != null || s.dateExpiration != null || s.coutUnitaire != null) ...[
              const Divider(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  if (s.fournisseur != null) _tag(Icons.store, s.fournisseur!),
                  if (s.coutUnitaire != null) _tag(Icons.euro, '${s.coutUnitaire} ${AppTheme.devise}/${s.unite}'),
                  if (s.dateExpiration != null)
                    _tag(Icons.event, 'Exp: ${formatDate(s.dateExpiration)}', color: s.estExpire ? Colors.red : null),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => StockFormScreen(stock: s)));
                    _load();
                  },
                  child: const Text('Modifier'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Supprimer ce stock ?',
                      message: 'Ce stock sera supprimé.',
                      confirmColor: AppTheme.error,
                    );
                    if (ok) { await db.deleteStock(s.id!); _load(); }
                  },
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color ?? Colors.grey.shade600)),
      ],
    );
  }

  Future<void> _consommer(Stock stock) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Consommer "${stock.produit}"'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Quantité utilisée (${stock.unite})'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
        ],
      ),
    );
    if (ok == true && ctrl.text.isNotEmpty) {
      final qte = double.tryParse(ctrl.text.replaceAll(',', '.'));
      if (qte != null && qte > 0 && qte <= stock.quantite) {
        await db.consommerStock(stock.id!, qte, DateTime.now().toIso8601String().substring(0, 10));
        _load();
        if (mounted) showSuccessSnackBar(context, 'Stock mis à jour');
      } else {
        if (mounted) {
          showErrorSnackBar(context, 'Quantité invalide ou supérieure au stock disponible');
        }
      }
    }
  }

  Future<void> _ajouter() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StockFormScreen()));
    _load();
  }
}
