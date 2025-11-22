# Guide d'Installation - Interface Web Element Import

## 🌐 Vue d'ensemble

L'interface web permet d'importer des conversations Element.io vers Mattermost via un navigateur, sans utiliser la ligne de commande.

**Fonctionnalités:**
- ✅ Upload drag & drop de fichiers JSON
- ✅ Suivi en temps réel de la progression
- ✅ Logs détaillés dans le navigateur
- ✅ Statistiques d'import (utilisateurs, messages, threads, fichiers)
- ✅ Interface moderne et responsive
- ✅ Aucune dépendance externe (tout en un fichier)

---

## 📋 Prérequis

### Système
- **Serveur Mattermost** déjà installé
- **Scripts d'import** installés (`element_to_mattermost.py` et `element-import.sh`)
- **Python 3.7+** avec pip

### Logiciels
- **Flask** (installé automatiquement)
- **Nginx** OU **Apache** (au choix)

---

## 🚀 Installation rapide (5 minutes)

### Étape 1 : Installer Flask

```bash
# En tant que root
sudo -i -u mattermost pip3 install flask werkzeug

# Vérifier l'installation
python3 -c "import flask; print(flask.__version__)"
```

### Étape 2 : Copier le fichier Python

```bash
# Depuis votre machine locale
scp element_import_web.py root@serveur:/opt/mattermost/scripts/

# Sur le serveur
sudo chown mattermost:mattermost /opt/mattermost/scripts/element_import_web.py
sudo chmod 750 /opt/mattermost/scripts/element_import_web.py
```

### Étape 3 : Créer les dossiers

```bash
# Dossier pour uploads temporaires
sudo mkdir -p /tmp/mattermost_web_imports
sudo chown mattermost:mattermost /tmp/mattermost_web_imports
sudo chmod 750 /tmp/mattermost_web_imports
```

### Étape 4 : Créer le service systemd

```bash
# Créer le fichier service
sudo nano /etc/systemd/system/element-import-web.service
```

Contenu :

```ini
[Unit]
Description=Element.io to Mattermost Import Web Interface
After=network.target mattermost.service

[Service]
Type=simple
User=mattermost
Group=mattermost
WorkingDirectory=/opt/mattermost/scripts
Environment="MMCTL_LOCAL=true"
Environment="FLASK_APP=/opt/mattermost/scripts/element_import_web.py"
ExecStart=/usr/bin/python3 /opt/mattermost/scripts/element_import_web.py
Restart=on-failure
RestartSec=10

# Sécurité
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp/mattermost_web_imports /var/log/mattermost

[Install]
WantedBy=multi-user.target
```

Activer le service :

```bash
sudo systemctl daemon-reload
sudo systemctl enable element-import-web
sudo systemctl start element-import-web

# Vérifier le statut
sudo systemctl status element-import-web
```

### Étape 5 : Configurer le proxy (Nginx OU Apache)

#### Option A : Nginx (recommandé)

```bash
# Créer la configuration
sudo nano /etc/nginx/sites-available/element-import
```

Contenu :

```nginx
server {
    listen 8080;
    server_name _;
    
    access_log /var/log/nginx/element-import-access.log;
    error_log /var/log/nginx/element-import-error.log;
    
    # Uploads volumineux
    client_max_body_size 500M;
    client_body_timeout 300s;
    proxy_read_timeout 600s;
    proxy_connect_timeout 600s;
    proxy_send_timeout 600s;
    
    # Headers de sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Activer :

```bash
# Lien symbolique
sudo ln -s /etc/nginx/sites-available/element-import /etc/nginx/sites-enabled/

# Tester la configuration
sudo nginx -t

# Recharger
sudo systemctl reload nginx
```

#### Option B : Apache

```bash
# Activer les modules nécessaires
sudo a2enmod proxy proxy_http headers

# Créer la configuration
sudo nano /etc/apache2/sites-available/element-import.conf
```

Contenu :

```apache
<VirtualHost *:8080>
    ServerName votre-serveur.com
    ServerAdmin admin@votre-serveur.com
    
    ErrorLog ${APACHE_LOG_DIR}/element-import-error.log
    CustomLog ${APACHE_LOG_DIR}/element-import-access.log combined
    
    # Proxy vers Flask
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:5000/
    ProxyPassReverse / http://127.0.0.1:5000/
    
    # Timeouts
    ProxyTimeout 600
    Timeout 600
    
    # Taille max upload (500 MB)
    LimitRequestBody 524288000
    
    # Headers de sécurité
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
</VirtualHost>

# Ajouter le port 8080 si nécessaire
Listen 8080
```

Activer :

```bash
# Activer le site
sudo a2ensite element-import

# Tester la configuration
sudo apache2ctl configtest

