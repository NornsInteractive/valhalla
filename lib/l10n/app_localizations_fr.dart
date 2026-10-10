// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'Gestion de serveurs & d\'agents native IA';

  @override
  String get navAiChat => 'Chat IA';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'Fichiers SFTP';

  @override
  String get navCommands => 'Commandes';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get serverConnected => 'Connecté';

  @override
  String get serverOnline => 'En ligne';

  @override
  String get serverOffline => 'Hors ligne';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Reconnecter';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get quickDisconnect => 'Déconnexion rapide';

  @override
  String get newSession => 'Nouvelle session';

  @override
  String get historySessions => 'Historique des sessions';

  @override
  String get switchAgent => 'Changer d\'agent';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agent actif';

  @override
  String get inputPromptHint =>
      'Demander à l\'agent de diagnostiquer, exécuter des outils ou écrire des commandes... (Entrée pour envoyer)';

  @override
  String get thinking => 'Processus de réflexion';

  @override
  String get executionPlan => 'Plan d\'exécution';

  @override
  String get toolCall => 'Appel d\'outil';

  @override
  String get toolStatusPending => 'En attente';

  @override
  String get toolStatusRunning => 'En cours d\'exécution...';

  @override
  String get toolStatusCompleted => 'Terminé';

  @override
  String get toolStatusFailed => 'Échec';

  @override
  String get permissionRequired => 'Autorisation requise';

  @override
  String get permissionDescription =>
      'L\'agent souhaite exécuter cette commande sur le serveur :';

  @override
  String get permissionReject => 'Refuser';

  @override
  String get permissionAllowOnce => 'Autoriser une fois';

  @override
  String get permissionAllowAlways => 'Toujours autoriser';

  @override
  String get quickTroubleshootCpu =>
      'Diagnostiquer l\'utilisation élevée du processeur';

  @override
  String get quickDockerHealth => 'Contrôle de santé Docker';

  @override
  String get quickCleanCache => 'Vider le cache système';

  @override
  String get quickNginxLogs => 'Vérifier les journaux d\'erreurs Nginx';

  @override
  String get terminalNewTab => 'Nouvel onglet';

  @override
  String get terminalCloseTab => 'Fermer l\'onglet';

  @override
  String get terminalClear => 'Effacer';

  @override
  String get terminalQuickCmds => 'Palette de commandes';

  @override
  String get terminalPaste => 'Coller';

  @override
  String get sftpCurrentPath => 'Chemin actuel';

  @override
  String get sftpUpload => 'Téléverser';

  @override
  String get sftpNewFolder => 'Nouveau dossier';

  @override
  String get sftpNewFile => 'Nouveau fichier';

  @override
  String get sftpRefresh => 'Actualiser';

  @override
  String get sftpSearchHint => 'Rechercher des fichiers ou dossiers...';

  @override
  String get sftpEmpty => 'Le répertoire est vide';

  @override
  String get sftpFileName => 'Nom';

  @override
  String get sftpFileSize => 'Taille';

  @override
  String get sftpFilePerm => 'Autorisations';

  @override
  String get sftpFileModified => 'Modifié';

  @override
  String get cmdCategoryDocker => 'STACK CONTENEURS DOCKER';

  @override
  String get cmdCategorySystem => 'MAINTENANCE DU SYSTÈME';

  @override
  String get cmdCategoryNetwork => 'RÉSEAU & PORTS';

  @override
  String get cmdExecute => 'Exécuter';

  @override
  String get cmdDangerous => 'Commande dangereuse';

  @override
  String get cmdDangerousWarning =>
      'Cette opération est irréversible et peut entraîner une interruption de service. Voulez-vous vraiment continuer ?';

  @override
  String get cmdParamRequired => 'Saisie de paramètre requise';

  @override
  String get cmdConfirm => 'Confirmer & Exécuter';

  @override
  String get cmdCancel => 'Annuler';

  @override
  String get settingsAppearance => 'Apparence & Thèmes';

  @override
  String get settingsThemeMode => 'Mode du thème';

  @override
  String get themeSystem => 'Système par défaut';

  @override
  String get themeSystemDesc => 'Adaptation automatique';

  @override
  String get themeLight => 'Mode clair';

  @override
  String get themeLightDesc => 'Blanc papier lumineux';

  @override
  String get themeDark => 'Geek sombre';

  @override
  String get themeDarkDesc => 'Anthracite profond';

  @override
  String get themeAmoled => 'Noir AMOLED';

  @override
  String get themeAmoledDesc => 'Noir absolu 0x000000';

  @override
  String get settingsAccentColor => 'Couleur d\'accentuation du thème';

  @override
  String get accentCyberEmerald => 'Émeraude cyber';

  @override
  String get accentTechBlue => 'Bleu tech';

  @override
  String get accentElectricViolet => 'Violet électrique';

  @override
  String get accentCrimsonRed => 'Rouge cramoisi';

  @override
  String get accentAmberOrange => 'Orange ambré';

  @override
  String get settingsLanguage => 'Langue & Région';

  @override
  String get langZh => '简体中文 (Simplified Chinese)';

  @override
  String get langEn => 'English (US)';

  @override
  String get langZhHant => '繁體中文 (Traditional Chinese)';

  @override
  String get langJa => '日本語';

  @override
  String get langKo => '한국어';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langFr => 'Français';

  @override
  String get langEs => 'Español';

  @override
  String get langPt => 'Português';

  @override
  String get langRu => 'Русский';

  @override
  String get langAr => 'العربية';

  @override
  String get langHi => 'हिन्दी';

  @override
  String get langId => 'Bahasa Indonesia';

  @override
  String get langIt => 'Italiano';

  @override
  String get langTr => 'Türkçe';

  @override
  String get langVi => 'Tiếng Việt';

  @override
  String get langTh => 'ไทย';

  @override
  String get settingsAiOps => 'AI Ops & Moteur';

  @override
  String get settingsSecurity => 'Connexion & Sécurité';

  @override
  String get settingsKnownHosts => 'Clés d\'hôtes connus';

  @override
  String get settingsClearStorage => 'Réinitialiser les identifiants';

  @override
  String get settingsResetDefault => 'Restaurer les valeurs par défaut';

  @override
  String get settingsTerminalUseTmux => 'Sessions persistantes (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Exécuter les sessions de terminal dans tmux sur le serveur distant';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Conserve la sortie de votre terminal après une déconnexion. Nécessite tmux sur le serveur distant. S\'applique aux nouveaux onglets de terminal.';

  @override
  String get settingsTerminalFontSize => 'Taille de police du terminal';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Ajuste la taille de la police pour les terminaux SSH et CLI';

  @override
  String get version => 'Version';

  @override
  String get addServer => 'Ajouter un serveur';

  @override
  String get editServer => 'Modifier le serveur';

  @override
  String get serverName => 'Nom du serveur';

  @override
  String get serverHost => 'Hôte / IP';

  @override
  String get serverPort => 'Port';

  @override
  String get serverUsername => 'Nom d\'utilisateur';

  @override
  String get serverAuthType => 'Type d\'authentification';

  @override
  String get serverPassword => 'Mot de passe';

  @override
  String get serverPrivateKey => 'Clé privée';

  @override
  String get serverSave => 'Enregistrer le serveur';

  @override
  String get serverDelete => 'Supprimer le serveur';

  @override
  String get fileEditor => 'Éditeur de fichiers';

  @override
  String get fileEditorSave => 'Enregistrer les modifications';

  @override
  String get fileSavedSuccess => 'Fichier enregistré avec succès';

  @override
  String get addCommand => 'Nouvelle commande';

  @override
  String get commandTitle => 'Titre de la commande';

  @override
  String get commandContent => 'Ligne de commande';

  @override
  String get commandCategory => 'Catégorie';

  @override
  String get commandDescription => 'Description';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get cmdExecutionChannel => 'Canal d\'exécution';

  @override
  String get cmdChannelTerminal => 'Directement dans le terminal SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'La commande est saisie directement dans la session de terminal active';

  @override
  String get cmdChannelBackground => 'Exécuter en arrière-plan';

  @override
  String get cmdChannelBackgroundDesc =>
      'S\'exécute via le shell de connexion SSH et capture la sortie';

  @override
  String get cmdInjectedToTerminal => 'Commande envoyée au terminal';

  @override
  String get cmdExecutionCompleted => 'Exécution terminée';

  @override
  String get cmdExecutionFailed => 'Échec de l\'exécution';

  @override
  String get cmdExecutingRemote => 'Exécution de la commande à distance...';

  @override
  String get cmdClose => 'Fermer';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Système';

  @override
  String get navMore => 'Plus';

  @override
  String get dashboardTitle => 'Tableau de bord du serveur';

  @override
  String get metricsCpu => 'Utilisation du processeur';

  @override
  String get metricsMemory => 'Utilisation de la mémoire';

  @override
  String get metricsLoadAvg => 'Charge moyenne';

  @override
  String get metricsUptime => 'Temps de fonctionnement';

  @override
  String get metricsRootDisk => 'Disque racine';

  @override
  String get quickActions => 'Navigation rapide';

  @override
  String get activeServerStatus => 'État du serveur actif';

  @override
  String get noServerSelected =>
      'Aucun serveur sélectionné pour le moment. Veuillez d\'abord choisir un serveur.';

  @override
  String get serverDisconnected => 'Déconnecté';

  @override
  String get serverConnecting => 'Connexion en cours...';

  @override
  String get connectNow => 'Se connecter maintenant';

  @override
  String get serverSpecs => 'Infos serveur & Spécifications';

  @override
  String get dockerTitle => 'Conteneurs Docker';

  @override
  String get dockerSearchHint =>
      'Rechercher des conteneurs par nom ou image...';

  @override
  String get dockerFilterAll => 'Tous';

  @override
  String get dockerFilterRunning => 'En cours';

  @override
  String get dockerFilterExited => 'Arrêtés';

  @override
  String get dockerFilterPaused => 'En pause';

  @override
  String get dockerActionStart => 'Démarrer';

  @override
  String get dockerActionStop => 'Arrêter';

  @override
  String get dockerActionRestart => 'Redémarrer';

  @override
  String get dockerActionPause => 'Mettre en pause';

  @override
  String get dockerActionUnpause => 'Reprendre';

  @override
  String get dockerActionRm => 'Supprimer';

  @override
  String get dockerActionLogs => 'Journaux';

  @override
  String get dockerActionInspect => 'Inspecter';

  @override
  String get dockerLogsTitle => 'Journaux du conteneur';

  @override
  String get dockerInspectTitle => 'Inspection du conteneur';

  @override
  String get dockerNoContainers => 'Aucun conteneur trouvé sur le serveur';

  @override
  String get dockerEmptyRunning => 'Aucun conteneur en cours d\'exécution';

  @override
  String get dockerPorts => 'Ports';

  @override
  String get dockerCreated => 'Créé';

  @override
  String get dockerImage => 'Image';

  @override
  String get systemTitle => 'Processus & Services';

  @override
  String get tabProcesses => 'Processus';

  @override
  String get tabServices => 'Services Systemd';

  @override
  String get processSearchHint => 'Rechercher par nom de processus ou PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'PROCESSEUR %';

  @override
  String get processMem => 'MÉMOIRE %';

  @override
  String get processStat => 'État';

  @override
  String get processCommand => 'Commande';

  @override
  String get processTerminate => 'Terminer (SIGTERM)';

  @override
  String get processForceKill => 'Tuer de force (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Refus de terminer le processus d\'initialisation du système (PID <= 1)';

  @override
  String get serviceSearchHint => 'Rechercher des services par nom...';

  @override
  String get serviceName => 'Service';

  @override
  String get serviceDescription => 'Description';

  @override
  String get serviceStatus => 'État';

  @override
  String get serviceStartup => 'Démarrage';

  @override
  String get serviceActionStart => 'Démarrer';

  @override
  String get serviceActionStop => 'Arrêter';

  @override
  String get serviceActionRestart => 'Redémarrer';

  @override
  String get serviceActionReload => 'Recharger';

  @override
  String get serviceActionEnable => 'Activer';

  @override
  String get serviceActionDisable => 'Désactiver';

  @override
  String get serviceNoServices => 'Aucun service systemd trouvé';

  @override
  String get riskDangerTitle => 'Confirmation d\'opération à haut risque';

  @override
  String get riskWarningTitle =>
      'Confirmation de l\'avertissement d\'opération';

  @override
  String get riskSafeTitle => 'Confirmer l\'action';

  @override
  String get riskIrreversibleWarning =>
      'Cette opération est classée à HAUT RISQUE et est irréversible. Elle peut entraîner des pertes de données ou des interruptions de service.';

  @override
  String get riskWarningDescription =>
      'Cette opération peut affecter des services actifs ou redémarrer des processus. Veuillez procéder avec prudence.';

  @override
  String get riskCommandPreview => 'Aperçu de la commande';

  @override
  String get riskConfirmButton => 'Confirmer & Continuer';

  @override
  String get riskCancelButton => 'Annuler';

  @override
  String get stateLoading => 'Chargement des données distantes...';

  @override
  String get stateOffline => 'Le serveur est hors ligne';

  @override
  String get stateOfflineDesc =>
      'Établissez une connexion SSH active pour gérer les ressources et suivre les métriques.';

  @override
  String get stateError => 'Une erreur est survenue';

  @override
  String get stateRetry => 'Réessayer';

  @override
  String get stateEmpty => 'Aucun élément trouvé';

  @override
  String get inspectorTitle => 'Inspecteur';

  @override
  String get inspectorClose => 'Fermer';

  @override
  String get inspectorDetails => 'Détails de l\'inspection';

  @override
  String get selectServerTitle => 'Sélectionner le serveur cible';

  @override
  String get sshDisconnectedSuccess => 'Connexion SSH interrompue';

  @override
  String get trustHostFingerprintTitle =>
      'Faire confiance à l\'empreinte de l\'hôte ?';

  @override
  String get trustAndConnect => 'Faire confiance & Se connecter';

  @override
  String get reject => 'Refuser';

  @override
  String get confirmDeleteServerTitle => 'Supprimer le serveur';

  @override
  String get noServersFound => 'Aucun serveur configuré pour le moment';

  @override
  String get agentNotReadyError =>
      'L\'agent sélectionné n\'est pas prêt. Veuillez vérifier son environnement et sa configuration.';

  @override
  String get sshDisconnectedError =>
      'SSH est déconnecté. Veuillez vous connecter à un serveur avant d\'utiliser AI Ops.';

  @override
  String get noAgentAvailable => 'Aucun agent disponible';

  @override
  String get noAgentAvailablePrompt =>
      'Aucun agent actif disponible. Veuillez configurer ou préparer un agent au préalable.';

  @override
  String get noAgentAvailableHint =>
      'Sélectionnez ou configurez un agent disponible pour commencer à discuter...';

  @override
  String get manageAgents => 'Gérer les agents';

  @override
  String get noReadyAgentsTitle => 'Aucun agent prêt';

  @override
  String get noReadyAgentsDesc =>
      'Aucun agent sur ce serveur n\'a passé les vérifications d\'environnement.';

  @override
  String get agentStatusReady => 'Prêt';

  @override
  String get agentStatusChecking => 'Vérification en cours...';

  @override
  String get agentStatusCliMissing => 'Installation non détectée';

  @override
  String get agentStatusAcpMissing => 'Composant ACP non détecté';

  @override
  String get agentStatusNotLoggedIn => 'Non connecté';

  @override
  String get agentStatusError => 'Erreur';

  @override
  String get agentStatusUnknown => 'Inconnu';

  @override
  String get agentActionInstall => 'Installer';

  @override
  String get agentActionLogin => 'Se connecter';

  @override
  String get agentActionRefresh => 'Vérifier l\'état';

  @override
  String get noConfiguredAgents => 'Aucun agent configuré sur ce serveur';

  @override
  String get agentManagementTitle => 'Gestion des agents';

  @override
  String get settingsAgentManagement => 'Gestion des agents';

  @override
  String get settingsAgentManagementSubtitle =>
      'Configurer, détecter et gérer les agents ACP pour le serveur actuel';

  @override
  String get addAgentButton => 'Ajouter un agent';

  @override
  String get noServerSelectedForAgents =>
      'Aucun serveur sélectionné. Veuillez d\'abord choisir un serveur depuis l\'interface principale.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH est déconnecté. La détection, l\'installation et la connexion sont désactivées jusqu\'à ce que la connexion soit établie.';

  @override
  String get noAgentsConfiguredTitle => 'Aucun agent configuré';

  @override
  String get noAgentsConfiguredDesc =>
      'Ajoutez Claude Code, Codex, OpenCode, AGY ou des agents ACP personnalisés pour activer AI Ops sur ce serveur.';

  @override
  String get agentPresetLabel => 'Modèle';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Personnalisé';

  @override
  String get agentNameLabel => 'Nom de l\'agent';

  @override
  String get agentNameHint => 'par ex. Codex de production';

  @override
  String get agentDescriptionLabel => 'Description';

  @override
  String get agentDescriptionHint => 'Brève description de l\'agent';

  @override
  String get agentCliCommandLabel => 'Commande de test CLI';

  @override
  String get agentCliCommandHint => 'par ex. claude, codex';

  @override
  String get agentAcpCommandLabel => 'Commande de lancement ACP';

  @override
  String get agentAcpCommandHint => 'par ex. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Commande d\'installation (Optionnel)';

  @override
  String get agentInstallCommandHint => 'par ex. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Commande de vérification de connexion (Optionnel)';

  @override
  String get agentLoginCheckCommandHint => 'par ex. codex --version';

  @override
  String get agentLoginCommandLabel => 'Commande de connexion (Optionnel)';

  @override
  String get agentLoginCommandHint => 'par ex. codex login';

  @override
  String get agentSaveButton => 'Enregistrer & Détecter';

  @override
  String get agentCliRequired => 'La commande de test CLI est requise';

  @override
  String get agentAcpRequired => 'La commande de lancement ACP est requise';

  @override
  String get agentNameRequired => 'Le nom de l\'agent est requis';

  @override
  String get confirmInstallAgentTitle =>
      'Confirmer l\'installation de l\'agent';

  @override
  String get confirmLoginAgentTitle => 'Confirmer la connexion de l\'agent';

  @override
  String get agentCommandRiskWarning =>
      'Cette commande sera exécutée directement sur le serveur distant avec les privilèges de l\'utilisateur actuel. Elle peut installer des paquets ou modifier l\'environnement système.';

  @override
  String get targetServerLabel => 'Serveur cible';

  @override
  String get commandPreviewLabel => 'Aperçu de la commande';

  @override
  String get executeButton => 'Exécuter';

  @override
  String get deleteAgentTitle => 'Supprimer l\'agent';

  @override
  String get deleteAgentConfirm => 'Supprimer';

  @override
  String get agentStatusCheckingDesc =>
      'Détection de l\'environnement sur le serveur distant...';

  @override
  String get agentStatusInstalling =>
      'Installation des dépendances sur le serveur...';

  @override
  String get agentStatusLoggingIn =>
      'Exécution de la commande de connexion sur le serveur...';

  @override
  String get agentNoLoginCheckProvided =>
      'Aucune commande de vérification de connexion spécifiée';

  @override
  String get agentInstallPrompt =>
      'Installation non détectée. Installer automatiquement maintenant ?';

  @override
  String get agentActionAutoInstall => 'Installation automatique';

  @override
  String get agentLoginPrompt => 'Non connecté. Se connecter maintenant ?';

  @override
  String get agentActionExecuteLogin => 'Se connecter maintenant';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Les agents sur ce serveur ne sont pas encore installés ou prêts. Veuillez gérer et terminer la configuration de l\'environnement.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Installez et préparez un agent pour commencer à discuter...';

  @override
  String get agentAcpInstallPrompt =>
      'Composant ACP non détecté. Installer automatiquement maintenant ?';

  @override
  String get agentInstallCommandAcpLabel =>
      'Commande d\'installation ACP (Optionnel)';

  @override
  String get agentInstallCommandAcpHint =>
      'par ex. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Aucune commande d\'installation configurée pour cet agent';

  @override
  String get agentInstallLogTitle => 'Sortie d\'installation';

  @override
  String get agentInstallLogEmpty => 'En attente de la sortie d\'installation…';

  @override
  String get agentInstallLogTruncated =>
      'Sortie trop longue ; affichage des lignes les plus récentes';

  @override
  String get agentAcpOptional => 'Optionnel ; laisser vide pour CLI uniquement';

  @override
  String get acpStreaming => 'Diffusion ACP en cours...';

  @override
  String get aiOpsAgentTitle => 'Agent AI Ops Valhalla';

  @override
  String get aiOpsEmptySubtitle => 'Connecté via ACP stdio sur le canal SSH';

  @override
  String get agentAuthRequiredTitle => 'Authentification requise';

  @override
  String get agentAuthRequiredDesc =>
      'L\'agent nécessite une authentification avant de pouvoir traiter votre requête.';

  @override
  String get agentAuthMethodLabel => 'Méthode d\'authentification';

  @override
  String get agentAuthNoMethodsNotice =>
      'L\'agent n\'a fourni aucune méthode de connexion. Veuillez vérifier sa configuration sur le serveur.';

  @override
  String get agentAuthProceedButton => 'Se connecter';

  @override
  String get agentAuthCancelButton => 'Annuler';

  @override
  String get agentAuthRetryHint =>
      'Après vous être connecté, veuillez renvoyer votre message.';

  @override
  String get agentAuthRequiredError =>
      'Authentification requise. Veuillez vous connecter pour continuer.';

  @override
  String get agentLoginTerminalTitle => 'Terminal de connexion interactif';

  @override
  String get agentLoginTerminalSubtitle =>
      'Effectuez les étapes de connexion dans le terminal ci-dessous. Suivez toute invite d\'URL ou de code affichée.';

  @override
  String get agentLoginTerminalRunning =>
      'La commande de connexion est en cours d\'exécution dans le terminal...';

  @override
  String get agentLoginTerminalDisconnected =>
      'Connexion SSH perdue. La session de connexion a été interrompue.';

  @override
  String get agentLoginTerminalRetry => 'Reconnecter le terminal';

  @override
  String get agentLoginTerminalFinish => 'Terminer & Vérifier';

  @override
  String get agentLoginTerminalClose => 'Fermer';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Si l\'agent nécessite de coller un code, appuyez longuement sur le terminal pour coller ou utilisez la touche COLLER.';

  @override
  String get agentLoginTerminalUrlLabel => 'URL de connexion détectée';

  @override
  String get agentLoginTerminalUrlCopy => 'Copier le lien';

  @override
  String get agentLoginTerminalUrlCopied =>
      'URL de connexion copiée dans le presse-papiers';

  @override
  String get agentLoginTerminalCopyAll => 'Copier toute la sortie';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Sortie du terminal copiée dans le presse-papiers';

  @override
  String get sshStatusReconnected => 'Connexion rétablie';

  @override
  String get sshStatusDisconnectedRetrying =>
      'Connexion perdue, nouvelle tentative';

  @override
  String get sshStatusDisconnectedManual => 'Déconnecté';

  @override
  String get sshStatusHostKeyChanged =>
      'Clé d\'hôte modifiée — connexion refusée';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla maintient vos sessions actives';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux introuvable — les sessions ne survivront pas à une coupure';

  @override
  String get terminalTmuxSessionRestored => 'Session de terminal restaurée';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Activer Mosh — un terminal itinérant qui survit aux coupures et changements d\'IP';

  @override
  String get moshServerPathLabel => 'Chemin de mosh-server';

  @override
  String get moshPortRangeLabel => 'Plage de ports UDP';

  @override
  String get moshNewSession => 'Nouvelle session Mosh';

  @override
  String get moshNotInstalled =>
      'mosh-server est introuvable sur le serveur distant. Installez-le avec : sudo apt install mosh (Debian/Ubuntu) ou sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Échec du démarrage de la session Mosh : $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Délai d\'attente de connexion Mosh dépassé — vérifiez que le trafic UDP n\'est pas bloqué par un pare-feu.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Session d\'agent restaurée';

  @override
  String get acpSessionRestartNotice =>
      'Session d\'agent redémarrée — contexte précédent indisponible';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Installer tmux sur le serveur distant ?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux est requis pour préserver les sessions de terminal lors des déconnexions. Souhaitez-vous l\'installer maintenant ?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Commande à exécuter :';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Aucun gestionnaire de paquets pris en charge détecté sur le serveur distant. Veuillez installer tmux manuellement.';

  @override
  String get terminalTmuxInstallFailed =>
      'Échec de l\'installation de tmux. Veuillez vérifier les autorisations du serveur et le réseau.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'Connexion SSH perdue. Veuillez vous reconnecter pour installer tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Installation de tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Installer tmux';

  @override
  String get terminalTmuxInstallSkip => 'Ignorer (Utiliser le shell simple)';

  @override
  String get sftpDownload => 'Télécharger';

  @override
  String get sftpOpen => 'Ouvrir';

  @override
  String get sftpUploadFailed =>
      'Échec du téléversement. Vérifiez les autorisations et réessayez.';

  @override
  String get sftpDownloadFailed => 'Échec du téléchargement';

  @override
  String get sftpOpenUnsupported =>
      'Ce format de fichier ne peut pas être ouvert.';

  @override
  String get sftpReadFailed =>
      'Échec de lecture du fichier. Vérifiez les autorisations et réessayez.';

  @override
  String get sftpTransferFailed =>
      'Échec de l\'opération de fichier. Veuillez réessayer.';

  @override
  String get sftpDownloadSuccess => 'Téléchargé avec succès';

  @override
  String get sftpUploading => 'Téléversement en cours...';

  @override
  String get sftpDownloading => 'Téléchargement en cours...';

  @override
  String get sftpUpDirectory => 'Dossier parent';

  @override
  String get sftpShowHiddenFiles => 'Afficher les fichiers masqués';

  @override
  String get sftpHideHiddenFiles => 'Masquer les fichiers cachés';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Échec de l\'enregistrement des préférences de fichiers masqués';

  @override
  String get sftpSymlink => 'Lien symbolique';

  @override
  String get sftpLinkTargetUnavailable =>
      'La cible du lien symbolique est indisponible ou cassée';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Permission refusée pour la cible du lien symbolique';

  @override
  String get settingsAutoConnect => 'Connexion automatique au démarrage';

  @override
  String get settingsAutoConnectFixed => 'Serveur SSH par défaut fixe';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Toujours se connecter au serveur sélectionné ci-dessous';

  @override
  String get settingsAutoConnectLast => 'Se souvenir de la dernière connexion';

  @override
  String get settingsAutoConnectLastDesc =>
      'Se connecter au serveur auquel la dernière connexion a réussi';

  @override
  String get settingsAutoConnectPickServer => 'Serveur';

  @override
  String get settingsAutoConnectNoServer =>
      'Aucun serveur sélectionné pour le moment';

  @override
  String get sftpSort => 'Trier';

  @override
  String get sftpSortName => 'Nom';

  @override
  String get sftpSortSize => 'Taille';

  @override
  String get sftpSortDate => 'Date de modification';

  @override
  String get sftpSortAscending => 'Croissant';

  @override
  String get sftpSortDescending => 'Décroissant';

  @override
  String get themeQuickSwitch => 'Thème';

  @override
  String get transferList => 'Transferts';

  @override
  String get transferEmpty => 'Aucun transfert pour le moment';

  @override
  String get transferUpload => 'Téléversement';

  @override
  String get transferDownload => 'Téléchargement';

  @override
  String get transferStatusQueued => 'En file d\'attente';

  @override
  String get transferStatusRunning => 'Transfert en cours';

  @override
  String get transferStatusPaused => 'En pause';

  @override
  String get transferStatusCompleted => 'Terminé';

  @override
  String get transferStatusFailed => 'Échec';

  @override
  String get transferStatusCanceled => 'Annulé';

  @override
  String get transferPause => 'Pause';

  @override
  String get transferResume => 'Reprendre';

  @override
  String get transferCancel => 'Annuler';

  @override
  String get transferRemove => 'Supprimer';

  @override
  String get transferClearFinished => 'Effacer les terminés';

  @override
  String get transferSizeUnknown => 'Taille inconnue';

  @override
  String get transferFailedUpload => 'Échec du téléversement';

  @override
  String get transferFailedDownload => 'Échec du téléchargement';

  @override
  String get stopGeneration => 'Arrêter';

  @override
  String get chatServerBindingRequired =>
      'Cette session n\'est liée à aucun serveur. Veuillez la lier au serveur actuel pour continuer.';

  @override
  String get chatSessionUnboundNotice =>
      'Cette session n\'est liée à aucun serveur.';

  @override
  String get bindServerAction => 'Lier le serveur';

  @override
  String get bindServerDialogTitle => 'Lier la session au serveur';

  @override
  String get bindServerConfirmAction => 'Confirmer la liaison';

  @override
  String get chatSessionIdentityMismatch =>
      'Le serveur ou l\'agent actuel ne correspond pas à l\'identité liée de cette session. Basculez vers le serveur et l\'agent correspondants pour continuer.';

  @override
  String get deleteSessionTitle => 'Supprimer la session';

  @override
  String get deleteSessionConfirmAction => 'Supprimer';

  @override
  String get shareAgentSessionsTitle => 'Partager les sessions d\'agents';

  @override
  String get shareAgentSessionsSubtitle =>
      'Partager les sessions entre différents agents sur ce serveur';

  @override
  String get shareAgentSessionsEnabled => 'Partage de session d\'agent activé';

  @override
  String get shareAgentSessionsDisabled =>
      'Partage de session d\'agent désactivé';

  @override
  String get agentCliStatusInstalled => 'CLI : Installé';

  @override
  String get agentCliStatusMissing => 'CLI : Manquant';

  @override
  String get agentCliStatusChecking => 'CLI : Vérification en cours...';

  @override
  String get agentCliStatusUnknown => 'CLI : Inconnu';

  @override
  String get agentCliStatusError => 'CLI : Erreur';

  @override
  String get agentAcpStatusReady => 'ACP : Prêt';

  @override
  String get agentAcpStatusMissing => 'ACP : Manquant';

  @override
  String get agentAcpStatusChecking => 'ACP : Vérification en cours...';

  @override
  String get agentAcpStatusPendingCli => 'ACP : En attente du CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP : Inconnu';

  @override
  String get agentAcpStatusError => 'ACP : Erreur';

  @override
  String get agentAcpStatusNa => 'ACP : N/D';

  @override
  String get agentAuthStatusAuthenticated => 'Auth : Connecté';

  @override
  String get agentAuthStatusUnauthenticated => 'Auth : Non connecté';

  @override
  String get agentAuthStatusUnknown => 'Auth : Inconnu';

  @override
  String get downloadNotificationsUnavailable =>
      'Les notifications de téléchargement système sont indisponibles. Les téléchargements continuent en arrière-plan.';

  @override
  String get downloadOpenFailed =>
      'Impossible d\'ouvrir le fichier téléchargé.';

  @override
  String get dockerActionPending =>
      'Une action est déjà en cours pour ce conteneur';

  @override
  String get dockerNoLogs => '(Aucun journal)';

  @override
  String get serverReboot => 'Redémarrer';

  @override
  String get serverRebootDialogTitle => 'Confirmer le redémarrage du serveur';

  @override
  String get serverRebootDialogMessage =>
      'Voulez-vous vraiment redémarrer ce serveur ? Toutes les connexions actives et les services d\'arrière-plan seront interrompus.';

  @override
  String get serverRebootConfirmButton => 'Redémarrer maintenant';

  @override
  String get serverRebootPasswordTitle => 'Mot de passe Sudo requis';

  @override
  String get serverRebootPasswordMessage =>
      'Des privilèges root sont requis pour redémarrer le serveur. Veuillez saisir le mot de passe sudo (utilisé une fois, non enregistré) :';

  @override
  String get serverRebootPasswordHint => 'Mot de passe Sudo';

  @override
  String get serverRebootSubmitting => 'Envoi de la commande de redémarrage...';

  @override
  String get serverRebootAccepted =>
      'Commande de redémarrage acceptée ; l\'achèvement n\'est pas encore vérifié. Veuillez vous reconnecter lorsque le serveur sera de nouveau en ligne.';

  @override
  String get serverRebootVerified =>
      'Le redémarrage du serveur a été vérifié ; le système est de nouveau en ligne.';

  @override
  String get serverRebootUnknown =>
      'Résultat du redémarrage incertain. La commande a été transmise, mais la finalisation n\'a pas pu être confirmée. Veuillez vérifier manuellement la connexion.';

  @override
  String get serverRebootReconnect => 'Reconnecter';

  @override
  String get serverRebootServerChanged =>
      'Le serveur cible a changé, redémarrage annulé';

  @override
  String get navCliChat => 'Chat CLI';

  @override
  String get cliChatTitle => 'Sessions CLI';

  @override
  String get cliChatSubtitle =>
      'Sessions natives de l\'agent CLI sur le serveur distant';

  @override
  String get cliSelectAgent => 'Sélectionner un agent';

  @override
  String get cliNoAgentsConfigured => 'Aucun agent ajouté pour ce serveur';

  @override
  String get cliAgentNeedsSetup =>
      'Environnement d\'agent manquant ou non connecté';

  @override
  String get cliManageAgentsGuide => 'Configurer dans la gestion des agents';

  @override
  String get cliNewDraft => 'Nouveau brouillon';

  @override
  String get cliNewDraftTooltip =>
      'Créer un brouillon vierge (session créée au premier message)';

  @override
  String get cliDeleteSessionTitle =>
      'Supprimer l\'historique de session CLI distant';

  @override
  String get cliDeleteSessionMessage =>
      'Cela supprimera définitivement l\'historique de session CLI sur le serveur distant. Voulez-vous vraiment continuer ?';

  @override
  String get cliDeleteConfirmButton => 'Supprimer la session';

  @override
  String get cliCannotDeleteTooltip =>
      'Suppression de session distante non prise en charge ou désactivée';

  @override
  String get cliSessionsHeader => 'Sessions';

  @override
  String get cliNoSessions => 'Aucune session CLI trouvée';

  @override
  String get cliFilterCwdHint => 'Filtrer par chemin CWD...';

  @override
  String get cliFilterCwdAction => 'Filtrer';

  @override
  String get cliClearCwdAction => 'Effacer';

  @override
  String get cliLoadMoreSessions => 'Charger plus de sessions';

  @override
  String get cliRefreshSessions => 'Actualiser';

  @override
  String get cliClaudeReadOnlyNotice =>
      'L\'historique Claude est en lecture seule. Poursuivez la conversation dans le vrai terminal.';

  @override
  String get cliContinueInTerminal => 'Continuer dans le terminal';

  @override
  String get cliOpenTerminal => 'Ouvrir le terminal';

  @override
  String get cliCloseTerminal => 'Fermer le terminal';

  @override
  String get cliTerminalRunning => 'Terminal CLI interactif';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Cet agent ne prend pas en charge la synchronisation structurée de l\'historique. Veuillez utiliser le terminal CLI natif pour interagir et sélectionner une session.';

  @override
  String get cliInstallSdkTitle => 'Installer le SDK officiel Claude History';

  @override
  String get cliInstallSdkMessage =>
      'Le SDK officiel Claude Code History est manquant sur le serveur distant. Souhaitez-vous l\'installer maintenant ?';

  @override
  String get cliInstallSdkAction => 'Installer le SDK officiel';

  @override
  String get cliApprovalsTitle => 'Approbations en attente';

  @override
  String get cliApprovalDetails => 'Détails';

  @override
  String get cliApprovalAllow => 'Autoriser';

  @override
  String get cliApprovalDecline => 'Refuser';

  @override
  String get cliInputHint => 'Saisir un message pour l\'agent CLI...';

  @override
  String get cliSend => 'Envoyer';

  @override
  String get cliStop => 'Arrêter';

  @override
  String get cliBusy => 'Opération en cours, veuillez patienter...';

  @override
  String get cliDisconnected => 'SSH n\'est pas connecté';

  @override
  String get cliServerChanged => 'Le serveur cible a changé';

  @override
  String get cliTurnFailed => 'Échec de l\'exécution du tour CLI';

  @override
  String get cliUseTerminal =>
      'Invite interactive requise, veuillez ouvrir le terminal pour continuer';

  @override
  String get cliDeleteFailed =>
      'Échec de la suppression de la session distante';

  @override
  String get cliDeleteUnsupported =>
      'La suppression de sessions distantes n\'est pas prise en charge par ce CLI';

  @override
  String get cliOperationFailed => 'Échec de l\'opération CLI';

  @override
  String get cliHistorySdkMissing =>
      'Le SDK d\'historique officiel est manquant sur le serveur';

  @override
  String get cliHistoryRuntimeMissing =>
      'L\'historique Claude nécessite Node.js/npm sur le serveur. Veuillez installer Node.js manuellement ; vous pouvez toujours utiliser le vrai CLI dans le terminal.';

  @override
  String get cliLoginRequired =>
      'Connexion à l\'agent requise. Veuillez vous connecter via la gestion des agents.';

  @override
  String get cliNotInstalled =>
      'CLI de l\'agent non installé. Veuillez l\'installer via la gestion des agents.';

  @override
  String get cliVersionUnsupported =>
      'La version du CLI de l\'agent n\'est pas prise en charge. Veuillez le mettre à niveau ou le réinstaller via la gestion des agents.';

  @override
  String get settingsNavigation => 'Navigation';

  @override
  String get settingsNavigationDesc =>
      'Configurer la page de démarrage par défaut et la barre de navigation inférieure';

  @override
  String get settingsStartupPage => 'Page de démarrage';

  @override
  String get settingsStartupPageDesc =>
      'Page affichée à l\'ouverture de l\'application';

  @override
  String get settingsBottomNav => 'Barre de navigation inférieure';

  @override
  String get settingsBottomNavDesc =>
      'Sélectionner les sections à afficher dans la barre inférieure mobile (prend en charge de 0 à 9 éléments)';

  @override
  String get settingsResetSuccess =>
      'Tous les paramètres ont été restaurés par défaut';

  @override
  String get metricsTrendSubtitle =>
      'Dernières ~3 minutes (jusqu\'à 60 échantillons)';

  @override
  String get metricsCurrent => 'Actuel';

  @override
  String get metricsPeak => 'Pic';

  @override
  String get metricsValley => 'Creux';

  @override
  String get metricsTrendWaiting => 'Collecte des données de métriques...';

  @override
  String get metricsTrendStopped =>
      'Collecte de données arrêtée (SSH déconnecté)';

  @override
  String get dockerActionTerminal => 'Terminal Exec';

  @override
  String get dockerTerminalTitle => 'Terminal de conteneur';

  @override
  String get dockerTerminalNotRunning =>
      'Le conteneur n\'est pas en cours d\'exécution';

  @override
  String get setDefaultAgent => 'Définir par défaut';

  @override
  String get defaultBadge => 'Par défaut';

  @override
  String get isDefaultAgent => 'Agent par défaut';

  @override
  String get setAsDefaultAgent =>
      'Définir comme agent par défaut pour ce serveur';

  @override
  String get agentGroupBasic => 'Informations de base';

  @override
  String get agentGroupCommands => 'Commandes';

  @override
  String get agentGroupAuth => 'Installation & Authentification';

  @override
  String get agentPresetTitle => 'Modèle prédéfini';

  @override
  String get resourceProcessList => 'Processus';

  @override
  String get resourceDiskScanning =>
      'Analyse des répertoires racine, cela peut prendre quelques secondes...';

  @override
  String get resourceDiskScanPartial =>
      'Certains répertoires n\'ont pas pu être analysés en raison d\'autorisations ou d\'un délai dépassé';

  @override
  String get resourceDiskDirectories =>
      'Utilisation des répertoires de premier niveau';

  @override
  String get resourceSortCpu => 'Trier par processeur';

  @override
  String get resourceSortMemory => 'Trier par mémoire';

  @override
  String get resourceRss => 'Mémoire RSS';

  @override
  String get resourceUsed => 'Utilisé';

  @override
  String get resourceAvailable => 'Disponible';

  @override
  String get resourceTotal => 'Total';

  @override
  String get settingsBottomNavOrderTitle =>
      'Éléments sélectionnés (Faites glisser pour réorganiser)';

  @override
  String get langSystem => 'Système par défaut';

  @override
  String get serverFieldRequired => 'Requis';

  @override
  String get serverPortInvalid => 'Le port doit être compris entre 1 et 65535';

  @override
  String get serverTestReachability => 'Tester l\'accessibilité';

  @override
  String get serverSaveFailedGeneric =>
      'Échec de l\'enregistrement du serveur. Veuillez vérifier votre configuration et réessayer.';

  @override
  String get serverViewPrivateKey => 'Afficher la clé privée';

  @override
  String get serverHidePrivateKey => 'Masquer la clé privée';

  @override
  String get dockerBashFallbackNotice =>
      'Bash indisponible dans le conteneur, bascule vers Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Répertoire de travail';

  @override
  String get cliDefaultWorkingDir => 'Par défaut (/)';

  @override
  String get cliPickWorkingDirTitle => 'Sélectionner le répertoire de travail';

  @override
  String get cliClearWorkingDir => 'Réinitialiser par défaut';

  @override
  String get cliBrowseWorkingDir => 'Parcourir';

  @override
  String get cliSelectCurrentDir => 'Sélectionner ce répertoire';

  @override
  String get cliNavigateUp => 'Dossier parent';

  @override
  String get chatSessionsTooltip => 'Sessions';

  @override
  String get hardwareSpecsTitle => 'Matériel & Système';

  @override
  String get hardwareCpu => 'Processeur';

  @override
  String get hardwareMemory => 'Mémoire';

  @override
  String get hardwareDisk => 'Disque racine';

  @override
  String get hardwareDistribution => 'OS';

  @override
  String get hardwareKernel => 'Noyau';

  @override
  String get hardwareLoading => 'Chargement des spécifications matérielles...';

  @override
  String get hardwareUnavailable => 'Spécifications matérielles indisponibles';

  @override
  String get hardwareUnknown => 'Inconnu';

  @override
  String get systemInfoTitle => 'Infos système';

  @override
  String get systemInfoTapHint => 'Appuyer pour afficher l\'art ASCII';

  @override
  String get systemInfoHost => 'Hôte';

  @override
  String get serverShutdown => 'Éteindre';

  @override
  String get serverShutdownDialogTitle => 'Confirmer l\'arrêt du serveur';

  @override
  String get serverShutdownDialogMessage =>
      'Voulez-vous vraiment éteindre ce serveur ? Le système sera complètement mis hors tension et ne pourra plus être joint à distance jusqu\'à un démarrage manuel.';

  @override
  String get serverShutdownConfirmButton => 'Éteindre maintenant';

  @override
  String get serverShutdownSubmitting =>
      'Envoi de la commande d\'extinction...';

  @override
  String get serverShutdownAccepted =>
      'Commande d\'extinction acceptée ; l\'achèvement de l\'arrêt n\'a pas été vérifié.';

  @override
  String get serverShutdownUnknown =>
      'Résultat d\'extinction inconnu : la commande a peut-être été envoyée mais n\'a pas pu être confirmée. Veuillez vérifier manuellement ; aucun nouvel essai automatique ne sera fait.';

  @override
  String get serverShutdownPasswordTitle =>
      'Mot de passe Sudo requis pour l\'arrêt';

  @override
  String get serverShutdownPasswordMessage =>
      'Des privilèges root sont requis pour éteindre le serveur. Veuillez saisir le mot de passe sudo (utilisé une fois, non enregistré) :';

  @override
  String get serverShutdownPasswordHint => 'Mot de passe Sudo';

  @override
  String get serverShutdownServerChanged =>
      'Le serveur cible a changé, arrêt annulé';

  @override
  String get metricsNetwork => 'Débit réseau';

  @override
  String get networkModalTitle => 'Détails des interfaces réseau';

  @override
  String get networkDownloadRate => 'Téléchargement (RX)';

  @override
  String get networkUploadRate => 'Téléversement (TX)';

  @override
  String get networkTotalRx => 'Total RX';

  @override
  String get networkTotalTx => 'Total TX';

  @override
  String get networkPrimary => 'Route par défaut';

  @override
  String get networkRatesEmpty => 'Aucune interface réseau active détectée';

  @override
  String get networkWaitingSecondSample => 'En attente du deuxième échantillon';

  @override
  String get networkUnavailable => 'Indisponible';

  @override
  String get networkNoDefaultInterface => 'Aucune route par défaut';

  @override
  String get selectThemeModeTitle => 'Sélectionner le mode du thème';

  @override
  String get selectLanguageTitle => 'Sélectionner la langue';

  @override
  String get selectStartupPageTitle => 'Sélectionner la page de démarrage';

  @override
  String get selectAutoConnectModeTitle =>
      'Sélectionner le mode de connexion automatique';

  @override
  String get accentColorDialogTitle =>
      'Personnaliser les couleurs d\'accentuation';

  @override
  String get accentColorLightMode => 'Mode clair';

  @override
  String get accentColorDarkMode => 'Mode sombre';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Préréglages';

  @override
  String get accentColorHsvPicker => 'Roue chromatique';

  @override
  String get accentColorHexCode => 'Code couleur Hex';

  @override
  String get accentColorPreview => 'Aperçu';

  @override
  String get accentColorSampleButton => 'Bouton d\'accentuation';

  @override
  String get accentColorInvalidHex =>
      'Format hexadécimal non valide (par ex. #10B981)';

  @override
  String get settingsDashboardQuickActions =>
      'Actions rapides du tableau de bord';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Configurer les raccourcis affichés sur le tableau de bord. Tout désélectionner masque la section des actions rapides.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Actions rapides masquées (aucun raccourci sélectionné)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Faites glisser pour réorganiser les raccourcis';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Sélectionner les raccourcis visibles';

  @override
  String get terminalCopySelection => 'Copier';

  @override
  String get terminalSelectionCopied =>
      'Sélection copiée dans le presse-papiers';

  @override
  String get editAgent => 'Modifier l\'agent';

  @override
  String get agentExecutionTarget => 'Environnement d\'exécution';

  @override
  String get agentExecutionHost => 'Système hôte';

  @override
  String get agentExecutionDocker => 'Conteneur Docker';

  @override
  String get agentContainerBinding => 'Mode de liaison du conteneur';

  @override
  String get agentContainerBindingId => 'Par ID de conteneur';

  @override
  String get agentContainerBindingName => 'Par nom de conteneur';

  @override
  String get agentContainerReference => 'Conteneur cible';

  @override
  String get agentContainerReferenceHint =>
      'Sélectionner ou saisir l\'ID ou le nom du conteneur';

  @override
  String get agentContainerRequired =>
      'Le conteneur cible est requis pour l\'exécution Docker';

  @override
  String get agentLoadingContainers =>
      'Interrogation des conteneurs sur le serveur...';

  @override
  String get agentNoContainersFound => 'Aucun conteneur trouvé sur ce serveur';

  @override
  String get agentContainerUser =>
      'Utilisateur d\'exécution du conteneur (Optionnel)';

  @override
  String get agentContainerUserHint => 'par ex. dev';

  @override
  String get agentContainerUserHelper =>
      'Laisser vide pour utiliser l\'utilisateur par défaut de l\'image ; par ex. dev ; prend en charge user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect =>
      'Sélectionner l\'utilisateur du conteneur';

  @override
  String get agentContainerUsersLoading => 'Chargement des utilisateurs...';

  @override
  String get agentContainerUsersEmpty => 'Aucun utilisateur trouvé dans passwd';

  @override
  String get agentViewDiagnosticLog => 'Afficher le journal de diagnostic';

  @override
  String get agentDiagnosticLogCopied =>
      'Journal de diagnostic copié dans le presse-papiers';

  @override
  String get agentDiagnosticLogCopy => 'Copier';

  @override
  String get agentDiagnosticLogClose => 'Fermer';

  @override
  String get settingsCliHistoryPageSize =>
      'Taille de page de l\'historique CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Nombre d\'anciens messages chargés par page lors du défilement vers le haut (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Sélectionner la taille de page de l\'historique CLI';

  @override
  String get cliLoadingOlderMessages =>
      'Chargement des messages plus anciens...';

  @override
  String get chatLoadOlderMessages => 'Charger les messages précédents';

  @override
  String get chatCommandsTooltip => 'Commandes';

  @override
  String get chatAttachTooltip => 'Joindre un fichier';

  @override
  String get chatAttachImage => 'Joindre une image locale';

  @override
  String get chatAttachLocalText => 'Joindre un fichier texte local';

  @override
  String get chatAttachRemoteText => 'Joindre un fichier texte distant';

  @override
  String get chatAttachRemotePathTitle => 'Joindre un fichier texte distant';

  @override
  String get chatAttachRemotePathHint => '/chemin/vers/fichier.txt';

  @override
  String get chatAttachTooLarge => 'Le fichier dépasse la limite de taille';

  @override
  String get chatUsageAndDiagnostics => 'Utilisation & Diagnostic';

  @override
  String get chatWorkingDirTooltip => 'Répertoire de travail du brouillon';

  @override
  String get chatAttachFailed => 'Échec de l\'ajout de la pièce jointe';

  @override
  String get chatInvalidRemotePath =>
      'Chemin de fichier distant non valide (doit commencer par /)';

  @override
  String get chatRemoteReadFailed => 'Impossible de lire le fichier distant';

  @override
  String get chatInvalidDirPath =>
      'Chemin de répertoire non valide (doit commencer par /)';

  @override
  String get chatNoSubdirectories => 'Aucun sous-répertoire';

  @override
  String get chatUsageTitle => 'Utilisation des jetons & Coûts';

  @override
  String get chatUsageUsed => 'Jetons utilisés';

  @override
  String get chatUsageSize => 'Taille du contexte';

  @override
  String get chatUsageCost => 'Coût';

  @override
  String get chatDiagnosticsTitle => 'Journal de diagnostic';

  @override
  String get chatNoDiagnostics => 'Aucun journal de diagnostic disponible';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Cela supprime uniquement l\'enregistrement local dans Valhalla et ne supprimera pas l\'historique natif de l\'agent sur le serveur.';

  @override
  String get chatSearchSessionsHint => 'Rechercher des sessions...';

  @override
  String get chatLoadMoreSessions => 'Charger plus de sessions';

  @override
  String get chatLoadingMoreSessions =>
      'Chargement de sessions supplémentaires...';

  @override
  String get chatExportSession => 'Exporter la session (Markdown)';

  @override
  String get chatExportSuccess => 'Session exportée avec succès';

  @override
  String get chatExportFailed => 'Échec de l\'exportation de la session';

  @override
  String get chatRemoteSessions => 'Sessions distantes';

  @override
  String get chatRemoteSessionsTitle => 'Sessions de l\'agent distant';

  @override
  String get chatRemoteSessionsDesc =>
      'Consulter et importer l\'historique natif des sessions de l\'agent distant';

  @override
  String get chatRemoteSessionsEmpty => 'Aucune session distante trouvée';

  @override
  String get chatRemoteImporting => 'Importation de l\'historique distant...';

  @override
  String get chatRemoteImportFailed =>
      'Échec de l\'importation de la session distante';

  @override
  String get chatStatusInterrupted => 'Interrompu';

  @override
  String get chatStatusFailed => 'Échec';

  @override
  String get chatStatusAwaitingAuth => 'En attente d\'authentification ACP';

  @override
  String get chatShowFullOutput => 'Afficher toute la sortie';

  @override
  String get chatShowLessOutput => 'Afficher moins';

  @override
  String get chatToolLocations => 'Chemins affectés';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Saisir une valeur pour $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Processus $pid terminé';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Action $action sur $service réussie';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Règle déclenchée : $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Code de sortie : $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Connexion réussie à $server via SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Échec de connexion SSH : $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Connexion à $host ($type) pour la première fois.\n\nEmpreinte SHA-256 :\n$fingerprint\n\nFaire confiance à cette empreinte et se connecter ?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Saisir le mot de passe pour $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Voulez-vous vraiment supprimer le serveur \'$name\' ? Cette action est irréversible.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Voulez-vous vraiment supprimer l\'agent \'$name\' ? Cela supprime sa configuration et son état d\'exécution sur ce serveur sans affecter les sessions de discussion passées ni les identifiants SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Dernière vérification : $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Choisir le mode de connexion à $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Reconnexion… (tentative $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n session(s) active(s)';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Lier cette session au serveur \\\"$serverName\\\" ? Une fois liée, cette session sera associée à ce serveur.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Voulez-vous vraiment supprimer la session \\\"$title\\\" ? Cette action est irréversible.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return '$action sur le conteneur $name réussie';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Échec de l\'action : $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Serveur cible : $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Sessions de terminal : $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Sessions d\'agent : $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Transferts actifs : $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Échec du redémarrage : $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Échec de la suppression de la session distante : $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Tendance de $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Avertissement : $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Danger : $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count points de données';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Utilisation des ressources de $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'Port TCP $port accessible';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Échec de connexion : $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Échec de l\'enregistrement du serveur : $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Cœurs';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Échec de l\'arrêt : $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Interface : $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Échec du chargement des conteneurs : $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Échec du chargement des utilisateurs du conteneur : $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Journal de diagnostic - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Échec de la détection de Docker/conteneur';

  @override
  String get chatCopiedAllMessages => 'Tous les messages ont été copiés';

  @override
  String get chatCopyAllMessages => 'Copier tous les messages';

  @override
  String get cliModelAtCapacity =>
      'Le modèle sélectionné est à pleine capacité. Essayez un autre modèle.';

  @override
  String get chatLaunchBlankDraft => 'Brouillon vierge';

  @override
  String get chatLaunchFixedSession => 'Session fixe';

  @override
  String get chatLaunchRememberLast => 'Mémoriser la dernière session';

  @override
  String get chatPermissionAskEveryTime => 'Demander à chaque fois';

  @override
  String get chatPermissionAutoAllowAll => 'Tout autoriser automatiquement';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'L\'agent exécutera toutes les opérations sans confirmation. Continuer ?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Autoriser toutes les opérations ?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Autoriser automatiquement les opérations sûres';

  @override
  String get chatRunSettingsDefault => 'Par défaut';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI interactif';

  @override
  String get chatRunSettingsModel => 'Modèle';

  @override
  String get chatRunSettingsPermissions => 'Autorisations';

  @override
  String get chatRunSettingsReasoning => 'Niveau de raisonnement';

  @override
  String get chatRunSettingsTitle => 'Paramètres d\'exécution';

  @override
  String get cliActionInsertCommand => 'Insérer une commande';

  @override
  String get cliActionInsertFile => 'Insérer un fichier';

  @override
  String get cliActionInsertWorkdir => 'Insérer le répertoire de travail';

  @override
  String get cliComposerInsertAction => 'Insérer';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Échec de l\'opération CLI : $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Sélectionner une commande';

  @override
  String get defaultAgentTitle => 'Agent par défaut';

  @override
  String get insertSkills => 'Insérer des compétences';

  @override
  String get isDefaultSession => 'Session par défaut';

  @override
  String get sessionLaunchMode => 'Mode de lancement de session';

  @override
  String get setAsDefaultSession => 'Définir comme session par défaut';

  @override
  String get navNas => 'Média NAS';

  @override
  String get nasAddExcludePath => 'Ajouter un chemin exclu';

  @override
  String get nasAddIncludePath => 'Ajouter un dossier à analyser';

  @override
  String get nasCancelScan => 'Annuler l\'analyse';

  @override
  String get nasClearSearch => 'Effacer la recherche';

  @override
  String get nasConfigDialogTitle => 'Paramètres de la médiathèque';

  @override
  String get nasConfigure => 'Configurer';

  @override
  String get nasConfigureScanDirs => 'Configurer les dossiers d\'analyse';

  @override
  String get nasCreatePlaylist => 'Créer une playlist';

  @override
  String get nasEmptyConfigDesc =>
      'Ajoutez au moins un dossier pour commencer à créer votre médiathèque.';

  @override
  String get nasEmptyConfigTitle => 'Aucun dossier d\'analyse configuré';

  @override
  String get nasExcludePaths => 'Dossiers exclus';

  @override
  String get nasExcludedBadge => 'Exclu';

  @override
  String get nasFilterImages => 'Images';

  @override
  String get nasFilterVideos => 'Vidéos';

  @override
  String get nasIncludePaths => 'Dossiers d\'analyse';

  @override
  String nasItemCount(Object value) {
    return '$value éléments';
  }

  @override
  String nasLastScan(Object value) {
    return 'Dernière analyse : $value';
  }

  @override
  String get nasLibrarySettings => 'Paramètres de la bibliothèque';

  @override
  String nasMediaOpening(Object value) {
    return 'Ouverture de $value…';
  }

  @override
  String get nasMiniPlayer => 'Mini lecteur';

  @override
  String get nasNoExcludePaths => 'Aucun dossier exclu';

  @override
  String get nasNoFavorites => 'Pas encore de favoris';

  @override
  String get nasNoIncludePaths => 'Aucun dossier d\'analyse';

  @override
  String get nasNoIndexDesc =>
      'Configurez des dossiers et lancez une analyse pour indexer vos médias.';

  @override
  String get nasNoIndexTitle => 'La médiathèque est vide';

  @override
  String get nasNoPlaylists => 'Pas encore de playlists';

  @override
  String get nasNoSearchResults => 'Aucun média correspondant';

  @override
  String get nasNotScanned => 'Pas encore analysé';

  @override
  String get nasNowPlaying => 'Lecture en cours';

  @override
  String get nasOpenMethodPrompt =>
      'Comment souhaitez-vous ouvrir ce fichier ?';

  @override
  String get nasOpenPolicyAsk => 'Demander à chaque fois';

  @override
  String get nasOpenPolicyExternal => 'Ouvrir avec une autre application';

  @override
  String get nasOpenPolicyInApp => 'Ouvrir dans l\'application';

  @override
  String get nasOpeningPolicy => 'Méthode d\'ouverture par défaut';

  @override
  String get nasPlaylistName => 'Nom de la playlist';

  @override
  String get nasQuickStats => 'Vue d\'ensemble de la bibliothèque';

  @override
  String get nasScan => 'Analyser maintenant';

  @override
  String get nasScanCancelled => 'Analyse annulée';

  @override
  String nasScanFailed(Object value) {
    return 'Échec de l\'analyse : $value';
  }

  @override
  String get nasScanning => 'Analyse en cours…';

  @override
  String get nasScopeBadge => 'Portée de l\'analyse';

  @override
  String get nasSearchHint => 'Rechercher des médias';

  @override
  String get nasStatMusic => 'Musique';

  @override
  String get nasStatPhotos => 'Photos';

  @override
  String get nasStatTotal => 'Total';

  @override
  String get nasStatVideos => 'Vidéos';

  @override
  String get nasTabFavorites => 'Favoris';

  @override
  String get nasTabFolders => 'Dossiers';

  @override
  String get nasTabHome => 'Accueil';

  @override
  String get nasTabMusic => 'Musique';

  @override
  String get nasTabPhotos => 'Photos';

  @override
  String get nasTabPlaylists => 'Playlists';

  @override
  String get nasTabVideos => 'Vidéos';

  @override
  String get nasSources => 'Sources de médias';

  @override
  String get nasAddSource => 'Ajouter une source de médias';

  @override
  String get nasEditSource => 'Modifier la source de médias';

  @override
  String get nasRemoveSource => 'Supprimer la source de médias';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Voulez-vous vraiment supprimer la source de médias \'$name\' ? Cela supprime sa configuration sans effacer les fichiers distants.';
  }

  @override
  String get nasNoSources => 'Aucune source de médias configurée';

  @override
  String get nasNoSourcesDesc =>
      'Ajoutez SFTP, SMB, WebDAV, Jellyfin ou Emby pour commencer à parcourir les médias.';

  @override
  String get nasSourceType => 'Type de source';

  @override
  String get nasSourceName => 'Nom de la source';

  @override
  String get nasProbe => 'Tester la connexion';

  @override
  String get nasProbeSuccess => 'Connexion réussie';

  @override
  String get nasProbeFailed => 'Échec du test de connexion';

  @override
  String get nasEndpoint => 'Point de terminaison / URL';

  @override
  String get nasRootPath => 'Chemin racine';

  @override
  String get nasUsername => 'Nom d\'utilisateur';

  @override
  String get nasPassword => 'Mot de passe';

  @override
  String get nasDomain => 'Domaine (optionnel)';

  @override
  String get nasAuthenticate => 'S\'authentifier';

  @override
  String get nasAuthSuccess => 'Authentification réussie';

  @override
  String get nasAuthFailed => 'Échec de l\'authentification';

  @override
  String get nasTabDownloads => 'Téléchargements';

  @override
  String get nasNoDownloads => 'Aucune tâche de téléchargement';

  @override
  String get nasDownloadQueued => 'En file d\'attente';

  @override
  String get nasDownloadDownloading => 'Téléchargement en cours';

  @override
  String get nasDownloadCompleted => 'Terminé';

  @override
  String get nasDownloadCancelled => 'Annulé';

  @override
  String get nasDownloadFailed => 'Échec du téléchargement';

  @override
  String get nasRetryDownload => 'Réessayer';

  @override
  String get nasCancelDownload => 'Annuler';

  @override
  String get nasOpenDownloadedFile => 'Ouvrir le fichier';

  @override
  String get nasQueue => 'File de lecture';

  @override
  String get nasNoQueue => 'La file d\'attente est vide';

  @override
  String get nasSpeed => 'Vitesse';

  @override
  String get nasQuality => 'Qualité';

  @override
  String get nasAudioTrack => 'Piste audio';

  @override
  String get nasSubtitleTrack => 'Sous-titres';

  @override
  String get nasRepeatOff => 'Répétition désactivée';

  @override
  String get nasRepeatAll => 'Tout répéter';

  @override
  String get nasRepeatOne => 'Répéter un titre';

  @override
  String get nasShuffle => 'Aléatoire';

  @override
  String get nasCast => 'Diffuser (Cast)';

  @override
  String get nasCastUnavailable => 'Aucun appareil de diffusion disponible';

  @override
  String get nasSlideshow => 'Diaporama';

  @override
  String get nasByFolder => 'Dossiers';

  @override
  String get nasByArtist => 'Artistes';

  @override
  String get nasByAlbum => 'Albums';

  @override
  String get nasAllTracks => 'Tous les titres';

  @override
  String get nasPlayAll => 'Tout lire';

  @override
  String get nasPreviousPage => 'Précédent';

  @override
  String get nasNextPage => 'Suivant';

  @override
  String get nasClearScope => 'Retour à tout';

  @override
  String get nasRenamePlaylist => 'Renommer la playlist';

  @override
  String get nasRemoveFromPlaylist => 'Supprimer de la playlist';

  @override
  String get nasMoveUp => 'Monter';

  @override
  String get nasMoveDown => 'Descendre';

  @override
  String get nasSshServer => 'Serveur SSH';

  @override
  String get nasSelectSshServer => 'Sélectionner un serveur SSH enregistré';

  @override
  String get nasQualityOriginal => 'Originale';

  @override
  String get nasQualityAuto => 'Automatique';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Appareils DLNA disponibles';

  @override
  String get nasCastDiscovering => 'Recherche d\'appareils DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'Relais du flux via l\'application au premier plan. Gardez Valhalla ouvert.';

  @override
  String get nasCastStop => 'Arrêter la diffusion';

  @override
  String get nasCastVolume => 'Volume';

  @override
  String get nasCastRetry => 'Réessayer la recherche';

  @override
  String get nasInstallTitle => 'Déployer le serveur multimédia NAS';

  @override
  String get nasInstallProduct => 'Produit';

  @override
  String get nasInstallMediaPath => 'Répertoire multimédia (Lecture seule)';

  @override
  String get nasInstallDataRoot => 'Répertoire de données & config';

  @override
  String get nasInstallPort => 'Port';

  @override
  String get nasInstallBindAddress => 'Adresse de liaison';

  @override
  String get nasInstallWebdavUser => 'Nom d\'utilisateur WebDAV';

  @override
  String get nasInstallWebdavPassword =>
      'Mot de passe WebDAV (12 caractères min.)';

  @override
  String get nasInstallPreparePlan => 'Examiner le plan de déploiement';

  @override
  String get nasInstallPlanTitle => 'Revue technique & Confirmation';

  @override
  String get nasInstallBlockersTitle => 'Points bloquants du déploiement';

  @override
  String get nasInstallConfirmDeploy => 'Confirmer & Installer';

  @override
  String get nasInstallDeploying => 'Déploiement du conteneur...';

  @override
  String get nasInstallSuccess => 'Déployé avec succès';

  @override
  String get nasInstallSuccessDesc =>
      'Le service est désormais en cours d\'exécution. Terminez la configuration initiale du serveur avant de l\'ajouter comme source de médias.';

  @override
  String get nasInstallContainerId => 'ID du conteneur';

  @override
  String get nasInstallEndpoint => 'Point de terminaison';

  @override
  String get nasUseSshTunnel => 'Utiliser un tunnel SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'Acheminer le trafic via un serveur SSH enregistré (par ex. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Le point de terminaison doit être accessible depuis le serveur SSH, par ex. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Laisser vide pour conserver le mot de passe / jeton existant';

  @override
  String get nasSourceNameRequired => 'Le nom de la source est requis';

  @override
  String get nasInvalidEndpoint =>
      'URL ou protocole de point de terminaison non valide';

  @override
  String get nasSourceUnreachable =>
      'Impossible de joindre la source de médias';

  @override
  String get nasSshTunnelFailed => 'Échec de la connexion par tunnel SSH';

  @override
  String get nasOperationFailed => 'Échec de l\'opération';

  @override
  String get nasInstallStepCreateDir => 'Créer le répertoire privé';

  @override
  String get nasInstallStepWriteCompose =>
      'Écrire la configuration docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Écrire les identifiants privés';

  @override
  String get nasInstallStepPullImage =>
      'Télécharger l\'image de conteneur épinglée';

  @override
  String get nasInstallStepStartService => 'Démarrer le service conteneurisé';

  @override
  String get nasInstallStepCheckHttp => 'Vérifier la santé HTTP du service';

  @override
  String get nasInstallBlockerDocker =>
      'Docker Engine est requis sur le serveur cible';

  @override
  String get nasInstallBlockerCompose => 'Le plugin Docker Compose est requis';

  @override
  String get nasInstallBlockerIdentity =>
      'L\'identité du serveur cible n\'a pas pu être vérifiée';

  @override
  String get nasInstallBlockerTools =>
      'Les outils requis (curl, ss, realpath) sont manquants sur le serveur cible';

  @override
  String get nasInstallBlockerMedia =>
      'Le répertoire multimédia n\'existe pas ou n\'est pas lisible';

  @override
  String get nasInstallBlockerParent =>
      'Le répertoire parent de la racine des données n\'est pas accessible en écriture';

  @override
  String get nasInstallBlockerOverlap =>
      'Le répertoire multimédia et le répertoire de données ne peuvent pas se chevaucher';

  @override
  String get nasInstallBlockerCollision =>
      'Le répertoire de données cible existe déjà ou est un lien symbolique';

  @override
  String get nasInstallBlockerPort =>
      'Le port sélectionné est déjà utilisé sur le serveur cible';

  @override
  String get nasInstallBlockerContainer =>
      'Un conteneur portant ce nom de projet existe déjà';

  @override
  String get nasInstallBlockerImage =>
      'Échec de la vérification de l\'image du conteneur. Vérifiez le nom de l\'image, la connectivité réseau et l\'architecture du serveur, puis réessayez.';

  @override
  String get nasInstallGuidanceTunnel =>
      'La liaison loopback (127.0.0.1) nécessite un tunnel SSH pour l\'accès à distance';

  @override
  String get nasInstallGuidanceTls =>
      'Il est recommandé de sécuriser la liaison publique derrière un proxy inverse TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Terminez la configuration initiale du compte administrateur dans le navigateur au premier lancement';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Le répertoire multimédia est monté en lecture seule pour préserver vos fichiers';

  @override
  String get nasInstallGuidancePreserved =>
      'Le répertoire de données sera conservé en cas d\'échec pour le dépannage';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Téléchargé (Impossible d\'ouvrir avec une application externe)';

  @override
  String get nasRetryOpen => 'Réessayer d\'ouvrir';

  @override
  String get nasExternalOpenFailed =>
      'Impossible d\'ouvrir le fichier dans une application externe';

  @override
  String get nasTitle => 'Média NAS';

  @override
  String get nasLoadMoreGroups => 'Charger plus de groupes';

  @override
  String get nasMetadataEnriching => 'Enrichissement des balises musicales...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Enrichissement des balises musicales ($count traitées)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Téléchargement de $value…';
  }

  @override
  String get nasSubtitleNone => 'Aucun';

  @override
  String get nasLibraryId => 'ID de bibliothèque';

  @override
  String get nasLibraryIdHint =>
      'Par défaut : tout (/), ou spécifiez l\'ID de bibliothèque';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relatif à la racine de la source ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'La source a changé pendant la configuration, enregistrement annulé';

  @override
  String get nasInvalidLibraryId => 'ID de bibliothèque non valide';

  @override
  String get startupFailed => 'Échec du démarrage de l\'application';

  @override
  String get startupFailedDesc =>
      'Une erreur inattendue est survenue au démarrage. Vous pouvez réessayer ou exporter les journaux de diagnostic.';

  @override
  String get retryStartup => 'Réessayer le démarrage';

  @override
  String get viewDiagnostics => 'Afficher les diagnostics';

  @override
  String get exportDiagnostics => 'Exporter les diagnostics';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnostics exportés vers $path';
  }

  @override
  String get diagnosticsExportFailed =>
      'Échec de l\'exportation des diagnostics';

  @override
  String get diagnosticsTitle => 'Diagnostics de l\'application';

  @override
  String get settingsDiagnostics => 'Diagnostics & Journaux';

  @override
  String get settingsDiagnosticsDesc =>
      'Afficher et exporter les journaux locaux assainis de l\'application';

  @override
  String get diagnosticsEmpty => 'Aucun enregistrement de diagnostic trouvé';

  @override
  String diagnosticsStorageError(String error) {
    return 'Erreur de stockage des diagnostics : $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Incident récupérable signalé : $category';
  }

  @override
  String get diagnosticsRefresh => 'Actualiser les journaux';

  @override
  String get nasInstallTaskTitle => 'Tâche de déploiement';

  @override
  String get nasInstallStagePreflight => 'Vérification préalable';

  @override
  String get nasInstallStageReview => 'Revue du plan';

  @override
  String get nasInstallStageWriting => 'Écriture de la configuration';

  @override
  String get nasInstallStagePulling => 'Téléchargement de l\'image';

  @override
  String get nasInstallStageStarting => 'Démarrage du conteneur';

  @override
  String get nasInstallStageHealth => 'Contrôle de santé';

  @override
  String get nasInstallStageCleanup => 'Nettoyage';

  @override
  String get nasInstallStageSucceeded => 'Déploiement réussi';

  @override
  String get nasInstallStageFailed => 'Échec du déploiement';

  @override
  String get nasInstallStageCancelled => 'Déploiement annulé';

  @override
  String get nasInstallStageNeedsInspection => 'Inspection requise';

  @override
  String get nasInstallStageReconciling => 'Réconciliation de l\'état';

  @override
  String get nasInstallCancel => 'Annuler le déploiement';

  @override
  String get nasInstallReconcile => 'Réconcilier l\'état';

  @override
  String get nasInstallServerNotFound =>
      'Le serveur sélectionné est introuvable';

  @override
  String get nasInstallPortRangeError =>
      'Le port doit être compris entre 1 et 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Écoulé : $time';
  }

  @override
  String get nasInstallLogTail => 'Journaux récents';

  @override
  String get nasInstallCleanupCompleted =>
      'Nettoyage après restauration terminé';

  @override
  String get nasInstallCleanupIncomplete =>
      'Nettoyage après restauration incomplet';

  @override
  String get nasInstallNewDeployment => 'Nouveau déploiement';

  @override
  String get nasInstallBackEdit => 'Retour / Modifier le formulaire';

  @override
  String get nasInstallClose => 'Fermer';

  @override
  String get nasInstallMediaPathHint =>
      'Montage lié en lecture seule sur l\'hôte (par ex. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Répertoire privé de données & config (ne doit pas encore exister)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 pour le tunnel, 0.0.0.0 pour le LAN';

  @override
  String get nasInstallWebdavPasswordHint => '12 caractères minimum requis';

  @override
  String get nasInstallTargetServer => 'Serveur cible';

  @override
  String get nasInstallTargetImage => 'Image cible';

  @override
  String get nasInstallContainerName => 'Nom du conteneur';

  @override
  String get nasInstallBindAndPort => 'Liaison & Port';

  @override
  String get nasInstallComposePreview => 'Aperçu de docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Étapes prévues';

  @override
  String get nasInstallGuidanceNotes => 'Notes de déploiement & Conseils';

  @override
  String get nasInstallNoLogsYet => 'Aucun journal pour le moment';

  @override
  String get sftpPreviewTooLarge =>
      'Le fichier dépasse la limite d\'aperçu de 1 Mio. Veuillez le télécharger et l\'ouvrir en externe.';

  @override
  String get sftpSaveFailed =>
      'Échec de l\'enregistrement du fichier. Vérifiez les autorisations ou la connexion réseau.';

  @override
  String get sftpSaving => 'Enregistrement en cours...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'La connexion au serveur cible a changé ; vérifiez l\'état distant avant de continuer';

  @override
  String get nasInstallBlockerCancelled =>
      'Le déploiement a été annulé par l\'utilisateur. Vérifiez les paramètres et réessayez si nécessaire.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'L\'inspection n\'a pas pu interroger le conteneur distant. Vérifiez la connectivité du serveur ou inspectez manuellement.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Le délai de l\'étape de déploiement a expiré. Vérifiez la charge du serveur ou la connexion réseau, puis réessayez.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Le déploiement a été interrompu ; vérifiez l\'état distant avant de continuer.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Le service a démarré mais le contrôle de santé HTTP a expiré. Vérifiez les journaux du service ou la disponibilité du port.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Échec de la réconciliation. Vérifiez l\'état du conteneur distant manuellement ou démarrez un nouveau déploiement.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'L\'état du conteneur distant est incertain. Une inspection manuelle et une réconciliation sont requises.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Le processus du conteneur s\'est arrêté prématurément. Vérifiez les journaux pour détecter des erreurs de configuration ou d\'autorisations.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Impossible d\'écrire les fichiers de déploiement sur le serveur cible. Vérifiez l\'espace disque et les autorisations.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Le plan de déploiement est obsolète. Veuillez réexécuter les vérifications préalables.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Le conteneur existant n\'a pas été créé par cette application. Inspectez manuellement pour éviter tout écrasement.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Une connexion SSH active au serveur cible est requise.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'L\'état distant diffère de l\'état local. Veuillez réconcilier avant de continuer.';

  @override
  String get nasInstallBlockerFailed =>
      'Le déploiement a rencontré une erreur. Consultez les journaux et réessayez.';

  @override
  String get nasInstallBlockerBusy =>
      'Une tâche d\'installation est déjà en cours. Veuillez vérifier la progression de la tâche actuelle.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Échec de la persistance de l\'état du déploiement. Veuillez vérifier l\'espace de stockage local et les autorisations de fichiers.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Le résultat de la commande distante est inconnu. Veuillez exécuter une inspection en lecture seule plutôt que de relancer directement le déploiement.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'La vérification de l\'environnement préalable au déploiement a échoué. Veuillez résoudre les points bloquants avant de continuer.';

  @override
  String serverDeleteFailed(String error) {
    return 'Échec de la suppression du serveur : $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Mode agent';

  @override
  String get chatRunSettingsApprovalPolicy => 'Politique d\'approbation locale';

  @override
  String get chatRunSettingsExtraSettings => 'Paramètres supplémentaires';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Autorise automatiquement les opérations connues comme sûres ; demande confirmation dès que la sécurité d\'une opération ne peut être garantie.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Impossible d\'appliquer les paramètres d\'exécution : $error';
  }

  @override
  String get chatMessageCopied => 'Message copié dans le presse-papiers';

  @override
  String get copy => 'Copier';

  @override
  String get rename => 'Renommer';

  @override
  String get refresh => 'Actualiser';

  @override
  String get sessionTitle => 'Titre de la session';

  @override
  String get chatSettingsStale => 'Obsolète';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Paramètres disponibles après le premier message';

  @override
  String get chatReimportAsCopy => 'Réimporter en tant que copie';

  @override
  String get chatSearchCommandsHint =>
      'Rechercher des commandes ou compétences...';

  @override
  String get chatCommandsTab => 'Commandes';

  @override
  String get chatSkillsTab => 'Compétences';

  @override
  String get chatAccountAndQuotaTitle => 'Compte & Quotas';

  @override
  String get chatAccountSectionTitle => 'Compte';

  @override
  String get chatAccountNotProvided => 'Aucun détail de compte communiqué';

  @override
  String get chatAccountKind => 'Type';

  @override
  String get chatAccountLabel => 'Libellé';

  @override
  String get chatAccountPlan => 'Forfait';

  @override
  String get chatAccountEmail => 'E-mail';

  @override
  String get chatAccountUpdatedAt => 'Mis à jour';

  @override
  String get chatQuotaSectionTitle => 'Quota & État';

  @override
  String get chatStatusSourceNote => 'Sortie brute /status de l\'agent';

  @override
  String get chatStatusNotQueried => 'État non encore interrogé';

  @override
  String get chatQueryStatusAction => 'Interroger l\'état (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Interrogation d\'état indisponible dans la session actuelle';

  @override
  String get chatAttachmentMissing => 'Fichier joint manquant ou indisponible';

  @override
  String get chatViewModeList => 'Liste';

  @override
  String get chatViewModeCards => 'Cartes';

  @override
  String get chatViewModeGrid => 'Images';

  @override
  String get chatRemoteBrowserTitle => 'Espace de travail distant';

  @override
  String get chatSelectDirectory => 'Sélectionner le répertoire';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Joindre la sélection ($count)';
  }

  @override
  String get chatNoFilesFound => 'Aucun fichier trouvé';

  @override
  String get chatRootDirectory => 'Racine';

  @override
  String get chatSelectThisDirectory => 'Utiliser ce répertoire';

  @override
  String get chatAgentVersion => 'Version de l\'agent';

  @override
  String get chatParentDirectory => 'Répertoire parent';

  @override
  String get chatSearchFilesHint => 'Rechercher des fichiers...';

  @override
  String get chatCommandsEmpty => 'Aucune commande slash fournie par l\'agent';

  @override
  String get chatSkillsEmpty => 'Aucune compétence fournie par l\'agent';

  @override
  String get chatFileUnsupported =>
      'Type de fichier non pris en charge en pièce jointe';

  @override
  String get chatStatusNotProvided =>
      'Interrogation de statut non fournie par l\'agent';

  @override
  String get sessionRecoveryReconnecting => 'Reconnexion en cours...';

  @override
  String get sessionRecoverySyncing => 'Synchronisation de la sortie...';

  @override
  String get sessionRecoveryIncomplete =>
      'Certaines sorties n\'ont pas pu être récupérées';

  @override
  String get sessionRecoveryFailed => 'Échec de la récupération';

  @override
  String get sessionRecoveryRetry => 'Réessayer';

  @override
  String get dashboardUpdatesPaused => 'Mises à jour suspendues';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'Le catalogue de modèles CLI est actuellement indisponible. Les modèles peuvent être mis en cache ou limités par la version du CLI ; vous pouvez également saisir un nom de modèle manuellement.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Les modèles sont interrogés depuis le serveur d\'applications CLI avec votre connexion CLI existante. Le catalogue peut être mis en cache ou limité par la version ; vous pouvez actualiser manuellement ou basculer vers la saisie manuelle.';

  @override
  String get chatModelCatalogError403 =>
      'Accès à la requête de modèles CLI refusé (403). Vérifiez la connexion CLI et la connectivité au service, ou saisissez un nom de modèle manuellement.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Erreur du catalogue de modèles : $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Autoriser le catalogue de modèles';

  @override
  String get chatModelAuthorizeConfirmTitle =>
      'Autoriser le catalogue de modèles';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Cela lancera l\'autorisation dans le navigateur pour le catalogue de modèles sur l\'hôte/conteneur cible. Votre connexion Codex et vos sessions de terminal existantes resteront intactes. Continuer ?';

  @override
  String get chatModelAuthorizing =>
      'Autorisation via le navigateur en cours...';

  @override
  String get chatModelAuthorizeCancel => 'Annuler l\'autorisation';

  @override
  String get chatCommandsFirstTurnNote =>
      'Les commandes slash seront annoncées par l\'agent une fois la session initialisée, sans nécessiter de conversation préalable ordinaire ; les brouillons ne créent pas automatiquement de sessions.';

  @override
  String get chatCommandsClientActionRunSettings => 'Paramètres d\'exécution';

  @override
  String get chatCommandsClientActionWorkingDirectory =>
      'Répertoire de travail';

  @override
  String get chatCommandsClientActionsSection => 'Actions locales';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Liste des modèles';

  @override
  String get chatRunSettingsModelSourceCustom => 'Saisie manuelle';

  @override
  String get chatRunSettingsCustomModelHint => 'Saisir l\'ID du modèle';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Les noms de modèles manuels ne sont pas vérifiés et seront envoyés directement à l\'agent, qui pourra rejeter les modèles non pris en charge.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Le nom du modèle ne peut pas être vide';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Le nom du modèle doit comporter au maximum 256 caractères sans espace ni caractère de contrôle';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Commandes vérifiées pour la version actuelle de l\'adaptateur. Sélectionner insère le texte dans le brouillon ; Envoyer initialisera la session à la demande et exécutera directement la commande.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Impossible de découvrir les commandes ou compétences';

  @override
  String get chatAuthWaitingForBrowser =>
      'En attente d\'autorisation dans le navigateur...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Impossible d\'ouvrir le navigateur externe. Veuillez rouvrir ou copier le lien d\'autorisation ci-dessous.';

  @override
  String get chatAuthReopenBrowser => 'Rouvrir le navigateur';

  @override
  String get chatAuthCopyLink => 'Copier le lien';

  @override
  String get chatAuthManualCallback => 'Rappel manuel';

  @override
  String get chatAuthManualCallbackTitle =>
      'Saisir l\'URL de rappel d\'autorisation';

  @override
  String get chatAuthManualCallbackDesc =>
      'Collez l\'URL de redirection complète (http://127.0.0.1:PORT/...?code=...&state=...) depuis le navigateur pour terminer l\'autorisation. Les codes d\'autorisation bruts ne sont pas acceptés.';

  @override
  String get chatAuthCallbackInputLabel => 'URL de rappel';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Format d\'URL de rappel non valide ou échec de transmission';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP nécessite une autorisation officielle de compte, distincte de la connexion CLI du terminal.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Ce tour nécessite une authentification ACP. Reconnectez-vous et demandez une autorisation pour continuer.';

  @override
  String get chatRequestAuthButton => 'Demander l\'authentification';

  @override
  String get agentActionAcpLogin => 'Connexion ACP';

  @override
  String get agentActionCliLogin => 'Connexion CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Identifiants ACP manquants (connexion ACP requise)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Identifiants ACP enregistrés (non vérifiés)';

  @override
  String get chatAuthMethodUnavailable =>
      'La méthode d\'authentification sélectionnée n\'est pas disponible.';

  @override
  String get chatAuthConnectionExpired =>
      'La connexion d\'authentification a expiré. Veuillez réessayer.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Échec de la transmission du rappel d\'autorisation au serveur.';

  @override
  String get agentTargetChangedNotice =>
      'Le serveur cible a changé. Veuillez rouvrir la gestion des agents sur le serveur actuel.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Vérification d\'authentification Antigravity indisponible';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Réponse de vérification d\'authentification Antigravity non valide';

  @override
  String get sftpDownloadDisconnected => 'Téléchargement déconnecté';

  @override
  String get sftpDownloadPermissionDenied => 'Permission refusée';

  @override
  String get sftpDownloadNotFound => 'Fichier distant introuvable';

  @override
  String get sftpDownloadTimeout => 'Délai de téléchargement dépassé';

  @override
  String get sftpDownloadLocalSpace => 'Espace de stockage local insuffisant';

  @override
  String get sftpDownloadLocalIo => 'Échec d\'écriture dans le stockage local';

  @override
  String get sftpDownloadIncomplete => 'Téléchargement incomplet';

  @override
  String get transferStatusWaitingConnection => 'En attente de connexion';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Échec du démarrage de l\'écouteur de rappel d\'autorisation local. Veuillez réessayer l\'authentification.';

  @override
  String get settingsExperimentalFeatures => 'Fonctionnalités expérimentales';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Essayer les fonctionnalités d\'aperçu et expérimentales';

  @override
  String get settingsExperimentalCliChatTitle => 'Chat intelligent CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Activer l\'interface de discussion dédiée aux agents en ligne de commande';

  @override
  String get settingsExperimentalDialogClose => 'Fermer';

  @override
  String get settingsExperimentalSaveFailed =>
      'Échec de la mise à jour des paramètres des fonctionnalités expérimentales';

  @override
  String get settingsExperimentalNasTitle => 'Média NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'Activer la médiathèque, l\'analyse des dossiers et la lecture audio';

  @override
  String get settingsLanguageSaveFailed =>
      'Échec de la mise à jour des paramètres de langue';

  @override
  String get settingsAboutPrivacy => 'À propos et confidentialité';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get privacyPolicyDescription => 'Utilisation des données et vos choix';

  @override
  String get privacyContactTitle => 'Contact confidentialité';

  @override
  String get privacyCopyEmail => 'Copier l’adresse e-mail';

  @override
  String get privacyEmailCopied => 'Adresse e-mail copiée';

  @override
  String get privacyOnlineVersion => 'Voir la version en ligne';

  @override
  String get privacyLinkFailed =>
      'Impossible d’ouvrir le lien. Vous pouvez copier l’adresse e-mail.';

  @override
  String get privacyLoadFailed =>
      'Impossible de charger la politique. Consultez la version en ligne.';

  @override
  String get privacyVersionUnknown => 'Version indisponible';

  @override
  String get aboutWebsite => 'Site officiel';

  @override
  String get aboutLicense => 'Licence de l’application';

  @override
  String get aboutThirdPartyLicenses => 'Licences open source tierces';

  @override
  String get aboutLicenseSummary =>
      'Le contenu original de Valhalla est sous licence PolyForm Noncommercial 1.0.0 pour un usage non commercial. Tout usage commercial dépassant les permissions de la licence nécessite une autorisation distincte. Les composants tiers conservent leurs propres licences. Les conditions complètes ci-dessous régissent l’utilisation.';

  @override
  String get aboutCopyrightNotice => 'Mentions de droit d’auteur';

  @override
  String get aboutLicenseLoadFailed =>
      'Impossible de charger la licence. Contactez norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Impossible d’ouvrir le lien. Ouvrez https://norns.cc.cd dans votre navigateur.';

  @override
  String get downloadReveal => 'Afficher dans l’Explorateur de fichiers';

  @override
  String get downloadRevealFailed =>
      'Impossible d’ouvrir le dossier de téléchargement. Il a peut-être été déplacé ou supprimé.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count clés d\'hôtes de confiance';
  }

  @override
  String get settingsKnownHostsEmpty =>
      'Aucune clé d\'hôte de confiance trouvée';

  @override
  String get settingsKnownHostsDialogTitle => 'Clés d\'hôtes connus';

  @override
  String get settingsHostKeyRevoke => 'Révoquer';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'Révoquer la clé d\'hôte';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return 'Révoquer la clé d\'hôte pour $hostPort ? Les connexions SSH actives vers cet hôte seront déconnectées et vous devrez revérifier la clé lors de la prochaine connexion.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Empreinte de la clé copiée dans le presse-papiers';

  @override
  String get settingsHostKeyRevoked => 'Clé d\'hôte révoquée';

  @override
  String get settingsClearStorageSubtitle =>
      'Effacer les mots de passe et clés privées enregistrés des serveurs sélectionnés';

  @override
  String get settingsClearStorageDialogTitle =>
      'Réinitialiser les identifiants';

  @override
  String get settingsClearStorageDesc =>
      'Sélectionnez les serveurs pour effacer les mots de passe SSH et clés privées enregistrés dans le stockage sécurisé. Les configurations de serveur et historiques de discussion ne seront pas supprimés.';

  @override
  String get settingsClearStorageNoServers => 'Aucun serveur disponible';

  @override
  String get settingsClearStorageSelectAll => 'Tout sélectionner';

  @override
  String get settingsClearStorageDeselectAll => 'Tout désélectionner';

  @override
  String get settingsClearStorageConfirmTitle =>
      'Confirmer la suppression des identifiants';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'Voulez-vous vraiment effacer les identifiants de $count serveur(s) sélectionné(s) ? Les connexions actives seront immédiatement coupées.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Effacer la sélection ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Identifiants des serveurs sélectionnés effacés avec succès';

  @override
  String get settingsClearStorageError =>
      'Échec de l\'effacement des identifiants de certains serveurs. Veuillez réessayer.';

  @override
  String get settingsDefaultAcpAgent => 'Agent ACP par défaut';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Agent par défaut pour le chat ACP sur ce serveur';

  @override
  String get settingsDefaultCliAgent => 'Agent CLI par défaut';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Agent par défaut pour le chat CLI sur ce serveur';

  @override
  String get settingsDefaultAgentAutomatic =>
      'Automatique (premier disponible)';

  @override
  String get settingsDefaultAgentSelectTitle =>
      'Sélectionner l\'agent par défaut';

  @override
  String get settingsDefaultAgentNoServer => 'Aucun serveur sélectionné';

  @override
  String get settingsDefaultAgentNoAgents =>
      'Aucun agent configuré pour ce serveur';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Échec de la mise à jour du paramètre d\'agent par défaut';

  @override
  String get dockerViewGroupContainers => 'Conteneurs';

  @override
  String get dockerViewGroupProjects => 'Projets Compose';

  @override
  String get dockerProjectActionStart => 'Démarrer le projet';

  @override
  String get dockerProjectActionStop => 'Arrêter le projet';

  @override
  String get dockerProjectActionRestart => 'Redémarrer le projet';

  @override
  String get dockerProjectConfirmStopTitle => 'Arrêter le projet Compose';

  @override
  String get dockerProjectConfirmRestartTitle => 'Redémarrer le projet Compose';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'Voulez-vous vraiment $action le projet « $project » ? Les $count conteneurs suivants seront affectés :';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'Projet « $project » $action avec succès';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'Projet « $project » $action terminé avec $failedCount échec(s)';
  }

  @override
  String get dockerNoProjects => 'Aucun projet Docker Compose trouvé';

  @override
  String get dockerMountsTitle => 'Montages';

  @override
  String get dockerMountReadOnly => 'Lecture seule';

  @override
  String get dockerMountReadWrite => 'Lecture/Écriture';

  @override
  String get sftpBookmarksTitle => 'Signets de répertoire';

  @override
  String get sftpNoBookmarks => 'Aucun signet enregistré pour l\'instant';

  @override
  String get sftpAddBookmark => 'Ajouter aux signets';

  @override
  String get sftpRemoveBookmark => 'Supprimer le signet';

  @override
  String get sftpCurrentDirectory => 'Répertoire actuel';

  @override
  String get sftpSelectMode => 'Sélection multiple';

  @override
  String sftpSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get sftpSelectAll => 'Tout sélectionner';

  @override
  String get sftpDeselectAll => 'Tout désélectionner';

  @override
  String get sftpBatchCopy => 'Copier';

  @override
  String get sftpBatchMove => 'Déplacer';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Confirmer la suppression par lot';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'Voulez-vous vraiment supprimer les $count éléments sélectionnés ?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Remarque : Les répertoires non vides ne peuvent pas être supprimés de façon récursive et seront ignorés.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Confirmer la copie par lot';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'Copier $count éléments sélectionnés vers \"$directory\" ?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Confirmer le déplacement par lot';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'Déplacer $count éléments sélectionnés vers \"$directory\" ?';
  }

  @override
  String get sftpBatchResultsTitle => 'Résultats des opérations par lot';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Ignoré (la cible existe déjà ou n\'est pas prise en charge)';

  @override
  String get sftpBatchTargetRestricted =>
      'Impossible de choisir le répertoire source ou un sous-répertoire comme destination';

  @override
  String get sftpSelectCurrentDir => 'Choisir ce répertoire';

  @override
  String sftpBatchOperationSuccess(int count) {
    return '$count éléments traités avec succès';
  }

  @override
  String get configMigrationTitle => 'Sauvegarde et migration de configuration';

  @override
  String get configExportTitle => 'Exporter la configuration';

  @override
  String get configExportSubtitle =>
      'Exporter serveurs, agents, commandes, signets et préférences en JSON';

  @override
  String get configExportDialogTitle => 'Exporter la configuration Valhalla';

  @override
  String get configExportSuccess => 'Configuration exportée avec succès';

  @override
  String configExportError(String error) {
    return 'Échec de l\'exportation de la configuration : $error';
  }

  @override
  String get configImportTitle => 'Importer la configuration';

  @override
  String get configImportSubtitle =>
      'Importer la configuration depuis un fichier JSON de sauvegarde';

  @override
  String get configBackupTooLarge =>
      'Le fichier de sauvegarde dépasse la taille maximale autorisée (8 Mo)';

  @override
  String get configImportPreviewTitle =>
      'Aperçu de l\'importation de configuration';

  @override
  String get configImportPreviewDesc =>
      'Examinez le contenu avant d\'importer. Les éléments existants seront conservés et fusionnés.';

  @override
  String configImportServersCount(int count) {
    return 'Serveurs ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'Agents configurés ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'Commandes rapides ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'Signets ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'Les commandes personnalisées peuvent contenir des scripts sensibles ou des identifiants intégrés. Aucun mot de passe, clé privée ou empreinte d\'hôte approuvée n\'est transféré.';

  @override
  String get configImportGlobalPreferences =>
      'Importer les préférences globales de l\'application';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Écrase les paramètres actuels de thème, terminal et navigation';

  @override
  String get configImportConfirmAction => 'Confirmer l\'importation';

  @override
  String get configImportSuccess => 'Configuration importée avec succès';

  @override
  String get configImportErrorTitle => 'Sauvegarde de configuration non valide';

  @override
  String configImportErrorGeneric(String error) {
    return 'Échec de l\'importation de la configuration : $error';
  }

  @override
  String get configImportErrorCopyDetails => 'Copier les détails de diagnostic';

  @override
  String get configImportErrorCopied =>
      'Détails de diagnostic copiés dans le presse-papiers';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Format ou version de sauvegarde non pris en charge';

  @override
  String get configImportErrorMalformed =>
      'JSON de configuration malformé ou corrompu';
}
