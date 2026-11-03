#!/usr/bin/env bash
#
# Jenkins install/cleanup script for Ubuntu/Debian VMs.
#
# Usage:
#   ./install_jenkins.sh install   # clean any previous/broken install, then install Jenkins
#   ./install_jenkins.sh cleanup   # fully remove Jenkins and its dependencies from the VM
#   ./install_jenkins.sh status    # show service status + initial admin password (if present)
#
set -euo pipefail

JENKINS_PORT="${JENKINS_PORT:-8080}"
# Jenkins requires Java 21+ to run the controller (Java 17 is no longer supported).
REQUIRED_JAVA_PKG="openjdk-21-jdk"
# Jenkins rotates this signing key yearly - if apt-get update fails with
# "NO_PUBKEY" or "repository is not signed", check https://pkg.jenkins.io/debian-stable/
# for the current key filename and update this URL.
JENKINS_REPO_KEY_URL="https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key"
JENKINS_REPO_LINE="deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/"
JENKINS_KEYRING="/usr/share/keyrings/jenkins-keyring.asc"
JENKINS_SOURCES_LIST="/etc/apt/sources.list.d/jenkins.list"

log()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        err "Please run this script as root (sudo ./install_jenkins.sh $1)."
        exit 1
    fi
}

cleanup_jenkins() {
    log "Stopping Jenkins service (if running)..."
    systemctl stop jenkins 2>/dev/null || true
    systemctl disable jenkins 2>/dev/null || true

    log "Removing Jenkins package..."
    apt-get remove --purge -y jenkins 2>/dev/null || true

    log "Removing Jenkins repo and keyring..."
    rm -f "$JENKINS_SOURCES_LIST"
    rm -f "$JENKINS_KEYRING"

    log "Removing Jenkins data and config directories..."
    rm -rf /var/lib/jenkins
    rm -rf /var/cache/jenkins
    rm -rf /var/log/jenkins
    rm -rf /etc/default/jenkins
    rm -rf /etc/sysconfig/jenkins

    log "Removing jenkins system user/group (if present)..."
    userdel jenkins 2>/dev/null || true
    groupdel jenkins 2>/dev/null || true

    log "Cleaning up apt cache..."
    apt-get autoremove -y 2>/dev/null || true
    apt-get clean

    log "Cleanup complete."
}

install_java() {
    if dpkg -l | grep -q "$REQUIRED_JAVA_PKG"; then
        log "Java ($REQUIRED_JAVA_PKG) already installed."
    else
        log "Installing Java ($REQUIRED_JAVA_PKG)..."
        apt-get install -y "$REQUIRED_JAVA_PKG"
    fi
}

install_jenkins() {
    log "Updating apt package index..."
    apt-get update -y

    log "Installing prerequisites (curl, gnupg, ca-certificates)..."
    apt-get install -y curl gnupg ca-certificates

    install_java

    log "Adding Jenkins apt repository key..."
    mkdir -p "$(dirname "$JENKINS_KEYRING")"
    curl -fsSL "$JENKINS_REPO_KEY_URL" | tee "$JENKINS_KEYRING" > /dev/null

    log "Adding Jenkins apt repository..."
    echo "$JENKINS_REPO_LINE" | tee "$JENKINS_SOURCES_LIST" > /dev/null

    log "Updating apt package index again (with Jenkins repo)..."
    apt-get update -y

    log "Installing Jenkins..."
    apt-get install -y jenkins

    log "Enabling and starting Jenkins service..."
    systemctl enable jenkins
    systemctl start jenkins

    log "Waiting for Jenkins to come up on port $JENKINS_PORT..."
    for i in $(seq 1 30); do
        if curl -s -o /dev/null "http://localhost:${JENKINS_PORT}"; then
            break
        fi
        sleep 2
    done

    show_status
}

show_status() {
    log "Jenkins service status:"
    systemctl status jenkins --no-pager || true

    if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
        log "Initial admin password:"
        cat /var/lib/jenkins/secrets/initialAdminPassword
    else
        warn "Initial admin password file not found (Jenkins may already be configured, or not finished starting)."
    fi

    log "Open Jenkins at: http://<vm-ip>:${JENKINS_PORT}"
}

main() {
    local action="${1:-}"

    case "$action" in
        install)
            require_root install
            warn "Running cleanup first to remove any previous/broken Jenkins install..."
            cleanup_jenkins
            install_jenkins
            ;;
        cleanup)
            require_root cleanup
            cleanup_jenkins
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {install|cleanup|status}"
            exit 1
            ;;
    esac
}

main "$@"
