# Dépendances fonctionnelles – Groupe Queen Bee

## Les DF de extrait_plat

| DF | En français |
| :--- | :--- |
| `site_id` → `site_nom, pays` | Un site rucher a un seul nom et se trouve dans un seul pays. |
| `ruche_code` → `site_id, telephone` | Une ruche est installée sur un seul site et appartient à une seule apicultrice (identifiée par son téléphone). |
| `telephone` → `apicultrice, cooperative` | Un numéro de téléphone désigne une seule apicultrice et sa coopérative (dans cet extrait). |
| `ruche_code, horodatage` → `poids_kg, temp_int_c` | Une ruche n’envoie qu’une seule mesure (poids et température) à un instant donné. |

---

## Trois fermetures et la clé candidate

### 1. Fermeture de `{site_id}`

| Tour | DF utilisée | `{site_id}⁺` |
| :--- | :--- | :--- |
| 0 | aucune | `{site_id}` |
| 1 | `site_id` → `site_nom, pays` | `+ site_nom, pays` |
| 2 | plus rien ne s’ajoute | **3 colonnes sur 10 : pas une clé** |

### 2. Fermeture de `{ruche_code}`

| Tour | DF utilisée | `{ruche_code}⁺` |
| :--- | :--- | :--- |
| 0 | aucune | `{ruche_code}` |
| 1 | `ruche_code` → `site_id, telephone` | `+ site_id, telephone` |
| 2 | `site_id` → `site_nom, pays` ; `telephone` → `apicultrice, cooperative` | `+ site_nom, pays, apicultrice, cooperative` |
| 3 | plus rien ne s’ajoute | **7 colonnes sur 10 : pas une clé** (il manque l'horodatage et les valeurs de mesure) |

### 3. Fermeture de `{ruche_code, horodatage}`

| Tour | DF utilisée | `{ruche_code, horodatage}⁺` |
| :--- | :--- | :--- |
| 0 | aucune | `{ruche_code, horodatage}` |
| 1 | `ruche_code` → `site_id, telephone` ; `ruche_code, horodatage` → `poids_kg, temp_int_c` | `+ site_id, telephone, poids_kg, temp_int_c` |
| 2 | `site_id` → `site_nom, pays` ; `telephone` → `apicultrice, cooperative` | `+ site_nom, pays, apicultrice, cooperative` |
| 3 | plus rien ne s’ajoute | **10 colonnes sur 10 : c'est une clé !** |

**Conclusion sur la clé candidate :**
La clé candidate de `extrait_plat` est **`{ruche_code, horodatage}`**. On ne peut rien en retirer car `{ruche_code}⁺` ne donne que 7 colonnes sur 10, et `{horodatage}⁺` ne donne que lui-même (plusieurs ruches mesurent à la même heure).

---

## Question de l'étape 4.3 : Impact d'une identification par le nom
Si l’application identifiait les apicultrices par leur nom (`apicultrice`), les deux **« Aminata Diop »** seraient confondues en une seule personne : l'une pourrait voir ou modifier les ruches de l'autre (atteinte à la confidentialité et à l'intégrité des données).


---

### Testez-vous · Lab 4 (Réponses)
1. **Que veut dire `site_id → pays` ?** : Si on connaît l'identifiant d'un site rucher (`site_id`), on connaît de manière unique le pays dans lequel il se trouve (un site ne peut pas être à cheval sur deux pays).
2. **Pourquoi `{ruche_code}` n’est-il pas une clé de `extrait_plat` ?** : Parce que `extrait_plat` contient une ligne par mesure (48 mesures par ruche sur 24 h). Une même ruche apparaît donc 48 fois dans la table : `{ruche_code}` seul ne permet pas de distinguer une mesure précise, il faut l'associer à `horodatage`.
3. **Pourquoi « 0 ligne » ne prouve-t-il pas qu’une DF est vraie ?** : Parce qu'une requête SQL ne teste que les données présentes à un instant T (un jeu d'essai limité). Ce n'est pas parce qu'il n'y a pas encore d'homonyme dans le jeu d'essai que la règle métier est vraie pour toujours.
