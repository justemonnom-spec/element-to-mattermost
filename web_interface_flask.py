#!/usr/bin/env python3
"""
Interface Web pour l'import Element.io → Mattermost
Framework: Flask
Port: 5000 (configurable)
"""

import os
import json
import subprocess
import uuid
from datetime import datetime
from pathlib import Path
from flask import Flask, render_template_string, request, jsonify, send_file
from werkzeug.utils import secure_filename
import threading
import time

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024  # 500MB max
app.config['UPLOAD_FOLDER'] = '/tmp/mattermost_web_imports'
app.config['SECRET_KEY'] = os.urandom(24)

# Dossier de travail
UPLOAD_FOLDER = Path(app.config['UPLOAD_FOLDER'])
UPLOAD_FOLDER.mkdir(parents=True, exist_ok=True)

# Script de conversion
CONVERTER_SCRIPT = '/opt/mattermost/scripts/element_to_mattermost.py'
IMPORT_SCRIPT = '/opt/mattermost/scripts/element-import.sh'

# Stockage des jobs en mémoire (à remplacer par Redis en production)
jobs = {}

# Template HTML
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Import Element.io → Mattermost</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 1.1em;
        }
        
        .content {
            padding: 40px;
        }
        
        .step {
            margin-bottom: 40px;
            padding: 25px;
            background: #f8f9fa;
            border-radius: 12px;
            border-left: 4px solid #667eea;
        }
        
        .step-title {
            font-size: 1.3em;
            margin-bottom: 15px;
            color: #333;
            display: flex;
            align-items: center;
        }
        
        .step-number {
            background: #667eea;
            color: white;
            width: 35px;
            height: 35px;
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-right: 15px;
            font-weight: bold;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }
        
        input[type="text"],
        input[type="password"],
        select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 1em;
            transition: border-color 0.3s;
        }
        
        input[type="text"]:focus,
        input[type="password"]:focus,
        select:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .file-upload {
            border: 3px dashed #667eea;
            border-radius: 12px;
            padding: 40px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s;
            background: white;
        }
        
        .file-upload:hover {
            background: #f8f9ff;
            border-color: #764ba2;
        }
        
        .file-upload.drag-over {
            background: #f0f0ff;
            border-color: #667eea;
            transform: scale(1.02);
        }
        
        .file-upload-icon {
            font-size: 3em;
            margin-bottom: 15px;
        }
        
        input[type="file"] {
            display: none;
        }
        
        .btn {
            padding: 14px 30px;
            border: none;
            border-radius: 8px;
            font-size: 1em;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            display: inline-block;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        
        .btn-primary:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
        }
        
        .progress-container {
            display: none;
            margin-top: 30px;
        }
        
        .progress-bar {
            width: 100%;
            height: 30px;
            background: #e0e0e0;
            border-radius: 15px;
            overflow: hidden;
            position: relative;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            width: 0%;
            transition: width 0.3s;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        
        .status-message {
            margin-top: 15px;
            padding: 15px;
            border-radius: 8px;
            font-weight: 500;
        }
        
        .status-info {
            background: #e3f2fd;
            color: #1976d2;
            border-left: 4px solid #1976d2;
        }
        
        .status-success {
            background: #e8f5e9;
            color: #388e3c;
            border-left: 4px solid #388e3c;
        }
        
        .status-error {
            background: #ffebee;
            color: #c62828;
            border-left: 4px solid #c62828;
        }
        
        .status-warning {
            background: #fff3e0;
            color: #f57c00;
            border-left: 4px solid #f57c00;
        }
        
        .log-container {
            display: none;
            margin-top: 20px;
            background: #1e1e1e;
            color: #d4d4d4;
            padding: 20px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            max-height: 400px;
            overflow-y: auto;
        }
        
        .log-line {
            margin-bottom: 5px;
            line-height: 1.5;
        }
        
        .log-timestamp {
            color: #858585;
        }
        
        .log-info {
            color: #4fc3f7;
        }
        
        .log-success {
            color: #81c784;
        }
        
        .log-error {
            color: #e57373;
        }
        
        .log-warning {
            color: #ffb74d;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            border: 2px solid #e0e0e0;
            text-align: center;
        }
        
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        
        .help-text {
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .file-info {
            display: none;
            margin-top: 15px;
            padding: 15px;
            background: #e8f5e9;
            border-radius: 8px;
            border-left: 4px solid #4caf50;
        }
        
        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Import Element.io → Mattermost</h1>
            <p>Interface Web - Conversion et Import automatisés</p>
        </div>
        
        <div class="content">
            <!-- Étape 1: Configuration -->
            <div class="step">
                <div class="step-title">
                    <span class="step-number">1</span>
                    Configuration de l'import
                </div>
                
                <form id="importForm">
                    <div class="form-group">
                        <label for="teamName">Nom de l'équipe Mattermost *</label>
                        <input type="text" id="teamName" name="teamName" required 
                               placeholder="mon-equipe" pattern="[a-z0-9-]+"
                               title="Lettres minuscules, chiffres et tirets uniquement">
                        <div class="help-text">L'équipe sera créée si elle n'existe pas</div>
                    </div>
                    
                    <div class="form-group">
                        <label for="password">Mot de passe par défaut (optionnel)</label>
                        <input type="password" id="password" name="password" 
                               placeholder="ChangeMe123!">
                        <div class="help-text">Si vide, utilisera "ChangeMe123!"</div>
                    </div>
                </form>
            </div>
            
            <!-- Étape 2: Upload fichier -->
            <div class="step">
                <div class="step-title">
                    <span class="step-number">2</span>
                    Fichier d'export Element.io
                </div>
                
                <div class="file-upload" id="fileUploadZone">
                    <div class="file-upload-icon">📁</div>
                    <p><strong>Glissez-déposez votre fichier JSON ici</strong></p>
                    <p>ou</p>
                    <button type="button" class="btn btn-primary" onclick="document.getElementById('fileInput').click()">
                        Parcourir les fichiers
                    </button>
                    <input type="file" id="fileInput" accept=".json" onchange="handleFileSelect(event)">
                    <div class="help-text" style="margin-top: 15px;">Taille max: 500 MB</div>
                </div>
                
                <div class="file-info" id="fileInfo">
                    <strong>✓ Fichier sélectionné:</strong>
                    <div id="fileName"></div>
                    <div id="fileSize"></div>
                </div>
            </div>
            
            <!-- Étape 3: Lancement -->
            <div class="step">
                <div class="step-title">
                    <span class="step-number">3</span>
                    Lancement de l'import
                </div>
                
                <button type="button" class="btn btn-primary" id="startImportBtn" 
                        onclick="startImport()" disabled>
                    🚀 Démarrer l'import
                </button>
                
                <!-- Progression -->
                <div class="progress-container" id="progressContainer">
                    <div class="progress-bar">
                        <div class="progress-fill" id="progressFill">0%</div>
                    </div>
                    
                    <div id="statusMessage" class="status-message status-info">
                        En attente...
                    </div>
                    
                    <div class="spinner" id="spinner" style="display:none;"></div>
                    
                    <!-- Statistiques -->
                    <div class="stats-grid" id="statsGrid" style="display:none;">
                        <div class="stat-card">
                            <div class="stat-value" id="statUsers">-</div>
                            <div class="stat-label">Utilisateurs</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value" id="statMessages">-</div>
                            <div class="stat-label">Messages</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value" id="statThreads">-</div>
                            <div class="stat-label">Threads</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value" id="statFiles">-</div>
                            <div class="stat-label">Fichiers</div>
                        </div>
                    </div>
                    
                    <!-- Logs -->
                    <div class="log-container" id="logContainer"></div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        let selectedFile = null;
        let currentJobId = null;
        
        // Gestion du drag & drop
        const uploadZone = document.getElementById('fileUploadZone');
        
        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            uploadZone.addEventListener(eventName, preventDefaults, false);
        });
        
        function preventDefaults(e) {
            e.preventDefault();
            e.stopPropagation();
        }
        
        ['dragenter', 'dragover'].forEach(eventName => {
            uploadZone.addEventListener(eventName, () => {
                uploadZone.classList.add('drag-over');
            }, false);
        });
        
        ['dragleave', 'drop'].forEach(eventName => {
            uploadZone.addEventListener(eventName, () => {
                uploadZone.classList.remove('drag-over');
            }, false);
        });
        
        uploadZone.addEventListener('drop', handleDrop, false);
        
        function handleDrop(e) {
            const dt = e.dataTransfer;
            const files = dt.files;
            if (files.length > 0) {
                handleFile(files[0]);
            }
        }
        
        function handleFileSelect(e) {
            const files = e.target.files;
            if (files.length > 0) {
                handleFile(files[0]);
            }
        }
        
        function handleFile(file) {
            if (!file.name.endsWith('.json')) {
                alert('Veuillez sélectionner un fichier JSON');
                return;
            }
            
            selectedFile = file;
            document.getElementById('fileInfo').style.display = 'block';
            document.getElementById('fileName').textContent = file.name;
            document.getElementById('fileSize').textContent = formatBytes(file.size);
            document.getElementById('startImportBtn').disabled = false;
        }
        
        function formatBytes(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
        }
        
        async function startImport() {
            const teamName = document.getElementById('teamName').value.trim();
            const password = document.getElementById('password').value.trim();
            
            if (!teamName) {
                alert('Veuillez saisir le nom de l\'équipe');
                return;
            }
            
            if (!selectedFile) {
                alert('Veuillez sélectionner un fichier');
                return;
            }
            
            // Désactiver le bouton
            document.getElementById('startImportBtn').disabled = true;
            
            // Afficher la progression
            document.getElementById('progressContainer').style.display = 'block';
            document.getElementById('spinner').style.display = 'block';
            document.getElementById('logContainer').style.display = 'block';
            
            updateStatus('info', '📤 Upload du fichier...');
            
            // Upload du fichier
            const formData = new FormData();
            formData.append('file', selectedFile);
            formData.append('team', teamName);
            formData.append('password', password);
            
            try {
                const response = await fetch('/api/upload', {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.success) {
                    currentJobId = result.job_id;
                    addLog('info', `Job créé: ${currentJobId}`);
                    updateStatus('info', '⚙️ Import en cours...');
                    pollJobStatus(currentJobId);
                } else {
                    updateStatus('error', '❌ Erreur: ' + result.error);
                    document.getElementById('spinner').style.display = 'none';
                }
            } catch (error) {
                updateStatus('error', '❌ Erreur réseau: ' + error.message);
                document.getElementById('spinner').style.display = 'none';
            }
        }
        
        function pollJobStatus(jobId) {
            const interval = setInterval(async () => {
                try {
                    const response = await fetch(`/api/job/${jobId}`);
                    const job = await response.json();
                    
                    updateProgress(job.progress);
                    
                    if (job.logs && job.logs.length > 0) {
                        job.logs.forEach(log => {
                            addLog(log.level, log.message);
                        });
                    }
                    
                    if (job.status === 'completed') {
                        clearInterval(interval);
                        document.getElementById('spinner').style.display = 'none';
                        updateStatus('success', '✅ Import terminé avec succès!');
                        showStats(job.stats);
                    } else if (job.status === 'error') {
                        clearInterval(interval);
                        document.getElementById('spinner').style.display = 'none';
                        updateStatus('error', '❌ Erreur lors de l\'import');
                    }
                } catch (error) {
                    console.error('Erreur polling:', error);
                }
            }, 2000);
        }
        
        function updateProgress(progress) {
            const fill = document.getElementById('progressFill');
            fill.style.width = progress + '%';
            fill.textContent = progress + '%';
        }
        
        function updateStatus(level, message) {
            const statusEl = document.getElementById('statusMessage');
            statusEl.className = 'status-message status-' + level;
            statusEl.textContent = message;
        }
        
        function addLog(level, message) {
            const container = document.getElementById('logContainer');
            const timestamp = new Date().toLocaleTimeString();
            const logLine = document.createElement('div');
            logLine.className = 'log-line log-' + level;
            logLine.innerHTML = `<span class="log-timestamp">[${timestamp}]</span> ${message}`;
            container.appendChild(logLine);
            container.scrollTop = container.scrollHeight;
        }
        
        function showStats(stats) {
            if (!stats) return;
            document.getElementById('statsGrid').style.display = 'grid';
            document.getElementById('statUsers').textContent = stats.users || 0;
            document.getElementById('statMessages').textContent = stats.messages || 0;
            document.getElementById('statThreads').textContent = stats.threads || 0;
            document.getElementById('statFiles').textContent = stats.files || 0;
        }
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    """Page principale"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/upload', methods=['POST'])
def upload_file():
    """Upload et démarrage de l'import"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'Aucun fichier'}), 400
        
        file = request.files['file']
        team = request.form.get('team', '').strip()
        password = request.form.get('password', '').strip() or 'ChangeMe123!'
        
        if not team:
            return jsonify({'success': False, 'error': 'Nom d\'équipe manquant'}), 400
        
        if file.filename == '':
            return jsonify({'success': False, 'error': 'Nom de fichier vide'}), 400
        
        # Créer un job ID
        job_id = str(uuid.uuid4())
        job_dir = UPLOAD_FOLDER / job_id
        job_dir.mkdir(parents=True, exist_ok=True)
        
        # Sauvegarder le fichier
        filename = secure_filename(file.filename)
        file_path = job_dir / filename
        file.save(str(file_path))
        
        # Créer le job
        jobs[job_id] = {
            'status': 'pending',
            'progress': 0,
            'logs': [],
            'stats': {},
            'file_path': str(file_path),
            'team': team,
            'password': password,
            'created_at': datetime.now().isoformat()
        }
        
        # Lancer l'import en arrière-plan
        thread = threading.Thread(target=run_import, args=(job_id,))
        thread.daemon = True
        thread.start()
        
        return jsonify({'success': True, 'job_id': job_id})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/job/<job_id>')
def get_job_status(job_id):
    """Récupérer le statut d'un job"""
    job = jobs.get(job_id)
    if not job:
        return jsonify({'error': 'Job non trouvé'}), 404
    return jsonify(job)

def run_import(job_id):
    """Exécuter l'import Element → Mattermost"""
    job = jobs[job_id]
    
    try:
        job['status'] = 'running'
        job['progress'] = 10
        add_job_log(job_id, 'info', 'Démarrage de la conversion...')
        
        file_path = job['file_path']
        team = job['team']
        password = job['password']
        job_dir = Path(file_path).parent
        
        # Étape 1: Conversion Python
        output_file = job_dir / 'import.jsonl'
        cmd = [
            'python3',
            CONVERTER_SCRIPT,
            file_path,
            '--team', team,
            '--password', password,
            '--output', str(output_file)
        ]
        
        add_job_log(job_id, 'info', f'Commande: {" ".join(cmd)}')
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300
        )
        
        if result.returncode != 0:
            raise Exception(f'Conversion échouée: {result.stderr}')
        
        # Parser la sortie pour extraire les stats
        output = result.stdout
        stats = parse_conversion_output(output)
        job['stats'] = stats
        
        job['progress'] = 40
        add_job_log(job_id, 'success', f'✓ Conversion réussie: {stats.get("messages", 0)} messages')
        
        # Étape 2: Création du ZIP
        add_job_log(job_id, 'info', 'Création de l\'archive ZIP...')
        
        zip_file = job_dir / 'import.zip'
        subprocess.run(
            ['zip', '-j', str(zip_file), str(output_file)],
            check=True,
            capture_output=True
        )
        
        job['progress'] = 60
        add_job_log(job_id, 'success', '✓ Archive créée')
        
        # Étape 3: Import mmctl
        add_job_log(job_id, 'info', 'Import dans Mattermost...')
        
        result = subprocess.run(
            ['mmctl', '--local', 'import', 'process', '--bypass-upload', str(zip_file)],
            capture_output=True,
            text=True,
            timeout=600,
            env={**os.environ, 'MMCTL_LOCAL': 'true'}
        )
        
        if result.returncode != 0:
            raise Exception(f'Import échoué: {result.stderr}')
        
        job['progress'] = 100
        job['status'] = 'completed'
        add_job_log(job_id, 'success', '✅ Import terminé avec succès!')
        
    except subprocess.TimeoutExpired:
        job['status'] = 'error'
        add_job_log(job_id, 'error', '❌ Timeout dépassé')
    except Exception as e:
        job['status'] = 'error'
        add_job_log(job_id, 'error', f'❌ Erreur: {str(e)}')

