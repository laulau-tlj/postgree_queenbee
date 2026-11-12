import psycopg

with psycopg.connect(dbname="queenbee") as conn:
    site = input("Site : ")
    tri = input("Trier par (code ou date_installation) : ")
    
    # FAILLE : le site est paramétré (%s), mais le tri est collé directement en texte !
    sql = f"SELECT id, date_installation, longitude FROM ruche WHERE site_id = %s ORDER BY {tri}"
    
    for row in conn.execute(sql, (site,)):
        print(row)
