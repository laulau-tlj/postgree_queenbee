import threading
import time
import psycopg

""" dans ce fichier, on simule une attaque sur un jeton pour voir si la base de données est vulnérable à une condition de course """
""" Ce script prouve qu'un jeton à usage unique peut être utilisé deux fois si le code vérifie son état avant de le modifier. Il simule deux requêtes simultanées envoyées par un attaquant au même millième de seconde. """
CODE_JETON = "RT-f.sow-25" # Jeton à usage unique (valeur aléatoire)
barriere = threading.Barrier(2)

""" Fonction pour simuler une attaque sur un jeton """
def attaquer(nom):
    with psycopg.connect(dbname="queenbee", autocommit=True) as conn:
        with conn.cursor() as cur:
            barriere.wait() # Synchronise les 2 threads au départ
            
            # Lecture du jeton (les deux voient utilise_le IS NULL)
            cur.execute("SELECT id, utilisateur_id FROM jeton WHERE valeur = %s AND utilise_le IS NULL", (CODE_JETON,))
            ligne = cur.fetchone()
            
            time.sleep(0.05) # Simule la latence réseau pour augmenter les chances de collision
            
            if ligne:
                jeton_id, user_id = ligne
                # Écriture du jeton (les deux valident !)
                cur.execute("UPDATE jeton SET utilise_le = now() WHERE id = %s", (jeton_id,))
                cur.execute("INSERT INTO session_app (utilisateur_id, jeton_id) VALUES (%s, %s)", (user_id, jeton_id))
                print(f"[{nom}] SUCCÈS : Session ouverte !")
            else:
                print(f"[{nom}] REFUS : Jeton déjà pris.")

t1 = threading.Thread(target=attaquer, args=("Thread-1",))
t2 = threading.Thread(target=attaquer, args=("Thread-2",))
t1.start(); t2.start()
t1.join(); t2.join()
