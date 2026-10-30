# Snus Counter

Widget interattivo per iPhone (iOS 17+): sulla schermata di blocco tocchi + e il contatore degli snus sale, si azzera da solo a mezzanotte. Il widget medio per la Home mostra anche gli ultimi 7 giorni. Il contatore vive nel widget; quando tocchi il widget fuori dai pulsanti + e −, si apre l'app e riceve lo storico (statistiche, grafico, ultimi 14 giorni).

## 1. Metti il progetto su GitHub

1. Crea un repository **pubblico** su github.com (i runner macOS sono gratuiti solo per i repo pubblici).
2. Carica **tutto il contenuto** di questa cartella, compresa la cartella nascosta `.github`.
   - Il modo più sicuro è GitHub Desktop (o git da terminale).
   - Se carichi dal sito e `.github/workflows/build.yml` non compare, crealo a mano: Add file → Create new file, nome `.github/workflows/build.yml`, e incolla il contenuto.

## 2. Genera l'IPA

1. Nel repo apri la scheda **Actions**.
2. Se serve, scegli **Build IPA** → **Run workflow**. Parte anche da solo a ogni push.
3. Quando è verde, apri l'esecuzione e scarica l'artifact **SnusCounter-ipa**: dentro c'è `SnusCounter.ipa`.

## 3. Installa con Sideloadly

1. iPhone: Impostazioni → Privacy e sicurezza → **Modalità sviluppatore** → attiva e riavvia.
2. Collega l'iPhone al PC, apri Sideloadly, trascina `SnusCounter.ipa`, inserisci il tuo Apple ID, premi **Start**.
3. Sull'iPhone: Impostazioni → Generali → VPN e gestione dispositivo → fidati del tuo Apple ID.

Con un Apple ID gratuito l'app scade dopo **7 giorni**: basta rifare Start in Sideloadly (i dati restano se reinstalli sopra). Il widget conta come ID aggiuntivo (limite: 10 ID a settimana).

## 4. Aggiungi il widget

Tieni premuto sulla schermata di blocco → **Personalizza** → **Schermata di blocco** → **Aggiungi widget** → Snus Counter. Disponibili: cerchio (tap = +1), rettangolo (− e +), riga di testo. Sulla Home: formato piccolo (oggi, − e +) e medio (oggi, − e + e storico di 7 giorni), con sfondo nero semitrasparente.

## Nota sulla condivisione dati

Con un Apple ID gratuito Sideloadly non ottiene l'App Group da Apple (verificato: "Gruppi nel profilo: nessuno"), quindi app e widget non possono condividere i dati. Per questo il contatore e lo storico stanno nel widget, che li passa all'app con un link (`snuscounter://sync`) quando lo tocchi: la sincronizzazione va solo dal widget all'app e l'app mostra i dati dell'ultimo tocco. Se un giorno avrai un account developer, `Shared/CounterStore.swift` userà da solo l'App Group.

## Attenzione al caricamento su GitHub

Carica i file nelle cartelle giuste (`App`, `Widget`, `Shared`) e senza " (1)" nel nome: un file duplicato nella cartella sbagliata fa fallire la build.
