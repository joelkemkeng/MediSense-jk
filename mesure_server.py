import serial
import time
import threading
import asyncio
import websockets
import logging
import signal
import sys
from typing import Optional

# Configuration du logging pour debug
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('medisense.log', mode='a')
    ]
)
logger = logging.getLogger(__name__)

# Déclaration des variables globales pour stocker les données
poids: Optional[float] = None
temperature: Optional[float] = None
validation: Optional[int] = None
refValidateCard: int = 310502


# Lock pour la synchronisation des threads
data_lock = threading.Lock()

# Variable pour contrôler l'arrêt propre du programme
shutdown_event = threading.Event()

# Liste des clients connectés
connected_clients = set()

def read_serial_data():
    """Fonction qui lit en continu les données du port série"""
    global poids, temperature, validation
    
    # Variables pour les connexions série
    ser_poids = None
    ser_temperature = None
    ser_validation = None
    
    try:
        logger.info("🔌 Tentative de connexion aux ports série...")
        
        # Tentative de connexion avec gestion d'erreur pour chaque port
        ports_connected = 0
        
        try:
            ser_poids = serial.Serial('/dev/ttyUSB0', 57600, timeout=1)
            logger.info("✅ Connexion réussie au port poids (/dev/ttyUSB0)")
            ports_connected += 1
        except serial.SerialException as e:
            logger.warning(f"⚠️ Port poids non disponible (/dev/ttyUSB0): {e}")
            
        try:
            ser_temperature = serial.Serial('/dev/ttyUSB1', 9600, timeout=1)
            logger.info("✅ Connexion réussie au port température (/dev/ttyUSB1)")
            ports_connected += 1
        except serial.SerialException as e:
            logger.warning(f"⚠️ Port température non disponible (/dev/ttyUSB1): {e}")
            
        try:
            ser_validation = serial.Serial('/dev/ttyACM0', 9600, timeout=1)
            logger.info("✅ Connexion réussie au port validation (/dev/ttyACM0)")
            ports_connected += 1
        except serial.SerialException as e:
            logger.warning(f"⚠️ Port validation non disponible (/dev/ttyACM0): {e}")
        
        # Mode simulation si aucun port n'est disponible
        simulate_data = (ports_connected == 0)
        
        if simulate_data:
            logger.warning("⚠️ Aucun port série disponible! Démarrage en mode SIMULATION...")
        else:
            logger.info(f"✅ {ports_connected} port(s) série connecté(s)")
            
        time.sleep(2)  # Pause pour permettre aux ports de s'initialiser
        logger.info("🚀 Début de la lecture des données...")

        # Compteur pour la simulation
        counter = 0
        last_validation_time = 0

        # Boucle infinie pour lire les données en continu
        while not shutdown_event.is_set():
            try:
                current_time = time.time()
                
                # Mode simulation si aucun port n'est disponible
                if simulate_data:
                    counter += 1
                    with data_lock:
                        # Simulation de données réalistes
                        poids = round(70.5 + (counter % 20) * 0.1, 1)  # 70.5 à 72.4 kg
                        temperature = round(36.5 + (counter % 8) * 0.05, 1)  # 36.5 à 36.85°C
                        
                        # Validation toutes les 30 secondes environ
                        if current_time - last_validation_time > 30:
                            validation = refValidateCard
                            last_validation_time = current_time
                            logger.info(f"✅ [SIMULATION] Validation générée: {validation}")
                    
                    if counter % 10 == 0:  # Log toutes les 10 itérations
                        logger.info(f"📊 [SIMULATION] Poids: {poids}kg, Température: {temperature}°C")
                    
                    time.sleep(2)  # 2 secondes en mode simulation
                    continue

                # Lecture réelle des ports série
                data_received = False
                
                # Lecture du poids
                if ser_poids and ser_poids.is_open:
                    try:
                        if ser_poids.in_waiting > 0:
                            data = ser_poids.readline().decode('utf-8', errors='ignore').strip()
                            if data and data.replace('.', '').replace('-', '').isdigit():
                                new_poids = float(data)
                                if 0 <= new_poids <= 500:  # Validation de plausibilité
                                    with data_lock:
                                        poids = round(new_poids, 1)
                                    logger.info(f"⚖️ Poids reçu: {poids} Kg")
                                    data_received = True
                    except Exception as e:
                        logger.error(f"❌ Erreur lecture poids: {e}")

                # Lecture de la température
                if ser_temperature and ser_temperature.is_open:
                    try:
                        if ser_temperature.in_waiting > 0:
                            data1 = ser_temperature.readline().decode('utf-8', errors='ignore').strip()
                            if data1 and data1.replace('.', '').replace('-', '').isdigit():
                                new_temperature = float(data1)
                                if 0 <= new_temperature <= 50:  # Validation de plausibilité
                                    with data_lock:
                                        temperature = round(new_temperature, 1)
                                    logger.info(f"🌡️ Température reçue: {temperature}°C")
                                    data_received = True
                    except Exception as e:
                        logger.error(f"❌ Erreur lecture température: {e}")

                # Lecture de la validation
                if ser_validation and ser_validation.is_open:
                    try:
                        if ser_validation.in_waiting > 0:
                            data3 = ser_validation.readline().decode('utf-8', errors='ignore').strip()
                            #if data3.isdigit():
                            new_validation = int(data3)
                            if new_validation == refValidateCard:
                                with data_lock:
                                    validation = new_validation
                                logger.info(f"✅ Validation reçue: {validation}")
                                data_received = True
                            else:
                                logger.warning(f"⚠️ Code de validation incorrect: {new_validation}")
                    except Exception as e:
                        logger.error(f"❌ Erreur lecture validation: {e}")
                
                # Pause adaptative
                time.sleep(0.05 if data_received else 0.2)
                        
            except Exception as e:
                logger.error(f"❌ Erreur lors de la lecture série: {e}")
                time.sleep(1)
                
    except Exception as e:
        logger.error(f"❌ Erreur critique dans read_serial_data: {e}")
    finally:
        # Fermeture propre des connexions série
        for ser_name, ser in [("poids", ser_poids), ("température", ser_temperature), ("validation", ser_validation)]:
            if ser and hasattr(ser, 'is_open') and ser.is_open:
                try:
                    ser.close()
                    logger.info(f"🔌 Port {ser_name} fermé")
                except Exception as e:
                    logger.error(f"❌ Erreur fermeture port {ser_name}: {e}")
        logger.info("🔌 Toutes les connexions série fermées")

