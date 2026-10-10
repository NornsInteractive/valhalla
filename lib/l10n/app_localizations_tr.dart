// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'Yapay Zeka Destekli Sunucu ve Ajan Yönetimi';

  @override
  String get navAiChat => 'AI Sohbeti';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'SFTP Dosyaları';

  @override
  String get navCommands => 'Komutlar';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get serverConnected => 'Bağlandı';

  @override
  String get serverOnline => 'Çevrimiçi';

  @override
  String get serverOffline => 'Çevrimdışı';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Yeniden Bağlan';

  @override
  String get disconnect => 'Bağlantıyı Kes';

  @override
  String get quickDisconnect => 'Hızlı Bağlantı Kes';

  @override
  String get newSession => 'Yeni Oturum';

  @override
  String get historySessions => 'Oturum Geçmişi';

  @override
  String get switchAgent => 'Ajan Değiştir';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Aktif Ajan';

  @override
  String get inputPromptHint =>
      'Ajandan teşhis koymasını, araç çalıştırmasını veya komut yazmasını isteyin... (Göndermek için Enter)';

  @override
  String get thinking => 'Düşünme Süreci';

  @override
  String get executionPlan => 'Yürütme Planı';

  @override
  String get toolCall => 'Araç Çağrısı';

  @override
  String get toolStatusPending => 'Beklemede';

  @override
  String get toolStatusRunning => 'Çalışıyor...';

  @override
  String get toolStatusCompleted => 'Tamamlandı';

  @override
  String get toolStatusFailed => 'Başarısız';

  @override
  String get permissionRequired => 'İzin Gerekli';

  @override
  String get permissionDescription =>
      'Ajan sunucuda şu komutu çalıştırmak istiyor:';

  @override
  String get permissionReject => 'Reddet';

  @override
  String get permissionAllowOnce => 'Bir Kez İzin Ver';

  @override
  String get permissionAllowAlways => 'Her Zaman İzin Ver';

  @override
  String get quickTroubleshootCpu => 'Yüksek CPU Sorununu Gider';

  @override
  String get quickDockerHealth => 'Docker Sağlık Kontrolü';

  @override
  String get quickCleanCache => 'Sistem Önbelleğini Temizle';

  @override
  String get quickNginxLogs => 'Nginx Hata Günlüklerini Kontrol Et';

  @override
  String get terminalNewTab => 'Yeni Sekme';

  @override
  String get terminalCloseTab => 'Sekmeyi Kapat';

  @override
  String get terminalClear => 'Temizle';

  @override
  String get terminalQuickCmds => 'Komut Paleti';

  @override
  String get terminalPaste => 'Yapıştır';

  @override
  String get sftpCurrentPath => 'Mevcut Yol';

  @override
  String get sftpUpload => 'Yükle';

  @override
  String get sftpNewFolder => 'Yeni Klasör';

  @override
  String get sftpNewFile => 'Yeni Dosya';

  @override
  String get sftpRefresh => 'Yenile';

  @override
  String get sftpSearchHint => 'Dosya veya klasör ara...';

  @override
  String get sftpEmpty => 'Dizin boş';

  @override
  String get sftpFileName => 'Ad';

  @override
  String get sftpFileSize => 'Boyut';

  @override
  String get sftpFilePerm => 'İzinler';

  @override
  String get sftpFileModified => 'Değiştirilme';

  @override
  String get cmdCategoryDocker => 'DOCKER KONTEYNER YIĞINI';

  @override
  String get cmdCategorySystem => 'SİSTEM BAKIMI';

  @override
  String get cmdCategoryNetwork => 'AĞ & PORTLAR';

  @override
  String get cmdExecute => 'Çalıştır';

  @override
  String get cmdDangerous => 'Tehlikeli Komut';

  @override
  String get cmdDangerousWarning =>
      'Bu işlem geri alınamaz ve hizmet kesintisine neden olabilir. Devam etmek istediğinizden emin misiniz?';

  @override
  String get cmdParamRequired => 'Parametre Girişi Gerekli';

  @override
  String get cmdConfirm => 'Onayla ve Çalıştır';

  @override
  String get cmdCancel => 'İptal';

  @override
  String get settingsAppearance => 'Görünüm ve Temalar';

  @override
  String get settingsThemeMode => 'Tema Modu';

  @override
  String get themeSystem => 'Sistemi Takip Et';

  @override
  String get themeSystemDesc => 'Otomatik Uyumlu';

  @override
  String get themeLight => 'Açık Mod';

  @override
  String get themeLightDesc => 'Yüksek Işıklı Kağıt';

  @override
  String get themeDark => 'Geek Koyu';

  @override
  String get themeDarkDesc => 'Derin Kömür';

  @override
  String get themeAmoled => 'AMOLED Siyah';

  @override
  String get themeAmoledDesc => 'Saf Siyah 0x000000';

  @override
  String get settingsAccentColor => 'Tema Vurgu Rengi';

  @override
  String get accentCyberEmerald => 'Siber Zümrüt';

  @override
  String get accentTechBlue => 'Teknoloji Mavisi';

  @override
  String get accentElectricViolet => 'Elektrik Menekşesi';

  @override
  String get accentCrimsonRed => 'Kızıl Kırmızı';

  @override
  String get accentAmberOrange => 'Kehribar Turuncusu';

  @override
  String get settingsLanguage => 'Dil ve Bölge';

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
  String get settingsAiOps => 'AI Ops ve Motor';

  @override
  String get settingsSecurity => 'Bağlantı ve Güvenlik';

  @override
  String get settingsKnownHosts => 'Bilinen Ana Bilgisayar Anahtarları';

  @override
  String get settingsClearStorage => 'Kimlik Bilgilerini Sıfırla';

  @override
  String get settingsResetDefault => 'Varsayılanlara Sıfırla';

  @override
  String get settingsTerminalUseTmux => 'Kalıcı Oturumlar (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Terminal oturumlarını uzak sunucuda tmux içinde çalıştırın';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Bağlantı kesildikten sonra terminal çıktısını korur. Uzak sunucuda tmux gerektirir. Değişiklikler yeni açılan terminal sekmelerine uygulanır.';

  @override
  String get settingsTerminalFontSize => 'Terminal Yazı Tipi Boyutu';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'SSH ve CLI terminal yazı tipi boyutunu ayarlar';

  @override
  String get version => 'Sürüm';

  @override
  String get addServer => 'Sunucu Ekle';

  @override
  String get editServer => 'Sunucuyu Düzenle';

  @override
  String get serverName => 'Sunucu Adı';

  @override
  String get serverHost => 'Ana Bilgisayar / IP';

  @override
  String get serverPort => 'Port';

  @override
  String get serverUsername => 'Kullanıcı Adı';

  @override
  String get serverAuthType => 'Kimlik Doğrulama Türü';

  @override
  String get serverPassword => 'Şifre';

  @override
  String get serverPrivateKey => 'Özel Anahtar';

  @override
  String get serverSave => 'Sunucuyu Kaydet';

  @override
  String get serverDelete => 'Sunucuyu Sil';

  @override
  String get fileEditor => 'Dosya Düzenleyici';

  @override
  String get fileEditorSave => 'Değişiklikleri Kaydet';

  @override
  String get fileSavedSuccess => 'Dosya başarıyla kaydedildi';

  @override
  String get addCommand => 'Yeni Komut';

  @override
  String get commandTitle => 'Komut Başlığı';

  @override
  String get commandContent => 'Komut Dizesi';

  @override
  String get commandCategory => 'Kategori';

  @override
  String get commandDescription => 'Açıklama';

  @override
  String get save => 'Kaydet';

  @override
  String get delete => 'Sil';

  @override
  String get cancel => 'İptal';

  @override
  String get confirm => 'Onayla';

  @override
  String get cmdExecutionChannel => 'Yürütme Kanalı';

  @override
  String get cmdChannelTerminal => 'Doğrudan SSH Terminaline';

  @override
  String get cmdChannelTerminalDesc =>
      'Komut doğrudan aktif terminal oturumuna yazılır';

  @override
  String get cmdChannelBackground => 'Arka Plan Oturumunda Çalıştır';

  @override
  String get cmdChannelBackgroundDesc =>
      'SSH giriş kabuğu aracılığıyla yürütülür ve çıktıyı yakalar';

  @override
  String get cmdInjectedToTerminal => 'Komut terminale gönderildi';

  @override
  String get cmdExecutionCompleted => 'Yürütme Tamamlandı';

  @override
  String get cmdExecutionFailed => 'Yürütme Başarısız';

  @override
  String get cmdExecutingRemote => 'Uzak komut çalıştırılıyor...';

  @override
  String get cmdClose => 'Kapat';

  @override
  String get navDashboard => 'Gösterge Paneli';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Sistem';

  @override
  String get navMore => 'Daha Fazla';

  @override
  String get dashboardTitle => 'Sunucu Gösterge Paneli';

  @override
  String get metricsCpu => 'CPU Kullanımı';

  @override
  String get metricsMemory => 'Bellek Kullanımı';

  @override
  String get metricsLoadAvg => 'Yük Ortalaması';

  @override
  String get metricsUptime => 'Sistem Çalışma Süresi';

  @override
  String get metricsRootDisk => 'Kök Disk Kullanımı';

  @override
  String get quickActions => 'Hızlı Gezinme';

  @override
  String get activeServerStatus => 'Aktif Sunucu Durumu';

  @override
  String get noServerSelected =>
      'Şu anda seçili sunucu yok. Lütfen önce bir sunucu seçin.';

  @override
  String get serverDisconnected => 'Bağlantı Kesildi';

  @override
  String get serverConnecting => 'Bağlanıyor...';

  @override
  String get connectNow => 'Şimdi Bağlan';

  @override
  String get serverSpecs => 'Sunucu Bilgileri ve Özellikleri';

  @override
  String get dockerTitle => 'Docker Konteynerleri';

  @override
  String get dockerSearchHint => 'Konteynerleri ada veya imaja göre ara...';

  @override
  String get dockerFilterAll => 'Tümü';

  @override
  String get dockerFilterRunning => 'Çalışıyor';

  @override
  String get dockerFilterExited => 'Çıkış Yapıldı';

  @override
  String get dockerFilterPaused => 'Duraklatıldı';

  @override
  String get dockerActionStart => 'Başlat';

  @override
  String get dockerActionStop => 'Durdur';

  @override
  String get dockerActionRestart => 'Yeniden Başlat';

  @override
  String get dockerActionPause => 'Duraklat';

  @override
  String get dockerActionUnpause => 'Devam Ettir';

  @override
  String get dockerActionRm => 'Kaldır';

  @override
  String get dockerActionLogs => 'Günlükler';

  @override
  String get dockerActionInspect => 'İncele';

  @override
  String get dockerLogsTitle => 'Konteyner Günlükleri';

  @override
  String get dockerInspectTitle => 'Konteyner İnceleme';

  @override
  String get dockerNoContainers => 'Sunucuda konteyner bulunamadı';

  @override
  String get dockerEmptyRunning => 'Çalışan konteyner yok';

  @override
  String get dockerPorts => 'Portlar';

  @override
  String get dockerCreated => 'Oluşturulma';

  @override
  String get dockerImage => 'İmaj';

  @override
  String get systemTitle => 'Süreçler ve Hizmetler';

  @override
  String get tabProcesses => 'Süreçler';

  @override
  String get tabServices => 'Systemd Hizmetleri';

  @override
  String get processSearchHint => 'Süreç adına veya PID\'ye göre ara...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEM';

  @override
  String get processStat => 'Durum';

  @override
  String get processCommand => 'Komut';

  @override
  String get processTerminate => 'Sonlandır (SIGTERM)';

  @override
  String get processForceKill => 'Zorla Sonlandır (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Sistem başlatma sürecini sonlandırma reddedildi (PID <= 1)';

  @override
  String get serviceSearchHint => 'Hizmetleri ada göre ara...';

  @override
  String get serviceName => 'Hizmet';

  @override
  String get serviceDescription => 'Açıklama';

  @override
  String get serviceStatus => 'Durum';

  @override
  String get serviceStartup => 'Başlangıç';

  @override
  String get serviceActionStart => 'Başlat';

  @override
  String get serviceActionStop => 'Durdur';

  @override
  String get serviceActionRestart => 'Yeniden Başlat';

  @override
  String get serviceActionReload => 'Yeniden Yükle';

  @override
  String get serviceActionEnable => 'Etkinleştir';

  @override
  String get serviceActionDisable => 'Devre Dışı Bırak';

  @override
  String get serviceNoServices => 'Systemd hizmeti bulunamadı';

  @override
  String get riskDangerTitle => 'Yüksek Riskli İşlem Onayı';

  @override
  String get riskWarningTitle => 'İşlem Uyarısı Onayı';

  @override
  String get riskSafeTitle => 'İşlemi Onayla';

  @override
  String get riskIrreversibleWarning =>
      'Bu işlem YÜKSEK RİSKLİ olarak sınıflandırılmıştır ve geri alınamaz. Veri kaybına veya hizmet kesintisine neden olabilir.';

  @override
  String get riskWarningDescription =>
      'Bu işlem aktif hizmetleri etkileyebilir veya süreçleri yeniden başlatabilir. Dikkatle devam edin.';

  @override
  String get riskCommandPreview => 'Komut Önizlemesi';

  @override
  String get riskConfirmButton => 'Onayla ve Devam Et';

  @override
  String get riskCancelButton => 'İptal';

  @override
  String get stateLoading => 'Uzak veriler yükleniyor...';

  @override
  String get stateOffline => 'Sunucu çevrimdışı';

  @override
  String get stateOfflineDesc =>
      'Kaynakları yönetmek ve metrikleri aktarmak için aktif bir SSH bağlantısı kurun.';

  @override
  String get stateError => 'Bir hata oluştu';

  @override
  String get stateRetry => 'Tekrar Dene';

  @override
  String get stateEmpty => 'Öğe bulunamadı';

  @override
  String get inspectorTitle => 'Denetçi';

  @override
  String get inspectorClose => 'Kapat';

  @override
  String get inspectorDetails => 'İnceleme Ayrıntıları';

  @override
  String get selectServerTitle => 'Hedef Sunucuyu Seçin';

  @override
  String get sshDisconnectedSuccess => 'SSH bağlantısı kesildi';

  @override
  String get trustHostFingerprintTitle =>
      'Ana Bilgisayar Parmak İzine Güvenilsin mi?';

  @override
  String get trustAndConnect => 'Güven ve Bağlan';

  @override
  String get reject => 'Reddet';

  @override
  String get confirmDeleteServerTitle => 'Sunucuyu Sil';

  @override
  String get noServersFound => 'Henüz yapılandırılmış sunucu yok';

  @override
  String get agentNotReadyError =>
      'Seçilen ajan hazır değil. Lütfen ortamını ve yapılandırmasını doğrulayın.';

  @override
  String get sshDisconnectedError =>
      'SSH bağlantısı kesildi. AI Ops kullanmadan önce lütfen bir sunucuya bağlanın.';

  @override
  String get noAgentAvailable => 'Kullanılabilir Ajan Yok';

  @override
  String get noAgentAvailablePrompt =>
      'Aktif ajan bulunmuyor. Lütfen önce bir ajanı yapılandırın veya hazırlayın.';

  @override
  String get noAgentAvailableHint =>
      'Sohbet etmek için kullanılabilir bir ajan seçin veya yapılandırın...';

  @override
  String get manageAgents => 'Ajanları Yönet';

  @override
  String get noReadyAgentsTitle => 'Hazır Ajan Yok';

  @override
  String get noReadyAgentsDesc =>
      'Bu sunucudaki hiçbir ajan ortam kontrollerinden geçemedi.';

  @override
  String get agentStatusReady => 'Hazır';

  @override
  String get agentStatusChecking => 'Kontrol ediliyor...';

  @override
  String get agentStatusCliMissing => 'Kurulum algılanmadı';

  @override
  String get agentStatusAcpMissing => 'ACP bileşeni algılanmadı';

  @override
  String get agentStatusNotLoggedIn => 'Giriş Yapılmadı';

  @override
  String get agentStatusError => 'Hata';

  @override
  String get agentStatusUnknown => 'Bilinmiyor';

  @override
  String get agentActionInstall => 'Yükle';

  @override
  String get agentActionLogin => 'Giriş Yap';

  @override
  String get agentActionRefresh => 'Durumu Kontrol Et';

  @override
  String get noConfiguredAgents => 'Bu sunucuda yapılandırılmış ajan yok';

  @override
  String get agentManagementTitle => 'Ajan Yönetimi';

  @override
  String get settingsAgentManagement => 'Ajan Yönetimi';

  @override
  String get settingsAgentManagementSubtitle =>
      'Mevcut sunucu için ACP Ajanlarını yapılandırın, algılayın ve yönetin';

  @override
  String get addAgentButton => 'Ajan Ekle';

  @override
  String get noServerSelectedForAgents =>
      'Sunucu seçilmedi. Lütfen önce ana arayüzden bir sunucu seçin.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH bağlantısı kesildi. Bağlantı kurulana kadar algılama, yükleme ve giriş devre dışıdır.';

  @override
  String get noAgentsConfiguredTitle => 'Yapılandırılmış Ajan Yok';

  @override
  String get noAgentsConfiguredDesc =>
      'Bu sunucuda AI Ops\'u etkinleştirmek için Claude Code, Codex, OpenCode, AGY veya özel ACP ajanları ekleyin.';

  @override
  String get agentPresetLabel => 'Hazır Ayar';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Özel';

  @override
  String get agentNameLabel => 'Ajan Adı';

  @override
  String get agentNameHint => 'örn. Production Codex';

  @override
  String get agentDescriptionLabel => 'Açıklama';

  @override
  String get agentDescriptionHint => 'Ajanın kısa açıklaması';

  @override
  String get agentCliCommandLabel => 'CLI Algılama Komutu';

  @override
  String get agentCliCommandHint => 'örn. claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP Başlatma Komutu';

  @override
  String get agentAcpCommandHint => 'örn. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Kurulum Komutu (İsteğe Bağlı)';

  @override
  String get agentInstallCommandHint => 'örn. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Giriş Kontrol Komutu (İsteğe Bağlı)';

  @override
  String get agentLoginCheckCommandHint => 'örn. codex --version';

  @override
  String get agentLoginCommandLabel => 'Giriş Komutu (İsteğe Bağlı)';

  @override
  String get agentLoginCommandHint => 'örn. codex login';

  @override
  String get agentSaveButton => 'Kaydet ve Algıla';

  @override
  String get agentCliRequired => 'CLI algılama komutu zorunludur';

  @override
  String get agentAcpRequired => 'ACP başlatma komutu zorunludur';

  @override
  String get agentNameRequired => 'Ajan adı zorunludur';

  @override
  String get confirmInstallAgentTitle => 'Ajan Kurulumunu Onayla';

  @override
  String get confirmLoginAgentTitle => 'Ajan Girişini Onayla';

  @override
  String get agentCommandRiskWarning =>
      'Bu komut geçerli kullanıcı ayrıcalıklarıyla doğrudan uzak sunucuda yürütülecektir. Paketler yükleyebilir veya sistem ortamlarını değiştirebilir.';

  @override
  String get targetServerLabel => 'Hedef Sunucu';

  @override
  String get commandPreviewLabel => 'Komut Önizlemesi';

  @override
  String get executeButton => 'Yürüt';

  @override
  String get deleteAgentTitle => 'Ajanı Sil';

  @override
  String get deleteAgentConfirm => 'Sil';

  @override
  String get agentStatusCheckingDesc => 'Uzak sunucuda ortam algılanıyor...';

  @override
  String get agentStatusInstalling => 'Sunucuda bağımlılıklar yükleniyor...';

  @override
  String get agentStatusLoggingIn => 'Sunucuda giriş komutu yürütülüyor...';

  @override
  String get agentNoLoginCheckProvided => 'Giriş kontrol komutu belirtilmedi';

  @override
  String get agentInstallPrompt =>
      'Kurulum algılanmadı. Şimdi otomatik olarak kurulsun mu?';

  @override
  String get agentActionAutoInstall => 'Otomatik Kur';

  @override
  String get agentLoginPrompt => 'Giriş yapılmadı. Şimdi giriş yapılsın mı?';

  @override
  String get agentActionExecuteLogin => 'Şimdi Giriş Yap';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Bu sunucudaki ajanlar henüz kurulu veya hazır değil. Lütfen ortam kurulumunu yönetin ve tamamlayın.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Sohbete başlamak için bir ajanı kurun ve hazırlayın...';

  @override
  String get agentAcpInstallPrompt =>
      'ACP bileşeni algılanmadı. Şimdi otomatik kurulsun mu?';

  @override
  String get agentInstallCommandAcpLabel => 'ACP Kurulum Komutu (İsteğe Bağlı)';

  @override
  String get agentInstallCommandAcpHint =>
      'örn. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Bu ajan için yapılandırılmış kurulum komutu yok';

  @override
  String get agentInstallLogTitle => 'Kurulum çıktısı';

  @override
  String get agentInstallLogEmpty => 'Kurulum çıktısı bekleniyor…';

  @override
  String get agentInstallLogTruncated =>
      'Çıktı çok uzun; en son satırlar gösteriliyor';

  @override
  String get agentAcpOptional => 'İsteğe bağlı; yalnızca CLI için boş bırakın';

  @override
  String get acpStreaming => 'ACP Akışı...';

  @override
  String get aiOpsAgentTitle => 'Valhalla AI Ops Ajanı';

  @override
  String get aiOpsEmptySubtitle => 'SSH Kanalı üzerinden ACP stdio ile bağlı';

  @override
  String get agentAuthRequiredTitle => 'Kimlik Doğrulama Gerekli';

  @override
  String get agentAuthRequiredDesc =>
      'Ajan, isteğinizi işlemeden önce kimlik doğrulaması gerektirir.';

  @override
  String get agentAuthMethodLabel => 'Kimlik Doğrulama Yöntemi';

  @override
  String get agentAuthNoMethodsNotice =>
      'Ajan bir giriş yöntemi sağlamadı. Lütfen sunucudaki yapılandırmasını kontrol edin.';

  @override
  String get agentAuthProceedButton => 'Giriş Yap';

  @override
  String get agentAuthCancelButton => 'İptal';

  @override
  String get agentAuthRetryHint =>
      'Giriş yaptıktan sonra mesajınızı tekrar gönderin.';

  @override
  String get agentAuthRequiredError =>
      'Kimlik doğrulama gerekli. Devam etmek için lütfen giriş yapın.';

  @override
  String get agentLoginTerminalTitle => 'Etkileşimli Giriş Terminali';

  @override
  String get agentLoginTerminalSubtitle =>
      'Aşağıdaki terminalde oturum açma adımlarını tamamlayın. Gösterilen URL veya kod istemlerini izleyin.';

  @override
  String get agentLoginTerminalRunning =>
      'Giriş komutu terminalde çalışıyor...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH bağlantısı kesildi. Giriş oturumu kesintiye uğradı.';

  @override
  String get agentLoginTerminalRetry => 'Terminali Yeniden Bağla';

  @override
  String get agentLoginTerminalFinish => 'Tamamla ve Doğrula';

  @override
  String get agentLoginTerminalClose => 'Kapat';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Ajan kod yapıştırmayı gerektiriyorsa, yapıştırmak için terminale uzun basın veya PASTE tuşunu kullanın.';

  @override
  String get agentLoginTerminalUrlLabel => 'Giriş URL\'si algılandı';

  @override
  String get agentLoginTerminalUrlCopy => 'Bağlantıyı kopyala';

  @override
  String get agentLoginTerminalUrlCopied => 'Giriş URL\'si panoya kopyalandı';

  @override
  String get agentLoginTerminalCopyAll => 'Tüm çıktıyı kopyala';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Terminal çıktısı panoya kopyalandı';

  @override
  String get sshStatusReconnected => 'Bağlantı geri yüklendi';

  @override
  String get sshStatusDisconnectedRetrying =>
      'Bağlantı kesildi, yeniden deneniyor';

  @override
  String get sshStatusDisconnectedManual => 'Bağlantı kesildi';

  @override
  String get sshStatusHostKeyChanged =>
      'Ana bilgisayar anahtarı değişti — bağlantı reddedildi';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla oturumlarınızı canlı tutuyor';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux bulunamadı — oturumlar bağlantı kopmasına dayanamaz';

  @override
  String get terminalTmuxSessionRestored => 'Terminal oturumu geri yüklendi';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Mosh\'u etkinleştir — bağlantı kopmalarına ve IP değişikliklerine dayanan gezici terminal';

  @override
  String get moshServerPathLabel => 'mosh-server yolu';

  @override
  String get moshPortRangeLabel => 'UDP port aralığı';

  @override
  String get moshNewSession => 'Yeni Mosh Oturumu';

  @override
  String get moshNotInstalled =>
      'Uzak sunucuda mosh-server bulunamadı. Şununla kurun: sudo apt install mosh (Debian/Ubuntu) veya sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Mosh oturumu başlatılamadı: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Mosh bağlantısı zaman aşımına uğradı — UDP trafiğinin güvenlik duvarı tarafından engellenmediğini doğrulayın.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Ajan oturumu geri yüklendi';

  @override
  String get acpSessionRestartNotice =>
      'Ajan oturumu yeniden başlatıldı — önceki bağlam kullanılamıyor';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Uzak Sunucuya tmux Kurulsun mu?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'Bağlantı kesilmelerinde terminal oturumlarını korumak için tmux gereklidir. Şimdi kurmak ister misiniz?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Yürütülecek komut:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Uzak sunucuda desteklenen bir paket yöneticisi algılanmadı. Lütfen tmux\'u manuel olarak kurun.';

  @override
  String get terminalTmuxInstallFailed =>
      'tmux kurulumu başarısız oldu. Lütfen sunucu izinlerini ve ağı doğrulayın.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH bağlantısı kesildi. tmux kurmak için lütfen yeniden bağlanın.';

  @override
  String get terminalTmuxInstallInstalling => 'tmux kuruluyor...';

  @override
  String get terminalTmuxInstallConfirm => 'tmux Kur';

  @override
  String get terminalTmuxInstallSkip => 'Atla (Düz Kabuk Kullan)';

  @override
  String get sftpDownload => 'İndir';

  @override
  String get sftpOpen => 'Aç';

  @override
  String get sftpUploadFailed =>
      'Yükleme başarısız. İzinleri kontrol edin ve tekrar deneyin.';

  @override
  String get sftpDownloadFailed => 'İndirme başarısız';

  @override
  String get sftpOpenUnsupported => 'Bu dosya biçimi açılamıyor.';

  @override
  String get sftpReadFailed =>
      'Dosya okunamadı. İzinleri kontrol edin ve tekrar deneyin.';

  @override
  String get sftpTransferFailed =>
      'Dosya işlemi başarısız oldu. Lütfen tekrar deneyin.';

  @override
  String get sftpDownloadSuccess => 'Başarıyla indirildi';

  @override
  String get sftpUploading => 'Yükleniyor...';

  @override
  String get sftpDownloading => 'İndiriliyor...';

  @override
  String get sftpUpDirectory => 'Üst dizine git';

  @override
  String get sftpShowHiddenFiles => 'Gizli dosyaları göster';

  @override
  String get sftpHideHiddenFiles => 'Gizli dosyaları gizle';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Gizli dosya tercihi kaydedilemedi';

  @override
  String get sftpSymlink => 'Sembolik bağlantı';

  @override
  String get sftpLinkTargetUnavailable =>
      'Sembolik bağlantı hedefi bozuk veya kullanılamıyor';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Sembolik bağlantı hedefine erişim reddedildi';

  @override
  String get settingsAutoConnect => 'Başlangıçta otomatik bağlan';

  @override
  String get settingsAutoConnectFixed => 'Sabit varsayılan SSH';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Her zaman aşağıda seçtiğiniz sunucuya bağlanın';

  @override
  String get settingsAutoConnectLast => 'Son bağlantıyı hatırla';

  @override
  String get settingsAutoConnectLastDesc =>
      'En son başarıyla bağlandığınız sunucuya bağlanın';

  @override
  String get settingsAutoConnectPickServer => 'Sunucu';

  @override
  String get settingsAutoConnectNoServer => 'Henüz sunucu seçilmedi';

  @override
  String get sftpSort => 'Sırala';

  @override
  String get sftpSortName => 'Ad';

  @override
  String get sftpSortSize => 'Boyut';

  @override
  String get sftpSortDate => 'Değiştirilme tarihi';

  @override
  String get sftpSortAscending => 'Artan';

  @override
  String get sftpSortDescending => 'Azalan';

  @override
  String get themeQuickSwitch => 'Tema';

  @override
  String get transferList => 'Aktarımlar';

  @override
  String get transferEmpty => 'Henüz aktarım yok';

  @override
  String get transferUpload => 'Yükle';

  @override
  String get transferDownload => 'İndir';

  @override
  String get transferStatusQueued => 'Kuyrukta';

  @override
  String get transferStatusRunning => 'Aktarılıyor';

  @override
  String get transferStatusPaused => 'Duraklatıldı';

  @override
  String get transferStatusCompleted => 'Tamamlandı';

  @override
  String get transferStatusFailed => 'Başarısız';

  @override
  String get transferStatusCanceled => 'İptal edildi';

  @override
  String get transferPause => 'Duraklat';

  @override
  String get transferResume => 'Devam Ettir';

  @override
  String get transferCancel => 'İptal';

  @override
  String get transferRemove => 'Kaldır';

  @override
  String get transferClearFinished => 'Tamamlananları temizle';

  @override
  String get transferSizeUnknown => 'Boyut bilinmiyor';

  @override
  String get transferFailedUpload => 'Yükleme başarısız';

  @override
  String get transferFailedDownload => 'İndirme başarısız';

  @override
  String get stopGeneration => 'Durdur';

  @override
  String get chatServerBindingRequired =>
      'Bu oturum bir sunucuya bağlı değil. Devam etmek için lütfen geçerli sunucuya bağlayın.';

  @override
  String get chatSessionUnboundNotice =>
      'Bu oturum herhangi bir sunucuya bağlı değil.';

  @override
  String get bindServerAction => 'Sunucuya Bağla';

  @override
  String get bindServerDialogTitle => 'Oturumu Sunucuya Bağla';

  @override
  String get bindServerConfirmAction => 'Bağlamayı Onayla';

  @override
  String get chatSessionIdentityMismatch =>
      'Geçerli sunucu veya ajan bu oturumun bağlı kimliğiyle eşleşmiyor. Devam etmek için eşleşen sunucu ve ajana geçin.';

  @override
  String get deleteSessionTitle => 'Oturumu Sil';

  @override
  String get deleteSessionConfirmAction => 'Sil';

  @override
  String get shareAgentSessionsTitle => 'Ajan Oturumlarını Paylaş';

  @override
  String get shareAgentSessionsSubtitle =>
      'Bu sunucudaki farklı ajanlar arasında oturumları paylaşın';

  @override
  String get shareAgentSessionsEnabled =>
      'Ajan oturumu paylaşımı etkinleştirildi';

  @override
  String get shareAgentSessionsDisabled =>
      'Ajan oturumu paylaşımı devre dışı bırakıldı';

  @override
  String get agentCliStatusInstalled => 'CLI: Kurulu';

  @override
  String get agentCliStatusMissing => 'CLI: Eksik';

  @override
  String get agentCliStatusChecking => 'CLI: Kontrol ediliyor...';

  @override
  String get agentCliStatusUnknown => 'CLI: Bilinmiyor';

  @override
  String get agentCliStatusError => 'CLI: Hata';

  @override
  String get agentAcpStatusReady => 'ACP: Hazır';

  @override
  String get agentAcpStatusMissing => 'ACP: Eksik';

  @override
  String get agentAcpStatusChecking => 'ACP: Kontrol ediliyor...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: CLI Bekleniyor';

  @override
  String get agentAcpStatusUnknown => 'ACP: Bilinmiyor';

  @override
  String get agentAcpStatusError => 'ACP: Hata';

  @override
  String get agentAcpStatusNa => 'ACP: Yok';

  @override
  String get agentAuthStatusAuthenticated => 'Kimlik Doğrulama: Giriş Yapıldı';

  @override
  String get agentAuthStatusUnauthenticated =>
      'Kimlik Doğrulama: Giriş Yapılmadı';

  @override
  String get agentAuthStatusUnknown => 'Kimlik Doğrulama: Bilinmiyor';

  @override
  String get downloadNotificationsUnavailable =>
      'Sistem indirme bildirimleri kullanılamıyor. İndirmeler arka planda devam eder.';

  @override
  String get downloadOpenFailed => 'İndirilen dosya açılamadı.';

  @override
  String get dockerActionPending =>
      'Bu konteyner için zaten bir işlem devam ediyor';

  @override
  String get dockerNoLogs => '(Günlük yok)';

  @override
  String get serverReboot => 'Yeniden Başlat';

  @override
  String get serverRebootDialogTitle => 'Sunucuyu Yeniden Başlatmayı Onayla';

  @override
  String get serverRebootDialogMessage =>
      'Bu sunucuyu yeniden başlatmak istediğinizden emin misiniz? Tüm aktif bağlantılar ve arka plan hizmetleri sonlandırılacaktır.';

  @override
  String get serverRebootConfirmButton => 'Şimdi Yeniden Başlat';

  @override
  String get serverRebootPasswordTitle => 'Sudo Şifresi Gerekli';

  @override
  String get serverRebootPasswordMessage =>
      'Sunucuyu yeniden başlatmak için root ayrıcalıkları gereklidir. Lütfen sudo şifresini girin (bir kez kullanılır, kaydedilmez):';

  @override
  String get serverRebootPasswordHint => 'Sudo Şifresi';

  @override
  String get serverRebootSubmitting =>
      'Yeniden başlatma komutu gönderiliyor...';

  @override
  String get serverRebootAccepted =>
      'Yeniden başlatma komutu kabul edildi; tamamlanma henüz doğrulanmadı. Sunucu tekrar çevrimiçi olduğunda lütfen yeniden bağlanın.';

  @override
  String get serverRebootVerified =>
      'Sunucunun yeniden başlatıldığı doğrulandı; sistem tekrar çevrimiçi.';

  @override
  String get serverRebootUnknown =>
      'Yeniden başlatma sonucu belirsiz. Komut gönderildi ancak tamamlanma doğrulanamadı. Lütfen bağlantıyı manuel olarak kontrol edin.';

  @override
  String get serverRebootReconnect => 'Yeniden Bağlan';

  @override
  String get serverRebootServerChanged =>
      'Hedef sunucu değişti, yeniden başlatma iptal edildi';

  @override
  String get navCliChat => 'CLI Sohbeti';

  @override
  String get cliChatTitle => 'CLI Oturumları';

  @override
  String get cliChatSubtitle => 'Uzak sunucuda yerel CLI Ajan oturumları';

  @override
  String get cliSelectAgent => 'Ajan Seç';

  @override
  String get cliNoAgentsConfigured => 'Bu sunucu için eklenmiş ajan yok';

  @override
  String get cliAgentNeedsSetup => 'Ajan ortamı eksik veya giriş yapılmamış';

  @override
  String get cliManageAgentsGuide => 'Ajan Yönetimi\'nde yapılandırın';

  @override
  String get cliNewDraft => 'Yeni Taslak';

  @override
  String get cliNewDraftTooltip =>
      'Boş bir taslak oluşturun (oturum ilk mesajda oluşturulur)';

  @override
  String get cliDeleteSessionTitle => 'Uzak CLI Oturum Geçmişini Sil';

  @override
  String get cliDeleteSessionMessage =>
      'Bu işlem uzak sunucudaki CLI oturum geçmişini kalıcı olarak silecektir. Devam etmek istediğinizden emin misiniz?';

  @override
  String get cliDeleteConfirmButton => 'Oturumu Sil';

  @override
  String get cliCannotDeleteTooltip =>
      'Uzak oturum silme desteklenmiyor veya devre dışı';

  @override
  String get cliSessionsHeader => 'Oturumlar';

  @override
  String get cliNoSessions => 'CLI oturumu bulunamadı';

  @override
  String get cliFilterCwdHint => 'CWD yoluna göre filtrele...';

  @override
  String get cliFilterCwdAction => 'Filtrele';

  @override
  String get cliClearCwdAction => 'Temizle';

  @override
  String get cliLoadMoreSessions => 'Daha Fazla Oturum Yükle';

  @override
  String get cliRefreshSessions => 'Yenile';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Claude geçmişi salt okunurdur. Konuşmaya gerçek terminalde devam edin.';

  @override
  String get cliContinueInTerminal => 'Terminalde Devam Et';

  @override
  String get cliOpenTerminal => 'Terminali Aç';

  @override
  String get cliCloseTerminal => 'Terminali Kapat';

  @override
  String get cliTerminalRunning => 'Etkileşimli CLI Terminali';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Bu ajan yapılandırılmış geçmiş senkronizasyonunu desteklemiyor. Etkileşim ve oturum seçimi için lütfen yerel CLI terminalini kullanın.';

  @override
  String get cliInstallSdkTitle => 'Resmi Claude Geçmiş SDK\'sını Kur';

  @override
  String get cliInstallSdkMessage =>
      'Resmi Claude Code History SDK uzak sunucuda eksik. Şimdi kurmak ister misiniz?';

  @override
  String get cliInstallSdkAction => 'Resmi SDK\'yı Kur';

  @override
  String get cliApprovalsTitle => 'Bekleyen Onaylar';

  @override
  String get cliApprovalDetails => 'Ayrıntılar';

  @override
  String get cliApprovalAllow => 'İzin Ver';

  @override
  String get cliApprovalDecline => 'Reddet';

  @override
  String get cliInputHint => 'CLI ajanına bir mesaj yazın...';

  @override
  String get cliSend => 'Gönder';

  @override
  String get cliStop => 'Durdur';

  @override
  String get cliBusy => 'İşlem devam ediyor, lütfen bekleyin...';

  @override
  String get cliDisconnected => 'SSH bağlı değil';

  @override
  String get cliServerChanged => 'Hedef sunucu değişti';

  @override
  String get cliTurnFailed => 'CLI tur yürütmesi başarısız oldu';

  @override
  String get cliUseTerminal =>
      'Etkileşimli istem gerekli, devam etmek için lütfen terminali açın';

  @override
  String get cliDeleteFailed => 'Uzak oturum silinemedi';

  @override
  String get cliDeleteUnsupported =>
      'Uzak oturumları silme bu CLI tarafından desteklenmiyor';

  @override
  String get cliOperationFailed => 'CLI işlemi başarısız oldu';

  @override
  String get cliHistorySdkMissing => 'Resmi History SDK sunucuda eksik';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude geçmişi sunucuda Node.js/npm gerektirir. Lütfen Node.js\'yi manuel olarak kurun; terminalde gerçek CLI\'yi kullanmaya devam edebilirsiniz.';

  @override
  String get cliLoginRequired =>
      'Ajan girişi gerekli. Lütfen Ajan Yönetimi aracılığıyla giriş yapın.';

  @override
  String get cliNotInstalled =>
      'Ajan CLI kurulu değil. Lütfen Ajan Yönetimi aracılığıyla kurun.';

  @override
  String get cliVersionUnsupported =>
      'Ajan CLI sürümü desteklenmiyor. Lütfen Ajan Yönetimi aracılığıyla yükseltin veya yeniden kurun.';

  @override
  String get settingsNavigation => 'Gezinme';

  @override
  String get settingsNavigationDesc =>
      'Varsayılan başlangıç sayfasını ve alt gezinme çubuğunu yapılandırın';

  @override
  String get settingsStartupPage => 'Başlangıç Sayfası';

  @override
  String get settingsStartupPageDesc =>
      'Uygulama açıldığında görüntülenen sayfa';

  @override
  String get settingsBottomNav => 'Alt Gezinme Çubuğu';

  @override
  String get settingsBottomNavDesc =>
      'Mobil alt çubukta görüntülenecek bölümleri seçin (0 ila 9 öğeyi destekler)';

  @override
  String get settingsResetSuccess => 'Tüm ayarlar varsayılanlara geri yüklendi';

  @override
  String get metricsTrendSubtitle => 'Son ~3 dakika (60 örneğe kadar)';

  @override
  String get metricsCurrent => 'Mevcut';

  @override
  String get metricsPeak => 'Zirve';

  @override
  String get metricsValley => 'Dip';

  @override
  String get metricsTrendWaiting => 'Metrik verileri toplanıyor...';

  @override
  String get metricsTrendStopped =>
      'Veri toplama durduruldu (SSH bağlantısı kesildi)';

  @override
  String get dockerActionTerminal => 'Exec Terminali';

  @override
  String get dockerTerminalTitle => 'Konteyner Terminali';

  @override
  String get dockerTerminalNotRunning => 'Konteyner çalışmıyor';

  @override
  String get setDefaultAgent => 'Varsayılan olarak ayarla';

  @override
  String get defaultBadge => 'Varsayılan';

  @override
  String get isDefaultAgent => 'Varsayılan Ajan';

  @override
  String get setAsDefaultAgent =>
      'Bu sunucu için varsayılan ajan olarak ayarla';

  @override
  String get agentGroupBasic => 'Temel Bilgiler';

  @override
  String get agentGroupCommands => 'Komutlar';

  @override
  String get agentGroupAuth => 'Kurulum ve Kimlik Doğrulama';

  @override
  String get agentPresetTitle => 'Hazır Ayar Şablonu';

  @override
  String get resourceProcessList => 'Süreçler';

  @override
  String get resourceDiskScanning =>
      'Kök dizinler taranıyor, bu işlem birkaç saniye sürebilir...';

  @override
  String get resourceDiskScanPartial =>
      'İzinler veya zaman aşımı nedeniyle bazı dizinler taranamadı';

  @override
  String get resourceDiskDirectories => 'Üst Düzey Dizin Kullanımı';

  @override
  String get resourceSortCpu => 'CPU\'ya göre sırala';

  @override
  String get resourceSortMemory => 'Belleğe göre sırala';

  @override
  String get resourceRss => 'RSS Belleği';

  @override
  String get resourceUsed => 'Kullanılan';

  @override
  String get resourceAvailable => 'Kullanılabilir';

  @override
  String get resourceTotal => 'Toplam';

  @override
  String get settingsBottomNavOrderTitle =>
      'Seçilen Öğeler (Yeniden sıralamak için sürükleyin)';

  @override
  String get langSystem => 'Sistemi Takip Et';

  @override
  String get serverFieldRequired => 'Gerekli';

  @override
  String get serverPortInvalid => 'Port 1 ile 65535 arasında olmalıdır';

  @override
  String get serverTestReachability => 'Erişilebilirliği Test Et';

  @override
  String get serverSaveFailedGeneric =>
      'Sunucu kaydedilemedi. Lütfen yapılandırmanızı kontrol edin ve tekrar deneyin.';

  @override
  String get serverViewPrivateKey => 'Özel Anahtarı Görüntüle';

  @override
  String get serverHidePrivateKey => 'Özel Anahtarı Gizle';

  @override
  String get dockerBashFallbackNotice =>
      'Konteynerde Bash mevcut değil, Sh\'ye dönülüyor';

  @override
  String get dockerShellLabel => 'Kabuk';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Çalışma Dizini';

  @override
  String get cliDefaultWorkingDir => 'Varsayılan (/)';

  @override
  String get cliPickWorkingDirTitle => 'Çalışma Dizini Seçin';

  @override
  String get cliClearWorkingDir => 'Varsayılana Sıfırla';

  @override
  String get cliBrowseWorkingDir => 'Gözat';

  @override
  String get cliSelectCurrentDir => 'Bu Dizini Seç';

  @override
  String get cliNavigateUp => 'Yukarı çık';

  @override
  String get chatSessionsTooltip => 'Oturumlar';

  @override
  String get hardwareSpecsTitle => 'Donanım ve Sistem';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Bellek';

  @override
  String get hardwareDisk => 'Kök Disk';

  @override
  String get hardwareDistribution => 'İşletim Sistemi';

  @override
  String get hardwareKernel => 'Çekirdek';

  @override
  String get hardwareLoading => 'Donanım özellikleri yükleniyor...';

  @override
  String get hardwareUnavailable => 'Donanım özellikleri kullanılamıyor';

  @override
  String get hardwareUnknown => 'Bilinmiyor';

  @override
  String get systemInfoTitle => 'Sistem Bilgisi';

  @override
  String get systemInfoTapHint => 'ASCII sanatını görüntülemek için dokunun';

  @override
  String get systemInfoHost => 'Ana Bilgisayar';

  @override
  String get serverShutdown => 'Kapat';

  @override
  String get serverShutdownDialogTitle => 'Sunucuyu Kapatmayı Onayla';

  @override
  String get serverShutdownDialogMessage =>
      'Bu sunucuyu kapatmak istediğinizden emin misiniz? Sistem tamamen kapatılacak ve manuel olarak açılana kadar uzaktan erişilemeyecektir.';

  @override
  String get serverShutdownConfirmButton => 'Şimdi Kapat';

  @override
  String get serverShutdownSubmitting => 'Kapatma komutu gönderiliyor...';

  @override
  String get serverShutdownAccepted =>
      'Kapatma komutu kabul edildi; kapatmanın tamamlandığı doğrulanmadı.';

  @override
  String get serverShutdownUnknown =>
      'Kapatma sonucu bilinmiyor: Komut gönderilmiş olabilir ancak doğrulanamıyor. Lütfen manuel olarak kontrol edin; otomatik olarak yeniden denenmeyecektir.';

  @override
  String get serverShutdownPasswordTitle => 'Kapatma için Sudo Şifresi Gerekli';

  @override
  String get serverShutdownPasswordMessage =>
      'Sunucuyu kapatmak için root ayrıcalıkları gereklidir. Lütfen sudo şifresini girin (bir kez kullanılır, kaydedilmez):';

  @override
  String get serverShutdownPasswordHint => 'Sudo Şifresi';

  @override
  String get serverShutdownServerChanged =>
      'Hedef sunucu değişti, kapatma iptal edildi';

  @override
  String get metricsNetwork => 'Ağ Hızı';

  @override
  String get networkModalTitle => 'Ağ Arayüzleri Ayrıntıları';

  @override
  String get networkDownloadRate => 'İndirme (RX)';

  @override
  String get networkUploadRate => 'Yükleme (TX)';

  @override
  String get networkTotalRx => 'Toplam RX';

  @override
  String get networkTotalTx => 'Toplam TX';

  @override
  String get networkPrimary => 'Varsayılan Yol';

  @override
  String get networkRatesEmpty => 'Aktif ağ arayüzü algılanmadı';

  @override
  String get networkWaitingSecondSample => 'İkinci örnek bekleniyor';

  @override
  String get networkUnavailable => 'Kullanılamıyor';

  @override
  String get networkNoDefaultInterface => 'Varsayılan rota yok';

  @override
  String get selectThemeModeTitle => 'Tema Modunu Seçin';

  @override
  String get selectLanguageTitle => 'Dili Seçin';

  @override
  String get selectStartupPageTitle => 'Başlangıç Sayfasını Seçin';

  @override
  String get selectAutoConnectModeTitle => 'Otomatik Bağlanma Modunu Seçin';

  @override
  String get accentColorDialogTitle => 'Vurgu Renklerini Özelleştirin';

  @override
  String get accentColorLightMode => 'Açık Mod';

  @override
  String get accentColorDarkMode => 'Koyu Mod';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Hazır Ayarlar';

  @override
  String get accentColorHsvPicker => 'Renk Çarkı';

  @override
  String get accentColorHexCode => 'Onaltılık Renk Kodu';

  @override
  String get accentColorPreview => 'Önizleme';

  @override
  String get accentColorSampleButton => 'Örnek Düğme';

  @override
  String get accentColorInvalidHex => 'Geçersiz onaltılık biçim (örn. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Gösterge Paneli Hızlı Eylemleri';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Gösterge panelinde gösterilen hızlı kısayol girişlerini yapılandırın. Temizlemek hızlı eylemler bölümünü gizler.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Hızlı eylemler gizlendi (hiçbir kısayol seçilmedi)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Kısayolları Yeniden Sıralamak İçin Sürükleyin';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Görünür Kısayolları Seçin';

  @override
  String get terminalCopySelection => 'Kopyala';

  @override
  String get terminalSelectionCopied => 'Seçim panoya kopyalandı';

  @override
  String get editAgent => 'Ajanı Düzenle';

  @override
  String get agentExecutionTarget => 'Yürütme Ortamı';

  @override
  String get agentExecutionHost => 'Ana Sistem';

  @override
  String get agentExecutionDocker => 'Docker Konteyneri';

  @override
  String get agentContainerBinding => 'Konteyner Bağlama Modu';

  @override
  String get agentContainerBindingId => 'Konteyner Kimliğine Göre';

  @override
  String get agentContainerBindingName => 'Konteyner Adına Göre';

  @override
  String get agentContainerReference => 'Hedef Konteyner';

  @override
  String get agentContainerReferenceHint =>
      'Konteyner kimliğini veya adını seçin ya da girin';

  @override
  String get agentContainerRequired =>
      'Docker yürütmesi için hedef konteyner gereklidir';

  @override
  String get agentLoadingContainers =>
      'Sunucudaki konteynerler sorgulanıyor...';

  @override
  String get agentNoContainersFound => 'Bu sunucuda konteyner bulunamadı';

  @override
  String get agentContainerUser =>
      'Konteyner Yürütme Kullanıcısı (İsteğe Bağlı)';

  @override
  String get agentContainerUserHint => 'örn. dev';

  @override
  String get agentContainerUserHelper =>
      'İmaj varsayılan kullanıcısını kullanmak için boş bırakın; örn. dev; user, UID, user:group, UID:GID destekler';

  @override
  String get agentContainerUserSelect => 'Konteyner kullanıcısını seçin';

  @override
  String get agentContainerUsersLoading => 'Kullanıcılar yükleniyor...';

  @override
  String get agentContainerUsersEmpty => 'Passwd kullanıcısı bulunamadı';

  @override
  String get agentViewDiagnosticLog => 'Teşhis Günlüğünü Görüntüle';

  @override
  String get agentDiagnosticLogCopied => 'Teşhis günlüğü panoya kopyalandı';

  @override
  String get agentDiagnosticLogCopy => 'Kopyala';

  @override
  String get agentDiagnosticLogClose => 'Kapat';

  @override
  String get settingsCliHistoryPageSize => 'CLI Geçmişi Sayfa Boyutu';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Yukarı kaydırırken sayfa başına yüklenen eski mesaj sayısı (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'CLI Geçmişi Sayfa Boyutunu Seçin';

  @override
  String get cliLoadingOlderMessages => 'Daha eski mesajlar yükleniyor...';

  @override
  String get chatLoadOlderMessages => 'Daha önceki mesajları yükle';

  @override
  String get chatCommandsTooltip => 'Komutlar';

  @override
  String get chatAttachTooltip => 'Dosya ekle';

  @override
  String get chatAttachImage => 'Yerel resim ekle';

  @override
  String get chatAttachLocalText => 'Yerel metin dosyası ekle';

  @override
  String get chatAttachRemoteText => 'Uzak metin dosyası ekle';

  @override
  String get chatAttachRemotePathTitle => 'Uzak Metin Dosyası Ekle';

  @override
  String get chatAttachRemotePathHint => '/yol/dosya.txt';

  @override
  String get chatAttachTooLarge => 'Dosya boyut sınırını aşıyor';

  @override
  String get chatUsageAndDiagnostics => 'Kullanım ve Teşhis';

  @override
  String get chatWorkingDirTooltip => 'Taslak Çalışma Dizini';

  @override
  String get chatAttachFailed => 'Dosya eklenemedi';

  @override
  String get chatInvalidRemotePath =>
      'Geçersiz uzak dosya yolu (/ ile başlamalıdır)';

  @override
  String get chatRemoteReadFailed => 'Uzak dosya okunamadı';

  @override
  String get chatInvalidDirPath => 'Geçersiz dizin yolu (/ ile başlamalıdır)';

  @override
  String get chatNoSubdirectories => 'Alt dizin yok';

  @override
  String get chatUsageTitle => 'Belirteç ve Maliyet Kullanımı';

  @override
  String get chatUsageUsed => 'Kullanılan Belirteçler';

  @override
  String get chatUsageSize => 'Bağlam Boyutu';

  @override
  String get chatUsageCost => 'Maliyet';

  @override
  String get chatDiagnosticsTitle => 'Teşhis Günlüğü';

  @override
  String get chatNoDiagnostics => 'Kullanılabilir teşhis günlüğü yok';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Bu yalnızca Valhalla\'daki yerel kaydı kaldırır ve sunucudaki yerel ajan oturum geçmişini silmez.';

  @override
  String get chatSearchSessionsHint => 'Oturumları ara...';

  @override
  String get chatLoadMoreSessions => 'Daha fazla oturum yükle';

  @override
  String get chatLoadingMoreSessions => 'Daha fazla oturum yükleniyor...';

  @override
  String get chatExportSession => 'Oturumu Dışa Aktar (Markdown)';

  @override
  String get chatExportSuccess => 'Oturum başarıyla dışa aktarıldı';

  @override
  String get chatExportFailed => 'Oturum dışa aktarılamadı';

  @override
  String get chatRemoteSessions => 'Uzak Oturumlar';

  @override
  String get chatRemoteSessionsTitle => 'Uzak Ajan Oturumları';

  @override
  String get chatRemoteSessionsDesc =>
      'Uzak ajandan yerel oturum geçmişini görüntüleyin ve içe aktarın';

  @override
  String get chatRemoteSessionsEmpty => 'Uzak oturum bulunamadı';

  @override
  String get chatRemoteImporting => 'Uzak oturum geçmişi içe aktarılıyor...';

  @override
  String get chatRemoteImportFailed => 'Uzak oturum içe aktarılamadı';

  @override
  String get chatStatusInterrupted => 'Kesintiye Uğradı';

  @override
  String get chatStatusFailed => 'Başarısız';

  @override
  String get chatStatusAwaitingAuth => 'ACP Kimlik Doğrulaması Bekleniyor';

  @override
  String get chatShowFullOutput => 'Tam çıktıyı göster';

  @override
  String get chatShowLessOutput => 'Daha az göster';

  @override
  String get chatToolLocations => 'Etkilenen yollar';

  @override
  String cmdParamPlaceholder(String param) {
    return '$param için değer girin';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Süreç $pid sonlandırıldı';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return '$service üzerinde $action eylemi başarılı oldu';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Tetiklenen kural: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Çıkış Kodu: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'SSH aracılığıyla $server sunucusuna başarıyla bağlandı';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH bağlantısı başarısız oldu: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return '$host ($type) ana bilgisayarına ilk kez bağlanılıyor.\n\nSHA-256 Parmak İzi:\n$fingerprint\n\nBu parmak izine güvenip bağlanılsın mı?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return '$server için şifre girin';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return '\'$name\' sunucusunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return '\'$name\' Ajanını silmek istediğinizden emin misiniz? Bu, geçmiş sohbet oturumlarını veya SSH kimlik bilgilerini etkilemeden bu sunucudaki yapılandırmasını ve çalışma zamanı durumunu kaldırır.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Son kontrol: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return '$agent için nasıl giriş yapılacağını seçin';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Yeniden bağlanılıyor… (deneme $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n aktif oturum';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Bu oturum \"$serverName\" sunucusuna bağlansın mı? Bağlandıktan sonra bu oturum bu sunucuyla ilişkilendirilecektir.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return '\"$title\" oturumunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return '$name konteynerinde $action işlemi başarılı oldu';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'İşlem başarısız oldu: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Hedef Sunucu: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Terminal Oturumları: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Ajan Oturumları: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Aktif Aktarımlar: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Yeniden başlatma başarısız oldu: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Uzak oturum silinemedi: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric Eğilimi';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Uyarı: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Tehlike: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count veri noktası';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric Kaynak Kullanımı';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP portu $port erişilebilir';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Bağlantı başarısız: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Sunucu kaydedilemedi: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Çekirdek';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Kapatma başarısız oldu: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Arayüz: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Konteynerler yüklenemedi: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Konteyner kullanıcıları yüklenemedi: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Teşhis Günlüğü - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Docker/konteyner algılama başarısız oldu';

  @override
  String get chatCopiedAllMessages => 'Tüm mesajlar kopyalandı';

  @override
  String get chatCopyAllMessages => 'Tüm mesajları kopyala';

  @override
  String get cliModelAtCapacity =>
      'Seçilen model tam kapasitede. Başka bir model deneyin.';

  @override
  String get chatLaunchBlankDraft => 'Boş taslak';

  @override
  String get chatLaunchFixedSession => 'Sabit oturum';

  @override
  String get chatLaunchRememberLast => 'Son oturumu hatırla';

  @override
  String get chatPermissionAskEveryTime => 'Her zaman sor';

  @override
  String get chatPermissionAutoAllowAll => 'Tümüne otomatik olarak izin ver';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Ajan sormadan tüm işlemleri gerçekleştirecektir. Devam edilsin mi?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Tüm işlemlere izin verilsin mi?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Güvenli işlemlere otomatik olarak izin ver';

  @override
  String get chatRunSettingsDefault => 'Varsayılan';

  @override
  String get chatRunSettingsInteractiveCli => 'Etkileşimli CLI';

  @override
  String get chatRunSettingsModel => 'Model';

  @override
  String get chatRunSettingsPermissions => 'İzinler';

  @override
  String get chatRunSettingsReasoning => 'Akıl yürütme seviyesi';

  @override
  String get chatRunSettingsTitle => 'Çalıştırma ayarları';

  @override
  String get cliActionInsertCommand => 'Komut ekle';

  @override
  String get cliActionInsertFile => 'Dosya ekle';

  @override
  String get cliActionInsertWorkdir => 'Çalışma dizini ekle';

  @override
  String get cliComposerInsertAction => 'Ekle';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI işlemi başarısız oldu: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Komut seçin';

  @override
  String get defaultAgentTitle => 'Varsayılan ajan';

  @override
  String get insertSkills => 'Beceri ekle';

  @override
  String get isDefaultSession => 'Varsayılan oturum';

  @override
  String get sessionLaunchMode => 'Oturum başlatma modu';

  @override
  String get setAsDefaultSession => 'Varsayılan oturum olarak ayarla';

  @override
  String get navNas => 'NAS Medya';

  @override
  String get nasAddExcludePath => 'Hariç tutulan yol ekle';

  @override
  String get nasAddIncludePath => 'Tarama yolu ekle';

  @override
  String get nasCancelScan => 'Taramayı iptal et';

  @override
  String get nasClearSearch => 'Aramayı temizle';

  @override
  String get nasConfigDialogTitle => 'Medya kitaplığı ayarları';

  @override
  String get nasConfigure => 'Yapılandır';

  @override
  String get nasConfigureScanDirs => 'Tarama klasörlerini yapılandır';

  @override
  String get nasCreatePlaylist => 'Çalma listesi oluştur';

  @override
  String get nasEmptyConfigDesc =>
      'Medya kitaplığınızı oluşturmaya başlamak için en az bir klasör ekleyin.';

  @override
  String get nasEmptyConfigTitle => 'Yapılandırılmış tarama klasörü yok';

  @override
  String get nasExcludePaths => 'Hariç tutulan klasörler';

  @override
  String get nasExcludedBadge => 'Hariç Tutuldu';

  @override
  String get nasFilterImages => 'Görseller';

  @override
  String get nasFilterVideos => 'Videolar';

  @override
  String get nasIncludePaths => 'Tarama klasörleri';

  @override
  String nasItemCount(Object value) {
    return '$value öğe';
  }

  @override
  String nasLastScan(Object value) {
    return 'Son tarama: $value';
  }

  @override
  String get nasLibrarySettings => 'Kitaplık ayarları';

  @override
  String nasMediaOpening(Object value) {
    return '$value açılıyor…';
  }

  @override
  String get nasMiniPlayer => 'Mini oynatıcı';

  @override
  String get nasNoExcludePaths => 'Hariç tutulan klasör yok';

  @override
  String get nasNoFavorites => 'Henüz favori yok';

  @override
  String get nasNoIncludePaths => 'Tarama klasörü yok';

  @override
  String get nasNoIndexDesc =>
      'Medyalarınızı dizine eklemek için klasörleri yapılandırın ve bir tarama çalıştırın.';

  @override
  String get nasNoIndexTitle => 'Medya kitaplığı boş';

  @override
  String get nasNoPlaylists => 'Henüz çalma listesi yok';

  @override
  String get nasNoSearchResults => 'Eşleşen medya yok';

  @override
  String get nasNotScanned => 'Henüz taranmadı';

  @override
  String get nasNowPlaying => 'Şimdi oynatılıyor';

  @override
  String get nasOpenMethodPrompt => 'Bu dosyayı nasıl açmak istersiniz?';

  @override
  String get nasOpenPolicyAsk => 'Her zaman sor';

  @override
  String get nasOpenPolicyExternal => 'Başka bir uygulamayla aç';

  @override
  String get nasOpenPolicyInApp => 'Uygulamada aç';

  @override
  String get nasOpeningPolicy => 'Varsayılan açma yöntemi';

  @override
  String get nasPlaylistName => 'Çalma listesi adı';

  @override
  String get nasQuickStats => 'Kitaplığa genel bakış';

  @override
  String get nasScan => 'Şimdi tara';

  @override
  String get nasScanCancelled => 'Tarama iptal edildi';

  @override
  String nasScanFailed(Object value) {
    return 'Tarama başarısız oldu: $value';
  }

  @override
  String get nasScanning => 'Taranıyor…';

  @override
  String get nasScopeBadge => 'Tarama kapsamı';

  @override
  String get nasSearchHint => 'Medya ara';

  @override
  String get nasStatMusic => 'Müzik';

  @override
  String get nasStatPhotos => 'Fotoğraflar';

  @override
  String get nasStatTotal => 'Toplam';

  @override
  String get nasStatVideos => 'Videolar';

  @override
  String get nasTabFavorites => 'Favoriler';

  @override
  String get nasTabFolders => 'Klasörler';

  @override
  String get nasTabHome => 'Ana Sayfa';

  @override
  String get nasTabMusic => 'Müzik';

  @override
  String get nasTabPhotos => 'Fotoğraflar';

  @override
  String get nasTabPlaylists => 'Çalma Listeleri';

  @override
  String get nasTabVideos => 'Videolar';

  @override
  String get nasSources => 'Medya kaynakları';

  @override
  String get nasAddSource => 'Medya kaynağı ekle';

  @override
  String get nasEditSource => 'Medya kaynağını düzenle';

  @override
  String get nasRemoveSource => 'Medya kaynağını kaldır';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return '\'$name\' medya kaynağını kaldırmak istediğinizden emin misiniz? Bu, uzak dosyaları silmeden yapılandırmasını kaldırır.';
  }

  @override
  String get nasNoSources => 'Yapılandırılmış medya kaynağı yok';

  @override
  String get nasNoSourcesDesc =>
      'Medyaya göz atmaya başlamak için SFTP, SMB, WebDAV, Jellyfin veya Emby ekleyin.';

  @override
  String get nasSourceType => 'Kaynak türü';

  @override
  String get nasSourceName => 'Kaynak adı';

  @override
  String get nasProbe => 'Bağlantıyı test et';

  @override
  String get nasProbeSuccess => 'Bağlantı başarılı';

  @override
  String get nasProbeFailed => 'Bağlantı testi başarısız oldu';

  @override
  String get nasEndpoint => 'Uç Nokta / URL';

  @override
  String get nasRootPath => 'Kök yolu';

  @override
  String get nasUsername => 'Kullanıcı adı';

  @override
  String get nasPassword => 'Şifre';

  @override
  String get nasDomain => 'Alan adı (isteğe bağlı)';

  @override
  String get nasAuthenticate => 'Kimlik doğrula';

  @override
  String get nasAuthSuccess => 'Kimlik doğrulama başarılı';

  @override
  String get nasAuthFailed => 'Kimlik doğrulama başarısız oldu';

  @override
  String get nasTabDownloads => 'İndirmeler';

  @override
  String get nasNoDownloads => 'İndirme görevi yok';

  @override
  String get nasDownloadQueued => 'Kuyrukta';

  @override
  String get nasDownloadDownloading => 'İndiriliyor';

  @override
  String get nasDownloadCompleted => 'Tamamlandı';

  @override
  String get nasDownloadCancelled => 'İptal edildi';

  @override
  String get nasDownloadFailed => 'İndirme başarısız';

  @override
  String get nasRetryDownload => 'Tekrar dene';

  @override
  String get nasCancelDownload => 'İptal';

  @override
  String get nasOpenDownloadedFile => 'Dosyayı aç';

  @override
  String get nasQueue => 'Oynatma kuyruğu';

  @override
  String get nasNoQueue => 'Kuyruk boş';

  @override
  String get nasSpeed => 'Hız';

  @override
  String get nasQuality => 'Kalite';

  @override
  String get nasAudioTrack => 'Ses parçası';

  @override
  String get nasSubtitleTrack => 'Altyazılar';

  @override
  String get nasRepeatOff => 'Tekrar kapalı';

  @override
  String get nasRepeatAll => 'Tümünü tekrarla';

  @override
  String get nasRepeatOne => 'Birini tekrarla';

  @override
  String get nasShuffle => 'Karıştır';

  @override
  String get nasCast => 'Yayınla';

  @override
  String get nasCastUnavailable => 'Kullanılabilir yayın cihazı yok';

  @override
  String get nasSlideshow => 'Slayt gösterisi';

  @override
  String get nasByFolder => 'Klasörler';

  @override
  String get nasByArtist => 'Sanatçılar';

  @override
  String get nasByAlbum => 'Albümler';

  @override
  String get nasAllTracks => 'Tüm parçalar';

  @override
  String get nasPlayAll => 'Tümünü oynat';

  @override
  String get nasPreviousPage => 'Önceki';

  @override
  String get nasNextPage => 'Sonraki';

  @override
  String get nasClearScope => 'Tümüne dön';

  @override
  String get nasRenamePlaylist => 'Çalma listesini yeniden adlandır';

  @override
  String get nasRemoveFromPlaylist => 'Çalma listesinden kaldır';

  @override
  String get nasMoveUp => 'Yukarı taşı';

  @override
  String get nasMoveDown => 'Aşağı taşı';

  @override
  String get nasSshServer => 'SSH sunucusu';

  @override
  String get nasSelectSshServer => 'Kayıtlı SSH sunucusunu seçin';

  @override
  String get nasQualityOriginal => 'Orijinal';

  @override
  String get nasQualityAuto => 'Otomatik';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Kullanılabilir DLNA Cihazları';

  @override
  String get nasCastDiscovering => 'DLNA cihazları aranıyor...';

  @override
  String get nasCastRelayingNotice =>
      'Akış ön plan uygulaması aracılığıyla aktarılıyor. Valhalla\'yı açık tutun.';

  @override
  String get nasCastStop => 'Yayınlamayı Durdur';

  @override
  String get nasCastVolume => 'Ses';

  @override
  String get nasCastRetry => 'Aramayı Tekrar Dene';

  @override
  String get nasInstallTitle => 'NAS Medya Sunucusunu Dağıt';

  @override
  String get nasInstallProduct => 'Ürün';

  @override
  String get nasInstallMediaPath => 'Medya Dizini (Salt Okunur)';

  @override
  String get nasInstallDataRoot => 'Veri ve Yapılandırma Dizini';

  @override
  String get nasInstallPort => 'Port';

  @override
  String get nasInstallBindAddress => 'Bağlama Adresi';

  @override
  String get nasInstallWebdavUser => 'WebDAV Kullanıcı Adı';

  @override
  String get nasInstallWebdavPassword => 'WebDAV Şifresi (en az 12 karakter)';

  @override
  String get nasInstallPreparePlan => 'Dağıtım Planını İncele';

  @override
  String get nasInstallPlanTitle => 'Teknik İnceleme ve Onay';

  @override
  String get nasInstallBlockersTitle => 'Dağıtım Engelleyicileri';

  @override
  String get nasInstallConfirmDeploy => 'Onayla ve Kur';

  @override
  String get nasInstallDeploying => 'Konteyner dağıtılıyor...';

  @override
  String get nasInstallSuccess => 'Başarıyla Dağıtıldı';

  @override
  String get nasInstallSuccessDesc =>
      'Hizmet şu anda çalışıyor. Bir medya kaynağı olarak eklemeden önce sunucu ilk kurulumunu tamamlayın.';

  @override
  String get nasInstallContainerId => 'Konteyner Kimliği';

  @override
  String get nasInstallEndpoint => 'Uç Nokta';

  @override
  String get nasUseSshTunnel => 'SSH Tüneli Kullan';

  @override
  String get nasUseSshTunnelDesc =>
      'Trafiği kayıtlı bir SSH sunucusu üzerinden yönlendirin (örn. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Uç nokta SSH sunucusundan erişilebilir olmalıdır, örn. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Mevcut şifreyi / belirteci korumak için boş bırakın';

  @override
  String get nasSourceNameRequired => 'Kaynak adı zorunludur';

  @override
  String get nasInvalidEndpoint => 'Geçersiz uç nokta URL\'si veya şeması';

  @override
  String get nasSourceUnreachable => 'Medya kaynağına ulaşılamıyor';

  @override
  String get nasSshTunnelFailed => 'SSH tünel bağlantısı başarısız oldu';

  @override
  String get nasOperationFailed => 'İşlem başarısız oldu';

  @override
  String get nasInstallStepCreateDir => 'Özel dizin oluştur';

  @override
  String get nasInstallStepWriteCompose =>
      'docker-compose.json yapılandırmasını yaz';

  @override
  String get nasInstallStepWriteCreds => 'Özel kimlik bilgilerini yaz';

  @override
  String get nasInstallStepPullImage => 'Sabitlenmiş konteyner imajını çek';

  @override
  String get nasInstallStepStartService =>
      'Konteynerleştirilmiş hizmeti başlat';

  @override
  String get nasInstallStepCheckHttp => 'Hizmet HTTP sağlığını kontrol et';

  @override
  String get nasInstallBlockerDocker =>
      'Hedef sunucuda Docker Engine gereklidir';

  @override
  String get nasInstallBlockerCompose => 'Docker Compose eklentisi gereklidir';

  @override
  String get nasInstallBlockerIdentity => 'Hedef sunucu kimliği doğrulanamadı';

  @override
  String get nasInstallBlockerTools =>
      'Gerekli araçlar (curl, ss, realpath) hedef sunucuda eksik';

  @override
  String get nasInstallBlockerMedia =>
      'Medya dizini mevcut değil veya okunamıyor';

  @override
  String get nasInstallBlockerParent =>
      'Veri kökü üst dizini yazılabilir değil';

  @override
  String get nasInstallBlockerOverlap =>
      'Medya dizini ile veri dizini çakışamaz';

  @override
  String get nasInstallBlockerCollision =>
      'Hedef veri dizini zaten mevcut veya bir sembolik bağlantı';

  @override
  String get nasInstallBlockerPort =>
      'Seçilen port hedef sunucuda zaten kullanımda';

  @override
  String get nasInstallBlockerContainer =>
      'Bu proje adına sahip bir konteyner zaten mevcut';

  @override
  String get nasInstallBlockerImage =>
      'Konteyner imajı doğrulanamadı. İmaj adını, ağ bağlantısını ve sunucu mimarisini kontrol edin, ardından tekrar deneyin.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Geri döngü bağlama (127.0.0.1) uzaktan erişim için SSH tüneli gerektirir';

  @override
  String get nasInstallGuidanceTls =>
      'Genel bağlamanın TLS ters proxy arkasında güvenceye alınması önerilir';

  @override
  String get nasInstallGuidanceSetup =>
      'İlk başlatmada tarayıcıda ilk yönetici hesabı kurulumunu tamamlayın';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Dosyalarınızı korumak için medya dizini salt okunur olarak bağlanır';

  @override
  String get nasInstallGuidancePreserved =>
      'Sorun giderme için arıza durumunda veri dizini korunacaktır';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'İndirildi (Harici olarak açılamadı)';

  @override
  String get nasRetryOpen => 'Açmayı Tekrar Dene';

  @override
  String get nasExternalOpenFailed => 'Dosya harici uygulamada açılamadı';

  @override
  String get nasTitle => 'NAS Medya';

  @override
  String get nasLoadMoreGroups => 'Daha fazla grup yükle';

  @override
  String get nasMetadataEnriching => 'Müzik etiketleri zenginleştiriliyor...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Müzik etiketleri zenginleştiriliyor ($count işlendi)...';
  }

  @override
  String nasDownloading(String value) {
    return '$value indiriliyor…';
  }

  @override
  String get nasSubtitleNone => 'Yok';

  @override
  String get nasLibraryId => 'Kitaplık Kimliği';

  @override
  String get nasLibraryIdHint =>
      'Varsayılan: tümü (/), veya kitaplık kimliğini belirtin';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Kaynak köküne göre ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Yapılandırma sırasında kaynak değişti, kaydetme iptal edildi';

  @override
  String get nasInvalidLibraryId => 'Geçersiz kitaplık kimliği';

  @override
  String get startupFailed => 'Uygulama başlatılamadı';

  @override
  String get startupFailedDesc =>
      'Başlangıç sırasında beklenmeyen bir hata oluştu. Tekrar deneyebilir veya teşhis günlüklerini dışa aktarabilirsiniz.';

  @override
  String get retryStartup => 'Başlatmayı Tekrar Dene';

  @override
  String get viewDiagnostics => 'Teşhisleri Görüntüle';

  @override
  String get exportDiagnostics => 'Teşhisleri Dışa Aktar';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Teşhisler $path konumuna aktarıldı';
  }

  @override
  String get diagnosticsExportFailed => 'Teşhisler dışa aktarılamadı';

  @override
  String get diagnosticsTitle => 'Uygulama Teşhisleri';

  @override
  String get settingsDiagnostics => 'Teşhisler ve Günlükler';

  @override
  String get settingsDiagnosticsDesc =>
      'Yerel arındırılmış uygulama günlüklerini görüntüleyin ve dışa aktarın';

  @override
  String get diagnosticsEmpty => 'Teşhis kaydı bulunamadı';

  @override
  String diagnosticsStorageError(String error) {
    return 'Teşhis depolama hatası: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Kurtarılabilir olay bildirildi: $category';
  }

  @override
  String get diagnosticsRefresh => 'Günlükleri Yenile';

  @override
  String get nasInstallTaskTitle => 'Dağıtım Görevi';

  @override
  String get nasInstallStagePreflight => 'Ön Kontrol';

  @override
  String get nasInstallStageReview => 'Plan İncelemesi';

  @override
  String get nasInstallStageWriting => 'Yapılandırma Yazılıyor';

  @override
  String get nasInstallStagePulling => 'İmaj Çekiliyor';

  @override
  String get nasInstallStageStarting => 'Konteyner Başlatılıyor';

  @override
  String get nasInstallStageHealth => 'Sağlık Kontrolü';

  @override
  String get nasInstallStageCleanup => 'Temizleniyor';

  @override
  String get nasInstallStageSucceeded => 'Dağıtım Başarılı Oldu';

  @override
  String get nasInstallStageFailed => 'Dağıtım Başarısız Oldu';

  @override
  String get nasInstallStageCancelled => 'Dağıtım İptal Edildi';

  @override
  String get nasInstallStageNeedsInspection => 'İnceleme Gerektiriyor';

  @override
  String get nasInstallStageReconciling => 'Durum Uzlaştırılıyor';

  @override
  String get nasInstallCancel => 'Dağıtımı İptal Et';

  @override
  String get nasInstallReconcile => 'Durumu Uzlaştır';

  @override
  String get nasInstallServerNotFound => 'Seçilen sunucu bulunamadı';

  @override
  String get nasInstallPortRangeError => 'Port 1 ile 65535 arasında olmalıdır';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Geçen süre: $time';
  }

  @override
  String get nasInstallLogTail => 'Son Günlükler';

  @override
  String get nasInstallCleanupCompleted => 'Geri alma temizliği tamamlandı';

  @override
  String get nasInstallCleanupIncomplete => 'Geri alma temizliği tamamlanmadı';

  @override
  String get nasInstallNewDeployment => 'Yeni Dağıtım';

  @override
  String get nasInstallBackEdit => 'Geri / Formu Düzenle';

  @override
  String get nasInstallClose => 'Kapat';

  @override
  String get nasInstallMediaPathHint =>
      'Ana bilgisayarda salt okunur bağlama noktası (örn. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Özel veri ve yapılandırma dizini (henüz mevcut olmamalıdır)';

  @override
  String get nasInstallBindAddressHint =>
      'Tünel için 127.0.0.1, LAN için 0.0.0.0';

  @override
  String get nasInstallWebdavPasswordHint => 'En az 12 karakter gereklidir';

  @override
  String get nasInstallTargetServer => 'Hedef Sunucu';

  @override
  String get nasInstallTargetImage => 'Hedef İmaj';

  @override
  String get nasInstallContainerName => 'Konteyner Adı';

  @override
  String get nasInstallBindAndPort => 'Bağlama ve Port';

  @override
  String get nasInstallComposePreview => 'docker-compose.json Önizlemesi';

  @override
  String get nasInstallPlannedSteps => 'Planlanan Adımlar';

  @override
  String get nasInstallGuidanceNotes => 'Dağıtım Notları ve Rehberlik';

  @override
  String get nasInstallNoLogsYet => 'Henüz günlük yok';

  @override
  String get sftpPreviewTooLarge =>
      'Dosya 1 MiB önizleme sınırını aşıyor. Lütfen indirin ve harici olarak açın.';

  @override
  String get sftpSaveFailed =>
      'Dosya kaydedilemedi. İzinleri veya ağ bağlantısını kontrol edin.';

  @override
  String get sftpSaving => 'Kaydediliyor...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Hedef sunucu bağlantısı değişti; devam etmeden önce uzak durumu doğrulayın';

  @override
  String get nasInstallBlockerCancelled =>
      'Dağıtım kullanıcı tarafından iptal edildi. Ayarları gözden geçirin ve gerekirse tekrar deneyin.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'İnceleme uzak konteyneri sorgulayamadı. Sunucu bağlantısını kontrol edin veya manuel olarak inceleyin.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Dağıtım adımı zaman aşımına uğradı. Sunucu yükünü veya ağ bağlantısını kontrol edip tekrar deneyin.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Dağıtım kesintiye uğradı; devam etmeden önce uzak durumu gözden geçirin.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Hizmet başlatıldı ancak HTTP sağlık kontrolü zaman aşımına uğradı. Hizmet günlüklerini veya port kullanılabilirliğini doğrulayın.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Uzlaştırma başarısız oldu. Uzak konteyner durumunu manuel olarak doğrulayın veya yeni bir dağıtım başlatın.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Uzak konteyner durumu belirsiz. Manuel inceleme ve uzlaştırma gereklidir.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Konteyner süreci zamanından önce sonlandı. Yapılandırma veya izin hataları için günlükleri kontrol edin.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Hedef sunucuya dağıtım dosyaları yazılamadı. Disk alanını ve izinleri kontrol edin.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Dağıtım planı güncelliğini yitirdi. Lütfen ön kontrolleri yeniden çalıştırın.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Mevcut konteyner bu uygulama tarafından oluşturulmadı. Üzerine yazılmasını önlemek için manuel olarak inceleyin.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Hedef sunucuya aktif bir SSH bağlantısı gereklidir.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Uzak durum yerel durumdan farklı. Devam etmeden önce lütfen uzlaştırın.';

  @override
  String get nasInstallBlockerFailed =>
      'Dağıtım sırasında bir hata oluştu. Günlükleri kontrol edin ve tekrar deneyin.';

  @override
  String get nasInstallBlockerBusy =>
      'Zaten bir kurulum görevi devam ediyor. Lütfen mevcut görev ilerlemesini kontrol edin.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Dağıtım durumu kalıcı hale getirilemedi. Lütfen yerel depolama alanını ve dosya izinlerini kontrol edin.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Uzak komut sonucu bilinmiyor. Dağıtımı doğrudan yeniden denemek yerine lütfen salt okunur bir inceleme çalıştırın.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Dağıtım öncesi ortam kontrolü başarısız oldu. Lütfen devam etmeden önce engelleyicileri çözün.';

  @override
  String serverDeleteFailed(String error) {
    return 'Sunucu silinemedi: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Ajan Modu';

  @override
  String get chatRunSettingsApprovalPolicy => 'Yerel Onay Politikası';

  @override
  String get chatRunSettingsExtraSettings => 'Ek Ayarlar';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Bilinen güvenli işlemlere otomatik olarak izin verir; işlem güvenliği belirlenemediğinde her zaman sorar.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Çalıştırma ayarları uygulanamadı: $error';
  }

  @override
  String get chatMessageCopied => 'Mesaj panoya kopyalandı';

  @override
  String get copy => 'Kopyala';

  @override
  String get rename => 'Yeniden Adlandır';

  @override
  String get refresh => 'Yenile';

  @override
  String get sessionTitle => 'Oturum Başlığı';

  @override
  String get chatSettingsStale => 'Eski';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Ayarlar ilk mesajdan sonra kullanılabilir';

  @override
  String get chatReimportAsCopy => 'Kopya Olarak Yeniden İçe Aktar';

  @override
  String get chatSearchCommandsHint => 'Komutları veya becerileri ara...';

  @override
  String get chatCommandsTab => 'Komutlar';

  @override
  String get chatSkillsTab => 'Beceriler';

  @override
  String get chatAccountAndQuotaTitle => 'Hesap ve Kota';

  @override
  String get chatAccountSectionTitle => 'Hesap';

  @override
  String get chatAccountNotProvided => 'Bildirilen hesap ayrıntısı yok';

  @override
  String get chatAccountKind => 'Tür';

  @override
  String get chatAccountLabel => 'Etiket';

  @override
  String get chatAccountPlan => 'Plan';

  @override
  String get chatAccountEmail => 'E-posta';

  @override
  String get chatAccountUpdatedAt => 'Güncellendi';

  @override
  String get chatQuotaSectionTitle => 'Kota ve Durum';

  @override
  String get chatStatusSourceNote => 'Ham Ajan /status Çıktısı';

  @override
  String get chatStatusNotQueried => 'Durum henüz sorgulanmadı';

  @override
  String get chatQueryStatusAction => 'Durumu Sorgula (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Mevcut oturumda durum sorgusu kullanılamıyor';

  @override
  String get chatAttachmentMissing => 'Ek dosyası eksik veya kullanılamıyor';

  @override
  String get chatViewModeList => 'Liste';

  @override
  String get chatViewModeCards => 'Kartlar';

  @override
  String get chatViewModeGrid => 'Resimler';

  @override
  String get chatRemoteBrowserTitle => 'Uzak Çalışma Alanı';

  @override
  String get chatSelectDirectory => 'Dizin Seçin';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Seçilenleri Ekle ($count)';
  }

  @override
  String get chatNoFilesFound => 'Dosya bulunamadı';

  @override
  String get chatRootDirectory => 'Kök';

  @override
  String get chatSelectThisDirectory => 'Bu dizini kullan';

  @override
  String get chatAgentVersion => 'Ajan Sürümü';

  @override
  String get chatParentDirectory => 'Üst Dizin';

  @override
  String get chatSearchFilesHint => 'Dosyaları ara...';

  @override
  String get chatCommandsEmpty =>
      'Ajan tarafından sağlanan eğik çizgi komutu yok';

  @override
  String get chatSkillsEmpty => 'Ajan tarafından sağlanan beceri yok';

  @override
  String get chatFileUnsupported => 'Ek için dosya türü desteklenmiyor';

  @override
  String get chatStatusNotProvided =>
      'Durum sorgusu ajan tarafından sağlanmıyor';

  @override
  String get sessionRecoveryReconnecting => 'Yeniden bağlanılıyor...';

  @override
  String get sessionRecoverySyncing => 'Çıktı senkronize ediliyor...';

  @override
  String get sessionRecoveryIncomplete => 'Bazı çıktılar kurtarılamadı';

  @override
  String get sessionRecoveryFailed => 'Kurtarma başarısız oldu';

  @override
  String get sessionRecoveryRetry => 'Tekrar Dene';

  @override
  String get dashboardUpdatesPaused => 'Güncellemeler duraklatıldı';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'CLI model kataloğu şu anda kullanılamıyor. Modeller önbelleğe alınmış veya CLI sürümüyle sınırlı olabilir; bir model adını manuel olarak da girebilirsiniz.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Modeller, mevcut CLI girişiniz kullanılarak CLI uygulama sunucusundan sorgulanır. Katalog önbelleğe alınmış veya sürümle sınırlı olabilir; manuel olarak yenileyebilir veya manuel girişe geçebilirsiniz.';

  @override
  String get chatModelCatalogError403 =>
      'CLI model sorgusu erişimi reddedildi (403). CLI girişini ve hizmet bağlantısını kontrol edin veya manuel olarak bir model adı girin.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Model kataloğu hatası: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Model Kataloğunu Yetkilendir';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Model Kataloğunu Yetkilendir';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Bu, hedef ana bilgisayarda/konteynerde model kataloğu için tarayıcı yetkilendirmesini başlatacaktır. Mevcut Codex girişiniz ve terminal oturumlarınız tamamen dokunulmadan kalacaktır. Devam edilsin mi?';

  @override
  String get chatModelAuthorizing =>
      'Tarayıcı aracılığıyla yetkilendiriliyor...';

  @override
  String get chatModelAuthorizeCancel => 'Yetkilendirmeyi İptal Et';

  @override
  String get chatCommandsFirstTurnNote =>
      'Eğik çizgi komutları, oturum başlatılır başlatılmaz ajan çalışma zamanı tarafından tanıtılacaktır; önceden sıradan bir konuşma gerekmez; taslaklar otomatik olarak oturum oluşturmaz.';

  @override
  String get chatCommandsClientActionRunSettings => 'Çalıştırma Ayarları';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Çalışma Dizini';

  @override
  String get chatCommandsClientActionsSection => 'Yerel Eylemler';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Model Listesi';

  @override
  String get chatRunSettingsModelSourceCustom => 'Manuel Giriş';

  @override
  String get chatRunSettingsCustomModelHint => 'Model kimliğini girin';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Manuel model adları doğrulanmamıştır ve doğrudan desteklenmeyen modelleri reddedebilecek olan ajan çalışma zamanına gönderilecektir.';

  @override
  String get chatRunSettingsCustomModelEmptyError => 'Model adı boş olamaz';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Model adı boşluk veya denetim karakteri içermeyen en fazla 256 karakter olmalıdır';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Geçerli bağdaştırıcı sürümü için doğrulanan komutlar. Seçim metni taslağa ekler; Gönder, oturumu istek üzerine başlatacak ve komutu doğrudan çalıştıracaktır.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Komutlar veya beceriler keşfedilemedi';

  @override
  String get chatAuthWaitingForBrowser =>
      'Tarayıcıda yetkilendirme bekleniyor...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Harici tarayıcı açılamadı. Lütfen aşağıdaki yetkilendirme bağlantısını yeniden açın veya kopyalayın.';

  @override
  String get chatAuthReopenBrowser => 'Tarayıcıyı Yeniden Aç';

  @override
  String get chatAuthCopyLink => 'Bağlantıyı Kopyala';

  @override
  String get chatAuthManualCallback => 'Manuel Geri Çağırma';

  @override
  String get chatAuthManualCallbackTitle =>
      'Yetkilendirme Geri Çağırma URL\'sini Girin';

  @override
  String get chatAuthManualCallbackDesc =>
      'Yetkilendirmeyi tamamlamak için tarayıcıdan tam yeniden yönlendirme URL\'sini (http://127.0.0.1:PORT/...?code=...&state=...) yapıştırın. Ham yetkilendirme kodları kabul edilmez.';

  @override
  String get chatAuthCallbackInputLabel => 'Geri Çağırma URL\'si';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Geçersiz geri çağırma URL biçimi veya teslimat başarısız oldu';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP, terminal CLI girişinden ayrı olarak resmi hesap yetkilendirmesi gerektirir.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Bu tur ACP kimlik doğrulaması gerektiriyor. Devam etmek için yeniden bağlanın ve yetkilendirme isteyin.';

  @override
  String get chatRequestAuthButton => 'Kimlik Doğrulama İste';

  @override
  String get agentActionAcpLogin => 'ACP Girişi';

  @override
  String get agentActionCliLogin => 'CLI Girişi';

  @override
  String get agentAgyAcpSignInRequired =>
      'ACP kimlik bilgileri eksik (ACP girişi gerekli)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'ACP kimlik bilgileri kaydedildi (doğrulanmadı)';

  @override
  String get chatAuthMethodUnavailable =>
      'Seçilen kimlik doğrulama yöntemi kullanılamıyor.';

  @override
  String get chatAuthConnectionExpired =>
      'Kimlik doğrulama bağlantısının süresi doldu. Lütfen tekrar deneyin.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Yetkilendirme geri çağırması sunucuya teslim edilemedi.';

  @override
  String get agentTargetChangedNotice =>
      'Hedef sunucu değişti. Lütfen mevcut sunucuda ajan yönetimini yeniden açın.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Antigravity kimlik doğrulama kontrolü kullanılamıyor';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Antigravity kimlik doğrulama kontrolü yanıtı geçersiz';

  @override
  String get sftpDownloadDisconnected => 'İndirme bağlantısı kesildi';

  @override
  String get sftpDownloadPermissionDenied => 'İzin reddedildi';

  @override
  String get sftpDownloadNotFound => 'Uzak dosya bulunamadı';

  @override
  String get sftpDownloadTimeout => 'İndirme zaman aşımına uğradı';

  @override
  String get sftpDownloadLocalSpace => 'Yetersiz yerel depolama alanı';

  @override
  String get sftpDownloadLocalIo => 'Yerel depolamaya yazma başarısız oldu';

  @override
  String get sftpDownloadIncomplete => 'Tamamlanmamış indirme';

  @override
  String get transferStatusWaitingConnection => 'Bağlantı bekleniyor';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Yerel yetkilendirme geri çağırma dinleyicisi başlatılamadı. Lütfen kimlik doğrulamasını tekrar deneyin.';

  @override
  String get settingsExperimentalFeatures => 'Deneysel Özellikler';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Önizleme ve deneysel yetenekleri deneyin';

  @override
  String get settingsExperimentalCliChatTitle => 'CLI Akıllı Sohbet';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Özel komut satırı ajanı sohbet arayüzünü etkinleştirin';

  @override
  String get settingsExperimentalDialogClose => 'Kapat';

  @override
  String get settingsExperimentalSaveFailed =>
      'Deneysel özellik ayarları güncellenemedi';

  @override
  String get settingsExperimentalNasTitle => 'NAS Medya';

  @override
  String get settingsExperimentalNasDesc =>
      'Medya kitaplığını, klasör taramasını ve ses oynatmayı etkinleştirin';

  @override
  String get settingsLanguageSaveFailed => 'Dil ayarları güncellenemedi';

  @override
  String get settingsAboutPrivacy => 'Hakkında ve gizlilik';

  @override
  String get privacyPolicyTitle => 'Gizlilik politikası';

  @override
  String get privacyPolicyDescription => 'Veri kullanımı ve seçenekleriniz';

  @override
  String get privacyContactTitle => 'Gizlilik iletişimi';

  @override
  String get privacyCopyEmail => 'E-posta adresini kopyala';

  @override
  String get privacyEmailCopied => 'E-posta adresi kopyalandı';

  @override
  String get privacyOnlineVersion => 'Çevrimiçi sürümü görüntüle';

  @override
  String get privacyLinkFailed =>
      'Bağlantı açılamadı. E-posta adresini kopyalayabilirsiniz.';

  @override
  String get privacyLoadFailed =>
      'Politika yüklenemedi. Çevrimiçi sürümü görüntüleyin.';

  @override
  String get privacyVersionUnknown => 'Sürüm bilgisi yok';

  @override
  String get aboutWebsite => 'Resmî web sitesi';

  @override
  String get aboutLicense => 'Uygulama lisansı';

  @override
  String get aboutThirdPartyLicenses => 'Üçüncü taraf açık kaynak lisansları';

  @override
  String get aboutLicenseSummary =>
      'Valhalla özgün içeriği PolyForm Noncommercial 1.0.0 kapsamında ticari olmayan kullanım için lisanslanmıştır. Lisans izinleri dışındaki ticari kullanım ayrı yetkilendirme gerektirir. Üçüncü taraf bileşenler kendi lisanslarını korur. Kullanımı aşağıdaki tam koşullar belirler.';

  @override
  String get aboutCopyrightNotice => 'Telif hakkı bildirimleri';

  @override
  String get aboutLicenseLoadFailed =>
      'Lisans yüklenemedi. norns.soft@gmail.com ile iletişime geçin.';

  @override
  String get aboutLinkFailed =>
      'Bağlantı açılamadı. Tarayıcınızda https://norns.cc.cd adresini açın.';

  @override
  String get downloadReveal => 'Dosya Gezgini’nde göster';

  @override
  String get downloadRevealFailed =>
      'İndirme klasörü açılamadı. Taşınmış veya silinmiş olabilir.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count güvenilen ana bilgisayar anahtarı';
  }

  @override
  String get settingsKnownHostsEmpty =>
      'Güvenilen ana bilgisayar anahtarı bulunamadı';

  @override
  String get settingsKnownHostsDialogTitle =>
      'Bilinen Ana Bilgisayar Anahtarları';

  @override
  String get settingsHostKeyRevoke => 'İptal Et';

  @override
  String get settingsHostKeyRevokeConfirmTitle =>
      'Ana Bilgisayar Anahtarını İptal Et';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return '$hostPort için ana bilgisayar anahtarı iptal edilsin mi? Bu ana bilgisayara olan etkin SSH bağlantıları kesilecek ve sonraki bağlantıda anahtarı doğrulamanız gerekecektir.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Ana bilgisayar anahtarı parmak izi panoya kopyalandı';

  @override
  String get settingsHostKeyRevoked => 'Ana bilgisayar anahtarı iptal edildi';

  @override
  String get settingsClearStorageSubtitle =>
      'Seçili sunucuların kayıtlı parolalarını ve özel anahtarlarını temizle';

  @override
  String get settingsClearStorageDialogTitle =>
      'Sunucu Kimlik Bilgilerini Sıfırla';

  @override
  String get settingsClearStorageDesc =>
      'Güvenli depolamadan SSH parolalarını ve özel anahtarlarını temizlemek için sunucuları seçin. Sunucu yapılandırmaları ve sohbet geçmişleri silinmeyecektir.';

  @override
  String get settingsClearStorageNoServers => 'Kullanılabilir sunucu yok';

  @override
  String get settingsClearStorageSelectAll => 'Tümünü Seç';

  @override
  String get settingsClearStorageDeselectAll => 'Seçimi Kaldır';

  @override
  String get settingsClearStorageConfirmTitle =>
      'Kimlik Bilgisi Sıfırlamayı Onayla';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'Seçili $count sunucu için kimlik bilgilerini temizlemek istediğinizden emin misiniz? Etkin bağlantılar derhal kesilecektir.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Seçilenleri Temizle ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Seçili sunucu kimlik bilgileri başarıyla temizlendi';

  @override
  String get settingsClearStorageError =>
      'Bazı sunucuların kimlik bilgileri temizlenemedi. Lütfen tekrar deneyin.';

  @override
  String get settingsDefaultAcpAgent => 'Varsayılan ACP Temsilcisi';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Bu sunucudaki ACP sohbeti için varsayılan temsilci';

  @override
  String get settingsDefaultCliAgent => 'Varsayılan CLI Temsilcisi';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Bu sunucudaki CLI sohbeti için varsayılan temsilci';

  @override
  String get settingsDefaultAgentAutomatic => 'Otomatik (ilk kullanılabilir)';

  @override
  String get settingsDefaultAgentSelectTitle => 'Varsayılan Temsilciyi Seç';

  @override
  String get settingsDefaultAgentNoServer => 'Sunucu seçilmedi';

  @override
  String get settingsDefaultAgentNoAgents =>
      'Bu sunucu için yapılandırılmış temsilci yok';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Varsayılan temsilci ayarı güncellenemedi';

  @override
  String get dockerViewGroupContainers => 'Konteynerler';

  @override
  String get dockerViewGroupProjects => 'Compose Projeleri';

  @override
  String get dockerProjectActionStart => 'Projeyi Başlat';

  @override
  String get dockerProjectActionStop => 'Projeyi Durdur';

  @override
  String get dockerProjectActionRestart => 'Projeyi Yeniden Başlat';

  @override
  String get dockerProjectConfirmStopTitle => 'Compose Projesini Durdur';

  @override
  String get dockerProjectConfirmRestartTitle =>
      'Compose Projesini Yeniden Başlat';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return '\"$project\" projesini $action istediğinizden emin misiniz? Aşağıdaki $count konteyner etkilenecektir:';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return '\"$project\" projesi $action başarıyla tamamlandı';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return '\"$project\" projesi $action $failedCount hata ile tamamlandı';
  }

  @override
  String get dockerNoProjects => 'Docker Compose projesi bulunamadı';

  @override
  String get dockerMountsTitle => 'Bağlama Noktaları';

  @override
  String get dockerMountReadOnly => 'Salt okunur';

  @override
  String get dockerMountReadWrite => 'Okuma/Yazma';

  @override
  String get sftpBookmarksTitle => 'Dizin Yer İmleri';

  @override
  String get sftpNoBookmarks => 'Henüz kaydedilmiş yer imi yok';

  @override
  String get sftpAddBookmark => 'Yer İmi Ekle';

  @override
  String get sftpRemoveBookmark => 'Yer İmini Kaldır';

  @override
  String get sftpCurrentDirectory => 'Mevcut Dizin';

  @override
  String get sftpSelectMode => 'Çoklu Seçim Modu';

  @override
  String sftpSelectedCount(int count) {
    return '$count seçildi';
  }

  @override
  String get sftpSelectAll => 'Tümünü Seç';

  @override
  String get sftpDeselectAll => 'Seçimi Kaldır';

  @override
  String get sftpBatchCopy => 'Kopyala';

  @override
  String get sftpBatchMove => 'Taşı';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Toplu Silmeyi Onayla';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'Seçili $count öğeyi silmek istediğinizden emin misiniz?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Not: Boş olmayan dizinler özyinelemeli olarak silinemez ve atlanacaktır.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Toplu Kopyalamayı Onayla';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'Seçilen $count öğe \"$directory\" hedefine kopyalansın mı?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Toplu Taşımayı Onayla';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'Seçilen $count öğe \"$directory\" hedefine taşınsın mı?';
  }

  @override
  String get sftpBatchResultsTitle => 'Toplu İşlem Sonuçları';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Atlandı (hedef zaten var veya desteklenmiyor)';

  @override
  String get sftpBatchTargetRestricted =>
      'Mevcut dizin veya alt dizinleri hedef olarak seçilemez';

  @override
  String get sftpSelectCurrentDir => 'Bu Dizini Seç';

  @override
  String sftpBatchOperationSuccess(int count) {
    return '$count öğe başarıyla işlendi';
  }

  @override
  String get configMigrationTitle => 'Yedekleme ve Yapılandırma Taşıma';

  @override
  String get configExportTitle => 'Yapılandırmayı Dışa Aktar';

  @override
  String get configExportSubtitle =>
      'Sunucuları, ajanları, komutları, yer imlerini ve tercihleri JSON\'a aktar';

  @override
  String get configExportDialogTitle => 'Valhalla Yapılandırmasını Dışa Aktar';

  @override
  String get configExportSuccess => 'Yapılandırma başarıyla dışa aktarıldı';

  @override
  String configExportError(String error) {
    return 'Yapılandırma dışa aktarılamadı: $error';
  }

  @override
  String get configImportTitle => 'Yapılandırmayı İçe Aktar';

  @override
  String get configImportSubtitle =>
      'Yedek JSON dosyasından yapılandırmayı içe aktar';

  @override
  String get configBackupTooLarge =>
      'Yedekleme dosyası izin verilen maksimum boyutu (8 MB) aşıyor';

  @override
  String get configImportPreviewTitle => 'Yapılandırma İçe Aktarma Önizlemesi';

  @override
  String get configImportPreviewDesc =>
      'İçe aktarmadan önce içeriği gözden geçirin. Mevcut öğeler korunacak ve birleştirilecektir.';

  @override
  String configImportServersCount(int count) {
    return 'Sunucular ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'Ajanlar ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'Hızlı Komutlar ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'Yer İmleri ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'Özel komutlar hassas komut dosyaları veya gömülü kimlik bilgileri içerebilir. Hiçbir parola, özel anahtar veya güvenilen ana bilgisayar parmak izi aktarılmaz.';

  @override
  String get configImportGlobalPreferences =>
      'Genel uygulama tercihlerini içe aktar';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Mevcut tema, terminal ve gezinme ayarlarının üzerine yazar';

  @override
  String get configImportConfirmAction => 'İçe Aktarmayı Onayla';

  @override
  String get configImportSuccess => 'Yapılandırma başarıyla içe aktarıldı';

  @override
  String get configImportErrorTitle => 'Geçersiz Yapılandırma Yedeği';

  @override
  String configImportErrorGeneric(String error) {
    return 'Yapılandırma içe aktarılamadı: $error';
  }

  @override
  String get configImportErrorCopyDetails => 'Tanılama Ayrıntılarını Kopyala';

  @override
  String get configImportErrorCopied =>
      'Tanılama ayrıntıları panoya kopyalandı';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Desteklenmeyen yedekleme biçimi veya sürümü';

  @override
  String get configImportErrorMalformed =>
      'Hatalı veya bozuk yapılandırma JSON\'u';
}
