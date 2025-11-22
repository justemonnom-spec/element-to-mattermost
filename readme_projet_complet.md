# 🚀 Element.io → Mattermost - Système d'Import Complet

**Version 2.0 - Novembre 2025**

Système complet pour migrer vos conversations Element.io (Matrix) vers Mattermost, avec interface web et ligne de commande.

---

## 📦 Composants du projet

### 1. **Scripts d'import** (CLI)
- `element_to_mattermost.py` - Convertisseur Python (Element JSON → Mattermost JSONL)
- `element-import.sh` - Script Bash d'orchestration
- `test_installation.sh` - Tests automatisés

### 2. **Interface Web** (optionnel)
- `element_import_web.py` - Application Flask avec interface moderne
- Configuration Nginx/Apache
- Service systemd

### 3. **Documentation**
- `GUIDE_INSTALLATION.md` - Installation et utilisation CLI
- `GUIDE_INTERFACE_WEB.md` - Installation interface web
- `GUIDE_UTILISATEUR.md` - Guide pour utilisateurs finaux

---

## ✨ Fonctionnalités

### Import automatique
✅ Création automatique des utilisateurs, équipes et canaux  
✅ Support des threads et réponses  
✅ Import des fichiers/images attachés  
✅ Détection automatique des canaux privés/publics  
✅ Préservation des timestamps  
✅ Suivi en temps réel de la progression  

### Interface Web
✅ Upload drag & drop  
✅ Barre de progression animée  
✅ Logs en temps réel (style terminal)  
✅ Statistiques détaillées (utilisateurs, messages, threads, fichiers)  
✅ Responsive design  
✅ Aucune dépendance externe lourde  

---

## 🎯 Installation rapide

### Prérequis
- **Mattermost** 5.12+ installé
- **mmctl** configuré
- **Python** 3.7+
- **Utilisateur mattermost** avec permissions

### Installation en 3 commandes

```bash
# 1. Créer les dossiers
sudo mkdir -p /opt/mattermost/scripts /var/log/mattermost
sudo chown -R mattermost:mattermost /opt/mattermost/scripts /var/log/mattermost

# 2. Copier les scripts (adapter les chemins)
sudo cp element_to_mattermost.py element-import.sh /opt/mattermost/scripts/
sudo chmod 750 /opt/mattermost/scripts/*.{sh,py}

# 3. Tester
sudo -u mattermost /opt/mattermost/scripts/test_installation.sh
```

---

## 📖 Utilisation

### CLI (Ligne de commande)

```bash
# Se connecter en tant que mattermost
sudo -i -u mattermost

# Import simple
cd /opt/mattermost/scripts
./element-import.sh --team mon-equipe /tmp/export.json

# Avec médias
./element-import.sh --team mon-equipe --data-dir /tmp/media /tmp/export.json

# Avec mot de passe personnalisé
./element-import.sh --team mon-equipe --password "Welcome2024!" /tmp/export.json
```

### Interface Web

1. **Installer l'interface :**
   ```bash
   sudo -u mattermost pip3 install flask
   # Suivre GUIDE_INTERFACE_WEB.md
   ```

2. **Accéder à l'interface :**
   ```
   http://votre-serveur:8080
   ```

3. **Utiliser :**
   - Glisser-déposer votre fichier JSON
   - Configurer l'équipe
   - Lancer l'import
   - Suivre la progression

---

## 📊 Architecture technique

```
┌─────────────────────────────────────────────────────────┐
│                  Interface Utilisateur                  │
├──────────────────────┬──────────────────────────────────┤
│   Interface Web      │   Ligne de commande (CLI)        │
│   (Flask + Nginx)    │   (Bash)                         │
└──────────┬───────────┴──────────────┬───────────────────┘
           │                          │
           └────────┬─────────────────┘
                    │
           ┌────────▼─────────┐
           │  element-import  │  Script Bash principal
           │      .sh         │  (orchestration)
           └────────┬─────────┘
                    │
           ┌────────▼──────────────┐
           │ element_to_mattermost │  Conversion Python
           │       .py              │  (Element → JSONL)
           └────────┬──────────────┘
                    │
           ┌────────▼─────────┐
           │  Archive ZIP     │
           │  (JSONL + files) │
           └────────┬─────────┘
                    │
           ┌────────▼─────────┐
           │      mmctl       │  Import Mattermost
           │  (--bypass-      │  (bulk loading)
           │    upload)       │
           └────────┬─────────┘
                    │
           ┌────────▼─────────┐
           │   Mattermost     │
           │   Database       │
           └──────────────────┘
```

