// Configuration WebSocket
const ipAddress = "127.0.0.1";
const port = "8765";
let socket = null;



function updateConnectionStatus(isConnected) {
    

    const statusItemCapteur = document.querySelector('.status-item.capteur');
    const statusTextCapteur = statusItemCapteur.querySelector('span');
    const statusDotItemCapteur = statusItemCapteur.querySelector('.status-dot')



    const statusItemSynchro = document.querySelector('.status-item.synchro');
    const statusTextSynchro = statusItemCapteur.querySelector('span');
    const statusDotItemSynchro = statusItemSynchro.querySelector('.status-dot')

    

    const statusElement = document.querySelector('.connection-status');
    const statusText = statusElement.querySelector('span');
    const statusDot = statusElement.querySelector('.status-dot');

    

    if (isConnected) {
        statusElement.style.background = 'rgba(0, 255, 100, 0.1)';
        statusText.textContent = 'Connecté au serveur IoT';
        if (statusDot) {
            statusDot.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
        }
        if (statusDotItem) {
            statusDotItem.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
        }


        statusItemCapteur.style.background = 'rgba(0, 255, 100, 0.1)';
        statusTextCapteur.textContent = 'Capteurs Actifs';
        if (statusDotItemCapteur) {
            statusDotItemCapteur.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
        }

        statusItemSynchro.style.background = 'rgba(0, 255, 100, 0.1)';
        statusTextSynchro.textContent = 'Synchronisation Auto';
        if (statusDotItemSynchro) {
            statusDotItemSynchro.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
        }


    } else {
        statusElement.style.background = 'rgba(255, 0, 0, 0.1)';
        statusText.textContent = 'Déconnecté - Tentative de reconnexion...';
        if (statusDot) {
            statusDot.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
        }


        statusItemCapteur.style.background = 'rgba(255, 0, 0, 0.1)';
        statusTextCapteur.textContent = 'Capteurs Non Connectés';
        if (statusDotItemCapteur) {
            statusDotItemCapteur.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
        }

        statusItemSynchro.style.background = 'rgba(255, 0, 0, 0.1)';
        statusTextSynchro.textContent = 'Synchronisation OFF';
        if (statusDotItemSynchro) {
            statusDotItemSynchro.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
        }
    }
}




// Fonction pour établir la connexion WebSocket
function connectWebSocket() {
    socket = new WebSocket(`ws://${ipAddress}:${port}`);

    console.log("Tentative de connexion WebSocket...");

    
    // Gestion des événements de connexion
    socket.onopen = function() {
        console.log("Connexion WebSocket établie");

        /*
        document.querySelector('.connection-status').style.background = 'rgba(0, 255, 100, 0.1)';
        document.querySelector('.connection-status span').textContent = 'Connecté au serveur IoT';
        const dot = document.querySelector('.connection-status .status-dot');
        if (dot) dot.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
        */
        updateConnectionStatus(true)
    };

    socket.onclose = function() {
        console.log("Connexion WebSocket fermée");
        
        /*
        document.querySelector('.connection-status').style.background = 'rgba(255, 0, 0, 0.1)';
        document.querySelector('.connection-status span').textContent = 'Déconnecté - Tentative de reconnexion...';
        const dot = document.querySelector('.connection-status .status-dot');
        if (dot) dot.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
        */
        updateConnectionStatus(false)

        // Tentative de reconnexion après 5 secondes
        setTimeout(connectWebSocket, 5000);
    };

    socket.onerror = function(error) {
        console.error("Erreur WebSocket:", error);
        
        /*
        document.querySelector('.connection-status').style.background = 'rgba(255, 0, 0, 0.1)';
        document.querySelector('.connection-status span').textContent = 'Erreur de connexion';
        const dot = document.querySelector('.connection-status .status-dot');
        if (dot) dot.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
        */
        updateConnectionStatus(false)

    };

    // Gestion des messages reçus
    socket.onmessage = function(event) {
        const message = event.data;
        
        if (message.startsWith("All-Mesure:")) {
            // Traitement des données groupées
            const mesures = message.substring(11).split(":");
            
            mesures.forEach(mesure => {
                const [type, valeur] = mesure.split(":");
                
                switch(type) {
                    case "poids":
                        updateCardValue('data-poid', valeur, 'kg');
                        break;
                    case "temperature":
                        updateCardValue('data-temperature', valeur, '°C');
                        break;
                    case "taille":
                        updateCardValue('data-taille', valeur, 'm');
                        break;
                    case "validation":
                        updateCardValue('data-validation', valeur, '');
                        break;
                }
            });
        } else {
            // Traitement des messages individuels
            if (message.startsWith("Poids:")) {
                const valeur = message.split(':')[1];
                updateCardValue('data-poid', valeur, 'kg');
            } 
            else if (message.startsWith("Température:")) {
                const valeur = message.split(':')[1];
                updateCardValue('data-temperature', valeur, '°C');
            } 
            else if (message.startsWith("Taille:")) {
                const valeur = message.split(':')[1];
                updateCardValue('data-taille', valeur, 'm');
            } 
            else if (message.startsWith("Validation:")) {
                const valeur = message.split(':')[1];
                updateCardValue('data-validation', valeur, '');
            }
        }
    };
}

