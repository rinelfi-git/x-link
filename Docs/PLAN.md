# Cross Link — Plan de conception

Deux versions du produit, une base de code partagée (Flutter).

| | Cross Link (gratuit) | Cross Link Entreprise |
|---|---|---|
| Cible | Grand public, usage personnel | Organisations, usage professionnel |
| Réseau | P2P local (UDP + TCP), même sous-réseau | Tracker central + P2P, fonctionne partout |
| Identité | Automatique (hostname + OS, pas de login) | Comptes utilisateur avec authentification |
| Fonctionnalités | Partage de texte et fichiers, fil de discussion | Messagerie, groupes, vocaux, visio, partage d'écran |
| Serveur | Aucun | Tracker dédié par organisation |
| Stockage | En mémoire (durée de session) | SQLite local + serveur chiffré E2E |

---

# PARTIE I — Cross Link (gratuit)

---

## I.1. Vision

Outil de partage P2P en réseau local, inspiré de Dukto :

- Aucun serveur, aucun login, aucun compte
- Identification automatique par l'appareil (hostname + OS)
- Découverte automatique des pairs sur le réseau local
- Partage de texte et de fichiers
- Fil de discussion entre pairs (en mémoire uniquement, perdu à la fermeture)
- **Totalement stateless** : aucune base de données, aucune persistance
- Interface rectangulaire verticale sur desktop
- Multi-plateforme : Android, iOS, Windows, macOS, Linux

---

## I.2. Choix techniques

### Réseau : UDP + TCP

Protocoles rudimentaires, aucune dépendance externe :

- **UDP broadcast** — découverte des pairs sur le réseau local
- **TCP** — transfert fiable des messages texte et fichiers

Pas de WebRTC, pas de WebSocket, pas de relay.

### Identification

Chaque instance est identifiée par :

- Nom de la machine (hostname)
- Système d'exploitation
- Un identifiant de session unique (UUID) généré au lancement

Aucun login. L'identité est celle de l'appareil.

### Stockage : aucun (stateless)

- **Aucune base de données** (pas de SQLite, pas de drift, rien)
- Fil de discussion maintenu en mémoire (List/Map Dart), perdu à la
  fermeture de l'app
- Fichiers reçus enregistrés directement dans le dossier de
  téléchargement de l'OS (aucun suivi en base)
- Aucune trace des échanges après fermeture

---

## I.3. Architecture réseau

### Découverte des pairs (UDP)

Détaillé dans [LAN_discovery.md](LAN_discovery.md).

```
[App démarre]
  |
  |-- Envoie un broadcast UDP (port fixe) : "je suis ici"
  |     Payload : { id, hostname, os, text_port, file_ports }
  |
  |-- Écoute les broadcasts des autres pairs
  |     Ajoute/met à jour la liste des pairs connus
  |
  |-- Heartbeat périodique (toutes les 5 secondes)
  |     Détection des pairs qui quittent le réseau
  |
  |-- Annonce de départ à la fermeture de l'app
  |-- Re-ANNOUNCE à chaque reconfiguration du FileServer
```

### Format des messages UDP

```
CROSSLINK|1|type|payload_json

Types :
  ANNOUNCE  — { id, hostname, os, text_port, file_ports }
  HEARTBEAT — { id }
  LEAVE     — { id }
```

### Transfert de données (TCP)

Détaillé dans [TCP_transfer.md](TCP_transfer.md).

Deux serveurs TCP séparés :

- **TextServer** — 1 port, immuable, backlog 10
- **FileServer** — pool de N ports, reconfigurable, backlog 0

Format du paquet TCP (même structure pour texte et fichier) :

```
┌──────────────────┬────────────────────────┬──────────────┐
│ header_length    │ header (JSON, UTF-8)   │ body         │
│ 4 bytes          │ header_length bytes    │ variable     │
└──────────────────┴────────────────────────┴──────────────┘
```

Pas de byte de type — c'est le serveur qui reçoit qui détermine
le type (TextServer = texte, FileServer = fichier).

---

## I.4. Interface utilisateur

### Navigation — 3 pages

| Page | Contenu | Navigation visible ? |
|------|---------|---------------------|
| Peers | Liste des pairs en ligne (page par défaut) | Oui |
| Settings | Paramètres (MAX_FILE_TRANSFERS, dossier de réception, etc.) | Oui |
| Context | Fil de discussion avec un pair sélectionné | Non (plein écran) |

