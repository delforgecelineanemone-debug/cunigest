// Écran : Formulaire Stock (Ajout / Modification)

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/stock.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class StockFormScreen extends StatefulWidget {
  final Stock? stock;
  const StockFormScreen({super.key, this.stock});

  @override
  State<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<StockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formCtrl = CuFormController(); // V2.5 — Sprint 3 : anti-perte de saisie
  final db = DBHelper.instance;

  final _produitCtrl = TextEditingController();
  final _quantiteCtrl = TextEditingController();
  final _quantiteMinCtrl = TextEditingController();
  final _fournisseurCtrl = TextEditingController();
  final _coutCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _typeAliment = Stock.typesAliments.first;
  String _unite = 'kg';
  String? _dateEntree;
  String? _dateExpiration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.stock;
    if (s != null) {
      _produitCtrl.text = s.produit;
      _typeAliment = s.typeAliment;
      _quantiteCtrl.text = s.quantite.toString();
      _unite = s.unite;
      _quantiteMinCtrl.text = s.quantiteMin > 0 ? s.quantiteMin.toString() : '';
      _dateEntree = s.dateEntree;
      _dateExpiration = s.dateExpiration;
      _fournisseurCtrl.text = s.fournisseur ?? '';
      _coutCtrl.text = s.coutUnitaire?.toString() ?? '';
      _notesCtrl.text = s.notes ?? '';
    } else {
      _dateEntree = DateTime.now().toIso8601String().substring(0, 10);
      _prefillFournisseurRecent();
    }
  }

  /// V2.5 — B5 : pré-remplit le fournisseur avec celui du dernier stock saisi.
  /// Évite la ressaisie quand l'éleveur s'approvisionne toujours au même endroit.
  Future<void> _prefillFournisseurRecent() async {
    try {
      final repo = await db.stocks;
      final stocks = await repo.getAllStocks();
      final dernier = stocks
          .map((s) => s.fournisseur)
          .firstWhere((f) => f != null && f.trim().isNotEmpty,
              orElse: () => null);
      if (dernier != null && mounted && _fournisseurCtrl.text.isEmpty) {
        setState(() => _fournisseurCtrl.text = dernier);
      }
    } catch (_) {
      // silencieux
    }
  }

  @override
  void dispose() {
    for (final c in [_produitCtrl, _quantiteCtrl, _quantiteMinCtrl, _fournisseurCtrl, _coutCtrl, _notesCtrl]) {
      c.dispose();
    }
    _formCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CuFormScaffold(
      controller: _formCtrl,
      appBar: CuAppBar(title: widget.stock != null ? 'Modifier le stock' : 'Nouveau stock', showActions: false),
      child: Form(
        key: _formKey,
        onChanged: _formCtrl.markDirty,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('📦 Informations produit'),
            TextFormField(
              controller: _produitCtrl,
              decoration: const InputDecoration(labelText: 'Nom du produit *', prefixIcon: Icon(Icons.inventory)),
              validator: (v) => v!.isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _typeAliment,
              decoration: const InputDecoration(labelText: 'Type d\'aliment *', prefixIcon: Icon(Icons.category)),
              items: Stock.typesAliments.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _typeAliment = v!),
            ),
            const SizedBox(height: 12),

            _section('📊 Quantités'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantiteCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité *', prefixIcon: Icon(Icons.numbers)),
                    validator: Validators.quantiteStock,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unite,
                    decoration: const InputDecoration(labelText: 'Unité'),
                    items: Stock.unites.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _unite = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantiteMinCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Seuil d\'alerte minimum ($_unite)',
                prefixIcon: const Icon(Icons.warning_amber),
                helperText: 'Recevez une alerte quand le stock passe sous ce seuil',
              ),
              // Optionnel — si saisi, doit être >= 0.
              validator: (v) => Validators.prixOuZero(v, requisField: false),
            ),
            const SizedBox(height: 12),

            _section('📅 Dates & Fournisseur'),
            _datePicker("Date d'entrée en stock", _dateEntree, (d) => setState(() => _dateEntree = d)),
            const SizedBox(height: 12),
            _datePicker("Date d'expiration", _dateExpiration, (d) => setState(() => _dateExpiration = d)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fournisseurCtrl,
                    decoration: const InputDecoration(labelText: 'Fournisseur', prefixIcon: Icon(Icons.store)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _coutCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Prix /$_unite (${AppTheme.devise})', prefixIcon: const Icon(Icons.euro)),
                    // Prix optionnel — refuse négatif si saisi.
                    validator: (v) => Validators.prix(v, requisField: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 24),
            // V2.5 — Sprint 4 : CTA unifié via CuButton.
            CuButton(
              label: widget.stock != null ? 'Enregistrer les modifications' : 'Ajouter au stock',
              icon: widget.stock != null ? Icons.save : Icons.add_box,
              variant: CuButtonVariant.primary,
              size: CuButtonSize.lg,
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ).responsive(),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: context.cuTextPrimary)),
  );

  Widget _datePicker(String label, String? value, Function(String) onPick) {
    return InkWell(
      onTap: () async {
        final init = value != null ? DateTime.tryParse(value) ?? DateTime.now() : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: init,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onPick(picked.toIso8601String().substring(0, 10));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: value != null ? IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: () => setState(() {
              if (label.contains('expiration')) {
                _dateExpiration = null;
              } else {
                _dateEntree = null;
              }
            }),
          ) : null,
        ),
        child: Text(
          value != null ? formatDate(value) : 'Non définie',
          style: TextStyle(color: value != null ? Colors.black87 : Colors.grey),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final stock = Stock(
      id: widget.stock?.id,
      produit: _produitCtrl.text.trim(),
      typeAliment: _typeAliment,
      quantite: double.parse(_quantiteCtrl.text.replaceAll(',', '.')),
      unite: _unite,
      quantiteMin: _quantiteMinCtrl.text.isEmpty ? 0 : (double.tryParse(_quantiteMinCtrl.text.replaceAll(',', '.')) ?? 0),
      dateEntree: _dateEntree,
      dateExpiration: _dateExpiration,
      fournisseur: _fournisseurCtrl.text.trim().isEmpty ? null : _fournisseurCtrl.text.trim(),
      coutUnitaire: _coutCtrl.text.isEmpty ? null : double.tryParse(_coutCtrl.text.replaceAll(',', '.')),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (widget.stock == null) {
      await db.insertStock(stock);
    } else {
      await db.updateStock(stock);
    }

    if (mounted) {
      _formCtrl.markClean();
      showSuccessSnackBar(context, 'Stock sauvegardé avec succès !');
      Navigator.pop(context, true);
    }
  }
}