// Fonction pour mettre à jour les valeurs des cartes avec animation
function updateCardValue(elementId, value, unit) {
    const element = document.getElementById(elementId);
    if (element) {
        // Animation de mise à jour
        element.style.transform = 'scale(1.2)';
        element.style.color = '#00ff64';
        
        // Mise à jour de la valeur
        setTimeout(() => {
            if (value === "0" || value === "non_disponible") {
                element.textContent = "--";
            } else {
                element.textContent = value;
            }
            element.style.transform = 'scale(1)';
            element.style.color = '';
        }, 200);

        // Mise à jour du statut "Mis à jour maintenant"
        const cardFooter = element.closest('.data-card').querySelector('.last-update span');
        if (cardFooter) {
            cardFooter.textContent = 'Mis à jour maintenant';
        }

        // Mise à jour de l'indicateur de tendance
        const trendIndicator = element.closest('.data-card').querySelector('.trend-indicator');
        if (trendIndicator) {
            if (value === "0" || value === "non_disponible") {
                trendIndicator.innerHTML = '<i class="fas fa-exclamation-circle"></i><span>Erreur</span>';
                trendIndicator.style.background = 'rgba(255, 0, 0, 0.1)';
                trendIndicator.style.color = '#ff0000';
            } else {
                trendIndicator.innerHTML = '<i class="fas fa-check"></i><span>Normal</span>';
                trendIndicator.style.background = 'rgba(0, 255, 100, 0.1)';
                trendIndicator.style.color = '#00ff64';
            }
        }
    }
}

// Fonction pour demander toutes les mesures
function getAllMesures() {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send("all-mesure");
        console.log("Demande de toutes les mesures envoyée avec succès");
    }
}

// Fonction pour demander une mesure spécifique
function getMesure(type) {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(`get-${type}`);
    }
}

// Initialisation
document.addEventListener('DOMContentLoaded', () => {
    // Connexion WebSocket
    connectWebSocket();
    console.log("Connexion WebSocket initialisée");

    // Mise à jour automatique toutes les 5 secondes
    setInterval(getAllMesures, 2000);

    // Ajout des événements de clic sur les cartes pour des mises à jour manuelles
    document.querySelectorAll('.data-card').forEach(card => {
        card.addEventListener('click', () => {
            const type = card.querySelector('.card-title').textContent.toLowerCase();
            switch(type) {
                case 'poids corporel':
                    getMesure('poid');
                    console.log(`Mise à jour de ${type} demandée`);
                    break;
                case 'température':
                    getMesure('temperature');
                    console.log(`Mise à jour de ${type} demandée`);
                    break;
                case 'taille':
                    getMesure('taille');
                    console.log(`Mise à jour de ${type} demandée`);
                    break;
                case 'validation':
                    getMesure('validation');
                    console.log(`Mise à jour de ${type} demandée`);
                    break;
            }
        });
    });
});