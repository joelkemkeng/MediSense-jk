import serial
import time
import threading
import asyncio
import websockets
import logging
import signal
import sys
import glob
from typing import Optional, Dict, Any

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
sensor_data: Dict[str, Any] = {
    'poids': None,
    'temperature': None,
    'temp': None,  # Alias pour temperature
    'validation': None,
    'card': None,  # Alias pour validation
    'taille': None,
    'size': None,  # Alias pour taille
}

# Configuration des capteurs avec validation
SENSOR_CONFIG = {
    'poids': {
        'min_value': 0,
        'max_value': 500,
        'unit': 'kg',
        'precision': 1,
        'aliases': ['weight', 'masse']
    },
    'temperature': {
        'min_value': 0,
        'max_value': 50,
        'unit': '°C',
        'precision': 1,
        'aliases': ['temp']
    },
    'temp': {
        'min_value': 0,
        'max_value': 50,
        'unit': '°C',
        'precision': 1,
        'aliases': ['temperature']
    },
    'validation': {
        'expected_value': 310502,
        'unit': '',
        'precision': 0,
        'aliases': ['card', 'valid']
    },
    'card': {
        'expected_value': 310502,
        'unit': '',
        'precision': 0,
        'aliases': ['validation', 'valid']
    },
    'taille': {
        'min_value': 0.5,
        'max_value': 3.0,
        'unit': 'm',
        'precision': 2,
        'aliases': ['size', 'height']
    },
    'size': {
        'min_value': 0.5,
        'max_value': 3.0,
        'unit': 'm',
        'precision': 2,
        'aliases': ['taille', 'height']
    }
}

# Code de référence pour la validation
refValidateCard: int = 310502

# Lock pour la synchronisation des threads
data_lock = threading.Lock()

# Variable pour contrôler l'arrêt propre du programme
shutdown_event = threading.Event()

# Liste des clients connectés
connected_clients = set()

# Dictionnaire des ports actifs
active_ports: Dict[str, serial.Serial] = {}

def discover_serial_ports():
    """
    Découvre automatiquement tous les ports série disponibles
    Returns: Liste des ports série détectés
    """
    logger.info("🔍 Découverte automatique des ports série...")
    
    # Types de ports à scanner
    port_patterns = [
        '/dev/ttyUSB*',
        '/dev/ttyACM*', 
        '/dev/ttyS*',
        '/dev/ttyAMA*'
    ]
    
    available_ports = []
    
    for pattern in port_patterns:
        ports = glob.glob(pattern)
        available_ports.extend(sorted(ports))
    
    # Filtrer les ports système non utilisables
    filtered_ports = []
    for port in available_ports:
        try:
            # Test rapide d'ouverture
            test_ser = serial.Serial(port, 9600, timeout=0.1)
            test_ser.close()
            filtered_ports.append(port)
            logger.info(f"📡 Port détecté: {port}")
        except (serial.SerialException, PermissionError) as e:
            logger.debug(f"⚠️ Port {port} non accessible: {e}")
    
    logger.info(f"✅ {len(filtered_ports)} port(s) série utilisable(s) trouvé(s)")
    return filtered_ports

def connect_to_ports(ports_list):
    """
    Établit les connexions avec tous les ports disponibles
    Args: ports_list - Liste des ports à connecter
    Returns: Dictionnaire des connexions établies
    """
    logger.info("🔌 Connexion aux ports série...")
    
    connections = {}
    
    # Baudrates courants à tester
    baudrates = [9600, 57600, 115200, 38400, 19200]
    
    for port in ports_list:
        port_name = port.split('/')[-1]  # Extraire le nom du port
        
        for baudrate in baudrates:
            try:
                ser = serial.Serial(port, baudrate, timeout=1)
                connections[port_name] = {
                    'serial': ser,
                    'port_path': port,
                    'baudrate': baudrate,
                    'last_data': None,
                    'error_count': 0
                }
                logger.info(f"✅ {port_name} connecté à {baudrate} baud")
                break  # Connexion réussie, arrêter les tests de baudrate
                
            except serial.SerialException as e:
                logger.debug(f"❌ Échec connexion {port} @ {baudrate}: {e}")
                continue
        
        if port_name not in connections:
            logger.warning(f"⚠️ Impossible de connecter {port}")
    
    logger.info(f"🎯 {len(connections)} connexion(s) établie(s)")
    return connections

