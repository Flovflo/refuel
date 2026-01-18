# 🚀 REFUEL - Premier Prompt pour Codex

Copie ce prompt dans Codex pour commencer le développement :

---

## Prompt Principal

```text
Tu es un Senior iOS Engineer expert. Ta mission est de développer l'application REFUEL.

1.  **Lois Fondamentales** : Lis IMPÉRATIVEMENT le fichier `refuel/AGENTS.md`. C'est ta constitution. Tu DOIS respecter le workflow "Think-Plan-Test-Code-Verify".

2.  **Contexte** : Utilise `refuel/codex.md` pour les références rapides (API, formules).

3.  **Tâche Immédiate** :
    -   Crée les Models (`FuelStation`, `FuelPrice`, `FuelType`).
    -   Crée le Service API (`FuelDataService`) et le Gestionnaire GPS (`LocationManager`).
    -   **CONTRAINTE CRITIQUE** : Pour chaque composant, crée d'abord un TEST UNITAIRE (XCTest) dans `refuelTests/`. Le code ne doit être écrit que si le test est prêt.

4.  **Ordre d'exécution** :
    a.  Analyse `AGENTS.md`.
    b.  Implémente `refuel/Models/`.
    c.  Implémente `refuelTests/ModelsTests.swift` et vérifie le build.
    d.  Implémente `refuel/Services/`.
    e.  Implémente `refuelTests/ServicesTests.swift` et vérifie le build.

Attends mes instructions pour la partie UI une fois que la couche Data/Logic est solide et testée.
```

---

## Suite (UI)

Une fois la partie Data validée :

```text
Les tests passent. Maintenant, passons à l'UI (LiquidGlass Design).

1.  Crée le ViewModel `StationsViewModel` (@Observable).
2.  Crée les composants UI (`GlassCard`, `PriceBadge`).
3.  Assemble les vues (`StationListView`, `StationDetailView`).
4.  N'oublie pas : divise les coordonnées par 100 000 !
```
