// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Cage (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Création / édition d'une cage (numéro UNIQUE, capacité, statut).
// Rattachée à un clapier.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/cage.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class CageFormScreen extends StatefulWidget {
  final int clapierId;
  final String clapierNom;
  final Cage? cage;

  const CageFormScreen({
    super.key,
    required this.clapierId,
    required this.clapierNom,
    this.cage,
  });

  @override
  State<CageFormScreen> createState() => _CageFormScreenState();
}

class _CageFormScreenState extends State<CageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numero;
  late final TextEditingController _capacite;
  late final TextEditingController _notes;
  late String _statut;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cage;
    _numero = TextEditingController(text: c?.numero ?? '');
    _capacite = TextEditingController(text: (c?.capaciteMax ?? 1).toString());
    _notes = TextEditingController(text: c?.notes ?? '');
    _statut = c?.statut ?? 'vide';
  }

  @override
  void dispose() {
    _numero.dispose();
    _capacite.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final repo = await DBHelper.instance.cages;
      final c = Cage(
        id: widget.cage?.id,
        numero: _numero.text.trim(),
        clapierId: widget.clapierId,
        capaciteMax: int.tryParse(_capacite.text) ?? 1,
        statut: _statut,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        dateCreation: widget.cage?.dateCreation,
      );
      if (widget.cage == null) {
        await repo.insertCage(c);
      } else {
        await repo.updateCage(c);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(widget.cage == null
            ? 'Cage créée.'
            : 'Cage mise à jour.'),
      ));
      navigator.pop(true);
    } catch (e) {
      // Doublon de numéro : message clair
      final msg = e.toString().contains('UNIQUE') ||
              e.toString().contains('unique')
          ? 'Ce numéro de cage existe déjà.'
          : 'Erreur : $e';
      if (mounted) showErrorSnackBar(context, msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cage != null;
    return Scaffold(
      appBar: CuAppBar(title: isEdit ? 'Modifier la cage' : 'Nouvelle cage', showActions: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.grey.shade100,
              child: ListTile(
                leading: const Icon(Icons.shelves, color: Colors.grey),
                title: const Text('Clapier'),
                subtitle: Text(widget.clapierNom),
              ),
            ),
            const SizedBox(height: 12),
            const FormSection('Identification'),
            TextFormField(
              controller: _numero,
              decoration: const InputDecoration(
                labelText: 'Numéro de cage *',
                hintText: 'Ex : C4B1',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Numéro requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacite,
              decoration: const InputDecoration(
                labelText: 'Capacité maximale (lapins) *',
                hintText: 'Nombre maximum de lapins dans cette cage',
                prefixIcon: Icon(Icons.groups),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Entier ≥ 1 requis';
                if (n > 999) return 'Trop grand (max 999)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const FormSection('État de la cage'),
            DropdownButtonFormField<String>(
              initialValue: _statut,
              decoration: InputDecoration(
                labelText: 'Statut',
                prefixIcon: Icon(cageStatutIcon(_statut),
                    color: cageStatutColor(_statut)),
              ),
              items: kCageStatuts
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(cageStatutIcon(s),
                                color: cageStatutColor(s), size: 18),
                            const SizedBox(width: 8),
                            Text(cageStatutLabel(s)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _statut = v ?? 'vide'),
            ),
            const SizedBox(height: 16),
            const FormSection('Notes'),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes libres',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(_busy
                  ? 'Enregistrement…'
                  : (isEdit ? 'Enregistrer' : 'Créer')),
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
