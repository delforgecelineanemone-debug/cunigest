// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Lot d'engraissement (création)
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/lot.dart';
import '../../services/id_generator_service.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class LotFormScreen extends StatefulWidget {
  final Lot? lot;
  const LotFormScreen({super.key, this.lot});

  @override
  State<LotFormScreen> createState() => _LotFormScreenState();
}

class _LotFormScreenState extends State<LotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formCtrl = CuFormController(); // V2.5 — Sprint 3 : anti-perte de saisie
  final _codeCtrl = TextEditingController();
  final _cageCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _poidsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.lot;
    if (l != null) {
      _codeCtrl.text = l.code;
      _cageCtrl.text = l.cage ?? '';
      _nombreCtrl.text = l.nombreInitial.toString();
      _poidsCtrl.text = l.poidsInitial?.toString() ?? '';
      _notesCtrl.text = l.notes ?? '';
      _date = l.dateCreation;
    } else {
      _genererCodeAuto();
    }
  }

  Future<void> _genererCodeAuto() async {
    try {
      final id = await IdGeneratorService.nextLotId();
      if (!mounted) return;
      if (_codeCtrl.text.trim().isEmpty) {
        setState(() => _codeCtrl.text = id);
      }
    } catch (_) {/* silencieux */}
  }

  Future<void> _regenererCode() async {
    try {
      final id = await IdGeneratorService.nextLotId();
      if (!mounted) return;
      setState(() => _codeCtrl.text = id);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Génération impossible : $e');
    }
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _cageCtrl, _nombreCtrl, _poidsCtrl, _notesCtrl]) {
      c.dispose();
    }
    _formCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.lot != null;
    return CuFormScaffold(
      controller: _formCtrl,
      appBar: CuAppBar(title: isEdit ? 'Modifier le lot' : 'Nouveau lot', showActions: false),
      child: Form(
        key: _formKey,
        onChanged: _formCtrl.markDirty,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: 'Code du lot *',
                helperText: widget.lot == null
                    ? 'Auto-généré (modifiable). Touche 🔄 pour régénérer.'
                    : 'Ex : LT-2026-05-001, BANDE-A...',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.tag),
                suffixIcon: widget.lot == null
                    ? IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Régénérer un nouvel ID',
                        onPressed: _regenererCode,
                      )
                    : null,
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cageCtrl,
              decoration: const InputDecoration(
                  labelText: 'Cage / Bande', prefixIcon: Icon(Icons.grid_on)),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_date),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() =>
                      _date = picked.toIso8601String().substring(0, 10));
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Date de mise en lot (sevrage)',
                    prefixIcon: Icon(Icons.calendar_today)),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nombreCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Nombre de lapereaux *',
                        prefixIcon: Icon(Icons.numbers)),
                    validator: (v) => (v == null ||
                            int.tryParse(v) == null ||
                            int.parse(v) <= 0)
                        ? 'Nombre invalide'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _poidsCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Poids initial total (kg)',
                      helperText: 'pour calcul GMQ',
                      prefixIcon: Icon(Icons.monitor_weight),
                      suffixText: 'kg',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Enregistrer' : 'Créer le lot'),
            ),
          ],
        ),
      ).responsive(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final lot = Lot(
      id: widget.lot?.id,
      code: _codeCtrl.text.trim(),
      dateCreation: _date,
      cage: _cageCtrl.text.trim().isEmpty ? null : _cageCtrl.text.trim(),
      nombreInitial: int.parse(_nombreCtrl.text),
      poidsInitial:
          _poidsCtrl.text.isEmpty ? null : double.tryParse(_poidsCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      statut: widget.lot?.statut ?? 'en_cours',
    );

    try {
      final repo = await DBHelper.instance.lots;
      if (widget.lot == null) {
        await repo.insertLot(lot);
      } else {
        await repo.update(lot);
      }
      if (mounted) {
        _formCtrl.markClean();
        showSuccessSnackBar(context, 'Lot enregistré !');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context,
            e.toString().contains('UNIQUE')
                ? 'Ce code de lot existe déjà'
                : 'Erreur : $e');
      }
    }
  }
}