def add_job_log(job_id, level, message):
    """Ajouter un log à un job"""
    if job_id in jobs:
        jobs[job_id]['logs'].append({
            'level': level,
            'message': message,
            'timestamp': datetime.now().isoformat()
        })

def parse_conversion_output(output):
    """Parser la sortie du script de conversion pour extraire les stats"""
    stats = {
        'users': 0,
        'messages': 0,
        'threads': 0,
        'files': 0
    }
    
    for line in output.split('\n'):
        if 'utilisateurs' in line.lower():
            try:
                stats['users'] = int(line.split()[0])
            except:
                pass
        elif 'messages' in line.lower():
            try:
                stats['messages'] = int(line.split()[0])
            except:
                pass
        elif 'threads' in line.lower():
            try:
                stats['threads'] = int(line.split()[0])
            except:
                pass
        elif 'fichiers' in line.lower():
            try:
                stats['files'] = int(line.split()[0])
            except:
                pass
    
    return stats

if __name__ == '__main__':
    # Vérifier que l'utilisateur est 'mattermost'
    import pwd
    current_user = pwd.getpwuid(os.getuid()).pw_name
    
    if current_user != 'mattermost':
        print(f"ATTENTION: Ce script devrait être exécuté en tant que 'mattermost'")
        print(f"Utilisateur actuel: {current_user}")
    
    print("=" * 60)
    print("Interface Web - Import Element.io → Mattermost")
    print("=" * 60)
    print(f"Serveur démarré sur http://0.0.0.0:5000")
    print("Accessible depuis: http://votre-serveur:5000")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5000, debug=False)
