import serial
import time
import threading
import asyncio
import websockets
import logging
import signal
import sys
import os
import glob
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

def detect_sensor_ports():
    """
    Détecte automatiquement les ports des capteurs en testant les baudrates
    Retourne un dictionnaire avec les ports détectés
    """
    logger.info("🔍 Détection automatique des ports des capteurs...")
    
    # Récupérer tous les ports USB disponibles
    usb_ports = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*')
    usb_ports.sort()  # Trier pour avoir un ordre cohérent
    
    logger.info(f"📡 Ports USB détectés: {usb_ports}")
    
    detected_ports = {
        'temperature': None,
        'poids': None,
        'validation': None
    }
    
    for port in usb_ports:
        logger.info(f"🔧 Test du port {port}...")
        
        # Test pour capteur de température (9600 baud)
        if detected_ports['temperature'] is None:
            try:
                ser = serial.Serial(port, 9600, timeout=2)
                time.sleep(1)
                
                # Lire quelques échantillons pour identifier le capteur
                for _ in range(5):
                    if ser.in_waiting > 0:
                        data = ser.readline().decode('utf-8', errors='ignore').strip()
                        if data:
                            try:
                                value = float(data)
                                # Test si c'est une température (range typique 35-42°C)
                                if 35.0 <= value <= 42.0:
                                    detected_ports['temperature'] = port
                                    logger.info(f"🌡️ Capteur température détecté sur {port} (valeur test: {value}°C)")
                                    ser.close()
                                    break
                            except ValueError:
                                pass
                    time.sleep(0.2)
                else:
                    ser.close()
            except Exception as e:
                logger.debug(f"❌ Erreur test température sur {port}: {e}")
        
        # Test pour capteur de poids (57600 baud)
        if detected_ports['poids'] is None:
            try:
                ser = serial.Serial(port, 57600, timeout=2)
                time.sleep(1)
                
                # Lire quelques échantillons pour identifier le capteur
                for _ in range(5):
                    if ser.in_waiting > 0:
                        data = ser.readline().decode('utf-8', errors='ignore').strip()
                        if data:
                            try:
                                value = float(data)
                                # Test si c'est un poids (range typique 1-200kg)
                                if 1.0 <= value <= 200.0:
                                    detected_ports['poids'] = port
                                    logger.info(f"⚖️ Capteur poids détecté sur {port} (valeur test: {value}kg)")
                                    ser.close()
                                    break
                            except ValueError:
                                pass
                    time.sleep(0.2)
                else:
                    ser.close()
            except Exception as e:
                logger.debug(f"❌ Erreur test poids sur {port}: {e}")
        
        # Test pour capteur de validation (9600 baud, codes numériques)
        if detected_ports['validation'] is None:
            try:
                ser = serial.Serial(port, 9600, timeout=2)
                time.sleep(1)
                
                # Lire quelques échantillons pour identifier le capteur
                for _ in range(5):
                    if ser.in_waiting > 0:
                        data = ser.readline().decode('utf-8', errors='ignore').strip()
                        if data:
                            try:
                                value = int(data)
                                # Test si c'est un code de validation (6 chiffres commençant par 31)
                                if 300000 <= value <= 999999:
                                    detected_ports['validation'] = port
                                    logger.info(f"🔐 Capteur validation détecté sur {port} (valeur test: {value})")
                                    ser.close()
                                    break
                            except ValueError:
                                pass
                    time.sleep(0.2)
                else:
                    ser.close()
            except Exception as e:
                logger.debug(f"❌ Erreur test validation sur {port}: {e}")
    
    # Afficher le résumé de détection
    logger.info("📊 Résumé de la détection automatique:")
    for sensor, port in detected_ports.items():
        if port:
            logger.info(f"   ✅ {sensor.capitalize()}: {port}")
        else:
            logger.warning(f"   ❌ {sensor.capitalize()}: Non détecté")
    
    return detected_ports

