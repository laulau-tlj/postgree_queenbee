# Lab 9 · Durabilité et Sauvegarde

## 1. Paramètres PostgreSQL vérifiés
- **`fsync = on`** : Force l'écriture physique sur le disque dur avant de valider une transaction.
- **`synchronous_commit = on`** : Attend que le journal WAL soit écrit sur le disque avant de confirmer le `COMMIT` au client.
- **`wal_level = replica`** : Enregistre assez de détails dans les journaux WAL pour restaurer la base à n'importe quel instant ou la répliquer.

## 2. Sauvegarde et vérification (`queenbee_j2.dump`)
- **Empreinte SHA-256** : `6dfbd7be74a227a0bd6565132cadb4f2ac7e6d6c27472f20caea0e0cf22f196f  queenbee_j2.dump`
- **Test de restauration** : Restauration réussie dans la base `queenbee_restore`. Le journal d'audit (`journal_audit`) et les règles de sécurité sont bien présents.

## 3. Questions de sécurité
1. **Pourquoi restaurer dans une base test ?** Une sauvegarde non testée peut être corrompue ou vide. La restauration prouve qu'elle est exploitable en cas d'incident.
2. **À quoi sert le fichier `.sha256` ?** À garantir l'intégrité du fichier : si quelqu'un modifie une ligne dans le `.dump`, l'empreinte change.
3. **Protection contre les rançongiciels** : Il faut appliquer la règle **3-2-1** et stocker une copie hors ligne ou immuable (WORM) inaccessible au compte `postgres`.
4. **RPO et RTO** : Avec une sauvegarde par jour (`pg_dump`), on peut perdre jusqu'à 24 h de données (**RPO**). L'archivage continu des journaux **WAL** permet de réduire cette perte à quelques secondes.