---

## 🗂️ Structure des fichiers

```
/opt/mattermost/scripts/
├── element_to_mattermost.py    # Convertisseur Python
├── element-import.sh            # Script principal
├── element_import_web.py        # Interface web (optionnel)
└── test_installation.sh         # Tests

/var/log/mattermost/
└── element_import.log           # Logs d'import

/tmp/mattermost_import_*/        # Fichiers temporaires
└── (auto-nettoyés)

/tmp/mattermost_web_imports/     # Uploads web
└── (jobs d'import)

/etc/systemd/system/
└── element-import-web.service   # Service web

/etc/nginx/sites-available/
└── element-import               # Config Nginx
```

---

## 🔒 Sécurité

### Bonnes pratiques implémentées

✅ Exécution en tant qu'utilisateur `mattermost` (pas root)  
✅ Permissions restrictives (750 pour scripts)  
✅ Pas de stockage de mots de passe en clair  
✅ Nettoyage automatique des fichiers temporaires  
✅ Support HTTPS pour l'interface web  
✅ Headers de sécurité (X-Frame-Options, etc.)  
✅ Validation des entrées utilisateur  
✅ Logs auditables  

### Configuration recommandée

```bash
# Permissions
sudo chown -R mattermost:mattermost /opt/mattermost/scripts
sudo chmod 750 /opt/mattermost/scripts/*.sh
sudo chmod 750 /opt/mattermost/scripts/*.py

# Firewall (si interface web)
sudo ufw allow from 192.168.1.0/24 to any port 8080
```

---

## 🧪 Tests

### Test automatique complet

```bash
sudo -u mattermost /opt/mattermost/scripts/test_installation.sh
```

Le script teste :
- Système et dépendances
- Fichiers et permissions
- Configuration mmctl
- Conversion fonctionnelle
- Interface web (si installée)
- Sécurité

### Test manuel simple

```bash
# Créer un fichier de test
cat > /tmp/test.json << 'EOF'
{
  "room_name": "Test",
  "events": [{
    "type": "m.room.message",
    "sender": "@test:matrix.org",
    "content": {"msgtype": "m.text", "body": "Test"},
    "origin_server_ts": 1234567890000,
    "event_id": "$test123"
  }]
}
EOF

# Tester la conversion
./element-import.sh --team test-team --no-import /tmp/test.json
```

---

## 📈 Performances

### Capacités testées

| Taille | Messages | Utilisateurs | Temps | Recommandation |
|--------|----------|--------------|-------|----------------|
| Petit | < 1K | < 10 | 1-2 min | Direct |
| Moyen | 1K-10K | 10-50 | 5-15 min | Direct |
| Grand | 10K-50K | 50-200 | 15-60 min | Désactiver Bleve |
| Très grand | > 50K | > 200 | > 1h | Import par lots |

### Optimisations

```bash
# Pour gros volumes (> 50K messages)
# 1. Désactiver l'indexation Bleve temporairement
# Console Système > Expérimental > Bleve > Désactiver

# 2. Augmenter les ressources serveur si possible

# 3. Importer en plusieurs fois
./element-import.sh --team myteam part1.json
sleep 60
./element-import.sh --team myteam part2.json
```

---

## 🐛 Dépannage

### Problèmes courants

