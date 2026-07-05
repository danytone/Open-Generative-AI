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

## Guida per chi non ha mai usato Xcode

Questa sezione spiega tutto da zero. **Non serve pagare** Apple: con un Apple ID gratuito puoi installare l'app sul tuo iPhone personale.

### Cosa ti serve

| Cosa | Perché |
|---|---|
| Un **Mac** (MacBook, iMac, Mac mini…) | Xcode funziona solo su macOS |
| Il tuo **iPhone** con iOS 17+ | Dove installerai l'app |
| Un **cavo Lightning/USB‑C** | Per collegare iPhone e Mac la prima volta |
| Un **Apple ID** (quello dell'iPhone va bene) | Per firmare l'app |
| **Chromecast** e server UPnP sulla stessa Wi‑Fi | Per usare l'app |

> **Non hai un Mac?** Purtroppo Apple non permette di compilare app iOS senza macOS. Alternative: chiedere a un amico con Mac, usare un Mac in cloud (MacStadium, ecc.), oppure valutare in futuro una versione distribuita via TestFlight.

---

### Passo 1 — Installa Xcode (solo la prima volta)

1. Sul Mac, apri l'**App Store**
2. Cerca **Xcode**
3. Clicca **Ottieni** / **Installa** (è gratuito, ma pesa ~12 GB)
4. Al termine, apri **Xcode** dalla cartella Applicazioni
5. Accetta la licenza e attendi che installi i componenti aggiuntivi

---

### Passo 2 — Scarica il progetto sul Mac

Apri l'app **Terminale** sul Mac (cerca "Terminale" con Spotlight: `Cmd + Spazio`) e incolla:

```bash
git clone https://github.com/danytone/Open-Generative-AI.git
cd Open-Generative-AI/apps/CastBridge
```

Se hai già il repository, vai solo nella cartella:

```bash
cd percorso/dove/hai/scaricato/Open-Generative-AI/apps/CastBridge
```

---

### Passo 3 — Installa le dipendenze (solo la prima volta)

Sempre nel Terminale, dentro la cartella `CastBridge`:

```bash
./setup.sh
```

Oppure manualmente:

```bash
sudo gem install cocoapods
pod install
```

Attendi che finisca senza errori. Questo passaggio scarica il SDK di Google Cast.

---

### Passo 4 — Apri il progetto in Xcode

Nel Terminale:

```bash
open CastBridge.xcworkspace
```

Si apre Xcode con il progetto. **Importante:** apri sempre il file `.xcworkspace`, **non** il `.xcodeproj`.

**Cosa vedi in Xcode:**

```
┌─────────────────────────────────────────────────────┐
│  ▶ CastBridge   [iPhone di Mario ▼]                 │  ← barra in alto
├──────────┬──────────────────────────────────────────┤
│ Navigator│  Codice sorgente dell'app               │
│ (sinistra)│                                         │
│          │                                         │
│ CastBridge│                                        │
│  ├ Models │                                        │
│  ├ Services│                                       │
│  └ Views  │                                        │
└──────────┴──────────────────────────────────────────┘
```

Non devi leggere il codice: ti serve solo la barra in alto e il pannello di sinistra.

---

### Passo 5 — Collega l'iPhone al Mac

1. Collega l'iPhone con il cavo
2. Sblocca l'iPhone
3. Se compare **"Autorizzare questo computer?"** → tocca **Autorizza**
4. In Xcode, nella barra in alto al centro, clicca sul menu a tendina (di default dice "iPhone 16" o simile)
5. Seleziona il **tuo iPhone** (appare con il nome che gli hai dato, es. "iPhone di Mario")

Se l'iPhone non compare: scollega e ricollega, sblocca il telefono, e attendi qualche secondo.

---

### Passo 6 — Configura la firma (solo la prima volta)

1. Nel pannello **sinistro** di Xcode, clicca sulla riga blu in cima chiamata **CastBridge** (icona con la "A")
2. Al centro compare una lista: sotto **TARGETS** seleziona **CastBridge**
3. Clicca la scheda **Signing & Capabilities** in alto
4. Spunta ✅ **Automatically manage signing**
5. Nel menu **Team**, scegli il tuo Apple ID
   - Se non c'è: clicca **Add Account…**, accedi con il tuo Apple ID, poi selezionalo
6. Se compare un errore sul **Bundle Identifier**, cambialo in qualcosa di unico, es. `com.tuonome.castbridge`

---

### Passo 7 — Installa l'app sull'iPhone

1. Clicca il pulsante **▶ Play** in alto a sinistra (oppure premi `Cmd + R`)
2. Xcode compila l'app (la prima volta può richiedere 1–3 minuti)
3. L'app viene installata e si apre sull'iPhone

**Se l'iPhone dice "Sviluppatore non attendibile":**

1. Su iPhone: **Impostazioni → Generali → VPN e gestione dispositivo**
2. Tocca il tuo Apple ID sotto "App per sviluppatori"
3. Tocca **Autorizza** e conferma

Poi riapri l'app **CastBridge** dall'icona sulla home.

---

### Passo 8 — Usa CastBridge

1. All'avvio, consenti l'accesso alla **rete locale** quando richiesto
2. L'app cerca automaticamente i server UPnP
3. Tocca un server → scegli un video
4. Tocca l'icona **Cast** (TV) in alto a destra → seleziona il Chromecast
5. Il video parte sulla TV

---

### Domande frequenti per principianti

**Devo modificare il codice?** No. Devi solo aprire il progetto e premere Play.

**L'app resta sull'iPhone per sempre?** Con un Apple ID gratuito l'app scade dopo ~7 giorni. Basta ricollegare l'iPhone al Mac e premere di nuovo ▶ Play.

**Posso pubblicarla sull'App Store?** Sì, ma serve un account Apple Developer a pagamento (99 €/anno). Per uso personale non serve.

**Xcode dà errore su "pod install"?** Assicurati di aver eseguito `pod install` e di aver aperto `CastBridge.xcworkspace`, non `.xcodeproj`.

**Non ho server UPnP** — Puoi usare la scheda **URL diretto** per incollare un link HTTP a un video sul tuo NAS o PC.

---

## Installazione (versione rapida)

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
