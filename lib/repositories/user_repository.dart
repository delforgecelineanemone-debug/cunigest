// ──────────────────────────────────────────────────────────────
// Repository : Utilisateurs (multi-utilisateur local)
// ──────────────────────────────────────────────────────────────
// Authentification PIN locale uniquement (4-6 chiffres).
// Le PIN est haché en SHA-256 + un sel fixe applicatif.
//
// IMPORTANT : ce n'est pas une protection cryptographique forte.
// Quelqu'un qui a accès au fichier .db peut lire toutes les
// données. Le PIN sert juste à séparer les comptes admin/soigneur
// au niveau de l'UI.
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/user.dart';

class UserRepository {
  final Database db;
  UserRepository(this.db);

  static const String _salt = 'cunigest_v2_pin_salt_4f7a';

  /// Hache un PIN avec sel
  static String hashPin(String pin) {
    final bytes = utf8.encode(_salt + pin);
    return sha256.convert(bytes).toString();
  }

  /// Crée un utilisateur (rôle 'admin' ou 'soigneur')
  Future<int> create({
    required String nom,
    required String role,
    required String pin,
  }) {
    return db.insert('users', {
      'nom': nom,
      'role': role,
      'pin_hash': hashPin(pin),
      'date_creation': DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  /// Liste tous les utilisateurs
  Future<List<AppUser>> getAll() async {
    final maps = await db.query('users', orderBy: 'role DESC, nom ASC');
    return maps.map((m) => AppUser.fromMap(m)).toList();
  }

  /// Trouve par nom
  Future<AppUser?> findByName(String nom) async {
    final maps = await db.query('users', where: 'nom = ?', whereArgs: [nom]);
    if (maps.isEmpty) return null;
    return AppUser.fromMap(maps.first);
  }

  /// Vérifie un PIN pour un utilisateur ; retourne l'utilisateur si OK
  Future<AppUser?> authenticate(String nom, String pin) async {
    final user = await findByName(nom);
    if (user == null) return null;
    if (user.pinHash != hashPin(pin)) return null;
    // Met à jour la dernière connexion
    await db.update(
      'users',
      {'derniere_connexion': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return user;
  }

  /// Compte le nombre d'utilisateurs (utile pour savoir si un onboarding est nécessaire)
  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Met à jour le PIN d'un utilisateur
  Future<int> updatePin(int userId, String newPin) {
    return db.update(
      'users',
      {'pin_hash': hashPin(newPin)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Supprime un utilisateur (mais garde au moins un admin)
  Future<bool> delete(int userId) async {
    final user = (await db.query('users', where: 'id = ?', whereArgs: [userId])).firstOrNull;
    if (user == null) return false;
    if (user['role'] == 'admin') {
      final adminCount = await db.rawQuery(
        "SELECT COUNT(*) as c FROM users WHERE role = 'admin'",
      );
      if ((adminCount.first['c'] as int) <= 1) return false; // Bloqué : dernier admin
    }
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    return true;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
