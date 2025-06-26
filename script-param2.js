// Configuration WebSocket
const ipAddress = "127.0.0.1";
const port = "8765";
let socket = null;
let reconnectInterval = null;
let maxReconnectAttempts = 10;
let reconnectAttempts = 0;
let autoUpdateInterval = null;
let verifCardAccess = "310502";

// === Loader général stylé ===
function showGlobalLoader() {
    let loader = document.getElementById('global-loader');
    if (!loader) {
        loader = document.createElement('div');
        loader.id = 'global-loader';
        loader.innerHTML = `
            <div class="loader-overlay">
                <div class="loader-spinner"></div>
                <div class="loader-text">Traitement en cours...</div>
            </div>
        `;
        document.body.appendChild(loader);
        // Style CSS dynamique
        const style = document.createElement('style');
        style.id = 'global-loader-style';
        style.textContent = `
            #global-loader {
                position: fixed;
                top: 0; left: 0; right: 0; bottom: 0;
                width: 100vw; height: 100vh;
                background: rgba(10, 11, 30, 0.85);
                z-index: 9999;
                display: flex;
                align-items: center;
                justify-content: center;
                animation: fadeInLoader 0.3s;
            }
            @keyframes fadeInLoader {
                from { opacity: 0; }
                to { opacity: 1; }
            }
            .loader-overlay {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
            }
            .loader-spinner {
                width: 80px;
                height: 80px;
                border: 8px solid rgba(255,255,255,0.15);
                border-top: 8px solid #667eea;
                border-radius: 50%;
                animation: spinLoader 1s linear infinite;
                margin-bottom: 24px;
                box-shadow: 0 0 40px #667eea44;
            }
            @keyframes spinLoader {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            .loader-text {
                color: #fff;
                font-size: 1.5rem;
                font-weight: 600;
                letter-spacing: 1px;
                text-shadow: 0 2px 16px #667eea88;
                margin-top: 8px;
                font-family: 'Inter', sans-serif;
            }
        `;
        document.head.appendChild(style);
    }
    loader.style.display = 'flex';
}

function hideGlobalLoader() {
    const loader = document.getElementById('global-loader');
    if (loader) loader.style.display = 'none';
}

