> Questa traduzione è stata generata da Claude. Se hai suggerimenti per migliorarla, apri una PR.

<h1 align="center">bmux</h1>
<p align="center">Un terminale macOS basato su Ghostty con schede verticali e notifiche per agenti di programmazione AI</p>

<p align="center">
  <a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
    <img src="../assets/macos-badge.png" alt="Scarica bmux per macOS" width="180" />
  </a>
</p>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.vi.md">Tiếng Việt</a> | <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.de.md">Deutsch</a> | <a href="README.es.md">Español</a> | <a href="README.fr.md">Français</a> | Italiano | <a href="README.da.md">Dansk</a> | <a href="README.pl.md">Polski</a> | <a href="README.ru.md">Русский</a> | <a href="README.bs.md">Bosanski</a> | <a href="README.ar.md">العربية</a> | <a href="README.no.md">Norsk</a> | <a href="README.pt-BR.md">Português (Brasil)</a> | <a href="README.th.md">ไทย</a> | <a href="README.tr.md">Türkçe</a> | <a href="README.km.md">ភាសាខ្មែរ</a> | <a href="README.uk.md">Українська</a>
</p>

<p align="center">
  <a href="https://x.com/manaflowai"><img src="https://img.shields.io/badge/@manaflow-555?logo=x" alt="X / Twitter" /></a>
  <a href="https://discord.gg/xsgFEVrWCZ"><img src="https://img.shields.io/badge/Discord-555?logo=discord" alt="Discord" /></a>
  <a href="https://github.com/manaflow-ai/bmux"><img src="https://img.shields.io/github/stars/manaflow-ai/bmux?style=flat&logo=github&label=stars&color=4c71f2" alt="GitHub stars" /></a>
</p>

<p align="center">
  <img src="../assets/main-first-image.png" alt="Screenshot di bmux" width="900" />
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=i-WxO5YUTOs">▶ Video demo</a> · <a href="https://bmux.com/blog/zen-of-bmux">The Zen of bmux</a>
</p>

## Funzionalità

<table>
<tr>
<td width="40%" valign="middle">
<h3>Anelli di notifica</h3>
I pannelli ricevono un anello blu e le schede si illuminano quando gli agenti di programmazione richiedono la tua attenzione
</td>
<td width="60%">
<img src="../assets/notification-rings.png" alt="Anelli di notifica" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Pannello notifiche</h3>
Visualizza tutte le notifiche in sospeso in un unico posto, salta alla più recente non letta
</td>
<td width="60%">
<img src="../assets/sidebar-notification-badge.png" alt="Badge notifica nella barra laterale" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Browser integrato</h3>
Dividi un browser accanto al tuo terminale con un'API scriptabile derivata da <a href="https://github.com/vercel-labs/agent-browser">agent-browser</a>
</td>
<td width="60%">
<img src="../assets/built-in-browser.png" alt="Browser integrato" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Schede verticali + orizzontali</h3>
La barra laterale mostra il branch git, lo stato/numero della PR collegata, la directory di lavoro, le porte in ascolto e il testo dell'ultima notifica. Dividi orizzontalmente e verticalmente.
</td>
<td width="60%">
<img src="../assets/vertical-horizontal-tabs-and-splits.png" alt="Schede verticali e pannelli divisi" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>SSH</h3>
<code>bmux ssh user@remote</code> crea un workspace per una macchina remota. I pannelli del browser vengono instradati attraverso la rete remota, quindi localhost funziona direttamente. Trascina un'immagine in una sessione remota per caricarla via scp.
</td>
<td width="60%">
<img src="../assets/ssh.png" alt="bmux SSH" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Claude Code Teams</h3>
<code>bmux claude-teams</code> avvia la modalità teammate di Claude Code con un solo comando. I teammate appaiono come divisioni native con metadati nella barra laterale e notifiche. Non serve tmux.
</td>
<td width="60%">
<img src="../assets/claude-code-teams.png" alt="Claude Code Teams" width="100%" />
</td>
</tr>
</table>

