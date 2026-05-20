# 🤝 Contribuer à CuniGest

Merci de votre intérêt pour CuniGest ! Ce guide vous accompagne dans le processus de contribution au projet.

---

## 📋 Table des matières

- [Comment contribuer](#comment-contribuer)
- [Conventions de commit](#conventions-de-commit)
- [Process de Pull Request](#process-de-pull-request)
- [Standards de code](#standards-de-code)
- [Reporting de bugs](#reporting-de-bugs)
- [Demande de fonctionnalités](#demande-de-fonctionnalités)
- [Code de conduite](#code-de-conduite)

---

## 🚀 Comment contribuer

### 1. Fork & Clone

```bash
# Forkez le dépôt via l'interface GitHub, puis clonez votre fork
git clone https://github.com/<votre-utilisateur>/cunicole_app.git
cd cunicole_app

# Ajoutez le dépôt original comme remote
git remote add upstream https://github.com/CuniGest/cunicole_app.git
```

### 2. Créer une branche

Créez toujours une branche dédiée à partir de `main` :

```bash
git checkout main
git pull upstream main
git checkout -b <type>/<description-courte>
```

**Nommage des branches :**

| Type        | Exemple                          |
|-------------|----------------------------------|
| `feature/`  | `feature/ajout-module-vaccins`   |
| `fix/`      | `fix/correction-calcul-gmq`     |
| `docs/`     | `docs/mise-a-jour-readme`        |
| `chore/`    | `chore/upgrade-flutter-3.24`     |
| `refactor/` | `refactor/service-authentification` |

### 3. Développer & Tester

```bash
# Installer les dépendances
flutter pub get

# Lancer les tests
flutter test

# Vérifier le formatage
dart format --set-exit-if-changed .

# Analyser le code
dart analyze
```

### 4. Soumettre

```bash
git add .
git commit -m "feat: ajout du module de vaccination"
git push origin feature/ajout-module-vaccins
```

Puis ouvrez une **Pull Request** sur GitHub.

---

## 📝 Conventions de commit

Nous utilisons les [Conventional Commits](https://www.conventionalcommits.org/fr/) :

```
<type>(<portée optionnelle>): <description>

[corps optionnel]

[pied de page optionnel]
```

### Types autorisés

| Type       | Description                                       |
|------------|---------------------------------------------------|
| `feat`     | Nouvelle fonctionnalité                           |
| `fix`      | Correction de bug                                 |
| `docs`     | Modification de la documentation uniquement       |
| `style`    | Formatage, points-virgules manquants, etc.        |
| `refactor` | Refactorisation sans ajout de fonctionnalité      |
| `test`     | Ajout ou modification de tests                    |
| `chore`    | Maintenance, dépendances, configuration           |
| `perf`     | Amélioration des performances                     |
| `ci`       | Modifications CI/CD                               |

### Exemples

```
feat(reproduction): ajout du suivi des portées
fix(alimentation): correction du calcul des rations quotidiennes
docs: mise à jour du guide d'installation
chore: mise à jour des dépendances Flutter
```

---

## 🔄 Process de Pull Request

1. **Assurez-vous** que votre branche est à jour avec `main`.
2. **Vérifiez** que tous les tests passent localement.
3. **Remplissez** le template de PR fourni.
4. **Attendez** la revue d'au moins un mainteneur.
5. **Répondez** aux commentaires et apportez les modifications demandées.
6. Une fois approuvée, la PR sera **mergée** par un mainteneur.

### Critères d'acceptation

- ✅ Tous les tests passent (CI verte)
- ✅ Le code respecte les conventions de formatage (`dart format`)
- ✅ Pas de warnings dans `dart analyze`
- ✅ La PR est documentée et décrit clairement les changements
- ✅ Les captures d'écran sont fournies pour les changements UI

---

## 🎯 Standards de code

### Flutter / Dart

- **Version Flutter** : Utilisez la version spécifiée dans le fichier `.fvmrc` ou `pubspec.yaml`.
- **Formatage** : Utilisez `dart format` avec la configuration par défaut (ligne max 80 caractères).
- **Analyse** : Aucun warning ne doit apparaître avec `dart analyze`.
- **Null Safety** : Tout le code doit être null-safe.

### Architecture

- Respectez l'architecture existante du projet (services, modèles, écrans).
- Séparez la logique métier de l'interface utilisateur.
- Utilisez les services existants pour l'accès aux données.

### Bonnes pratiques

- Nommez vos variables et fonctions en **anglais**.
- Commentez le code complexe en **français** ou en **anglais**.
- Créez des widgets réutilisables plutôt que de dupliquer du code.
- Utilisez `const` autant que possible pour les widgets.
- Préférez les `StatelessWidget` quand l'état n'est pas nécessaire.

### Tests

- Écrivez des tests unitaires pour la logique métier.
- Ajoutez des tests de widgets pour les composants UI critiques.
- Maintenez une couverture de test raisonnable.

---

## 🐛 Reporting de bugs

Utilisez le [template de bug report](.github/ISSUE_TEMPLATE/bug_report.md) pour signaler un bug.

### Avant de signaler

1. Vérifiez que le bug n'a pas déjà été signalé dans les [issues existantes](https://github.com/CuniGest/cunicole_app/issues).
2. Mettez à jour vers la dernière version de l'application.
3. Essayez de reproduire le bug de manière fiable.

### Informations à fournir

- **Description claire** du problème.
- **Étapes de reproduction** détaillées.
- **Comportement attendu** vs **comportement observé**.
- **Captures d'écran** si applicable.
- **Environnement** : appareil, OS, version de l'application.

---

## 💡 Demande de fonctionnalités

Utilisez le [template de feature request](.github/ISSUE_TEMPLATE/feature_request.md) pour proposer une nouvelle fonctionnalité.

### Conseils

- Décrivez le **problème** que la fonctionnalité résoudrait.
- Proposez une **solution concrète**.
- Mentionnez les **alternatives** envisagées.
- Fournissez un **contexte** sur votre cas d'utilisation (taille d'élevage, etc.).

---

## 📜 Code de conduite

En participant à ce projet, vous vous engagez à respecter les principes suivants :

- **Respect** — Traitez chaque contributeur avec respect et bienveillance.
- **Inclusion** — Accueillez les contributions de tous, indépendamment de l'expérience, du genre, de l'origine ou de toute autre caractéristique personnelle.
- **Collaboration** — Privilégiez le dialogue constructif et la résolution de problèmes.
- **Professionnalisme** — Évitez tout langage ou comportement inapproprié, harcelant ou discriminatoire.
- **Transparence** — Communiquez ouvertement et honnêtement sur vos intentions et vos contributions.

Tout comportement contraire à ces principes pourra entraîner des mesures allant de l'avertissement à l'exclusion du projet.

---

## ❓ Questions ?

Si vous avez des questions, n'hésitez pas à ouvrir une [Discussion](https://github.com/CuniGest/cunicole_app/discussions) ou à contacter les mainteneurs.

Merci de contribuer à CuniGest ! 🐰