Peers et Settings sont accessibles via une navigation partagée
(onglets en bas sur mobile, tabs en haut sur desktop).

Context est une page plein écran — la navigation est cachée. On y
entre en cliquant sur un pair dans Peers. Un bouton retour ramène
à Peers.

### Page Peers

```
┌──────────────────────────────┐
│  Cross Link        [_][□][x] │
├──────────────────────────────┤
│                              │
│  Pairs en ligne (3)          │
│                              │
│  ┌────────────────────────┐  │
│  │  PC-Bureau (linux)     │  │
│  ├────────────────────────┤  │
│  │  Pixel-8 (android)     │  │
│  ├────────────────────────┤  │
│  │  MacBook (macos)       │  │
│  └────────────────────────┘  │
│                              │
│                              │
│                              │
├──────────────────────────────┤
│  [Peers]          [Settings] │
└──────────────────────────────┘
```

### Page Settings

```
┌──────────────────────────────┐
│  Cross Link        [_][□][x] │
├──────────────────────────────┤
│                              │
│  Paramètres                  │
│                              │
│  Transferts fichier          │
│  simultanés : [2]  [-] [+]  │
│                              │
│  Dossier de réception :      │
│  ~/Téléchargements           │
│  [Changer]                   │
│                              │
│                              │
│                              │
├──────────────────────────────┤
│  [Peers]          [Settings] │
└──────────────────────────────┘
```

### Page Context (plein écran, sans navigation)

```
┌──────────────────────────────┐
│  ← PC-Bureau (linux)        │
├──────────────────────────────┤
│                              │
│  ┌─ Moi ──────────────────┐  │
│  │ Salut, voici le doc    │  │
│  └────────────────────────┘  │
│  ┌─ PC-Bureau ────────────┐  │
│  │  rapport.pdf (2 MB)    │  │
│  │ [Ouvrir] [Dossier]     │  │
│  └────────────────────────┘  │
│  ┌─ Moi ──────────────────┐  │
│  │ Merci !                │  │
│  └────────────────────────┘  │
│                              │
├──────────────────────────────┤
│  [+]  Message...    [Envoyer]│
└──────────────────────────────┘
```

### Layout mobile

Même structure et mêmes 3 pages. Peers et Settings en onglets,
Context en navigation push (plein écran).

### Types de messages dans le fil (Context)

| Type | Affichage |
|------|-----------|
| Texte envoyé | Bulle alignée à droite |
| Texte reçu | Bulle alignée à gauche |
| Fichier envoyé | Bulle avec nom + taille + progression |
| Fichier reçu | Bulle avec nom + taille + boutons Ouvrir/Dossier |
| Fichier en attente | Bulle avec "En attente d'un slot" |
| Fichier échoué | Bulle avec message d'erreur + bouton Réessayer |

---

## I.5. Structure du code

```
lib/
├── main.dart                         ← détection plateforme → setupDesktop / setupMobile
├── app/
│   ├── desktop_app.dart              ← DesktopApp (fenêtre fixe verticale)
│   ├── mobile_app.dart               ← MobileApp (plein écran, navigation push)
│   ├── setup_desktop.dart            ← setupDesktop() : window_manager + runApp(DesktopApp)
│   ├── setup_mobile.dart             ← setupMobile() : config mobile + runApp(MobileApp)
│   └── theme.dart
├── core/
│   ├── network/
│   │   ├── server/
│   │   │   ├── text_server.dart      ← TextServer : 1 port, immuable, N connexions
│   │   │   └── file_server.dart      ← FileServer : pool de N ServerSocket, reconfigurable
│   │   ├── client/
│   │   │   ├── text_client.dart      ← envoi texte vers peer.textPort
│   │   │   └── file_client.dart      ← envoi fichier avec fallback entre file_ports
│   │   ├── udp_discovery.dart        ← broadcast/écoute UDP, ANNOUNCE/HEARTBEAT/LEAVE
│   │   └── protocol.dart             ← format des paquets (header_length + JSON + body)
│   ├── models/
│   │   ├── peer.dart                 ← Peer (id, hostname, os, ip, textPort, filePorts)
│   │   ├── message.dart              ← Message (abstract), TextMessage, FileMessage
│   │   └── transfer_state.dart       ← TransferState (progression, status, checksum)
│   └── providers/
│       ├── discovery_provider.dart    ← UdpDiscovery, liste réactive des pairs
│       ├── text_server_provider.dart  ← TextServer singleton
│       ├── file_server_provider.dart  ← FileServer reconfigurable
│       ├── messages_provider.dart     ← messagesProvider(peerId) [family]
│       └── transfer_provider.dart     ← transferProvider(transferId) [family]
├── features/
│   ├── peers/
│   │   └── presentation/
│   │       ├── peers_list_page.dart
│   │       └── widgets/
│   │           └── peer_tile.dart
│   ├── conversation/
│   │   └── presentation/
│   │       ├── conversation_page.dart
│   │       └── widgets/
│   │           ├── message_bubble.dart
│   │           ├── file_message.dart
│   │           └── message_input.dart
│   └── settings/
│       └── presentation/
│           └── settings_page.dart     ← modification MAX_FILE_TRANSFERS
└── shared/
    └── widgets/
```