// Fonction pour mettre à jour le statut de connexion (BUG CORRIGÉ)
function updateConnectionStatus(isConnected) {
    console.log(`🔄 Mise à jour du statut de connexion: ${isConnected ? 'Connecté' : 'Déconnecté'}`);
    
    // Éléments de statut principal
    const statusElement = document.querySelector('.connection-status');
    const statusText = statusElement?.querySelector('span');
    const statusDot = statusElement?.querySelector('.status-dot');

    // Éléments de statut des capteurs
    const statusItemCapteur = document.querySelector('.status-item.capteur');
    const statusTextCapteur = statusItemCapteur?.querySelector('span');
    const statusDotItemCapteur = statusItemCapteur?.querySelector('.status-dot');

    // Éléments de statut de synchronisation
    const statusItemSynchro = document.querySelector('.status-item.synchro');
    const statusTextSynchro = statusItemSynchro?.querySelector('span'); // ✅ BUG CORRIGÉ
    const statusDotItemSynchro = statusItemSynchro?.querySelector('.status-dot');

    if (isConnected) {
        // État connecté - Vert
        if (statusElement) {
            statusElement.style.background = 'rgba(0, 255, 100, 0.1)';
            statusElement.style.borderColor = 'rgba(0, 255, 100, 0.3)';
            statusElement.style.boxShadow = '0 0 20px rgba(0, 255, 100, 0.3)';
        }
        if (statusText) statusText.textContent = 'Connecté au serveur IoT';
        if (statusDot) {
            statusDot.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
            statusDot.style.boxShadow = '0 0 10px rgba(0, 255, 100, 0.8)';
        }

        // Capteurs actifs
        if (statusItemCapteur) {
            statusItemCapteur.style.background = 'rgba(0, 255, 100, 0.1)';
            statusItemCapteur.style.borderColor = 'rgba(0, 255, 100, 0.3)';
        }
        if (statusTextCapteur) statusTextCapteur.textContent = 'Capteurs Actifs';
        if (statusDotItemCapteur) {
            statusDotItemCapteur.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
            statusDotItemCapteur.style.boxShadow = '0 0 10px rgba(0, 255, 100, 0.8)';
        }

        // Synchronisation active
        if (statusItemSynchro) {
            statusItemSynchro.style.background = 'rgba(0, 255, 100, 0.1)';
            statusItemSynchro.style.borderColor = 'rgba(0, 255, 100, 0.3)';
        }
        if (statusTextSynchro) statusTextSynchro.textContent = 'Synchronisation Auto';
        if (statusDotItemSynchro) {
            statusDotItemSynchro.style.background = 'linear-gradient(45deg, #00ff64, #00ff64)';
            statusDotItemSynchro.style.boxShadow = '0 0 10px rgba(0, 255, 100, 0.8)';
        }

        // Réinitialiser le compteur de reconnexion
        reconnectAttempts = 0;
        
    } else {
        // État déconnecté - Rouge
        const statusMessage = reconnectAttempts > 0 ? 
            `Reconnexion... (${reconnectAttempts}/${maxReconnectAttempts})` : 
            'Déconnecté - Tentative de reconnexion...';

        if (statusElement) {
            statusElement.style.background = 'rgba(255, 0, 0, 0.1)';
            statusElement.style.borderColor = 'rgba(255, 0, 0, 0.3)';
            statusElement.style.boxShadow = '0 0 20px rgba(255, 0, 0, 0.3)';
        }
        if (statusText) statusText.textContent = statusMessage;
        if (statusDot) {
            statusDot.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
            statusDot.style.boxShadow = '0 0 10px rgba(255, 0, 0, 0.8)';
        }

        // Capteurs non connectés
        if (statusItemCapteur) {
            statusItemCapteur.style.background = 'rgba(255, 0, 0, 0.1)';
            statusItemCapteur.style.borderColor = 'rgba(255, 0, 0, 0.3)';
        }
        if (statusTextCapteur) statusTextCapteur.textContent = 'Capteurs Non Connectés';
        if (statusDotItemCapteur) {
            statusDotItemCapteur.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
            statusDotItemCapteur.style.boxShadow = '0 0 10px rgba(255, 0, 0, 0.8)';
        }

        // Synchronisation off
        if (statusItemSynchro) {
            statusItemSynchro.style.background = 'rgba(255, 0, 0, 0.1)';
            statusItemSynchro.style.borderColor = 'rgba(255, 0, 0, 0.3)';
        }
        if (statusTextSynchro) statusTextSynchro.textContent = 'Synchronisation OFF';
        if (statusDotItemSynchro) {
            statusDotItemSynchro.style.background = 'linear-gradient(45deg, #ff0000, #ff0000)';
            statusDotItemSynchro.style.boxShadow = '0 0 10px rgba(255, 0, 0, 0.8)';
        }
    }
}

// Fonction pour afficher une notification toast
function showNotification(message, type = 'info', duration = 3000) {
    console.log(`📢 Notification [${type}]: ${message}`);
    
    // Créer ou récupérer l'élément de notification
    let notification = document.getElementById('notification-toast');
    if (!notification) {
        notification = document.createElement('div');
        notification.id = 'notification-toast';
        notification.style.cssText = `
            position: fixed;
            top: 100px;
            right: 2rem;
            padding: 1rem 1.5rem;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.18);
            border-radius: 12px;
            color: white;
            font-size: 0.9rem;
            z-index: 2000;
            transform: translateX(100%);
            transition: transform 0.3s ease;
            max-width: 300px;
            word-wrap: break-word;
        `;
        document.body.appendChild(notification);
    }

    // Couleurs selon le type
    const colors = {
        success: 'rgba(0, 255, 100, 0.2)',
        error: 'rgba(255, 0, 0, 0.2)',
        warning: 'rgba(255, 255, 0, 0.2)',
        info: 'rgba(0, 150, 255, 0.2)'
    };

    notification.style.background = colors[type] || colors.info;
    notification.textContent = message;
    notification.style.transform = 'translateX(0)';

    // Masquer après le délai spécifié
    setTimeout(() => {
        notification.style.transform = 'translateX(100%)';
    }, duration);
}

