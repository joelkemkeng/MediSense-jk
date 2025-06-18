import serial
import time
import threading
import asyncio
import websockets

# Déclaration des variables globales pour stocker les données
# qui seront récupérées depuis l'Arduino
poids = None
temperature = None
validation = None

# Fonction qui lit en continu les données du port série
def read_serial_data():
    # Déclare les variables globales pour pouvoir les modifier
    global poids, temperature, validation
    
    # Connexion aux différents ports série pour chaque capteur
    try:
        ser_poids = serial.Serial('/dev/ttyUSB0', 57600)  # Port pour le poids
        ser_temperature = serial.Serial('/dev/ttyUSB1', 9600)  # Port pour la température
        ser_validation = serial.Serial('/dev/ttyACM0', 9600)  # Port pour la validation
        time.sleep(2)  # Pause pour permettre aux ports de s'initialiser

        # Boucle infinie pour lire les données en continu
        while True:
            # Vérifie si des données sont disponibles pour le poids
            if ser_poids.in_waiting > 0:
                data = ser_poids.readline().decode('utf-8').strip()  # Lit une ligne et la décode
                try:
                    poids = float(data)  # Convertit la donnée en float
                    print(f'Votre poids est de {poids} Kg')  # Affiche le poids
                except ValueError:
                    print(f'Erreur de conversion des donnees pour poids : {data}')  # Affiche une erreur si la conversion échoue

            # Vérifie si des données sont disponibles pour la température
            if ser_temperature.in_waiting > 0:
                data1 = ser_temperature.readline().decode('utf-8').strip()  # Lit une ligne et la décode
                try:
                    temperature = float(data1)  # Convertit la donnée en float
                    print(f'Votre température est de {temperature}')  # Affiche la température
                except ValueError:
                    print(f'Erreur de conversion des donnees pour temperature : {data1}')  # Affiche une erreur si la conversion échoue

         
            # Vérifie si des données sont disponibles pour la validation
            if ser_validation.in_waiting > 0:
                data3 = ser_validation.readline().decode('utf-8').strip()  # Lit une ligne et la décode
                try:
                    validation = int(data3)  # Convertit la donnée en int
                    if validation == 31052002:  # Vérifie si la validation est correcte
                        print(f'Validation reçue : {validation}')  # Affiche la validation
                    else:
                        validation = None
               
                except ValueError:
                    print(f'Erreur de conversion des donnees pour validation : {data3}')  # Affiche une erreur si la conversion échoue
                    
    except serial.SerialException as e:
        print(f'Erreur de connexion au port serie: {e}')  # Affiche une erreur si le port série ne peut pas être ouvert

# Fonction pour gérer les connexions WebSocket et répondre aux demandes
async def socket_server(websocket, path):
    
    
    # Déclare les variables globales pour pouvoir les modifier
    global poids, temperature, validation
    
    # Envoie un message de bienvenue lorsque le client se connecte
    await websocket.send("Connection au serveur effectuée")

    # Boucle infinie pour écouter les messages du client
    while True:
        try:
            # Attente d'un message du client
            message = await websocket.recv()
            
            print(f"Message reçu: {message}")
            
            if message == "get-poid":
                if poids is not None and poids != 0:  # Vérifie si poids existe et n'est pas 0
                    await websocket.send(f"Poids:{poids}")  # Envoie la valeur du poids
                    poids = None  # Réinitialisation après envoi
                else:
                    await websocket.send("Poids:0")

            elif message == "get-temperature":
                if temperature is not None and temperature != 0:  # Vérifie si température existe et n'est pas 0
                    await websocket.send(f"Température:{temperature}")
                    temperature = None
                else:
                    await websocket.send("Température:0")


            elif message == "get-validation":
                if validation is not None and validation != 0:  # Vérifie si validation existe et n'est pas 0
                    await websocket.send(f"Validation:{validation}")
                    validation = None
                else:
                    await websocket.send("Validation:0")

            elif message == "all-mesure":
                # Création d'une chaîne avec toutes les mesures
                mesures = []
                
                if poids is not None and poids != 0:
                    mesures.append(f"poids:{poids}")
                    poids = None
                else:
                    mesures.append("poids:0")
                
                if temperature is not None and temperature != 0:
                    mesures.append(f"temperature:{temperature}")
                    temperature = None
                else:
                    mesures.append("temperature:0")
                
                if validation is not None and validation != 0:
                    mesures.append(f"validation:{validation}")
                    validation = None
                else:
                    mesures.append("validation:0")
                
                # Envoi de toutes les mesures dans une seule chaîne
                await websocket.send("All-Mesure:" + ":".join(mesures))

        except websockets.exceptions.ConnectionClosed:
            print("Client déconnecté")  # Affiche un message lorsque le client se déconnecte
            break  # Sort de la boucle si la connexion est fermée

# Démarrage du serveur WebSocket
def start_socket_server():
    # Définit un nouvel événement pour la boucle asynchrone
    asyncio.set_event_loop(asyncio.new_event_loop())
    # Démarre le serveur WebSocket sur localhost au port 8765
    server = websockets.serve(socket_server, "127.0.0.1", 8765)
    asyncio.get_event_loop().run_until_complete(server)  # Attend que le serveur soit prêt
    asyncio.get_event_loop().run_forever()  # Démarre la boucle asynchrone pour le serveur

# Exécution des threads pour la lecture série et le serveur WebSocket
if __name__ == "__main__":
    # Lancement de la lecture série dans un thread séparé
    serial_thread = threading.Thread(target=read_serial_data)
    serial_thread.start()

    # Lancement du serveur WebSocket dans un thread séparé
    socket_thread = threading.Thread(target=start_socket_server)
    socket_thread.start()