# ✅ CORRECTION PRINCIPALE: Signature de fonction corrigée
async def socket_server(websocket):
    """Fonction pour gérer les connexions WebSocket - SIGNATURE CORRIGÉE"""
    global poids, temperature, validation
    
    client_address = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
    logger.info(f"🌐 Nouvelle connexion WebSocket de {client_address}")
    
    # Ajouter le client à la liste
    connected_clients.add(websocket)
    
    try:
        # Message de bienvenue
        await websocket.send("Connection au serveur effectuée")
        logger.info(f"✅ Message de bienvenue envoyé à {client_address}")

        # Boucle pour écouter les messages du client
        async for message in websocket:
            logger.info(f"📨 Message de {client_address}: {message}")
            
            try:
                response = ""
                
                # Gestion des commandes
                if message == "get-poid":
                    with data_lock:
                        if poids is not None and poids > 0:
                            response = f"Poids:{poids}"
                        else:
                            response = "Poids:0"

                elif message == "get-temperature":
                    with data_lock:
                        if temperature is not None and temperature > 0:
                            response = f"Température:{temperature}"
                        else:
                            response = "Température:0"

                elif message == "get-validation":
                    with data_lock:
                        if validation is not None and validation == refValidateCard:
                            response = f"Validation:{validation}"
                            validation = None  # Réinitialiser après envoi
                        else:
                            response = "Validation:0"

                elif message == "reset-data":
                    with data_lock:
                        poids = None
                        temperature = None
                        validation = None
                    response = "Reset:OK"

                elif message == "all-mesure":
                    # Création d'une chaîne avec toutes les mesures
                    mesures = []
                    
                    with data_lock:
                        # Poids
                        if poids is not None and poids > 0:
                            mesures.append(f"poids:{poids}")
                        else:
                            mesures.append("poids:0")
                        
                        # Température
                        if temperature is not None and temperature > 0:
                            mesures.append(f"temperature:{temperature}")
                        else:
                            mesures.append("temperature:0")
                        
                        # Validation
                        if validation is not None and validation == refValidateCard:
                            mesures.append(f"validation:{validation}")
                            validation = None  # Réinitialiser après envoi
                        else:
                            mesures.append("validation:0")
                    
                    response = "All-Mesure:" + ":".join(mesures)

                elif message == "ping":
                    response = "pong"
                
                elif message == "status":
                    # Commande de statut du serveur
                    with data_lock:
                        response = f"Status:clients={len(connected_clients)},poids={poids},temp={temperature},valid={validation}"
                
                else:
                    response = f"Commande inconnue: {message}"
                    logger.warning(f"⚠️ Commande inconnue de {client_address}: {message}")
                
                # Envoyer la réponse
                await websocket.send(response)
                logger.info(f"📤 Envoyé à {client_address}: {response}")
                    
            except websockets.exceptions.ConnectionClosed:
                logger.info(f"🔌 Connexion fermée par {client_address}")
                break
            except Exception as e:
                logger.error(f"❌ Erreur traitement message de {client_address}: {e}")
                try:
                    await websocket.send(f"Erreur serveur: {str(e)}")
                except:
                    pass  # Connexion peut être fermée
                
    except websockets.exceptions.ConnectionClosed:
        logger.info(f"🔌 Client {client_address} déconnecté")
    except Exception as e:
        logger.error(f"❌ Erreur dans socket_server pour {client_address}: {e}")
    finally:
        # Retirer le client de la liste
        connected_clients.discard(websocket)
        logger.info(f"🔚 Fin de session avec {client_address} (Clients restants: {len(connected_clients)})")

