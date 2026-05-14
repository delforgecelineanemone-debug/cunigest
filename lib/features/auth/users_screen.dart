// ──────────────────────────────────────────────────────────────
// Écran : Gestion des utilisateurs (admin uniquement)
// ──────────────────────────────────────────────────────────────
// Permet à un administrateur de :
// - Créer un compte (admin ou soigneur) avec PIN
// - Changer le PIN d'un utilisateur existant
// - Supprimer un utilisateur (sauf le dernier admin)
//
// Si aucun utilisateur n'existe, un onboarding est proposé pour
// créer le premier compte admin.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/db_helper.dart';
import '../../models/user.dart';
import '../../providers/state_providers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await DBHelper.instance.users;
    final users = await repo.getAll();
    if (mounted) setState(() { _users = users; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final estAdmin = session.isAdmin || !session.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('👥 Utilisateurs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (!estAdmin)
                  const AlertBanner(
                    message: 'Seuls les administrateurs peuvent gérer les comptes.',
                    color: Colors.orange,
                    icon: Icons.lock,
                  ),
                if (_users.isEmpty)
                  EmptyState(
                    message:
                        'Aucun utilisateur.\nCréez le premier compte admin pour activer la gestion des rôles.',
                    icon: Icons.person_add,
                    onAction: () => _creerUtilisateur(forcerAdmin: true),
                    actionLabel: 'Créer le premier admin',
                  )
                else
                  ..._users.map((u) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: u.role == 'admin'
                                ? AppTheme.primary
                                : Colors.blue,
                            child: Text(u.nom[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(u.nom),
                          subtitle: Text(
                            '${u.roleLabel}${u.derniereConnexion != null ? "\nDernière connexion : ${u.derniereConnexion!.substring(0, 10)}" : ""}',
                          ),
                          isThreeLine: u.derniereConnexion != null,
                          trailing: estAdmin
                              ? PopupMenuButton<String>(
                                  onSelected: (v) => _action(v, u),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'pin',
                                        child: Text('🔑 Changer le PIN')),
                                    PopupMenuItem(
                                        value: 'supprimer',
                                        child: Text('🗑️ Supprimer')),
                                  ],
                                )
                              : null,
                        ),
                      )),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: estAdmin
          ? FloatingActionButton.extended(
              onPressed: _creerUtilisateur,
              icon: const Icon(Icons.person_add),
              label: const Text('Nouvel utilisateur'),
            )
          : null,
    );
  }

  Future<void> _action(String v, AppUser u) async {
    if (v == 'pin') return _changerPin(u);
    if (v == 'supprimer') return _supprimer(u);
  }

  Future<void> _creerUtilisateur({bool forcerAdmin = false}) async {
    final nomCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String role = forcerAdmin ? 'admin' : 'soigneur';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Nouvel utilisateur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'PIN (4-6 chiffres) *',
                ),
              ),
              const SizedBox(height: 12),
              if (!forcerAdmin)
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('👤 Administrateur')),
                    DropdownMenuItem(
                        value: 'soigneur', child: Text('🧑‍🌾 Soigneur')),
                  ],
                  onChanged: (v) => setDialog(() => role = v!),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Créer')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (nomCtrl.text.trim().isEmpty || pinCtrl.text.length < 4) {
      if (mounted) showErrorSnackBar(context, 'Nom et PIN (4 chiffres min) requis');
      return;
    }

    try {
      final repo = await DBHelper.instance.users;
      await repo.create(
        nom: nomCtrl.text.trim(),
        role: role,
        pin: pinCtrl.text,
      );
      _load();
      if (mounted) showSuccessSnackBar(context, 'Utilisateur créé !');
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context,
            e.toString().contains('UNIQUE')
                ? 'Ce nom existe déjà'
                : 'Erreur : $e');
      }
    }
  }

  Future<void> _changerPin(AppUser u) async {
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nouveau PIN pour ${u.nom}'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: 'PIN (4-6 chiffres)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Valider')),
        ],
      ),
    );
    if (ok != true || pinCtrl.text.length < 4) return;
    final repo = await DBHelper.instance.users;
    await repo.updatePin(u.id!, pinCtrl.text);
    if (mounted) showSuccessSnackBar(context, 'PIN mis à jour');
  }

  Future<void> _supprimer(AppUser u) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ${u.nom} ?',
      message: 'Cette action est irréversible.',
      confirmColor: AppTheme.error,
    );
    if (!ok) return;
    final repo = await DBHelper.instance.users;
    final success = await repo.delete(u.id!);
    if (!success && mounted) {
      showErrorSnackBar(context, 'Impossible : c\'est le dernier admin.');
    } else {
      _load();
      if (mounted) showSuccessSnackBar(context, 'Supprimé');
    }
  }
}