- **Import browser** — Importa cookie, cronologia e sessioni da Chrome, Firefox, Arc e oltre 20 browser in modo che i pannelli del browser partano già autenticati
- **Comandi personalizzati** — Definisci azioni specifiche per il progetto in [`bmux.json`](https://bmux.com/docs/custom-commands) che si lanciano dalla palette dei comandi
- **Scriptabile** — CLI e socket API per creare workspace, dividere pannelli, inviare sequenze di tasti e automatizzare il browser
- **App macOS nativa** — Costruita con Swift e AppKit, non Electron. Avvio rapido, basso consumo di memoria.
- **Compatibile con Ghostty** — Legge la tua configurazione esistente `~/.config/ghostty/config` per temi, font e colori
- **Accelerazione GPU** — Alimentato da libghostty per un rendering fluido
- **Scorciatoie da tastiera** — [Scorciatoie estese](https://bmux.com/docs/keyboard-shortcuts) per workspace, divisioni, browser e altro
- **Open source** — Gratuito e con licenza GPL

## Installazione

### DMG (consigliato)

<a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
  <img src="../assets/macos-badge.png" alt="Scarica bmux per macOS" width="180" />
</a>

Apri il file `.dmg` e trascina bmux nella cartella Applicazioni. bmux si aggiorna automaticamente tramite Sparkle, quindi devi scaricarlo solo una volta.

### Homebrew

```bash
brew tap manaflow-ai/bmux
brew install --cask bmux
```

Per aggiornare in seguito:

```bash
brew upgrade --cask bmux
```

Al primo avvio, macOS potrebbe chiederti di confermare l'apertura di un'app da uno sviluppatore identificato. Fai clic su **Apri** per procedere.

## Perché bmux?

Eseguo molte sessioni di Claude Code e Codex in parallelo. Usavo Ghostty con un mucchio di pannelli divisi, e mi affidavo alle notifiche native di macOS per sapere quando un agente aveva bisogno di me. Ma il corpo della notifica di Claude Code è sempre solo "Claude is waiting for your input" senza contesto, e con abbastanza schede aperte non riuscivo nemmeno più a leggere i titoli.

Ho provato alcuni orchestratori di codifica, ma la maggior parte erano app Electron/Tauri e le prestazioni mi infastidivano. Inoltre preferisco semplicemente il terminale dato che gli orchestratori con interfaccia grafica ti vincolano al loro flusso di lavoro. Così ho costruito bmux come app macOS nativa in Swift/AppKit. Usa libghostty per il rendering del terminale e legge la tua configurazione Ghostty esistente per temi, font e colori.

Le aggiunte principali sono la barra laterale e il sistema di notifiche. La barra laterale ha schede verticali che mostrano il branch git, lo stato/numero della PR collegata, la directory di lavoro, le porte in ascolto e il testo dell'ultima notifica per ogni workspace. Il sistema di notifiche rileva le sequenze terminale (OSC 9/99/777) e ha un CLI (`bmux notify`) che puoi collegare agli hook degli agenti per Claude Code, OpenCode, ecc. Quando un agente è in attesa, il suo pannello riceve un anello blu e la scheda si illumina nella barra laterale, così posso capire quale ha bisogno di me tra divisioni e schede. Cmd+Shift+U salta alla più recente non letta.

Il browser integrato ha un'API scriptabile derivata da [agent-browser](https://github.com/vercel-labs/agent-browser). Gli agenti possono acquisire l'albero di accessibilità, ottenere riferimenti agli elementi, fare clic, compilare moduli e valutare JS. Puoi dividere un pannello browser accanto al tuo terminale e far interagire Claude Code direttamente con il tuo server di sviluppo.

Tutto è scriptabile attraverso il CLI e la socket API — creare workspace/schede, dividere pannelli, inviare sequenze di tasti, aprire URL nel browser.

## The Zen of bmux

bmux non prescrive come gli sviluppatori usano i propri strumenti. È un terminale e un browser con un CLI, il resto dipende da te.

bmux è una primitiva, non una soluzione. Ti dà un terminale, un browser, notifiche, workspace, divisioni, schede e un CLI per controllare tutto. bmux non ti obbliga a usare gli agenti di programmazione in un modo predefinito. Quello che costruisci con le primitive è tuo.

I migliori sviluppatori hanno sempre costruito i propri strumenti. Nessuno ha ancora trovato il modo migliore di lavorare con gli agenti, e i team che costruiscono prodotti chiusi non l'hanno trovato nemmeno loro. Gli sviluppatori più vicini alle proprie basi di codice lo troveranno per primi.

Date a un milione di sviluppatori primitive componibili e troveranno collettivamente i flussi di lavoro più efficienti più velocemente di quanto qualsiasi team di prodotto potrebbe progettare dall'alto.

## Documentazione

Per maggiori informazioni su come configurare bmux, [consulta la nostra documentazione](https://bmux.com/docs/getting-started?utm_source=readme).

## Scorciatoie da Tastiera

### Workspace

| Scorciatoia | Azione |
|----------|--------|
| ⌘ N | Nuovo workspace |
| ⌘ 1–8 | Vai al workspace 1–8 |
| ⌘ 9 | Vai all'ultimo workspace |
| ⌃ ⌘ ] | Workspace successivo |
| ⌃ ⌘ [ | Workspace precedente |
| ⌘ ⇧ W | Chiudi workspace |
| ⌘ ⇧ R | Rinomina workspace |
| ⌥ ⌘ E | Modifica descrizione del workspace |
| ⌘ B | Mostra/nascondi barra laterale |
| ⌥ ⌘ B | Mostra/nascondi barra laterale destra |
| ⌘ ⇧ E | Attiva/disattiva il focus della barra laterale destra |

### Superfici

| Scorciatoia | Azione |
|----------|--------|
| ⌘ T | Nuova superficie |
| ⌘ ⇧ ] | Superficie successiva |
| ⌘ ⇧ [ | Superficie precedente |
| ⌃ Tab | Superficie successiva |
| ⌃ ⇧ Tab | Superficie precedente |
| ⌃ 1–8 | Vai alla superficie 1–8 |
| ⌃ 9 | Vai all'ultima superficie |
| ⌘ W | Chiudi superficie |

### Pannelli Divisi

| Scorciatoia | Azione |
|----------|--------|
| ⌘ D | Dividi a destra |
| ⌘ ⇧ D | Dividi in basso |
| ⌥ ⌘ ← → ↑ ↓ | Sposta il focus direzionalmente |
| ⌘ ⇧ H | Lampeggia pannello focalizzato |

### Browser

Le scorciatoie degli strumenti di sviluppo del browser seguono i valori predefiniti di Safari e sono personalizzabili in `Impostazioni → Scorciatoie da tastiera`.
Le scorciatoie di navigazione della palette dei comandi, inclusa ⌃ P, sono anch'esse personalizzabili e possono essere cancellate in modo che la pressione raggiunga il terminale attivo.

| Scorciatoia | Azione |
|----------|--------|
| ⌘ ⇧ L | Apri browser in divisione |
| ⌘ L | Focus sulla barra degli indirizzi |
| ⌘ [ | Indietro |
| ⌘ ] | Avanti |
| ⌘ R | Ricarica pagina |
| ⌥ ⌘ I | Mostra/Nascondi Strumenti di Sviluppo (predefinito Safari) |
| ⌥ ⌘ C | Mostra Console JavaScript (predefinito Safari) |

### Notifiche

| Scorciatoia | Azione |
|----------|--------|
| ⌘ I | Mostra pannello notifiche |
| ⌘ ⇧ U | Vai all'ultima non letta |
| ⌥ ⌘ U | Attiva/disattiva lo stato non letto dell'elemento corrente |
| ⌃ ⌘ U | Segna l'elemento corrente come la non letta più vecchia e salta alla successiva più recente non letta |

### Cerca

| Scorciatoia | Azione |
|----------|--------|
| ⌘ F | Cerca |
| ⌘ ⇧ F | Cerca nella directory |
| ⌘ G / ⌥ ⌘ G | Trova successivo / precedente |
| ⌥ ⌘ ⇧ F | Nascondi barra di ricerca |
| ⌘ E | Usa selezione per la ricerca |

### Terminale

| Scorciatoia | Azione |
|----------|--------|
| ⌘ K | Cancella scrollback |
| ⌘ C | Copia (con selezione) |
| ⌘ V | Incolla |
| ⌘ + / ⌘ - | Aumenta / diminuisci dimensione font |
| ⌘ 0 | Ripristina dimensione font |

### Finestra

| Scorciatoia | Azione |
|----------|--------|
| ⌘ ⇧ N | Nuova finestra |
| ⌘ ⇧ O | Riapri sessione precedente |
| ⌘ , | Impostazioni |
| ⌘ ⇧ , | Ricarica configurazione |
| ⌘ Q | Esci |

## Build Nightly

[Scarica bmux NIGHTLY](https://github.com/manaflow-ai/bmux/releases/download/nightly/bmux-nightly-macos.dmg)

bmux NIGHTLY è un'app separata con il proprio bundle ID, quindi funziona in parallelo alla versione stabile. Compilata automaticamente dall'ultimo commit `main` e aggiornata automaticamente tramite il proprio feed Sparkle.

Segnala i bug delle nightly su [GitHub Issues](https://github.com/manaflow-ai/bmux/issues) o in [#nightly-bugs su Discord](https://discord.gg/xsgFEVrWCZ).

## Ripristino sessione

Alla chiusura, bmux salva la sessione corrente. Al riavvio, bmux ripristina lo stato
gestito dall'app:
- Layout di finestre/workspace/pannelli
- Directory di lavoro
- Scrollback del terminale (best effort)
- URL del browser e cronologia di navigazione

bmux non crea checkpoint per processi attivi arbitrari. tmux, vim, shell e app terminale
non supportate si riaprono come terminali normali.

Le sessioni degli agent supportati possono riprendere quando gli hook hanno salvato un ID
sessione nativo. Installa gli hook dopo aver installato il CLI dell'agente in modo che il suo
binario sia nel `PATH`:

```bash
bmux hooks setup
bmux hooks setup codex
bmux hooks setup --agent opencode
```

`bmux hooks setup` installa gli agent supportati che trova e stampa un riepilogo
degli agent saltati. Le integrazioni di ripristino supportate includono Claude Code, Codex,
Grok, OpenCode, Pi, Amp, Cursor CLI, Gemini, Rovo Dev, Copilot, CodeBuddy,
Factory e Qoder. Claude Code è gestito dal wrapper Claude di bmux quando l'integrazione
Claude è abilitata nelle Impostazioni.

Utenti avanzati e integrazioni possono associare un comando di ripristino personalizzato alla
surface del terminale corrente. È utile per strumenti con stato persistente proprio, come
sessioni tmux o CLI agent personalizzate:

```bash
bmux surface resume set --kind tmux --checkpoint work --shell "tmux attach -t work"
bmux surface resume show --json
bmux surface resume clear --checkpoint work
```

L'associazione resta legata alla surface di bmux. Le associazioni create dal CLI pubblico o dal
socket vengono salvate per ispezione e ripristino manuale, a meno che tu non approvi un prefisso
di comando firmato per il ripristino automatico. I prefissi approvati sono anche legati alla
directory di lavoro e ai valori esatti dell'ambiente, quando presenti. Esamina o modifica le
approvazioni in **Impostazioni > Terminale > Comandi di ripristino**. bmux esegue automaticamente
solo le associazioni di resume che marca come attendibili, per esempio quelle tmux rilevate dai
processi attivi o i prefissi approvati dall'utente. Le chiavi di ambiente sensibili, come token,
password, segreti e chiavi API, vengono scartate prima di salvare un'associazione di resume.

Per mantenere inattivi i terminali degli agent ripristinati invece di eseguire automaticamente i loro comandi di ripristino,
disattiva **Impostazioni > Terminale > Riprendi sessioni agent alla riapertura** o imposta questo in
`~/.config/bmux/bmux.json`:

```json
{
  "terminal": {
    "autoResumeAgentSessions": false
  }
}
```

Questo disattiva solo i comandi di ripristino automatico degli agent. bmux continua a ripristinare il layout salvato,
le directory di lavoro, lo scrollback e la cronologia del browser.

Se devi riapplicare manualmente l'ultima istantanea salvata, usa:
- `File > Riapri sessione precedente`
- `⌘ ⇧ O`
- `bmux restore-session`

Internamente, bmux scrive un'istantanea versionata in
`~/Library/Application Support/bmux/` e gli hook degli agent scrivono le mappature di sessione
in `~/.bmuxterm/`. Al ripristino, bmux ricostruisce prima il layout, poi esegue il comando
di ripristino nativo dell'agent supportato quando il ripristino automatico degli agent è abilitato.

Leggi la guida completa su <https://bmux.com/docs/session-restore>.

## FAQ

### Che relazione c'è tra bmux e Ghostty?

bmux non è un fork di Ghostty. Usa [libghostty](https://github.com/ghostty-org/ghostty) come libreria per il rendering del terminale, allo stesso modo in cui le app usano WebKit per le viste web. Ghostty è un terminale autonomo; bmux è un'app diversa costruita sopra il suo motore di rendering.

### Quali piattaforme supporta?

Solo macOS, per ora. bmux è un'app nativa Swift + AppKit.

### C'è un'app iOS?

Sì, in beta. Associa il tuo iPhone al tuo Mac dalla finestra Mobile Connect e connettiti ai tuoi terminali dal telefono, con inoltro opzionale delle notifiche del terminale. È distribuita su TestFlight come bmux BETA. Consulta la [documentazione iOS](https://bmux.com/docs/ios).

### Con quali agenti di programmazione funziona bmux?

Con tutti. bmux è un terminale, quindi qualsiasi agente che gira in un terminale funziona da subito: Claude Code, Codex, OpenCode, Gemini CLI, Kiro, Aider, Goose, Amp, Cline, Cursor Agent e qualsiasi altra cosa tu possa lanciare dalla riga di comando.

### bmux può orchestrare più agenti e subagenti?

Sì. Quando un agente genera subagenti o teammate, bmux li trasforma in pannelli e divisioni native invece che in processi nascosti in background. Supporta [Claude Code teams](https://bmux.com/docs/agent-integrations/claude-code-teams) e l'orchestrazione multi-modello di [oh-my-opencode](https://bmux.com/docs/agent-integrations/oh-my-opencode), così ogni agente di un'esecuzione è visibile e controllabile.

### Posso usare bmux con macchine remote?

Sì. Apri workspace tramite SSH e connettiti a sessioni tmux remote, così gli agenti possono girare su un host remoto mentre li piloti da bmux. Consulta [SSH e remoto](https://bmux.com/docs/ssh).

### Come funzionano le notifiche?

Quando un processo richiede attenzione, bmux mostra anelli di notifica attorno ai pannelli, badge di non lette nella barra laterale, un popover di notifiche e una notifica desktop di macOS. Queste si attivano automaticamente tramite sequenze di escape del terminale standard (OSC 9/99/777), oppure puoi attivarle con il [CLI di bmux](https://bmux.com/docs/notifications#cli-usage) e gli [hook degli agenti](https://bmux.com/docs/notifications#integration-examples). Funziona qualsiasi agente che supporti gli hook o OSC, inclusi Claude Code, Codex, OpenCode e pi.

### bmux è programmabile?

Sì. Ogni azione è disponibile tramite il CLI di bmux e un socket Unix: creare workspace, aprire pannelli divisi, inviare input, leggere il contenuto dello schermo, fare screenshot e pilotare il browser integrato. Consulta il [riferimento del CLI](https://bmux.com/docs/api) e la documentazione sull'[automazione del browser](https://bmux.com/docs/browser-automation).

### Cosa può fare il browser integrato?

bmux può dividere un vero pannello browser accanto al tuo terminale, ed è completamente programmabile: navigare, acquisire il DOM, fare clic, digitare, valutare JavaScript e leggere l'attività della console e della rete tramite la stessa socket API. Gli agenti lo usano per verificare le proprie modifiche web senza uscire da bmux. Consulta [automazione del browser](https://bmux.com/docs/browser-automation).

### bmux ha le skill?

Sì. Le skill sono flussi di lavoro riutilizzabili che puoi dare a qualsiasi agente in esecuzione in bmux, per cose come il controllo del CLI, l'automazione dei workspace, le impostazioni e le superfici browser. Sfoglia la collezione aperta su [bmux-skills](https://github.com/manaflow-ai/bmux-skills), oppure leggi la [documentazione delle skill](https://bmux.com/docs/skills).

### Posso personalizzare le scorciatoie da tastiera?

Le combinazioni di tasti del terminale vengono lette dal tuo file di configurazione Ghostty (`~/.config/ghostty/config`). Le scorciatoie specifiche di bmux (workspace, divisioni, browser, notifiche) si possono personalizzare nelle Impostazioni. Consulta le [scorciatoie predefinite](https://bmux.com/docs/keyboard-shortcuts) per l'elenco completo.

### Posso personalizzare bmux?

Sì. Il rendering del terminale usa la tua configurazione Ghostty, quindi temi, font, colori e cursore vengono trasferiti direttamente. Le impostazioni proprie di bmux in `~/.config/bmux/bmux.json` controllano la barra laterale, la barra delle schede, i pannelli divisi e il comportamento, e ogni [scorciatoia da tastiera](https://bmux.com/docs/keyboard-shortcuts) è modificabile. Consulta [configurazione](https://bmux.com/docs/configuration).

### Le mie sessioni vengono salvate?

Sì. bmux ripristina le tue finestre, workspace, pannelli, directory di lavoro e scrollback al riavvio, e lo stato sopravvive a un riavvio completo del computer, non solo alla chiusura dell'app. Tornano anche le sessioni degli agenti come Claude Code, Codex e OpenCode. Consulta [ripristino sessione](https://bmux.com/docs/session-restore).

### Come si confronta con tmux?

tmux è un multiplexer di terminale che gira dentro qualsiasi terminale. bmux è un'app macOS nativa con GUI: schede verticali, pannelli divisi, un browser integrato e una socket API, tutto incorporato, senza bisogno di file di configurazione o tasti prefisso. Detto questo, molte persone usano felicemente bmux insieme a SSH e tmux, e bmux può connettersi nativamente alle tue sessioni tmux remote ([beta](https://bmux.com/docs/remote-tmux)).

### bmux è gratuito?

Sì, bmux è gratuito da usare. Il codice sorgente è disponibile su [GitHub](https://github.com/manaflow-ai/bmux).

### Come posso supportare bmux?

bmux è gratuito e open source, e lo sarà sempre. Se vuoi sostenere lo sviluppo e ottenere accesso anticipato a ciò che arriverà, inclusi bmux AI, l'app iOS e le Cloud VM, dai un'occhiata a [bmux Founders Edition](https://github.com/manaflow-ai/bmux#founders-edition).

### Ho una richiesta di funzionalità o ho trovato un bug?

Vogliamo saperlo. Apri una [issue](https://github.com/manaflow-ai/bmux/issues) o una [pull request](https://github.com/manaflow-ai/bmux/pulls) su GitHub, oppure [scrivici un'email](mailto:founders@manaflow.com?subject=bmux%20feature%20request).

## Cronologia Stelle

<a href="https://star-history.com/#manaflow-ai/bmux&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" width="600" />
 </picture>
</a>

## Contribuire

Modi per partecipare:

- Seguici su X per aggiornamenti [@manaflowai](https://x.com/manaflowai), [@lawrencecchen](https://x.com/lawrencecchen), e [@austinywang](https://x.com/austinywang)
- Unisciti alla conversazione su [Discord](https://discord.gg/xsgFEVrWCZ)
- Crea e partecipa alle [issue su GitHub](https://github.com/manaflow-ai/bmux/issues) e alle [discussioni](https://github.com/manaflow-ai/bmux/discussions)
- Facci sapere cosa stai costruendo con bmux

## Comunità

- [Discord](https://discord.gg/xsgFEVrWCZ)
- [GitHub](https://github.com/manaflow-ai/bmux)
- [X / Twitter](https://twitter.com/manaflowai)
- [YouTube](https://www.youtube.com/channel/UCAa89_j-TWkrXfk9A3CbASw)
- [LinkedIn](https://www.linkedin.com/company/manaflow-ai/)
- [Reddit](https://www.reddit.com/r/bmux/)

<p>
  <strong>WeChat:</strong> Scansiona il codice QR per unirti alla community.<br />
  <img src="./docs/assets/wechat-community-qr.jpg" alt="Codice QR WeChat per unirti alla community di bmux" width="240" />
</p>

## Edizione Fondatore

bmux è gratuito, open source, e lo sarà sempre. Se vuoi supportare lo sviluppo e ottenere accesso anticipato a ciò che arriverà:

**[Ottieni l'Edizione Fondatore](https://buy.stripe.com/3cI00j2Ld0it5OU33r5EY0q)**

- **Richieste di funzionalità e correzioni di bug prioritarie**
- **Accesso anticipato: bmux AI che ti dà contesto su ogni workspace, scheda e pannello**
- **Accesso anticipato: app iOS con terminali sincronizzati tra desktop e telefono**
- **Accesso anticipato: VM cloud**
- **Accesso anticipato: Modalità vocale**
- **Il mio iMessage/WhatsApp personale**

## Licenza

bmux è open source sotto [GPL-3.0-or-later](LICENSE).

Se la tua organizzazione non può conformarsi alla GPL, è disponibile una licenza commerciale. Contatta [founders@manaflow.com](mailto:founders@manaflow.com) per i dettagli.
