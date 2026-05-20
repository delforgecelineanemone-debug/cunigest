# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [2.4] - 2026-05

### Ajouté
- Audit complet de l'interface utilisateur (UI) — v3.1
- Landing page publique pour la présentation du projet
- Déploiement automatisé via GitHub Pages

### Amélioré
- Cohérence visuelle sur l'ensemble des écrans
- Documentation du projet (README, CONTRIBUTING, templates GitHub)

---

## [2.3] - 2026-04

### Ajouté
- Navigation inférieure avec 5 onglets principaux
- Mode sombre (dark mode) complet
- Écrans d'onboarding pour les nouveaux utilisateurs
- Courbes et graphiques interactifs via `fl_chart`
- États vides (empty states) illustrés sur toutes les listes

### Amélioré
- Expérience utilisateur générale et fluidité de la navigation
- Performance d'affichage des listes de données

---

## [2.2]

### Ajouté
- Module Cages complet avec hiérarchie : Bâtiments → Clapiers → Cages
- Upload et affichage de photos pour les lapins
- Génération de QR codes pour l'identification des cages
- Génération d'étiquettes PDF imprimables pour les cages

### Amélioré
- Organisation et gestion de l'infrastructure d'élevage

---

## [2.1]

### Ajouté
- Chiffrement de la base de données locale avec AES-256
- Gestion fine des permissions Android

### Corrigé
- Stabilisation générale de l'application
- Correction de bugs critiques identifiés en production
- Amélioration de la fiabilité des opérations de données

---

## [2.0]

### Ajouté
- Module Lots d'engraissement complet
- Calcul du Gain Moyen Quotidien (GMQ) et de l'Indice de Consommation (IC)
- Synchronisation cloud via Supabase
- Système multi-utilisateur avec authentification par PIN
- Génération de rapports PDF détaillés
- Système de QR codes pour le suivi des animaux

### Amélioré
- Architecture de l'application pour le support multi-utilisateur
- Performance de synchronisation des données

---

## [1.0]

### Ajouté
- Gestion complète des lapins (fiches individuelles, identification)
- Module de reproduction (accouplements, gestations, mises bas, portées)
- Module de santé (traitements, vaccinations, suivi sanitaire)
- Module d'alimentation (rations, stocks, consommation)
- Module de ventes (enregistrement, suivi des revenus)
- Système de notifications et rappels automatiques
- Base de données locale SQLite

---

[2.4]: https://github.com/CuniGest/cunicole_app/compare/v2.3...v2.4
[2.3]: https://github.com/CuniGest/cunicole_app/compare/v2.2...v2.3
[2.2]: https://github.com/CuniGest/cunicole_app/compare/v2.1...v2.2
[2.1]: https://github.com/CuniGest/cunicole_app/compare/v2.0...v2.1
[2.0]: https://github.com/CuniGest/cunicole_app/compare/v1.0...v2.0
[1.0]: https://github.com/CuniGest/cunicole_app/releases/tag/v1.0
