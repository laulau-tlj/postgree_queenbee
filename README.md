# Queen Bee

## Présentation

Queen Bee est un projet de modélisation de données pour le suivi d'un rucher. Il vise à structurer les informations sur les sites, les ruches, les apicultrices, les coopératives et les activités de suivi des colonies.

## Travail réalisé

Ce travail de conception recense les entités métier, leurs attributs et leurs identifiants, puis définit les relations et cardinalités entre elles. Le modèle couvre notamment :

- les sites et les ruches qui y sont installées ;
- les apicultrices, leurs ruches et leurs coopératives ;
- les mesures de capteurs, inspections, récoltes et alertes associés aux ruches ;
- les comptes utilisateurs et la validation des récoltes par les coordinateurs.

Les hypothèses métier précisent entre autres que les ruches et apicultrices sont rattachées à un site, qu'une récolte validée doit être associée à un coordinateur et à une date de validation, et que les alertes peuvent être ouvertes ou fermées.

## Données sensibles

La conception identifie comme sensibles la localisation GPS des ruches, les numéros de téléphone des apicultrices, les identifiants de connexion et les mesures des capteurs. Ces données doivent être protégées contre les accès non autorisés et les modifications frauduleuses.

## Contenu

- [`annotations.md`](./annotations.md) : notes détaillées sur les entités, attributs, relations, hypothèses et risques liés aux données.
