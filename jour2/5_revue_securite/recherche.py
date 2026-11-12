import sys
import psycopg
from psycopg import sql

""" ici, on corrige la faille de sécurité de recherche_vuln.py """
TRI_AUTORISES = {"id", "date_installation"}

site = input("Site : ")
tri = input("Trier par (id ou date_installation) : ")

# 1. Liste blanche : bloque immédiatement toute tentative d'injection
if tri not in TRI_AUTORISES:
    print("Tri refusé : choisissez id ou date_installation.")
    sys.exit(1)

try:
    with psycopg.connect(dbname="queenbee") as conn:
        # 2. sql.Identifier protège le nom de colonne, %s protège la valeur du site
        requete = sql.SQL(
            "SELECT id, date_installation, longitude FROM ruche WHERE site_id = %s ORDER BY {}"
        ).format(sql.Identifier(tri))
        
        for row in conn.execute(requete, (site,)):
            print(row)
except psycopg.Error:
    # 3. Masque les détails techniques de PostgreSQL en cas d'incident
    print("Erreur technique lors de la recherche.")