def create_udev_rules(detected_ports):
    """
    Créer des règles udev pour fixer les ports (optionnel)
    """
    try:
        udev_rules = []
        
        for sensor, port in detected_ports.items():
            if port:
                # Obtenir les informations du périphérique
                try:
                    import subprocess
                    result = subprocess.run(['udevadm', 'info', '-a', '-n', port], 
                                          capture_output=True, text=True)
                    
                    # Extraire le numéro de série ou ID unique si disponible
                    lines = result.stdout.split('\n')
                    serial_num = None
                    vendor_id = None
                    product_id = None
                    
                    for line in lines:
                        if 'ATTRS{serial}' in line and serial_num is None:
                            serial_num = line.split('"')[1]
                        elif 'ATTRS{idVendor}' in line and vendor_id is None:
                            vendor_id = line.split('"')[1]
                        elif 'ATTRS{idProduct}' in line and product_id is None:
                            product_id = line.split('"')[1]
                    
                    if vendor_id and product_id:
                        rule = f'SUBSYSTEM=="tty", ATTRS{{idVendor}}=="{vendor_id}", ATTRS{{idProduct}}=="{product_id}"'
                        if serial_num:
                            rule += f', ATTRS{{serial}}=="{serial_num}"'
                        rule += f', SYMLINK+="medisense_{sensor}"'
                        udev_rules.append(rule)
                        
                        logger.info(f"📝 Règle udev pour {sensor}: {rule}")
                
                except Exception as e:
                    logger.debug(f"❌ Impossible de créer la règle udev pour {sensor}: {e}")
        
        if udev_rules:
            rules_content = '\n'.join(udev_rules) + '\n'
            logger.info("💡 Pour fixer définitivement les ports, créez le fichier:")
            logger.info("   sudo nano /etc/udev/rules.d/99-medisense.rules")
            logger.info("💡 Avec le contenu suivant:")
            logger.info(f"   {rules_content}")
            logger.info("💡 Puis redémarrez avec: sudo reboot")
            
    except Exception as e:
        logger.error(f"❌ Erreur création règles udev: {e}")