// Fonction pour établir la connexion WebSocket avec gestion robuste
function connectWebSocket() {
    if (socket && (socket.readyState === WebSocket.CONNECTING || socket.readyState === WebSocket.OPEN)) {
        console.log("⚠️ Connexion déjà en cours ou établie");
        return;
    }

    try {
        console.log(`🔄 Tentative de connexion WebSocket ${reconnectAttempts + 1}/${maxReconnectAttempts}...`);
        socket = new WebSocket(`ws://${ipAddress}:${port}`);

        // Timeout de connexion
        const connectionTimeout = setTimeout(() => {
            if (socket.readyState === WebSocket.CONNECTING) {
                console.log("⏰ Timeout de connexion WebSocket");
                socket.close();
            }
        }, 10000); // 10 secondes

        // Gestion de l'ouverture de connexion
        socket.onopen = function(event) {
            clearTimeout(connectionTimeout);
            console.log("✅ Connexion WebSocket établie avec succès");
            updateConnectionStatus(true);
            showNotification("Connexion au serveur établie", "success");
            
            // Réinitialiser les tentatives de reconnexion
            reconnectAttempts = 0;
            if (reconnectInterval) {
                clearInterval(reconnectInterval);
                reconnectInterval = null;
            }

            // Démarrer les mises à jour automatiques
            startAutoUpdate();
        };

        // Gestion de la fermeture de connexion
        socket.onclose = function(event) {
            clearTimeout(connectionTimeout);
            console.log(`❌ Connexion WebSocket fermée (Code: ${event.code}, Raison: ${event.reason || 'Non spécifiée'})`);
            updateConnectionStatus(false);
            
            // Arrêter les mises à jour automatiques
            stopAutoUpdate();
            
            if (event.code !== 1000) { // 1000 = fermeture normale
                showNotification("Connexion perdue, tentative de reconnexion...", "warning");
            }

            // Tentative de reconnexion avec backoff exponentiel
            if (reconnectAttempts < maxReconnectAttempts) {
                reconnectAttempts++;
                const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000); // Max 30s
                console.log(`🔄 Reconnexion dans ${delay/1000}s...`);
                
                setTimeout(() => {
                    connectWebSocket();
                }, delay);
            } else {
                console.error("🚫 Nombre maximum de tentatives de reconnexion atteint");
                showNotification("Impossible de se reconnecter au serveur", "error", 5000);
            }
        };

        // Gestion des erreurs
        socket.onerror = function(error) {
            clearTimeout(connectionTimeout);
            console.error("❌ Erreur WebSocket:", error);
            updateConnectionStatus(false);
            showNotification("Erreur de connexion au serveur", "error");
        };

        // Gestion des messages reçus
        socket.onmessage = function(event) {
            const message = event.data;
            console.log("📨 Message reçu:", message);
            
            try {
                if (message.startsWith("All-Mesure:")) {
                    // Traitement des données groupées
                    const mesuresData = message.substring(11); // Supprimer "All-Mesure:"
                    const mesures = mesuresData.split(":");
                    
                    console.log("📊 Données reçues:", mesures);
                    
                    // Traiter par paires (type:valeur)
                    for (let i = 0; i < mesures.length; i += 2) {
                        if (i + 1 < mesures.length) {
                            const type = mesures[i];
                            const valeur = mesures[i + 1];
                            
                            console.log(`📈 Traitement: ${type} = ${valeur}`);
                            
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
                                    // Vérification et reset si besoin
                                    let valStr = (typeof valeur === "string") ? valeur : String(valeur);
                                    if (valStr === verifCardAccess) {
                                        if (socket && socket.readyState === WebSocket.OPEN) {
                                            socket.send("reset-data");
                                            console.log("✅ Validation correcte, reset demandé au serveur");
                                            showGlobalLoader();
                                            setTimeout(hideGlobalLoader, 3000);
                                        }
                                    }
                                    break;
                                default:
                                    console.warn(`⚠️ Type de donnée inconnu: ${type}`);
                            }
                        }
                    }
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
                        // Vérification et reset si besoin
                        let valStr = (typeof valeur === "string") ? valeur : String(valeur);
                        if (valStr === verifCardAccess) {
                            if (socket && socket.readyState === WebSocket.OPEN) {
                                socket.send("reset-data");
                                console.log("✅ Validation correcte, reset demandé au serveur");
                                showGlobalLoader();
                                setTimeout(hideGlobalLoader, 3000);
                            }
                        }
                    }
                    else if (message === "Connection au serveur effectuée") {
                        console.log("✅ Message de bienvenue reçu du serveur");
                        showNotification("Serveur MediSense connecté", "success");
                    }
                    else if (message === "pong") {
                        console.log("🏓 Pong reçu du serveur");
                    }
                    else {
                        console.log("📝 Autre message:", message);
                    }
                }
            } catch (parseError) {
                console.error("❌ Erreur lors du traitement du message:", parseError);
                showNotification("Erreur de traitement des données", "error");
            }
        };

    } catch (error) {
        console.error("❌ Erreur lors de la création de la connexion WebSocket:", error);
        updateConnectionStatus(false);
        showNotification("Erreur de création de connexion", "error");
    }
}

