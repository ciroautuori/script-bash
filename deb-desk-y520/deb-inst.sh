#!/bin/bash

# Exit on error and undefined variables
# Imposta lo script per uscire in caso di errore o variabili non definite
set -eu

# Colors for output
# Definisce i colori per l'output
RED='\033[0;31m'       # Rosso
GREEN='\033[0;32m'     # Verde
NC='\033[0m'           # Nessun colore (reset)

# Logging function
# Funzione per loggare messaggi di stato
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"  # Stampa un messaggio con la data e l'ora
}

# Error function
# Funzione per loggare errori e fermare lo script
error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2   # Stampa l'errore in rosso
    exit 1  # Esce dallo script con stato di errore
}

# Check if running as root
# Controlla se lo script è eseguito come root
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root"  # Mostra errore e termina se non è root
fi

# Backup sources.list
# Fa una copia di backup del file sources.list
log "Backing up sources.list..."
cp /etc/apt/sources.list /etc/apt/sources.list.backup  # Copia il file delle sorgenti APT

# Update system
# Esegue l'aggiornamento del sistema
log "Updating package lists..."
apt update || error "Failed to update package lists"  # Aggiorna la lista dei pacchetti
apt upgrade -y || error "Failed to upgrade packages"   # Esegue l'upgrade dei pacchetti

# Install essential packages
# Installa pacchetti di base essenziali
log "Installing base system packages..."
BASE_PACKAGES=(   # Definisce un array con i pacchetti di base da installare
    sudo
    htop
    curl
    wget
    ufw
    gnupg
    apt-transport-https
    ca-certificates
    lsb-release
    software-properties-common
    debian-archive-keyring
)

apt install -y "${BASE_PACKAGES[@]}" || error "Failed to install base packages"  # Installa i pacchetti definiti

# Install desktop environment with minimal recommendations
# Installa l'ambiente desktop con raccomandazioni minime
log "Installing desktop environment..."
DESKTOP_PACKAGES=(  # Array con i pacchetti per l'ambiente desktop
    xorg
    xfce4
    xfce4-goodies
    lightdm
    lightdm-gtk-greeter
)

apt install -y --no-install-recommends "${DESKTOP_PACKAGES[@]}" || error "Failed to install desktop packages"  # Installa i pacchetti senza raccomandazioni aggiuntive

# Install NVIDIA drivers if needed
# Installa i driver NVIDIA se necessario
if lspci | grep -i nvidia > /dev/null; then   # Controlla se c'è una GPU NVIDIA
    log "NVIDIA card detected, installing drivers..."
    apt install -y nvidia-driver nvidia-kernel-dkms nvidia-kernel-source || error "Failed to install NVIDIA drivers"  # Installa i driver NVIDIA
fi

# Install additional utilities
# Installa pacchetti utili aggiuntivi
log "Installing additional utilities..."
UTILITY_PACKAGES=(  # Array con i pacchetti aggiuntivi
    gnome-disk-utility
    neofetch
    powertop
    firefox-esr
    git
    mousepad
    network-manager-gnome
    firmware-iwlwifi
    iw
    pavucontrol
    python3
    python3-pip
    gnome-screenshot
    arc-theme
    faenza-icon-theme
    ffmpeg
    synaptic
    gstreamer1.0-libav
    bleachbit
    timeshift
    xdg-utils 
    xarchiver   
    tlp
    gvfs 
    gvfs-backends 
    gvfs-daemons 
    gvfs-fuse 
)

apt install -y "${UTILITY_PACKAGES[@]}" || error "Failed to install utility packages"  # Installa i pacchetti aggiuntivi

# Install and configure Docker
# Installa e configura Docker
install_docker() {
    log "Installing Docker..."
    
    # Ensure ciroautuori is in sudo group
    log "Adding ciroautuori to sudo group..."
    adduser ciroautuori sudo || error "Failed to add ciroautuori to sudo group"
    
    if ! command -v docker &> /dev/null; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error "Failed to install Docker"
        
        # Add ciroautuori to docker group
        usermod -aG docker ciroautuori || error "Failed to add ciroautuori to docker group"
        log "User ciroautuori added to docker group"
        
        # Notify about logout requirement
        log "Please logout and login again for docker group changes to take effect"
    else
        log "Docker is already installed"
        # Ensure user is in docker group even if Docker was already installed
        usermod -aG docker ciroautuori || error "Failed to add ciroautuori to docker group"
    fi
}
# Install Node.js
# Installa Node.js
install_nodejs() {
    log "Installing Node.js..."
    if ! command -v node &> /dev/null; then  # Verifica se Node.js è già installato
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -  # Scarica e installa il setup per Node.js 20.x
        apt install -y nodejs || error "Failed to install Node.js"  # Installa Node.js
    else
        log "Node.js is already installed"  # Se Node.js è già installato, mostra un messaggio
    fi
}

# Install and configure system tools
# Installa e configura Docker e Node.js
install_docker
install_nodejs

# Configure LightDM
# Configura LightDM (gestore di accesso)
log "Configuring LightDM..."
sed -i 's/#greeter-show-power=false/greeter-show-power=true/' /etc/lightdm/lightdm.conf  # Modifica il file di configurazione di LightDM
systemctl enable lightdm || error "Failed to enable LightDM"  # Abilita LightDM all'avvio

# Restart network manager
# Riavvia il gestore di rete
log "Restarting NetworkManager..."
systemctl restart NetworkManager || error "Failed to restart NetworkManager"  # Riavvia NetworkManager per applicare eventuali modifiche

# Final system update
# Esegui un ultimo aggiornamento del sistema
log "Performing final system update..."
apt update && apt upgrade -y || error "Failed to perform final system update"  # Aggiorna i pacchetti per l'ultima volta

# Clean up
# Pulisce i pacchetti inutilizzati
log "Cleaning up..."
apt autoremove -y  # Rimuove pacchetti non più necessari
apt clean  # Pulisce la cache di apt

# Create success file
# Crea un file che indica che l'installazione è completa
touch /root/.debian_setup_complete

log "Installation completed successfully!"  # Mostra il messaggio di successo
log "System will reboot in 10 seconds..."  # Messaggio prima del riavvio
sleep 10  # Attende 10 secondi
reboot  # Riavvia il sistema