def read_serial_data():
    """Fonction qui lit en continu les données du port série avec détection automatique"""
    global poids, temperature, validation
    
    # Variables pour les connexions série
    ser_poids = None
    ser_temperature = None
    ser_validation = None
    
    try:
        # Détection automatique des ports
        detected_ports = detect_sensor_ports()
        
        # Si aucun port détecté automatiquement, essayer la configuration par défaut
        if not any(detected_ports.values()):
            logger.warning("⚠️ Aucun capteur détecté automatiquement, essai configuration manuelle...")
            detected_ports = {
                'temperature': '/dev/ttyUSB2',
                'poids': '/dev/ttyUSB1', 
                'validation': '/dev/ttyACM0'
            }
        
        # Créer les règles udev (informatif)
        create_udev_rules(detected_ports)
        
        ports_connected = 0
        
        # Connexion au capteur de température
        if detected_ports['temperature']:
            try:
                ser_temperature = serial.Serial(detected_ports['temperature'], 9600, timeout=1)
                logger.info(f"✅ Température connectée sur {detected_ports['temperature']}")
                ports_connected += 1
            except serial.SerialException as e:
                logger.warning(f"⚠️ Erreur connexion température sur {detected_ports['temperature']}: {e}")
        
        # Connexion au capteur de poids
        if detected_ports['poids']:
            try:
                ser_poids = serial.Serial(detected_ports['poids'], 57600, timeout=1)
                logger.info(f"✅ Poids connecté sur {detected_ports['poids']}")
                ports_connected += 1
            except serial.SerialException as e:
                logger.warning(f"⚠️ Erreur connexion poids sur {detected_ports['poids']}: {e}")
        
        # Connexion au capteur de validation
        if detected_ports['validation']:
            try:
                ser_validation = serial.Serial(detected_ports['validation'], 9600, timeout=1)
                logger.info(f"✅ Validation connectée sur {detected_ports['validation']}")
                ports_connected += 1
            except serial.SerialException as e:
                logger.warning(f"⚠️ Erreur connexion validation sur {detected_ports['validation']}: {e}")
        
        # Mode simulation si aucun port n'est disponible
        simulate_data = (ports_connected == 0)
        
        if simulate_data:
            logger.warning("⚠️ Aucun capteur connecté! Démarrage en mode SIMULATION...")
        else:
            logger.info(f"✅ {ports_connected} capteur(s) connecté(s)")
            
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
                        poids = round(70.5 + (counter % 20) * 0.1, 1)
                        temperature = round(36.5 + (counter % 8) * 0.05, 1)
                        
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
                
                # Lecture de la température
                if ser_temperature and ser_temperature.is_open:
                    try:
                        if ser_temperature.in_waiting > 0:
                            data1 = ser_temperature.readline().decode('utf-8', errors='ignore').strip()
                            if data1:
                                new_temperature = float(data1)
                                if new_temperature > 35.6:  # Seuil de validation
                                    with data_lock:
                                        temperature = round(new_temperature, 2)
                                    logger.info(f"🌡️ Température reçue: {temperature}°C")
                                    data_received = True
                                else:
                                    logger.debug(f"🌡️ Température trop basse: {new_temperature}°C")
                    except ValueError as e:
                        logger.error(f"❌ Erreur conversion température: {e}")
                    except Exception as e:
                        logger.error(f"❌ Erreur lecture température: {e}")

                # Lecture du poids
                if ser_poids and ser_poids.is_open:
                    try:
                        if ser_poids.in_waiting > 0:
                            data = ser_poids.readline().decode('utf-8', errors='ignore').strip()
                            if data:
                                new_poids = float(data)
                                if new_poids > 2:  # Seuil de validation
                                    with data_lock:
                                        poids = round(new_poids, 1)
                                    logger.info(f"⚖️ Poids reçu: {poids} Kg")
                                    data_received = True
                                else:
                                    logger.debug(f"⚖️ Poids trop bas: {new_poids}kg")
                    except ValueError as e:
                        logger.error(f"❌ Erreur conversion poids: {e}")
                    except Exception as e:
                        logger.error(f"❌ Erreur lecture poids: {e}")

                # Lecture de la validation
                if ser_validation and ser_validation.is_open:
                    try:
                        if ser_validation.in_waiting > 0:
                            data3 = ser_validation.readline().decode('utf-8', errors='ignore').strip()
                            if data3:
                                new_validation = int(data3)
                                if new_validation == refValidateCard:
                                    with data_lock:
                                        validation = new_validation
                                    logger.info(f"✅ Validation reçue: {validation}")
                                    data_received = True
                                else:
                                    logger.debug(f"🔐 Code incorrect: {new_validation}")
                    except ValueError as e:
                        logger.error(f"❌ Erreur conversion validation: {e}")
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

# [Le reste du code WebSocket reste identique...]

