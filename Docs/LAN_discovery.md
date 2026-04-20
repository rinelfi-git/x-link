# Découverte LAN — Protocole UDP

Plan détaillé de la découverte des pairs sur le réseau local via UDP
broadcast pour Cross Link (version gratuite).

---

## Configuration

Le port de découverte UDP est configurable via le fichier `.env` :

```
CROSSLINK_DISCOVERY_PORT=53317
```

Tous les pairs sur le même réseau doivent utiliser le même port pour se
découvrir mutuellement.

---

## Vue d'ensemble

```
┌──────────┐  broadcast ANNOUNCE  ┌──────────┐
│ Pair A   │ ──────────────────> │ Pair B   │
│          │ <────────────────── │          │
│          │  unicast ANNOUNCE   │          │
│          │                     │          │
│          │  HEARTBEAT (5s)     │          │
│          │ ──────────────────> │          │
│          │ <────────────────── │          │
│          │                     │          │
│          │  LEAVE (fermeture)  │          │
│          │ ──────────────────> │          │
└──────────┘                     └──────────┘

Tout passe en UDP sur un port unique (défaut : 53317).
```

---

## Principe clé : l'IP vient du datagramme, pas du payload

L'adresse IP d'un pair n'est **jamais** incluse dans le payload JSON.
Elle est extraite de l'adresse source du datagramme UDP reçu
(`datagram.address` en Dart).

Pourquoi :

- Un pair peut avoir plusieurs interfaces réseau (Wi-Fi + Ethernet,
  VPN, etc.)
- Chaque réseau voit une IP source différente dans le datagramme
- L'IP du datagramme est **toujours** celle par laquelle le pair est
  joignable sur ce réseau précis
- Mettre l'IP dans le JSON créerait une ambiguïté : quelle IP choisir
  quand le pair a plusieurs interfaces ?

Le payload ANNOUNCE contient uniquement
`{ id, hostname, os, text_port, file_ports }`. L'IP est déduite du
transport.

---

## Étape 1 — Démarrage et annonce initiale

```
[App démarre]
  |
  |-- Lit CROSSLINK_DISCOVERY_PORT depuis .env (défaut : 53317)
  |-- Génère un UUID de session (identifiant unique pour cette exécution)
  |-- Récupère le hostname et l'OS de la machine
  |-- Ouvre le TextServer TCP sur un port dynamique (port 0 → l'OS attribue)
  |-- Ouvre le FileServer TCP sur un port dynamique
  |-- Bind un socket UDP sur le port de découverte
  |
  |-- Envoie un broadcast UDP sur 255.255.255.255:DISCOVERY_PORT
  |     Message : ANNOUNCE avec { id, hostname, os, text_port, file_port }
  |
  |-- Tous les pairs qui reçoivent l'ANNOUNCE répondent avec leur propre
  |   ANNOUNCE en unicast vers l'IP source du datagramme
  |     → Le nouveau pair découvre immédiatement les pairs existants
```

---

## Étape 2 — Écoute continue

```
[Boucle d'écoute UDP — tourne en permanence]
  |
  |-- Reçoit un datagramme UDP
  |-- Extraire l'IP source depuis datagram.address (PAS depuis le JSON)
  |-- Parse le message : CROSSLINK|version|type|payload_json
  |
  |-- Si type = ANNOUNCE :
  |     Si le pair est inconnu → l'ajouter à la liste avec l'IP du datagramme
  |     Si le pair est connu → mettre à jour last_seen_at et l'IP
  |     Répondre avec son propre ANNOUNCE en unicast vers datagram.address
  |       (uniquement si le message reçu était un broadcast)
  |
  |-- Si type = HEARTBEAT :
  |     Si le pair est connu → mettre à jour last_seen_at
  |     Si le pair est inconnu → ignorer
  |
  |-- Si type = LEAVE :
  |     Retirer le pair de la liste immédiatement
  |
  |-- Ignorer les messages dont le sender_id = notre propre id
  |     (on reçoit nos propres broadcasts)
```

---

## Étape 3 — Heartbeat périodique

```
[Timer — toutes les 5 secondes]
  |
  |-- Envoie un broadcast UDP HEARTBEAT avec { id }
  |     → Confirme aux autres pairs qu'on est toujours là
  |
  |-- Parcourt la liste des pairs connus
  |     Pour chaque pair :
  |       Si last_seen_at > 15 secondes (3 heartbeats manqués)
  |         → Retirer le pair de la liste (considéré déconnecté)
```

---

## Étape 4 — Annonce de départ

```
[App se ferme (dispose / onClose)]
  |
  |-- Envoie un broadcast UDP LEAVE avec { id }
  |     → Les autres pairs le retirent immédiatement sans attendre le timeout
  |
  |-- Ferme le socket UDP
  |-- Ferme le TextServer TCP
  |-- Ferme le FileServer TCP
```

---

## Étape 5 — Gestion des cas limites