// Fonction pour mettre à jour les valeurs des cartes avec animation améliorée
function updateCardValue(elementId, value, unit) {
    const element = document.getElementById(elementId);
    if (!element) {
        console.warn(`⚠️ Élément ${elementId} non trouvé`);
        return;
    }

    console.log(`📊 Mise à jour ${elementId}: ${value}${unit}`);

    // Animation de mise à jour avec effet de pulsation
    element.style.transform = 'scale(1.2)';
    element.style.color = '#00ff64';
    element.style.textShadow = '0 0 20px rgba(0, 255, 100, 0.8)';
    element.style.transition = 'all 0.2s ease';
    
    // Mise à jour de la valeur après l'animation
    setTimeout(() => {
        if (value === "0" || value === "non_disponible" || value === "" || value === null || value === undefined) {
            element.textContent = "--";
        } else {
            element.textContent = value;
        }
        element.style.transform = 'scale(1)';
        element.style.color = '';
        element.style.textShadow = '';
    }, 200);

    // Mise à jour du statut de la carte
    const card = element.closest('.data-card');
    if (card) {
        // Mise à jour du timestamp
        const cardFooter = card.querySelector('.last-update span');
        if (cardFooter) {
            const now = new Date();
            const timeString = now.toLocaleTimeString('fr-FR');
            cardFooter.textContent = `Mis à jour à ${timeString}`;
        }

        // Mise à jour de l'indicateur de tendance
        const trendIndicator = card.querySelector('.trend-indicator');
        if (trendIndicator) {
            if (value === "0" || value === "non_disponible" || value === "" || value === null || value === undefined) {
                trendIndicator.innerHTML = '<i class="fas fa-exclamation-circle"></i><span>Erreur</span>';
                trendIndicator.style.background = 'rgba(255, 0, 0, 0.1)';
                trendIndicator.style.color = '#ff0000';
            } else {
                // Indicateurs spécifiques selon le type de données
                if (elementId === 'data-validation' && value === '31052002') {
                    trendIndicator.innerHTML = '<i class="fas fa-shield-check"></i><span>Validé</span>';
                    trendIndicator.style.background = 'rgba(0, 255, 100, 0.1)';
                    trendIndicator.style.color = '#00ff64';
                } else if (elementId === 'data-validation') {
                    trendIndicator.innerHTML = '<i class="fas fa-clock"></i><span>En attente</span>';
                    trendIndicator.style.background = 'rgba(255, 255, 0, 0.1)';
                    trendIndicator.style.color = '#ffff00';
                } else {
                    trendIndicator.innerHTML = '<i class="fas fa-check"></i><span>Normal</span>';
                    trendIndicator.style.background = 'rgba(0, 255, 100, 0.1)';
                    trendIndicator.style.color = '#00ff64';
                }
            }
        }

        // Effet de pulsation sur la carte
        card.style.boxShadow = '0 20px 60px rgba(0, 255, 100, 0.4)';
        card.style.transform = 'translateY(-5px) scale(1.01)';
        setTimeout(() => {
            card.style.boxShadow = '';
            card.style.transform = '';
        }, 1000);
    }
}