# Fonction pour gérer les connexions WebSocket
async def socket_server(websocket):
    """Fonction pour gérer les connexions WebSocket"""
    global poids, temperature, validation
    
    client_address = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
    logger.info(f"🌐 Nouvelle connexion WebSocket de {client_address}")
    
    connected_clients.add(websocket)
    
    try:
        await websocket.send("Connection au serveur effectuée")
        logger.info(f"✅ Message de bienvenue envoyé à {client_address}")

        async for message in websocket:
            logger.info(f"📨 Message de {client_address}: {message}")
            
            try:
                response = ""
                
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
                            validation = None
                        else:
                            response = "Validation:0"

                elif message == "reset-data":
                    with data_lock:
                        poids = None
                        temperature = None
                        validation = None
                    response = "Reset:OK"
                    logger.info(f"🔄 Données réinitialisées par {client_address}")

                elif message == "all-mesure":
                    mesures = []
                    
                    with data_lock:
                        if poids is not None and poids > 0:
                            mesures.append(f"poids:{poids}")
                        else:
                            mesures.append("poids:0")
                        
                        if temperature is not None and temperature > 0:
                            mesures.append(f"temperature:{temperature}")
                        else:
                            mesures.append("temperature:0")
                        
                        if validation is not None and validation == refValidateCard:
                            mesures.append(f"validation:{validation}")
                            validation = None
                        else:
                            mesures.append("validation:0")
                    
                    response = "All-Mesure:" + ":".join(mesures)

                elif message == "ping":
                    response = "pong"
                
                elif message == "status":
                    with data_lock:
                        response = f"Status:clients={len(connected_clients)},poids={poids},temp={temperature},valid={validation}"
                
                elif message == "detect-ports":
                    # Nouvelle commande pour re-détecter les ports
                    ports = detect_sensor_ports()
                    ports_str = ",".join([f"{k}:{v}" for k, v in ports.items() if v])
                    response = f"Ports:{ports_str}"
                
                else:
                    response = f"Commande inconnue: {message}"
                    logger.warning(f"⚠️ Commande inconnue de {client_address}: {message}")
                
                await websocket.send(response)
                logger.debug(f"📤 Envoyé à {client_address}: {response}")
                    
            except websockets.exceptions.ConnectionClosed:
                logger.info(f"🔌 Connexion fermée par {client_address}")
                break
            except Exception as e:
                logger.error(f"❌ Erreur traitement message de {client_address}: {e}")
                try:
                    await websocket.send(f"Erreur serveur: {str(e)}")
                except:
                    pass
                
    except websockets.exceptions.ConnectionClosed:
        logger.info(f"🔌 Client {client_address} déconnecté")
    except Exception as e:
        logger.error(f"❌ Erreur dans socket_server pour {client_address}: {e}")
    finally:
        connected_clients.discard(websocket)
        logger.info(f"🔚 Fin de session avec {client_address} (Clients restants: {len(connected_clients)})")

# Fonction de démarrage du serveur WebSocket
async def start_websocket_server():
    """Démarrage du serveur WebSocket"""
    logger.info("🚀 Démarrage du serveur WebSocket sur 127.0.0.1:8765")
    try:
        async with websockets.serve(
            socket_server,
            "127.0.0.1", 
            8765,
            ping_interval=30,
            ping_timeout=10,
            close_timeout=10
        ):
            logger.info("✅ Serveur WebSocket démarré avec succès")
            logger.info(f"📡 En écoute sur ws://127.0.0.1:8765")
            
            await asyncio.Future()  # Run forever
        
    except Exception as e:
        logger.error(f"❌ Erreur serveur WebSocket: {e}")
        raise

def run_websocket_server():
    """Fonction pour exécuter le serveur WebSocket dans un thread"""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
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
    
    for client in connected_clients.copy():
        try:
            asyncio.create_task(client.close())
        except:
            pass
    
    sys.exit(0)

def main():
    """Point d'entrée principal"""
    logger.info("=" * 60)
    logger.info("🏥 ===== DÉMARRAGE DE MEDISENSE PRO v2.2 =====")
    logger.info("=" * 60)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Lancement du thread de lecture série
        logger.info("🔧 Lancement du thread de lecture série avec détection automatique...")
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
        logger.info("🔍 Détection automatique des ports USB activée")
        logger.info("🌐 WebSocket accessible sur ws://127.0.0.1:8765")
        logger.info("⏹️  Appuyez sur Ctrl+C pour arrêter")
        logger.info("-" * 60)
        
        # Maintenir le programme principal en vie avec monitoring
        heartbeat_counter = 0
        while not shutdown_event.is_set():
            time.sleep(10)
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
            
            # Log de status toutes les minutes
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
        time.sleep(2)
        logger.info("✅ Programme terminé proprement")
        logger.info("=" * 60)

if __name__ == "__main__":
    main()