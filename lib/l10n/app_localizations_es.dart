// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'Gestión de servidores y agentes nativa con IA';

  @override
  String get navAiChat => 'Chat IA';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'Archivos SFTP';

  @override
  String get navCommands => 'Comandos';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get serverConnected => 'Conectado';

  @override
  String get serverOnline => 'En línea';

  @override
  String get serverOffline => 'Desconectado';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get quickDisconnect => 'Desconexión rápida';

  @override
  String get newSession => 'Nueva sesión';

  @override
  String get historySessions => 'Historial de sesiones';

  @override
  String get switchAgent => 'Cambiar agente';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agente activo';

  @override
  String get inputPromptHint =>
      'Pide al agente diagnosticar, ejecutar herramientas o escribir comandos... (Enter para enviar)';

  @override
  String get thinking => 'Pensando';

  @override
  String get executionPlan => 'Plan de ejecución';

  @override
  String get toolCall => 'Llamada a herramienta';

  @override
  String get toolStatusPending => 'Pendiente';

  @override
  String get toolStatusRunning => 'Ejecutando...';

  @override
  String get toolStatusCompleted => 'Completado';

  @override
  String get toolStatusFailed => 'Error';

  @override
  String get permissionRequired => 'Permiso requerido';

  @override
  String get permissionDescription =>
      'El agente desea ejecutar este comando en el servidor:';

  @override
  String get permissionReject => 'Rechazar';

  @override
  String get permissionAllowOnce => 'Permitir una vez';

  @override
  String get permissionAllowAlways => 'Permitir siempre';

  @override
  String get quickTroubleshootCpu => 'Diagnosticar uso alto de CPU';

  @override
  String get quickDockerHealth => 'Comprobación de estado de Docker';

  @override
  String get quickCleanCache => 'Limpiar caché del sistema';

  @override
  String get quickNginxLogs => 'Revisar registros de errores de Nginx';

  @override
  String get terminalNewTab => 'Nueva pestaña';

  @override
  String get terminalCloseTab => 'Cerrar pestaña';

  @override
  String get terminalClear => 'Limpiar';

  @override
  String get terminalQuickCmds => 'Paleta de comandos';

  @override
  String get terminalPaste => 'Pegar';

  @override
  String get terminalConfirmPasteTitle => 'Confirmar pegado';

  @override
  String terminalConfirmPasteMessage(int count) {
    return 'Pegando $count líneas de texto en la terminal. ¿Continuar?';
  }

  @override
  String get settingsTerminalPinnedKeys => 'Teclas de barra de terminal';

  @override
  String get settingsTerminalPinnedKeysSubtitle =>
      'Personalizar y reordenar las teclas de la barra';

  @override
  String get terminalResetPinnedKeys => 'Restablecer a valores predeterminados';

  @override
  String get terminalToggleKeyboard => 'Alternar teclado';

  @override
  String get sftpCurrentPath => 'Ruta actual';

  @override
  String get sftpUpload => 'Subir';

  @override
  String get sftpNewFolder => 'Nueva carpeta';

  @override
  String get sftpNewFile => 'Nuevo archivo';

  @override
  String get sftpRefresh => 'Actualizar';

  @override
  String get sftpSearchHint => 'Buscar archivos o carpetas...';

  @override
  String get sftpEmpty => 'El directorio está vacío';

  @override
  String get sftpFileName => 'Nombre';

  @override
  String get sftpFileSize => 'Tamaño';

  @override
  String get sftpFilePerm => 'Permisos';

  @override
  String get sftpFileModified => 'Modificado';

  @override
  String get cmdCategoryDocker => 'STACK DE CONTENEDORES DOCKER';

  @override
  String get cmdCategorySystem => 'MANTENIMIENTO DEL SISTEMA';

  @override
  String get cmdCategoryNetwork => 'RED Y PUERTOS';

  @override
  String get cmdExecute => 'Ejecutar';

  @override
  String get cmdDangerous => 'Comando peligroso';

  @override
  String get cmdDangerousWarning =>
      'Esta operación es irreversible y puede causar interrupción del servicio. ¿Estás seguro de que deseas continuar?';

  @override
  String get cmdParamRequired => 'Parámetro obligatorio';

  @override
  String get cmdConfirm => 'Confirmar y ejecutar';

  @override
  String get cmdCancel => 'Cancelar';

  @override
  String get settingsAppearance => 'Apariencia y temas';

  @override
  String get settingsThemeMode => 'Modo de tema';

  @override
  String get themeSystem => 'Seguir el sistema';

  @override
  String get themeSystemDesc => 'Adaptación automática';

  @override
  String get themeLight => 'Modo claro';

  @override
  String get themeLightDesc => 'Papel luminoso';

  @override
  String get themeDark => 'Geek oscuro';

  @override
  String get themeDarkDesc => 'Antracita profundo';

  @override
  String get themeAmoled => 'Negro AMOLED';

  @override
  String get themeAmoledDesc => 'Negro absoluto 0x000000';

  @override
  String get settingsAccentColor => 'Color de acento del tema';

  @override
  String get accentCyberEmerald => 'Esmeralda cibernético';

  @override
  String get accentTechBlue => 'Azul tecnológico';

  @override
  String get accentElectricViolet => 'Violeta eléctrico';

  @override
  String get accentCrimsonRed => 'Rojo carmesí';

  @override
  String get accentAmberOrange => 'Naranja ámbar';

  @override
  String get settingsLanguage => 'Idioma y región';

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
  String get settingsAiOps => 'AI Ops y motor';

  @override
  String get settingsSecurity => 'Conexión y seguridad';

  @override
  String get settingsKnownHosts => 'Claves de hosts conocidos';

  @override
  String get settingsClearStorage => 'Restablecer credenciales';

  @override
  String get settingsResetDefault => 'Restablecer valores predeterminados';

  @override
  String get settingsTerminalUseTmux => 'Sesiones persistentes (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Ejecutar sesiones de terminal dentro de tmux en el servidor remoto';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Conserva la salida del terminal tras una desconexión. Requiere tmux en el servidor remoto. Se aplica a las pestañas de terminal nuevas.';

  @override
  String get settingsTerminalFontSize => 'Tamaño de fuente del terminal';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Ajusta el tamaño de fuente para terminales SSH y CLI';

  @override
  String get version => 'Versión';

  @override
  String get addServer => 'Añadir servidor';

  @override
  String get editServer => 'Editar servidor';

  @override
  String get serverName => 'Nombre del servidor';

  @override
  String get serverHost => 'Host / IP';

  @override
  String get serverPort => 'Puerto';

  @override
  String get serverUsername => 'Nombre de usuario';

  @override
  String get serverAuthType => 'Tipo de autenticación';

  @override
  String get serverPassword => 'Contraseña';

  @override
  String get serverPrivateKey => 'Clave privada';

  @override
  String get serverSave => 'Guardar servidor';

  @override
  String get serverDelete => 'Eliminar servidor';

  @override
  String get fileEditor => 'Editor de archivos';

  @override
  String get fileEditorSave => 'Guardar cambios';

  @override
  String get fileSavedSuccess => 'Archivo guardado correctamente';

  @override
  String get addCommand => 'Nuevo comando';

  @override
  String get commandTitle => 'Título del comando';

  @override
  String get commandContent => 'Cadena de comando';

  @override
  String get commandCategory => 'Categoría';

  @override
  String get commandDescription => 'Descripción';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get cmdExecutionChannel => 'Canal de ejecución';

  @override
  String get cmdChannelTerminal => 'Directo al terminal SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'El comando se escribe directamente en la sesión de terminal activa';

  @override
  String get cmdChannelBackground => 'Ejecutar en segundo plano';

  @override
  String get cmdChannelBackgroundDesc =>
      'Se ejecuta a través del shell de inicio de sesión SSH y captura la salida';

  @override
  String get cmdInjectedToTerminal => 'Comando enviado al terminal';

  @override
  String get cmdExecutionCompleted => 'Ejecución completada';

  @override
  String get cmdExecutionFailed => 'Error de ejecución';

  @override
  String get cmdExecutingRemote => 'Ejecutando comando remoto...';

  @override
  String get cmdClose => 'Cerrar';

  @override
  String get navDashboard => 'Panel';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Sistema';

  @override
  String get navMore => 'Más';

  @override
  String get dashboardTitle => 'Panel del servidor';

  @override
  String get metricsCpu => 'Uso de CPU';

  @override
  String get metricsMemory => 'Uso de memoria';

  @override
  String get metricsLoadAvg => 'Carga media';

  @override
  String get metricsUptime => 'Tiempo de actividad';

  @override
  String get metricsRootDisk => 'Disco raíz';

  @override
  String get quickActions => 'Navegación rápida';

  @override
  String get activeServerStatus => 'Estado del servidor activo';

  @override
  String get noServerSelected =>
      'No hay ningún servidor seleccionado actualmente. Elige un servidor primero.';

  @override
  String get serverDisconnected => 'Desconectado';

  @override
  String get serverConnecting => 'Conectando...';

  @override
  String get connectNow => 'Conectar ahora';

  @override
  String get serverSpecs => 'Información y especificaciones';

  @override
  String get dockerTitle => 'Contenedores Docker';

  @override
  String get dockerSearchHint => 'Buscar contenedores por nombre o imagen...';

  @override
  String get dockerFilterAll => 'Todos';

  @override
  String get dockerFilterRunning => 'En ejecución';

  @override
  String get dockerFilterExited => 'Detenidos';

  @override
  String get dockerFilterPaused => 'En pausa';

  @override
  String get dockerActionStart => 'Iniciar';

  @override
  String get dockerActionStop => 'Detener';

  @override
  String get dockerActionRestart => 'Reiniciar';

  @override
  String get dockerActionPause => 'Pausar';

  @override
  String get dockerActionUnpause => 'Reanudar';

  @override
  String get dockerActionRm => 'Eliminar';

  @override
  String get dockerActionLogs => 'Registros';

  @override
  String get dockerActionInspect => 'Inspeccionar';

  @override
  String get dockerLogsTitle => 'Registros del contenedor';

  @override
  String get dockerInspectTitle => 'Inspección del contenedor';

  @override
  String get dockerNoContainers =>
      'No se encontraron contenedores en el servidor';

  @override
  String get dockerEmptyRunning => 'No hay contenedores en ejecución';

  @override
  String get dockerPorts => 'Puertos';

  @override
  String get dockerCreated => 'Creado';

  @override
  String get dockerImage => 'Imagen';

  @override
  String get systemTitle => 'Procesos y servicios';

  @override
  String get tabProcesses => 'Procesos';

  @override
  String get tabServices => 'Servicios Systemd';

  @override
  String get processSearchHint => 'Buscar por nombre de proceso o PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEMORIA';

  @override
  String get processStat => 'Estado';

  @override
  String get processCommand => 'Comando';

  @override
  String get processTerminate => 'Terminar (SIGTERM)';

  @override
  String get processForceKill => 'Forzar detención (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Rechazo de terminación del proceso de inicialización del sistema (PID <= 1)';

  @override
  String get serviceSearchHint => 'Buscar servicios por nombre...';

  @override
  String get serviceName => 'Servicio';

  @override
  String get serviceDescription => 'Descripción';

  @override
  String get serviceStatus => 'Estado';

  @override
  String get serviceStartup => 'Inicio';

  @override
  String get serviceActionStart => 'Iniciar';

  @override
  String get serviceActionStop => 'Detener';

  @override
  String get serviceActionRestart => 'Reiniciar';

  @override
  String get serviceActionReload => 'Recargar';

  @override
  String get serviceActionEnable => 'Habilitar';

  @override
  String get serviceActionDisable => 'Deshabilitar';

  @override
  String get serviceNoServices => 'No se encontraron servicios systemd';

  @override
  String get riskDangerTitle => 'Confirmación de operación de alto riesgo';

  @override
  String get riskWarningTitle => 'Confirmación de advertencia de operación';

  @override
  String get riskSafeTitle => 'Confirmar acción';

  @override
  String get riskIrreversibleWarning =>
      'Esta operación está clasificada como de ALTO RIESGO y no se puede deshacer. Puede provocar pérdida de datos o interrupción del servicio.';

  @override
  String get riskWarningDescription =>
      'Esta operación puede afectar servicios activos o reiniciar procesos. Procede con precaución.';

  @override
  String get riskCommandPreview => 'Vista previa del comando';

  @override
  String get riskConfirmButton => 'Confirmar y continuar';

  @override
  String get riskCancelButton => 'Cancelar';

  @override
  String get stateLoading => 'Cargando datos remotos...';

  @override
  String get stateOffline => 'El servidor está desconectado';

  @override
  String get stateOfflineDesc =>
      'Establece una conexión SSH activa para administrar recursos y transmitir métricas.';

  @override
  String get stateError => 'Se ha producido un error';

  @override
  String get stateRetry => 'Reintentar';

  @override
  String get stateEmpty => 'No se encontraron elementos';

  @override
  String get inspectorTitle => 'Inspector';

  @override
  String get inspectorClose => 'Cerrar';

  @override
  String get inspectorDetails => 'Detalles de inspección';

  @override
  String get selectServerTitle => 'Seleccionar servidor de destino';

  @override
  String get sshDisconnectedSuccess => 'Conexión SSH desconectada';

  @override
  String get trustHostFingerprintTitle =>
      '¿Confiar en la huella digital del host?';

  @override
  String get trustAndConnect => 'Confiar y conectar';

  @override
  String get reject => 'Rechazar';

  @override
  String get confirmDeleteServerTitle => 'Eliminar servidor';

  @override
  String get noServersFound => 'Aún no hay servidores configurados';

  @override
  String get agentNotReadyError =>
      'El agente seleccionado no está listo. Verifica su entorno y configuración.';

  @override
  String get sshDisconnectedError =>
      'SSH desconectado. Conéctate a un servidor antes de usar AI Ops.';

  @override
  String get noAgentAvailable => 'No hay ningún agente disponible';

  @override
  String get noAgentAvailablePrompt =>
      'No hay ningún agente activo disponible. Configura o prepara un agente primero.';

  @override
  String get noAgentAvailableHint =>
      'Selecciona o configura un agente disponible para chatear...';

  @override
  String get manageAgents => 'Administrar agentes';

  @override
  String get noReadyAgentsTitle => 'No hay agentes listos';

  @override
  String get noReadyAgentsDesc =>
      'Ningún agente en este servidor ha superado las comprobaciones del entorno.';

  @override
  String get agentStatusReady => 'Listo';

  @override
  String get agentStatusChecking => 'Comprobando...';

  @override
  String get agentStatusCliMissing => 'Instalación no detectada';

  @override
  String get agentStatusAcpMissing => 'Componente ACP no detectado';

  @override
  String get agentStatusNotLoggedIn => 'No ha iniciado sesión';

  @override
  String get agentStatusError => 'Error';

  @override
  String get agentStatusUnknown => 'Desconocido';

  @override
  String get agentActionInstall => 'Instalar';

  @override
  String get agentActionLogin => 'Iniciar sesión';

  @override
  String get agentActionRefresh => 'Comprobar estado';

  @override
  String get noConfiguredAgents =>
      'No hay agentes configurados en este servidor';

  @override
  String get agentManagementTitle => 'Gestión de agentes';

  @override
  String get settingsAgentManagement => 'Gestión de agentes';

  @override
  String get settingsAgentManagementSubtitle =>
      'Configurar, detectar y administrar agentes ACP para el servidor actual';

  @override
  String get addAgentButton => 'Añadir agente';

  @override
  String get noServerSelectedForAgents =>
      'Ningún servidor seleccionado. Elige primero un servidor desde la interfaz principal.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH desconectado. La detección, instalación e inicio de sesión están deshabilitados hasta que se establezca la conexión.';

  @override
  String get noAgentsConfiguredTitle => 'No hay agentes configurados';

  @override
  String get noAgentsConfiguredDesc =>
      'Añade Claude Code, Codex, OpenCode, AGY o agentes ACP personalizados para habilitar AI Ops en este servidor.';

  @override
  String get agentPresetLabel => 'Preajuste';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Personalizado';

  @override
  String get agentNameLabel => 'Nombre del agente';

  @override
  String get agentNameHint => 'p. ej., Codex de producción';

  @override
  String get agentDescriptionLabel => 'Descripción';

  @override
  String get agentDescriptionHint => 'Breve descripción del agente';

  @override
  String get agentCliCommandLabel => 'Comando de prueba de CLI';

  @override
  String get agentCliCommandHint => 'p. ej., claude, codex';

  @override
  String get agentAcpCommandLabel => 'Comando de lanzamiento ACP';

  @override
  String get agentAcpCommandHint => 'p. ej., codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Comando de instalación (Opcional)';

  @override
  String get agentInstallCommandHint => 'p. ej., npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Comando de comprobación de inicio de sesión (Opcional)';

  @override
  String get agentLoginCheckCommandHint => 'p. ej., codex --version';

  @override
  String get agentLoginCommandLabel => 'Comando de inicio de sesión (Opcional)';

  @override
  String get agentLoginCommandHint => 'p. ej., codex login';

  @override
  String get agentSaveButton => 'Guardar y detectar';

  @override
  String get agentCliRequired => 'El comando de prueba de CLI es obligatorio';

  @override
  String get agentAcpRequired =>
      'El comando de lanzamiento de ACP es obligatorio';

  @override
  String get agentNameRequired => 'El nombre del agente es obligatorio';

  @override
  String get confirmInstallAgentTitle => 'Confirmar instalación del agente';

  @override
  String get confirmLoginAgentTitle => 'Confirmar inicio de sesión del agente';

  @override
  String get agentCommandRiskWarning =>
      'Este comando se ejecutará directamente en el servidor remoto con los privilegios del usuario actual. Puede instalar paquetes o modificar entornos del sistema.';

  @override
  String get targetServerLabel => 'Servidor de destino';

  @override
  String get commandPreviewLabel => 'Vista previa del comando';

  @override
  String get executeButton => 'Ejecutar';

  @override
  String get deleteAgentTitle => 'Eliminar agente';

  @override
  String get deleteAgentConfirm => 'Eliminar';

  @override
  String get agentStatusCheckingDesc =>
      'Detectando entorno en el servidor remoto...';

  @override
  String get agentStatusInstalling =>
      'Instalando dependencias en el servidor...';

  @override
  String get agentStatusLoggingIn =>
      'Ejecutando comando de inicio de sesión en el servidor...';

  @override
  String get agentNoLoginCheckProvided =>
      'No se especificó comando de comprobación de inicio de sesión';

  @override
  String get agentInstallPrompt =>
      'Instalación no detectada. ¿Deseas instalarlo automáticamente ahora?';

  @override
  String get agentActionAutoInstall => 'Instalación automática';

  @override
  String get agentLoginPrompt =>
      'No ha iniciado sesión. ¿Deseas iniciar sesión ahora?';

  @override
  String get agentActionExecuteLogin => 'Iniciar sesión ahora';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Los agentes en este servidor aún no están instalados o listos. Por favor, administra y completa la configuración del entorno.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Instala y prepara un agente para comenzar a chatear...';

  @override
  String get agentAcpInstallPrompt =>
      'Componente ACP no detectado. ¿Deseas instalarlo automáticamente ahora?';

  @override
  String get agentInstallCommandAcpLabel =>
      'Comando de instalación de ACP (Opcional)';

  @override
  String get agentInstallCommandAcpHint =>
      'p. ej., npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'No hay ningún comando de instalación configurado para este agente';

  @override
  String get agentInstallLogTitle => 'Salida de instalación';

  @override
  String get agentInstallLogEmpty => 'Esperando salida de instalación…';

  @override
  String get agentInstallLogTruncated =>
      'Salida demasiado larga; mostrando las líneas más recientes';

  @override
  String get agentAcpOptional => 'Opcional; dejar vacío para solo CLI';

  @override
  String get acpStreaming => 'Transmitiendo ACP...';

  @override
  String get aiOpsAgentTitle => 'Agente AI Ops de Valhalla';

  @override
  String get aiOpsEmptySubtitle =>
      'Conectado mediante ACP stdio sobre canal SSH';

  @override
  String get agentAuthRequiredTitle => 'Autenticación requerida';

  @override
  String get agentAuthRequiredDesc =>
      'El agente requiere autenticación antes de poder procesar tu solicitud.';

  @override
  String get agentAuthMethodLabel => 'Método de autenticación';

  @override
  String get agentAuthNoMethodsNotice =>
      'El agente no proporcionó un método de inicio de sesión. Comprueba su configuración en el servidor.';

  @override
  String get agentAuthProceedButton => 'Iniciar sesión';

  @override
  String get agentAuthCancelButton => 'Cancelar';

  @override
  String get agentAuthRetryHint =>
      'Después de iniciar sesión, envía tu mensaje de nuevo.';

  @override
  String get agentAuthRequiredError =>
      'Autenticación requerida. Inicia sesión para continuar.';

  @override
  String get agentLoginTerminalTitle =>
      'Terminal de inicio de sesión interactivo';

  @override
  String get agentLoginTerminalSubtitle =>
      'Completa los pasos de inicio de sesión en el terminal a continuación. Sigue las instrucciones de URL o código mostradas.';

  @override
  String get agentLoginTerminalRunning =>
      'El comando de inicio de sesión se está ejecutando en el terminal...';

  @override
  String get agentLoginTerminalDisconnected =>
      'Conexión SSH perdida. La sesión de inicio de sesión fue interrumpida.';

  @override
  String get agentLoginTerminalRetry => 'Reconectar terminal';

  @override
  String get agentLoginTerminalFinish => 'Finalizar y verificar';

  @override
  String get agentLoginTerminalClose => 'Cerrar';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Si el agente requiere pegar un código, mantén presionado el terminal para pegar o usa la tecla PEGAR.';

  @override
  String get agentLoginTerminalUrlLabel => 'URL de inicio de sesión detectada';

  @override
  String get agentLoginTerminalUrlCopy => 'Copiar enlace';

  @override
  String get agentLoginTerminalUrlCopied =>
      'URL de inicio de sesión copiada al portapapeles';

  @override
  String get agentLoginTerminalCopyAll => 'Copiar toda la salida';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Salida del terminal copiada al portapapeles';

  @override
  String get sshStatusReconnected => 'Conexión restablecida';

  @override
  String get sshStatusDisconnectedRetrying => 'Conexión perdida, reintentando';

  @override
  String get sshStatusDisconnectedManual => 'Desconectado';

  @override
  String get sshStatusHostKeyChanged =>
      'La clave de host cambió: conexión rechazada';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla mantiene tus sesiones activas';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux no encontrado: las sesiones no sobrevivirán a una desconexión';

  @override
  String get terminalTmuxSessionRestored => 'Sesión de terminal restaurada';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Habilitar Mosh: un terminal móvil resistente a cortes de conexión y cambios de IP';

  @override
  String get moshServerPathLabel => 'Ruta de mosh-server';

  @override
  String get moshPortRangeLabel => 'Rango de puertos UDP';

  @override
  String get moshNewSession => 'Nueva sesión de Mosh';

  @override
  String get moshNotInstalled =>
      'No se encontró mosh-server en el servidor remoto. Instálalo con: sudo apt install mosh (Debian/Ubuntu) o sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Error al iniciar la sesión de Mosh: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Tiempo de espera de conexión Mosh agotado: verifica que el tráfico UDP no esté bloqueado por un firewall.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Sesión de agente restaurada';

  @override
  String get acpSessionRestartNotice =>
      'Sesión de agente reiniciada: contexto anterior no disponible';

  @override
  String get terminalTmuxInstallDialogTitle =>
      '¿Instalar tmux en el servidor remoto?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux es necesario para preservar las sesiones de terminal ante desconexiones. ¿Deseas instalarlo ahora?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Comando a ejecutar:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'No se detectó ningún gestor de paquetes compatible en el servidor remoto. Instala tmux manualmente.';

  @override
  String get terminalTmuxInstallFailed =>
      'Falló la instalación de tmux. Verifica los permisos del servidor y la red.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'Conexión SSH perdida. Vuelve a conectarte para instalar tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Instalando tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Instalar tmux';

  @override
  String get terminalTmuxInstallSkip => 'Omitir (usar shell simple)';

  @override
  String get sftpDownload => 'Descargar';

  @override
  String get sftpOpen => 'Abrir';

  @override
  String get sftpUploadFailed =>
      'Error al subir. Verifica los permisos y vuelve a intentarlo.';

  @override
  String get sftpDownloadFailed => 'Error al descargar';

  @override
  String get sftpOpenUnsupported =>
      'Este formato de archivo no se puede abrir.';

  @override
  String get sftpReadFailed =>
      'Error al leer el archivo. Verifica los permisos e inténtalo de nuevo.';

  @override
  String get sftpTransferFailed =>
      'Error en la operación del archivo. Inténtalo de nuevo.';

  @override
  String get sftpDownloadSuccess => 'Descargado correctamente';

  @override
  String get sftpUploading => 'Subiendo...';

  @override
  String get sftpDownloading => 'Descargando...';

  @override
  String get sftpUpDirectory => 'Subir al directorio superior';

  @override
  String get sftpShowHiddenFiles => 'Mostrar archivos ocultos';

  @override
  String get sftpHideHiddenFiles => 'Ocultar archivos ocultos';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Error al guardar la preferencia de archivos ocultos';

  @override
  String get sftpViewModeList => 'Vista de lista';

  @override
  String get sftpViewModeGrid => 'Vista de cuadrícula';

  @override
  String get sftpViewPreferenceSaveFailed =>
      'Error al guardar la preferencia de modo de vista';

  @override
  String get sftpSymlink => 'Enlace simbólico';

  @override
  String get sftpLinkTargetUnavailable =>
      'El destino del enlace simbólico no está disponible o está roto';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Permiso denegado para leer el destino del enlace simbólico';

  @override
  String get settingsAutoConnect => 'Conectar automáticamente al iniciar';

  @override
  String get settingsAutoConnectFixed => 'Servidor SSH fijo por defecto';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Conectar siempre al servidor seleccionado a continuación';

  @override
  String get settingsAutoConnectLast => 'Recordar última conexión';

  @override
  String get settingsAutoConnectLastDesc =>
      'Conectar al último servidor conectado con éxito';

  @override
  String get settingsAutoConnectPickServer => 'Servidor';

  @override
  String get settingsAutoConnectNoServer =>
      'Ningún servidor seleccionado todavía';

  @override
  String get sftpSort => 'Ordenar';

  @override
  String get sftpSortName => 'Nombre';

  @override
  String get sftpSortSize => 'Tamaño';

  @override
  String get sftpSortDate => 'Fecha de modificación';

  @override
  String get sftpSortAscending => 'Ascendente';

  @override
  String get sftpSortDescending => 'Descendente';

  @override
  String get themeQuickSwitch => 'Tema';

  @override
  String get transferList => 'Transferencias';

  @override
  String get transferEmpty => 'Aún no hay transferencias';

  @override
  String get transferUpload => 'Subida';

  @override
  String get transferDownload => 'Descarga';

  @override
  String get transferStatusQueued => 'En cola';

  @override
  String get transferStatusRunning => 'Transfiriendo';

  @override
  String get transferStatusPaused => 'En pausa';

  @override
  String get transferStatusCompleted => 'Completado';

  @override
  String get transferStatusFailed => 'Error';

  @override
  String get transferStatusCanceled => 'Cancelado';

  @override
  String get transferPause => 'Pausar';

  @override
  String get transferResume => 'Reanudar';

  @override
  String get transferCancel => 'Cancelar';

  @override
  String get transferRemove => 'Eliminar';

  @override
  String get transferClearFinished => 'Limpiar completados';

  @override
  String get transferSizeUnknown => 'Tamaño desconocido';

  @override
  String get transferFailedUpload => 'Error de subida';

  @override
  String get transferFailedDownload => 'Error de descarga';

  @override
  String get stopGeneration => 'Detener';

  @override
  String get chatServerBindingRequired =>
      'Esta sesión no está vinculada a ningún servidor. Vincúlala al servidor actual para continuar.';

  @override
  String get chatSessionUnboundNotice =>
      'Esta sesión no está vinculada a ningún servidor.';

  @override
  String get bindServerAction => 'Vincular servidor';

  @override
  String get bindServerDialogTitle => 'Vincular sesión al servidor';

  @override
  String get bindServerConfirmAction => 'Confirmar vinculación';

  @override
  String get chatSessionIdentityMismatch =>
      'El servidor o agente actual no coincide con la identidad vinculada a esta sesión. Cambia al servidor y agente correspondientes para continuar.';

  @override
  String get deleteSessionTitle => 'Eliminar sesión';

  @override
  String get deleteSessionConfirmAction => 'Eliminar';

  @override
  String get shareAgentSessionsTitle => 'Compartir sesiones de agentes';

  @override
  String get shareAgentSessionsSubtitle =>
      'Compartir sesiones entre diferentes agentes en este servidor';

  @override
  String get shareAgentSessionsEnabled =>
      'Uso compartido de sesiones de agentes habilitado';

  @override
  String get shareAgentSessionsDisabled =>
      'Uso compartido de sesiones de agentes deshabilitado';

  @override
  String get agentCliStatusInstalled => 'CLI: Instalado';

  @override
  String get agentCliStatusMissing => 'CLI: No encontrado';

  @override
  String get agentCliStatusChecking => 'CLI: Comprobando...';

  @override
  String get agentCliStatusUnknown => 'CLI: Desconocido';

  @override
  String get agentCliStatusError => 'CLI: Error';

  @override
  String get agentAcpStatusReady => 'ACP: Listo';

  @override
  String get agentAcpStatusMissing => 'ACP: No encontrado';

  @override
  String get agentAcpStatusChecking => 'ACP: Comprobando...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Esperando CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Desconocido';

  @override
  String get agentAcpStatusError => 'ACP: Error';

  @override
  String get agentAcpStatusNa => 'ACP: N/A';

  @override
  String get agentAuthStatusAuthenticated => 'Autenticación: Conectado';

  @override
  String get agentAuthStatusUnauthenticated => 'Autenticación: No conectado';

  @override
  String get agentAuthStatusUnknown => 'Autenticación: Desconocido';

  @override
  String get downloadNotificationsUnavailable =>
      'Las notificaciones de descarga del sistema no están disponibles. Las descargas continuarán en segundo plano.';

  @override
  String get downloadOpenFailed => 'No se pudo abrir el archivo descargado.';

  @override
  String get dockerActionPending =>
      'Ya hay una acción en curso para este contenedor';

  @override
  String get dockerNoLogs => '(Sin registros)';

  @override
  String get serverReboot => 'Reiniciar';

  @override
  String get serverRebootDialogTitle => 'Confirmar reinicio del servidor';

  @override
  String get serverRebootDialogMessage =>
      '¿Seguro que deseas reiniciar este servidor? Se cerrarán todas las conexiones activas y los servicios en segundo plano.';

  @override
  String get serverRebootConfirmButton => 'Reiniciar ahora';

  @override
  String get serverRebootPasswordTitle => 'Contraseña de sudo requerida';

  @override
  String get serverRebootPasswordMessage =>
      'Se requieren privilegios de root para reiniciar el servidor. Introduce la contraseña de sudo (se usa una vez, no se guarda):';

  @override
  String get serverRebootPasswordHint => 'Contraseña de Sudo';

  @override
  String get serverRebootSubmitting => 'Enviando comando de reinicio...';

  @override
  String get serverRebootAccepted =>
      'Comando de reinicio aceptado; finalización aún no verificada. Vuelve a conectarte cuando el servidor vuelva a estar en línea.';

  @override
  String get serverRebootVerified =>
      'Se ha verificado el reinicio del servidor; el sistema vuelve a estar en línea.';

  @override
  String get serverRebootUnknown =>
      'El resultado del reinicio es incierto. El comando se envió, pero no se pudo confirmar la finalización. Comprueba la conexión manualmente.';

  @override
  String get serverRebootReconnect => 'Reconectar';

  @override
  String get serverRebootServerChanged =>
      'El servidor de destino cambió, reinicio cancelado';

  @override
  String get navCliChat => 'Chat CLI';

  @override
  String get cliChatTitle => 'Sesiones CLI';

  @override
  String get cliChatSubtitle =>
      'Sesiones nativas de agentes CLI en el servidor remoto';

  @override
  String get cliSelectAgent => 'Seleccionar agente';

  @override
  String get cliNoAgentsConfigured =>
      'No hay agentes añadidos para este servidor';

  @override
  String get cliAgentNeedsSetup =>
      'Falta el entorno del agente o no ha iniciado sesión';

  @override
  String get cliManageAgentsGuide => 'Configurar en Gestión de agentes';

  @override
  String get cliNewDraft => 'Nuevo borrador';

  @override
  String get cliNewDraftTooltip =>
      'Crear un borrador en blanco (la sesión se crea al enviar el primer mensaje)';

  @override
  String get cliDeleteSessionTitle => 'Eliminar historial de sesión CLI remoto';

  @override
  String get cliDeleteSessionMessage =>
      'Esto eliminará permanentemente el historial de sesiones CLI en el servidor remoto. ¿Estás seguro de que deseas continuar?';

  @override
  String get cliDeleteConfirmButton => 'Eliminar sesión';

  @override
  String get cliCannotDeleteTooltip =>
      'Eliminación de sesiones remotas no compatible o deshabilitada';

  @override
  String get cliSessionsHeader => 'Sesiones';

  @override
  String get cliNoSessions => 'No se encontraron sesiones CLI';

  @override
  String get cliFilterCwdHint => 'Filtrar por ruta CWD...';

  @override
  String get cliFilterCwdAction => 'Filtrar';

  @override
  String get cliClearCwdAction => 'Limpiar';

  @override
  String get cliLoadMoreSessions => 'Cargar más sesiones';

  @override
  String get cliRefreshSessions => 'Actualizar';

  @override
  String get cliClaudeReadOnlyNotice =>
      'El historial de Claude es de solo lectura. Continúa la conversación en el terminal real.';

  @override
  String get cliContinueInTerminal => 'Continuar en el terminal';

  @override
  String get cliOpenTerminal => 'Abrir terminal';

  @override
  String get cliCloseTerminal => 'Cerrar terminal';

  @override
  String get cliTerminalRunning => 'Terminal CLI interactivo';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Este agente no admite sincronización estructurada del historial. Utiliza el terminal CLI nativo para la interacción y selección de sesiones.';

  @override
  String get cliInstallSdkTitle =>
      'Instalar SDK oficial de historial de Claude';

  @override
  String get cliInstallSdkMessage =>
      'Falta el SDK oficial de Claude Code History en el servidor remoto. ¿Deseas instalarlo ahora?';

  @override
  String get cliInstallSdkAction => 'Instalar SDK oficial';

  @override
  String get cliApprovalsTitle => 'Aprobaciones pendientes';

  @override
  String get cliApprovalDetails => 'Detalles';

  @override
  String get cliApprovalAllow => 'Permitir';

  @override
  String get cliApprovalDecline => 'Rechazar';

  @override
  String get cliInputHint => 'Escribe un mensaje para el agente CLI...';

  @override
  String get cliSend => 'Enviar';

  @override
  String get cliStop => 'Detener';

  @override
  String get cliBusy => 'Operación en curso, por favor espera...';

  @override
  String get cliDisconnected => 'SSH no está conectado';

  @override
  String get cliServerChanged => 'El servidor de destino cambió';

  @override
  String get cliTurnFailed => 'Falló la ejecución del turno de CLI';

  @override
  String get cliUseTerminal =>
      'Se requiere entrada interactiva, abre el terminal para continuar';

  @override
  String get cliDeleteFailed => 'Error al eliminar la sesión remota';

  @override
  String get cliDeleteUnsupported =>
      'Este CLI no admite eliminar sesiones remotas';

  @override
  String get cliOperationFailed => 'Operación de CLI fallida';

  @override
  String get cliHistorySdkMissing =>
      'Falta el SDK oficial de historial en el servidor';

  @override
  String get cliHistoryRuntimeMissing =>
      'El historial de Claude requiere Node.js/npm en el servidor. Instala Node.js manualmente; aún puedes usar el CLI real en el terminal.';

  @override
  String get cliLoginRequired =>
      'Se requiere inicio de sesión del agente. Inicia sesión a través de Gestión de agentes.';

  @override
  String get cliNotInstalled =>
      'CLI del agente no instalado. Instálalo a través de Gestión de agentes.';

  @override
  String get cliVersionUnsupported =>
      'Versión del CLI del agente no compatible. Actualízala o reinstálala mediante Gestión de agentes.';

  @override
  String get settingsNavigation => 'Navegación';

  @override
  String get settingsNavigationDesc =>
      'Configurar la página de inicio predeterminada y la barra de navegación inferior';

  @override
  String get settingsStartupPage => 'Página de inicio';

  @override
  String get settingsStartupPageDesc =>
      'Página mostrada al abrir la aplicación';

  @override
  String get settingsBottomNav => 'Barra de navegación inferior';

  @override
  String get settingsBottomNavDesc =>
      'Seleccionar secciones para mostrar en la barra inferior móvil (admite de 0 a 9 elementos)';

  @override
  String get settingsResetSuccess =>
      'Todos los ajustes se han restablecido a los valores predeterminados';

  @override
  String get metricsTrendSubtitle => 'Últimos ~3 minutos (hasta 60 muestras)';

  @override
  String get metricsCurrent => 'Actual';

  @override
  String get metricsPeak => 'Pico';

  @override
  String get metricsValley => 'Valle';

  @override
  String get metricsTrendWaiting => 'Recopilando datos de métricas...';

  @override
  String get metricsTrendStopped =>
      'Recopilación de datos detenida (SSH desconectado)';

  @override
  String get dockerActionTerminal => 'Terminal Exec';

  @override
  String get dockerTerminalTitle => 'Terminal del contenedor';

  @override
  String get dockerTerminalNotRunning => 'El contenedor no está en ejecución';

  @override
  String get setDefaultAgent => 'Establecer por defecto';

  @override
  String get defaultBadge => 'Por defecto';

  @override
  String get isDefaultAgent => 'Agente por defecto';

  @override
  String get setAsDefaultAgent =>
      'Establecer como agente predeterminado para este servidor';

  @override
  String get agentGroupBasic => 'Información básica';

  @override
  String get agentGroupCommands => 'Comandos';

  @override
  String get agentGroupAuth => 'Instalación y autenticación';

  @override
  String get agentPresetTitle => 'Plantilla predefinida';

  @override
  String get resourceProcessList => 'Procesos';

  @override
  String get resourceDiskScanning =>
      'Escaneando directorios raíz, esto puede tardar unos segundos...';

  @override
  String get resourceDiskScanPartial =>
      'Algunos directorios no se pudieron escanear por permisos o tiempo de espera';

  @override
  String get resourceDiskDirectories => 'Uso de directorios de primer nivel';

  @override
  String get resourceSortCpu => 'Ordenar por CPU';

  @override
  String get resourceSortMemory => 'Ordenar por memoria';

  @override
  String get resourceRss => 'Memoria RSS';

  @override
  String get resourceUsed => 'Usado';

  @override
  String get resourceAvailable => 'Disponible';

  @override
  String get resourceTotal => 'Total';

  @override
  String get settingsBottomNavOrderTitle =>
      'Elementos seleccionados (Arrastrar para reordenar)';

  @override
  String get langSystem => 'Predeterminado del sistema';

  @override
  String get serverFieldRequired => 'Obligatorio';

  @override
  String get serverPortInvalid => 'El puerto debe estar entre 1 y 65535';

  @override
  String get serverTestReachability => 'Probar accesibilidad';

  @override
  String get serverSaveFailedGeneric =>
      'Error al guardar el servidor. Comprueba la configuración y vuelve a intentarlo.';

  @override
  String get serverViewPrivateKey => 'Ver clave privada';

  @override
  String get serverHidePrivateKey => 'Ocultar clave privada';

  @override
  String get dockerBashFallbackNotice =>
      'Bash no está disponible en el contenedor, se usará Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Directorio de trabajo';

  @override
  String get cliDefaultWorkingDir => 'Predeterminado (/)';

  @override
  String get cliPickWorkingDirTitle => 'Seleccionar directorio de trabajo';

  @override
  String get cliClearWorkingDir => 'Restablecer a predeterminado';

  @override
  String get cliBrowseWorkingDir => 'Examinar';

  @override
  String get cliSelectCurrentDir => 'Seleccionar este directorio';

  @override
  String get cliNavigateUp => 'Subir de nivel';

  @override
  String get chatSessionsTooltip => 'Sesiones';

  @override
  String get hardwareSpecsTitle => 'Hardware y sistema';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Memoria';

  @override
  String get hardwareDisk => 'Disco raíz';

  @override
  String get hardwareDistribution => 'SO';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Cargando especificaciones de hardware...';

  @override
  String get hardwareUnavailable => 'Especificaciones no disponibles';

  @override
  String get hardwareUnknown => 'Desconocido';

  @override
  String get systemInfoTitle => 'Información del sistema';

  @override
  String get systemInfoTapHint => 'Toca para ver el arte ASCII';

  @override
  String get systemInfoHost => 'Host';

  @override
  String get serverShutdown => 'Apagar';

  @override
  String get serverShutdownDialogTitle => 'Confirmar apagado del servidor';

  @override
  String get serverShutdownDialogMessage =>
      '¿Seguro que deseas apagar este servidor? El sistema se apagará por completo y no se podrá acceder de forma remota hasta que se encienda manualmente.';

  @override
  String get serverShutdownConfirmButton => 'Apagar ahora';

  @override
  String get serverShutdownSubmitting => 'Enviando comando de apagado...';

  @override
  String get serverShutdownAccepted =>
      'Comando de apagado aceptado; la finalización no se ha verificado.';

  @override
  String get serverShutdownUnknown =>
      'Resultado de apagado desconocido: es posible que se haya enviado el comando, pero no se puede confirmar. Comprueba manualmente; no se reintentará de forma automática.';

  @override
  String get serverShutdownPasswordTitle =>
      'Contraseña de sudo requerida para apagar';

  @override
  String get serverShutdownPasswordMessage =>
      'Se requieren privilegios de root para apagar el servidor. Introduce la contraseña de sudo (se usa una vez, no se guarda):';

  @override
  String get serverShutdownPasswordHint => 'Contraseña de Sudo';

  @override
  String get serverShutdownServerChanged =>
      'El servidor de destino cambió, apagado cancelado';

  @override
  String get metricsNetwork => 'Tasa de red';

  @override
  String get networkModalTitle => 'Detalles de interfaces de red';

  @override
  String get networkDownloadRate => 'Descarga (RX)';

  @override
  String get networkUploadRate => 'Subida (TX)';

  @override
  String get networkTotalRx => 'Total RX';

  @override
  String get networkTotalTx => 'Total TX';

  @override
  String get networkPrimary => 'Ruta por defecto';

  @override
  String get networkRatesEmpty => 'No se detectaron interfaces de red activas';

  @override
  String get networkWaitingSecondSample => 'Esperando segunda muestra';

  @override
  String get networkUnavailable => 'No disponible';

  @override
  String get networkNoDefaultInterface => 'Sin ruta por defecto';

  @override
  String get selectThemeModeTitle => 'Seleccionar modo de tema';

  @override
  String get selectLanguageTitle => 'Seleccionar idioma';

  @override
  String get selectStartupPageTitle => 'Seleccionar página de inicio';

  @override
  String get selectAutoConnectModeTitle =>
      'Seleccionar modo de conexión automática';

  @override
  String get accentColorDialogTitle => 'Personalizar colores de acento';

  @override
  String get accentColorLightMode => 'Modo claro';

  @override
  String get accentColorDarkMode => 'Modo oscuro';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Valores predeterminados';

  @override
  String get accentColorHsvPicker => 'Rueda de colores';

  @override
  String get accentColorHexCode => 'Código Hex';

  @override
  String get accentColorPreview => 'Vista previa';

  @override
  String get accentColorSampleButton => 'Botón de acento';

  @override
  String get accentColorInvalidHex =>
      'Formato hexadecimal no válido (ej. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Acciones rápidas del panel';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Configurar accesos directos mostrados en el panel. Limpiar ocultará la sección de acciones rápidas.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Acciones rápidas ocultas (ningún acceso seleccionado)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Arrastrar para reordenar accesos directos';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Seleccionar accesos directos visibles';

  @override
  String get terminalCopySelection => 'Copiar';

  @override
  String get terminalSelectionCopied => 'Selección copiada al portapapeles';

  @override
  String get editAgent => 'Editar agente';

  @override
  String get agentExecutionTarget => 'Entorno de ejecución';

  @override
  String get agentExecutionHost => 'Sistema host';

  @override
  String get agentExecutionDocker => 'Contenedor Docker';

  @override
  String get agentContainerBinding => 'Modo de enlace de contenedor';

  @override
  String get agentContainerBindingId => 'Por ID de contenedor';

  @override
  String get agentContainerBindingName => 'Por nombre de contenedor';

  @override
  String get agentContainerReference => 'Contenedor de destino';

  @override
  String get agentContainerReferenceHint =>
      'Seleccionar o ingresar ID o nombre de contenedor';

  @override
  String get agentContainerRequired =>
      'Se requiere un contenedor de destino para ejecución en Docker';

  @override
  String get agentLoadingContainers =>
      'Consultando contenedores en el servidor...';

  @override
  String get agentNoContainersFound =>
      'No se encontraron contenedores en este servidor';

  @override
  String get agentContainerUser =>
      'Usuario de ejecución del contenedor (Opcional)';

  @override
  String get agentContainerUserHint => 'p. ej., dev';

  @override
  String get agentContainerUserHelper =>
      'Dejar en blanco para usar el usuario predeterminado de la imagen; ej. dev; admite user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Seleccionar usuario del contenedor';

  @override
  String get agentContainerUsersLoading => 'Cargando usuarios...';

  @override
  String get agentContainerUsersEmpty => 'No se encontraron usuarios en passwd';

  @override
  String get agentViewDiagnosticLog => 'Ver registro de diagnóstico';

  @override
  String get agentDiagnosticLogCopied =>
      'Registro de diagnóstico copiado al portapapeles';

  @override
  String get agentDiagnosticLogCopy => 'Copiar';

  @override
  String get agentDiagnosticLogClose => 'Cerrar';

  @override
  String get settingsCliHistoryPageSize => 'Tamaño de página del historial CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Número de mensajes anteriores cargados por página al desplazarse hacia arriba (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Seleccionar tamaño de página del historial CLI';

  @override
  String get cliLoadingOlderMessages => 'Cargando mensajes anteriores...';

  @override
  String get chatLoadOlderMessages => 'Cargar mensajes anteriores';

  @override
  String get chatCommandsTooltip => 'Comandos';

  @override
  String get chatAttachTooltip => 'Adjuntar archivo';

  @override
  String get chatAttachImage => 'Adjuntar imagen local';

  @override
  String get chatAttachLocalText => 'Adjuntar archivo de texto local';

  @override
  String get chatAttachRemoteText => 'Adjuntar archivo de texto remoto';

  @override
  String get chatAttachRemotePathTitle => 'Adjuntar archivo de texto remoto';

  @override
  String get chatAttachRemotePathHint => '/ruta/al/archivo.txt';

  @override
  String get chatAttachTooLarge => 'El archivo supera el límite de tamaño';

  @override
  String get chatUsageAndDiagnostics => 'Uso y diagnóstico';

  @override
  String get chatWorkingDirTooltip => 'Directorio de trabajo del borrador';

  @override
  String get chatAttachFailed => 'Error al adjuntar archivo';

  @override
  String get chatInvalidRemotePath =>
      'Ruta remota no válida (debe comenzar con /)';

  @override
  String get chatRemoteReadFailed => 'Error al leer el archivo remoto';

  @override
  String get chatInvalidDirPath =>
      'Ruta de directorio no válida (debe comenzar con /)';

  @override
  String get chatNoSubdirectories => 'Sin subdirectorios';

  @override
  String get chatUsageTitle => 'Uso de tokens y costes';

  @override
  String get chatUsageUsed => 'Tokens usados';

  @override
  String get chatUsageSize => 'Tamaño del contexto';

  @override
  String get chatUsageCost => 'Coste';

  @override
  String get chatDiagnosticsTitle => 'Registro de diagnóstico';

  @override
  String get chatNoDiagnostics => 'No hay registros de diagnóstico disponibles';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Esto solo elimina el registro local en Valhalla y no borrará el historial nativo del agente en el servidor.';

  @override
  String get chatSearchSessionsHint => 'Buscar sesiones...';

  @override
  String get chatLoadMoreSessions => 'Cargar más sesiones';

  @override
  String get chatLoadingMoreSessions => 'Cargando más sesiones...';

  @override
  String get chatExportSession => 'Exportar sesión (Markdown)';

  @override
  String get chatExportSuccess => 'Sesión exportada con éxito';

  @override
  String get chatExportFailed => 'Error al exportar la sesión';

  @override
  String get chatRemoteSessions => 'Sesiones remotas';

  @override
  String get chatRemoteSessionsTitle => 'Sesiones remotas de agentes';

  @override
  String get chatRemoteSessionsDesc =>
      'Ver e importar historial nativo de sesiones del agente remoto';

  @override
  String get chatRemoteSessionsEmpty => 'No se encontraron sesiones remotas';

  @override
  String get chatRemoteImporting =>
      'Importando historial de sesiones remotas...';

  @override
  String get chatRemoteImportFailed => 'Error al importar sesión remota';

  @override
  String get chatStatusInterrupted => 'Interrumpido';

  @override
  String get chatStatusFailed => 'Error';

  @override
  String get chatStatusAwaitingAuth => 'Esperando autenticación ACP';

  @override
  String get chatShowFullOutput => 'Mostrar toda la salida';

  @override
  String get chatShowLessOutput => 'Mostrar menos';

  @override
  String get chatToolLocations => 'Rutas afectadas';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Introduce el valor para $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Proceso $pid terminado';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Acción $action en $service completada con éxito';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Regla activada: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Código de salida: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Conectado correctamente a $server vía SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Error de conexión SSH: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Conectando a $host ($type) por primera vez.\n\nHuella digital SHA-256:\n$fingerprint\n\n¿Confiar en esta huella y conectar?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Introduce la contraseña para $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return '¿Seguro que deseas eliminar el servidor \'$name\'? Esta acción no se puede deshacer.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return '¿Seguro que deseas eliminar el agente \'$name\'? Esto elimina su configuración y estado de tiempo de ejecución en este servidor sin afectar el historial de chats o las credenciales SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Última comprobación: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Elige cómo iniciar sesión en $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Reconectando… (intento $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n sesión(es) activa(s)';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return '¿Vincular esta sesión al servidor \\\"$serverName\\\"? Una vez vinculada, quedará asociada a este servidor.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return '¿Seguro que deseas eliminar la sesión \\\"$title\\\"? Esta acción no se puede deshacer.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Acción $action en el contenedor $name exitosa';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Acción fallida: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Servidor de destino: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Sesiones de terminal: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Sesiones de agente: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Transferencias activas: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Error al reiniciar: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Error al eliminar la sesión remota: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Tendencia de $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Advertencia: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Peligro: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count puntos de datos';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Uso de recursos de $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'Puerto TCP $port accesible';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Error de conexión: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Error al guardar el servidor: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores núcleos';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Error al apagar: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Interfaz: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Error al cargar contenedores: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Error al cargar usuarios del contenedor: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Registro de diagnóstico - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Falló la detección de Docker/contenedor';

  @override
  String get chatCopiedAllMessages => 'Todos los mensajes copiados';

  @override
  String get chatCopyAllMessages => 'Copiar todos los mensajes';

  @override
  String get cliModelAtCapacity =>
      'El modelo seleccionado está saturado. Prueba con otro modelo.';

  @override
  String get chatLaunchBlankDraft => 'Borrador en blanco';

  @override
  String get chatLaunchFixedSession => 'Sesión fija';

  @override
  String get chatLaunchRememberLast => 'Recordar última sesión';

  @override
  String get chatPermissionAskEveryTime => 'Preguntar siempre';

  @override
  String get chatPermissionAutoAllowAll => 'Permitir todo automáticamente';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'El agente ejecutará todas las operaciones sin preguntar. ¿Continuar?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      '¿Permitir todas las operaciones?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Permitir operaciones seguras automáticamente';

  @override
  String get chatRunSettingsDefault => 'Predeterminado';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI interactivo';

  @override
  String get chatRunSettingsModel => 'Modelo';

  @override
  String get chatRunSettingsPermissions => 'Permisos';

  @override
  String get chatRunSettingsReasoning => 'Nivel de razonamiento';

  @override
  String get chatRunSettingsTitle => 'Ajustes de ejecución';

  @override
  String get cliActionInsertCommand => 'Insertar comando';

  @override
  String get cliActionInsertFile => 'Insertar archivo';

  @override
  String get cliActionInsertWorkdir => 'Insertar directorio de trabajo';

  @override
  String get cliComposerInsertAction => 'Insertar';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Operación de CLI fallida: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Seleccionar comando';

  @override
  String get defaultAgentTitle => 'Agente predeterminado';

  @override
  String get insertSkills => 'Insertar habilidades';

  @override
  String get isDefaultSession => 'Sesión predeterminada';

  @override
  String get sessionLaunchMode => 'Modo de inicio de sesión';

  @override
  String get setAsDefaultSession => 'Establecer como sesión predeterminada';

  @override
  String get navNas => 'Medios NAS';

  @override
  String get nasAddExcludePath => 'Añadir ruta excluida';

  @override
  String get nasAddIncludePath => 'Añadir carpeta de escaneo';

  @override
  String get nasCancelScan => 'Cancelar escaneo';

  @override
  String get nasClearSearch => 'Limpiar búsqueda';

  @override
  String get nasConfigDialogTitle => 'Ajustes de la biblioteca de medios';

  @override
  String get nasConfigure => 'Configurar';

  @override
  String get nasConfigureScanDirs => 'Configurar carpetas de escaneo';

  @override
  String get nasCreatePlaylist => 'Crear lista de reproducción';

  @override
  String get nasEmptyConfigDesc =>
      'Añade al menos una carpeta para comenzar a crear tu biblioteca multimedia.';

  @override
  String get nasEmptyConfigTitle => 'No hay carpetas de escaneo configuradas';

  @override
  String get nasExcludePaths => 'Carpetas excluidas';

  @override
  String get nasExcludedBadge => 'Excluido';

  @override
  String get nasFilterImages => 'Imágenes';

  @override
  String get nasFilterVideos => 'Vídeos';

  @override
  String get nasIncludePaths => 'Carpetas de escaneo';

  @override
  String nasItemCount(Object value) {
    return '$value elementos';
  }

  @override
  String nasLastScan(Object value) {
    return 'Último escaneo: $value';
  }

  @override
  String get nasLibrarySettings => 'Ajustes de la biblioteca';

  @override
  String nasMediaOpening(Object value) {
    return 'Abriendo $value…';
  }

  @override
  String get nasMiniPlayer => 'Mini reproductor';

  @override
  String get nasNoExcludePaths => 'Sin carpetas excluidas';

  @override
  String get nasNoFavorites => 'Aún no hay favoritos';

  @override
  String get nasNoIncludePaths => 'Sin carpetas de escaneo';

  @override
  String get nasNoIndexDesc =>
      'Configura carpetas y realiza un escaneo para indexar tus archivos.';

  @override
  String get nasNoIndexTitle => 'La biblioteca de medios está vacía';

  @override
  String get nasNoPlaylists => 'Aún no hay listas de reproducción';

  @override
  String get nasNoSearchResults => 'No hay medios coincidentes';

  @override
  String get nasNotScanned => 'Aún no escaneado';

  @override
  String get nasNowPlaying => 'Reproduciendo ahora';

  @override
  String get nasOpenMethodPrompt => '¿Cómo deseas abrir este archivo?';

  @override
  String get nasOpenPolicyAsk => 'Preguntar siempre';

  @override
  String get nasOpenPolicyExternal => 'Abrir con otra aplicación';

  @override
  String get nasOpenPolicyInApp => 'Abrir en la aplicación';

  @override
  String get nasOpeningPolicy => 'Método de apertura predeterminado';

  @override
  String get nasPlaylistName => 'Nombre de la lista';

  @override
  String get nasQuickStats => 'Resumen de la biblioteca';

  @override
  String get nasScan => 'Escanear ahora';

  @override
  String get nasScanCancelled => 'Escaneo cancelado';

  @override
  String nasScanFailed(Object value) {
    return 'Error de escaneo: $value';
  }

  @override
  String get nasScanning => 'Escaneando…';

  @override
  String get nasScopeBadge => 'Alcance del escaneo';

  @override
  String get nasSearchHint => 'Buscar medios';

  @override
  String get nasStatMusic => 'Música';

  @override
  String get nasStatPhotos => 'Fotos';

  @override
  String get nasStatTotal => 'Total';

  @override
  String get nasStatVideos => 'Vídeos';

  @override
  String get nasTabFavorites => 'Favoritos';

  @override
  String get nasTabFolders => 'Carpetas';

  @override
  String get nasTabHome => 'Inicio';

  @override
  String get nasTabMusic => 'Música';

  @override
  String get nasTabPhotos => 'Fotos';

  @override
  String get nasTabPlaylists => 'Listas de reproducción';

  @override
  String get nasTabVideos => 'Vídeos';

  @override
  String get nasSources => 'Fuentes de medios';

  @override
  String get nasAddSource => 'Añadir fuente de medios';

  @override
  String get nasEditSource => 'Editar fuente de medios';

  @override
  String get nasRemoveSource => 'Eliminar fuente de medios';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return '¿Seguro que deseas eliminar la fuente de medios \'$name\'? Esto elimina su configuración sin borrar los archivos remotos.';
  }

  @override
  String get nasNoSources => 'No hay fuentes de medios configuradas';

  @override
  String get nasNoSourcesDesc =>
      'Añade SFTP, SMB, WebDAV, Jellyfin o Emby para empezar a explorar tus medios.';

  @override
  String get nasSourceType => 'Tipo de fuente';

  @override
  String get nasSourceName => 'Nombre de la fuente';

  @override
  String get nasProbe => 'Probar conexión';

  @override
  String get nasProbeSuccess => 'Conexión exitosa';

  @override
  String get nasProbeFailed => 'Error en la prueba de conexión';

  @override
  String get nasEndpoint => 'Punto final / URL';

  @override
  String get nasRootPath => 'Ruta raíz';

  @override
  String get nasUsername => 'Nombre de usuario';

  @override
  String get nasPassword => 'Contraseña';

  @override
  String get nasDomain => 'Dominio (opcional)';

  @override
  String get nasAuthenticate => 'Autenticar';

  @override
  String get nasAuthSuccess => 'Autenticación exitosa';

  @override
  String get nasAuthFailed => 'Error de autenticación';

  @override
  String get nasTabDownloads => 'Descargas';

  @override
  String get nasNoDownloads => 'No hay tareas de descarga';

  @override
  String get nasDownloadQueued => 'En cola';

  @override
  String get nasDownloadDownloading => 'Descargando';

  @override
  String get nasDownloadCompleted => 'Completado';

  @override
  String get nasDownloadCancelled => 'Cancelado';

  @override
  String get nasDownloadFailed => 'Error de descarga';

  @override
  String get nasRetryDownload => 'Reintentar';

  @override
  String get nasCancelDownload => 'Cancelar';

  @override
  String get nasOpenDownloadedFile => 'Abrir archivo';

  @override
  String get nasQueue => 'Cola de reproducción';

  @override
  String get nasNoQueue => 'La cola está vacía';

  @override
  String get nasSpeed => 'Velocidad';

  @override
  String get nasQuality => 'Calidad';

  @override
  String get nasAudioTrack => 'Pista de audio';

  @override
  String get nasSubtitleTrack => 'Subtítulos';

  @override
  String get nasRepeatOff => 'Repetición desactivada';

  @override
  String get nasRepeatAll => 'Repetir todo';

  @override
  String get nasRepeatOne => 'Repetir una';

  @override
  String get nasShuffle => 'Aleatorio';

  @override
  String get nasCast => 'Transmitir (Cast)';

  @override
  String get nasCastUnavailable =>
      'No hay dispositivos de transmisión disponibles';

  @override
  String get nasSlideshow => 'Presentación de diapositivas';

  @override
  String get nasByFolder => 'Carpetas';

  @override
  String get nasByArtist => 'Artistas';

  @override
  String get nasByAlbum => 'Álbumes';

  @override
  String get nasAllTracks => 'Todas las pistas';

  @override
  String get nasPlayAll => 'Reproducir todo';

  @override
  String get nasPreviousPage => 'Anterior';

  @override
  String get nasNextPage => 'Siguiente';

  @override
  String get nasClearScope => 'Volver a todo';

  @override
  String get nasRenamePlaylist => 'Renombrar lista';

  @override
  String get nasRemoveFromPlaylist => 'Quitar de la lista';

  @override
  String get nasMoveUp => 'Mover arriba';

  @override
  String get nasMoveDown => 'Mover abajo';

  @override
  String get nasSshServer => 'Servidor SSH';

  @override
  String get nasSelectSshServer => 'Seleccionar servidor SSH guardado';

  @override
  String get nasQualityOriginal => 'Original';

  @override
  String get nasQualityAuto => 'Automático';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Dispositivos DLNA disponibles';

  @override
  String get nasCastDiscovering => 'Buscando dispositivos DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'Retransmitiendo flujo mediante la aplicación en primer plano. Mantén Valhalla abierta.';

  @override
  String get nasCastStop => 'Detener transmisión';

  @override
  String get nasCastVolume => 'Volumen';

  @override
  String get nasCastRetry => 'Reintentar búsqueda';

  @override
  String get nasInstallTitle => 'Desplegar servidor multimedia NAS';

  @override
  String get nasInstallProduct => 'Producto';

  @override
  String get nasInstallMediaPath => 'Directorio de medios (Solo lectura)';

  @override
  String get nasInstallDataRoot => 'Directorio de datos y configuración';

  @override
  String get nasInstallPort => 'Puerto';

  @override
  String get nasInstallBindAddress => 'Dirección de enlace';

  @override
  String get nasInstallWebdavUser => 'Usuario WebDAV';

  @override
  String get nasInstallWebdavPassword =>
      'Contraseña WebDAV (mín. 12 caracteres)';

  @override
  String get nasInstallPreparePlan => 'Revisar plan de despliegue';

  @override
  String get nasInstallPlanTitle => 'Revisión técnica y confirmación';

  @override
  String get nasInstallBlockersTitle => 'Bloqueadores de despliegue';

  @override
  String get nasInstallConfirmDeploy => 'Confirmar e instalar';

  @override
  String get nasInstallDeploying => 'Desplegando contenedor...';

  @override
  String get nasInstallSuccess => 'Desplegado con éxito';

  @override
  String get nasInstallSuccessDesc =>
      'El servicio se está ejecutando. Completa la configuración inicial del servidor antes de añadirlo como fuente de medios.';

  @override
  String get nasInstallContainerId => 'ID del contenedor';

  @override
  String get nasInstallEndpoint => 'Punto final';

  @override
  String get nasUseSshTunnel => 'Usar túnel SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'Enrutar tráfico a través de un servidor SSH guardado (p. ej., http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'El punto final debe ser accesible desde el servidor SSH, ej. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Dejar en blanco para mantener la contraseña o el token existente';

  @override
  String get nasSourceNameRequired => 'El nombre de la fuente es obligatorio';

  @override
  String get nasInvalidEndpoint => 'URL o esquema de punto final no válido';

  @override
  String get nasSourceUnreachable =>
      'No se puede acceder a la fuente de medios';

  @override
  String get nasSshTunnelFailed => 'Falló la conexión del túnel SSH';

  @override
  String get nasOperationFailed => 'Operación fallida';

  @override
  String get nasInstallStepCreateDir => 'Crear directorio privado';

  @override
  String get nasInstallStepWriteCompose =>
      'Escribir configuración docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Escribir credenciales privadas';

  @override
  String get nasInstallStepPullImage =>
      'Descargar imagen fijada del contenedor';

  @override
  String get nasInstallStepStartService => 'Iniciar servicio en contenedor';

  @override
  String get nasInstallStepCheckHttp => 'Comprobar estado HTTP del servicio';

  @override
  String get nasInstallBlockerDocker =>
      'Se requiere Docker Engine en el servidor de destino';

  @override
  String get nasInstallBlockerCompose =>
      'Se requiere el complemento Docker Compose';

  @override
  String get nasInstallBlockerIdentity =>
      'No se pudo verificar la identidad del servidor de destino';

  @override
  String get nasInstallBlockerTools =>
      'Faltan herramientas requeridas (curl, ss, realpath) en el servidor de destino';

  @override
  String get nasInstallBlockerMedia =>
      'El directorio de medios no existe o no se puede leer';

  @override
  String get nasInstallBlockerParent =>
      'El directorio superior de datos no tiene permisos de escritura';

  @override
  String get nasInstallBlockerOverlap =>
      'El directorio de medios y el de datos no pueden superponerse';

  @override
  String get nasInstallBlockerCollision =>
      'El directorio de datos de destino ya existe o es un enlace simbólico';

  @override
  String get nasInstallBlockerPort =>
      'El puerto seleccionado ya está en uso en el servidor de destino';

  @override
  String get nasInstallBlockerContainer =>
      'Ya existe un contenedor con este nombre de proyecto';

  @override
  String get nasInstallBlockerImage =>
      'No se pudo verificar la imagen del contenedor. Comprueba el nombre, la conectividad y la arquitectura del servidor, y reintenta.';

  @override
  String get nasInstallGuidanceTunnel =>
      'El enlace de bucle invertido (127.0.0.1) requiere un túnel SSH para acceso remoto';

  @override
  String get nasInstallGuidanceTls =>
      'Se recomienda proteger el enlace público detrás de un proxy inverso TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Completa la configuración inicial de la cuenta de administrador en el navegador al iniciar por primera vez';

  @override
  String get nasInstallGuidanceReadOnly =>
      'El directorio de medios se monta como solo lectura para proteger tus archivos';

  @override
  String get nasInstallGuidancePreserved =>
      'El directorio de datos se conservará en caso de fallo para facilitar la resolución de problemas';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Descargado (Error al abrir externamente)';

  @override
  String get nasRetryOpen => 'Reintentar abrir';

  @override
  String get nasExternalOpenFailed =>
      'No se pudo abrir el archivo en la aplicación externa';

  @override
  String get nasTitle => 'Medios NAS';

  @override
  String get nasLoadMoreGroups => 'Cargar más grupos';

  @override
  String get nasMetadataEnriching => 'Enriqueciendo etiquetas de música...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Enriqueciendo etiquetas de música ($count procesadas)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Descargando $value…';
  }

  @override
  String get nasSubtitleNone => 'Ninguno';

  @override
  String get nasLibraryId => 'ID de biblioteca';

  @override
  String get nasLibraryIdHint =>
      'Predeterminado: todo (/), o especificar ID de biblioteca';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relativo a la raíz de la fuente ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'La fuente cambió durante la configuración, guardado cancelado';

  @override
  String get nasInvalidLibraryId => 'ID de biblioteca no válido';

  @override
  String get startupFailed => 'La aplicación no pudo iniciarse';

  @override
  String get startupFailedDesc =>
      'Ocurrió un error inesperado durante el inicio. Puedes reintentar o exportar los registros de diagnóstico.';

  @override
  String get retryStartup => 'Reintentar inicio';

  @override
  String get viewDiagnostics => 'Ver diagnósticos';

  @override
  String get exportDiagnostics => 'Exportar diagnósticos';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnósticos exportados a $path';
  }

  @override
  String get diagnosticsExportFailed => 'Error al exportar diagnósticos';

  @override
  String get diagnosticsTitle => 'Diagnóstico de la app';

  @override
  String get settingsDiagnostics => 'Diagnósticos y registros';

  @override
  String get settingsDiagnosticsDesc =>
      'Ver y exportar registros locales saneados de la aplicación';

  @override
  String get diagnosticsEmpty => 'No se encontraron registros de diagnóstico';

  @override
  String diagnosticsStorageError(String error) {
    return 'Error de almacenamiento de diagnósticos: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Incidente recuperable reportado: $category';
  }

  @override
  String get diagnosticsRefresh => 'Actualizar registros';

  @override
  String get nasInstallTaskTitle => 'Tarea de despliegue';

  @override
  String get nasInstallStagePreflight => 'Comprobación previa';

  @override
  String get nasInstallStageReview => 'Revisión del plan';

  @override
  String get nasInstallStageWriting => 'Escribiendo configuración';

  @override
  String get nasInstallStagePulling => 'Descargando imagen';

  @override
  String get nasInstallStageStarting => 'Iniciando contenedor';

  @override
  String get nasInstallStageHealth => 'Comprobando estado';

  @override
  String get nasInstallStageCleanup => 'Limpieza';

  @override
  String get nasInstallStageSucceeded => 'Despliegue exitoso';

  @override
  String get nasInstallStageFailed => 'Despliegue fallido';

  @override
  String get nasInstallStageCancelled => 'Despliegue cancelado';

  @override
  String get nasInstallStageNeedsInspection => 'Requiere inspección';

  @override
  String get nasInstallStageReconciling => 'Conciliando estado';

  @override
  String get nasInstallCancel => 'Cancelar despliegue';

  @override
  String get nasInstallReconcile => 'Conciliar estado';

  @override
  String get nasInstallServerNotFound =>
      'No se encontró el servidor seleccionado';

  @override
  String get nasInstallPortRangeError => 'El puerto debe estar entre 1 y 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Transcurrido: $time';
  }

  @override
  String get nasInstallLogTail => 'Registros recientes';

  @override
  String get nasInstallCleanupCompleted => 'Limpieza de reversión completada';

  @override
  String get nasInstallCleanupIncomplete => 'Limpieza de reversión incompleta';

  @override
  String get nasInstallNewDeployment => 'Nuevo despliegue';

  @override
  String get nasInstallBackEdit => 'Atrás / Editar formulario';

  @override
  String get nasInstallClose => 'Cerrar';

  @override
  String get nasInstallMediaPathHint =>
      'Montaje enlazado de solo lectura en el host (p. ej., /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Directorio privado de datos y configuración (no debe existir todavía)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 para túnel, 0.0.0.0 para LAN';

  @override
  String get nasInstallWebdavPasswordHint =>
      'Se requieren al menos 12 caracteres';

  @override
  String get nasInstallTargetServer => 'Servidor de destino';

  @override
  String get nasInstallTargetImage => 'Imagen de destino';

  @override
  String get nasInstallContainerName => 'Nombre del contenedor';

  @override
  String get nasInstallBindAndPort => 'Enlace y puerto';

  @override
  String get nasInstallComposePreview => 'Vista previa de docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Pasos planificados';

  @override
  String get nasInstallGuidanceNotes => 'Notas y guía de despliegue';

  @override
  String get nasInstallNoLogsYet => 'Aún no hay registros';

  @override
  String get sftpPreviewTooLarge =>
      'El archivo supera el límite de vista previa de 1 MiB. Descárgalo y ábrelo externamente.';

  @override
  String get sftpSaveFailed =>
      'Error al guardar el archivo. Comprueba los permisos o la conexión de red.';

  @override
  String get sftpSaving => 'Guardando...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'La conexión con el servidor de destino cambió; verifica el estado remoto antes de continuar';

  @override
  String get nasInstallBlockerCancelled =>
      'Despliegue cancelado por el usuario. Revisa los ajustes y reintenta si es necesario.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'La inspección no pudo consultar el contenedor remoto. Comprueba la conectividad o inspecciona manualmente.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'El paso de despliegue superó el tiempo límite. Comprueba la carga del servidor o la red y reintenta.';

  @override
  String get nasInstallBlockerInterrupted =>
      'El despliegue se interrumpió; revisa el estado remoto antes de continuar.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'El servicio se inició pero la comprobación de salud HTTP agotó el tiempo de espera. Revisa los registros o el puerto.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Falló la conciliación. Verifica el estado del contenedor manualmente o inicia un nuevo despliegue.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'El estado del contenedor remoto es incierto. Se requiere inspección y conciliación manual.';

  @override
  String get nasInstallBlockerServiceExited =>
      'El proceso del contenedor terminó prematuramente. Revisa los registros en busca de errores de configuración o permisos.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'No se pudieron escribir los archivos de despliegue en el servidor de destino. Comprueba el espacio y permisos.';

  @override
  String get nasInstallBlockerPlanStale =>
      'El plan de despliegue está desactualizado. Vuelve a ejecutar las comprobaciones previas.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'El contenedor existente no fue creado por esta app. Inspecciona manualmente para evitar sobrescribirlo.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Se requiere una conexión SSH activa al servidor de destino.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'El estado remoto difiere del estado local. Concilia antes de continuar.';

  @override
  String get nasInstallBlockerFailed =>
      'El despliegue encontró un error. Revisa los registros y reintenta.';

  @override
  String get nasInstallBlockerBusy =>
      'Ya hay una tarea de instalación en progreso. Comprueba el progreso de la tarea actual.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Error al persistir el estado de despliegue. Comprueba el espacio local y los permisos de archivos.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'El resultado del comando remoto es desconocido. Ejecuta una inspección de solo lectura en lugar de reintentar directamente.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Falló la comprobación del entorno previo al despliegue. Resuelve los bloqueadores antes de continuar.';

  @override
  String serverDeleteFailed(String error) {
    return 'Error al eliminar el servidor: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Modo de agente';

  @override
  String get chatRunSettingsApprovalPolicy => 'Política de aprobación local';

  @override
  String get chatRunSettingsExtraSettings => 'Ajustes adicionales';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Permite automáticamente operaciones seguras conocidas; pregunta cuando la seguridad no se pueda determinar.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Error al aplicar ajustes de ejecución: $error';
  }

  @override
  String get chatMessageCopied => 'Mensaje copiado al portapapeles';

  @override
  String get copy => 'Copiar';

  @override
  String get rename => 'Renombrar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get sessionTitle => 'Título de la sesión';

  @override
  String get chatSettingsStale => 'Desactualizado';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Ajustes disponibles tras el primer mensaje';

  @override
  String get chatReimportAsCopy => 'Reimportar como copia';

  @override
  String get chatSearchCommandsHint => 'Buscar comandos o habilidades...';

  @override
  String get chatCommandsTab => 'Comandos';

  @override
  String get chatSkillsTab => 'Habilidades';

  @override
  String get chatAccountAndQuotaTitle => 'Cuenta y cuota';

  @override
  String get chatAccountSectionTitle => 'Cuenta';

  @override
  String get chatAccountNotProvided =>
      'No se han reportado detalles de la cuenta';

  @override
  String get chatAccountKind => 'Tipo';

  @override
  String get chatAccountLabel => 'Etiqueta';

  @override
  String get chatAccountPlan => 'Plan';

  @override
  String get chatAccountEmail => 'Correo electrónico';

  @override
  String get chatAccountUpdatedAt => 'Actualizado';

  @override
  String get chatQuotaSectionTitle => 'Cuota y estado';

  @override
  String get chatStatusSourceNote =>
      'Salida sin procesar de /status del agente';

  @override
  String get chatStatusNotQueried => 'Estado no consultado aún';

  @override
  String get chatQueryStatusAction => 'Consultar estado (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Consulta de estado no disponible en la sesión actual';

  @override
  String get chatAttachmentMissing => 'Archivo adjunto ausente o no disponible';

  @override
  String get chatViewModeList => 'Lista';

  @override
  String get chatViewModeCards => 'Tarjetas';

  @override
  String get chatViewModeGrid => 'Imágenes';

  @override
  String get chatRemoteBrowserTitle => 'Espacio de trabajo remoto';

  @override
  String get chatSelectDirectory => 'Seleccionar directorio';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Adjuntar seleccionados ($count)';
  }

  @override
  String get chatNoFilesFound => 'No se encontraron archivos';

  @override
  String get chatRootDirectory => 'Raíz';

  @override
  String get chatSelectThisDirectory => 'Usar este directorio';

  @override
  String get chatAgentVersion => 'Versión del agente';

  @override
  String get chatParentDirectory => 'Directorio superior';

  @override
  String get chatSearchFilesHint => 'Buscar archivos...';

  @override
  String get chatCommandsEmpty =>
      'No hay comandos slash proporcionados por el agente';

  @override
  String get chatSkillsEmpty =>
      'No hay habilidades proporcionadas por el agente';

  @override
  String get chatFileUnsupported => 'Tipo de archivo no admitido para adjuntar';

  @override
  String get chatStatusNotProvided =>
      'Consulta de estado no admitida por el agente';

  @override
  String get sessionRecoveryReconnecting => 'Reconectando...';

  @override
  String get sessionRecoverySyncing => 'Sincronizando salida...';

  @override
  String get sessionRecoveryIncomplete =>
      'Algunas salidas no se pudieron recuperar';

  @override
  String get sessionRecoveryFailed => 'Recuperación fallida';

  @override
  String get sessionRecoveryRetry => 'Reintentar';

  @override
  String get dashboardUpdatesPaused => 'Actualizaciones pausadas';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'El catálogo de modelos CLI no está disponible. Los modelos pueden estar en caché o limitados por la versión del CLI; también puedes introducir un nombre manualmente.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Los modelos se consultan desde el servidor de aplicaciones CLI usando tu inicio de sesión CLI. El catálogo puede estar en caché o limitado; puedes actualizarlo o usar entrada manual.';

  @override
  String get chatModelCatalogError403 =>
      'Acceso denegado a la consulta de modelos CLI (403). Comprueba el inicio de sesión y la conectividad, o introduce el nombre manualmente.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Error del catálogo de modelos: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Autorizar catálogo de modelos';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Autorizar catálogo de modelos';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Esto iniciará la autorización en el navegador para el catálogo de modelos en el host/contenedor de destino. Tu inicio de sesión de Codex y sesiones de terminal se mantendrán intactos. ¿Continuar?';

  @override
  String get chatModelAuthorizing => 'Autorizando mediante navegador...';

  @override
  String get chatModelAuthorizeCancel => 'Cancelar autorización';

  @override
  String get chatCommandsFirstTurnNote =>
      'Los comandos slash serán anunciados por el agente una vez que la sesión esté inicializada, sin requerir una conversación previa ordinaria; los borradores no crean sesiones automáticamente.';

  @override
  String get chatCommandsClientActionRunSettings => 'Ajustes de ejecución';

  @override
  String get chatCommandsClientActionWorkingDirectory =>
      'Directorio de trabajo';

  @override
  String get chatCommandsClientActionsSection => 'Acciones locales';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Lista de modelos';

  @override
  String get chatRunSettingsModelSourceCustom => 'Entrada manual';

  @override
  String get chatRunSettingsCustomModelHint => 'Introducir ID de modelo';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Los nombres de modelos manuales no están verificados y se enviarán directamente al agente, que podría rechazar modelos no compatibles.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'El nombre del modelo no puede estar vacío';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'El nombre del modelo debe tener como máximo 256 caracteres sin espacios ni caracteres de control';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Comandos verificados para la versión actual del adaptador. Al seleccionar se inserta texto en el borrador; Enviar inicializará la sesión bajo demanda y ejecutará el comando directamente.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Error al descubrir comandos o habilidades';

  @override
  String get chatAuthWaitingForBrowser =>
      'Esperando autorización en el navegador...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'No se pudo abrir el navegador externo. Vuelve a abrir o copia el enlace de autorización a continuación.';

  @override
  String get chatAuthReopenBrowser => 'Reabrir navegador';

  @override
  String get chatAuthCopyLink => 'Copiar enlace';

  @override
  String get chatAuthManualCallback => 'Devolución manual';

  @override
  String get chatAuthManualCallbackTitle =>
      'Introducir URL de retorno de autorización';

  @override
  String get chatAuthManualCallbackDesc =>
      'Pega la URL de redireccionamiento completa (http://127.0.0.1:PORT/...?code=...&state=...) del navegador para completar la autorización. No se aceptan códigos sin procesar.';

  @override
  String get chatAuthCallbackInputLabel => 'URL de retorno';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Formato de URL de retorno no válido o entrega fallida';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP requiere autorización oficial de la cuenta, independiente del inicio de sesión CLI del terminal.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Este turno requiere autenticación ACP. Reconéctate y solicita autorización para continuar.';

  @override
  String get chatRequestAuthButton => 'Solicitar autenticación';

  @override
  String get agentActionAcpLogin => 'Iniciar sesión ACP';

  @override
  String get agentActionCliLogin => 'Iniciar sesión CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Faltan credenciales ACP (se requiere iniciar sesión en ACP)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Credenciales ACP guardadas (no verificadas)';

  @override
  String get chatAuthMethodUnavailable =>
      'El método de autenticación seleccionado no está disponible.';

  @override
  String get chatAuthConnectionExpired =>
      'La conexión de autenticación ha caducado. Inténtalo de nuevo.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Error al entregar el retorno de autorización al servidor.';

  @override
  String get agentTargetChangedNotice =>
      'El servidor de destino ha cambiado. Vuelve a abrir la gestión de agentes en el servidor actual.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Comprobación de autenticación de Antigravity no disponible';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Respuesta de comprobación de autenticación de Antigravity no válida';

  @override
  String get sftpDownloadDisconnected => 'Descarga desconectada';

  @override
  String get sftpDownloadPermissionDenied => 'Permiso denegado';

  @override
  String get sftpDownloadNotFound => 'Archivo remoto no encontrado';

  @override
  String get sftpDownloadTimeout => 'Tiempo de espera de descarga agotado';

  @override
  String get sftpDownloadLocalSpace =>
      'Espacio de almacenamiento local insuficiente';

  @override
  String get sftpDownloadLocalIo =>
      'Error al escribir en el almacenamiento local';

  @override
  String get sftpDownloadIncomplete => 'Descarga incompleta';

  @override
  String get transferStatusWaitingConnection => 'Esperando conexión';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Error al iniciar el receptor local de retorno de autorización. Vuelve a intentar la autenticación.';

  @override
  String get settingsExperimentalFeatures => 'Funciones experimentales';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Prueba funciones preliminares y experimentales';

  @override
  String get settingsExperimentalCliChatTitle => 'Chat inteligente CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Habilitar interfaz de chat dedicada a agentes de línea de comandos';

  @override
  String get settingsExperimentalDialogClose => 'Cerrar';

  @override
  String get settingsExperimentalSaveFailed =>
      'Error al actualizar los ajustes de funciones experimentales';

  @override
  String get settingsExperimentalNasTitle => 'Medios NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'Habilitar biblioteca de medios, escaneo de carpetas y reproducción de audio';

  @override
  String get settingsLanguageSaveFailed =>
      'Error al actualizar los ajustes de idioma';

  @override
  String get settingsAboutPrivacy => 'Acerca de y privacidad';

  @override
  String get privacyPolicyTitle => 'Política de privacidad';

  @override
  String get privacyPolicyDescription => 'Uso de datos y tus opciones';

  @override
  String get privacyContactTitle => 'Contacto de privacidad';

  @override
  String get privacyCopyEmail => 'Copiar correo electrónico';

  @override
  String get privacyEmailCopied => 'Correo electrónico copiado';

  @override
  String get privacyOnlineVersion => 'Ver versión en línea';

  @override
  String get privacyLinkFailed =>
      'No se puede abrir el enlace. Puedes copiar el correo electrónico.';

  @override
  String get privacyLoadFailed =>
      'No se puede cargar la política. Consulta la versión en línea.';

  @override
  String get privacyVersionUnknown => 'Versión no disponible';

  @override
  String get aboutWebsite => 'Sitio web oficial';

  @override
  String get aboutLicense => 'Licencia de la aplicación';

  @override
  String get aboutThirdPartyLicenses =>
      'Licencias de código abierto de terceros';

  @override
  String get aboutLicenseSummary =>
      'El contenido original de Valhalla se licencia para uso no comercial bajo PolyForm Noncommercial 1.0.0. El uso comercial fuera de los permisos de la licencia requiere una autorización adicional. Los componentes de terceros conservan sus propias licencias. Las condiciones completas siguientes rigen el uso.';

  @override
  String get aboutCopyrightNotice => 'Avisos de derechos de autor';

  @override
  String get aboutLicenseLoadFailed =>
      'No se pudo cargar la licencia. Contacte con norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'No se pudo abrir el enlace. Abra https://norns.cc.cd en su navegador.';

  @override
  String get downloadReveal => 'Mostrar en el Explorador de archivos';

  @override
  String get downloadRevealFailed =>
      'No se pudo abrir la carpeta de descargas. Puede haberse movido o eliminado.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count claves de hosts de confianza';
  }

  @override
  String get settingsKnownHostsEmpty =>
      'No se encontraron claves de hosts de confianza';

  @override
  String get settingsKnownHostsDialogTitle => 'Claves de hosts conocidos';

  @override
  String get settingsHostKeyRevoke => 'Revocar';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'Revocar clave de host';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return '¿Revocar la clave de host para $hostPort? Se desconectarán las conexiones SSH activas a este host y deberá volver a verificar la clave en la próxima conexión.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Huella de la clave copiada al portapapeles';

  @override
  String get settingsHostKeyRevoked => 'Clave de host revocada';

  @override
  String get settingsClearStorageSubtitle =>
      'Borrar contraseñas y claves privadas guardadas para los servidores seleccionados';

  @override
  String get settingsClearStorageDialogTitle =>
      'Restablecer credenciales de servidor';

  @override
  String get settingsClearStorageDesc =>
      'Seleccione servidores para borrar contraseñas SSH y claves privadas del almacenamiento seguro local. Las configuraciones de servidor y los historiales de chat no se eliminarán.';

  @override
  String get settingsClearStorageNoServers => 'No hay servidores disponibles';

  @override
  String get settingsClearStorageSelectAll => 'Seleccionar todo';

  @override
  String get settingsClearStorageDeselectAll => 'Deseleccionar todo';

  @override
  String get settingsClearStorageConfirmTitle =>
      'Confirmar restablecimiento de credenciales';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return '¿Está seguro de que desea borrar las credenciales de $count servidor(es) seleccionado(s)? Las conexiones activas se desconectarán de inmediato.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Borrar seleccionados ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Credenciales de los servidores seleccionados borradas con éxito';

  @override
  String get settingsClearStorageError =>
      'Error al borrar las credenciales de algunos servidores. Inténtelo de nuevo.';

  @override
  String get settingsDefaultAcpAgent => 'Agente ACP predeterminado';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Agente predeterminado para el chat ACP en este servidor';

  @override
  String get settingsDefaultCliAgent => 'Agente CLI predeterminado';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Agente predeterminado para el chat CLI en este servidor';

  @override
  String get settingsDefaultAgentAutomatic => 'Automático (primer disponible)';

  @override
  String get settingsDefaultAgentSelectTitle =>
      'Seleccionar agente predeterminado';

  @override
  String get settingsDefaultAgentNoServer => 'Ningún servidor seleccionado';

  @override
  String get settingsDefaultAgentNoAgents =>
      'No hay agentes configurados para este servidor';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Error al actualizar la configuración del agente predeterminado';

  @override
  String get dockerViewGroupContainers => 'Contenedores';

  @override
  String get dockerViewGroupProjects => 'Proyectos Compose';

  @override
  String get dockerProjectActionStart => 'Iniciar proyecto';

  @override
  String get dockerProjectActionStop => 'Detener proyecto';

  @override
  String get dockerProjectActionRestart => 'Reiniciar proyecto';

  @override
  String get dockerProjectConfirmStopTitle => 'Detener proyecto Compose';

  @override
  String get dockerProjectConfirmRestartTitle => 'Reiniciar proyecto Compose';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return '¿Está seguro de que desea $action el proyecto \"$project\"? Se afectarán los siguientes $count contenedores:';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'Proyecto \"$project\" $action completado con éxito';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'Proyecto \"$project\" $action completado con $failedCount error(es)';
  }

  @override
  String get dockerNoProjects =>
      'No se encontraron proyectos de Docker Compose';

  @override
  String get dockerMountsTitle => 'Puntos de montaje';

  @override
  String get dockerMountReadOnly => 'Solo lectura';

  @override
  String get dockerMountReadWrite => 'Lectura/Escritura';

  @override
  String get sftpBookmarksTitle => 'Marcadores de directorio';

  @override
  String get sftpNoBookmarks => 'No hay marcadores guardados todavía';

  @override
  String get sftpAddBookmark => 'Añadir a marcadores';

  @override
  String get sftpRemoveBookmark => 'Eliminar marcador';

  @override
  String get sftpCurrentDirectory => 'Directorio actual';

  @override
  String get sftpSelectMode => 'Selección múltiple';

  @override
  String sftpSelectedCount(int count) {
    return '$count seleccionado(s)';
  }

  @override
  String get sftpSelectAll => 'Seleccionar todo';

  @override
  String get sftpDeselectAll => 'Deseleccionar todo';

  @override
  String get sftpBatchCopy => 'Copiar';

  @override
  String get sftpBatchMove => 'Mover';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Confirmar eliminación por lotes';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return '¿Seguro que desea eliminar los $count elementos seleccionados?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Aviso: Los directorios no vacíos no se pueden eliminar recursivamente y se omitirán.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Confirmar copia por lotes';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return '¿Copiar $count elementos seleccionados a \"$directory\"?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Confirmar movimiento por lotes';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return '¿Mover $count elementos seleccionados a \"$directory\"?';
  }

  @override
  String get sftpBatchResultsTitle => 'Resultados de la operación por lotes';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Omitido (el destino ya existe o no es compatible)';

  @override
  String get sftpBatchTargetRestricted =>
      'No se puede seleccionar el directorio actual ni sus descendientes como destino';

  @override
  String get sftpSelectCurrentDir => 'Elegir este directorio';

  @override
  String sftpBatchOperationSuccess(int count) {
    return '$count elementos procesados correctamente';
  }

  @override
  String get configMigrationTitle =>
      'Copia de seguridad y migración de configuración';

  @override
  String get configExportTitle => 'Exportar configuración';

  @override
  String get configExportSubtitle =>
      'Exportar servidores, agentes, comandos, marcadores y preferencias a JSON';

  @override
  String get configExportDialogTitle => 'Exportar configuración de Valhalla';

  @override
  String get configExportSuccess => 'Configuración exportada correctamente';

  @override
  String configExportError(String error) {
    return 'Error al exportar configuración: $error';
  }

  @override
  String get configImportTitle => 'Importar configuración';

  @override
  String get configImportSubtitle =>
      'Importar configuración desde un archivo JSON de copia de seguridad';

  @override
  String get configBackupTooLarge =>
      'El archivo de copia de seguridad supera el tamaño máximo permitido (8 MB)';

  @override
  String get configImportPreviewTitle =>
      'Vista previa de la importación de configuración';

  @override
  String get configImportPreviewDesc =>
      'Revise el contenido antes de importar. Los elementos existentes se conservarán y combinarán.';

  @override
  String configImportServersCount(int count) {
    return 'Servidores ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'Agentes ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'Comandos rápidos ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'Marcadores ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'Los comandos personalizados pueden contener scripts confidenciales o credenciales incrustadas. No se transfieren contraseñas, claves privadas ni huellas de host de confianza.';

  @override
  String get configImportGlobalPreferences =>
      'Importar preferencias globales de la aplicación';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Sobrescribe la configuración actual de tema, terminal y navegación';

  @override
  String get configImportConfirmAction => 'Confirmar importación';

  @override
  String get configImportSuccess => 'Configuración importada correctamente';

  @override
  String get configImportErrorTitle =>
      'Copia de seguridad de configuración no válida';

  @override
  String configImportErrorGeneric(String error) {
    return 'Error al importar configuración: $error';
  }

  @override
  String get configImportErrorCopyDetails => 'Copiar detalles de diagnóstico';

  @override
  String get configImportErrorCopied =>
      'Detalles de diagnóstico copiados al portapapeles';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Formato o versión de copia de seguridad no compatible';

  @override
  String get configImportErrorMalformed =>
      'JSON de configuración con formato incorrecto o dañado';

  @override
  String get aboutRepository => 'Repositorio de GitHub';

  @override
  String get updateCheckTitle => 'Buscar actualizaciones';

  @override
  String get updateChecking => 'Buscando actualizaciones...';

  @override
  String get updateCheckNow => 'Buscar ahora';

  @override
  String get updateUpToDate => 'Valhalla está actualizado';

  @override
  String updateInstalledVersion(String version) {
    return 'Instalado: v$version';
  }

  @override
  String updateAvailableBadge(String version) {
    return 'Nueva versión disponible: v$version';
  }

  @override
  String get updateViewUpdate => 'Ver actualización';

  @override
  String updateLastChecked(String time) {
    return 'Última comprobación: $time';
  }

  @override
  String get updateNeverChecked => 'Nunca comprobado';

  @override
  String get updateAutoCheckTitle =>
      'Comprobación automática de actualizaciones';

  @override
  String get updateAutoCheckSubtitle =>
      'Buscar actualizaciones diariamente cuando la aplicación esté activa';

  @override
  String get updateAutoCheckSaveFailed =>
      'Error al guardar la configuración de actualización automática';

  @override
  String get updateDialogTitle => 'Actualización de software';

  @override
  String updateCurrentVersion(String version) {
    return 'Actual: $version';
  }

  @override
  String updateTargetVersion(String version) {
    return 'Última: v$version';
  }

  @override
  String updateBuildNumber(String build) {
    return 'Compilación $build';
  }

  @override
  String updateCommit(String commit) {
    return 'Hash del commit: $commit';
  }

  @override
  String get updateArtifactDetails => 'Paquete de instalación';

  @override
  String updateArtifactName(String name) {
    return 'Archivo: $name';
  }

  @override
  String updateArtifactSize(String size) {
    return 'Tamaño: $size';
  }

  @override
  String updateArtifactHash(String hash) {
    return 'Hash SHA-256: $hash';
  }

  @override
  String get updateCopyHash => 'Copiar hash SHA-256';

  @override
  String get updateHashCopied => 'Hash SHA-256 copiado al portapapeles';

  @override
  String get updateCopyCommit => 'Copiar hash del commit';

  @override
  String get updateCommitCopied => 'Hash del commit copiado al portapapeles';

  @override
  String get updateReleaseNotes => 'Notas de la versión';

  @override
  String get updateNoReleaseNotes =>
      'No se proporcionaron notas de la versión.';

  @override
  String get updateNoArtifactForPlatform =>
      'No hay ningún paquete de instalación directa disponible para esta plataforma/arquitectura.';

  @override
  String get updateOpenReleasePage => 'Abrir versiones en GitHub';

  @override
  String get updateDownload => 'Descargar actualización';

  @override
  String updateDownloading(String progress) {
    return 'Descargando... $progress%';
  }

  @override
  String get updatePause => 'Pausar';

  @override
  String get updateResume => 'Reanudar';

  @override
  String get updateRetry => 'Reintentar';

  @override
  String get updateDownloadPaused => 'Descarga pausada';

  @override
  String get updateDownloadCompleted => 'Descarga completada y verificada';

  @override
  String get updateInstall => 'Instalar actualización';

  @override
  String get updateRevealInFolder => 'Mostrar en carpeta';

  @override
  String get updateOpenFolder => 'Abrir ubicación de descarga';

  @override
  String get updateRetryInstall => 'Reintentar instalación';

  @override
  String get updateDesktopInstructions =>
      'Extraiga el archivo descargado y reemplace la aplicación cuando esté cerrada. Nunca sobrescriba el programa en ejecución.';

  @override
  String get updateCopyErrorDetails => 'Copiar detalles del error';

  @override
  String get updateErrorCopied => 'Detalles del error copiados al portapapeles';

  @override
  String get updateErrorRateLimited =>
      'Límite de solicitudes de la API de GitHub excedido. Vuelva a intentarlo más tarde.';

  @override
  String get updateErrorNetwork =>
      'Error de conexión de red. Compruebe su conexión a Internet.';

  @override
  String get updateErrorManifest =>
      'El manifiesto de actualización no es válido o faltan metadatos necesarios.';

  @override
  String get updateErrorIntegrity =>
      'Error en la comprobación de integridad de la descarga. La suma de comprobación no coincide.';

  @override
  String get updateErrorSignatureMismatch =>
      'Error de firma de instalación: el paquete está firmado con una clave diferente a esta aplicación. No se pueden sobrescribir firmas diferentes. Para evitar la pérdida de datos, nunca desinstale ni borre los datos de la aplicación.';

  @override
  String get updateErrorPermissionRequired =>
      'Se requiere permiso de instalación. Permita la instalación de aplicaciones desconocidas en los ajustes del sistema y pulse Reintentar instalación.';

  @override
  String get updateErrorPermission =>
      'Permiso de almacenamiento o del sistema denegado.';

  @override
  String get updateErrorPackageInvalid =>
      'La ruta o la identidad del paquete no son válidas.';

  @override
  String get updateErrorStoreInstall =>
      'Esta aplicación se instaló desde una tienda de aplicaciones. Actualícela a través de la tienda.';

  @override
  String get updateErrorPlatform => 'No se pudo abrir o iniciar el instalador.';

  @override
  String get updateErrorGeneric =>
      'Error en la operación de actualización. Inténtelo de nuevo o consulte los lanzamientos en GitHub.';
}