// Fonction pour demander toutes les mesures
function getAllMesures() {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send("all-mesure");
        console.log("📤 Demande de toutes les mesures envoyée");
        return true;
    } else {
        console.warn("⚠️ WebSocket non connecté, impossible d'envoyer la requête");
        return false;
    }
}

// Fonction pour demander une mesure spécifique
function getMesure(type) {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(`get-${type}`);
        console.log(`📤 Demande de mesure ${type} envoyée`);
        return true;
    } else {
        console.warn("⚠️ WebSocket non connecté, impossible d'envoyer la requête");
        showNotification("Connexion requise pour obtenir les données", "warning");
        return false;
    }
}

// Fonction pour tester la connexion (ping)
function pingServer() {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send("ping");
        console.log("🏓 Ping envoyé au serveur");
        return true;
    }
    return false;
}

// Fonctions pour gérer les mises à jour automatiques
function startAutoUpdate() {
    console.log("⏰ Démarrage des mises à jour automatiques (toutes les 2 secondes)");
    
    // Arrêter toute mise à jour existante
    stopAutoUpdate();
    
    // Première mise à jour immédiate
    getAllMesures();
    
    // Mise à jour toutes les 2 secondes
    autoUpdateInterval = setInterval(() => {
        if (socket && socket.readyState === WebSocket.OPEN) {
            getAllMesures();
        } else {
            console.warn("⚠️ WebSocket fermé, arrêt des mises à jour automatiques");
            stopAutoUpdate();
        }
    }, 2000);
}

function stopAutoUpdate() {
    if (autoUpdateInterval) {
        console.log("⏸️ Arrêt des mises à jour automatiques");
        clearInterval(autoUpdateInterval);
        autoUpdateInterval = null;
    }
}

// Fonction pour réinitialiser la connexion
function resetConnection() {
    console.log("🔄 Réinitialisation de la connexion...");
    
    // Arrêter les mises à jour
    stopAutoUpdate();
    
    // Fermer la connexion existante
    if (socket) {
        socket.close(1000, "Reconnexion manuelle");
    }
    
    // Réinitialiser les tentatives
    reconnectAttempts = 0;
    
    // Nouvelle connexion après un court délai
    setTimeout(() => {
        connectWebSocket();
    }, 1000);
}

