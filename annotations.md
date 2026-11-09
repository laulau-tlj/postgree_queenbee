# Lab 1 · Modèle entité-association – Queen Bee

## Question 1 : De quoi le système doit-il se souvenir ?

Le système doit se souvenir de **9 choses (entités)** :
1. **Site** (site rucher)
2. **Ruche**
3. **Apicultrice**
4. **Coopérative**
5. **Mesure** (relevé des capteurs)
6. **Inspection**
7. **Récolte**
8. **Alerte**
9. **Utilisateur** (compte de connexion)

---

## Question 2 : Que garde-t-on sur chacune, et qu’est-ce qui la distingue ?

| Chose | Ce qu’on garde | Ce qui la distingue |
| :--- | :--- | :--- |
| site | nom, pays | un code lisible attribué (ex. `SN-CASA`) ou `id_site` |
| ruche | code, latitude, longitude, date d’installation | le code unique (ex. `SN-CASA-014`) ou `id_ruche` |
| apicultrice | nom, téléphone | un identifiant unique `id_apicultrice` (deux personnes peuvent avoir le même nom) |
| coopérative | nom | un identifiant unique `id_cooperative` |
| mesure | horodatage, poids, température intérieure, température extérieure, humidité, activité sonore, niveau de batterie | la ruche et l’horodatage (ou `id_mesure`) |
| inspection | date, état de la colonie, présence de la reine, observations | un identifiant unique `id_inspection` |
| récolte | date, quantité, statut (déclarée / validée), date de validation | un identifiant unique `id_recolte` |
| alerte | type (essaimage, vol, capteur silencieux), niveau de confiance, horodatage, statut | un identifiant unique `id_alerte` |
| utilisateur | login, mot de passe, rôle (apicultrice, coordinateur, gestionnaire, administrateur) | un identifiant unique `id_utilisateur` |

---

## Question 3 : Comment sont-elles liées ?

| Lien | Dans un sens | Dans l’autre sens |
| :--- | :--- | :--- |
| ruche – apicultrice | une ruche appartient à une seule apicultrice (`1,1`) | une apicultrice possède zéro, une ou plusieurs ruches (`0,n`) |
| site – ruche | un site abrite zéro, une ou plusieurs ruches (`0,n`) | une ruche est installée sur un seul site (`1,1`) |
| apicultrice – coopérative | une apicultrice adhère à une ou plusieurs coopératives (`1,n`) | une coopérative regroupe plusieurs adhérentes (`0,n` ou `1,n`) |
| ruche – mesure | une ruche émet zéro, une ou plusieurs mesures (`0,n`) | une mesure provient d’une seule ruche (`1,1`) |
| ruche – récolte | une ruche produit zéro, une ou plusieurs récoltes (`0,n`) | une récolte concerne une seule ruche (`1,1`) |
| coordinateur – récolte validée | un coordinateur (utilisateur) valide zéro, une ou plusieurs récoltes (`0,n`) | une récolte est validée par au plus un coordinateur (`0,1`) |
| apicultrice – compte de connexion | une apicultrice possède au plus un compte (`0,1`) | un compte appartient au plus à une apicultrice (`0,1`) |
| *apicultrice – site* | *une apicultrice est rattachée à un seul site (`1,1`)* | *un site accueille zéro, une ou plusieurs apicultrices (`0,n`)* |
| *ruche – inspection* | *une ruche subit zéro, une ou plusieurs inspections (`0,n`)* | *une inspection porte sur une seule ruche (`1,1`)* |
| *ruche – alerte* | *une ruche déclenche zéro, une ou plusieurs alertes (`0,n`)* | *une alerte concerne une seule ruche (`1,1`)* |
| *site – coopérative* | *un site héberge zéro, une ou plusieurs coopératives (`0,n`)* | *une coopérative est rattachée à un seul site (`1,1`)* |
| *site – utilisateur* | *un site peut être géré par zéro, un ou plusieurs utilisateurs (`0,n`)* | *un utilisateur (coordinateur) est rattaché à au plus un site (`0,1`)* |

---

## Question 4 : Qu’est-ce que le sujet ne dit pas ? (Hypothèses)

| Question au client | Notre hypothèse |
| :--- | :--- |
| Une ruche peut-elle changer de site ou d’apicultrice ? | Oui, mais on ne conserve que le site et l’apicultrice actuels (pas d’historique de déplacement). |
| Une récolte peut-elle être validée sans date ni coordinateur ? | Non, dès qu’une récolte passe au statut « validée », l’identifiant du coordinateur et la date de validation sont obligatoires. |
| Une apicultrice peut-elle posséder des ruches sur un site différent de celui auquel elle est rattachée ? | Non, ses ruches sont installées sur son site de rattachement. |
| Les quatre types d’utilisateurs ont-ils tous une fiche dans la table `apicultrice` ? | Non, seuls les comptes ayant le rôle « apicultrice » sont liés à une apicultrice (les coordinateurs, gestionnaires et administrateurs ont uniquement un compte utilisateur). |
| Une alerte peut-elle être acquittée ou fermée après traitement ? | Oui, on ajoute un attribut statut (`ouverte` / `fermée`) pour suivre son traitement. |

---

## Question 5 : Qu’est-ce qui intéresserait un fraudeur ?

Trois informations sensibles de Queen Bee et ce qu'un attaquant pourrait en faire :
1. **La position GPS des ruches :** Un voleur peut localiser précisément les ruches isolées sur le terrain pour aller les dérober ou voler le miel.
2. **Le numéro de téléphone des apicultrices :** Un fraudeur peut revendre ces données personnelles ou mener des campagnes d’hameçonnage (phishing par SMS/appel) pour usurper l'identité de la coopérative.
3. **Les identifiants de connexion (`login` / mot de passe) et les mesures des capteurs :** Un attaquant peut se connecter à la place d’un coordinateur pour valider de fausses récoltes, ou injecter de fausses mesures (poids, température) pour masquer un vol ou déclencher de fausses alertes.