def parse_sensor_data(raw_data: str, port_name: str) -> tuple:
    """
    Parse les données reçues d'un capteur selon le format préfixe:valeur
    Args: 
        raw_data - Données brutes reçues
        port_name - Nom du port source
    Returns: (sensor_type, value, success)
    """
    try:
        # Nettoyer les données
        data = raw_data.strip()
        
        if not data:
            return None, None, False
        
        # Vérifier le format préfixe:valeur
        if ':' not in data:
            logger.debug(f"📥 {port_name}: Format non reconnu: '{data}'")
            return None, None, False
        
        # Séparer préfixe et valeur
        parts = data.split(':', 1)  # Split seulement sur le premier ':'
        if len(parts) != 2:
            logger.debug(f"📥 {port_name}: Format invalide: '{data}'")
            return None, None, False
        
        sensor_type = parts[0].lower().strip()
        value_str = parts[1].strip()
        
        # Vérifier si le type de capteur est connu
        if sensor_type not in SENSOR_CONFIG:
            # Vérifier les aliases
            found = False
            for main_type, config in SENSOR_CONFIG.items():
                if sensor_type in config.get('aliases', []):
                    sensor_type = main_type
                    found = True
                    break
            
            if not found:
                logger.debug(f"📥 {port_name}: Type capteur inconnu: '{sensor_type}'")
                return None, None, False
        
        # Convertir la valeur selon le type
        config = SENSOR_CONFIG[sensor_type]
        
        try:
            if sensor_type in ['validation', 'card']:
                # Pour la validation, convertir en entier
                value = int(float(value_str))  # float puis int pour gérer "310502.0"
            else:
                # Pour les autres, convertir en float
                value = float(value_str)
                # Appliquer la précision
                value = round(value, config.get('precision', 1))
        
        except ValueError as e:
            logger.warning(f"❌ {port_name}: Impossible de convertir '{value_str}': {e}")
            return None, None, False
        
        logger.debug(f"📊 {port_name}: {sensor_type} = {value}")
        return sensor_type, value, True
        
    except Exception as e:
        logger.error(f"❌ Erreur parsing données de {port_name}: {e}")
        return None, None, False

def validate_sensor_value(sensor_type: str, value) -> bool:
    """
    Valide une valeur de capteur selon sa configuration
    Args:
        sensor_type - Type du capteur
        value - Valeur à valider
    Returns: True si valide, False sinon
    """
    if sensor_type not in SENSOR_CONFIG:
        return False
    
    config = SENSOR_CONFIG[sensor_type]
    
    try:
        if sensor_type in ['validation', 'card']:
            # Validation spéciale pour les codes
            expected = config.get('expected_value', refValidateCard)
            return value == expected
        else:
            # Validation par plage pour les autres capteurs
            min_val = config.get('min_value', float('-inf'))
            max_val = config.get('max_value', float('inf'))
            return min_val <= value <= max_val
    
    except Exception as e:
        logger.error(f"❌ Erreur validation {sensor_type}: {e}")
        return False

def update_sensor_data(sensor_type: str, value, port_name: str):
    """
    Met à jour les données globales des capteurs
    Args:
        sensor_type - Type du capteur
        value - Nouvelle valeur
        port_name - Port source
    """
    global sensor_data
    
    if not validate_sensor_value(sensor_type, value):
        logger.warning(f"⚠️ {port_name}: Valeur {sensor_type}={value} hors limites")
        return False
    
    with data_lock:
        # Mettre à jour la valeur principale
        sensor_data[sensor_type] = value
        
        # Mettre à jour les aliases si nécessaire
        config = SENSOR_CONFIG.get(sensor_type, {})
        for alias in config.get('aliases', []):
            if alias in sensor_data:
                sensor_data[alias] = value
        
        # Log de mise à jour
        unit = config.get('unit', '')
        logger.info(f"📊 {sensor_type.capitalize()}: {value}{unit} (depuis {port_name})")
    
    return True

