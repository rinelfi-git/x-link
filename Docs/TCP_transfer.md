# Transfert TCP — Texte et fichiers

Plan détaillé du protocole de transfert entre pairs via TCP pour
Cross Link (version gratuite).

---

## Principe général

Chaque pair écoute sur **deux types de serveurs TCP** séparés :

- **TextServer** — 1 port, immuable, réception de messages texte
- **FileServer** — N ports (pool), reconfigurable, réception de fichiers

Les ports sont dynamiques (attribués par l'OS) et communiqués aux
autres pairs via l'ANNOUNCE UDP.

Le type de donnée (texte ou fichier) n'est **pas** dans le paquet —
c'est le serveur qui reçoit qui le détermine. TextServer = texte,
FileServer = fichier.

### Pourquoi deux types de serveurs

Un transfert de fichier de 2 GB ne doit jamais bloquer l'envoi ou la
réception de messages texte. Canaux séparés = indépendance totale.

---

## Configuration

```
CROSSLINK_MAX_FILE_TRANSFERS=2
```

Le nombre de slots fichier (= nombre de ServerSocket dans le pool).
Chaque slot accepte un transfert à la fois. Les ports sont dynamiques.

---

## Architecture des services

### TextServer — immuable

```
TextServer
  - 1 seul ServerSocket, 1 seul port
  - Créé une seule fois au démarrage
  - Accepte jusqu'à 10 connexions en attente (backlog = 10)
  - Ne se reconfigure jamais
  - Se ferme uniquement à la fermeture de l'app
```

### FileServer — pool reconfigurable

```
FileServer
  - Pool de N ServerSocket (N = MAX_FILE_TRANSFERS)
  - Chaque ServerSocket = 1 slot, 1 port, 1 transfert à la fois
  - Aucune connexion en attente (backlog = 0) : si le slot est occupé,
    la connexion est refusée immédiatement → l'envoyeur fallback sur
    un autre port
  - Pool partagé entre TOUS les pairs (pas par pair)
  - Total ServerSocket ouverts = N, peu importe le nombre de pairs

  Reconfiguration (ex: passer de 2 à 3 slots) :
    1. Ouvrir un nouveau ServerSocket (nouveau port)
    2. L'ajouter au pool
    3. Broadcast ANNOUNCE avec file_ports mis à jour

  Reconfiguration (ex: passer de 3 à 2 slots) :
    1. Attendre la fin du transfert sur le slot à retirer
    2. Fermer le ServerSocket
    3. Le retirer du pool
    4. Broadcast ANNOUNCE avec file_ports mis à jour
```

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│  Pair local (MAX_FILE_TRANSFERS = 2)                        │
│                                                             │
│  ┌──────────────────┐    ┌───────────────────────────────┐  │
│  │ TextServer        │    │ FileServer (pool)             │  │
│  │ port: 45231       │    │   slot 0 → port 45232         │  │
│  │ immuable          │    │   slot 1 → port 45233         │  │
│  │ N connexions      │    │                               │  │
│  └──────────────────┘    └───────────────────────────────┘  │
│                                                             │
│  Total : 3 ServerSocket ouverts (1 texte + 2 fichier)      │
│  Même avec 19 pairs connectés, toujours 3 ServerSocket.    │
│                                                             │
│  ANNOUNCE: { text_port: 45231, file_ports: [45232, 45233] }│
└─────────────────────────────────────────────────────────────┘
```

---

## Protocole TCP — structure du paquet

Plus de byte de type. Le serveur qui reçoit sait déjà ce qu'il traite.

```
┌──────────────────┬────────────────────────┬──────────────┐
│ header_length    │ header (JSON, UTF-8)   │ body         │
│ 4 bytes          │ header_length bytes    │ variable     │
└──────────────────┴────────────────────────┴──────────────┘
```

Le header JSON contient toutes les métadonnées. Le body contient le
contenu (texte UTF-8 ou bytes d'un chunk de fichier).

---

## Architecture avec Riverpod

```
┌─────────────────────────────────────────────────────────────┐
│                       UI (Flutter)                          │
│                                                             │
│  watch(messagesProvider(peerId))     → fil de discussion    │
│  watch(transferProvider(transferId)) → barre de progression │
│  watch(activeTransfersProvider)      → liste des transferts │
└──────────┬───────────────────────────────────┬──────────────┘
           │                                   │
     notifie via provider                notifie via provider
           │                                   │
┌──────────▼───────────────────────────────────▼──────────────┐
│                   Couche réseau                             │
│                                                             │
│  TextServer (1 port, N connexions texte)                   │
│  FileServer (N ports, 1 connexion par port)                │
│  TextClient (envoi texte vers peer.textPort)               │
│  FileClient (envoi fichier, fallback entre file_ports)     │
└─────────────────────────────────────────────────────────────┘
```

### Providers Riverpod

```
textServerProvider
  Rôle : écoute les messages texte sur 1 port
  Lifecycle : créé au démarrage, dispose à la fermeture

fileServerProvider
  Rôle : pool de ServerSocket, reconfigurable
  Lifecycle : créé au démarrage, reconfigurable, dispose à la fermeture

messagesProvider(String peerId)    [family]
  Rôle : liste des messages échangés avec un pair
  Type : List<Message> en mémoire

activeTransfersProvider
  Rôle : tous les transferts en cours (envoi + réception)
  Type : Map<String, TransferState>

transferProvider(String transferId)    [family]
  Rôle : état d'un transfert individuel
  Mis à jour : à chaque chunk reçu/envoyé + ACK/RETRY
```

---

## Modèles

### Message (abstrait)

```
Message (abstract)
  id                    UUID
  peerId                identifiant du pair (expéditeur ou destinataire)
  direction             "sent" | "received"
  timestamp             DateTime

TextMessage extends Message
  content               texte du message

FileMessage extends Message
  transferId            UUID du transfert
  filename              nom du fichier
  fileSize              taille en bytes
  localFilePath         chemin local du fichier reçu (null tant que pas terminé)
```

### TransferState

```
TransferState
  transferId            UUID
  peerId                identifiant du pair
  direction             "upload" | "download"
  filename              nom du fichier
  totalBytes            taille totale
  transferredBytes      bytes transférés jusqu'ici
  totalChunks           nombre total de chunks
  lastCompleteChunk     dernier chunk écrit avec succès
  status                "pending" | "transferring" | "completed" | "failed" | "cancelled"
  progress              double (0.0 → 1.0) = transferredBytes / totalBytes
  startedAt             DateTime
  error                 String? (message d'erreur si failed)
```

---

## Protocole TEXT (via TextServer)

### Header

```json
{
  "sender_id": "uuid",
  "content_length": 42
}
```

### Envoi

```
[Utilisateur clique Envoyer]
  |
  |-- Créer un Message (direction = "sent", type = "text")
  |-- Ajouter dans messagesProvider(peerId)
  |     → UI met à jour le fil immédiatement
  |
  |-- Ouvrir une connexion TCP vers peer.ip:peer.textPort
  |-- Envoyer : header_length (4 bytes) + header JSON + body (texte UTF-8)
  |-- Fermer la connexion
  |
  |-- En cas d'erreur : marquer le message "failed"
```

### Réception

```
[TextServer accepte une connexion]
  |
  |-- Lire 4 bytes → header_length
  |-- Lire header_length bytes → header JSON
  |-- Lire content_length bytes → texte UTF-8
  |
  |-- Créer un Message (direction = "received", type = "text")
  |-- Ajouter dans messagesProvider(senderId)
  |-- Fermer la connexion
```

---

## Protocole FILE (via FileServer) — bidirectionnel avec ACK/RETRY

Le transfert de fichier est **bidirectionnel** sur une seule connexion
TCP. L'envoyeur envoie des paquets, le receveur répond par des paquets.
Même format : `header_length + header JSON + body`.

### Actions (champ "action" dans le header JSON)

#### Envoyeur → Receveur

```
"start"     début du transfert (métadonnées)
"chunk"     un morceau de fichier (avec checksum CRC32)
"end"       fin du transfert (avec checksum SHA-256 global)
"cancel"    annulation par l'envoyeur
"resume"    reprise d'un transfert interrompu
```

#### Receveur → Envoyeur

```
"ack"       chunk reçu et vérifié OK
"retry"     chunk corrompu, renvoyer (max 3 tentatives)
"ack_end"   transfert complet et vérifié
"error"     erreur fatale, abandon
```

---

## Envoi de fichier — logique de connexion avec fallback

L'envoyeur connaît les `file_ports` du pair via l'ANNOUNCE. Il tente
de se connecter en alternant entre les ports toutes les 200ms. Après
30 secondes sans connexion réussie → erreur.

```
[Envoyeur veut envoyer un fichier vers PC-Bureau]
  |
  |-- Lire peer.filePorts → [45232, 45233]
  |
  |-- Tentative 1 : connexion vers :45232
  |     Connexion réussie → démarrer le transfert
  |     Connexion refusée → attendre 200ms
  |
  |-- Tentative 2 : connexion vers :45233
  |     Connexion réussie → démarrer le transfert
  |     Connexion refusée → attendre 200ms
  |
  |-- Tentative 3 : connexion vers :45232
  |     ...
  |
  |-- Alternance :45232 → :45233 → :45232 → :45233 ...
  |   toutes les 200ms
  |
  |-- Après 30 secondes (150 tentatives) sans succès :
  |     Status → "failed"
  |     Erreur : "Aucun slot disponible sur le pair distant"
```

### Envoi de plusieurs fichiers

```
[Envoyeur envoie 3 fichiers, pair a 2 slots]
  |
  |-- Fichier 1 : tente :45232 → connecté → START
  |-- Fichier 2 : tente :45232 (occupé) → 200ms → :45233 → connecté → START
  |-- Fichier 3 : tente :45232 (occupé) → 200ms → :45233 (occupé) → 200ms
  |     → :45232 (occupé) → 200ms → :45233 (occupé) → 200ms
  |     → ... attend qu'un slot se libère ...
  |     → :45232 se libère → connecté → START
```

Chaque fichier tourne dans sa propre boucle de fallback, indépendamment.

---

## Séquence complète d'un transfert réussi

```
Envoyeur                                    Receveur (FileServer slot)
  │                                              │
  │── [connexion TCP établie sur un file_port] ──│
  │                                              │
  │── START ───────────────────────────────────► │
  │   { action: "start", transfer_id: "uuid",   │
  │     sender_id: "uuid",                       │
  │     filename: "rapport.pdf",                 │
  │     file_size: 2148576, chunk_size: 65536,   │
  │     total_chunks: 33 }                       │
  │                                              │ Crée rapport.pdf.part
  │                                              │ Crée TransferState
  │                                              │
  │── CHUNK 0 ─────────────────────────────────► │
  │   { action: "chunk", transfer_id: "uuid",   │
  │     chunk_index: 0, chunk_length: 65536,     │
  │     checksum: "crc32" }                      │
  │   + body [65536 bytes]                       │
  │                                              │ Vérifie CRC32
  │                                              │ Écrit sur disque (append)
  │◄── ACK ─────────────────────────────────────│
  │   { action: "ack", chunk_index: 0 }         │ Met à jour transferProvider
  │                                              │
  │── CHUNK 1 ─────────────────────────────────► │
  │◄── ACK ─────────────────────────────────────│
  │                                              │
  │   ... (chunks 2 à 31) ...                    │
  │                                              │
  │── CHUNK 32 (dernier, 50240 bytes) ─────────► │
  │◄── ACK ─────────────────────────────────────│
  │                                              │
  │── END ─────────────────────────────────────► │
  │   { action: "end", transfer_id: "uuid",     │
  │     checksum: "sha256_global" }              │
  │                                              │ Vérifie SHA-256 global
  │                                              │ Rename .part → fichier final
  │◄── ACK_END ────────────────────────────────│
  │   { action: "ack_end", transfer_id: "uuid" }│
  │                                              │
  [Connexion fermée, slot libéré]                │
```

---

## Séquence avec chunk corrompu et retry

```
Envoyeur                                    Receveur
  │                                              │
  │── CHUNK 5 (checksum: "abc123") ────────────► │
  │                                              │ CRC32 ne correspond pas
  │◄── RETRY ───────────────────────────────────│
  │   { action: "retry", chunk_index: 5,         │
  │     attempt: 1 }                             │
  │                                              │
  │── CHUNK 5 (renvoi) ───────────────────────► │
  │                                              │ CRC32 OK cette fois
  │◄── ACK ─────────────────────────────────────│
  │   { action: "ack", chunk_index: 5 }         │
  │                                              │
  │── CHUNK 6 ...                                │
```

---

## Séquence avec 3 retries échoués

```
Envoyeur                                    Receveur
  │                                              │
  │── CHUNK 5 ─────────────────────────────────► │ CRC32 KO
  │◄── RETRY { attempt: 1 } ───────────────────│
  │── CHUNK 5 (renvoi) ───────────────────────► │ CRC32 KO
  │◄── RETRY { attempt: 2 } ───────────────────│
  │── CHUNK 5 (renvoi) ───────────────────────► │ CRC32 KO
  │◄── RETRY { attempt: 3 } ───────────────────│
  │── CHUNK 5 (renvoi) ───────────────────────► │ CRC32 KO
  │                                              │
  │◄── ERROR ───────────────────────────────────│
  │   { action: "error", transfer_id: "uuid",   │
  │     reason: "chunk_corrupted",               │
  │     chunk_index: 5 }                         │
  │                                              │ Tronque le .part au chunk 4
  │                                              │ Status → "failed"
  [Connexion fermée, slot libéré]
```

---

## Séquence avec annulation

```
Envoyeur                                    Receveur
  │                                              │
  │── START → CHUNK 0 → ACK → CHUNK 1 → ACK    │
  │                                              │
  │  [Utilisateur clique Annuler]                │
  │                                              │
  │── CANCEL ──────────────────────────────────► │
  │   { action: "cancel", transfer_id: "uuid",  │
  │     reason: "user_cancelled" }               │
  │                                              │ Supprime le .part
  │                                              │ Status → "cancelled"
  [Connexion fermée, slot libéré]
```

---

## Séquence avec reprise

```
[Connexion 1 — coupure au chunk 14]

  │── START → CHUNK 0 → ACK → ... → CHUNK 14 → [COUPURE]
  │                                              │ Garde le .part (15 chunks OK)
  │                                              │ Slot libéré

[Connexion 2 — nouvelle tentative avec fallback sur les file_ports]

  │── RESUME ──────────────────────────────────► │
  │   { action: "resume", transfer_id: "uuid",  │
  │     sender_id: "uuid",                       │
  │     filename: "rapport.pdf",                 │
  │     file_size: 2148576, chunk_size: 65536,   │
  │     resume_from_chunk: 15 }                  │
  │                                              │ Vérifie que le .part existe
  │                                              │ Vérifie la taille (15 * 65536)
  │── CHUNK 15 ────────────────────────────────► │
  │◄── ACK ─────────────────────────────────────│
  │── CHUNK 16 ...                               │
  │   ...                                        │
  │── END { checksum } ────────────────────────► │
  │◄── ACK_END ────────────────────────────────│
  [Connexion fermée, slot libéré]
```

---

## Séquence avec checksum global KO

```
Envoyeur                                    Receveur
  │                                              │
  │── END { checksum: "sha256..." } ───────────► │
  │                                              │ SHA-256 calculé ≠ SHA-256 reçu
  │                                              │ Supprime le .part
  │◄── ERROR ───────────────────────────────────│
  │   { action: "error", transfer_id: "uuid",   │
  │     reason: "checksum_mismatch" }            │
  │                                              │ Status → "failed"
  [Connexion fermée, slot libéré]
```

---

## Écriture sur disque

### Append chunk par chunk

Chaque chunk vérifié est écrit immédiatement sur le disque via append :

```
rapport.pdf.part → append chunk 0 (64 KB)
rapport.pdf.part → append chunk 1 (64 KB)
rapport.pdf.part → append chunk 2 (64 KB)
...
Transfert terminé → rename rapport.pdf.part → rapport.pdf
```

### Troncature après erreur

Si un chunk s'écrit partiellement (disque plein, erreur I/O) :

```
Chunk 5 : écriture partielle (30 KB sur 64 KB)
  |
  |-- Tronquer le fichier à : lastCompleteChunk * chunkSize
  |     → Revient au dernier état propre (fin du chunk 4)
  |-- Status → "failed"
  |-- Le .part est conservé pour une reprise éventuelle
```

---

## Scénario multi-pairs

```
Pixel-8                    PC-Bureau (2 slots)              MacBook
  │                             │                              │
  │  Fichier 1 :                │                              │
  │  tente :45232 → connecté    │                              │
  │── START rapport.pdf ──────► │                              │
  │                             │  Fichier 2 :                 │
  │                             │◄── tente :45232 (occupé)     │
  │                             │    200ms                     │
  │                             │◄── tente :45233 → connecté ──│
  │                             │◄── START photo.jpg ──────────│
  │                             │                              │
  │  Fichier 3 :                │                              │
  │  tente :45232 (occupé)      │                              │
  │  200ms                      │                              │
  │  tente :45233 (occupé)      │                              │
  │  200ms                      │                              │
  │  tente :45232 (occupé)      │                              │
  │  ...                        │                              │
  │  :45232 se libère           │                              │
  │  tente :45232 → connecté    │                              │
  │── START video.mp4 ────────► │                              │
```

---

## Constantes

| Constante | Valeur | Description |
|-----------|--------|-------------|
| CHUNK_SIZE | 65536 (64 KB) | Taille d'un chunk |
| HEADER_LENGTH_SIZE | 4 bytes | Préfixe de taille du header |
| MAX_HEADER_SIZE | 4096 bytes | Taille max du header JSON |
| CONNECT_TIMEOUT | 5 secondes | Timeout connexion TCP |
| TRANSFER_TIMEOUT | 30 secondes | Timeout inactivité pendant transfert |
| SLOT_RETRY_INTERVAL | 200 ms | Intervalle entre les tentatives de connexion |
| SLOT_RETRY_TOTAL | 30 secondes | Durée max avant abandon (aucun slot libre) |
| MAX_RETRIES | 3 | Tentatives de renvoi d'un chunk corrompu |
| MAX_FILE_TRANSFERS | `.env` (défaut 2) | Nombre de slots fichier (ServerSocket) |
| TEXT_BACKLOG | 10 | Connexions en attente max sur le TextServer |
| FILE_BACKLOG | 0 | Aucune connexion en attente sur les slots fichier |

---

## Affichage dans l'UI

### Message texte

```
┌─ Moi ──────────────────┐
│ Salut, voici le doc    │
│                  14:32 │
└────────────────────────┘
```

### Fichier en cours de transfert

```
┌─ Moi ──────────────────┐
│  rapport.pdf           │
│  ████████░░░░  67%     │
│  1.4 MB / 2.1 MB       │
│  [Annuler]       14:33 │
└────────────────────────┘
```

### Deux fichiers en parallèle

```
┌─ Moi ──────────────────┐
│  rapport.pdf           │
│  ████████░░░░  67%     │
│  1.4 MB / 2.1 MB       │
│  [Annuler]             │
├────────────────────────┤
│  photo.jpg             │
│  ██░░░░░░░░░  15%     │
│  0.3 MB / 2.0 MB       │
│  [Annuler]       14:33 │
└────────────────────────┘
```

### Fichier en attente de slot

```
┌─ Moi ──────────────────┐
│  video.mp4             │
│  En attente d'un slot  │
│  [Annuler]       14:34 │
└────────────────────────┘
```

### Fichier transféré (terminé)

```
┌─ PC-Bureau ────────────┐
│  rapport.pdf (2.1 MB)  │
│  [Ouvrir] [Dossier]    │
│                  14:33 │
└────────────────────────┘
```

### Fichier échoué (aucun slot après 30s)

```
┌─ Moi ──────────────────┐
│  video.mp4             │
│  Aucun slot disponible │
│  [Réessayer]     14:34 │
└────────────────────────┘
```

### Fichier échoué (chunk corrompu)

```
┌─ Moi ──────────────────┐
│  rapport.pdf           │
│  Échec du transfert    │
│  [Réessayer]     14:33 │
└────────────────────────┘
```
