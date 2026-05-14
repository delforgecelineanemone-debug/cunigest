// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Bâtiment (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Création / édition d'un bâtiment d'élevage.
// Champs : nom (requis), adresse (optionnel), notes.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../widgets/common_widgets.dart';

class BatimentFormScreen extends StatefulWidget {
  final Batiment? batiment;
  const BatimentFormScreen({super.key, this.batiment});

  @override
  State<BatimentFormScreen> createState() => _BatimentFormScreenState();
}

class _BatimentFormScreenState extends State<BatimentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _adresse;
  late final TextEditingController _notes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final b = widget.batiment;
    _nom = TextEditingController(text: b?.nom ?? '');
    _adresse = TextEditingController(text: b?.adresse ?? '');
    _notes = TextEditingController(text: b?.notes ?? '');
  }

  @override
  void dispose() {
    _nom.dispose();
    _adresse.dispose();
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
      final b = Batiment(
        id: widget.batiment?.id,
        nom: _nom.text.trim(),
        adresse: _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        dateCreation: widget.batiment?.dateCreation,
      );
      if (widget.batiment == null) {
        await repo.insertBatiment(b);
      } else {
        await repo.updateBatiment(b);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(widget.batiment == null
            ? 'Bâtiment créé.'
            : 'Bâtiment mis à jour.'),
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
    final isEdit = widget.batiment != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Modifier le bâtiment' : 'Nouveau bâtiment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormSection('Identification'),
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(
                labelText: 'Nom du bâtiment *',
                hintText: 'Ex : Bâtiment principal',
                prefixIcon: Icon(Icons.home_work),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adresse,
              decoration: const InputDecoration(
                labelText: 'Adresse (optionnel)',
                prefixIcon: Icon(Icons.place),
              ),
              textInputAction: TextInputAction.next,
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