# Recharger
sudo systemctl reload apache2
```

---

## ✅ Vérification de l'installation

### Test 1 : Service Flask

```bash
# Vérifier que le service tourne
sudo systemctl status element-import-web

# Devrait afficher: Active: active (running)
```

### Test 2 : Port Flask (5000)

```bash
# Tester la connexion directe
curl http://127.0.0.1:5000

# Devrait retourner du HTML
```

### Test 3 : Proxy web (8080)

```bash
# Tester via le proxy
curl http://127.0.0.1:8080

# Devrait retourner le même HTML
```

### Test 4 : Accès depuis le navigateur

Ouvrir dans votre navigateur :
```
http://votre-serveur:8080
```

Vous devriez voir l'interface avec :
- Header violet avec le titre
- 3 étapes numérotées
- Zone de drag & drop pour les fichiers

---

## 🎯 Utilisation de l'interface

### 1. Accéder à l'interface

```
http://votre-serveur-mattermost:8080
```

### 2. Configuration

- **Nom de l'équipe** : Saisir le nom (ex: `mon-equipe`)
- **Mot de passe** : Optionnel (défaut: `ChangeMe123!`)

### 3. Upload du fichier

**Méthode 1 : Drag & Drop**
- Glisser-déposer votre `export.json` Element.io dans la zone

**Méthode 2 : Bouton parcourir**
- Cliquer sur "Parcourir les fichiers"
- Sélectionner votre fichier

### 4. Lancer l'import

- Cliquer sur "🚀 Démarrer l'import"
- Suivre la progression en temps réel

### 5. Suivre l'avancement

L'interface affiche :
- **Barre de progression** (0-100%)
- **Statut textuel** (Upload → Conversion → Import → Terminé)
- **Logs en temps réel** (fond noir, style terminal)
- **Statistiques** (utilisateurs, messages, threads, fichiers)

### 6. Résultat

Une fois terminé, vous verrez :
- ✅ Message de succès en vert
- 📊 Statistiques complètes
- Instructions pour se connecter

---

## 🔧 Configuration avancée

### Changer le port Flask

Éditer `/opt/mattermost/scripts/element_import_web.py` :

```python
# Ligne finale
app.run(host='0.0.0.0', port=5555, debug=False)  # Port 5555 au lieu de 5000
```

Puis redémarrer :

```bash
sudo systemctl restart element-import-web
```

N'oubliez pas de mettre à jour la config Nginx/Apache !

### Activer HTTPS (recommandé en production)

#### Avec Nginx + Let's Encrypt

```bash
# Installer certbot
sudo apt install certbot python3-certbot-nginx

# Obtenir un certificat
sudo certbot --nginx -d import.votre-domaine.com

# Certbot configure automatiquement Nginx
```

Modifier `/etc/nginx/sites-available/element-import` :

```nginx
server {
    listen 443 ssl http2;
    server_name import.votre-domaine.com;
    
    ssl_certificate /etc/letsencrypt/live/import.votre-domaine.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/import.votre-domaine.com/privkey.pem;
    
    # ... reste de la config
}

# Redirection HTTP → HTTPS
server {
    listen 80;
    server_name import.votre-domaine.com;
    return 301 https://$server_name$request_uri;
}
```

### Limiter l'accès par IP

Dans Nginx :

```nginx
location / {
    # Autoriser uniquement le réseau local
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;
    
    proxy_pass http://127.0.0.1:5000;
    # ... reste de la config
}
```

### Authentification basique

Dans Nginx :

```bash
# Créer le fichier de mots de passe
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Ajouter dans la config Nginx
auth_basic "Restricted Access";
auth_basic_user_file /etc/nginx/.htpasswd;
```

---

## 📊 Monitoring et logs

### Logs du service Flask

```bash
# Logs systemd
sudo journalctl -u element-import-web -f

# Voir les dernières erreurs
sudo journalctl -u element-import-web -p err -n 50
```

### Logs Nginx

```bash
# Accès
sudo tail -f /var/log/nginx/element-import-access.log

# Erreurs
sudo tail -f /var/log/nginx/element-import-error.log
```

### Logs Apache

```bash
# Accès
sudo tail -f /var/log/apache2/element-import-access.log

# Erreurs
sudo tail -f /var/log/apache2/element-import-error.log
```

### Statistiques d'utilisation

```bash
# Compter les imports
sudo journalctl -u element-import-web | grep "Job créé" | wc -l

