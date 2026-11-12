// mCLOUD — textes dans les 4 langues (fr, en, es, it). Langue du système ; hors de ces 4, anglais.
import Foundation

enum Lang {
    static let lang: String = {
        let p = Locale.preferredLanguages.first ?? "en"
        for c in ["fr", "es", "it"] where p.hasPrefix(c) { return c }
        return "en"
    }()
    private static let idx = ["fr": 0, "en": 1, "es": 2, "it": 3]
    static func f(_ key: String, _ args: [CVarArg]) -> String {
        guard let row = table[key] else { return key }
        let s = row[idx[lang]!]
        return args.isEmpty ? s : String(format: s, arguments: args)
    }
    static func t(_ key: String, _ args: CVarArg...) -> String { f(key, args) }

    private static let rows: [(String, String, String, String, String)] = [
        ("tab.accounts", "Comptes", "Accounts", "Cuentas", "Account"),
        ("tab.watch", "Veille", "Watch", "Vigilancia", "Sorveglianza"),
        ("tab.settings", "Réglages", "Settings", "Ajustes", "Impostazioni"),
        ("acc.add", "Ajouter un compte", "Add an account", "Añadir una cuenta", "Aggiungi un account"),
        ("acc.empty.title", "Aucun compte pour l'instant", "No accounts yet", "Aún no hay cuentas", "Nessun account per ora"),
        ("acc.empty.body", "Ajoutez Google Drive, Dropbox, OneDrive ou un autre service : il apparaîtra comme un disque dans le Finder.", "Add Google Drive, Dropbox, OneDrive or another service: it shows up as a drive in the Finder.", "Añada Google Drive, Dropbox, OneDrive u otro servicio: aparecerá como un disco en el Finder.", "Aggiungi Google Drive, Dropbox, OneDrive o un altro servizio: apparirà come un disco nel Finder."),
        ("acc.import", "Importer de CloudMounter", "Import from CloudMounter", "Importar de CloudMounter", "Importa da CloudMounter"),
        ("acc.import.done", "%d compte(s) importé(s) : autorisez-les un par un.", "%d account(s) imported: authorize them one by one.", "%d cuenta(s) importada(s): autorícelas una a una.", "%d account importati: autorizzali uno per uno."),
        ("acc.pending", "À autoriser", "To authorize", "Por autorizar", "Da autorizzare"),
        ("acc.authorize", "Autoriser", "Authorize", "Autorizar", "Autorizza"),
        ("acc.mount", "Monter", "Mount", "Montar", "Monta"),
        ("acc.unmount", "Démonter", "Unmount", "Desmontar", "Smonta"),
        ("acc.open", "Ouvrir", "Open", "Abrir", "Apri"),
        ("acc.edit", "Réglages", "Settings", "Ajustes", "Impostazioni"),
        ("acc.status.off", "Non monté", "Not mounted", "No montado", "Non montato"),
        ("acc.status.starting", "Connexion…", "Connecting…", "Conectando…", "Connessione…"),
        ("acc.status.on", "Monté", "Mounted", "Montado", "Montato"),
        ("acc.status.error", "Erreur : %@", "Error: %@", "Error: %@", "Errore: %@"),
        ("acc.status.heal", "Reconnexion automatique…", "Reconnecting automatically…", "Reconectando automáticamente…", "Riconnessione automatica…"),
        ("acc.encrypted", "Chiffré", "Encrypted", "Cifrado", "Cifrato"),
        ("add.title", "Nouveau compte", "New account", "Nueva cuenta", "Nuovo account"),
        ("add.provider", "Service", "Service", "Servicio", "Servizio"),
        ("add.name", "Nom du disque", "Drive name", "Nombre del disco", "Nome del disco"),
        ("add.encrypt", "Chiffrer les fichiers avant l'envoi", "Encrypt files before upload", "Cifrar los archivos antes de enviarlos", "Cifra i file prima dell'invio"),
        ("add.encrypt.pw", "Mot de passe de chiffrement", "Encryption password", "Contraseña de cifrado", "Password di cifratura"),
        ("add.encrypt.hint", "Gardez-le : sans lui, vos fichiers chiffrés sont illisibles. Il est rangé dans le Trousseau.", "Keep it: without it, your encrypted files are unreadable. It is stored in the Keychain.", "Guárdela: sin ella, sus archivos cifrados son ilegibles. Se guarda en el llavero.", "Conservala: senza, i file cifrati sono illeggibili. È salvata nel Portachiavi."),
        ("add.login", "Monter au démarrage", "Mount at startup", "Montar al iniciar", "Monta all'avvio"),
        ("add.connect", "Se connecter", "Connect", "Conectar", "Connetti"),
        ("add.connecting", "Connexion en cours…", "Connecting…", "Conectando…", "Connessione in corso…"),
        ("add.cancel", "Annuler", "Cancel", "Cancelar", "Annulla"),
        ("add.oauth.hint", "Votre navigateur va s'ouvrir pour autoriser l'accès. mCLOUD ne voit jamais votre mot de passe.", "Your browser will open to authorize access. mCLOUD never sees your password.", "Se abrirá su navegador para autorizar el acceso. mCLOUD nunca ve su contraseña.", "Si aprirà il browser per autorizzare l'accesso. mCLOUD non vede mai la tua password."),
        ("add.error", "Connexion impossible : %@", "Couldn't connect: %@", "No se pudo conectar: %@", "Connessione non riuscita: %@"),
        ("add.2fa", "Code de vérification reçu", "Verification code received", "Código de verificación recibido", "Codice di verifica ricevuto"),
        ("add.2fa.ok", "Valider", "Confirm", "Validar", "Conferma"),
        ("add.required", "Remplissez les champs obligatoires.", "Fill in the required fields.", "Rellene los campos obligatorios.", "Compila i campi obbligatori."),
        ("f.drive_id", "ID du kDrive (nombre dans l'adresse de votre kDrive)", "kDrive ID (number in your kDrive address)", "ID del kDrive (número en la dirección de su kDrive)", "ID del kDrive (numero nell'indirizzo del tuo kDrive)"),
        ("f.client_id", "ID client (facultatif)", "Client ID (optional)", "ID de cliente (opcional)", "ID client (facoltativo)"),
        ("f.client_secret", "Secret client (facultatif)", "Client secret (optional)", "Secreto de cliente (opcional)", "Segreto client (facoltativo)"),
        ("f.user", "Identifiant", "Username", "Usuario", "Utente"),
        ("f.pass", "Mot de passe", "Password", "Contraseña", "Password"),
        ("f.host", "Serveur", "Server", "Servidor", "Server"),
        ("f.port", "Port (facultatif)", "Port (optional)", "Puerto (opcional)", "Porta (facoltativa)"),
        ("f.url", "Adresse (URL)", "Address (URL)", "Dirección (URL)", "Indirizzo (URL)"),
        ("f.apple_id", "Identifiant Apple", "Apple ID", "ID de Apple", "ID Apple"),
        ("f.access_key", "Clé d'accès", "Access key", "Clave de acceso", "Chiave di accesso"),
        ("f.secret_key", "Clé secrète", "Secret key", "Clave secreta", "Chiave segreta"),
        ("f.region", "Région (facultatif)", "Region (optional)", "Región (opcional)", "Regione (facoltativa)"),
        ("f.endpoint", "Point d'accès (endpoint)", "Endpoint", "Punto de acceso (endpoint)", "Endpoint"),
        ("f.account", "ID de compte", "Account ID", "ID de cuenta", "ID account"),
        ("f.key", "Clé d'application", "Application key", "Clave de aplicación", "Chiave applicazione"),
        ("f.path", "Dossier", "Folder", "Carpeta", "Cartella"),
        ("f.keyfile", "Fichier de clé privée (facultatif)", "Private key file (optional)", "Archivo de clave privada (opcional)", "File chiave privata (facoltativo)"),
        ("edit.title", "Réglages du compte", "Account settings", "Ajustes de la cuenta", "Impostazioni account"),
        ("edit.cache", "Cache hors ligne", "Offline cache", "Caché sin conexión", "Cache offline"),
        ("edit.mode.hint.offline", "Les fichiers ouverts restent sur ce Mac et se synchronisent au retour du réseau.", "Opened files stay on this Mac and sync when the network is back.", "Los archivos abiertos se quedan en este Mac y se sincronizan al volver la red.", "I file aperti restano su questo Mac e si sincronizzano al ritorno della rete."),
        ("edit.mode.minimal", "Minimal", "Minimal", "Mínimo", "Minimo"),
        ("edit.mode.balanced", "Équilibré", "Balanced", "Equilibrado", "Equilibrato"),
        ("edit.mode.offline", "Hors ligne", "Offline", "Sin conexión", "Offline"),
        ("edit.mode.hint.minimal", "Stockage local quasi nul (256 Mo max, vidé au démontage). Les fichiers sont lus en direct depuis le cloud : il faut du réseau.", "Almost no local storage (256 MB max, cleared on unmount). Files are read live from the cloud: a network connection is needed.", "Almacenamiento local casi nulo (256 MB máx., vaciado al desmontar). Los archivos se leen en directo desde la nube: hace falta red.", "Spazio locale quasi nullo (256 MB max, svuotato allo smontaggio). I file sono letti in diretta dal cloud: serve la rete."),
        ("edit.mode.hint.balanced", "Garde les derniers fichiers ouverts (2 Go max, 6 h) pour accélérer l'accès.", "Keeps recently opened files (2 GB max, 6 h) for faster access.", "Guarda los últimos archivos abiertos (2 GB máx., 6 h) para acelerar el acceso.", "Conserva gli ultimi file aperti (2 GB max, 6 h) per accedere più in fretta."),
        ("edit.cache.hint", "Les fichiers ouverts restent sur ce Mac et se synchronisent au retour du réseau.", "Opened files stay on this Mac and sync when the network is back.", "Los archivos abiertos se quedan en este Mac y se sincronizan al volver la red.", "I file aperti restano su questo Mac e si sincronizzano al ritorno della rete."),
        ("edit.cache.gb", "Taille maximale (Go)", "Maximum size (GB)", "Tamaño máximo (GB)", "Dimensione massima (GB)"),
        ("edit.cache.days", "Durée de conservation (jours)", "Retention (days)", "Conservación (días)", "Conservazione (giorni)"),
        ("edit.delete", "Supprimer ce compte", "Remove this account", "Eliminar esta cuenta", "Rimuovi questo account"),
        ("edit.delete.confirm", "Retirer ce compte de mCLOUD ? Vos fichiers en ligne ne sont pas touchés.", "Remove this account from mCLOUD? Your online files are not touched.", "¿Quitar esta cuenta de mCLOUD? Sus archivos en línea no se tocan.", "Rimuovere questo account da mCLOUD? I file online non vengono toccati."),
        ("edit.save", "Enregistrer", "Save", "Guardar", "Salva"),
        ("watch.title", "Veille sur les services", "Service watch", "Vigilancia de servicios", "Sorveglianza dei servizi"),
        ("watch.intro", "mCLOUD surveille en silence le moteur de connexion et la santé de chaque compte, pour garantir une connexion sans faille. Il signale ici tout changement chez un service qui demande une correction du code.", "mCLOUD silently watches the connection engine and each account's health to keep connections flawless. Anything a service changes that requires a code fix is reported here.", "mCLOUD vigila en silencio el motor de conexión y la salud de cada cuenta para garantizar una conexión impecable. Aquí se avisa de todo cambio de un servicio que requiera corregir el código.", "mCLOUD sorveglia in silenzio il motore di connessione e lo stato di ogni account per garantire una connessione perfetta. Qui segnala ogni modifica di un servizio che richiede una correzione del codice."),
        ("watch.run", "Lancer la veille", "Run the watch", "Ejecutar la vigilancia", "Avvia la sorveglianza"),
        ("watch.running", "Veille en cours…", "Watching…", "Vigilando…", "Sorveglianza in corso…"),
        ("watch.last", "Dernière veille : %@", "Last check: %@", "Última vigilancia: %@", "Ultima verifica: %@"),
        ("watch.never", "Pas encore de veille.", "No check yet.", "Aún sin vigilancia.", "Nessuna verifica ancora."),
        ("watch.empty", "Rien à signaler : tous les services répondent normalement.", "Nothing to report: all services respond normally.", "Nada que señalar: todos los servicios responden con normalidad.", "Niente da segnalare: tutti i servizi rispondono normalmente."),
        ("watch.kind.code", "Code à corriger", "Code fix needed", "Corregir el código", "Correzione del codice"),
        ("watch.kind.user", "Reconnexion", "Reconnect", "Reconexión", "Riconnessione"),
        ("watch.kind.info", "Information", "Information", "Información", "Informazione"),
        ("watch.markread", "Tout marquer comme lu", "Mark all as read", "Marcar todo como leído", "Segna tutto come letto"),
        ("watch.report", "Ouvrir le rapport", "Open the report", "Abrir el informe", "Apri il rapporto"),
        ("set.login", "Lancer mCLOUD à l'ouverture de session", "Launch mCLOUD at login", "Abrir mCLOUD al iniciar sesión", "Avvia mCLOUD all'accesso"),
        ("set.engine", "Moteur de connexion : rclone %@", "Connection engine: rclone %@", "Motor de conexión: rclone %@", "Motore di connessione: rclone %@"),
        ("set.about", "À propos", "About", "Acerca de", "Informazioni"),
        ("menu.open", "Ouvrir mCLOUD", "Open mCLOUD", "Abrir mCLOUD", "Apri mCLOUD"),
        ("menu.quit", "Quitter mCLOUD", "Quit mCLOUD", "Salir de mCLOUD", "Esci da mCLOUD"),
        ("menu.watch", "Veille : %d à lire", "Watch: %d unread", "Vigilancia: %d sin leer", "Sorveglianza: %d da leggere"),
        ("menu.none", "Aucun compte", "No accounts", "Sin cuentas", "Nessun account"),
        ("about.menu", "À propos de mCLOUD", "About mCLOUD", "Acerca de mCLOUD", "Informazioni su mCLOUD"),
        ("about.version", "Version %@ (%@)", "Version %@ (%@)", "Versión %@ (%@)", "Versione %@ (%@)"),
        ("about.tagline", "Vos clouds comme des disques dans le Finder.", "Your clouds as drives in the Finder.", "Sus nubes como discos en el Finder.", "I tuoi cloud come dischi nel Finder."),
        ("about.authors", "Par Stéphan Le Gac Savoye", "By Stéphan Le Gac Savoye", "Por Stéphan Le Gac Savoye", "Di Stéphan Le Gac Savoye"),
        ("about.license", "Licence MIT", "MIT license", "Licencia MIT", "Licenza MIT"),
        ("about.disclaimer", "Application indépendante, sans lien avec les services cloud cités.", "Independent app, not affiliated with the cloud services mentioned.", "Aplicación independiente, sin relación con los servicios en la nube citados.", "App indipendente, non affiliata ai servizi cloud citati."),
        ("about.credit", "Propulsé par rclone (licence MIT).", "Powered by rclone (MIT license).", "Impulsado por rclone (licencia MIT).", "Basato su rclone (licenza MIT)."),
        ("upd.title", "Mises à jour", "Updates", "Actualizaciones", "Aggiornamenti"),
        ("upd.auto", "Installer automatiquement", "Install automatically", "Instalar automáticamente", "Installa automaticamente"),
        ("upd.check", "Rechercher une mise à jour", "Check for updates", "Buscar actualizaciones", "Cerca aggiornamenti"),
        ("upd.checking", "Recherche…", "Checking…", "Buscando…", "Ricerca…"),
        ("upd.uptodate", "mCLOUD est à jour.", "mCLOUD is up to date.", "mCLOUD está actualizado.", "mCLOUD è aggiornato."),
        ("upd.available", "Version %@ disponible", "Version %@ available", "Versión %@ disponible", "Versione %@ disponibile"),
        ("upd.install", "Installer et relancer", "Install and relaunch", "Instalar y reiniciar", "Installa e riavvia"),
        ("upd.downloading", "Téléchargement…", "Downloading…", "Descargando…", "Download…"),
        ("upd.err.none", "Aucune version publiée.", "No release published.", "Ninguna versión publicada.", "Nessuna versione pubblicata."),
        ("upd.err.download", "Téléchargement impossible.", "Download failed.", "Descarga imposible.", "Download non riuscito."),
        ("upd.err.signature", "Signature de la mise à jour invalide.", "Invalid update signature.", "Firma de la actualización no válida.", "Firma dell'aggiornamento non valida."),
        ("w.auth", "%@ : reconnexion nécessaire (autorisation expirée ou révoquée).", "%@: reconnection needed (authorization expired or revoked).", "%@: reconexión necesaria (autorización caducada o revocada).", "%@: riconnessione necessaria (autorizzazione scaduta o revocata)."),
        ("w.api", "%@ : le service répond de façon inattendue, son API a peut-être changé : le code est à vérifier.", "%@: the service answers unexpectedly, its API may have changed: the code needs checking.", "%@: el servicio responde de forma inesperada, su API puede haber cambiado: hay que revisar el código.", "%@: il servizio risponde in modo inatteso, la sua API potrebbe essere cambiata: il codice va verificato."),
        ("w.engine.new", "Nouvelle version du moteur rclone : %@ (embarquée : %@). Une mise à jour de mCLOUD est conseillée.", "New rclone engine version: %@ (bundled: %@). An mCLOUD update is advised.", "Nueva versión del motor rclone: %@ (incluida: %@). Se aconseja actualizar mCLOUD.", "Nuova versione del motore rclone: %@ (inclusa: %@). Si consiglia di aggiornare mCLOUD."),
        ("w.engine.changes", "rclone %@ : changements qui touchent %@", "rclone %@: changes affecting %@", "rclone %@: cambios que afectan a %@", "rclone %@: modifiche che riguardano %@"),
        ("w.engine.dead", "Le moteur rclone ne démarre pas.", "The rclone engine won't start.", "El motor rclone no arranca.", "Il motore rclone non si avvia."),
        ("upd.err.version", "Version de mise à jour inattendue.", "Unexpected update version.", "Versión de actualización inesperada.", "Versione dell'aggiornamento inattesa."),
    ]
    private static let table: [String: [String]] = Dictionary(uniqueKeysWithValues: rows.map { ($0.0, [$0.1, $0.2, $0.3, $0.4]) })
}

func L(_ key: String, _ args: CVarArg...) -> String { Lang.f(key, args) }

enum VersionCompare {
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