# ✅ CORRECTION: Fonction de démarrage du serveur WebSocket simplifiée
async def start_websocket_server():
    """Démarrage du serveur WebSocket"""
    logger.info("🚀 Démarrage du serveur WebSocket sur 127.0.0.1:8765")
    try:
        # Créer le serveur - SIGNATURE CORRIGÉE sans 'path'
        async with websockets.serve(
            socket_server,  # Fonction handler sans paramètre 'path'
            "127.0.0.1", 
            8765,
            ping_interval=30,  # Ping toutes les 30 secondes
            ping_timeout=10,   # Timeout ping 10 secondes
            close_timeout=10   # Timeout fermeture 10 secondes
        ):
            logger.info("✅ Serveur WebSocket démarré avec succès")
            logger.info(f"📡 En écoute sur ws://127.0.0.1:8765")
            
            # Attendre indéfiniment
            await asyncio.Future()  # Run forever
        
    except Exception as e:
        logger.error(f"❌ Erreur serveur WebSocket: {e}")
        raise

def run_websocket_server():
    """Fonction pour exécuter le serveur WebSocket dans un thread"""
    try:
        # Créer une nouvelle boucle d'événements pour ce thread
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        # Exécuter le serveur WebSocket
        loop.run_until_complete(start_websocket_server())
        
    except Exception as e:
        logger.error(f"❌ Erreur dans run_websocket_server: {e}")
    finally:
        try:
            loop.close()
        except:
            pass

def signal_handler(signum, frame):
    """Gestionnaire de signal pour arrêt propre"""
    logger.info(f"🛑 Signal {signum} reçu, arrêt du programme...")
    shutdown_event.set()
    
    # Fermer toutes les connexions WebSocket
    for client in connected_clients.copy():
        try:
            asyncio.create_task(client.close())
        except:
            pass
    
    sys.exit(0)

def main():
    """Point d'entrée principal"""
    logger.info("=" * 60)
    logger.info("🏥 ===== DÉMARRAGE DE MEDISENSE PRO v2.0 =====")
    logger.info("=" * 60)
    
    # Enregistrer les gestionnaires de signaux
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Lancement du thread de lecture série
        logger.info("🔧 Lancement du thread de lecture série...")
        serial_thread = threading.Thread(
            target=read_serial_data, 
            daemon=True, 
            name="SerialReader"
        )
        serial_thread.start()
        logger.info("✅ Thread série démarré")

        # Lancement du thread serveur WebSocket
        logger.info("🌐 Lancement du thread WebSocket...")
        socket_thread = threading.Thread(
            target=run_websocket_server, 
            daemon=True, 
            name="WebSocketServer"
        )
        socket_thread.start()
        logger.info("✅ Thread WebSocket démarré")

        logger.info("🎯 Tous les services sont actifs!")
        logger.info("📊 Rafraîchissement automatique toutes les 2 secondes côté client")
        logger.info("🌐 WebSocket accessible sur ws://127.0.0.1:8765")
        logger.info("⏹️  Appuyez sur Ctrl+C pour arrêter")
        logger.info("-" * 60)
        
        # Maintenir le programme principal en vie avec monitoring
        heartbeat_counter = 0
        while not shutdown_event.is_set():
            time.sleep(10)  # Heartbeat toutes les 10 secondes
            heartbeat_counter += 1
            
            # Vérifier l'état des threads
            if not serial_thread.is_alive():
                logger.warning("⚠️ Thread série arrêté, redémarrage...")
                serial_thread = threading.Thread(
                    target=read_serial_data, 
                    daemon=True, 
                    name="SerialReader"
                )
                serial_thread.start()
                
            if not socket_thread.is_alive():
                logger.warning("⚠️ Thread WebSocket arrêté, redémarrage...")
                socket_thread = threading.Thread(
                    target=run_websocket_server, 
                    daemon=True, 
                    name="WebSocketServer"
                )
                socket_thread.start()
            
            # Log de status toutes les minutes (6 * 10 secondes)
            if heartbeat_counter % 6 == 0:
                with data_lock:
                    logger.info(
                        f"💓 Status: Clients={len(connected_clients)}, "
                        f"Poids={poids}, Temp={temperature}, Valid={validation}"
                    )
            
    except KeyboardInterrupt:
        logger.info("⏹️ Arrêt demandé par l'utilisateur (Ctrl+C)")
    except Exception as e:
        logger.error(f"❌ Erreur critique dans main: {e}")
    finally:
        logger.info("🛑 Arrêt en cours...")
        shutdown_event.set()
        time.sleep(2)  # Laisser le temps aux threads de se terminer
        logger.info("✅ Programme terminé proprement")
        logger.info("=" * 60)

if __name__ == "__main__":
    main()