```
[Changement de réseau / perte de connexion]
  |
  |-- Détection via NetworkInterface.list() (polling ou écoute)
  |-- Si changement d'interface réseau :
  |     Vider la liste des pairs
  |     Ré-envoyer un ANNOUNCE broadcast sur le nouveau réseau

[Crash / fermeture non propre]
  |
  |-- Le pair ne peut pas envoyer LEAVE
  |-- Les autres pairs le détectent via le timeout heartbeat (15s)
  |     → Retrait automatique de la liste

[Réception d'un message d'un protocole inconnu]
  |
  |-- Le datagramme ne commence pas par CROSSLINK|
  |     → Ignorer silencieusement

[Plusieurs interfaces réseau]
  |
  |-- Envoyer le broadcast sur toutes les interfaces réseau actives
  |     ou sur l'adresse broadcast de chaque sous-réseau
  |-- L'IP du pair est toujours celle du datagramme reçu
  |     → Chaque réseau voit la bonne IP naturellement

[Reconfiguration du FileServer]
  |
  |-- L'utilisateur change le nombre de transferts simultanés
  |-- Le FileServer se reconfigure (nouveau port potentiel)
  |-- Broadcast immédiat d'un ANNOUNCE avec les nouveaux ports
  |     → Les pairs mettent à jour text_port/file_ports du pair
```

---

## Format des messages UDP

```
CROSSLINK|1|type|payload_json
```

Le préfixe `CROSSLINK|1|` identifie le protocole et sa version.
Le payload est du JSON encodé en UTF-8.

### Messages

```
// ANNOUNCE — au démarrage, en réponse à un ANNOUNCE, ou après reconfiguration
CROSSLINK|1|ANNOUNCE|{"id":"uuid","hostname":"PC-Bureau","os":"linux","text_port":45231,"file_ports":[45232,45233]}

// HEARTBEAT — envoyé toutes les 5 secondes
CROSSLINK|1|HEARTBEAT|{"id":"uuid"}

// LEAVE — envoyé à la fermeture de l'app
CROSSLINK|1|LEAVE|{"id":"uuid"}
```

Pas d'adresse IP dans le JSON. L'IP est extraite du datagramme UDP.

---

## Modèle Peer en mémoire

```
Peer
  id                    UUID de session
  hostname              "PC-Bureau"
  os                    "linux" | "windows" | "macos" | "android" | "ios"
  ip                    adresse IP extraite du datagramme UDP (PAS du JSON)
  text_port             port TCP pour les messages texte
  file_ports            List<int> — ports TCP pour les transferts de fichiers
  last_seen_at          DateTime du dernier message reçu (ANNOUNCE ou HEARTBEAT)
```

Stocké dans un `Map<String, Peer>` en mémoire (clé = id). Aucune base
de données. Perdu à la fermeture.

---

## Constantes

| Constante | Valeur | Description |
|-----------|--------|-------------|
| DISCOVERY_PORT | `.env` (défaut 53317) | Port UDP de découverte |
| HEARTBEAT_INTERVAL | 5 secondes | Fréquence d'envoi des heartbeats |
| PEER_TIMEOUT | 15 secondes | Délai avant retrait d'un pair |
| PROTOCOL_PREFIX | `CROSSLINK\|1` | Préfixe protocole + version |

---

## Diagramme de séquence — nouveau pair rejoint le réseau

```
     Pair A (existant)          Pair B (existant)          Pair C (nouveau)
          |                          |                          |
          |                          |           [démarre l'app]|
          |                          |                          |
          |<─── broadcast ANNOUNCE ──────────────────────────── |
          |                          |<─── broadcast ANNOUNCE ──|
          |                          |                          |
          |─── unicast ANNOUNCE ────────────────────────────── >|
          |                          |─── unicast ANNOUNCE ──── >|
          |                          |                          |
          |     [C connaît A et B]   |     [C connaît A et B]  |
          |     [A connaît C]        |     [B connaît C]       |
          |                          |                          |
          |<─── broadcast HEARTBEAT ─────────────────────────── |  (5s)
          |                          |<─── broadcast HEARTBEAT ─|  (5s)
          |                          |                          |
```

---

## Diagramme de séquence — pair quitte le réseau

```
     Pair A                     Pair B                     Pair C
          |                          |                          |
          |                          |              [ferme l'app]|
          |                          |                          |
          |<─── broadcast LEAVE ─────────────────────────────── |
          |                          |<─── broadcast LEAVE ──── |
          |                          |                          |
          |  [retire C de la liste]  | [retire C de la liste]  |
          |                          |                          |
```

---

## Diagramme de séquence — crash d'un pair

```
     Pair A                     Pair B                     Pair C
          |                          |                          |
          |                          |                     [CRASH]
          |                          |                          X
          |                          |
          |  ... 5s ... pas de heartbeat de C
          |  ... 10s ... pas de heartbeat de C
          |  ... 15s ... timeout atteint
          |                          |
          |  [retire C de la liste]  | [retire C de la liste]
          |                          |
```