| Problème | Cause | Solution |
|----------|-------|----------|
| "mattermost is not in the sudoers file" | Utilisation de sudo | Ne PAS utiliser sudo |
| "mmctl: command not found" | mmctl pas installé | Installer mmctl |
| "unknown flag: --validate" | Ancienne version script | Utiliser --bypass-upload |
| Messages non visibles | Import silencieux | Vérifier les logs |
| "Permission denied" | Mauvaises permissions | chown mattermost:mattermost |

### Logs à consulter

```bash
# Import CLI
tail -f /var/log/mattermost/element_import.log

# Mattermost général
tail -f /opt/mattermost/logs/mattermost.log

# Interface web
sudo journalctl -u element-import-web -f

# Nginx
tail -f /var/log/nginx/element-import-error.log
```

---

## 📚 Documentation complète

1. **GUIDE_INSTALLATION.md** - Installation et utilisation CLI
2. **GUIDE_INTERFACE_WEB.md** - Installation interface web
3. **GUIDE_UTILISATEUR.md** - Guide pour utilisateurs finaux
4. **Ce README** - Vue d'ensemble du projet

---

## 🔄 Mises à jour

### Vérifier la version

```bash
head -1 /opt/mattermost/scripts/element-import.sh | grep Version
# Version 2.0
```

### Mettre à jour

```bash
# Sauvegarder l'ancien
sudo cp /opt/mattermost/scripts/element-import.sh{,.backup}

# Copier la nouvelle version
sudo cp element-import.sh /opt/mattermost/scripts/
sudo chown mattermost:mattermost /opt/mattermost/scripts/element-import.sh
sudo chmod 750 /opt/mattermost/scripts/element-import.sh

# Tester
sudo -u mattermost /opt/mattermost/scripts/test_installation.sh
```

---

## 🤝 Contribution

### Signaler un bug

1. Consulter les logs
2. Exécuter le script de tests
3. Créer un rapport avec :
   - Version de Mattermost
   - Version du script
   - Logs d'erreur
   - Étapes pour reproduire

### Proposer une amélioration

Les contributions sont bienvenues ! Domaines d'amélioration :
- Support des réactions emoji
- Interface web : authentification avancée
- Import incrémental
- Support de plusieurs salons en parallèle
- Export direct depuis Element (API)

---

## 📄 Licence

MIT License - Libre d'utilisation, modification et distribution.

---

## 🎉 Remerciements

- Équipe Mattermost pour l'API de bulk import
- Communauté Element.io / Matrix
- Contributeurs et testeurs

---

## 📞 Support et ressources

### Documentation officielle
- [Mattermost Bulk Loading](https://docs.mattermost.com/onboard/bulk-loading-data.html)
- [mmctl Documentation](https://docs.mattermost.com/manage/mmctl-command-line-tool.html)
- [Matrix/Element API](https://matrix.org/docs/api/)

### Liens utiles
- Forum Mattermost : https://forum.mattermost.com/
- GitHub Mattermost : https://github.com/mattermost/
- Documentation Matrix : https://matrix.org/docs/

---

## ✅ Checklist de déploiement

Installation :
- [ ] Scripts copiés dans `/opt/mattermost/scripts/`
- [ ] Permissions correctes (mattermost:mattermost, 750)
- [ ] mmctl installé et mode local activé
- [ ] Python 3.7+ installé
- [ ] Tests réussis (`test_installation.sh`)

Optionnel - Interface web :
- [ ] Flask installé
- [ ] Service systemd actif
- [ ] Nginx/Apache configuré
- [ ] HTTPS activé (production)
- [ ] Page accessible dans navigateur

Documentation :
- [ ] Guides distribués aux administrateurs
- [ ] Guide utilisateur envoyé aux utilisateurs
- [ ] Procédure de première connexion expliquée

Production :
- [ ] Test d'import réussi avec vraies données
- [ ] Backup des scripts créé
- [ ] Monitoring activé
- [ ] Procédure de rollback documentée

---

**Dernière mise à jour :** Novembre 2025  
**Version :** 2.0  
**Auteur :** Projet Element → Mattermost  
**Statut :** Production Ready ✅