# Derniers imports
sudo journalctl -u element-import-web | grep "Job créé" | tail -10
```

---

## ❌ Dépannage

### Problème : Service ne démarre pas

**Vérifier les logs :**

```bash
sudo journalctl -u element-import-web -n 50
```

**Causes courantes :**
- Flask non installé : `pip3 install flask`
- Port 5000 déjà utilisé : changer le port dans le script
- Permissions : vérifier `chown mattermost:mattermost`

### Problème : Page blanche dans le navigateur

**Vérifier :**

```bash
# Flask tourne ?
curl http://127.0.0.1:5000

# Nginx/Apache tourne ?
sudo systemctl status nginx
# ou
sudo systemctl status apache2

# Configuration valide ?
sudo nginx -t
# ou
sudo apache2ctl configtest
```

### Problème : Upload échoue (413 Request Entity Too Large)

**Augmenter la limite dans Nginx :**

```nginx
client_max_body_size 1000M;  # 1 GB
```

Recharger : `sudo systemctl reload nginx`

### Problème : Import bloque à 60%

**Cause :** Import Mattermost en cours.

**Solution :**
- Consulter les logs Mattermost : `tail -f /opt/mattermost/logs/mattermost.log`
- Vérifier l'espace disque : `df -h`
- Vérifier les processus : `ps aux | grep mmctl`

### Problème : Cannot import name 'Flask'

**Cause :** Flask mal installé.

**Solution :**

```bash
# Réinstaller Flask pour l'utilisateur mattermost
sudo -i -u mattermost
pip3 install --upgrade --force-reinstall flask werkzeug
```

---

## 🔒 Sécurité

### Checklist de sécurité

- [ ] Service tourne en tant que `mattermost` (pas root)
- [ ] HTTPS activé (Let's Encrypt)
- [ ] Authentification basique ou restriction IP
- [ ] Firewall configuré (port 8080 uniquement depuis IP autorisées)
- [ ] Logs régulièrement consultés
- [ ] Mises à jour système automatiques
- [ ] Backup de `/opt/mattermost/scripts`

### Commandes firewall (ufw)

```bash
# Autoriser uniquement depuis IP spécifique
sudo ufw allow from 192.168.1.0/24 to any port 8080

# Ou autoriser globalement (moins sécurisé)
sudo ufw allow 8080/tcp
```

---

## 🎬 Script d'installation automatique

Créer `install_web_interface.sh` :

```bash
#!/bin/bash
set -e

echo "Installation de l'interface web Element Import..."

# 1. Installer Flask
sudo -u mattermost pip3 install flask werkzeug

# 2. Copier le fichier (à adapter)
sudo cp element_import_web.py /opt/mattermost/scripts/
sudo chown mattermost:mattermost /opt/mattermost/scripts/element_import_web.py
sudo chmod 750 /opt/mattermost/scripts/element_import_web.py

# 3. Créer les dossiers
sudo mkdir -p /tmp/mattermost_web_imports
sudo chown mattermost:mattermost /tmp/mattermost_web_imports

# 4. Service systemd
sudo tee /etc/systemd/system/element-import-web.service > /dev/null << 'EOF'
[Unit]
Description=Element Import Web Interface
After=network.target

[Service]
Type=simple
User=mattermost
Group=mattermost
WorkingDirectory=/opt/mattermost/scripts
Environment="MMCTL_LOCAL=true"
ExecStart=/usr/bin/python3 /opt/mattermost/scripts/element_import_web.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable element-import-web
sudo systemctl start element-import-web

# 5. Nginx
sudo tee /etc/nginx/sites-available/element-import > /dev/null << 'EOF'
server {
    listen 8080;
    server_name _;
    client_max_body_size 500M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/element-import /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "✅ Installation terminée!"
echo "Interface disponible: http://$(hostname -I | cut -d' ' -f1):8080"
```

Exécution :

```bash
chmod +x install_web_interface.sh
sudo ./install_web_interface.sh
```

---

## ✅ Checklist finale

Installation :
- [ ] Flask installé
- [ ] Script Python copié et permissions OK
- [ ] Dossier uploads créé
- [ ] Service systemd actif
- [ ] Nginx/Apache configuré et actif
- [ ] Page accessible dans le navigateur

Sécurité :
- [ ] HTTPS activé (production)
- [ ] Authentification configurée (optionnel)
- [ ] Firewall configuré
- [ ] Logs consultables

Tests :
- [ ] Upload d'un petit fichier JSON fonctionne
- [ ] Import se termine avec succès
- [ ] Statistiques s'affichent
- [ ] Messages visibles dans Mattermost

---

## 📞 Support

**Logs à consulter en cas de problème :**

```bash
# Service Flask
sudo journalctl -u element-import-web -f

# Nginx
sudo tail -f /var/log/nginx/element-import-error.log

# Mattermost
sudo tail -f /opt/mattermost/logs/mattermost.log
```

---

*Dernière mise à jour : Novembre 2025*  
*Version : 2.0*  
*Licence : MIT*