def read_serial_data():
    """Fonction principale qui lit en continu les données de tous les ports série"""
    logger.info("🚀 Démarrage de la lecture des données série...")
    
    # Découvrir les ports disponibles
    available_ports = discover_serial_ports()
    
    if not available_ports:
        logger.warning("⚠️ Aucun port série disponible! Démarrage en mode SIMULATION...")
        run_simulation_mode()
        return
    
    # Établir les connexions
    connections = connect_to_ports(available_ports)
    
    if not connections:
        logger.warning("⚠️ Aucune connexion établie! Démarrage en mode SIMULATION...")
        run_simulation_mode()
        return
    
    logger.info(f"✅ Lecture démarrée sur {len(connections)} port(s)")
    
    # Boucle principale de lecture
    while not shutdown_event.is_set():
        try:
            data_received = False
            
            # Lire chaque port connecté
            for port_name, conn_info in connections.items():
                ser = conn_info['serial']
                
                try:
                    if not ser.is_open:
                        continue
                    
                    # Lire les données disponibles
                    if ser.in_waiting > 0:
                        raw_data = ser.readline().decode('utf-8', errors='ignore').strip()
                        
                        if raw_data:
                            # Parser les données
                            sensor_type, value, success = parse_sensor_data(raw_data, port_name)
                            
                            if success and sensor_type and value is not None:
                                # Mettre à jour les données
                                if update_sensor_data(sensor_type, value, port_name):
                                    data_received = True
                                    conn_info['last_data'] = time.time()
                                    conn_info['error_count'] = 0
                            else:
                                logger.debug(f"📥 {port_name}: Données ignorées: '{raw_data}'")
                
                except serial.SerialException as e:
                    conn_info['error_count'] += 1
                    logger.error(f"❌ Erreur lecture {port_name}: {e}")
                    
                    # Reconnecter si trop d'erreurs
                    if conn_info['error_count'] > 5:
                        logger.warning(f"🔄 Tentative de reconnexion {port_name}...")
                        try:
                            ser.close()
                            time.sleep(1)
                            new_ser = serial.Serial(conn_info['port_path'], conn_info['baudrate'], timeout=1)
                            conn_info['serial'] = new_ser
                            conn_info['error_count'] = 0
                            logger.info(f"✅ {port_name} reconnecté")
                        except Exception as reconnect_error:
                            logger.error(f"❌ Échec reconnexion {port_name}: {reconnect_error}")
                
                except Exception as e:
                    logger.error(f"❌ Erreur inattendue {port_name}: {e}")
            
            # Pause adaptative
            time.sleep(0.05 if data_received else 0.2)
            
        except Exception as e:
            logger.error(f"❌ Erreur critique dans la boucle de lecture: {e}")
            time.sleep(1)
    
    # Fermeture propre des connexions
    logger.info("🔌 Fermeture des connexions série...")
    for port_name, conn_info in connections.items():
        try:
            if conn_info['serial'].is_open:
                conn_info['serial'].close()
                logger.info(f"🔌 {port_name} fermé")
        except Exception as e:
            logger.error(f"❌ Erreur fermeture {port_name}: {e}")

def run_simulation_mode():
    """Mode simulation avec données fictives"""
    logger.info("🎭 Mode SIMULATION activé")
    
    counter = 0
    last_validation_time = 0
    
    while not shutdown_event.is_set():
        try:
            current_time = time.time()
            counter += 1
            
            with data_lock:
                # Simulation de données réalistes
                sensor_data['poids'] = round(70.5 + (counter % 20) * 0.1, 1)
                sensor_data['temperature'] = round(36.5 + (counter % 8) * 0.05, 1) 
                sensor_data['temp'] = sensor_data['temperature']  # Alias
                
                # Validation toutes les 30 secondes
                if current_time - last_validation_time > 30:
                    sensor_data['validation'] = refValidateCard
                    sensor_data['card'] = refValidateCard  # Alias
                    last_validation_time = current_time
                    logger.info(f"✅ [SIMULATION] Validation générée: {refValidateCard}")
            
            # Log périodique
            if counter % 10 == 0:
                with data_lock:
                    logger.info(f"📊 [SIMULATION] Poids: {sensor_data['poids']}kg, "
                              f"Température: {sensor_data['temperature']}°C")
            
            time.sleep(2)
            
        except Exception as e:
            logger.error(f"❌ Erreur en mode simulation: {e}")
            time.sleep(1)

