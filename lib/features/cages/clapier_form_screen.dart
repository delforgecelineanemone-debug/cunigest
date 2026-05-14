// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Clapier (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Création / édition d'un clapier (ensemble physique de cages),
// rattaché à un bâtiment.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/clapier.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class ClapierFormScreen extends StatefulWidget {
  final int batimentId;
  final String batimentNom;
  final Clapier? clapier;

  const ClapierFormScreen({
    super.key,
    required this.batimentId,
    required this.batimentNom,
    this.clapier,
  });

  @override
  State<ClapierFormScreen> createState() => _ClapierFormScreenState();
}

class _ClapierFormScreenState extends State<ClapierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _notes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.clapier;
    _nom = TextEditingController(text: c?.nom ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nom.dispose();
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
      final c = Clapier(
        id: widget.clapier?.id,
        nom: _nom.text.trim(),
        batimentId: widget.batimentId,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        dateCreation: widget.clapier?.dateCreation,
      );
      if (widget.clapier == null) {
        await repo.insertClapier(c);
      } else {
        await repo.updateClapier(c);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(widget.clapier == null
            ? 'Clapier créé.'
            : 'Clapier mis à jour.'),
      ));
      navigator.pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.clapier != null;
    return Scaffold(
      appBar: CuAppBar(title: isEdit ? 'Modifier le clapier' : 'Nouveau clapier', showActions: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.grey.shade100,
              child: ListTile(
                leading: const Icon(Icons.home_work, color: Colors.grey),
                title: const Text('Bâtiment'),
                subtitle: Text(widget.batimentNom),
              ),
            ),
            const SizedBox(height: 12),
            const FormSection('Identification'),
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(
                labelText: 'Nom du clapier *',
                hintText: 'Ex : Reproducteurs A',
                prefixIcon: Icon(Icons.shelves),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
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
