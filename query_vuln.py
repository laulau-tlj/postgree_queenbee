# query_vuln.py : version VOLONTAIREMENT VULNÉRABLE (Lab 3)
# La saisie est collée dans le texte de la requête : l'utilisateur peut écrire du SQL.
# Connexion : psycopg lit PGUSER, PGHOST et le mot de passe dans les variables du terminal.
import psycopg

conn = psycopg.connect(dbname="queenbee")
code = input("Code ruche : ")
sql = "SELECT nom, site_id FROM ruche WHERE nom = '" + code + "'"
print("Requête envoyée :", sql)
rows = conn.execute(sql).fetchall()
print(len(rows), "ligne(s)")
for row in rows:
    print(row)
