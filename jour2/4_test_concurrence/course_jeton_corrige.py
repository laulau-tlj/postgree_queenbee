import threading
import psycopg

CODE_JETON = "RT-f.sow-11"
barriere = threading.Barrier(2)

""" Fonction pour sécuriser l'utilisation d'un jeton à usage unique """
""" Ce script montre comment empêcher cette faille côté code applicatif. Il fusionne la vérification et la modification en une seule requête indivisible pour que le moteur PostgreSQL gère lui-même la file d'attente. """
def securiser(nom):
    with psycopg.connect(dbname="queenbee", autocommit=True) as conn:
        with conn.cursor() as cur:
            barriere.wait()
            
            # Requête atomique : vérifie et consomme le jeton en une seule opération
            cur.execute("""
                UPDATE jeton 
                SET utilise_le = now() 
                WHERE valeur = %s AND utilise_le IS NULL 
                RETURNING id, utilisateur_id
            """, (CODE_JETON,))
            ligne = cur.fetchone()
            
            if ligne:
                jeton_id, user_id = ligne
                cur.execute(
                    "INSERT INTO session_app (utilisateur_id, jeton_id) VALUES (%s, %s)",
                    (user_id, jeton_id)
                )
                print(f"[{nom}] SUCCÈS : Session unique ouverte !")
            else:
                print(f"[{nom}] REFUS : Jeton déjà consommé.")

t1 = threading.Thread(target=securiser, args=("Thread-1",))
t2 = threading.Thread(target=securiser, args=("Thread-2",))

t1.start()
t2.start()
t1.join()
t2.join()