// Initialisation principale
document.addEventListener('DOMContentLoaded', () => {
    console.log("🚀 Initialisation de l'application MediSense Pro");
    
    // Afficher les informations de version
    console.log("📱 Version: 2.0 - WebSocket avec auto-reconnexion");
    console.log(`🌐 Serveur cible: ws://${ipAddress}:${port}`);
    
    // Connexion WebSocket initiale
    connectWebSocket();
    
    // Ping du serveur toutes les 30 secondes pour maintenir la connexion
    setInterval(() => {
        if (socket && socket.readyState === WebSocket.OPEN) {
            pingServer();
        }
    }, 30000);

    // Gestion des événements de clic sur les cartes
    document.querySelectorAll('.data-card').forEach(card => {
        card.addEventListener('click', (e) => {
            e.preventDefault();
            
            const title = card.querySelector('.card-title')?.textContent?.toLowerCase();
            if (!title) {
                console.warn("⚠️ Titre de carte non trouvé");
                return;
            }

            let type = '';
            switch(title) {
                case 'poids corporel':
                    type = 'poid';
                    break;
                case 'température':
                    type = 'temperature';
                    break;
                case 'taille':
                    type = 'taille';
                    break;
                case 'validation':
                    type = 'validation';
                    break;
                default:
                    console.warn(`⚠️ Type de carte non reconnu: ${title}`);
                    return;
            }
            
            if (getMesure(type)) {
                console.log(`🖱️ Mise à jour manuelle de ${title} demandée`);
                showNotification(`Mise à jour de ${title}`, "info", 1500);
            }
            
            // Effet visuel de clic
            card.style.transform = 'scale(0.98)';
            setTimeout(() => {
                card.style.transform = '';
            }, 150);
        });
    });

    // Gestion du clic sur le statut de connexion pour reconnexion manuelle
    const connectionStatus = document.querySelector('.connection-status');
    if (connectionStatus) {
        connectionStatus.addEventListener('click', () => {
            if (!socket || socket.readyState !== WebSocket.OPEN) {
                console.log("🔄 Reconnexion manuelle demandée");
                showNotification("Tentative de reconnexion...", "info");
                resetConnection();
            } else {
                console.log("ℹ️ Connexion déjà active");
                showNotification("Connexion déjà établie", "info", 1500);
            }
        });
        
        // Ajouter un curseur pointer pour indiquer que c'est cliquable
        connectionStatus.style.cursor = 'pointer';
        connectionStatus.title = 'Cliquer pour reconnecter si nécessaire';
    }

    // Gestion des raccourcis clavier
    document.addEventListener('keydown', (e) => {
        if (e.ctrlKey || e.metaKey) {
            switch(e.key) {
                case 'r':
                case 'R':
                    e.preventDefault();
                    console.log("⌨️ Raccourci: Reconnexion");
                    resetConnection();
                    break;
                case 'u':
                case 'U':
                    e.preventDefault();
                    console.log("⌨️ Raccourci: Mise à jour manuelle");
                    getAllMesures();
                    break;
            }
        }
    });

    console.log("✅ Initialisation terminée");
    console.log("🎮 Raccourcis: Ctrl+R (Reconnexion), Ctrl+U (Mise à jour)");
    console.log("🖱️ Cliquez sur les cartes pour une mise à jour manuelle");
    console.log("🔄 Cliquez sur le statut de connexion pour reconnecter");
});

// Nettoyage lors de la fermeture de la page
window.addEventListener('beforeunload', (e) => {
    console.log("🚪 Fermeture de la page détectée");
    stopAutoUpdate();
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.close(1000, "Page fermée");
    }
});

// Gestion de la visibilité de la page pour économiser les ressources
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        console.log("📱 Page masquée, ralentissement des mises à jour");
        stopAutoUpdate();
    } else {
        console.log("📱 Page visible, reprise des mises à jour normales");
        if (socket && socket.readyState === WebSocket.OPEN) {
            startAutoUpdate();
        }
    }
});

// Gestion des erreurs globales JavaScript
window.addEventListener('error', (e) => {
    console.error("❌ Erreur JavaScript globale:", e.error);
    showNotification("Erreur application détectée", "error");
});

// Gestion des erreurs de promesse non gérées
window.addEventListener('unhandledrejection', (e) => {
    console.error("❌ Promesse rejetée non gérée:", e.reason);
    e.preventDefault(); // Empêche l'affichage de l'erreur dans la console
});

// Exposer quelques fonctions pour le debug en console
window.MediSense = {
    reconnect: resetConnection,
    getData: getAllMesures,
    getSpecific: getMesure,
    ping: pingServer,
    status: () => {
        return {
            socketState: socket ? socket.readyState : 'Non initialisé',
            reconnectAttempts: reconnectAttempts,
            autoUpdateActive: !!autoUpdateInterval
        };
    }
};

console.log("🔧 Interface de debug disponible: window.MediSense");