// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get nasPlaylistLoadFailed =>
      'As listas de reprodução estão temporariamente indisponíveis. A lista de arquivos salva continua disponível. Atualize para tentar novamente.';

  @override
  String get nasAllLibraries => 'Todas as bibliotecas';

  @override
  String get nasDiagnosticsTitle => 'Diagnóstico da fonte de mídia';

  @override
  String get nasDiagnosticsConnection => 'Conexão';

  @override
  String get nasDiagnosticsScan => 'Varredura da biblioteca';

  @override
  String get nasDiagnosticsLastSuccess => 'Última conexão bem-sucedida';

  @override
  String get nasDiagnosticsCredentials => 'Verificando credenciais salvas';

  @override
  String get nasDiagnosticsFinalizing => 'Finalizando o índice';

  @override
  String get nasDiagnosticsNotChecked => 'Não verificado';

  @override
  String get nasCacheLegacy => 'Miniaturas antigas (sem fonte atribuída)';

  @override
  String get nasCacheGlobalBudget => 'Limite de miniaturas (todas as fontes)';

  @override
  String get nasCacheNoSource =>
      'Selecione uma fonte de mídia para gerenciar o cache.';

  @override
  String get nasOfflineRecordedHint =>
      'Bytes de download registrados, não o uso de disco medido. Limpar as miniaturas não remove arquivos offline.';

  @override
  String nasCacheClearConfirm(String scope) {
    return 'Limpar as miniaturas de $scope? Os arquivos offline e as mídias remotas serão mantidos.';
  }

  @override
  String nasOfflineRecordedBytes(String size) {
    return 'Downloads registrados: $size';
  }

  @override
  String get nasDeployDockerTitle => 'Aplicativo Docker';

  @override
  String get nasDeployDockerDesc =>
      'Abra o aplicativo oficial do Jellyfin na Central de aplicativos. Revise a configuração antes de instalar.';

  @override
  String get nasDeployNativeDesc =>
      'Instale o Jellyfin diretamente neste servidor com seus pacotes oficiais. As instalações existentes não serão alteradas.';

  @override
  String get nasDeployEnableAppCenter =>
      'Ativar a Central de aplicativos experimental para continuar? A disposição do menu não mudará.';

  @override
  String get nasDeployCatalogUnavailable =>
      'O aplicativo oficial do Jellyfin não está disponível. Verifique se a fonte oficial está ativada e tente novamente.';

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle =>
      'Gerenciamento de servidores e agentes nativo com IA';

  @override
  String get navAiChat => 'Chat IA';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'Arquivos SFTP';

  @override
  String get navCommands => 'Comandos';

  @override
  String get navSettings => 'Configurações';

  @override
  String get serverConnected => 'Conectado';

  @override
  String get serverOnline => 'Online';

  @override
  String get serverOffline => 'Offline';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get quickDisconnect => 'Desconexão rápida';

  @override
  String get newSession => 'Nova sessão';

  @override
  String get historySessions => 'Histórico de sessões';

  @override
  String get switchAgent => 'Trocar agente';

  @override
  String get agentClaudeCode => 'Claude Code';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agente ativo';

  @override
  String get inputPromptHint =>
      'Peça ao agente para diagnosticar, executar ferramentas ou criar comandos... (Enter para enviar)';

  @override
  String get thinking => 'Pensando';

  @override
  String get executionPlan => 'Plano de execução';

  @override
  String get toolCall => 'Chamada de ferramenta';

  @override
  String get toolStatusPending => 'Pendente';

  @override
  String get toolStatusRunning => 'Executando...';

  @override
  String get toolStatusCompleted => 'Concluído';

  @override
  String get toolStatusFailed => 'Falhou';

  @override
  String get permissionRequired => 'Permissão necessária';

  @override
  String get permissionDescription =>
      'O agente deseja executar este comando no servidor:';

  @override
  String get permissionReject => 'Rejeitar';

  @override
  String get permissionAllowOnce => 'Permitir uma vez';

  @override
  String get permissionAllowAlways => 'Permitir sempre';

  @override
  String get quickTroubleshootCpu => 'Diagnosticar alto uso de CPU';

  @override
  String get quickDockerHealth => 'Verificação de integridade do Docker';

  @override
  String get quickCleanCache => 'Limpar cache do sistema';

  @override
  String get quickNginxLogs => 'Verificar logs de erro do Nginx';

  @override
  String get terminalNewTab => 'Nova aba';

  @override
  String get terminalCloseTab => 'Fechar aba';

  @override
  String get terminalClear => 'Limpar';

  @override
  String get terminalQuickCmds => 'Paleta de comandos';

  @override
  String get terminalPaste => 'Colar';

  @override
  String get terminalConfirmPasteTitle => 'Confirmar colagem';

  @override
  String terminalConfirmPasteMessage(int count) {
    return 'Colando $count linhas de texto no terminal. Continuar?';
  }

  @override
  String get settingsTerminalPinnedKeys => 'Teclas da barra do terminal';

  @override
  String get settingsTerminalPinnedKeysSubtitle =>
      'Personalizar e reordenar as teclas da barra';

  @override
  String get terminalResetPinnedKeys => 'Restaurar padrão';

  @override
  String get terminalToggleKeyboard => 'Alternar teclado';

  @override
  String get terminalKeyArrows => 'Teclas de seta';

  @override
  String get terminalDirectionPad => 'Painel direcional';

  @override
  String get terminalCloseDirectionPad => 'Fechar painel direcional';

  @override
  String get terminalDirectionPadModeFixed => 'Fixo à direita';

  @override
  String get terminalDirectionPadModeFlow => 'Rolar com as teclas';

  @override
  String get terminalDirectionPadModeHidden => 'Oculto';

  @override
  String get terminalDirectionKeyColor => 'Cor das teclas de direção';

  @override
  String get terminalDirectionKeyColorDefault => 'Seguir o tema';

  @override
  String get terminalDirectionKeyColorReset => 'Redefinir para o tema';

  @override
  String get terminalAccessorySaveFailed =>
      'Falha ao salvar as configurações da barra de acessórios';

  @override
  String get terminalDirectionKeyNormal => 'Normal';

  @override
  String get terminalDirectionKeyPressed => 'Pressionado';

  @override
  String terminalPinnedKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fixadas ($count)',
      one: 'Fixadas ($count)',
    );
    return '$_temp0';
  }

  @override
  String get terminalNoPinnedKeys => 'Nenhuma tecla fixada';

  @override
  String terminalAvailableKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Disponíveis para adicionar ($count)',
      one: 'Disponíveis para adicionar ($count)',
    );
    return '$_temp0';
  }

  @override
  String get sftpCurrentPath => 'Caminho atual';

  @override
  String get sftpUpload => 'Enviar';

  @override
  String get sftpNewFolder => 'Nova pasta';

  @override
  String get sftpNewFile => 'Novo arquivo';

  @override
  String get sftpRefresh => 'Atualizar';

  @override
  String get sftpSearchHint => 'Pesquisar arquivos ou pastas...';

  @override
  String get sftpEmpty => 'O diretório está vazio';

  @override
  String get sftpFileName => 'Nome';

  @override
  String get sftpFileSize => 'Tamanho';

  @override
  String get sftpFilePerm => 'Permissões';

  @override
  String get sftpFileModified => 'Modificado';

  @override
  String get cmdCategoryDocker => 'PILHA DE CONTÊINERES DOCKER';

  @override
  String get cmdCategorySystem => 'MANUTENÇÃO DO SISTEMA';

  @override
  String get cmdCategoryNetwork => 'REDE E PORTAS';

  @override
  String get cmdExecute => 'Executar';

  @override
  String get cmdDangerous => 'Comando perigoso';

  @override
  String get cmdDangerousWarning =>
      'Esta operação é irreversível e pode causar interrupção do serviço. Tem certeza de que deseja continuar?';

  @override
  String get cmdParamRequired => 'Parâmetro obrigatório';

  @override
  String get cmdConfirm => 'Confirmar e executar';

  @override
  String get cmdCancel => 'Cancelar';

  @override
  String get settingsAppearance => 'Aparência e temas';

  @override
  String get settingsThemeMode => 'Modo de tema';

  @override
  String get themeSystem => 'Seguir o sistema';

  @override
  String get themeSystemDesc => 'Adaptação automática';

  @override
  String get themeLight => 'Modo claro';

  @override
  String get themeLightDesc => 'Papel luminoso';

  @override
  String get themeDark => 'Geek escuro';

  @override
  String get themeDarkDesc => 'Grafite profundo';

  @override
  String get themeAmoled => 'Preto AMOLED';

  @override
  String get themeAmoledDesc => 'Preto absoluto 0x000000';

  @override
  String get settingsAccentColor => 'Cor de destaque do tema';

  @override
  String get accentCyberEmerald => 'Esmeralda cibernético';

  @override
  String get accentTechBlue => 'Azul tecnológico';

  @override
  String get accentElectricViolet => 'Violeta elétrico';

  @override
  String get accentCrimsonRed => 'Vermelho carmesim';

  @override
  String get accentAmberOrange => 'Laranja âmbar';

  @override
  String get settingsLanguage => 'Idioma e região';

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
  String get settingsAiOps => 'AI Ops e motor';

  @override
  String get settingsSecurity => 'Conexão e segurança';

  @override
  String get settingsKnownHosts => 'Chaves de hosts conhecidos';

  @override
  String get settingsClearStorage => 'Redefinir credenciais';

  @override
  String get settingsResetDefault => 'Restaurar padrões';

  @override
  String get settingsTerminalUseTmux => 'Modo de novo terminal manual';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Executar sessões de terminal no tmux no servidor remoto';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Afeta apenas os terminais criados manualmente. Os novos terminais automáticos sempre usam SSH padrão sem histórico recuperável; com o tmux ativado, as sessões criadas manualmente podem ser restauradas após desconexão (requer tmux remoto). A recuperação do histórico existente não é afetada.';

  @override
  String get settingsTerminalFontSize => 'Tamanho da fonte do terminal';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Ajusta o tamanho da fonte para terminais SSH e CLI';

  @override
  String get version => 'Versão';

  @override
  String get addServer => 'Adicionar servidor';

  @override
  String get editServer => 'Editar servidor';

  @override
  String get serverName => 'Nome do servidor';

  @override
  String get serverHost => 'Host / IP';

  @override
  String get serverPort => 'Porta';

  @override
  String get serverUsername => 'Nome de usuário';

  @override
  String get serverAuthType => 'Tipo de autenticação';

  @override
  String get serverPassword => 'Senha';

  @override
  String get serverPrivateKey => 'Chave privada';

  @override
  String get serverSave => 'Salvar servidor';

  @override
  String get serverDelete => 'Excluir servidor';

  @override
  String get fileEditor => 'Editor de arquivos';

  @override
  String get fileEditorSave => 'Salvar alterações';

  @override
  String get fileSavedSuccess => 'Arquivo salvo com sucesso';

  @override
  String get addCommand => 'Novo comando';

  @override
  String get commandTitle => 'Título do comando';

  @override
  String get commandContent => 'Linha de comando';

  @override
  String get commandCategory => 'Categoria';

  @override
  String get commandDescription => 'Descrição';

  @override
  String get save => 'Salvar';

  @override
  String get delete => 'Excluir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get cmdExecutionChannel => 'Canal de execução';

  @override
  String get cmdChannelTerminal => 'Direto para o terminal SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'O comando é digitado diretamente na sessão de terminal ativa';

  @override
  String get cmdChannelBackground => 'Executar em segundo plano';

  @override
  String get cmdChannelBackgroundDesc =>
      'Executa via shell de login SSH e captura a saída';

  @override
  String get cmdInjectedToTerminal => 'Comando enviado para o terminal';

  @override
  String get cmdExecutionCompleted => 'Execução concluída';

  @override
  String get cmdExecutionFailed => 'Falha na execução';

  @override
  String get cmdExecutingRemote => 'Executando comando remoto...';

  @override
  String get cmdClose => 'Fechar';

  @override
  String get navDashboard => 'Painel';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Sistema';

  @override
  String get navMore => 'Mais';

  @override
  String get dashboardTitle => 'Painel do servidor';

  @override
  String get metricsCpu => 'Uso de CPU';

  @override
  String get metricsMemory => 'Uso de memória';

  @override
  String get metricsLoadAvg => 'Carga média';

  @override
  String get metricsUptime => 'Tempo de atividade';

  @override
  String get metricsRootDisk => 'Disco raiz';

  @override
  String get quickActions => 'Navegação rápida';

  @override
  String get activeServerStatus => 'Status do servidor ativo';

  @override
  String get noServerSelected =>
      'Nenhum servidor selecionado no momento. Escolha um servidor primeiro.';

  @override
  String get serverDisconnected => 'Desconectado';

  @override
  String get serverConnecting => 'Conectando...';

  @override
  String get connectNow => 'Conectar agora';

  @override
  String get serverSpecs => 'Informações e especificações';

  @override
  String get dockerTitle => 'Contêineres Docker';

  @override
  String get dockerSearchHint => 'Pesquisar contêineres por nome ou imagem...';

  @override
  String get dockerFilterAll => 'Todos';

  @override
  String get dockerFilterRunning => 'Em execução';

  @override
  String get dockerFilterExited => 'Encerrados';

  @override
  String get dockerFilterPaused => 'Pausados';

  @override
  String get dockerActionStart => 'Iniciar';

  @override
  String get dockerActionStop => 'Parar';

  @override
  String get dockerActionRestart => 'Reiniciar';

  @override
  String get dockerActionPause => 'Pausar';

  @override
  String get dockerActionUnpause => 'Retomar';

  @override
  String get dockerActionRm => 'Remover';

  @override
  String get dockerActionLogs => 'Logs';

  @override
  String get dockerActionInspect => 'Inspecionar';

  @override
  String get dockerLogsTitle => 'Logs do contêiner';

  @override
  String get dockerInspectTitle => 'Inspeção do contêiner';

  @override
  String get dockerNoContainers => 'Nenhum contêiner encontrado no servidor';

  @override
  String get dockerEmptyRunning => 'Nenhum contêiner em execução';

  @override
  String get dockerPorts => 'Portas';

  @override
  String get dockerCreated => 'Criado';

  @override
  String get dockerImage => 'Imagem';

  @override
  String get systemTitle => 'Processos e serviços';

  @override
  String get tabProcesses => 'Processos';

  @override
  String get tabServices => 'Serviços Systemd';

  @override
  String get processSearchHint => 'Pesquisar por nome de processo ou PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEMÓRIA';

  @override
  String get processStat => 'Estado';

  @override
  String get processCommand => 'Comando';

  @override
  String get processTerminate => 'Encerrar (SIGTERM)';

  @override
  String get processForceKill => 'Forçar encerramento (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Recusa de encerramento do processo de inicialização do sistema (PID <= 1)';

  @override
  String get serviceSearchHint => 'Pesquisar serviços por nome...';

  @override
  String get serviceName => 'Serviço';

  @override
  String get serviceDescription => 'Descrição';

  @override
  String get serviceStatus => 'Status';

  @override
  String get serviceStartup => 'Inicialização';

  @override
  String get serviceActionStart => 'Iniciar';

  @override
  String get serviceActionStop => 'Parar';

  @override
  String get serviceActionRestart => 'Reiniciar';

  @override
  String get serviceActionReload => 'Recarregar';

  @override
  String get serviceActionEnable => 'Ativar';

  @override
  String get serviceActionDisable => 'Desativar';

  @override
  String get serviceNoServices => 'Nenhum serviço systemd encontrado';

  @override
  String get riskDangerTitle => 'Confirmação de operação de alto risco';

  @override
  String get riskWarningTitle => 'Confirmação de aviso de operação';

  @override
  String get riskSafeTitle => 'Confirmar ação';

  @override
  String get riskIrreversibleWarning =>
      'Esta operação é classificada como de ALTO RISCO e não pode ser desfeita. Pode causar perda de dados ou interrupção do serviço.';

  @override
  String get riskWarningDescription =>
      'Esta operação pode afetar serviços ativos ou reiniciar processos. Proceda com cuidado.';

  @override
  String get riskCommandPreview => 'Visualização do comando';

  @override
  String get riskConfirmButton => 'Confirmar e prosseguir';

  @override
  String get riskCancelButton => 'Cancelar';

  @override
  String get stateLoading => 'Carregando dados remotos...';

  @override
  String get stateOffline => 'O servidor está offline';

  @override
  String get stateOfflineDesc =>
      'Estabeleça uma conexão SSH ativa para gerenciar recursos e transmitir métricas.';

  @override
  String get stateError => 'Ocorreu um erro';

  @override
  String get stateRetry => 'Tentar novamente';

  @override
  String get stateEmpty => 'Nenhum item encontrado';

  @override
  String get inspectorTitle => 'Inspetor';

  @override
  String get inspectorClose => 'Fechar';

  @override
  String get inspectorDetails => 'Detalhes da inspeção';

  @override
  String get selectServerTitle => 'Selecionar servidor de destino';

  @override
  String get sshDisconnectedSuccess => 'Conexão SSH desconectada';

  @override
  String get trustHostFingerprintTitle =>
      'Confiar na impressão digital do host?';

  @override
  String get trustAndConnect => 'Confiar e conectar';

  @override
  String get reject => 'Rejeitar';

  @override
  String get confirmDeleteServerTitle => 'Excluir servidor';

  @override
  String get noServersFound => 'Nenhum servidor configurado ainda';

  @override
  String get agentNotReadyError =>
      'O agente selecionado não está pronto. Verifique seu ambiente e configuração.';

  @override
  String get sshDisconnectedError =>
      'SSH desconectado. Conecte-se a um servidor antes de usar o AI Ops.';

  @override
  String get noAgentAvailable => 'Nenhum agente disponível';

  @override
  String get noAgentAvailablePrompt =>
      'Nenhum agente ativo disponível. Configure ou prepare um agente primeiro.';

  @override
  String get noAgentAvailableHint =>
      'Selecione ou configure um agente disponível para conversar...';

  @override
  String get manageAgents => 'Gerenciar agentes';

  @override
  String get noReadyAgentsTitle => 'Nenhum agente pronto';

  @override
  String get noReadyAgentsDesc =>
      'Nenhum agente neste servidor passou nas verificações de ambiente.';

  @override
  String get agentStatusReady => 'Pronto';

  @override
  String get agentStatusChecking => 'Verificando...';

  @override
  String get agentStatusCliMissing => 'Instalação não detectada';

  @override
  String get agentStatusAcpMissing => 'Componente ACP não detectado';

  @override
  String get agentStatusNotLoggedIn => 'Não conectado';

  @override
  String get agentStatusError => 'Erro';

  @override
  String get agentStatusUnknown => 'Desconhecido';

  @override
  String get agentActionInstall => 'Instalar';

  @override
  String get agentActionLogin => 'Entrar';

  @override
  String get agentActionRefresh => 'Verificar status';

  @override
  String get noConfiguredAgents => 'Nenhum agente configurado neste servidor';

  @override
  String get agentManagementTitle => 'Gerenciamento de agentes';

  @override
  String get settingsAgentManagement => 'Gerenciamento de agentes';

  @override
  String get settingsAgentManagementSubtitle =>
      'Configurar, detectar e gerenciar agentes ACP para o servidor atual';

  @override
  String get addAgentButton => 'Adicionar agente';

  @override
  String get noServerSelectedForAgents =>
      'Nenhum servidor selecionado. Escolha um servidor na interface principal primeiro.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH desconectado. A detecção, instalação e login estão desativados até que a conexão seja estabelecida.';

  @override
  String get noAgentsConfiguredTitle => 'Nenhum agente configurado';

  @override
  String get noAgentsConfiguredDesc =>
      'Adicione Claude Code, Codex, OpenCode, AGY ou agentes ACP personalizados para habilitar o AI Ops neste servidor.';

  @override
  String get agentPresetLabel => 'Predefinição';

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
  String get agentNameLabel => 'Nome do agente';

  @override
  String get agentNameHint => 'ex.: Codex de produção';

  @override
  String get agentDescriptionLabel => 'Descrição';

  @override
  String get agentDescriptionHint => 'Breve descrição do agente';

  @override
  String get agentCliCommandLabel => 'Comando de teste de CLI';

  @override
  String get agentCliCommandHint => 'ex.: claude, codex';

  @override
  String get agentAcpCommandLabel => 'Comando de inicialização do ACP';

  @override
  String get agentAcpCommandHint => 'ex.: codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Comando de instalação (Opcional)';

  @override
  String get agentInstallCommandHint => 'ex.: npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Comando de verificação de login (Opcional)';

  @override
  String get agentLoginCheckCommandHint => 'ex.: codex --version';

  @override
  String get agentLoginCommandLabel => 'Comando de login (Opcional)';

  @override
  String get agentLoginCommandHint => 'ex.: codex login';

  @override
  String get agentSaveButton => 'Salvar e detectar';

  @override
  String get agentCliRequired => 'O comando de teste de CLI é obrigatório';

  @override
  String get agentAcpRequired =>
      'O comando de inicialização do ACP é obrigatório';

  @override
  String get agentNameRequired => 'O nome do agente é obrigatório';

  @override
  String get confirmInstallAgentTitle => 'Confirmar instalação do agente';

  @override
  String get confirmLoginAgentTitle => 'Confirmar login do agente';

  @override
  String get agentCommandRiskWarning =>
      'Este comando será executado diretamente no servidor remoto com os privilégios do usuário atual. Ele pode instalar pacotes ou modificar ambientes do sistema.';

  @override
  String get targetServerLabel => 'Servidor de destino';

  @override
  String get commandPreviewLabel => 'Visualização do comando';

  @override
  String get executeButton => 'Executar';

  @override
  String get deleteAgentTitle => 'Excluir agente';

  @override
  String get deleteAgentConfirm => 'Excluir';

  @override
  String get agentStatusCheckingDesc =>
      'Detectando ambiente no servidor remoto...';

  @override
  String get agentStatusInstalling => 'Instalando dependências no servidor...';

  @override
  String get agentStatusLoggingIn =>
      'Executando comando de login no servidor...';

  @override
  String get agentNoLoginCheckProvided =>
      'Nenhum comando de verificação de login especificado';

  @override
  String get agentInstallPrompt =>
      'Instalação não detectada. Instalar automaticamente agora?';

  @override
  String get agentActionAutoInstall => 'Instalação automática';

  @override
  String get agentLoginPrompt => 'Não conectado. Deseja fazer login agora?';

  @override
  String get agentActionExecuteLogin => 'Fazer login agora';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Os agentes neste servidor ainda não estão instalados ou prontos. Gerencie e conclua a configuração do ambiente.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Instale e prepare um agente para começar a conversar...';

  @override
  String get agentAcpInstallPrompt =>
      'Componente ACP não detectado. Instalar automaticamente agora?';

  @override
  String get agentInstallCommandAcpLabel =>
      'Comando de instalação do ACP (Opcional)';

  @override
  String get agentInstallCommandAcpHint =>
      'ex.: npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Nenhum comando de instalação configurado para este agente';

  @override
  String get agentInstallLogTitle => 'Saída da instalação';

  @override
  String get agentInstallLogEmpty => 'Aguardando saída da instalação…';

  @override
  String get agentInstallLogTruncated =>
      'Saída muito longa; mostrando as linhas mais recentes';

  @override
  String get agentAcpOptional => 'Opcional; deixe em branco para apenas CLI';

  @override
  String get acpStreaming => 'Transmitindo ACP...';

  @override
  String get aiOpsAgentTitle => 'Agente AI Ops do Valhalla';

  @override
  String get aiOpsEmptySubtitle => 'Conectado via ACP stdio pelo canal SSH';

  @override
  String get agentAuthRequiredTitle => 'Autenticação necessária';

  @override
  String get agentAuthRequiredDesc =>
      'O agente requer autenticação antes de poder processar sua solicitação.';

  @override
  String get agentAuthMethodLabel => 'Método de autenticação';

  @override
  String get agentAuthNoMethodsNotice =>
      'O agente não forneceu um método de login. Verifique sua configuração no servidor.';

  @override
  String get agentAuthProceedButton => 'Entrar';

  @override
  String get agentAuthCancelButton => 'Cancelar';

  @override
  String get agentAuthRetryHint =>
      'Após fazer login, envie sua mensagem novamente.';

  @override
  String get agentAuthRequiredError =>
      'Autenticação necessária. Faça login para continuar.';

  @override
  String get agentLoginTerminalTitle => 'Terminal de login interativo';

  @override
  String get agentLoginTerminalSubtitle =>
      'Conclua as etapas de login no terminal abaixo. Siga qualquer instrução de URL ou código exibida.';

  @override
  String get agentLoginTerminalRunning =>
      'O comando de login está sendo executado no terminal...';

  @override
  String get agentLoginTerminalDisconnected =>
      'Conexão SSH perdida. A sessão de login foi interrompida.';

  @override
  String get agentLoginTerminalRetry => 'Reconectar terminal';

  @override
  String get agentLoginTerminalFinish => 'Concluir e verificar';

  @override
  String get agentLoginTerminalClose => 'Fechar';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Se o agente exigir colar um código, pressione e segure o terminal para colar ou use a tecla COLAR.';

  @override
  String get agentLoginTerminalUrlLabel => 'URL de login detectada';

  @override
  String get agentLoginTerminalUrlCopy => 'Copiar link';

  @override
  String get agentLoginTerminalUrlCopied =>
      'URL de login copiada para a área de transferência';

  @override
  String get agentLoginTerminalCopyAll => 'Copiar toda a saída';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Saída do terminal copiada para a área de transferência';

  @override
  String get sshStatusReconnected => 'Conexão restaurada';

  @override
  String get sshStatusDisconnectedRetrying =>
      'Conexão perdida, tentando novamente';

  @override
  String get sshStatusDisconnectedManual => 'Desconectado';

  @override
  String get sshStatusHostKeyChanged =>
      'A chave do host mudou — conexão recusada';

  @override
  String get sshKeepAliveNotificationTitle =>
      'O Valhalla está mantendo suas sessões ativas';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux não encontrado — as sessões não sobreviverão a uma queda de conexão';

  @override
  String get terminalTmuxSessionRestored => 'Sessão de terminal restaurada';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Habilitar Mosh — um terminal móvel resistente a quedas de conexão e mudanças de IP';

  @override
  String get moshServerPathLabel => 'Caminho do mosh-server';

  @override
  String get moshPortRangeLabel => 'Intervalo de portas UDP';

  @override
  String get moshNewSession => 'Nova sessão Mosh';

  @override
  String get moshNotInstalled =>
      'mosh-server não encontrado no servidor remoto. Instale-o com: sudo apt install mosh (Debian/Ubuntu) ou sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Falha ao iniciar sessão Mosh: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Tempo limite de conexão do Mosh esgotado — verifique se o tráfego UDP não está bloqueado por firewall.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Sessão do agente restaurada';

  @override
  String get acpSessionRestartNotice =>
      'Sessão do agente reiniciada — contexto anterior indisponível';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Instalar tmux no servidor remoto?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'O tmux é necessário para preservar as sessões de terminal em caso de desconexão. Deseja instalá-lo agora?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Comando a ser executado:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Nenhum gerenciador de pacotes suportado foi detectado no servidor remoto. Instale o tmux manualmente.';

  @override
  String get terminalTmuxInstallFailed =>
      'Falha na instalação do tmux. Verifique as permissões do servidor e a rede.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'Conexão SSH perdida. Reconecte-se para instalar o tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Instalando tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Instalar tmux';

  @override
  String get terminalTmuxInstallSkip => 'Pular (usar shell simples)';

  @override
  String get sftpDownload => 'Baixar';

  @override
  String get sftpOpen => 'Abrir';

  @override
  String get sftpUploadFailed =>
      'Falha no envio. Verifique as permissões e tente novamente.';

  @override
  String get sftpDownloadFailed => 'Falha no download';

  @override
  String get sftpOpenUnsupported =>
      'Este formato de arquivo não pode ser aberto.';

  @override
  String get sftpReadFailed =>
      'Falha ao ler o arquivo. Verifique as permissões e tente novamente.';

  @override
  String get sftpTransferFailed =>
      'Falha na operação do arquivo. Tente novamente.';

  @override
  String get sftpDownloadSuccess => 'Baixado com sucesso';

  @override
  String get sftpUploading => 'Enviando...';

  @override
  String get sftpDownloading => 'Baixando...';

  @override
  String get sftpUpDirectory => 'Subir para pasta superior';

  @override
  String get sftpShowHiddenFiles => 'Mostrar arquivos ocultos';

  @override
  String get sftpHideHiddenFiles => 'Ocultar arquivos ocultos';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Falha ao salvar preferência de arquivos ocultos';

  @override
  String get sftpViewModeList => 'Visualização em lista';

  @override
  String get sftpViewModeGrid => 'Visualização em grade';

  @override
  String get sftpViewPreferenceSaveFailed =>
      'Falha ao salvar a preferência do modo de exibição';

  @override
  String get sftpSymlink => 'Link simbólico';

  @override
  String get sftpLinkTargetUnavailable =>
      'Destino do link simbólico corrompido ou indisponível';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Permissão negada para acessar o destino do link simbólico';

  @override
  String get settingsAutoConnect => 'Conectar automaticamente ao iniciar';

  @override
  String get settingsAutoConnectFixed => 'Servidor SSH padrão fixo';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Sempre conectar ao servidor selecionado abaixo';

  @override
  String get settingsAutoConnectLast => 'Lembrar última conexão';

  @override
  String get settingsAutoConnectLastDesc =>
      'Conectar ao último servidor conectado com sucesso';

  @override
  String get settingsAutoConnectPickServer => 'Servidor';

  @override
  String get settingsAutoConnectNoServer => 'Nenhum servidor selecionado ainda';

  @override
  String get sftpSort => 'Ordenar';

  @override
  String get sftpSortName => 'Nome';

  @override
  String get sftpSortSize => 'Tamanho';

  @override
  String get sftpSortDate => 'Data de modificação';

  @override
  String get sftpSortAscending => 'Crescente';

  @override
  String get sftpSortDescending => 'Decrescente';

  @override
  String get themeQuickSwitch => 'Tema';

  @override
  String get transferList => 'Transferências';

  @override
  String get transferEmpty => 'Nenhuma transferência ainda';

  @override
  String get transferUpload => 'Envio';

  @override
  String get transferDownload => 'Download';

  @override
  String get transferStatusQueued => 'Na fila';

  @override
  String get transferStatusRunning => 'Transferindo';

  @override
  String get transferStatusPaused => 'Pausado';

  @override
  String get transferStatusCompleted => 'Concluído';

  @override
  String get transferStatusFailed => 'Falhou';

  @override
  String get transferStatusCanceled => 'Cancelado';

  @override
  String get transferPause => 'Pausar';

  @override
  String get transferResume => 'Retomar';

  @override
  String get transferCancel => 'Cancelar';

  @override
  String get transferRemove => 'Remover';

  @override
  String get transferClearFinished => 'Limpar concluídos';

  @override
  String get transferSizeUnknown => 'Tamanho desconhecido';

  @override
  String get transferFailedUpload => 'Falha no envio';

  @override
  String get transferFailedDownload => 'Falha no download';

  @override
  String get transferPhasePreparing => 'Preparando...';

  @override
  String get transferPhaseVerifyingPartial => 'Verificando arquivo parcial...';

  @override
  String get transferPhaseVerifying => 'Verificando integridade...';

  @override
  String get stopGeneration => 'Parar';

  @override
  String get chatServerBindingRequired =>
      'Esta sessão não está vinculada a nenhum servidor. Vincule-a ao servidor atual para continuar.';

  @override
  String get chatSessionUnboundNotice =>
      'Esta sessão não está vinculada a nenhum servidor.';

  @override
  String get bindServerAction => 'Vincular servidor';

  @override
  String get bindServerDialogTitle => 'Vincular sessão ao servidor';

  @override
  String get bindServerConfirmAction => 'Confirmar vinculação';

  @override
  String get chatSessionIdentityMismatch =>
      'O servidor ou agente atual não corresponde à identidade vinculada a esta sessão. Mude para o servidor e agente correspondentes para continuar.';

  @override
  String get deleteSessionTitle => 'Excluir sessão';

  @override
  String get deleteSessionConfirmAction => 'Excluir';

  @override
  String get shareAgentSessionsTitle => 'Compartilhar sessões de agentes';

  @override
  String get shareAgentSessionsSubtitle =>
      'Compartilhar sessões entre diferentes agentes neste servidor';

  @override
  String get shareAgentSessionsEnabled =>
      'Compartilhamento de sessões de agentes ativado';

  @override
  String get shareAgentSessionsDisabled =>
      'Compartilhamento de sessões de agentes desativado';

  @override
  String get agentCliStatusInstalled => 'CLI: Instalado';

  @override
  String get agentCliStatusMissing => 'CLI: Ausente';

  @override
  String get agentCliStatusChecking => 'CLI: Verificando...';

  @override
  String get agentCliStatusUnknown => 'CLI: Desconhecido';

  @override
  String get agentCliStatusError => 'CLI: Erro';

  @override
  String get agentAcpStatusReady => 'ACP: Pronto';

  @override
  String get agentAcpStatusMissing => 'ACP: Ausente';

  @override
  String get agentAcpStatusChecking => 'ACP: Verificando...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Aguardando CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Desconhecido';

  @override
  String get agentAcpStatusError => 'ACP: Erro';

  @override
  String get agentAcpStatusNa => 'ACP: N/D';

  @override
  String get agentAuthStatusAuthenticated => 'Autenticação: Conectado';

  @override
  String get agentAuthStatusUnauthenticated => 'Autenticação: Não conectado';

  @override
  String get agentAuthStatusUnknown => 'Autenticação: Desconhecido';

  @override
  String get downloadNotificationsUnavailable =>
      'As notificações de download do sistema não estão disponíveis. Os downloads continuarão em segundo plano.';

  @override
  String get downloadOpenFailed => 'Falha ao abrir o arquivo baixado.';

  @override
  String get dockerActionPending =>
      'Já existe uma ação em andamento para este contêiner';

  @override
  String get dockerNoLogs => '(Sem logs)';

  @override
  String get serverReboot => 'Reiniciar';

  @override
  String get serverRebootDialogTitle => 'Confirmar reinicialização do servidor';

  @override
  String get serverRebootDialogMessage =>
      'Tem certeza de que deseja reiniciar este servidor? Todas as conexões ativas e serviços em segundo plano serão encerrados.';

  @override
  String get serverRebootConfirmButton => 'Reiniciar agora';

  @override
  String get serverRebootPasswordTitle => 'Senha de sudo necessária';

  @override
  String get serverRebootPasswordMessage =>
      'Privilégios de root são necessários para reiniciar o servidor. Digite a senha de sudo (usada uma vez, não salva):';

  @override
  String get serverRebootPasswordHint => 'Senha de Sudo';

  @override
  String get serverRebootSubmitting => 'Enviando comando de reinicialização...';

  @override
  String get serverRebootAccepted =>
      'Comando de reinicialização aceito; conclusão ainda não verificada. Reconecte-se quando o servidor estiver online novamente.';

  @override
  String get serverRebootVerified =>
      'A reinicialização do servidor foi verificada; o sistema está online novamente.';

  @override
  String get serverRebootUnknown =>
      'Resultado da reinicialização incerto. O comando foi despachado, mas a conclusão não pôde ser confirmada. Verifique a conexão manualmente.';

  @override
  String get serverRebootReconnect => 'Reconectar';

  @override
  String get serverRebootServerChanged =>
      'O servidor de destino mudou, reinicialização cancelada';

  @override
  String get navCliChat => 'Chat CLI';

  @override
  String get cliChatTitle => 'Sessões CLI';

  @override
  String get cliChatSubtitle =>
      'Sessões nativas de agentes CLI no servidor remoto';

  @override
  String get cliSelectAgent => 'Selecionar agente';

  @override
  String get cliNoAgentsConfigured =>
      'Nenhum agente adicionado para este servidor';

  @override
  String get cliAgentNeedsSetup =>
      'Ambiente do agente ausente ou não conectado';

  @override
  String get cliManageAgentsGuide => 'Configurar no Gerenciamento de agentes';

  @override
  String get cliNewDraft => 'Novo rascunho';

  @override
  String get cliNewDraftTooltip =>
      'Criar um rascunho em branco (a sessão é criada na primeira mensagem)';

  @override
  String get cliDeleteSessionTitle => 'Excluir histórico de sessão CLI remoto';

  @override
  String get cliDeleteSessionMessage =>
      'Isso excluirá permanentemente o histórico da sessão CLI no servidor remoto. Tem certeza de que deseja continuar?';

  @override
  String get cliDeleteConfirmButton => 'Excluir sessão';

  @override
  String get cliCannotDeleteTooltip =>
      'Exclusão de sessão remota não suportada ou desativada';

  @override
  String get cliSessionsHeader => 'Sessões';

  @override
  String get cliNoSessions => 'Nenhuma sessão CLI encontrada';

  @override
  String get cliFilterCwdHint => 'Filtrar por caminho CWD...';

  @override
  String get cliFilterCwdAction => 'Filtrar';

  @override
  String get cliClearCwdAction => 'Limpar';

  @override
  String get cliLoadMoreSessions => 'Carregar mais sessões';

  @override
  String get cliRefreshSessions => 'Atualizar';

  @override
  String get cliClaudeReadOnlyNotice =>
      'O histórico do Claude é somente leitura. Continue a conversa no terminal real.';

  @override
  String get cliContinueInTerminal => 'Continuar no terminal';

  @override
  String get cliOpenTerminal => 'Abrir terminal';

  @override
  String get cliCloseTerminal => 'Fechar terminal';

  @override
  String get cliTerminalRunning => 'Terminal CLI interativo';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Este agente não suporta sincronização estruturada do histórico. Use o terminal CLI nativo para interação e seleção de sessões.';

  @override
  String get cliInstallSdkTitle => 'Instalar SDK oficial do Claude History';

  @override
  String get cliInstallSdkMessage =>
      'O SDK oficial do Claude Code History está ausente no servidor remoto. Deseja instalá-lo agora?';

  @override
  String get cliInstallSdkAction => 'Instalar SDK oficial';

  @override
  String get cliApprovalsTitle => 'Aprovações pendentes';

  @override
  String get cliApprovalDetails => 'Detalhes';

  @override
  String get cliApprovalAllow => 'Permitir';

  @override
  String get cliApprovalDecline => 'Recusar';

  @override
  String get cliInputHint => 'Digite uma mensagem para o agente CLI...';

  @override
  String get cliSend => 'Enviar';

  @override
  String get cliStop => 'Parar';

  @override
  String get cliBusy => 'Operação em andamento, por favor aguarde...';

  @override
  String get cliDisconnected => 'SSH não está conectado';

  @override
  String get cliServerChanged => 'O servidor de destino mudou';

  @override
  String get cliTurnFailed => 'Falha na execução do turno da CLI';

  @override
  String get cliUseTerminal =>
      'Prompt interativo necessário, abra o terminal para continuar';

  @override
  String get cliDeleteFailed => 'Falha ao excluir a sessão remota';

  @override
  String get cliDeleteUnsupported =>
      'A exclusão de sessões remotas não é suportada por esta CLI';

  @override
  String get cliOperationFailed => 'Operação da CLI falhou';

  @override
  String get cliHistorySdkMissing =>
      'O SDK oficial de histórico está ausente no servidor';

  @override
  String get cliHistoryRuntimeMissing =>
      'O histórico do Claude requer Node.js/npm no servidor. Instale o Node.js manualmente; você ainda pode usar a CLI real no terminal.';

  @override
  String get cliLoginRequired =>
      'Login do agente necessário. Faça login via Gerenciamento de agentes.';

  @override
  String get cliNotInstalled =>
      'CLI do agente não instalada. Instale-a via Gerenciamento de agentes.';

  @override
  String get cliVersionUnsupported =>
      'Versão da CLI do agente não suportada. Atualize ou reinstale via Gerenciamento de agentes.';

  @override
  String get settingsNavigation => 'Navegação';

  @override
  String get settingsNavigationDesc =>
      'Configurar página inicial padrão e barra de navegação inferior';

  @override
  String get settingsStartupPage => 'Página inicial';

  @override
  String get settingsStartupPageDesc => 'Página exibida ao abrir o aplicativo';

  @override
  String get settingsBottomNav => 'Barra de navegação inferior';

  @override
  String get settingsBottomNavDesc =>
      'Selecionar seções a serem exibidas na barra inferior móvel (suporta de 0 a 9 itens)';

  @override
  String get settingsResetSuccess =>
      'Todas as configurações foram restauradas para os padrões';

  @override
  String get metricsTrendSubtitle => 'Últimos ~3 minutos (até 60 amostras)';

  @override
  String get metricsCurrent => 'Atual';

  @override
  String get metricsPeak => 'Pico';

  @override
  String get metricsValley => 'Mínimo';

  @override
  String get metricsTrendWaiting => 'Coletando dados de métricas...';

  @override
  String get metricsTrendStopped =>
      'Coleta de dados interrompida (SSH desconectado)';

  @override
  String get dockerActionTerminal => 'Terminal Exec';

  @override
  String get dockerTerminalTitle => 'Terminal do contêiner';

  @override
  String get dockerTerminalNotRunning => 'O contêiner não está em execução';

  @override
  String get setDefaultAgent => 'Definir como padrão';

  @override
  String get defaultBadge => 'Padrão';

  @override
  String get isDefaultAgent => 'Agente padrão';

  @override
  String get setAsDefaultAgent =>
      'Definir como agente padrão para este servidor';

  @override
  String get agentGroupBasic => 'Informações básicas';

  @override
  String get agentGroupCommands => 'Comandos';

  @override
  String get agentGroupAuth => 'Instalação e autenticação';

  @override
  String get agentPresetTitle => 'Modelo predefinido';

  @override
  String get resourceProcessList => 'Processos';

  @override
  String get resourceDiskScanning =>
      'Verificando diretórios raiz, isso pode levar alguns segundos...';

  @override
  String get resourceDiskScanPartial =>
      'Alguns diretórios não puderam ser verificados por permissões ou tempo limite';

  @override
  String get resourceDiskDirectories => 'Uso dos diretórios de nível superior';

  @override
  String get resourceSortCpu => 'Ordenar por CPU';

  @override
  String get resourceSortMemory => 'Ordenar por memória';

  @override
  String get resourceRss => 'Memória RSS';

  @override
  String get resourceUsed => 'Usado';

  @override
  String get resourceAvailable => 'Disponível';

  @override
  String get resourceTotal => 'Total';

  @override
  String get settingsBottomNavOrderTitle =>
      'Itens selecionados (Arraste para reordenar)';

  @override
  String get langSystem => 'Padrão do sistema';

  @override
  String get serverFieldRequired => 'Obrigatório';

  @override
  String get serverPortInvalid => 'A porta deve estar entre 1 e 65535';

  @override
  String get serverTestReachability => 'Testar acessibilidade';

  @override
  String get serverSaveFailedGeneric =>
      'Falha ao salvar o servidor. Verifique sua configuração e tente novamente.';

  @override
  String get serverViewPrivateKey => 'Ver chave privada';

  @override
  String get serverHidePrivateKey => 'Ocultar chave privada';

  @override
  String get dockerBashFallbackNotice =>
      'Bash não disponível no contêiner, alternando para Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Diretório de trabalho';

  @override
  String get cliDefaultWorkingDir => 'Padrão (/)';

  @override
  String get cliPickWorkingDirTitle => 'Selecionar diretório de trabalho';

  @override
  String get cliClearWorkingDir => 'Redefinir para o padrão';

  @override
  String get cliBrowseWorkingDir => 'Procurar';

  @override
  String get cliSelectCurrentDir => 'Selecionar este diretório';

  @override
  String get cliNavigateUp => 'Subir nível';

  @override
  String get chatSessionsTooltip => 'Sessões';

  @override
  String get hardwareSpecsTitle => 'Hardware e sistema';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Memória';

  @override
  String get hardwareDisk => 'Disco raiz';

  @override
  String get hardwareDistribution => 'SO';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Carregando especificações de hardware...';

  @override
  String get hardwareUnavailable => 'Especificações indisponíveis';

  @override
  String get hardwareUnknown => 'Desconhecido';

  @override
  String get systemInfoTitle => 'Informações do sistema';

  @override
  String get systemInfoTapHint => 'Toque para ver a arte ASCII';

  @override
  String get systemInfoHost => 'Host';

  @override
  String get serverShutdown => 'Desligar';

  @override
  String get serverShutdownDialogTitle => 'Confirmar desligamento do servidor';

  @override
  String get serverShutdownDialogMessage =>
      'Tem certeza de que deseja desligar este servidor? O sistema será completamente desligado e não poderá ser acessado remotamente até ser ligado manualmente.';

  @override
  String get serverShutdownConfirmButton => 'Desligar agora';

  @override
  String get serverShutdownSubmitting => 'Enviando comando de desligamento...';

  @override
  String get serverShutdownAccepted =>
      'Comando de desligamento aceito; conclusão do desligamento não foi verificada.';

  @override
  String get serverShutdownUnknown =>
      'Resultado do desligamento desconhecido: o comando pode ter sido enviado, mas não pôde ser confirmado. Verifique manualmente; não haverá nova tentativa automática.';

  @override
  String get serverShutdownPasswordTitle =>
      'Senha de sudo necessária para desligamento';

  @override
  String get serverShutdownPasswordMessage =>
      'Privilégios de root são necessários para desligar o servidor. Digite a senha de sudo (usada uma vez, não salva):';

  @override
  String get serverShutdownPasswordHint => 'Senha de Sudo';

  @override
  String get serverShutdownServerChanged =>
      'O servidor de destino mudou, desligamento cancelado';

  @override
  String get metricsNetwork => 'Taxa de rede';

  @override
  String get networkModalTitle => 'Detalhes das interfaces de rede';

  @override
  String get networkDownloadRate => 'Download (RX)';

  @override
  String get networkUploadRate => 'Upload (TX)';

  @override
  String get networkTotalRx => 'Total RX';

  @override
  String get networkTotalTx => 'Total TX';

  @override
  String get networkPrimary => 'Rota padrão';

  @override
  String get networkRatesEmpty => 'Nenhuma interface de rede ativa detectada';

  @override
  String get networkWaitingSecondSample => 'Aguardando segunda amostra';

  @override
  String get networkUnavailable => 'Indisponível';

  @override
  String get networkNoDefaultInterface => 'Sem rota padrão';

  @override
  String get selectThemeModeTitle => 'Selecionar modo de tema';

  @override
  String get selectLanguageTitle => 'Selecionar idioma';

  @override
  String get selectStartupPageTitle => 'Selecionar página inicial';

  @override
  String get selectAutoConnectModeTitle =>
      'Selecionar modo de conexão automática';

  @override
  String get accentColorDialogTitle => 'Personalizar cores de destaque';

  @override
  String get accentColorLightMode => 'Modo claro';

  @override
  String get accentColorDarkMode => 'Modo escuro';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Predefinições';

  @override
  String get accentColorHsvPicker => 'Círculo cromático';

  @override
  String get accentColorHexCode => 'Código Hex';

  @override
  String get accentColorPreview => 'Visualização';

  @override
  String get accentColorSampleButton => 'Botão de destaque';

  @override
  String get accentColorInvalidHex =>
      'Formato hexadecimal inválido (ex.: #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Ações rápidas do painel';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Configurar atalhos exibidos no painel. Limpar ocultará a seção de ações rápidas.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Ações rápidas ocultas (nenhum atalho selecionado)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Arraste para reordenar atalhos';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Selecionar atalhos visíveis';

  @override
  String get terminalCopySelection => 'Copiar';

  @override
  String get terminalSelectionCopied =>
      'Seleção copiada para a área de transferência';

  @override
  String get editAgent => 'Editar agente';

  @override
  String get agentExecutionTarget => 'Ambiente de execução';

  @override
  String get agentExecutionHost => 'Sistema host';

  @override
  String get agentExecutionDocker => 'Contêiner Docker';

  @override
  String get agentContainerBinding => 'Modo de vinculação do contêiner';

  @override
  String get agentContainerBindingId => 'Por ID do contêiner';

  @override
  String get agentContainerBindingName => 'Por nome do contêiner';

  @override
  String get agentContainerReference => 'Contêiner de destino';

  @override
  String get agentContainerReferenceHint =>
      'Selecione ou insira o ID ou nome do contêiner';

  @override
  String get agentContainerRequired =>
      'O contêiner de destino é obrigatório para execução no Docker';

  @override
  String get agentLoadingContainers => 'Consultando contêineres no servidor...';

  @override
  String get agentNoContainersFound =>
      'Nenhum contêiner encontrado neste servidor';

  @override
  String get agentContainerUser =>
      'Usuário de execução do contêiner (Opcional)';

  @override
  String get agentContainerUserHint => 'ex.: dev';

  @override
  String get agentContainerUserHelper =>
      'Deixe em branco para usar o usuário padrão da imagem; ex.: dev; suporta user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Selecionar usuário do contêiner';

  @override
  String get agentContainerUsersLoading => 'Carregando usuários...';

  @override
  String get agentContainerUsersEmpty => 'Nenhum usuário passwd encontrado';

  @override
  String get agentViewDiagnosticLog => 'Ver log de diagnóstico';

  @override
  String get agentDiagnosticLogCopied =>
      'Log de diagnóstico copiado para a área de transferência';

  @override
  String get agentDiagnosticLogCopy => 'Copiar';

  @override
  String get agentDiagnosticLogClose => 'Fechar';

  @override
  String get settingsCliHistoryPageSize => 'Tamanho da página do histórico CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Número de mensagens antigas carregadas por página ao rolar para cima (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Selecionar tamanho da página do histórico CLI';

  @override
  String get cliLoadingOlderMessages => 'Carregando mensagens anteriores...';

  @override
  String get chatLoadOlderMessages => 'Carregar mensagens anteriores';

  @override
  String get chatCommandsTooltip => 'Comandos';

  @override
  String get chatAttachTooltip => 'Anexar arquivo';

  @override
  String get chatAttachImage => 'Anexar imagem local';

  @override
  String get chatAttachLocalText => 'Anexar arquivo de texto local';

  @override
  String get chatAttachRemoteText => 'Anexar arquivo de texto remoto';

  @override
  String get chatAttachRemotePathTitle => 'Anexar arquivo de texto remoto';

  @override
  String get chatAttachRemotePathHint => '/caminho/para/arquivo.txt';

  @override
  String get chatAttachTooLarge => 'O arquivo excede o limite de tamanho';

  @override
  String get chatUsageAndDiagnostics => 'Uso e diagnóstico';

  @override
  String get chatWorkingDirTooltip => 'Diretório de trabalho do rascunho';

  @override
  String get chatAttachFailed => 'Falha ao anexar arquivo';

  @override
  String get chatInvalidRemotePath =>
      'Caminho remoto inválido (deve começar com /)';

  @override
  String get chatRemoteReadFailed => 'Falha ao ler arquivo remoto';

  @override
  String get chatInvalidDirPath =>
      'Caminho de diretório inválido (deve começar com /)';

  @override
  String get chatNoSubdirectories => 'Sem subdiretórios';

  @override
  String get chatUsageTitle => 'Uso de tokens e custos';

  @override
  String get chatUsageUsed => 'Tokens usados';

  @override
  String get chatUsageSize => 'Tamanho do contexto';

  @override
  String get chatUsageCost => 'Custo';

  @override
  String get chatDiagnosticsTitle => 'Log de diagnóstico';

  @override
  String get chatNoDiagnostics => 'Nenhum log de diagnóstico disponível';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Isso remove apenas o registro local no Valhalla e não excluirá o histórico nativo do agente no servidor.';

  @override
  String get chatSearchSessionsHint => 'Pesquisar sessões...';

  @override
  String get chatLoadMoreSessions => 'Carregar mais sessões';

  @override
  String get chatLoadingMoreSessions => 'Carregando mais sessões...';

  @override
  String get chatExportSession => 'Exportar sessão (Markdown)';

  @override
  String get chatExportSuccess => 'Sessão exportada com sucesso';

  @override
  String get chatExportFailed => 'Falha ao exportar sessão';

  @override
  String get chatRemoteSessions => 'Sessões remotas';

  @override
  String get chatRemoteSessionsTitle => 'Sessões de agentes remotos';

  @override
  String get chatRemoteSessionsDesc =>
      'Ver e importar histórico nativo de sessões do agente remoto';

  @override
  String get chatRemoteSessionsEmpty => 'Nenhuma sessão remota encontrada';

  @override
  String get chatRemoteImporting =>
      'Importando histórico de sessões remotas...';

  @override
  String get chatRemoteImportFailed => 'Falha ao importar sessão remota';

  @override
  String get chatStatusInterrupted => 'Interrompido';

  @override
  String get chatStatusFailed => 'Falhou';

  @override
  String get chatStatusAwaitingAuth => 'Aguardando autenticação ACP';

  @override
  String get chatShowFullOutput => 'Mostrar toda a saída';

  @override
  String get chatShowLessOutput => 'Mostrar menos';

  @override
  String get chatToolLocations => 'Caminhos afetados';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Digite o valor para $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Processo $pid encerrado';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Ação $action em $service realizada com sucesso';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Regra acionada: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Código de saída: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Conectado com sucesso a $server via SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Falha na conexão SSH: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Conectando a $host ($type) pela primeira vez.\n\nImpressão digital SHA-256:\n$fingerprint\n\nConfiar nesta impressão digital e conectar?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Digite a senha para $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Tem certeza de que deseja excluir o servidor \'$name\'? Esta ação não pode ser desfeita.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Tem certeza de que deseja excluir o agente \'$name\'? Isso remove sua configuração e estado de execução neste servidor sem afetar sessões de chat anteriores ou credenciais SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Última verificação: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Escolha como fazer login em $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Reconectando… (tentativa $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n sessão(ões) ativa(s)';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Vincular esta sessão ao servidor \\\"$serverName\\\"? Uma vez vinculada, ela ficará associada a este servidor.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Tem certeza de que deseja excluir a sessão \\\"$title\\\"? Esta ação não pode ser desfeita.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Ação $action no contêiner $name realizada com sucesso';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Ação falhou: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Servidor de destino: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Sessões de terminal: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Sessões de agentes: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Transferências ativas: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Falha na reinicialização: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Falha ao excluir sessão remota: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Tendência de $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Aviso: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Perigo: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count pontos de dados';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Uso de recursos de $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'Porta TCP $port acessível';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Falha na conexão: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Falha ao salvar o servidor: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Núcleos';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Falha no desligamento: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Interface: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Falha ao carregar contêineres: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Falha ao carregar usuários do contêiner: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Log de diagnóstico - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Falha na detecção do Docker/contêiner';

  @override
  String get chatCopiedAllMessages => 'Todas as mensagens copiadas';

  @override
  String get chatCopyAllMessages => 'Copiar todas as mensagens';

  @override
  String get cliModelAtCapacity =>
      'O modelo selecionado está com capacidade máxima. Tente outro modelo.';

  @override
  String get chatLaunchBlankDraft => 'Rascunho em branco';

  @override
  String get chatLaunchFixedSession => 'Sessão fixa';

  @override
  String get chatLaunchRememberLast => 'Lembrar última sessão';

  @override
  String get chatPermissionAskEveryTime => 'Perguntar sempre';

  @override
  String get chatPermissionAutoAllowAll => 'Permitir tudo automaticamente';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'O agente executará todas as operações sem perguntar. Continuar?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Permitir todas as operações?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Permitir operações seguras automaticamente';

  @override
  String get chatRunSettingsDefault => 'Padrão';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI interativa';

  @override
  String get chatRunSettingsModel => 'Modelo';

  @override
  String get chatRunSettingsPermissions => 'Permissões';

  @override
  String get chatRunSettingsReasoning => 'Nível de raciocínio';

  @override
  String get chatRunSettingsTitle => 'Configurações de execução';

  @override
  String get cliActionInsertCommand => 'Inserir comando';

  @override
  String get cliActionInsertFile => 'Inserir arquivo';

  @override
  String get cliActionInsertWorkdir => 'Inserir diretório de trabalho';

  @override
  String get cliComposerInsertAction => 'Inserir';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Operação da CLI falhou: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Selecionar comando';

  @override
  String get defaultAgentTitle => 'Agente padrão';

  @override
  String get insertSkills => 'Inserir habilidades';

  @override
  String get isDefaultSession => 'Sessão padrão';

  @override
  String get sessionLaunchMode => 'Modo de inicialização de sessão';

  @override
  String get setAsDefaultSession => 'Definir como sessão padrão';

  @override
  String get navNas => 'Mídia NAS';

  @override
  String get nasAddExcludePath => 'Adicionar caminho excluído';

  @override
  String get nasAddIncludePath => 'Adicionar pasta de verificação';

  @override
  String get nasCancelScan => 'Cancelar verificação';

  @override
  String get nasClearSearch => 'Limpar pesquisa';

  @override
  String get nasConfigDialogTitle => 'Configurações da biblioteca de mídia';

  @override
  String get nasConfigure => 'Configurar';

  @override
  String get nasConfigureScanDirs => 'Configurar pastas de verificação';

  @override
  String get nasCreatePlaylist => 'Criar lista de reprodução';

  @override
  String get nasEmptyConfigDesc =>
      'Adicione pelo menos uma pasta para começar a criar sua biblioteca de mídia.';

  @override
  String get nasEmptyConfigTitle => 'Nenhuma pasta de verificação configurada';

  @override
  String get nasExcludePaths => 'Pastas excluídas';

  @override
  String get nasExcludedBadge => 'Excluído';

  @override
  String get nasFilterImages => 'Fotos';

  @override
  String get nasFilterVideos => 'Vídeos';

  @override
  String get nasIncludePaths => 'Pastas de verificação';

  @override
  String nasItemCount(Object value) {
    return '$value itens';
  }

  @override
  String nasLastScan(Object value) {
    return 'Última verificação: $value';
  }

  @override
  String get nasLibrarySettings => 'Configurações da biblioteca';

  @override
  String nasMediaOpening(Object value) {
    return 'Abrindo $value…';
  }

  @override
  String get nasMiniPlayer => 'Mini reprodutor';

  @override
  String get nasNoExcludePaths => 'Nenhuma pasta excluída';

  @override
  String get nasNoFavorites => 'Ainda não há favoritos';

  @override
  String get nasNoIncludePaths => 'Nenhuma pasta de verificação';

  @override
  String get nasNoIndexDesc =>
      'Configure pastas e execute uma verificação para indexar seus arquivos de mídia.';

  @override
  String get nasNoIndexTitle => 'A biblioteca de mídia está vazia';

  @override
  String get nasNoPlaylists => 'Ainda não há listas de reprodução';

  @override
  String get nasNoSearchResults => 'Nenhuma mídia correspondente';

  @override
  String get nasNotScanned => 'Ainda não verificado';

  @override
  String get nasNowPlaying => 'Reproduzindo agora';

  @override
  String get nasOpenMethodPrompt => 'Como deseja abrir este arquivo?';

  @override
  String get nasOpenPolicyAsk => 'Perguntar sempre';

  @override
  String get nasOpenPolicyExternal => 'Abrir com outro aplicativo';

  @override
  String get nasOpenPolicyInApp => 'Abrir no aplicativo';

  @override
  String get nasOpeningPolicy => 'Método de abertura padrão';

  @override
  String get nasPlaylistName => 'Nome da lista';

  @override
  String get nasQuickStats => 'Visão geral da biblioteca';

  @override
  String get nasScan => 'Verificar agora';

  @override
  String get nasScanCancelled => 'Verificação cancelada';

  @override
  String nasScanFailed(Object value) {
    return 'Falha na verificação: $value';
  }

  @override
  String get nasScanning => 'Verificando…';

  @override
  String get nasScopeBadge => 'Escopo da verificação';

  @override
  String get nasSearchHint => 'Pesquisar mídia';

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
  String get nasTabFolders => 'Pastas';

  @override
  String get nasTabHome => 'Início';

  @override
  String get nasTabMusic => 'Música';

  @override
  String get nasTabPhotos => 'Fotos';

  @override
  String get nasTabPlaylists => 'Listas de reprodução';

  @override
  String get nasTabVideos => 'Vídeos';

  @override
  String get nasSources => 'Fontes de mídia';

  @override
  String get nasAddSource => 'Adicionar fonte de mídia';

  @override
  String get nasEditSource => 'Editar fonte de mídia';

  @override
  String get nasRemoveSource => 'Remover fonte de mídia';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Tem certeza de que deseja remover a fonte de mídia \'$name\'? Isso remove sua configuração sem excluir os arquivos remotos.';
  }

  @override
  String get nasNoSources => 'Nenhuma fonte de mídia configurada';

  @override
  String get nasNoSourcesDesc =>
      'Adicione SFTP, SMB, WebDAV, Jellyfin ou Emby para começar a navegar pelas mídias.';

  @override
  String get nasSourceType => 'Tipo de fonte';

  @override
  String get nasSourceName => 'Nome da fonte';

  @override
  String get nasProbe => 'Testar conexão';

  @override
  String get nasProbeSuccess => 'Conexão bem-sucedida';

  @override
  String get nasProbeFailed => 'Falha no teste de conexão';

  @override
  String get nasEndpoint => 'Endpoint / URL';

  @override
  String get nasRootPath => 'Caminho raiz';

  @override
  String get nasUsername => 'Nome de usuário';

  @override
  String get nasPassword => 'Senha';

  @override
  String get nasDomain => 'Domínio (opcional)';

  @override
  String get nasAuthenticate => 'Autenticar';

  @override
  String get nasAuthSuccess => 'Autenticação bem-sucedida';

  @override
  String get nasAuthFailed => 'Falha na autenticação';

  @override
  String get nasTabDownloads => 'Downloads';

  @override
  String get nasNoDownloads => 'Nenhuma tarefa de download';

  @override
  String get nasDownloadQueued => 'Na fila';

  @override
  String get nasDownloadDownloading => 'Baixando';

  @override
  String get nasDownloadCompleted => 'Concluído';

  @override
  String get nasDownloadCancelled => 'Cancelado';

  @override
  String get nasDownloadFailed => 'Falha no download';

  @override
  String get nasRetryDownload => 'Tentar novamente';

  @override
  String get nasCancelDownload => 'Cancelar';

  @override
  String get nasOpenDownloadedFile => 'Abrir arquivo';

  @override
  String get nasQueue => 'Fila de reprodução';

  @override
  String get nasNoQueue => 'A fila está vazia';

  @override
  String get nasSpeed => 'Velocidade';

  @override
  String get nasQuality => 'Qualidade';

  @override
  String get nasAudioTrack => 'Faixa de áudio';

  @override
  String get nasSubtitleTrack => 'Legendas';

  @override
  String get nasRepeatOff => 'Repetição desativada';

  @override
  String get nasRepeatAll => 'Repetir tudo';

  @override
  String get nasRepeatOne => 'Repetir uma';

  @override
  String get nasShuffle => 'Aleatório';

  @override
  String get nasCast => 'Transmitir (Cast)';

  @override
  String get nasCastUnavailable =>
      'Nenhum dispositivo de transmissão disponível';

  @override
  String get nasSlideshow => 'Apresentação de slides';

  @override
  String get nasByFolder => 'Pastas';

  @override
  String get nasByArtist => 'Artistas';

  @override
  String get nasByAlbum => 'Álbuns';

  @override
  String get nasAllTracks => 'Todas as faixas';

  @override
  String get nasPlayAll => 'Reproduzir tudo';

  @override
  String get nasPreviousPage => 'Anterior';

  @override
  String get nasNextPage => 'Próximo';

  @override
  String get nasClearScope => 'Voltar para tudo';

  @override
  String get nasRenamePlaylist => 'Renomear lista';

  @override
  String get nasRemoveFromPlaylist => 'Remover da lista';

  @override
  String get nasMoveUp => 'Mover para cima';

  @override
  String get nasMoveDown => 'Mover para baixo';

  @override
  String get nasSshServer => 'Servidor SSH';

  @override
  String get nasSelectSshServer => 'Selecionar servidor SSH salvo';

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
  String get nasCastDevices => 'Dispositivos DLNA disponíveis';

  @override
  String get nasCastDiscovering => 'Procurando dispositivos DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'Retransmitindo fluxo pelo aplicativo em primeiro plano. Mantenha o Valhalla aberto.';

  @override
  String get nasCastStop => 'Parar transmissão';

  @override
  String get nasCastVolume => 'Volume';

  @override
  String get nasCastRetry => 'Tentar busca novamente';

  @override
  String get nasInstallTitle => 'Implantar servidor de mídia NAS';

  @override
  String get nasInstallProduct => 'Produto';

  @override
  String get nasInstallMediaPath => 'Diretório de mídia (Somente leitura)';

  @override
  String get nasInstallDataRoot => 'Diretório de dados e configuração';

  @override
  String get nasInstallPort => 'Porta';

  @override
  String get nasInstallBindAddress => 'Endereço de ligação';

  @override
  String get nasInstallWebdavUser => 'Nome de usuário WebDAV';

  @override
  String get nasInstallWebdavPassword =>
      'Senha WebDAV (mínimo de 12 caracteres)';

  @override
  String get nasInstallPreparePlan => 'Revisar plano de implantação';

  @override
  String get nasInstallPlanTitle => 'Revisão técnica e confirmação';

  @override
  String get nasInstallBlockersTitle => 'Bloqueadores de implantação';

  @override
  String get nasInstallConfirmDeploy => 'Confirmar e instalar';

  @override
  String get nasInstallDeploying => 'Implantando contêiner...';

  @override
  String get nasInstallSuccess => 'Implantado com sucesso';

  @override
  String get nasInstallSuccessDesc =>
      'O serviço está em execução. Conclua a configuração inicial do servidor antes de adicioná-lo como fonte de mídia.';

  @override
  String get nasInstallContainerId => 'ID do contêiner';

  @override
  String get nasInstallEndpoint => 'Endpoint';

  @override
  String get nasUseSshTunnel => 'Usar túnel SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'Roteie o tráfego por um servidor SSH salvo (ex.: http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'O endpoint deve ser acessível a partir do servidor SSH, ex.: http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Deixe em branco para manter a senha ou token existente';

  @override
  String get nasSourceNameRequired => 'O nome da fonte é obrigatório';

  @override
  String get nasInvalidEndpoint => 'URL ou esquema de endpoint inválido';

  @override
  String get nasSourceUnreachable =>
      'Não foi possível acessar a fonte de mídia';

  @override
  String get nasSshTunnelFailed => 'Falha na conexão do túnel SSH';

  @override
  String get nasOperationFailed => 'Operação falhou';

  @override
  String get nasInstallStepCreateDir => 'Criar diretório privado';

  @override
  String get nasInstallStepWriteCompose =>
      'Gravar configuração do docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Gravar credenciais privadas';

  @override
  String get nasInstallStepPullImage => 'Baixar imagem fixada do contêiner';

  @override
  String get nasInstallStepStartService => 'Iniciar serviço em contêiner';

  @override
  String get nasInstallStepCheckHttp => 'Verificar integridade HTTP do serviço';

  @override
  String get nasInstallBlockerDocker =>
      'O Docker Engine é necessário no servidor de destino';

  @override
  String get nasInstallBlockerCompose => 'O plugin Docker Compose é necessário';

  @override
  String get nasInstallBlockerIdentity =>
      'Não foi possível verificar a identidade do servidor de destino';

  @override
  String get nasInstallBlockerTools =>
      'Ferramentas necessárias (curl, ss, realpath) estão ausentes no servidor de destino';

  @override
  String get nasInstallBlockerMedia =>
      'O diretório de mídia não existe ou não pode ser lido';

  @override
  String get nasInstallBlockerParent =>
      'O diretório pai da raiz de dados não tem permissão de gravação';

  @override
  String get nasInstallBlockerOverlap =>
      'O diretório de mídia e o diretório de dados não podem se sobrepor';

  @override
  String get nasInstallBlockerCollision =>
      'O diretório de dados de destino já existe ou é um link simbólico';

  @override
  String get nasInstallBlockerPort =>
      'A porta selecionada já está em uso no servidor de destino';

  @override
  String get nasInstallBlockerContainer =>
      'Já existe um contêiner com este nome de projeto';

  @override
  String get nasInstallBlockerImage =>
      'Falha ao verificar a imagem do contêiner. Verifique o nome da imagem, a conectividade e a arquitetura do servidor e tente novamente.';

  @override
  String get nasInstallGuidanceTunnel =>
      'A ligação loopback (127.0.0.1) requer túnel SSH para acesso remoto';

  @override
  String get nasInstallGuidanceTls =>
      'Recomenda-se proteger a ligação pública atrás de um proxy reverso TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Conclua a configuração inicial da conta de administrador no navegador no primeiro início';

  @override
  String get nasInstallGuidanceReadOnly =>
      'O diretório de mídia é montado como somente leitura para proteger seus arquivos';

  @override
  String get nasInstallGuidancePreserved =>
      'O diretório de dados será preservado em caso de falha para solução de problemas';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Baixado (Falha ao abrir externamente)';

  @override
  String get nasRetryOpen => 'Tentar abrir novamente';

  @override
  String get nasExternalOpenFailed =>
      'Falha ao abrir o arquivo no aplicativo externo';

  @override
  String get nasTitle => 'Mídia NAS';

  @override
  String get nasLoadMoreGroups => 'Carregar mais grupos';

  @override
  String get nasMetadataEnriching => 'Enriquecendo tags de música...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Enriquecendo tags de música ($count processadas)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Baixando $value…';
  }

  @override
  String get nasSubtitleNone => 'Nenhum';

  @override
  String get nasLibraryId => 'ID da biblioteca';

  @override
  String get nasLibraryIdHint =>
      'Padrão: tudo (/), ou especifique o ID da biblioteca';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relativo à raiz da fonte ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'A fonte mudou durante a configuração, gravação cancelada';

  @override
  String get nasInvalidLibraryId => 'ID de biblioteca inválido';

  @override
  String get startupFailed => 'Falha ao iniciar o aplicativo';

  @override
  String get startupFailedDesc =>
      'Ocorreu um erro inesperado durante a inicialização. Você pode tentar novamente ou exportar logs de diagnóstico.';

  @override
  String get retryStartup => 'Tentar iniciar novamente';

  @override
  String get viewDiagnostics => 'Ver diagnósticos';

  @override
  String get exportDiagnostics => 'Exportar diagnósticos';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnósticos exportados para $path';
  }

  @override
  String get diagnosticsExportFailed => 'Falha ao exportar diagnósticos';

  @override
  String get diagnosticsTitle => 'Diagnósticos do app';

  @override
  String get settingsDiagnostics => 'Diagnósticos e logs';

  @override
  String get settingsDiagnosticsDesc =>
      'Exibir e exportar logs locais higienizados do aplicativo';

  @override
  String get diagnosticsEmpty => 'Nenhum registro de diagnóstico encontrado';

  @override
  String diagnosticsStorageError(String error) {
    return 'Erro no armazenamento de diagnósticos: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Incidente recuperável relatado: $category';
  }

  @override
  String get diagnosticsRefresh => 'Atualizar logs';

  @override
  String get nasInstallTaskTitle => 'Tarefa de implantação';

  @override
  String get nasInstallStagePreflight => 'Verificação prévia';

  @override
  String get nasInstallStageReview => 'Revisão do plano';

  @override
  String get nasInstallStageWriting => 'Gravando configuração';

  @override
  String get nasInstallStagePulling => 'Baixando imagem';

  @override
  String get nasInstallStageStarting => 'Iniciando contêiner';

  @override
  String get nasInstallStageHealth => 'Verificando integridade';

  @override
  String get nasInstallStageCleanup => 'Limpando';

  @override
  String get nasInstallStageSucceeded => 'Implantação bem-sucedida';

  @override
  String get nasInstallStageFailed => 'Falha na implantação';

  @override
  String get nasInstallStageCancelled => 'Implantação cancelada';

  @override
  String get nasInstallStageNeedsInspection => 'Requer inspeção';

  @override
  String get nasInstallStageReconciling => 'Reconciliando estado';

  @override
  String get nasInstallCancel => 'Cancelar implantação';

  @override
  String get nasInstallReconcile => 'Reconciliar status';

  @override
  String get nasInstallServerNotFound =>
      'O servidor selecionado não foi encontrado';

  @override
  String get nasInstallPortRangeError => 'A porta deve estar entre 1 e 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Decorrido: $time';
  }

  @override
  String get nasInstallLogTail => 'Logs recentes';

  @override
  String get nasInstallCleanupCompleted => 'Limpeza de reversão concluída';

  @override
  String get nasInstallCleanupIncomplete => 'Limpeza de reversão incompleta';

  @override
  String get nasInstallNewDeployment => 'Nova implantação';

  @override
  String get nasInstallBackEdit => 'Voltar / Editar formulário';

  @override
  String get nasInstallClose => 'Fechar';

  @override
  String get nasInstallMediaPathHint =>
      'Montagem vinculada somente leitura no host (ex.: /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Diretório privado de dados e configuração (ainda não deve existir)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 para túnel, 0.0.0.0 para LAN';

  @override
  String get nasInstallWebdavPasswordHint =>
      'Mínimo de 12 caracteres obrigatório';

  @override
  String get nasInstallTargetServer => 'Servidor de destino';

  @override
  String get nasInstallTargetImage => 'Imagem de destino';

  @override
  String get nasInstallContainerName => 'Nome do contêiner';

  @override
  String get nasInstallBindAndPort => 'Ligação e porta';

  @override
  String get nasInstallComposePreview =>
      'Pré-visualização do docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Etapas planejadas';

  @override
  String get nasInstallGuidanceNotes => 'Notas e diretrizes de implantação';

  @override
  String get nasInstallNoLogsYet => 'Ainda não há logs';

  @override
  String get sftpPreviewTooLarge =>
      'O arquivo excede o limite de pré-visualização de 1 MiB. Baixe-o e abra-o externamente.';

  @override
  String get sftpSaveFailed =>
      'Falha ao salvar o arquivo. Verifique as permissões ou a conexão de rede.';

  @override
  String get sftpSaving => 'Salvando...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'A conexão com o servidor de destino mudou; verifique o estado remoto antes de continuar';

  @override
  String get nasInstallBlockerCancelled =>
      'A implantação foi cancelada pelo usuário. Revise as configurações e tente novamente se necessário.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'A inspeção falhou ao consultar o contêiner remoto. Verifique a conectividade ou inspecione manualmente.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'A etapa de implantação atingiu o tempo limite. Verifique a carga do servidor ou a rede e tente novamente.';

  @override
  String get nasInstallBlockerInterrupted =>
      'A implantação foi interrompida; revise o estado remoto antes de continuar.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'O serviço iniciou, mas a verificação de integridade HTTP expirou. Verifique os logs do serviço ou a porta.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Falha na reconciliação. Verifique o status do contêiner manualmente ou inicie uma nova implantação.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'O status do contêiner remoto é incerto. Inspeção manual e reconciliação necessárias.';

  @override
  String get nasInstallBlockerServiceExited =>
      'O processo do contêiner foi encerrado prematuramente. Verifique os logs para erros de configuração ou permissão.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Falha ao gravar arquivos de implantação no servidor de destino. Verifique o espaço em disco e as permissões.';

  @override
  String get nasInstallBlockerPlanStale =>
      'O plano de implantação está desatualizado. Execute as verificações prévias novamente.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'O contêiner existente não foi criado por este aplicativo. Inspecione manualmente para evitar sobrescrevê-lo.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Uma conexão SSH ativa com o servidor de destino é necessária.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'O estado remoto difere do estado local. Reconcilie antes de continuar.';

  @override
  String get nasInstallBlockerFailed =>
      'A implantação encontrou um erro. Verifique os logs e tente novamente.';

  @override
  String get nasInstallBlockerBusy =>
      'Uma tarefa de instalação já está em andamento. Verifique o progresso da tarefa atual.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Falha ao persistir o estado de implantação. Verifique o espaço local e as permissões de arquivos.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'O resultado do comando remoto é desconhecido. Execute uma inspeção somente leitura em vez de tentar implantar diretamente.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'A verificação do ambiente pré-implantação falhou. Resolva os bloqueadores antes de continuar.';

  @override
  String serverDeleteFailed(String error) {
    return 'Falha ao excluir o servidor: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Modo do agente';

  @override
  String get chatRunSettingsApprovalPolicy => 'Política de aprovação local';

  @override
  String get chatRunSettingsExtraSettings => 'Configurações adicionais';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Permite automaticamente operações sabidamente seguras; pergunta sempre que a segurança da operação não puder ser determinada.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Falha ao aplicar configurações de execução: $error';
  }

  @override
  String get chatMessageCopied =>
      'Mensagem copiada para a área de transferência';

  @override
  String get copy => 'Copiar';

  @override
  String get rename => 'Renomear';

  @override
  String get refresh => 'Atualizar';

  @override
  String get sessionTitle => 'Título da sessão';

  @override
  String get chatSettingsStale => 'Desatualizado';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Configurações disponíveis após a primeira mensagem';

  @override
  String get chatReimportAsCopy => 'Reimportar como cópia';

  @override
  String get chatSearchCommandsHint => 'Pesquisar comandos ou habilidades...';

  @override
  String get chatCommandsTab => 'Comandos';

  @override
  String get chatSkillsTab => 'Habilidades';

  @override
  String get chatAccountAndQuotaTitle => 'Conta e cota';

  @override
  String get chatAccountSectionTitle => 'Conta';

  @override
  String get chatAccountNotProvided => 'Nenhum detalhe da conta informado';

  @override
  String get chatAccountKind => 'Tipo';

  @override
  String get chatAccountLabel => 'Rótulo';

  @override
  String get chatAccountPlan => 'Plano';

  @override
  String get chatAccountEmail => 'E-mail';

  @override
  String get chatAccountUpdatedAt => 'Atualizado';

  @override
  String get chatQuotaSectionTitle => 'Cota e status';

  @override
  String get chatStatusSourceNote => 'Saída bruta do /status do agente';

  @override
  String get chatStatusNotQueried => 'Status ainda não consultado';

  @override
  String get chatQueryStatusAction => 'Consultar status (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Consulta de status indisponível na sessão atual';

  @override
  String get chatAttachmentMissing => 'Arquivo anexo ausente ou indisponível';

  @override
  String get chatViewModeList => 'Lista';

  @override
  String get chatViewModeCards => 'Cartões';

  @override
  String get chatViewModeGrid => 'Imagens';

  @override
  String get chatRemoteBrowserTitle => 'Espaço de trabalho remoto';

  @override
  String get chatSelectDirectory => 'Selecionar diretório';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Anexar selecionados ($count)';
  }

  @override
  String get chatNoFilesFound => 'Nenhum arquivo encontrado';

  @override
  String get chatRootDirectory => 'Raiz';

  @override
  String get chatSelectThisDirectory => 'Usar este diretório';

  @override
  String get chatAgentVersion => 'Versão do agente';

  @override
  String get chatParentDirectory => 'Diretório pai';

  @override
  String get chatSearchFilesHint => 'Pesquisar arquivos...';

  @override
  String get chatCommandsEmpty => 'Nenhum comando slash fornecido pelo agente';

  @override
  String get chatSkillsEmpty => 'Nenhuma habilidade fornecida pelo agente';

  @override
  String get chatFileUnsupported => 'Tipo de arquivo não suportado para anexo';

  @override
  String get chatStatusNotProvided =>
      'Consulta de status não fornecida pelo agente';

  @override
  String get sessionRecoveryReconnecting => 'Reconectando...';

  @override
  String get sessionRecoverySyncing => 'Sincronizando saída...';

  @override
  String get sessionRecoveryIncomplete =>
      'Algumas saídas não puderam ser recuperadas';

  @override
  String get sessionRecoveryFailed => 'Recuperação falhou';

  @override
  String get sessionRecoveryRetry => 'Tentar novamente';

  @override
  String get dashboardUpdatesPaused => 'Atualizações pausadas';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'O catálogo de modelos CLI está indisponível no momento. Os modelos podem estar em cache ou limitados pela versão da CLI; você também pode inserir um nome de modelo manualmente.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Os modelos são consultados no servidor de aplicativos da CLI usando seu login existente. O catálogo pode estar em cache ou limitado por versão; você pode atualizar manualmente ou alternar para entrada manual.';

  @override
  String get chatModelCatalogError403 =>
      'Acesso negado à consulta de modelos CLI (403). Verifique o login e a conectividade ou insira um nome de modelo manualmente.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Erro no catálogo de modelos: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Autorizar catálogo de modelos';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Autorizar catálogo de modelos';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Isso iniciará a autorização no navegador para o catálogo de modelos no host/contêiner de destino. Seu login do Codex e sessões de terminal existentes permanecerão intactos. Continuar?';

  @override
  String get chatModelAuthorizing => 'Autorizando pelo navegador...';

  @override
  String get chatModelAuthorizeCancel => 'Cancelar autorização';

  @override
  String get chatCommandsFirstTurnNote =>
      'Comandos slash serão anunciados pelo agente assim que a sessão for inicializada, sem exigir conversa prévia; rascunhos não criam sessões automaticamente.';

  @override
  String get chatCommandsClientActionRunSettings => 'Configurações de execução';

  @override
  String get chatCommandsClientActionWorkingDirectory =>
      'Diretório de trabalho';

  @override
  String get chatCommandsClientActionsSection => 'Ações locais';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Lista de modelos';

  @override
  String get chatRunSettingsModelSourceCustom => 'Entrada manual';

  @override
  String get chatRunSettingsCustomModelHint => 'Inserir ID do modelo';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Nomes de modelo manuais não são verificados e serão enviados diretamente ao agente, que pode rejeitar modelos não suportados.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'O nome do modelo não pode ficar vazio';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'O nome do modelo deve ter no máximo 256 caracteres, sem espaços ou caracteres de controle';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Comandos verificados para a versão atual do adaptador. Selecionar insere o texto no rascunho; Enviar inicializará a sessão sob demanda e executará o comando diretamente.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Falha ao descobrir comandos ou habilidades';

  @override
  String get chatAuthWaitingForBrowser =>
      'Aguardando autorização no navegador...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Não foi possível abrir o navegador externo. Reabra ou copie o link de autorização abaixo.';

  @override
  String get chatAuthReopenBrowser => 'Reabrir navegador';

  @override
  String get chatAuthCopyLink => 'Copiar link';

  @override
  String get chatAuthManualCallback => 'Retorno manual';

  @override
  String get chatAuthManualCallbackTitle =>
      'Inserir URL de retorno de autorização';

  @override
  String get chatAuthManualCallbackDesc =>
      'Cole a URL de redirecionamento completa (http://127.0.0.1:PORT/...?code=...&state=...) do navegador para concluir a autorização. Códigos de autorização brutos não são aceitos.';

  @override
  String get chatAuthCallbackInputLabel => 'URL de retorno';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Formato de URL de retorno inválido ou falha no envio';

  @override
  String get agentAuthAgYNotice =>
      'O Antigravity ACP requer autorização oficial de conta, separada do login da CLI no terminal.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Este turno requer autenticação ACP. Reconecte-se e solicite autorização para continuar.';

  @override
  String get chatRequestAuthButton => 'Solicitar autenticação';

  @override
  String get agentActionAcpLogin => 'Login no ACP';

  @override
  String get agentActionCliLogin => 'Login na CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Credenciais ACP ausentes (login no ACP necessário)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Credenciais ACP salvas (não verificadas)';

  @override
  String get chatAuthMethodUnavailable =>
      'O método de autenticação selecionado não está disponível.';

  @override
  String get chatAuthConnectionExpired =>
      'A conexão de autenticação expirou. Tente novamente.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Falha ao entregar retorno de autorização ao servidor.';

  @override
  String get agentTargetChangedNotice =>
      'O servidor de destino mudou. Reabra o gerenciamento de agentes no servidor atual.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Verificação de autenticação do Antigravity indisponível';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Resposta da verificação de autenticação do Antigravity inválida';

  @override
  String get sftpDownloadDisconnected => 'Download desconectado';

  @override
  String get sftpDownloadPermissionDenied => 'Permissão negada';

  @override
  String get sftpDownloadNotFound => 'Arquivo remoto não encontrado';

  @override
  String get sftpDownloadTimeout => 'Tempo limite de download esgotado';

  @override
  String get sftpDownloadLocalSpace =>
      'Espaço de armazenamento local insuficiente';

  @override
  String get sftpDownloadLocalIo => 'Falha ao gravar no armazenamento local';

  @override
  String get sftpDownloadIncomplete => 'Download incompleto';

  @override
  String get transferStatusWaitingConnection => 'Aguardando conexão';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Falha ao iniciar o ouvinte local de retorno de autorização. Tente a autenticação novamente.';

  @override
  String get settingsExperimentalFeatures => 'Recursos experimentais';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Experimente recursos de visualização e experimentais';

  @override
  String get settingsExperimentalCliChatTitle => 'Chat inteligente CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Habilitar interface de chat dedicada para agentes de linha de comando';

  @override
  String get settingsExperimentalDialogClose => 'Fechar';

  @override
  String get settingsExperimentalSaveFailed =>
      'Falha ao atualizar configurações de recursos experimentais';

  @override
  String get settingsExperimentalNasTitle => 'Mídia NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'Habilitar biblioteca de mídia, verificação de pastas e reprodução de áudio';

  @override
  String get settingsLanguageSaveFailed =>
      'Falha ao atualizar configurações de idioma';

  @override
  String get settingsAboutPrivacy => 'Sobre e privacidade';

  @override
  String get privacyPolicyTitle => 'Política de privacidade';

  @override
  String get privacyPolicyDescription => 'Uso de dados e suas opções';

  @override
  String get privacyContactTitle => 'Contato de privacidade';

  @override
  String get privacyCopyEmail => 'Copiar e-mail';

  @override
  String get privacyEmailCopied => 'E-mail copiado';

  @override
  String get privacyOnlineVersion => 'Ver versão online';

  @override
  String get privacyLinkFailed =>
      'Não foi possível abrir o link. Você pode copiar o e-mail.';

  @override
  String get privacyLoadFailed =>
      'Não foi possível carregar a política. Consulte a versão online.';

  @override
  String get privacyVersionUnknown => 'Versão indisponível';

  @override
  String get aboutWebsite => 'Site oficial';

  @override
  String get aboutLicense => 'Licença do aplicativo';

  @override
  String get aboutThirdPartyLicenses =>
      'Licenças de código aberto de terceiros';

  @override
  String get aboutLicenseSummary =>
      'O conteúdo original do Valhalla é licenciado para uso não comercial sob a PolyForm Noncommercial 1.0.0. O uso comercial além das permissões da licença exige autorização separada. Os componentes de terceiros mantêm suas próprias licenças. Os termos completos abaixo regem o uso.';

  @override
  String get aboutCopyrightNotice => 'Avisos de direitos autorais';

  @override
  String get aboutLicenseLoadFailed =>
      'Não foi possível carregar a licença. Entre em contato com norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Não foi possível abrir o link. Abra https://norns.cc.cd no navegador.';

  @override
  String get downloadReveal => 'Mostrar no Explorador de Arquivos';

  @override
  String get downloadRevealFailed =>
      'Não foi possível abrir a pasta de downloads. Ela pode ter sido movida ou excluída.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count chaves de hosts confiáveis';
  }

  @override
  String get settingsKnownHostsEmpty =>
      'Nenhuma chave de host confiável encontrada';

  @override
  String get settingsKnownHostsDialogTitle => 'Chaves de hosts conhecidos';

  @override
  String get settingsHostKeyRevoke => 'Revogar';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'Revogar chave de host';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return 'Revogar chave de host para $hostPort? Conexões SSH ativas com este host serão desconectadas e você precisará verificar a chave na próxima conexão.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Impressão digital da chave copiada para a área de transferência';

  @override
  String get settingsHostKeyRevoked => 'Chave de host revogada';

  @override
  String get settingsClearStorageSubtitle =>
      'Limpar senhas e chaves privadas salvas dos servidores selecionados';

  @override
  String get settingsClearStorageDialogTitle =>
      'Redefinir credenciais do servidor';

  @override
  String get settingsClearStorageDesc =>
      'Selecione servidores para limpar senhas SSH e chaves privadas do armazenamento seguro. As configurações do servidor e os históricos de conversa não serão excluídos.';

  @override
  String get settingsClearStorageNoServers => 'Nenhum servidor disponível';

  @override
  String get settingsClearStorageSelectAll => 'Selecionar tudo';

  @override
  String get settingsClearStorageDeselectAll => 'Desmarcar tudo';

  @override
  String get settingsClearStorageConfirmTitle =>
      'Confirmar redefinição de credenciais';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'Tem certeza de que deseja limpar as credenciais de $count servidor(es) selecionado(s)? Conexões ativas serão desconectadas imediatamente.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Limpar selecionados ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Credenciais dos servidores selecionados limpas com sucesso';

  @override
  String get settingsClearStorageError =>
      'Falha ao limpar credenciais de alguns servidores. Tente novamente.';

  @override
  String get settingsDefaultAcpAgent => 'Agente ACP padrão';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Agente padrão para chat ACP neste servidor';

  @override
  String get settingsDefaultCliAgent => 'Agente CLI padrão';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Agente padrão para chat CLI neste servidor';

  @override
  String get settingsDefaultAgentAutomatic =>
      'Automático (primeiro disponível)';

  @override
  String get settingsDefaultAgentSelectTitle => 'Selecionar agente padrão';

  @override
  String get settingsDefaultAgentNoServer => 'Nenhum servidor selecionado';

  @override
  String get settingsDefaultAgentNoAgents =>
      'Nenhum agente configurado para este servidor';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Falha ao atualizar a configuração do agente padrão';

  @override
  String get dockerViewGroupContainers => 'Contêineres';

  @override
  String get dockerViewGroupProjects => 'Projetos Compose';

  @override
  String get dockerProjectActionStart => 'Iniciar projeto';

  @override
  String get dockerProjectActionStop => 'Parar projeto';

  @override
  String get dockerProjectActionRestart => 'Reiniciar projeto';

  @override
  String get dockerProjectConfirmStopTitle => 'Parar projeto Compose';

  @override
  String get dockerProjectConfirmRestartTitle => 'Reiniciar projeto Compose';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'Tem certeza de que deseja $action o projeto \"$project\"? Os seguintes $count contêineres serão afetados:';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'Projeto \"$project\" $action concluído com sucesso';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'Projeto \"$project\" $action concluído com $failedCount falha(s)';
  }

  @override
  String get dockerNoProjects => 'Nenhum projeto Docker Compose encontrado';

  @override
  String get dockerMountsTitle => 'Montagens';

  @override
  String get dockerMountReadOnly => 'Somente leitura';

  @override
  String get dockerMountReadWrite => 'Leitura/Escrita';

  @override
  String get sftpBookmarksTitle => 'Marcadores de diretório';

  @override
  String get sftpNoBookmarks => 'Nenhum marcador salvo ainda';

  @override
  String get sftpAddBookmark => 'Adicionar aos marcadores';

  @override
  String get sftpRemoveBookmark => 'Remover marcador';

  @override
  String get sftpCurrentDirectory => 'Diretório atual';

  @override
  String get sftpSelectMode => 'Seleção múltipla';

  @override
  String sftpSelectedCount(int count) {
    return '$count selecionado(s)';
  }

  @override
  String get sftpSelectAll => 'Selecionar tudo';

  @override
  String get sftpDeselectAll => 'Desmarcar tudo';

  @override
  String get sftpBatchCopy => 'Copiar';

  @override
  String get sftpBatchMove => 'Mover';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Confirmar exclusão em lote';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'Tem certeza de que deseja excluir os $count itens selecionados?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Aviso: Diretórios não vazios não podem ser excluídos recursivamente e serão ignorados.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Confirmar cópia em lote';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'Copiar $count itens selecionados para \"$directory\"?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Confirmar movimentação em lote';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'Mover $count itens selecionados para \"$directory\"?';
  }

  @override
  String get sftpBatchResultsTitle => 'Resultados da operação em lote';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Ignorado (destino existente ou não suportado)';

  @override
  String get sftpBatchTargetRestricted =>
      'Não é possível selecionar o diretório atual ou seus subdiretórios como destino';

  @override
  String get sftpSelectCurrentDir => 'Escolher este diretório';

  @override
  String sftpBatchOperationSuccess(int count) {
    return '$count itens processados com sucesso';
  }

  @override
  String get configMigrationTitle => 'Backup e migração de configuração';

  @override
  String get configExportTitle => 'Exportar configuração';

  @override
  String get configExportSubtitle =>
      'Exportar servidores, agentes, comandos, marcadores e preferências para JSON';

  @override
  String get configExportDialogTitle => 'Exportar configuração do Valhalla';

  @override
  String get configExportSuccess => 'Configuração exportada com sucesso';

  @override
  String configExportError(String error) {
    return 'Falha ao exportar configuração: $error';
  }

  @override
  String get configImportTitle => 'Importar configuração';

  @override
  String get configImportSubtitle =>
      'Importar configuração a partir de um arquivo JSON de backup';

  @override
  String get configBackupTooLarge =>
      'O arquivo de backup excede o tamanho máximo permitido (8 MB)';

  @override
  String get configImportPreviewTitle =>
      'Pré-visualização da importação de configuração';

  @override
  String get configImportPreviewDesc =>
      'Revise o conteúdo antes de importar. Os itens existentes serão preservados e mesclados.';

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
      'Comandos personalizados podem conter scripts confidenciais ou credenciais incorporadas. Nenhuma senha, chave privada ou impressão digital de host confiável é transferida.';

  @override
  String get configImportGlobalPreferences =>
      'Importar preferências globais do aplicativo';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Substitui as configurações atuais de tema, terminal e navegação';

  @override
  String get configImportConfirmAction => 'Confirmar importação';

  @override
  String get configImportSuccess => 'Configuração importada com sucesso';

  @override
  String get configImportErrorTitle => 'Backup de configuração inválido';

  @override
  String configImportErrorGeneric(String error) {
    return 'Falha ao importar configuração: $error';
  }

  @override
  String get configImportErrorCopyDetails => 'Copiar detalhes de diagnóstico';

  @override
  String get configImportErrorCopied =>
      'Detalhes de diagnóstico copiados para a área de transferência';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Formato ou versão de backup não suportado';

  @override
  String get configImportErrorMalformed =>
      'JSON de configuração corrompido ou malformado';

  @override
  String get aboutRepository => 'Repositório do GitHub';

  @override
  String get updateCheckTitle => 'Verificar atualizações';

  @override
  String get updateChecking => 'Verificando atualizações...';

  @override
  String get updateCheckNow => 'Verificar agora';

  @override
  String get updateUpToDate => 'O Valhalla está atualizado';

  @override
  String updateInstalledVersion(String version) {
    return 'Instalado: v$version';
  }

  @override
  String updateAvailableBadge(String version) {
    return 'Nova versão disponível: v$version';
  }

  @override
  String get updateViewUpdate => 'Ver atualização';

  @override
  String updateLastChecked(String time) {
    return 'Última verificação: $time';
  }

  @override
  String get updateNeverChecked => 'Nunca verificado';

  @override
  String get updateAutoCheckTitle => 'Verificação automática de atualizações';

  @override
  String get updateAutoCheckSubtitle =>
      'Verificar atualizações diariamente quando o app estiver ativo';

  @override
  String get updateAutoCheckSaveFailed =>
      'Falha ao salvar a configuração de atualização automática';

  @override
  String get updateDialogTitle => 'Atualização de software';

  @override
  String updateCurrentVersion(String version) {
    return 'Atual: $version';
  }

  @override
  String updateTargetVersion(String version) {
    return 'Mais recente: v$version';
  }

  @override
  String updateBuildNumber(String build) {
    return 'Compilação $build';
  }

  @override
  String updateCommit(String commit) {
    return 'Hash do commit: $commit';
  }

  @override
  String get updateArtifactDetails => 'Pacote de instalação';

  @override
  String updateArtifactName(String name) {
    return 'Arquivo: $name';
  }

  @override
  String updateArtifactSize(String size) {
    return 'Tamanho: $size';
  }

  @override
  String updateArtifactHash(String hash) {
    return 'Hash SHA-256: $hash';
  }

  @override
  String get updateCopyHash => 'Copiar hash SHA-256';

  @override
  String get updateHashCopied =>
      'Hash SHA-256 copiado para a área de transferência';

  @override
  String get updateCopyCommit => 'Copiar hash do commit';

  @override
  String get updateCommitCopied =>
      'Hash do commit copiado para a área de transferência';

  @override
  String get updateReleaseNotes => 'Notas de lançamento';

  @override
  String get updateNoReleaseNotes => 'Nenhuma nota de lançamento fornecida.';

  @override
  String get updateNoArtifactForPlatform =>
      'Nenhum pacote de instalação direta disponível para esta plataforma/arquitetura.';

  @override
  String get updateOpenReleasePage => 'Abrir página de lançamentos';

  @override
  String get updateDownload => 'Baixar atualização';

  @override
  String updateDownloading(String progress) {
    return 'Baixando... $progress%';
  }

  @override
  String get updatePause => 'Pausar';

  @override
  String get updateResume => 'Retomar';

  @override
  String get updateRetry => 'Tentar novamente';

  @override
  String get updateDownloadPaused => 'Download pausado';

  @override
  String get updateDownloadCompleted => 'Download concluído e verificado';

  @override
  String get updatePhaseResolving => 'Conectando ao servidor de atualização...';

  @override
  String get updatePhaseVerifying => 'Verificando pacote de atualização...';

  @override
  String get updateOpeningInstaller => 'Preparando instalação...';

  @override
  String get updateInstall => 'Instalar atualização';

  @override
  String get updateRevealInFolder => 'Mostrar na pasta';

  @override
  String get updateOpenFolder => 'Abrir local de download';

  @override
  String get updateRetryInstall => 'Tentar instalar novamente';

  @override
  String get updateDesktopInstructions =>
      'Extraia o arquivo baixado e substitua o aplicativo quando fechado. Nunca sobrescreva o programa em execução.';

  @override
  String get updateCopyErrorDetails => 'Copiar detalhes do erro';

  @override
  String get updateErrorCopied =>
      'Detalhes do erro copiados para a área de transferência';

  @override
  String get updateErrorRateLimited =>
      'Limite de requisições do serviço de atualização excedido. Tente novamente mais tarde.';

  @override
  String get updateErrorNetwork =>
      'Falha na conexão de rede. Verifique sua conexão com a internet.';

  @override
  String get updateErrorManifest =>
      'O manifesto de atualização é inválido ou faltam metadados necessários.';

  @override
  String get updateErrorIntegrity =>
      'Falha na verificação de integridade do download. O checksum do arquivo não corresponde.';

  @override
  String get updateErrorSignatureMismatch =>
      'Incompatibilidade de assinatura de instalação: o pacote é assinado com uma chave diferente. Não é possível sobrescrever assinaturas diferentes. Para evitar perda de dados, nunca desinstale ou limpe os dados do aplicativo.';

  @override
  String get updateErrorPermissionRequired =>
      'Permissão de instalação necessária. Permita a instalação de fontes desconhecidas nas configurações do sistema e toque em Tentar instalar novamente.';

  @override
  String get updateErrorPermission =>
      'Permissão de armazenamento ou do sistema negada.';

  @override
  String get updateErrorPackageInvalid =>
      'Caminho ou identidade do pacote inválidos.';

  @override
  String get updateErrorStoreInstall =>
      'Este aplicativo foi instalado de uma loja de aplicativos. Atualize pela loja.';

  @override
  String get updateErrorPlatform => 'Falha ao abrir ou iniciar o instalador.';

  @override
  String get updateErrorGeneric =>
      'Falha na operação de atualização. Tente novamente ou acesse a página de lançamentos.';

  @override
  String get servicePermissionDenied =>
      'Permissão negada para gerenciar o serviço';

  @override
  String get serviceUnsupported => 'Ação não suportada para este serviço';

  @override
  String get serviceQueryFailed => 'Falha ao consultar o status do serviço';

  @override
  String get serviceTargetChanged =>
      'Servidor de destino alterado; operação cancelada';

  @override
  String get serviceActionInProgress =>
      'Outra ação já está em andamento para este serviço';

  @override
  String get processIdentityChanged =>
      'O processo foi reiniciado; encerramento cancelado';

  @override
  String get processIdentityUnavailable =>
      'Hora de início do processo indisponível; encerramento recusado';

  @override
  String get serviceLogsTitle => 'Registros do serviço';

  @override
  String get serviceLogsLoadOlder => 'Carregar registros mais antigos';

  @override
  String get serviceLogsEmpty => 'Nenhum registro encontrado';

  @override
  String get serviceLogsCopied =>
      'Registros copiados para a área de transferência';

  @override
  String get fileEditorUnsavedTitle => 'Alterações não salvas';

  @override
  String get fileEditorUnsavedMessage =>
      'Você tem alterações não salvas. Escolha uma ação antes de sair:';

  @override
  String get fileEditorKeepDraft => 'Manter rascunho';

  @override
  String get fileEditorDiscard => 'Descartar';

  @override
  String get fileEditorDiscardConfirmTitle => 'Descartar rascunho?';

  @override
  String get fileEditorDiscardConfirmMessage =>
      'Tem certeza de que deseja descartar o rascunho local e recarregar o arquivo do servidor?';

  @override
  String get fileEditorConflictBanner =>
      'O arquivo foi modificado no servidor ou está em conflito com o rascunho local.';

  @override
  String get fileEditorCopyDraft => 'Copiar rascunho';

  @override
  String get fileEditorDraftCopied =>
      'Rascunho copiado para a área de transferência';

  @override
  String get fileEditorReload => 'Recarregar';

  @override
  String get sftpAtomicSaveUnsupported =>
      'O servidor não suporta salvamento atômico seguro';

  @override
  String get sftpEditorExpired => 'A sessão do editor expirou';

  @override
  String get sftpDraftSaveFailed => 'Falha ao salvar o rascunho local';

  @override
  String get sftpEditConflict =>
      'Arquivo modificado no servidor; recarregue ou copie o rascunho';

  @override
  String get sftpEditDraftConflict =>
      'O rascunho local está em conflito com o arquivo do servidor';

  @override
  String get sftpTransferSourceChanged =>
      'O arquivo de origem foi alterado durante a transferência';

  @override
  String get sftpTransferPartialInvalid =>
      'Arquivo de transferência parcial inválido ou corrompido';

  @override
  String get sftpTransferCommitting =>
      'Transferência já em confirmação; não é possível reiniciar';

  @override
  String get sftpTransferCleanupFailed =>
      'Falha ao limpar a transferência incompleta';

  @override
  String get sftpUploadTargetExists => 'O arquivo de destino já existe';

  @override
  String get sftpUploadCommitFailed => 'Falha ao finalizar o upload remoto';

  @override
  String get sftpUploadSourceInvalid =>
      'O arquivo de origem local foi alterado ou é inválido';

  @override
  String cachedDataNotice(String time) {
    return 'Em cache às $time';
  }

  @override
  String get serviceLogsCapReached => 'Limite: 1000 registros mantidos';

  @override
  String get nasThumbnailCacheUsage => 'Cache de miniaturas';

  @override
  String get nasThumbnailCacheBudget => 'Limite de cache';

  @override
  String get nasThumbnailCacheClear => 'Limpar cache';

  @override
  String get nasThumbnailCacheCleared => 'Cache de miniaturas limpo';

  @override
  String get nasThumbnailCacheOff => 'Desativado';

  @override
  String get navAppCenter => 'Central de Aplicativos';

  @override
  String get settingsExperimentalAppCenterTitle =>
      'Central de Aplicativos (Docker)';

  @override
  String get settingsExperimentalAppCenterDesc =>
      'Loja experimental de aplicativos e gerenciador de implantação de contêineres';

  @override
  String get appCenterTitle => 'Central de Aplicativos';

  @override
  String get appCenterTabStore => 'Loja';

  @override
  String get appCenterTabInstalled => 'Instalados';

  @override
  String get appCenterTabTasks => 'Tarefas';

  @override
  String get appCenterSources => 'Fontes';

  @override
  String get appCenterManageSources => 'Gerenciar Fontes';

  @override
  String get appCenterAddSource => 'Adicionar Fonte';

  @override
  String get appCenterSourceName => 'Nome da Fonte';

  @override
  String get appCenterSourceUrl => 'URL da Fonte (HTTPS)';

  @override
  String get appCenterDeleteSource => 'Excluir Fonte';

  @override
  String get appCenterRefresh => 'Atualizar';

  @override
  String get appCenterSearchHint => 'Pesquisar aplicativos...';

  @override
  String get appCenterFilterAllCategories => 'Todas as Categorias';

  @override
  String get appCenterFilterAllSources => 'Todas as Fontes';

  @override
  String get appCenterNoApps => 'Nenhum aplicativo encontrado';

  @override
  String get appCenterNoInstalled => 'Nenhum aplicativo instalado';

  @override
  String get appCenterNoTasks => 'Nenhuma tarefa ativa ou recente';

  @override
  String get appCenterInstall => 'Instalar';

  @override
  String get appCenterInstalledBadge => 'Instalado';

  @override
  String get appCenterIncompatibleBadge => 'Incompatível';

  @override
  String get appCenterUpdateAvailable => 'Atualização Disponível';

  @override
  String get appCenterArchitectureBlocker => 'Arquitetura não suportada';

  @override
  String get appCenterAppDetails => 'Detalhes do Aplicativo';

  @override
  String get appCenterVersion => 'Versão';

  @override
  String get appCenterCategory => 'Categoria';

  @override
  String get appCenterSource => 'Fonte';

  @override
  String get appCenterArchitectures => 'Arquiteturas Suportadas';

  @override
  String get appCenterScreenshots => 'Capturas de Tela';

  @override
  String get appCenterDescription => 'Descrição';

  @override
  String appCenterWizardTitle(String appName) {
    return 'Instalar $appName';
  }

  @override
  String appCenterConfigureTitle(String appName) {
    return 'Configurar $appName';
  }

  @override
  String appCenterUpdateTitle(String appName) {
    return 'Atualizar $appName';
  }

  @override
  String get appCenterStepEnvironment => 'Ambiente';

  @override
  String get appCenterStepConfig => 'Configuração';

  @override
  String get appCenterStepReview => 'Revisar Plano';

  @override
  String get appCenterStepProgress => 'Progresso';

  @override
  String get appCenterInstanceName => 'Nome da Instância';

  @override
  String get appCenterDataDirectory => 'Diretório de Dados';

  @override
  String get appCenterBrowseDirectory => 'Navegar no Diretório';

  @override
  String get appCenterNetworkAndPorts => 'Rede e Portas';

  @override
  String get appCenterBindAddress => 'Endereço de Vinculação';

  @override
  String get appCenterBindLoopback => 'Apenas Localhost (127.0.0.1)';

  @override
  String get appCenterBindAll => 'Todas as Interfaces (0.0.0.0)';

  @override
  String get appCenterPortMapping => 'Mapeamento de Portas';

  @override
  String get appCenterMounts => 'Montagens de Armazenamento';

  @override
  String get appCenterMountSource => 'Caminho no Host';

  @override
  String get appCenterMountTarget => 'Caminho no Contêiner';

  @override
  String get appCenterMountReadOnly => 'Somente Leitura';

  @override
  String get appCenterVariables => 'Variáveis';

  @override
  String get appCenterEnvironmentVariables => 'Variáveis de Ambiente';

  @override
  String get appCenterNext => 'Avançar';

  @override
  String get appCenterBack => 'Voltar';

  @override
  String get appCenterConfirmAndExecute => 'Executar Plano';

  @override
  String get appCenterPlanPreview => 'Pré-visualização do Plano de Implantação';

  @override
  String get appCenterPlanSanitizedNotice =>
      'Revise o plano de implantação gerado antes da execução:';

  @override
  String get appCenterEnvironmentCheck => 'Ambiente Docker';

  @override
  String get appCenterDockerFound => 'Docker está disponível';

  @override
  String get appCenterDockerMissing => 'Docker não está instalado';

  @override
  String get appCenterComposeFound => 'Docker Compose está disponível';

  @override
  String get appCenterComposeMissing => 'Docker Compose não está instalado';

  @override
  String get appCenterBootstrapPrompt =>
      'Docker e Compose podem ser instalados automaticamente neste servidor. Permissão de root/sudo é necessária.';

  @override
  String get appCenterBootstrapButton => 'Instalar Docker e Compose';

  @override
  String get appCenterSudoPassword =>
      'Senha do Sudo (opcional / se necessária)';

  @override
  String get appCenterSudoPasswordHint =>
      'Digite a senha do sudo para operações privilegiadas';

  @override
  String get appCenterOpen => 'Abrir Interface Web';

  @override
  String get appCenterStart => 'Iniciar';

  @override
  String get appCenterStop => 'Parar';

  @override
  String get appCenterRestart => 'Reiniciar';

  @override
  String get appCenterLogs => 'Logs';

  @override
  String get appCenterConfig => 'Configurar';

  @override
  String get appCenterUpdate => 'Atualizar';

  @override
  String get appCenterRestore => 'Restaurar';

  @override
  String get appCenterUninstall => 'Desinstalar';

  @override
  String appCenterUninstallConfirmTitle(String appName) {
    return 'Desinstalar $appName?';
  }

  @override
  String appCenterUninstallConfirmMessage(String appName) {
    return 'Tem certeza de que deseja desinstalar $appName? Os contêineres serão removidos, mas seu diretório de dados do aplicativo será preservado.';
  }

  @override
  String get appCenterUninstallKeepData => 'Desinstalar (Manter dados)';

  @override
  String get appCenterUninstallDeleteSelected =>
      'Desinstalar e excluir selecionados';

  @override
  String get appCenterUninstallInspecting =>
      'Inspecionando diretórios de dados do aplicativo...';

  @override
  String get appCenterUninstallInspectionFailedWarning =>
      'Falha na inspeção de limpeza de dados. Você ainda pode desinstalar os contêineres do aplicativo mantendo todos os dados em segurança.';

  @override
  String get appCenterUninstallDirectoriesTitle =>
      'Diretórios de dados e volumes Docker';

  @override
  String get appCenterUninstallNoDirectories =>
      'Nenhum diretório de dados montado foi detectado. Os contêineres serão removidos enquanto os dados serão preservados.';

  @override
  String get appCenterUninstallDefaultPreservedHint =>
      'Todos os dados são preservados por padrão. Selecione somente os diretórios ou volumes que deseja excluir permanentemente.';

  @override
  String get appCenterUninstallPermanentLossWarning =>
      'Os dados selecionados serão excluídos permanentemente do servidor. Não há lixeira.';

  @override
  String get appCenterUninstallSelectedPathsTitle =>
      'Dados a excluir permanentemente:';

  @override
  String get appCenterUninstallRiskAck =>
      'Entendo os riscos e os efeitos sobre outros aplicativos e confirmo a exclusão permanente destes dados.';

  @override
  String get remoteBrowserAllFileTypes => 'Todos os formatos';

  @override
  String get remoteBrowserDocuments => 'Texto e documentos';

  @override
  String get remoteBrowserFileFormat => 'Formato do arquivo';

  @override
  String get appCenterUninstallRiskSystem => 'Caminho do sistema';

  @override
  String get appCenterUninstallRiskShared =>
      'Compartilhado com outros aplicativos';

  @override
  String get appCenterUninstallRiskVolume => 'Volume Docker';

  @override
  String get appCenterCleanupVolumeDeleteFailed =>
      'Falha ao excluir o volume Docker. Libere seu uso por outros contêineres, verifique novamente e tente de novo.';

  @override
  String get appCenterCleanupPermissionDenied =>
      'Acesso negado. Use uma conta com acesso aos dados ou sudo.';

  @override
  String get appCenterCleanupCriticalPath =>
      'A raiz do servidor e os diretórios de execução ou gerenciamento não podem ser excluídos ao desinstalar um aplicativo.';

  @override
  String appCenterUninstallTypeAppNameHint(String appName) {
    return 'Digite o nome exato do aplicativo para confirmar a exclusão permanente: $appName';
  }

  @override
  String get appCenterUninstallRiskLegacy =>
      'Propriedade exclusiva não verificada';

  @override
  String get appCenterUninstallRiskExternal =>
      'Fora da raiz de dados do aplicativo';

  @override
  String get appCenterUninstallRiskMedia =>
      'Caminho de mídia ou somente leitura';

  @override
  String get appCenterUninstallTargetBlocked =>
      'Diretório protegido, não pode ser excluído';

  @override
  String get appCenterCleanupProtected =>
      'Diretório de dados mantido porque está protegido ou não é seguro removê-lo';

  @override
  String get appCenterCleanupUnavailable =>
      'Inspeção de limpeza indisponível; desinstalação comum possível mantendo os dados';

  @override
  String get appCenterCleanupChanged =>
      'Diretório ou destino de implantação alterado; inspecione e confirme novamente';

  @override
  String get appCenterCleanupConfirmationRequired =>
      'Confirme novamente os diretórios selecionados, os riscos e o nome exato do aplicativo';

  @override
  String get appCenterCleanupRetryUnavailable =>
      'A limpeza não pode ser repetida com segurança; inspecione os detalhes da tarefa';

  @override
  String get appCenterCleanupAlreadyAbsent =>
      'O diretório já não existe; nenhuma exclusão necessária';

  @override
  String get appCenterCleanupDeleteFailed =>
      'Exclusão incompleta; alguns arquivos já podem ter sido removidos. Inspecione os caminhos restantes.';

  @override
  String get appCenterCleanupUnconfirmed =>
      'Não foi possível confirmar o resultado ou a segurança da limpeza; inspecione a tarefa e verifique antes de continuar';

  @override
  String appCenterCleanupRetryTitle(String appName) {
    return 'Repetir a limpeza de dados restantes para $appName?';
  }

  @override
  String get appCenterCleanupRetryDescription =>
      'O aplicativo já está desinstalado. Selecione apenas os diretórios de dados pendentes; a repetição não o desinstalará novamente.';

  @override
  String get appCenterCleanupRetrySelected =>
      'Excluir dados restantes selecionados';

  @override
  String get appCenterCleanupResultsTitle =>
      'Resultados da limpeza de diretórios';

  @override
  String get appCenterCleanupPartialSummary =>
      'Aplicativo desinstalado; alguns dados não foram totalmente apagados.';

  @override
  String get appCenterCleanupPending => 'Não confirmado como concluído';

  @override
  String get appCenterCleanupRemoved => 'Removido';

  @override
  String get appCenterCleanupRetained => 'Mantido';

  @override
  String get appCenterCleanupRetryAction =>
      'Repetir limpeza de dados restantes';

  @override
  String get appCenterJellyfinSoftwareTitle =>
      'Modo de decodificação por software';

  @override
  String get appCenterJellyfinSoftwareDesc =>
      'Desativa a transcodificação por GPU, remove os mapeamentos de dispositivos GPU revisados e monta /Media como somente leitura.';

  @override
  String get appCenterJellyfinProfileUnavailable =>
      'O perfil de decodificação por software não está disponível para este modelo';

  @override
  String get appCenterJellyfinSoftwareChanges =>
      'Alterações de perfil aplicadas:';

  @override
  String get nasNativeInstallTitle => 'Instalar Jellyfin (pacote nativo)';

  @override
  String get nasNativeStepVerifyRepo =>
      'Verificar o repositório oficial assinado';

  @override
  String get nasNativeStepPreventAutostart =>
      'Impedir a inicialização automática antes da configuração';

  @override
  String get nasNativeStepInstallPackages =>
      'Instalar pacotes assinados com versões fixadas';

  @override
  String get nasNativeStepConfigureLoopback =>
      'Configurar a escuta apenas em localhost';

  @override
  String get nasNativeStageInstalling =>
      'Instalando pacotes com versões fixadas';

  @override
  String get nasNativeStageStarting => 'Iniciando o serviço systemd';

  @override
  String get nasNativeGuidanceMediaAccess =>
      'As permissões e os proprietários dos arquivos de mídia permanecem inalterados. Verifique se o usuário do serviço Jellyfin tem acesso de leitura.';

  @override
  String get nasNativeGuidanceNoUpgrade =>
      'Instalações existentes do Jellyfin não serão adotadas, modificadas nem atualizadas.';

  @override
  String get nasNativeSupportedRequirements =>
      'Requer Debian ou Ubuntu (amd64/arm64), systemd e acesso root ou sudo sem senha.';

  @override
  String get nasNativeExistingInstallTitle =>
      'Instalação existente do Jellyfin detectada';

  @override
  String get nasNativeExistingInstallExplanation =>
      'O Jellyfin já está instalado neste servidor. O Valhalla não o modificará nem reinstalará. Verifique a conexão diretamente.';

  @override
  String get nasNativeCancelExplanation =>
      'Cancelamento solicitado no próximo ponto seguro. As operações de pacotes em andamento serão concluídas com segurança.';

  @override
  String get nasNativeMediaPathLabel => 'Caminho do diretório de mídia';

  @override
  String get nasNativeMediaPathHint =>
      'Caminho absoluto já existente no servidor (ex.: /media/library). As permissões permanecem inalteradas.';

  @override
  String get nasNativeSudoRequired =>
      'É necessário acesso root ou sudo sem senha para instalar pacotes do sistema';

  @override
  String appCenterLogsTitle(String appName) {
    return 'Logs de $appName';
  }

  @override
  String get appCenterLogsEmpty => 'Nenhum log gravado para esta implantação';

  @override
  String get appCenterLogsCopied =>
      'Logs copiados para a área de transferência';

  @override
  String get appCenterTaskStageQueued => 'Na fila';

  @override
  String get appCenterTaskStagePreparing => 'Preparando';

  @override
  String get appCenterTaskStagePulling => 'Baixando imagens';

  @override
  String get appCenterTaskStageApplying => 'Aplicando configuração';

  @override
  String get appCenterTaskStageChecking => 'Verificando integridade';

  @override
  String get appCenterTaskStageSucceeded => 'Concluído com sucesso';

  @override
  String get appCenterTaskStageFailed => 'Falhou';

  @override
  String get appCenterTaskStageCancelled => 'Cancelado';

  @override
  String get appCenterTaskStageNeedsInspection => 'Requer inspeção';

  @override
  String get appCenterCancelTask => 'Cancelar Tarefa';

  @override
  String get appCenterCopyLog => 'Copiar Log';

  @override
  String get appCenterErrorNotConnected => 'Servidor não está conectado';

  @override
  String get appCenterErrorEnvironmentRequired =>
      'Verificação do ambiente Docker necessária';

  @override
  String get appCenterErrorPlanExpired =>
      'Plano de implantação expirado ou inválido';

  @override
  String get appCenterErrorTargetChanged =>
      'Servidor de destino foi alterado; operação cancelada';

  @override
  String get appCenterErrorConfigInvalid =>
      'Configuração de aplicativo inválida';

  @override
  String appCenterErrorPathInvalid(String field) {
    return '$field deve ser um caminho absoluto diferente da raiz (/), e não pode conter segmentos . ou ..';
  }

  @override
  String get appCenterErrorSourceInvalid =>
      'Fonte da loja de aplicativos inválida';

  @override
  String get appCenterErrorNoWebEntry =>
      'Este aplicativo não fornece uma interface web';

  @override
  String get appCenterErrorHttpsDirectRequired =>
      'Ponto de extremidade HTTPS não pode ser encapsulado via SSH; abra diretamente';

  @override
  String get appCenterErrorOpenFailed => 'Falha ao abrir a URL do aplicativo';

  @override
  String appCenterErrorGeneric(String error) {
    return 'Erro na Central de Aplicativos: $error';
  }

  @override
  String get appCenterSourceCommunityHint => 'ex.: Loja da Comunidade';

  @override
  String get appCenterSourceUrlInvalidHttps => 'Deve ser um URL HTTPS válido';

  @override
  String get appCenterDirectUrlLabel => 'URL Direto';

  @override
  String get appCenterErrorSourceRemoved =>
      'A fonte do aplicativo não está mais disponível no catálogo. Não é possível atualizar o modelo.';

  @override
  String appCenterRestoreConfirmTitle(String appName) {
    return 'Restaurar $appName?';
  }

  @override
  String appCenterRestoreConfirmMessage(String appName) {
    return 'Restaurar $appName para a configuração de implantação anterior?';
  }

  @override
  String appCenterHostPortLabel(String target) {
    return 'Porta do Host (-> $target)';
  }

  @override
  String appCenterHostMountLabel(String target) {
    return 'Caminho do host ($target)';
  }

  @override
  String get appCenterVersionLatest => 'mais recente';

  @override
  String get appCenterWaitingForLogs => 'Aguardando logs da tarefa...';

  @override
  String get appCenterNoPreviewAvailable =>
      'Nenhuma pré-visualização disponível';

  @override
  String get appCenterBlockerLocalDockerRequired =>
      'Daemon Docker local necessário (DOCKER_HOST remoto não suportado)';

  @override
  String get appCenterBlockerToolsRequired =>
      'Ferramentas necessárias ausentes no servidor (bash, setsid, flock, base64, realpath, ss, awk)';

  @override
  String get appCenterBlockerLinuxRequired =>
      'Sistema operacional Linux necessário';

  @override
  String appCenterBlockerTemplateUnsupported(String feature) {
    return 'Recurso de modelo não suportado: $feature';
  }

  @override
  String get appCenterFieldRequired => 'Este campo é obrigatório';

  @override
  String get appCenterContinueInstall => 'Continuar instalação';

  @override
  String get appCenterOperation => 'Operação';

  @override
  String get nasTabLibrary => 'Biblioteca';

  @override
  String get nasContinueWatching => 'Continuar assistindo';

  @override
  String get nasRecentPhotos => 'Fotos recentes';

  @override
  String get nasRecentVideos => 'Vídeos recentes';

  @override
  String get nasRecentMusic => 'Músicas recentes';

  @override
  String get nasDownloadPaused => 'Pausado';

  @override
  String get nasDownloadDeleteConfirmTitle => 'Excluir arquivo offline';

  @override
  String get nasDownloadDeleteConfirmMessage =>
      'Isso excluirá o arquivo offline baixado no seu dispositivo. O arquivo original no servidor remoto não será excluído.';

  @override
  String get nasDownloadDeleteConfirmButton => 'Excluir cópia offline';

  @override
  String get nasDownloadSourceChangedMessage =>
      'A configuração da origem remota mudou desde o início do download. Deseja reiniciar o download do início?';

  @override
  String get nasDownloadRestartFromScratch => 'Reiniciar do início';

  @override
  String get nasDownloadErrorSourceChanged => 'Configuração da origem alterada';

  @override
  String get nasDownloadErrorOfflineFileInvalid =>
      'O arquivo baixado está corrompido ou incompleto';

  @override
  String get nasDownloadErrorStorageFailed =>
      'Falha ao gravar no armazenamento';

  @override
  String get nasDownloadErrorHlsUnsupported =>
      'Download offline não é suportado para transmissões contínuas';

  @override
  String get nasDownloadErrorPathInvalid =>
      'Caminho de armazenamento do download inválido';

  @override
  String get nasOpenInApp => 'Abrir no aplicativo';

  @override
  String get nasOpenSystem => 'Abrir com o sistema';

  @override
  String get sftpRecentDirectories => 'Diretórios recentes';

  @override
  String get sftpNoRecentDirectories => 'Nenhum diretório recente';

  @override
  String get sftpRetryFailed => 'Repetir com falha';

  @override
  String get appCenterDiskCheckFailed =>
      'Não foi possível verificar o espaço em disco disponível no servidor';

  @override
  String get appCenterDiskFull =>
      'O disco do servidor está cheio; não é possível prosseguir';

  @override
  String get appCenterHealthInvalid =>
      'Verificação de saúde do contêiner falhou ou reportou estado inválido';

  @override
  String get appCenterPreflightSummary => 'Resumo da verificação prévia';

  @override
  String get appCenterMeasuredAvailableSpace =>
      'Espaço em disco medido disponível';

  @override
  String get appCenterUpdateComparison => 'Comparação de atualização';

  @override
  String get appCenterNoChangesDetected =>
      'Nenhuma alteração estrutural detectada';

  @override
  String get appCenterSectionImage => 'Imagem do contêiner';

  @override
  String get appCenterSectionPorts => 'Mapeamentos de portas';

  @override
  String get appCenterSectionVolumes => 'Montagens de armazenamento';

  @override
  String get appCenterSectionEnvironment => 'Variáveis de ambiente';

  @override
  String get appCenterSectionHealthcheck => 'Verificação de integridade';

  @override
  String get appCenterSectionRestart => 'Política de reinicialização';

  @override
  String get appCenterSectionServices => 'Serviços';

  @override
  String get appCenterHealthNoCheck => 'Sem verificação de integridade';

  @override
  String get appCenterHealthHealthy => 'Saudável';

  @override
  String get appCenterHealthUnhealthy => 'Com problemas';

  @override
  String get appCenterHealthStarting => 'Iniciando';

  @override
  String get appCenterNoSources => 'Nenhuma fonte de aplicativos ativada';

  @override
  String get appCenterNoMatchingApps =>
      'Nenhum aplicativo corresponde à pesquisa ou filtros';

  @override
  String get appCenterClearFilters => 'Limpar filtros';

  @override
  String get appCenterSourceLoadFailed =>
      'Falha ao carregar fonte de aplicativos';

  @override
  String get appCenterRetry => 'Tentar novamente';

  @override
  String get appCenterRecheck => 'Reverificar';

  @override
  String get appCenterRecheckTask => 'Reverificar status da tarefa';

  @override
  String get appCenterTaskNeedsInspectionTitle =>
      'Status da tarefa não confirmado';

  @override
  String get appCenterTaskNeedsInspectionMessage =>
      'Resultado da tarefa no servidor desconhecido. Verifique o status ou consulte logs antes de repetir a operação.';

  @override
  String appCenterStopConfirmTitle(String appName) {
    return 'Parar $appName?';
  }

  @override
  String appCenterStopConfirmMessage(String appName, String serverName) {
    return 'Tem certeza de que deseja parar $appName no servidor $serverName? Os contêineres em execução serão interrompidos.';
  }

  @override
  String appCenterRestartConfirmTitle(String appName) {
    return 'Reiniciar $appName?';
  }

  @override
  String appCenterRestartConfirmMessage(String appName, String serverName) {
    return 'Tem certeza de que deseja reiniciar $appName no servidor $serverName?';
  }

  @override
  String get appCenterBrowseStore => 'Navegar na loja';

  @override
  String get appCenterViewTasks => 'Ver tarefas';

  @override
  String get appCenterViewInstalled => 'Ver aplicativo instalado';

  @override
  String get appCenterRunInBackground => 'Executar em segundo plano';

  @override
  String get appCenterTaskDetails => 'Detalhes da tarefa';

  @override
  String get appCenterTaskTarget => 'Alvo';

  @override
  String get appCenterTaskDirectory => 'Diretório';

  @override
  String get appCenterTaskCreatedAt => 'Criado em';

  @override
  String appCenterTaskExitCode(int code) {
    return 'Código de saída: $code';
  }

  @override
  String get appCenterStatusRunning => 'Em execução';

  @override
  String get appCenterStatusStopped => 'Parado';

  @override
  String get appCenterStatusInstalling => 'Instalando';

  @override
  String get appCenterStatusUnknown => 'Desconhecido';

  @override
  String get appCenterEnvReady => 'Ambiente Docker e Compose pronto';

  @override
  String get appCenterEnvNotReady => 'Ambiente Docker não está pronto';

  @override
  String get appCenterEnvInspecting => 'Verificando ambiente Docker...';

  @override
  String get appCenterUninstallWholeDataRoot => 'Raiz de dados completa';

  @override
  String get appCenterUninstallWholeDataRootWarning =>
      'Isso inclui arquivos não montados e subdiretórios armazenados na raiz de dados do aplicativo.';

  @override
  String get appCenterUninstallCoveredByParent => 'Coberto pelo diretório pai';

  @override
  String get appCenterContainerNameInvalid =>
      'O nome da instância deve começar com um caractere alfanumérico e conter apenas letras, números, sublinhados, pontos e hifens (até 120 caracteres).';

  @override
  String get appCenterMainService => 'Serviço principal';

  @override
  String get appCenterContainerNamesPreview =>
      'Pré-visualização dos nomes dos contêineres';

  @override
  String get appCenterContainersRecreationNotice =>
      'Alterar os nomes dos contêineres da instância recriará os contêineres do aplicativo existentes.';

  @override
  String get remoteBrowserTitle => 'Navegador de arquivos remoto';

  @override
  String get remoteBrowserSelectDirectory => 'Selecionar diretório';

  @override
  String get remoteBrowserSelectCurrentDirectory =>
      'Selecionar diretório atual';

  @override
  String get remoteBrowserSearchHint => 'Pesquisar arquivos e pastas...';

  @override
  String get remoteBrowserNoEntries =>
      'Nenhum arquivo ou diretório correspondente encontrado';

  @override
  String get remoteBrowserEmptyDirectory => 'Este diretório está vazio';

  @override
  String remoteBrowserSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens selecionados',
      one: '1 item selecionado',
    );
    return '$_temp0';
  }

  @override
  String get remoteBrowserParentDirectory => 'Diretório pai';

  @override
  String get remoteBrowserLibrariesTitle => 'Bibliotecas de mídia';

  @override
  String get remoteBrowserDisconnected =>
      'Conexão remota perdida ou indisponível.';

  @override
  String get remoteBrowserTargetChanged =>
      'O ambiente de destino ou o servidor ativo foi alterado.';

  @override
  String get remoteBrowserPathInvalid =>
      'O caminho solicitado é inválido ou não pode ser acessado.';

  @override
  String get remoteBrowserPathOutsideRoot =>
      'O caminho solicitado está fora do diretório raiz permitido.';

  @override
  String get remoteBrowserPathDisplayMode => 'Modo de exibição de caminho';

  @override
  String get remoteBrowserPathDisplayModeScroll => 'Rolagem horizontal';

  @override
  String get remoteBrowserPathDisplayModeCollapsed => 'Recolher caminho';

  @override
  String get remoteBrowserEntryUnavailable =>
      'A entrada selecionada está indisponível ou inválida.';

  @override
  String get nasBrowseUnavailable =>
      'O serviço de navegação do NAS está indisponível no momento.';

  @override
  String get nasInvalidDirectoryEntry =>
      'Entrada de diretório inválida encontrada ao navegar no NAS.';

  @override
  String get nasInvalidLibraryResponse =>
      'Resposta da biblioteca de mídia inválida ou malformada.';

  @override
  String get nasScanFilterUnresolved =>
      'Não foi possível resolver o caminho do filtro de verificação.';

  @override
  String get nasSourceSaveIncomplete =>
      'O salvamento anterior da fonte persistiu apenas parcialmente. Digite as credenciais novamente e salve com sucesso antes de navegar.';

  @override
  String get terminalHistoryTitle => 'Histórico de sessões';

  @override
  String get terminalHistoryButton => 'Histórico de sessões';

  @override
  String get terminalHistoryEmpty =>
      'Nenhum histórico de sessões. Sessões persistentes requerem tmux no servidor remoto.';

  @override
  String get terminalHistoryRefresh => 'Atualizar histórico';

  @override
  String get terminalStartupSession => 'Sessão de inicialização';

  @override
  String get terminalStartupSessionSubtitle =>
      'Escolha qual sessão abre ao iniciar o terminal';

  @override
  String get terminalStartupSessionFresh => 'Nova sessão (Padrão)';

  @override
  String get terminalStatusOpen => 'Aberta';

  @override
  String get terminalStatusAvailable => 'Disponível';

  @override
  String get terminalStatusEnded => 'Encerrada';

  @override
  String get terminalStatusOffline => 'Offline';

  @override
  String get terminalDefaultBadge => 'Padrão';

  @override
  String get terminalLegacyBadge => 'Não importada';

  @override
  String get terminalRestoreSession => 'Restaurar sessão';

  @override
  String get terminalSetDefault => 'Definir como padrão';

  @override
  String get terminalClearDefault => 'Limpar padrão';

  @override
  String get terminalRename => 'Renomear sessão';

  @override
  String get terminalRenameDialogTitle => 'Renomear sessão';

  @override
  String get terminalRenameInputLabel => 'Nome da sessão';

  @override
  String get terminalTitleInvalid =>
      'O título deve ter de 1 a 64 caracteres sem caracteres de controle';

  @override
  String get terminalErrorHistoryLoadFailed =>
      'Falha ao carregar histórico do terminal';

  @override
  String get terminalErrorHistorySaveFailed =>
      'Falha ao salvar histórico do terminal';

  @override
  String get terminalErrorHistoryRefreshFailed =>
      'Falha ao atualizar histórico do terminal';

  @override
  String get terminalErrorStartFailed => 'Falha ao iniciar sessão do terminal';

  @override
  String get terminalErrorRestoreFailed =>
      'Falha ao restaurar sessão do terminal';

  @override
  String get terminalErrorDefaultSaveFailed =>
      'Falha ao salvar sessão de inicialização padrão';

  @override
  String get terminalErrorCommandFailed =>
      'Falha ao executar comando no terminal';

  @override
  String get terminalErrorTitleInvalid =>
      'Título de sessão inválido (necessário 1–64 caracteres)';

  @override
  String get terminalErrorSshDisconnected => 'Conexão SSH perdida';

  @override
  String get terminalNoticeDefaultMissing =>
      'A sessão padrão estava ausente ou encerrada; um novo terminal foi aberto';

  @override
  String get terminalNoticeSessionMissing =>
      'A sessão tmux solicitada não existe mais no servidor remoto';

  @override
  String get terminalNoticePlainInterrupted =>
      'Conexão perdida. Processos de shell sem tmux não puderam ser retomados';

  @override
  String get terminalHistoryDeleteDialogTitle => 'Excluir histórico de sessão';

  @override
  String get terminalHistoryTerminateRemote =>
      'Também encerrar a sessão no servidor remoto';

  @override
  String get terminalHistoryTerminateConfirmTitle =>
      'Encerrar a sessão remota?';

  @override
  String get terminalHistoryTerminateConfirmMessage =>
      'Isso encerrará a sessão tmux remota e interromperá todos os processos em execução nela.';

  @override
  String get terminalErrorHistoryDeleteFailed =>
      'Falha ao excluir o histórico do terminal';

  @override
  String get terminalErrorHistoryTerminateFailed =>
      'Falha ao encerrar a sessão remota';

  @override
  String get terminalErrorTargetChanged =>
      'O servidor de destino foi alterado. Reabra a sessão no servidor atual.';

  @override
  String get terminalModeStandard =>
      'Terminal SSH padrão (padrão, sem histórico)';

  @override
  String get terminalModeTmux =>
      'Terminal tmux (mantém sessão remota e histórico)';

  @override
  String get terminalModeSaveFailed =>
      'Falha ao salvar o modo do terminal, tente novamente';

  @override
  String get sftpNew => 'Novo';

  @override
  String get terminalHistorySearchHint => 'Pesquisar nome da sessão…';

  @override
  String get configMigrationBoundaryNote =>
      'Apenas configuração do dispositivo local. Os dados no servidor remoto não são alterados.';

  @override
  String get configMigrationSubtitle =>
      'Exportar ou importar configurações locais e perfis de servidor';

  @override
  String get installAppId => 'ID do aplicativo';

  @override
  String get installArchitecture => 'Arquitetura';

  @override
  String get installPlatform => 'Plataforma';

  @override
  String get settingsAboutPrivacyDesc =>
      'Versão, licenças de código aberto e política de privacidade';

  @override
  String get settingsAccentColorDesc =>
      'Personalizar cores de destaque do tema';

  @override
  String get settingsSearchHint => 'Pesquisar configurações…';

  @override
  String get settingsSearchNoResults =>
      'Nenhuma configuração correspondente encontrada';

  @override
  String get settingsSecurityDesc =>
      'Hosts conhecidos, credenciais e ações de segurança';

  @override
  String get agentExpandDetails => 'Detalhes';

  @override
  String get agentCollapseDetails => 'Recolher';

  @override
  String get transferPauseAll => 'Pausar tudo';

  @override
  String get transferResumePaused => 'Retomar pausadas';

  @override
  String get transferFilterAll => 'Todas';

  @override
  String get transferFilterActive => 'Ativas';

  @override
  String get transferFilterFailed => 'Com falha';

  @override
  String get transferFilterCompleted => 'Concluídas';

  @override
  String get transferPauseReasonUser => 'Pausado pelo usuário';

  @override
  String get transferPauseReasonNetwork =>
      'Pausado devido a desconexão de rede';

  @override
  String get transferPauseReasonAppRestart =>
      'Pausado após reinicialização do app';

  @override
  String get transferRemotePath => 'Caminho remoto';

  @override
  String get transferLocalPath => 'Caminho local';

  @override
  String get transferErrorDetail => 'Detalhe do erro';

  @override
  String get chatFailureKindAuth => 'Autenticação necessária';

  @override
  String get chatFailureKindModelUnavailable => 'Modelo indisponível';

  @override
  String get chatFailureKindConnection => 'Falha na conexão';

  @override
  String get chatFailureKindHistory => 'Falha no histórico';

  @override
  String get chatFailureKindOther => 'Falha na solicitação';

  @override
  String get chatFailureActionLogin => 'Entrar';

  @override
  String get chatFailureActionRunSettings => 'Configurações do modelo';

  @override
  String get chatFailureActionReconnect => 'Reconectar';

  @override
  String get chatFailureActionReloadHistory => 'Tentar novamente';

  @override
  String get chatFailureActionDetails => 'Detalhes';

  @override
  String get sftpConfigureToolbar => 'Configurar barra de ferramentas';

  @override
  String get sftpConfigureToolbarDesc =>
      'Escolha as ações a serem fixadas na barra de ferramentas. As demais aparecerão no menu Mais.';

  @override
  String get sftpToolbarPreferenceSaveFailed =>
      'Falha ao salvar preferências da barra de ferramentas';

  @override
  String get sftpToolbarActionView => 'Alternar visualização';

  @override
  String agentUpdateNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count atualizações de agente disponíveis',
      one: '1 atualização de agente disponível',
    );
    return '$_temp0';
  }

  @override
  String get agentUpdateViewAction => 'Visualizar';

  @override
  String get agentUpdateCheckAll => 'Verificar atualizações';

  @override
  String get agentUpdateCheck => 'Verificar atualização';

  @override
  String get agentUpdateChecking => 'Verificando...';

  @override
  String get agentUpdateAvailable => 'Atualização disponível';

  @override
  String get agentUpdateUpToDate => 'Atualizado';

  @override
  String get agentUpdateDialogTitle => 'Atualizar agente';

  @override
  String get agentUpdateConfirmButton => 'Confirmar e atualizar';

  @override
  String get agentUpdateCancelButton => 'Cancelar';

  @override
  String get agentUpdateTargetServer => 'Servidor';

  @override
  String get agentUpdateTargetEnvironment => 'Ambiente';

  @override
  String get agentUpdateTargetIdentity => 'Identidade';

  @override
  String get agentUpdateCommandPreview => 'Pré-visualização do comando';

  @override
  String get agentUpdateClaudeMigrationNotice =>
      'Esta atualização migra o adaptador Claude antigo (claude-code-acp) para o adaptador oficial claude-agent-acp. O histórico e as credenciais existentes são preservados.';

  @override
  String get agentUpdateAgyNotice =>
      'A CLI AgY é atualizada por meio de seu canal de lançamento estável oficial. A versão instalada pode ser mais recente do que o instantâneo exibido na confirmação.';

  @override
  String get agentUpdateLogs => 'Logs de atualização';

  @override
  String get agentUpdateCopyLog => 'Copiar log';

  @override
  String get agentUpdateLogCopied =>
      'Log de atualização copiado para a área de transferência';

  @override
  String get agentUpdateSuccess => 'Agente atualizado com sucesso';

  @override
  String get agentUpdateFailed => 'Falha na atualização';

  @override
  String get agentUpdateInterrupted =>
      'A atualização foi interrompida ou a conexão foi perdida. Verifique a versão real antes de tentar novamente; novas tentativas automáticas estão desativadas por segurança.';

  @override
  String get agentUpdateInProgress =>
      'Uma atualização está em andamento neste servidor.';

  @override
  String get agentUpdateBusy =>
      'O servidor ou agente está ocupado. Aguarde a conclusão das tarefas ativas.';

  @override
  String get agentUpdateVersionUnknown => 'Desconhecido';

  @override
  String get agentUpdateSource => 'Origem';

  @override
  String get agentUpdateLastChecked => 'Última verificação';

  @override
  String get agentUpdateNeverChecked => 'Nunca verificado';

  @override
  String get agentUpdateCodexMigrationTitle =>
      'Instalar novo adaptador e alternar este agente';

  @override
  String get agentUpdateCodexMigrationNotice =>
      'O programa e as configurações existentes serão preservados. Um novo adaptador independente é instalado e a conexão é alternada, com reversão segura em caso de problemas.';

  @override
  String get agentUpdateReplacementCommand => 'Comando substituto';
}
