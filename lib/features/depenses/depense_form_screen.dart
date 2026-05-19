// ──────────────────────────────────────────────────────────────
// DepenseFormScreen — création/édition d'une dépense
// (V2.4 — Phase 4 — Finances)
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/db_helper.dart';
import '../../models/depense.dart';
import '../../models/lapin.dart';
import '../../models/lot.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class DepenseFormScreen extends StatefulWidget {
  final Depense? depense;
  const DepenseFormScreen({super.key, this.depense});

  @override
  State<DepenseFormScreen> createState() => _DepenseFormScreenState();
}

class _DepenseFormScreenState extends State<DepenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // V2.5 — UX Sprint 1 : SANS défaut. Imputation comptable doit être
  // un choix explicite (sinon tous les rapports financiers sont biaisés).
  String? _categorie;
  DateTime _date = DateTime.now();

  // V2.5 — Imputation optionnelle (Phase 4)
  // 'aucun' = frais général ; 'lot' = lié à un lot ; 'lapin' = lié à un lapin
  String _imputation = 'aucun';
  int? _lotIdSel;
  int? _lapinIdSel;
  List<Lot> _lots = const [];
  List<Lapin> _lapins = const [];

  @override
  void initState() {
    super.initState();
    final d = widget.depense;
    if (d != null) {
      _montantCtrl.text = d.montant.toStringAsFixed(2);
      _descCtrl.text = d.description ?? '';
      _notesCtrl.text = d.notes ?? '';
      _categorie = d.categorie;
      _date = DateTime.tryParse(d.dateDepense) ?? DateTime.now();
      if (d.lotId != null) {
        _imputation = 'lot';
        _lotIdSel = d.lotId;
      } else if (d.lapinId != null) {
        _imputation = 'lapin';
        _lapinIdSel = d.lapinId;
      }
    }
    _chargerImputables();
  }

  Future<void> _chargerImputables() async {
    final lotsRepo = await DBHelper.instance.lots;
    final lots = await lotsRepo.getAll();
    final lapins = await DBHelper.instance.getLapinsByStatut('actif');
    if (!mounted) return;
    setState(() {
      _lots = lots;
      _lapins = lapins;
    });
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final montant =
        double.tryParse(_montantCtrl.text.replaceAll(',', '.')) ?? 0;
    final repo = await DBHelper.instance.depenses;
    final base = Depense(
      id: widget.depense?.id,
      dateDepense: _date.toIso8601String().substring(0, 10),
      // Garanti non-null par le validator (form.validate() en haut de _save).
      categorie: _categorie!,
      montant: montant,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      lotId: _imputation == 'lot' ? _lotIdSel : null,
      lapinId: _imputation == 'lapin' ? _lapinIdSel : null,
      dateCreation: widget.depense?.dateCreation,
    );
    if (widget.depense == null) {
      await repo.insert(base);
    } else {
      await repo.update(base);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.depense != null;
    return Scaffold(
      appBar: CuAppBar(title: isEdit ? 'Modifier dépense' : 'Nouvelle dépense', showActions: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _montantCtrl,
              decoration: InputDecoration(
                labelText: 'Montant (${AppTheme.devise}) *',
                prefixIcon: const Icon(Icons.payments),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categorie,
              decoration: const InputDecoration(
                labelText: 'Catégorie *',
                prefixIcon: Icon(Icons.category),
                helperText:
                    'Choix obligatoire — utilisé pour les rapports financiers.',
                helperMaxLines: 2,
              ),
              hint: const Text('— Sélectionnez —'),
              items: kDepenseCategories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(depenseCategorieLabel(c)),
                      ))
                  .toList(),
              validator: (v) => v == null ? 'Catégorie obligatoire' : null,
              onChanged: (v) => setState(() => _categorie = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: context.cuBorder),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle:
                  Text('${_date.day}/${_date.month}/${_date.year}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.short_text),
                hintText: 'Ex : Sac granulés 25kg',
              ),
            ),
            const SizedBox(height: 16),

            // ── Imputation (V2.5 — Phase 4) ──
            const Text('Imputer cette dépense à...',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'aucun',
                    label: Text('Aucun', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.public, size: 16)),
                ButtonSegment(
                    value: 'lot',
                    label: Text('Lot', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.groups, size: 16)),
                ButtonSegment(
                    value: 'lapin',
                    label: Text('Lapin', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.pets, size: 16)),
              ],
              selected: {_imputation},
              onSelectionChanged: (s) => setState(() => _imputation = s.first),
            ),
            if (_imputation == 'lot') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _lotIdSel,
                decoration: const InputDecoration(
                  labelText: 'Lot concerné',
                  prefixIcon: Icon(Icons.groups),
                ),
                items: _lots
                    .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(
                              '${l.code} (${l.nombreInitial} sujets — ${l.statut})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _lotIdSel = v),
                validator: (v) =>
                    v == null ? 'Choisir un lot ou changer l\'imputation' : null,
              ),
            ],
            if (_imputation == 'lapin') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _lapinIdSel,
                decoration: const InputDecoration(
                  labelText: 'Lapin concerné',
                  prefixIcon: Icon(Icons.pets),
                ),
                items: _lapins
                    .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(
                              '${l.displayName} (${l.numeroBague})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _lapinIdSel = v),
                validator: (v) =>
                    v == null ? 'Choisir un lapin ou changer l\'imputation' : null,
              ),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'Mettre à jour' : 'Enregistrer'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Supprimer cette dépense ?',
                    message:
                        '${formatMontant(widget.depense!.montant)} — ${depenseCategorieLabel(widget.depense!.categorie)}',
                  );
                  if (!ok || !mounted) return;
                  final repo = await DBHelper.instance.depenses;
                  await repo.delete(widget.depense!.id!);
                  if (!mounted) return;
                  navigator.pop(true);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ],
          ],
        ),
      ).responsive(),
    );
  }
}
