# Lab 5 · Formes normales et normalisation – Queen Bee

## 1. Diagnostic des anomalies dans `extrait_plat` (Étape 5.1)

* **Anomalie de mise à jour :** Modifier `Sénégal` en `Senegal` sur une seule ligne crée un 4e pays fictif dans la base. **Cause :** la dépendance transitive `ruche_code` → `site_id` → `pays` (violation de la **3NF**).
* **Anomalie de suppression :** Supprimer les mesures d'Awa Diop (qui n'a qu'une seule ruche) efface définitivement son numéro de téléphone. **Cause :** les dépendances partielles `ruche_code` → `telephone` → `apicultrice, cooperative` (violation de la **2NF** et de la **3NF**).
* **Anomalie d'insertion :** Avec la clé primaire `(ruche_code, horodatage)`, il est impossible d'enregistrer un nouveau site rucher tant qu'il n'a ni ruche ni mesure. **Cause :** `ruche_code` fait partie de la clé primaire et ne peut pas être `NULL` (violation de la **2NF**).

---

## 2. Classement des dépendances par forme normale

| Forme normale | Règle | Vos dépendances qui la violent dans `extrait_plat` |
| :--- | :--- | :--- |
| **1NF** | Chaque case contient une seule valeur (attributs atomiques) et il existe une clé. | Aucune violation (chaque colonne contient une valeur simple). |
| **2NF** | En 1NF, et aucune colonne non-clé ne dépend d’une **partie** de la clé candidate `{ruche_code, horodatage}`. | `ruche_code` → `site_id, site_nom, pays, telephone, apicultrice, cooperative` (ces 6 colonnes ne dépendent que de `ruche_code`, pas de `horodatage`). |
| **3NF** | En 2NF, et aucune colonne non-clé ne dépend d’une autre colonne non-clé (pas de dépendance transitive). | `site_id` → `site_nom, pays` et `telephone` → `apicultrice, cooperative` (dépendent d'attributs non-clés). |
| **BCNF** | Pour toute dépendance fonctionnelle non triviale `X → Y`, la partie gauche `X` est une super-clé. | `ruche_code` → `...`, `site_id` → `...`, et `telephone` → `...` (aucun de ces déterminants n'est clé de `extrait_plat`). |

---

## 3. Vérification BCNF des tables `norm` et conclusion (Étape 5.3)

### Vérification table par table
1. **`norm.site (site_id, site_nom, pays)` :** L'unique DF est `site_id → site_nom, pays`. `site_id` est la clé primaire : **BCNF respectée**.
2. **`norm.apicultrice (telephone, apicultrice, cooperative)` :** L'unique DF est `telephone → apicultrice, cooperative`. `telephone` est la clé primaire : **BCNF respectée**.
3. **`norm.ruche (ruche_code, site_id, telephone)` :** L'unique DF est `ruche_code → site_id, telephone`. `ruche_code` est la clé primaire : **BCNF respectée**.
4. **`norm.mesure (ruche_code, horodatage, poids_kg, temp_int_c)` :** L'unique DF est `ruche_code, horodatage → poids_kg, temp_int_c`. `(ruche_code, horodatage)` est la clé primaire : **BCNF respectée**.

### Conclusion
Une seule ligne modifiée a fait passer l’enquête de **3** à **4** pays. Une base non normalisée ne peut pas servir de preuve.

---

### Testez-vous · Lab 5 (Réponses)
1. **Un exemple de chaque anomalie dans `extrait_plat` :**
   * *Mise à jour :* Changer le pays d'une seule ligne transforme `Sénégal` en `Senegal` sur 1 ligne tout en laissant `Sénégal` sur les autres.
   * *Suppression :* Supprimer les mesures d'une apicultrice ayant une seule ruche supprime aussi son nom et son téléphone de la base.
   * *Insertion :* Impossible d'insérer un site vide (`CI-BOUA`) sans ruche ni horodatage car la clé primaire refuse les valeurs `NULL`.
2. **Pourquoi `ruche_code → site_id` viole-t-il la 2NF ?** : Parce que la clé primaire de `extrait_plat` est composée de deux colonnes `{ruche_code, horodatage}`, et que `site_id` ne dépend que d'une **seule partie** de cette clé (`ruche_code`).
3. **Comment prouve-t-on en SQL qu’une décomposition est sans perte ?** : On recompose la table d'origine par jointure dans une vue (`norm.reconstruit`) et on vérifie par double différence (`(A EXCEPT B) UNION ALL (B EXCEPT A)`) que le résultat renvoie **0 ligne**.