---

## I.6. Plan d'implémentation

### Phase 1 — Découverte réseau

- `UdpDiscovery` : broadcast, écoute, heartbeat, annonce de départ
- Modèle `Peer` avec gestion d'état (liste réactive)
- UI : liste des pairs en ligne, mise à jour en temps réel

### Phase 2 — Transfert de texte

- `TcpServer` (écoute) et `TcpClient` (envoi)
- Protocole header JSON + contenu
- Modèle `Message` et fil de discussion en mémoire
- UI : fil de discussion, envoi/réception de texte

### Phase 3 — Transfert de fichiers

- Envoi de fichiers via TCP avec métadonnées (nom, taille)
- Réception et stockage dans un dossier configurable
- Barre de progression
- UI : sélecteur de fichier, affichage dans le fil

### Phase 4 — Polish

- Drag & drop de fichiers (desktop)
- Notifications de réception
- Paramètres (dossier de réception, nom d'affichage)
- Gestion des erreurs réseau

---

## I.7. Points techniques

- **Port UDP** : port fixe (ex: 53317)
- **Port TCP** : dynamique, communiqué via l'annonce UDP
- **Timeout pairs** : retrait de la liste si pas de heartbeat depuis N secondes
- **Pas de chiffrement** pour la version gratuite (réseau local de confiance)
- **Stateless** : aucune base de données, aucune persistance, zéro trace
- **Limites** : même sous-réseau uniquement

---

# PARTIE II — Cross Link Entreprise

---

## II.1. Vision

Application de communication pour organisations, avec architecture à
**deux niveaux de serveur** :

### Architecture globale

```
┌─────────────────────────────────────────────────────────┐
│              Serveur Central Cross Link                 │
│           (géré par l'équipe Cross Link)               │
│                                                         │
│  - Comptes utilisateurs globaux (inscription, login)   │
│  - Validation des clés API des instances               │
│  - Annuaire des instances                              │
└────────────┬────────────────────┬───────────────────────┘
             │                    │
    clé API  │                    │  clé API
   + auth    │                    │  + auth
             │                    │
┌────────────▼──────┐  ┌─────────▼────────────┐
│ Instance Org A    │  │ Instance Org B       │
│ (déployée par A)  │  │ (déployée par B)     │
│                   │  │                      │
│ - Channels        │  │ - Channels           │
│ - Messages E2E    │  │ - Messages E2E       │
│ - Fichiers E2E    │  │ - Fichiers E2E       │
│ - Présence/statut │  │ - Présence/statut    │
│ - Visio (LiveKit) │  │ - Visio (LiveKit)    │
└───────────────────┘  └──────────────────────┘
```

### Deux niveaux de serveur

| | Serveur central | Instance (par organisation) |
|---|---|---|
| Géré par | Équipe Cross Link | L'organisation cliente |
| Rôle | Identité globale + licences | Communication chiffrée |
| Comptes utilisateurs | Inscription, login, profil | Référence au compte central |
| Clés API | Émet et valide | Reçoit et se fait valider |
| Messages | Jamais | Stocke les blobs chiffrés |
| Fichiers | Jamais | Stocke les blobs chiffrés (rétention) |
| Statut de connexion | Non | Oui (géré localement par instance) |

### Principes

- Le serveur central ne voit **jamais** de messages ni de fichiers
- Les instances ne stockent **jamais** de message en clair — uniquement
  des blobs chiffrés
- Le chiffrement/déchiffrement se fait exclusivement côté client
- Un utilisateur a **un seul compte** (sur le serveur central) et peut
  rejoindre **plusieurs instances**
- Le statut de connexion (en ligne/hors ligne) est géré **par chaque
  instance** indépendamment

### Modèle économique

- **Client** : totalement gratuit, multi-plateforme
- **Instance serveur** : payante, validée par clé API auprès du serveur
  central
- **Serveur central** : opéré par l'équipe Cross Link

---

## II.2. Architecture

### Flux de communication

```
┌─────────┐    auth     ┌──────────────────┐   valide clé API   ┌──────────────┐
│ Client  │ ──────────> │ Serveur Central  │ <──────────────── │  Instance    │
│         │ <────────── │ (Cross Link)     │ ──────────────── > │  (Org A)     │
│         │   token     │                  │   OK / refusé      │              │
│         │             │ - Comptes        │                    │ - Channels   │
│         │  messages   │ - Licences       │                    │ - Messages   │
│         │  chiffrés   │                  │                    │ - Fichiers   │
│         │ ──────────────────────────────────────────────────> │ - Présence   │
│         │ <────────────────────────────────────────────────── │ - Visio      │
└─────────┘             └──────────────────┘                    └──────────────┘
```

Le client s'authentifie auprès du **serveur central** (compte unique), puis
communique directement avec les **instances** pour les messages, fichiers et
appels. Les instances valident leur clé API auprès du serveur central.

### Ce que chaque serveur stocke

**Serveur central**

| Donnée | En clair ? |
|--------|------------|
| Comptes utilisateurs (username, email, hash mdp) | Oui |
| Clés publiques des utilisateurs | Oui |
| Licences / clés API des instances | Oui |
| Annuaire des instances | Oui |

**Instance (par organisation)**

| Donnée | En clair ? |
|--------|------------|
| Channels / groupes (nom, membres) | Oui |
| Messages | Non — blob chiffré + métadonnées (date, expéditeur, channel) |
| Fichiers | Non — blob chiffré + référence (taille, date, expiration) |
| Statut de connexion des utilisateurs | Oui (géré localement) |

**Jamais stocké nulle part**

- Contenu des messages en clair
- Contenu des fichiers en clair
- Clés privées des utilisateurs

### Stack technique

**Serveur central — Java 21 + Spring Boot 3**

- Spring Security — authentification, gestion des tokens
- PostgreSQL — comptes, licences, annuaire instances
- Redis — cache de sessions d'authentification

**Instance — Java 21 + Spring Boot 3**

- Prend la **clé API en argument** au démarrage
- PostgreSQL — channels, messages chiffrés, fichiers, sessions locales
- Redis — présence temps-réel
- Stockage fichiers — filesystem ou object storage (S3-compatible)
- LiveKit — audio/vidéo temps réel, partage d'écran

Stack Java unifiée : un seul écosystème, mêmes compétences, mêmes
outils de build (Maven/Gradle), mêmes pratiques de déploiement.

**Client Flutter**

- `web_socket_channel` — connexion persistante aux instances
- `dio` ou `http` — REST (auth centrale + upload/download fichiers)
- `drift` — SQLite local (cache des messages déchiffrés)
- `riverpod` — gestion d'état
- `go_router` — routing adaptatif
- `flutter_secure_storage` — clés de chiffrement, tokens
- `pointycastle` ou `cryptography` — chiffrement E2E côté client
- `livekit_client` — visio/audio
- `record` + `just_audio` — messages vocaux
- `file_picker` + `desktop_drop` — fichiers

---

## II.3. Chiffrement

### Principe

Tout message et fichier est chiffré **côté client** avant d'être envoyé au
serveur. Le serveur ne manipule que des blobs opaques.

### Flux d'envoi d'un message

```
[Client expéditeur]
  1. Rédige le message en clair
  2. Chiffre avec la clé de conversation (symétrique, AES-256-GCM)
  3. Envoie le blob chiffré + métadonnées (channel_id, timestamp) au serveur

[Serveur]
  4. Stocke le blob chiffré tel quel
  5. Notifie les destinataires via WebSocket

[Client destinataire]
  6. Reçoit le blob chiffré
  7. Déchiffre avec la clé de conversation
  8. Affiche le message en clair localement
```

### Flux d'envoi d'un fichier

```
[Client expéditeur]
  1. Chiffre le fichier localement (AES-256-GCM)
  2. Upload le blob chiffré via REST (multipart)
  3. Envoie un message de type "file" avec la référence (file_id, nom
     original chiffré, taille, clé de fichier chiffrée avec la clé de
     conversation)

[Serveur]
  4. Stocke le blob chiffré sur le filesystem/object storage
  5. Stocke la référence en base (file_id, taille, date, expiration)
  6. Supprime automatiquement le fichier après expiration

[Client destinataire]
  7. Télécharge le blob chiffré via REST
  8. Déchiffre avec la clé extraite du message
```

### Gestion des clés

- Chaque conversation (DM ou groupe) a une **clé symétrique** partagée
  entre les participants
- Les clés de conversation sont échangées via un mécanisme de clé publique
  (chaque utilisateur a une paire RSA ou X25519)
- Les clés privées sont stockées uniquement sur l'appareil
  (`flutter_secure_storage`)
- Le serveur ne voit jamais les clés

---

## II.4. Multi-serveurs côté client

### Concept

Le client gère une liste de serveurs (organisations). L'utilisateur peut :

- Ajouter un serveur en saisissant son URL hôte
- Se connecter avec ses identifiants propres à chaque serveur
- Basculer entre serveurs dans l'interface
- Recevoir des notifications de tous les serveurs connectés

### Stockage local

```
central_account (SQLite local)
  user_id               UUID du serveur central
  username
  central_token
  private_key           clé privée E2E (chiffrée par master password local)
  public_key

instances (SQLite local)
  id                    PK
  host_url              "https://crosslink.org-a.com"
  display_name          "Organisation A"
  instance_token
  session_id
  last_connected_at
```

### Interface

Barre latérale avec les icônes/initiales des serveurs, similaire à Discord :

```
┌───┬─────────┬──────────────┬─────────────────────┐
│ E │ Rail    │ Liste        │ Vue principale      │
│ A │ (nav)   │ (channels/   │ (conversation,      │
│   │         │  DMs)        │  appel)             │
│ E │         │              │                     │
│ B │         │              │                     │
│   │         │              │                     │
│ + │         │              │                     │
└───┴─────────┴──────────────┴─────────────────────┘
  ^
  Sélecteur de serveur
```

---

## II.5. Licence serveur

### Principe

Le client est gratuit. Le serveur est payant. Le serveur prend la **clé API
en argument** au démarrage :

```
./crosslink-server --api-key "CL-XXXX-XXXX-XXXX-XXXX"
```

### Flux de validation

```
[Serveur démarre avec --api-key]
  ↓
[Validation initiale : POST vers api.crosslink.io/license/validate]
  Body: { api_key, server_fingerprint, version, timestamp }
  ↓
  200 OK → { valid, plan, max_users, features, expires_at, signed_token }
    → Démarrage normal
  ↓
  401/403 → Clé invalide ou expirée
    → Le serveur refuse de démarrer
  ↓
[Validation périodique : toutes les 24h]
  ↓
  Échec temporaire → grace period de 7 jours
  Après grace period → arrêt du serveur
```

### Protection anti-falsification

Le risque principal : un opérateur redirige le trafic vers
`api.crosslink.io` en local (via `/etc/hosts`, DNS interne, ou proxy) et
répond toujours `200 OK` avec une fausse validation.

**Couche 1 — Réponse signée (asymétrique)**

La réponse de validation est signée avec une clé privée détenue
uniquement par le service de licence Cross Link. Le serveur embarque la
**clé publique** correspondante dans son binaire compilé.

```
[Service de licence]
  Signe la réponse avec sa clé privée Ed25519

[Serveur Cross Link]
  Vérifie la signature avec la clé publique embarquée
  → Impossible de forger une réponse valide sans la clé privée
  → Rediriger le trafic en local ne sert à rien : la signature sera
    invalide
```

Le serveur rejette toute réponse dont la signature ne correspond pas.
Même un faux serveur local ne peut pas produire une signature valide.

**Couche 2 — Certificate pinning (TLS)**

Le serveur embarque le certificat (ou son hash SHA-256) attendu pour
`api.crosslink.io`. Même si l'attaquant redirige le DNS et présente un
certificat auto-signé ou émis par une CA interne, la connexion TLS est
refusée.

```
Vérifications :
  - Le certificat présenté correspond au pin embarqué
  - Le hostname correspond à api.crosslink.io
  - La chaîne de certification est valide
```

**Couche 3 — Challenge-response avec timestamp**

Le serveur envoie un **nonce** (valeur aléatoire unique) à chaque
requête de validation. Le service de licence inclut ce nonce dans la
réponse signée, empêchant le **replay** d'anciennes réponses valides.

```
[Serveur]
  Génère nonce = random(32 bytes)
  POST { api_key, nonce, timestamp, server_fingerprint }

[Service de licence]
  Signe { valid, plan, nonce, timestamp, expires_at }
  → La signature couvre le nonce

[Serveur]
  Vérifie que le nonce dans la réponse = celui envoyé
  Vérifie que le timestamp est récent (< 5 minutes)
  → Empêche le rejeu d'anciennes réponses
```

**Couche 4 — Fingerprint serveur**

Le serveur génère un fingerprint stable basé sur des caractéristiques
matérielles (MAC addresses, CPU ID, hostname, etc.). Ce fingerprint est
lié à la licence. Une même clé API ne peut pas être utilisée sur deux
machines différentes simultanément.

```
Le service de licence vérifie :
  - api_key connue et valide
  - server_fingerprint correspond à celui enregistré pour cette clé
  - Pas de fingerprint différent actif pour la même clé
    → Si oui : rejet (licence déjà utilisée ailleurs)
```

**Couche 5 — Obfuscation du binaire**

La clé publique et la logique de validation sont protégées contre le
reverse engineering :

- Clé publique fragmentée dans le code (pas une constante lisible)
- Logique de vérification dispersée (pas un seul `if (valid)`)
- Pour Go : obfuscation via `garble`
- Pour Java : obfuscation via ProGuard/R8

Ce n'est pas une protection absolue mais augmente significativement le
coût d'attaque.

### Résumé des protections

| Attaque | Protection |
|---------|-----------|
| Redirection DNS/hosts vers serveur local | Signature asymétrique (clé publique embarquée) |
| Faux certificat TLS (CA interne) | Certificate pinning |
| Rejeu d'une ancienne réponse valide | Challenge-response avec nonce + timestamp |
| Même clé API sur plusieurs machines | Fingerprint serveur lié à la licence |
| Reverse engineering pour patcher le binaire | Obfuscation (garble / ProGuard) |
| Interception réseau (MITM) | TLS + pinning + signature |

---

## II.6. Modèle d'identité

### Un compte global, une présence par instance

L'utilisateur a **un seul compte** sur le serveur central. Il peut
rejoindre **plusieurs instances**. Le statut de connexion (en ligne /
hors ligne) est géré **indépendamment par chaque instance**.

| Niveau | Géré par | Données |
|--------|----------|---------|
| Compte (identité) | Serveur central | username, email, mdp, clé publique |
| Présence / session | Chaque instance | connection_status, claimed_session |

### Concepts clés

| Concept | Sens |
|---------|------|
| `claimed_session` | Session propriétaire par instance, ne se libère que par action explicite |
| `connection_status` | Temps réel par instance : WebSocket ouverte ou non |
| `ownership_status` | Durable par instance : droit de reconnexion silencieuse |
| `device_fingerprint` | Identifiant stable de l'appareil |

### Flux d'authentification

```
[Client]
  1. Login avec username + mdp → Serveur Central
  2. Reçoit un auth_token central
  3. Se connecte à une instance avec auth_token + device_fingerprint
  4. L'instance vérifie le token auprès du serveur central
  5. L'instance crée une session locale (présence, statut)
```

### Politique de session : takeover (par instance)

Quand un login est tenté depuis un autre appareil sur une même instance,
l'utilisateur choisit :

- **Basculer ici** — l'ancien appareil est déconnecté de cette instance
- **Annuler** — l'ancien appareil garde la session sur cette instance

---

## II.7. Schéma de données

### Serveur central — tables

```
users
  id                    PK (UUID)
  username              unique
  email                 unique
  password_hash
  display_name
  public_key            clé publique E2E (X25519 ou RSA)
  created_at
  updated_at
```

```
licenses
  id                    PK (UUID)
  api_key               unique, clé API de l'instance
  plan                  "starter" | "business" | "enterprise"
  max_users
  features              JSON (flags de fonctionnalités)
  server_fingerprint    fingerprint de la machine liée
  owner_user_id         FK users (l'acheteur)
  created_at
  expires_at
  last_validated_at
```

```
instances
  id                    PK (UUID)
  license_id            FK licenses
  host_url              "https://crosslink.org-a.com"
  display_name          "Organisation A"
  registered_at
```

### Instance — tables

```
instance_users
  id                    PK
  central_user_id       UUID de l'utilisateur sur le serveur central
  display_name          copie locale (cache)
  public_key            copie locale (cache)
  joined_at
```

```
sessions
  id                    PK (UUID)
  instance_user_id      FK instance_users
  device_name
  device_os
  device_fingerprint
  ip_address
  created_at
  last_active_at
  connection_status     "online" | "offline"
  ownership_status      "claimed" | "released"
  released_at
  released_reason       "logout" | "replaced_by_new_login"
```

```
channels
  id                    PK
  name
  type                  "dm" | "group" | "voice"
  created_by            FK instance_users
  created_at
```

```
channel_members
  channel_id            FK
  instance_user_id      FK
  role                  "owner" | "admin" | "member"
  joined_at
  encrypted_channel_key clé de conversation chiffrée avec la clé publique du membre
```

```
messages
  id                    PK
  channel_id            FK
  sender_id             FK instance_users
  type                  "text" | "file" | "image" | "voice" | "system"
  encrypted_content     blob chiffré (jamais en clair)
  sent_at
```

L'instance ne stocke pas `delivery_status` — c'est géré côté client.

```
files
  id                    PK (UUID)
  channel_id            FK
  uploaded_by           FK instance_users
  encrypted_filename    nom original chiffré
  size_bytes
  storage_path          chemin vers le blob chiffré
  uploaded_at
  expires_at            date d'expiration (suppression auto)
```

### Contraintes

```sql
-- Une seule session claimed par utilisateur par instance
CREATE UNIQUE INDEX one_claimed_session_per_user
ON sessions(instance_user_id) WHERE ownership_status = 'claimed';
```

---

## II.8. API

### API du serveur central (api.crosslink.io)

#### Authentification utilisateur

```
POST /auth/register
  Body: { username, email, password }
  201 → { user_id, token }

POST /auth/login
  Body: { username, password }
  200 → { user_id, token, public_key }
  401 → credentials invalides

POST /auth/validate-token
  Headers: Authorization: Bearer <token>
  200 → { valid, user }
  401 → token invalide/expiré

GET  /auth/me
  → { user_id, username, email, display_name, public_key }

PUT  /auth/me
  Body: { display_name, public_key }

POST /auth/change-password
  Body: { old_password, new_password }
```

#### Validation des licences (appelée par les instances)

```
POST /license/validate
  Body: { api_key, server_fingerprint, nonce, timestamp, version }
  200 → { valid, plan, max_users, features, expires_at, nonce,
           signature }
  401 → clé invalide
  403 → fingerprint mismatch / licence déjà active ailleurs

GET  /license/info
  Headers: Authorization: Bearer <api_key>
  → { plan, max_users, features, expires_at }
```

#### Annuaire des instances

```
GET  /instances
  Headers: Authorization: Bearer <user_token>
  → { instances: [{ id, host_url, display_name }] }

POST /instances/:id/join
  Headers: Authorization: Bearer <user_token>
  200 → { instance_token }
```

### API de l'instance (crosslink.org-a.com)

#### Connexion à l'instance

```
POST /connect
  Body: { central_token, device_fingerprint, device_name, device_os }
  200 → { session_id, instance_token }
  → L'instance vérifie le central_token auprès du serveur central
  → Crée/met à jour l'entrée instance_users
  → Crée une session locale
  409 → { existing_session, takeover_token }

POST /connect/takeover
  Body: { takeover_token, device_fingerprint, device_name, device_os }
  200 → { session_id, instance_token }

POST /disconnect
GET  /sessions
```

#### Channels

```
POST   /channels
GET    /channels
GET    /channels/:id/messages    historique (blobs chiffrés, paginé)
POST   /channels/:id/members    ajouter un membre (avec clé chiffrée)
DELETE /channels/:id/members/:user_id
```

#### Messages

```
POST /channels/:id/messages
  Body: { type, encrypted_content }
  L'instance stocke le blob, notifie via WebSocket
```

#### Fichiers

```
POST   /channels/:id/files/upload
  Multipart: blob chiffré
  200 → { file_id, expires_at }

GET    /files/:id/download
  → blob chiffré

DELETE /files/:id
```

#### Événements WebSocket (instance -> client)

```
{ type: "heartbeat", timestamp, session_valid }
{ type: "session_revoked", reason, replaced_by_device }
{ type: "presence_update", user_id, status }
{ type: "new_message", channel_id, message_id, sender_id, type, encrypted_content }
{ type: "file_uploaded", channel_id, file_id, sender_id }
{ type: "call_incoming", channel_id, room_token }
```

---

## II.9. Architecture des pages

### Layout à quatre colonnes (desktop)

```
┌───┬─────────┬──────────────┬─────────────────────┐
│ S │ Rail    │ Liste        │ Vue principale      │
│ e │ (nav)   │ (channels/   │ (conversation,      │
│ r │         │  DMs)        │  appel)             │
│ v │         │              │                     │
│ e │         │              │                     │
│ u │         │              │                     │
│ r │         │              │                     │
│ s │         │              │                     │
└───┴─────────┴──────────────┴─────────────────────┘
```

Sur mobile : sélecteur de serveur en haut ou en drawer, puis navigation
par onglets.

### Navigation principale (par serveur)

1. Conversations — DMs et groupes
2. Salons vocaux — channels voix/visio
3. Membres — utilisateurs du serveur, présence
4. Paramètres

---

## II.10. Plan d'implémentation

### Phase 1 — Serveur central + licence

- Serveur central : inscription, login, gestion des comptes
- Module de validation des clés API (signature, pinning, challenge-response)
- Annuaire des instances
- Client : écran de login central + liste des instances

### Phase 2 — Instance + connexion

- Instance minimale : connexion via token central, sessions locales, présence
- Validation de clé API au démarrage + toutes les 24h
- Client : sélecteur d'instances, connexion/takeover par instance

### Phase 3 — Chiffrement + messagerie

- Génération de clés côté client (paire asymétrique + clés de conversation)
- Échange de clés à la création de channel
- Envoi/réception de messages chiffrés via WebSocket
- Stockage local (SQLite) des messages déchiffrés

### Phase 4 — Fichiers

- Upload/download de fichiers chiffrés via REST
- Rétention configurable avec suppression automatique
- Affichage dans le fil de discussion

### Phase 5 — Groupes et channels

- Création de groupes avec gestion des membres
- Distribution des clés de groupe (re-chiffrement à l'ajout/retrait)
- Channels vocaux

### Phase 6 — Visio et partage d'écran

- Intégration LiveKit
- Salons vocaux persistants
- Partage d'écran

### Phase 7 — Polish

- Notifications multi-instances
- Messages vocaux
- Paramètres (instances, sécurité, rétention)
- Mode dégradé offline (lecture du cache local)

---

## II.11. Points de vigilance

### Rétention des fichiers

Les fichiers chiffrés sont supprimés automatiquement après expiration.
La durée de rétention est configurable par l'administrateur du serveur
(par défaut : 30 jours).

### Rotation des clés

Quand un membre quitte un channel, la clé de conversation doit être
renouvelée et redistribuée aux membres restants.

### Perte de clés

Si un utilisateur perd ses clés locales (changement d'appareil, reset),
l'historique chiffré devient illisible. Options :
- Export/import de clés (backup chiffré par master password)
- Accepter la perte (les nouveaux messages seront lisibles avec les
  nouvelles clés)

### Scalabilité serveur

- PostgreSQL + Redis suffisent pour des organisations de taille moyenne
- Object storage (S3-compatible) recommandé pour les fichiers au-delà
  d'un certain volume
- Le serveur est stateless (sauf WebSocket) : scaling horizontal possible