async def socket_server(websocket):
    """Fonction pour gérer les connexions WebSocket"""
    client_address = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
    logger.info(f"🌐 Nouvelle connexion WebSocket de {client_address}")
    
    connected_clients.add(websocket)
    
    try:
        await websocket.send("Connection au serveur effectuée")
        logger.info(f"✅ Message de bienvenue envoyé à {client_address}")

        async for message in websocket:
            logger.debug(f"📨 Message de {client_address}: {message}")
            
            try:
                response = ""
                
                # Gestion des commandes
                if message == "get-poid":
                    with data_lock:
                        value = sensor_data.get('poids')
                        response = f"Poids:{value}" if value is not None and value > 0 else "Poids:0"

                elif message == "get-temperature":
                    with data_lock:
                        value = sensor_data.get('temperature') or sensor_data.get('temp')
                        response = f"Température:{value}" if value is not None and value > 0 else "Température:0"

                elif message == "get-validation":
                    with data_lock:
                        value = sensor_data.get('validation') or sensor_data.get('card')
                        if value == refValidateCard:
                            response = f"Validation:{value}"
                            # Réinitialiser après envoi
                            sensor_data['validation'] = None
                            sensor_data['card'] = None
                        else:
                            response = "Validation:0"

                elif message == "get-taille":
                    with data_lock:
                        value = sensor_data.get('taille') or sensor_data.get('size')
                        response = f"Taille:{value}" if value is not None and value > 0 else "Taille:0"

                elif message == "reset-data":
                    with data_lock:
                        for key in sensor_data:
                            sensor_data[key] = None
                    response = "Reset:OK"
                    logger.info(f"🔄 Données réinitialisées par {client_address}")

                elif message == "all-mesure":
                    mesures = []
                    
                    with data_lock:
                        # Poids
                        poids_val = sensor_data.get('poids')
                        mesures.append(f"poids:{poids_val}" if poids_val is not None and poids_val > 0 else "poids:0")
                        
                        # Température
                        temp_val = sensor_data.get('temperature') or sensor_data.get('temp')
                        mesures.append(f"temperature:{temp_val}" if temp_val is not None and temp_val > 0 else "temperature:0")
                        
                        # Taille
                        taille_val = sensor_data.get('taille') or sensor_data.get('size')
                        mesures.append(f"taille:{taille_val}" if taille_val is not None and taille_val > 0 else "taille:0")
                        
                        # Validation
                        valid_val = sensor_data.get('validation') or sensor_data.get('card')
                        if valid_val == refValidateCard:
                            mesures.append(f"validation:{valid_val}")
                            # Réinitialiser après envoi
                            sensor_data['validation'] = None
                            sensor_data['card'] = None
                        else:
                            mesures.append("validation:0")
                    
                    response = "All-Mesure:" + ":".join(mesures)

                elif message == "ping":
                    response = "pong"

                elif message == "status":
                    with data_lock:
                        response = f"Status:clients={len(connected_clients)},sensors={len([k for k, v in sensor_data.items() if v is not None])}"

                elif message == "get-sensors":
                    # Nouvelle commande pour lister tous les capteurs détectés
                    with data_lock:
                        active_sensors = [k for k, v in sensor_data.items() if v is not None]
                        response = f"Sensors:{','.join(active_sensors)}"

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

def signal_handler(signum):
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
    logger.info("🏥 ===== DÉMARRAGE DE MEDISENSE PRO v3.0 =====")
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
        logger.info("🔍 Détection automatique des capteurs par préfixe activée")
        logger.info("📊 Format attendu: 'type:valeur' (ex: temp:36.5, poids:70.2)")
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
                    active_sensors = [k for k, v in sensor_data.items() if v is not None]
                    logger.info(f"💓 Status: Clients={len(connected_clients)}, "
                              f"Capteurs actifs={len(active_sensors)}, "
                              f"Données: {dict((k, v) for k, v in sensor_data.items() if v is not None)}")
            
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