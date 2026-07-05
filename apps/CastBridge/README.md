# CastBridge

**CastBridge** è un'app iOS che scopre server multimediali **UPnP/DLNA** sulla rete locale e permette di **streammare video su Chromecast** direttamente dal tuo iPhone.

## Funzionalità

- **Discovery automatica** dei server UPnP/DLNA (MiniDLNA, Jellyfin DLNA, Plex, NAS Synology/QNAP, ecc.)
- **Navigazione cartelle** e selezione video dal server
- **Streaming su Chromecast** tramite Google Cast SDK
- **URL diretto** per stream HTTP/HLS (`.mp4`, `.m3u8`, ecc.)
- **Server manuale** se la discovery automatica non trova il dispositivo

## Requisiti

| Componente | Versione |
|---|---|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| CocoaPods | 1.12+ |
| Rete | iPhone, Chromecast e server UPnP sulla **stessa LAN** |

## Installazione

### 1. Clona il repository e vai alla cartella dell'app

```bash
cd apps/CastBridge
```

### 2. Installa le dipendenze CocoaPods

```bash
sudo gem install cocoapods   # se non già installato
pod install
```

### 3. Apri il workspace (non il progetto .xcodeproj)

```bash
open CastBridge.xcworkspace
```

> Dopo `pod install`, usa sempre il file `.xcworkspace`.

### 4. Configura il signing

1. Seleziona il target **CastBridge** in Xcode
2. Vai su **Signing & Capabilities**
3. Imposta il tuo **Team** Apple Developer
4. Modifica il **Bundle Identifier** se necessario (es. `com.tuonome.castbridge`)

### 5. Compila e installa su iPhone

Collega il tuo iPhone, selezionalo come destinazione e premi **Run** (⌘R).

## Utilizzo

```
┌─────────────┐     Wi‑Fi LAN      ┌──────────────┐
│   iPhone    │◄──────────────────►│ Server UPnP  │
│  CastBridge │                    │ (NAS/DLNA)   │
└──────┬──────┘                    └──────▲───────┘
       │ Cast (controllo)                │
       │                                 │ HTTP stream
       ▼                                 │
┌─────────────┐──────────────────────────┘
│ Chromecast  │  scarica il video direttamente dal server
└─────────────┘
```

1. Apri **CastBridge** sul tuo iPhone
2. Attendi la ricerca automatica dei server, oppure aggiungi un URL manuale
3. Tocca un server → naviga le cartelle → seleziona un video
4. Tocca il pulsante **Cast** (icona TV) e scegli il Chromecast
5. Il video viene riprodotto sulla TV

### Scheda "URL diretto"

Per server che non espongono UPnP o per flussi HLS personalizzati:

```
http://192.168.1.10:8080/live/stream.m3u8
http://nas.local/videos/film.mp4
```

## Server compatibili

L'app funziona con qualsiasi server che espone il servizio **ContentDirectory UPnP**:

- **MiniDLNA** / **ReadyMedia**
- **Jellyfin** (con DLNA abilitato)
- **Plex** (con DLNA abilitato)
- **Servizi DLNA integrati** in Synology, QNAP, Western Digital
- **Kodi** (con server UPnP attivo)
- Server personalizzati con API UPnP standard

## Formati video supportati

Il Chromecast riproduce direttamente i formati che supporta nativamente:

| Formato | MIME type | Note |
|---|---|---|
| MP4 (H.264/AAC) | `video/mp4` | ✅ Consigliato |
| HLS | `application/vnd.apple.mpegurl` | ✅ `.m3u8` |
| WebM | `video/webm` | Dipende dal modello Chromecast |
| MKV | `video/x-matroska` | ⚠️ Potrebbe richiedere transcoding |

> **Nota:** MKV e AVI spesso non sono riproducibili nativamente su Chromecast. In questi casi configura il server per il transcoding in MP4/HLS.

## Permessi iOS

L'app richiede accesso alla **rete locale** per:

- Discovery SSDP dei server UPnP (multicast `239.255.255.250:1900`)
- Comunicazione con Chromecast (Bonjour `_googlecast._tcp`)

Al primo avvio iOS chiederà il permesso di accesso alla rete locale: **consenti** per far funzionare discovery e Cast.

## Architettura

```
CastBridge/
├── Models/
│   └── UPnPModels.swift          # Modelli dati
├── Services/
│   ├── SSDPClient.swift          # Discovery multicast SSDP
│   ├── UPnPDeviceParser.swift    # Parsing device description XML
│   ├── ContentDirectoryService.swift  # Browsing SOAP ContentDirectory
│   ├── UPnPViewModels.swift      # ViewModel discovery e browser
│   └── CastManager.swift         # Wrapper Google Cast SDK
└── Views/
    ├── ServerListView.swift      # Lista server trovati
    ├── MediaBrowserView.swift    # Browser cartelle/video
    ├── ManualStreamView.swift    # URL diretto
    └── CastViews.swift           # Pulsante Cast e mini controller
```

## Risoluzione problemi

### Nessun server trovato
- Verifica che iPhone e server siano sulla stessa rete Wi‑Fi (non rete ospiti)
- Disattiva VPN sul telefono
- Aggiungi manualmente l'URL del server (es. `http://192.168.1.10:8200`)

### Chromecast non appare
- Chromecast e iPhone devono essere sulla stessa rete
- Riavvia l'app e il Chromecast
- Verifica che il router non blocchi il traffico mDNS/Bonjour

### Video non parte sul Chromecast
- Il Chromecast deve poter raggiungere l'URL del server (stessa LAN)
- Prova con un file MP4 H.264 invece di MKV
- Controlla che il server non richieda autenticazione per il download diretto

### Errore "Google Cast SDK non installato"
- Esegui `pod install` e apri `CastBridge.xcworkspace`

## Licenza

Parte del progetto Open Generative AI. Uso libero per scopi personali.
