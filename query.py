# query.py : version CORRIGÉE, requête paramétrée (Lab 3)
#
# | Saisie                                             | query_vuln.py                  | query.py |
# | code normal (SN-CASA-014)                          | 1 ligne                        | 1 ligne  |
# | ' OR '1'='1                                        | 11 lignes (toutes les ruches)  | 0 ligne  |
# | ' UNION SELECT nom, telephone FROM apicultrice --  | 8 lignes (noms et téléphones)  | 0 ligne  |
#
# Pourquoi query.py résiste : la requête et la valeur sont envoyées séparément (%s).
# Ce que tape l'utilisateur n'est jamais lu comme du SQL : c'est juste une valeur, cherchée
# telle quelle comme nom de ruche. Comme aucune ruche ne s'appelle « ' OR '1'='1 », 0 ligne.
import psycopg

conn = psycopg.connect(dbname="queenbee")
code = input("Code ruche : ")
rows = conn.execute(
    "SELECT nom, site_id FROM ruche WHERE nom = %s", (code,)
).fetchall()
print(len(rows), "ligne(s)")
for row in rows:
    print(row)
