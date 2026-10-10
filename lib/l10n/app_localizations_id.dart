// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'Manajemen Server & Agen Berbasis AI';

  @override
  String get navAiChat => 'Obrolan AI';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'Berkas SFTP';

  @override
  String get navCommands => 'Perintah';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get serverConnected => 'Terhubung';

  @override
  String get serverOnline => 'Online';

  @override
  String get serverOffline => 'Offline';

  @override
  String get latencyMs => 'md';

  @override
  String get reconnect => 'Hubungkan Ulang';

  @override
  String get disconnect => 'Putuskan Koneksi';

  @override
  String get quickDisconnect => 'Putus Cepat';

  @override
  String get newSession => 'Sesi Baru';

  @override
  String get historySessions => 'Riwayat Sesi';

  @override
  String get switchAgent => 'Ganti Agen';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agen Aktif';

  @override
  String get inputPromptHint =>
      'Minta Agen mendiagnosis, menjalankan alat, atau menulis perintah... (Enter untuk mengirim)';

  @override
  String get thinking => 'Proses Berpikir';

  @override
  String get executionPlan => 'Rencana Eksekusi';

  @override
  String get toolCall => 'Panggilan Alat';

  @override
  String get toolStatusPending => 'Menunggu';

  @override
  String get toolStatusRunning => 'Menjalankan...';

  @override
  String get toolStatusCompleted => 'Selesai';

  @override
  String get toolStatusFailed => 'Gagal';

  @override
  String get permissionRequired => 'Izin Diperlukan';

  @override
  String get permissionDescription =>
      'Agen ingin mengeksekusi perintah ini di server:';

  @override
  String get permissionReject => 'Tolak';

  @override
  String get permissionAllowOnce => 'Izinkan Sekali';

  @override
  String get permissionAllowAlways => 'Selalu Izinkan';

  @override
  String get quickTroubleshootCpu => 'Atasi CPU Tinggi';

  @override
  String get quickDockerHealth => 'Pemeriksaan Kesehatan Docker';

  @override
  String get quickCleanCache => 'Bersihkan Cache Sistem';

  @override
  String get quickNginxLogs => 'Periksa Log Kesalahan Nginx';

  @override
  String get terminalNewTab => 'Tab Baru';

  @override
  String get terminalCloseTab => 'Tutup Tab';

  @override
  String get terminalClear => 'Bersihkan';

  @override
  String get terminalQuickCmds => 'Palet Perintah';

  @override
  String get terminalPaste => 'Tempel';

  @override
  String get sftpCurrentPath => 'Jalur Saat Ini';

  @override
  String get sftpUpload => 'Unggah';

  @override
  String get sftpNewFolder => 'Folder Baru';

  @override
  String get sftpNewFile => 'Berkas Baru';

  @override
  String get sftpRefresh => 'Segarkan';

  @override
  String get sftpSearchHint => 'Cari berkas atau folder...';

  @override
  String get sftpEmpty => 'Direktori kosong';

  @override
  String get sftpFileName => 'Nama';

  @override
  String get sftpFileSize => 'Ukuran';

  @override
  String get sftpFilePerm => 'Izin';

  @override
  String get sftpFileModified => 'Diubah';

  @override
  String get cmdCategoryDocker => 'TUMPUKAN KONTAINER DOCKER';

  @override
  String get cmdCategorySystem => 'PEMELIHARAAN SISTEM';

  @override
  String get cmdCategoryNetwork => 'JARINGAN & PORT';

  @override
  String get cmdExecute => 'Jalankan';

  @override
  String get cmdDangerous => 'Perintah Berbahaya';

  @override
  String get cmdDangerousWarning =>
      'Operasi ini tidak dapat dibatalkan dan dapat menyebabkan gangguan layanan. Anda yakin ingin melanjutkan?';

  @override
  String get cmdParamRequired => 'Input Parameter Diperlukan';

  @override
  String get cmdConfirm => 'Konfirmasi & Jalankan';

  @override
  String get cmdCancel => 'Batal';

  @override
  String get settingsAppearance => 'Tampilan & Tema';

  @override
  String get settingsThemeMode => 'Mode Tema';

  @override
  String get themeSystem => 'Ikuti Sistem';

  @override
  String get themeSystemDesc => 'Adaptif Otomatis';

  @override
  String get themeLight => 'Mode Terang';

  @override
  String get themeLightDesc => 'Kertas Cerah';

  @override
  String get themeDark => 'Geek Gelap';

  @override
  String get themeDarkDesc => 'Arang Pekat';

  @override
  String get themeAmoled => 'AMOLED Hitam';

  @override
  String get themeAmoledDesc => 'Hitam Murni 0x000000';

  @override
  String get settingsAccentColor => 'Warna Aksen Tema';

  @override
  String get accentCyberEmerald => 'Cyber Emerald';

  @override
  String get accentTechBlue => 'Tech Blue';

  @override
  String get accentElectricViolet => 'Electric Violet';

  @override
  String get accentCrimsonRed => 'Crimson Red';

  @override
  String get accentAmberOrange => 'Amber Orange';

  @override
  String get settingsLanguage => 'Bahasa & Wilayah';

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
  String get settingsAiOps => 'AI Ops & Mesin';

  @override
  String get settingsSecurity => 'Koneksi & Keamanan';

  @override
  String get settingsKnownHosts => 'Kunci Host yang Dikenal';

  @override
  String get settingsClearStorage => 'Atur Ulang Kredensial';

  @override
  String get settingsResetDefault => 'Kembalikan ke Default';

  @override
  String get settingsTerminalUseTmux => 'Sesi Persisten (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Jalankan sesi terminal di dalam tmux pada server jarak jauh';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Menjaga output terminal Anda setelah koneksi terputus. Memerlukan tmux pada server jarak jauh. Perubahan berlaku untuk tab terminal yang baru dibuka.';

  @override
  String get settingsTerminalFontSize => 'Ukuran Font Terminal';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Sesuaikan ukuran font terminal SSH dan CLI';

  @override
  String get version => 'Versi';

  @override
  String get addServer => 'Tambah Server';

  @override
  String get editServer => 'Ubah Server';

  @override
  String get serverName => 'Nama Server';

  @override
  String get serverHost => 'Host / IP';

  @override
  String get serverPort => 'Port';

  @override
  String get serverUsername => 'Nama Pengguna';

  @override
  String get serverAuthType => 'Jenis Autentikasi';

  @override
  String get serverPassword => 'Kata Sandi';

  @override
  String get serverPrivateKey => 'Kunci Privat';

  @override
  String get serverSave => 'Simpan Server';

  @override
  String get serverDelete => 'Hapus Server';

  @override
  String get fileEditor => 'Editor Berkas';

  @override
  String get fileEditorSave => 'Simpan Perubahan';

  @override
  String get fileSavedSuccess => 'Berkas berhasil disimpan';

  @override
  String get addCommand => 'Perintah Baru';

  @override
  String get commandTitle => 'Judul Perintah';

  @override
  String get commandContent => 'Teks Perintah';

  @override
  String get commandCategory => 'Kategori';

  @override
  String get commandDescription => 'Deskripsi';

  @override
  String get save => 'Simpan';

  @override
  String get delete => 'Hapus';

  @override
  String get cancel => 'Batal';

  @override
  String get confirm => 'Konfirmasi';

  @override
  String get cmdExecutionChannel => 'Saluran Eksekusi';

  @override
  String get cmdChannelTerminal => 'Langsung ke Terminal SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'Perintah diketik langsung ke dalam sesi terminal aktif';

  @override
  String get cmdChannelBackground => 'Jalankan di Sesi Latar Belakang';

  @override
  String get cmdChannelBackgroundDesc =>
      'Mengeksekusi melalui shell login SSH dan menangkap output';

  @override
  String get cmdInjectedToTerminal => 'Perintah dikirim ke terminal';

  @override
  String get cmdExecutionCompleted => 'Eksekusi Selesai';

  @override
  String get cmdExecutionFailed => 'Eksekusi Gagal';

  @override
  String get cmdExecutingRemote => 'Mengeksekusi perintah jarak jauh...';

  @override
  String get cmdClose => 'Tutup';

  @override
  String get navDashboard => 'Dasbor';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Sistem';

  @override
  String get navMore => 'Lainnya';

  @override
  String get dashboardTitle => 'Dasbor Server';

  @override
  String get metricsCpu => 'Penggunaan CPU';

  @override
  String get metricsMemory => 'Penggunaan Memori';

  @override
  String get metricsLoadAvg => 'Rata-rata Beban';

  @override
  String get metricsUptime => 'Waktu Aktif Sistem';

  @override
  String get metricsRootDisk => 'Penggunaan Disk Root';

  @override
  String get quickActions => 'Navigasi Cepat';

  @override
  String get activeServerStatus => 'Status Server Aktif';

  @override
  String get noServerSelected =>
      'Tidak ada server yang dipilih saat ini. Silakan pilih server terlebih dahulu.';

  @override
  String get serverDisconnected => 'Terputus';

  @override
  String get serverConnecting => 'Menghubungkan...';

  @override
  String get connectNow => 'Hubungkan Sekarang';

  @override
  String get serverSpecs => 'Informasi & Spesifikasi Server';

  @override
  String get dockerTitle => 'Kontainer Docker';

  @override
  String get dockerSearchHint =>
      'Cari kontainer berdasarkan nama atau gambar...';

  @override
  String get dockerFilterAll => 'Semua';

  @override
  String get dockerFilterRunning => 'Berjalan';

  @override
  String get dockerFilterExited => 'Keluar';

  @override
  String get dockerFilterPaused => 'Dijeda';

  @override
  String get dockerActionStart => 'Mulai';

  @override
  String get dockerActionStop => 'Hentikan';

  @override
  String get dockerActionRestart => 'Mulai Ulang';

  @override
  String get dockerActionPause => 'Jeda';

  @override
  String get dockerActionUnpause => 'Lanjutkan';

  @override
  String get dockerActionRm => 'Hapus';

  @override
  String get dockerActionLogs => 'Log';

  @override
  String get dockerActionInspect => 'Inspeksi';

  @override
  String get dockerLogsTitle => 'Log Kontainer';

  @override
  String get dockerInspectTitle => 'Inspeksi Kontainer';

  @override
  String get dockerNoContainers => 'Tidak ada kontainer ditemukan di server';

  @override
  String get dockerEmptyRunning => 'Tidak ada kontainer yang berjalan';

  @override
  String get dockerPorts => 'Port';

  @override
  String get dockerCreated => 'Dibuat';

  @override
  String get dockerImage => 'Gambar';

  @override
  String get systemTitle => 'Proses & Layanan';

  @override
  String get tabProcesses => 'Proses';

  @override
  String get tabServices => 'Layanan Systemd';

  @override
  String get processSearchHint => 'Cari berdasarkan nama proses atau PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEM';

  @override
  String get processStat => 'Status';

  @override
  String get processCommand => 'Perintah';

  @override
  String get processTerminate => 'Hentikan (SIGTERM)';

  @override
  String get processForceKill => 'Paksa Berhenti (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Menolak menghentikan init sistem (PID <= 1)';

  @override
  String get serviceSearchHint => 'Cari layanan berdasarkan nama...';

  @override
  String get serviceName => 'Layanan';

  @override
  String get serviceDescription => 'Deskripsi';

  @override
  String get serviceStatus => 'Status';

  @override
  String get serviceStartup => 'Startup';

  @override
  String get serviceActionStart => 'Mulai';

  @override
  String get serviceActionStop => 'Hentikan';

  @override
  String get serviceActionRestart => 'Mulai Ulang';

  @override
  String get serviceActionReload => 'Muat Ulang';

  @override
  String get serviceActionEnable => 'Aktifkan';

  @override
  String get serviceActionDisable => 'Nonaktifkan';

  @override
  String get serviceNoServices => 'Tidak ada layanan systemd ditemukan';

  @override
  String get riskDangerTitle => 'Konfirmasi Operasi Berisiko Tinggi';

  @override
  String get riskWarningTitle => 'Konfirmasi Peringatan Operasi';

  @override
  String get riskSafeTitle => 'Konfirmasi Tindakan';

  @override
  String get riskIrreversibleWarning =>
      'Operasi ini diklasifikasikan sebagai RISIKO TINGGI dan tidak dapat dibatalkan. Tindakan ini dapat menyebabkan hilangnya data atau gangguan layanan.';

  @override
  String get riskWarningDescription =>
      'Operasi ini dapat memengaruhi layanan aktif atau memulai ulang proses. Lanjutkan dengan hati-hati.';

  @override
  String get riskCommandPreview => 'Pratinjau Perintah';

  @override
  String get riskConfirmButton => 'Konfirmasi & Lanjutkan';

  @override
  String get riskCancelButton => 'Batal';

  @override
  String get stateLoading => 'Memuat data jarak jauh...';

  @override
  String get stateOffline => 'Server sedang offline';

  @override
  String get stateOfflineDesc =>
      'Buat koneksi SSH aktif untuk mengelola sumber daya dan mengalirkan metrik.';

  @override
  String get stateError => 'Terjadi kesalahan';

  @override
  String get stateRetry => 'Coba Lagi';

  @override
  String get stateEmpty => 'Tidak ada item yang ditemukan';

  @override
  String get inspectorTitle => 'Inspektur';

  @override
  String get inspectorClose => 'Tutup';

  @override
  String get inspectorDetails => 'Detail Inspeksi';

  @override
  String get selectServerTitle => 'Pilih Server Target';

  @override
  String get sshDisconnectedSuccess => 'Koneksi SSH terputus';

  @override
  String get trustHostFingerprintTitle => 'Percayai Sidik Jari Host?';

  @override
  String get trustAndConnect => 'Percayai & Hubungkan';

  @override
  String get reject => 'Tolak';

  @override
  String get confirmDeleteServerTitle => 'Hapus Server';

  @override
  String get noServersFound => 'Belum ada server yang dikonfigurasi';

  @override
  String get agentNotReadyError =>
      'Agen yang dipilih belum siap. Harap verifikasi lingkungan dan konfigurasinya.';

  @override
  String get sshDisconnectedError =>
      'SSH terputus. Silakan hubungkan ke server sebelum menggunakan AI Ops.';

  @override
  String get noAgentAvailable => 'Tidak Ada Agen yang Tersedia';

  @override
  String get noAgentAvailablePrompt =>
      'Tidak ada Agen aktif yang tersedia. Harap konfigurasi atau siapkan agen terlebih dahulu.';

  @override
  String get noAgentAvailableHint =>
      'Pilih atau konfigurasi agen yang tersedia untuk mengobrol...';

  @override
  String get manageAgents => 'Kelola Agen';

  @override
  String get noReadyAgentsTitle => 'Tidak Ada Agen yang Siap';

  @override
  String get noReadyAgentsDesc =>
      'Tidak ada agen di server ini yang lolos pemeriksaan lingkungan.';

  @override
  String get agentStatusReady => 'Siap';

  @override
  String get agentStatusChecking => 'Memeriksa...';

  @override
  String get agentStatusCliMissing => 'Instalasi tidak terdeteksi';

  @override
  String get agentStatusAcpMissing => 'Komponen ACP tidak terdeteksi';

  @override
  String get agentStatusNotLoggedIn => 'Belum Masuk';

  @override
  String get agentStatusError => 'Kesalahan';

  @override
  String get agentStatusUnknown => 'Tidak Diketahui';

  @override
  String get agentActionInstall => 'Instal';

  @override
  String get agentActionLogin => 'Masuk';

  @override
  String get agentActionRefresh => 'Periksa Status';

  @override
  String get noConfiguredAgents =>
      'Tidak ada agen yang dikonfigurasi di server ini';

  @override
  String get agentManagementTitle => 'Manajemen Agen';

  @override
  String get settingsAgentManagement => 'Manajemen Agen';

  @override
  String get settingsAgentManagementSubtitle =>
      'Konfigurasi, deteksi, dan kelola Agen ACP untuk server saat ini';

  @override
  String get addAgentButton => 'Tambah Agen';

  @override
  String get noServerSelectedForAgents =>
      'Tidak ada server yang dipilih. Silakan pilih server dari antarmuka utama terlebih dahulu.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH terputus. Deteksi, instalasi, dan login dinonaktifkan hingga koneksi dibuat.';

  @override
  String get noAgentsConfiguredTitle => 'Tidak Ada Agen yang Dikonfigurasi';

  @override
  String get noAgentsConfiguredDesc =>
      'Tambahkan Claude Code, Codex, OpenCode, AGY, atau agen kustom ACP untuk mengaktifkan AI Ops di server ini.';

  @override
  String get agentPresetLabel => 'Preset';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Kustom';

  @override
  String get agentNameLabel => 'Nama Agen';

  @override
  String get agentNameHint => 'mis. Production Codex';

  @override
  String get agentDescriptionLabel => 'Deskripsi';

  @override
  String get agentDescriptionHint => 'Deskripsi singkat tentang agen';

  @override
  String get agentCliCommandLabel => 'Perintah Uji CLI';

  @override
  String get agentCliCommandHint => 'mis. claude, codex';

  @override
  String get agentAcpCommandLabel => 'Perintah Peluncuran ACP';

  @override
  String get agentAcpCommandHint => 'mis. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Perintah Instal (Opsional)';

  @override
  String get agentInstallCommandHint => 'mis. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Perintah Pemeriksaan Login (Opsional)';

  @override
  String get agentLoginCheckCommandHint => 'mis. codex --version';

  @override
  String get agentLoginCommandLabel => 'Perintah Login (Opsional)';

  @override
  String get agentLoginCommandHint => 'mis. codex login';

  @override
  String get agentSaveButton => 'Simpan & Deteksi';

  @override
  String get agentCliRequired => 'Perintah uji CLI diperlukan';

  @override
  String get agentAcpRequired => 'Perintah peluncuran ACP diperlukan';

  @override
  String get agentNameRequired => 'Nama agen diperlukan';

  @override
  String get confirmInstallAgentTitle => 'Konfirmasi Instalasi Agen';

  @override
  String get confirmLoginAgentTitle => 'Konfirmasi Login Agen';

  @override
  String get agentCommandRiskWarning =>
      'Perintah ini akan dieksekusi langsung di server jarak jauh dengan hak istimewa pengguna saat ini. Tindakan ini dapat menginstal paket atau mengubah lingkungan sistem.';

  @override
  String get targetServerLabel => 'Server Target';

  @override
  String get commandPreviewLabel => 'Pratinjau Perintah';

  @override
  String get executeButton => 'Eksekusi';

  @override
  String get deleteAgentTitle => 'Hapus Agen';

  @override
  String get deleteAgentConfirm => 'Hapus';

  @override
  String get agentStatusCheckingDesc =>
      'Mendeteksi lingkungan di server jarak jauh...';

  @override
  String get agentStatusInstalling => 'Menginstal dependensi di server...';

  @override
  String get agentStatusLoggingIn => 'Mengeksekusi perintah login di server...';

  @override
  String get agentNoLoginCheckProvided =>
      'Tidak ada perintah pemeriksaan login yang ditentukan';

  @override
  String get agentInstallPrompt =>
      'Instalasi tidak terdeteksi. Instal otomatis sekarang?';

  @override
  String get agentActionAutoInstall => 'Instal Otomatis';

  @override
  String get agentLoginPrompt => 'Belum masuk. Masuk sekarang?';

  @override
  String get agentActionExecuteLogin => 'Masuk Sekarang';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Agen di server ini belum terinstal atau belum siap. Silakan kelola dan selesaikan pengaturan lingkungan.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Instal dan siapkan agen untuk mulai mengobrol...';

  @override
  String get agentAcpInstallPrompt =>
      'Komponen ACP tidak terdeteksi. Instal otomatis sekarang?';

  @override
  String get agentInstallCommandAcpLabel => 'Perintah Instal ACP (Opsional)';

  @override
  String get agentInstallCommandAcpHint =>
      'mis. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Tidak ada perintah instalasi yang dikonfigurasi untuk agen ini';

  @override
  String get agentInstallLogTitle => 'Output instalasi';

  @override
  String get agentInstallLogEmpty => 'Menunggu output instalasi…';

  @override
  String get agentInstallLogTruncated =>
      'Output terlalu panjang; menampilkan baris terbaru';

  @override
  String get agentAcpOptional => 'Opsional; biarkan kosong untuk hanya CLI';

  @override
  String get acpStreaming => 'Streaming ACP...';

  @override
  String get aiOpsAgentTitle => 'Agen Valhalla AI Ops';

  @override
  String get aiOpsEmptySubtitle => 'Terhubung melalui ACP stdio di Saluran SSH';

  @override
  String get agentAuthRequiredTitle => 'Autentikasi Diperlukan';

  @override
  String get agentAuthRequiredDesc =>
      'Agen memerlukan autentikasi sebelum dapat memproses permintaan Anda.';

  @override
  String get agentAuthMethodLabel => 'Metode Autentikasi';

  @override
  String get agentAuthNoMethodsNotice =>
      'Agen tidak menyediakan metode login. Harap periksa konfigurasinya di server.';

  @override
  String get agentAuthProceedButton => 'Masuk';

  @override
  String get agentAuthCancelButton => 'Batal';

  @override
  String get agentAuthRetryHint => 'Setelah masuk, kirim pesan Anda lagi.';

  @override
  String get agentAuthRequiredError =>
      'Autentikasi diperlukan. Silakan masuk untuk melanjutkan.';

  @override
  String get agentLoginTerminalTitle => 'Terminal Login Interaktif';

  @override
  String get agentLoginTerminalSubtitle =>
      'Selesaikan langkah-langkah login di terminal berikut. Ikuti URL atau kode yang ditampilkan.';

  @override
  String get agentLoginTerminalRunning =>
      'Perintah login sedang berjalan di terminal...';

  @override
  String get agentLoginTerminalDisconnected =>
      'Koneksi SSH terputus. Sesi login terganggu.';

  @override
  String get agentLoginTerminalRetry => 'Hubungkan Ulang Terminal';

  @override
  String get agentLoginTerminalFinish => 'Selesai & Verifikasi';

  @override
  String get agentLoginTerminalClose => 'Tutup';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Jika agen memerlukan penempelan kode, tekan lama terminal untuk menempel atau gunakan tombol PASTE.';

  @override
  String get agentLoginTerminalUrlLabel => 'URL login terdeteksi';

  @override
  String get agentLoginTerminalUrlCopy => 'Salin tautan';

  @override
  String get agentLoginTerminalUrlCopied => 'URL login disalin ke papan klip';

  @override
  String get agentLoginTerminalCopyAll => 'Salin semua output';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Output terminal disalin ke papan klip';

  @override
  String get sshStatusReconnected => 'Koneksi dipulihkan';

  @override
  String get sshStatusDisconnectedRetrying => 'Koneksi terputus, mencoba lagi';

  @override
  String get sshStatusDisconnectedManual => 'Terputus';

  @override
  String get sshStatusHostKeyChanged => 'Kunci host berubah — koneksi ditolak';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla menjaga sesi Anda tetap hidup';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux tidak ditemukan — sesi tidak akan bertahan jika terputus';

  @override
  String get terminalTmuxSessionRestored => 'Sesi terminal dipulihkan';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Aktifkan Mosh — terminal roaming yang tahan terhadap pemutusan koneksi dan perubahan IP';

  @override
  String get moshServerPathLabel => 'Jalur mosh-server';

  @override
  String get moshPortRangeLabel => 'Rentang port UDP';

  @override
  String get moshNewSession => 'Sesi Mosh Baru';

  @override
  String get moshNotInstalled =>
      'mosh-server tidak ditemukan di server jarak jauh. Instal dengan: sudo apt install mosh (Debian/Ubuntu) atau sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Gagal memulai sesi Mosh: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Koneksi Mosh batas waktu habis — periksa apakah lalu lintas UDP tidak diblokir oleh firewall.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Sesi agen dipulihkan';

  @override
  String get acpSessionRestartNotice =>
      'Sesi agen dimulai ulang — konteks sebelumnya tidak tersedia';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Instal tmux di Server Jarak Jauh?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux diperlukan untuk mempertahankan sesi terminal saat koneksi terputus. Apakah Anda ingin menginstalnya sekarang?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Perintah untuk dieksekusi:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Tidak ada pengelola paket yang didukung terdeteksi di server jarak jauh. Silakan instal tmux secara manual.';

  @override
  String get terminalTmuxInstallFailed =>
      'Instalasi tmux gagal. Harap verifikasi izin server dan jaringan.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'Koneksi SSH terputus. Silakan hubungkan ulang untuk menginstal tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Menginstal tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Instal tmux';

  @override
  String get terminalTmuxInstallSkip => 'Lewati (Gunakan Shell Biasa)';

  @override
  String get sftpDownload => 'Unduh';

  @override
  String get sftpOpen => 'Buka';

  @override
  String get sftpUploadFailed => 'Unggahan gagal. Periksa izin dan coba lagi.';

  @override
  String get sftpDownloadFailed => 'Unduhan gagal';

  @override
  String get sftpOpenUnsupported => 'Format berkas ini tidak dapat dibuka.';

  @override
  String get sftpReadFailed =>
      'Gagal membaca berkas. Periksa izin dan coba lagi.';

  @override
  String get sftpTransferFailed => 'Operasi berkas gagal. Silakan coba lagi.';

  @override
  String get sftpDownloadSuccess => 'Berhasil diunduh';

  @override
  String get sftpUploading => 'Mengunggah...';

  @override
  String get sftpDownloading => 'Mengunduh...';

  @override
  String get sftpUpDirectory => 'Naik ke direktori induk';

  @override
  String get sftpShowHiddenFiles => 'Tampilkan berkas tersembunyi';

  @override
  String get sftpHideHiddenFiles => 'Sembunyikan berkas tersembunyi';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Gagal menyimpan preferensi berkas tersembunyi';

  @override
  String get sftpSymlink => 'Tautan simbolik';

  @override
  String get sftpLinkTargetUnavailable =>
      'Target tautan simbolik rusak atau tidak tersedia';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Izin ditolak untuk mengakses target tautan simbolik';

  @override
  String get settingsAutoConnect => 'Koneksi otomatis saat diluncurkan';

  @override
  String get settingsAutoConnectFixed => 'SSH default tetap';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Selalu hubungkan ke server yang Anda pilih di bawah';

  @override
  String get settingsAutoConnectLast => 'Ingat koneksi terakhir';

  @override
  String get settingsAutoConnectLastDesc =>
      'Hubungkan ke server yang terakhir berhasil terhubung';

  @override
  String get settingsAutoConnectPickServer => 'Server';

  @override
  String get settingsAutoConnectNoServer => 'Belum ada server yang dipilih';

  @override
  String get sftpSort => 'Urutkan';

  @override
  String get sftpSortName => 'Nama';

  @override
  String get sftpSortSize => 'Ukuran';

  @override
  String get sftpSortDate => 'Tanggal diubah';

  @override
  String get sftpSortAscending => 'Menaik';

  @override
  String get sftpSortDescending => 'Menurun';

  @override
  String get themeQuickSwitch => 'Tema';

  @override
  String get transferList => 'Transfer';

  @override
  String get transferEmpty => 'Belum ada transfer';

  @override
  String get transferUpload => 'Unggah';

  @override
  String get transferDownload => 'Unduh';

  @override
  String get transferStatusQueued => 'Dalam antrean';

  @override
  String get transferStatusRunning => 'Mentransfer';

  @override
  String get transferStatusPaused => 'Dijeda';

  @override
  String get transferStatusCompleted => 'Selesai';

  @override
  String get transferStatusFailed => 'Gagal';

  @override
  String get transferStatusCanceled => 'Dibatalkan';

  @override
  String get transferPause => 'Jeda';

  @override
  String get transferResume => 'Lanjutkan';

  @override
  String get transferCancel => 'Batal';

  @override
  String get transferRemove => 'Hapus';

  @override
  String get transferClearFinished => 'Bersihkan yang selesai';

  @override
  String get transferSizeUnknown => 'Ukuran tidak diketahui';

  @override
  String get transferFailedUpload => 'Unggahan gagal';

  @override
  String get transferFailedDownload => 'Unduhan gagal';

  @override
  String get stopGeneration => 'Hentikan';

  @override
  String get chatServerBindingRequired =>
      'Sesi ini tidak terikat ke server. Harap ikat ke server saat ini untuk melanjutkan.';

  @override
  String get chatSessionUnboundNotice =>
      'Sesi ini tidak terikat ke server mana pun.';

  @override
  String get bindServerAction => 'Ikat Server';

  @override
  String get bindServerDialogTitle => 'Ikat Sesi ke Server';

  @override
  String get bindServerConfirmAction => 'Konfirmasi Pengikatan';

  @override
  String get chatSessionIdentityMismatch =>
      'Server atau agen saat ini tidak cocok dengan identitas terikat sesi ini. Beralih ke server dan agen yang cocok untuk melanjutkan.';

  @override
  String get deleteSessionTitle => 'Hapus Sesi';

  @override
  String get deleteSessionConfirmAction => 'Hapus';

  @override
  String get shareAgentSessionsTitle => 'Bagikan Sesi Agen';

  @override
  String get shareAgentSessionsSubtitle =>
      'Bagikan sesi antar agen yang berbeda di server ini';

  @override
  String get shareAgentSessionsEnabled => 'Berbagi sesi agen diaktifkan';

  @override
  String get shareAgentSessionsDisabled => 'Berbagi sesi agen dinonaktifkan';

  @override
  String get agentCliStatusInstalled => 'CLI: Terinstal';

  @override
  String get agentCliStatusMissing => 'CLI: Hilang';

  @override
  String get agentCliStatusChecking => 'CLI: Memeriksa...';

  @override
  String get agentCliStatusUnknown => 'CLI: Tidak Diketahui';

  @override
  String get agentCliStatusError => 'CLI: Kesalahan';

  @override
  String get agentAcpStatusReady => 'ACP: Siap';

  @override
  String get agentAcpStatusMissing => 'ACP: Hilang';

  @override
  String get agentAcpStatusChecking => 'ACP: Memeriksa...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Menunggu CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Tidak Diketahui';

  @override
  String get agentAcpStatusError => 'ACP: Kesalahan';

  @override
  String get agentAcpStatusNa => 'ACP: N/A';

  @override
  String get agentAuthStatusAuthenticated => 'Autentikasi: Masuk';

  @override
  String get agentAuthStatusUnauthenticated => 'Autentikasi: Belum Masuk';

  @override
  String get agentAuthStatusUnknown => 'Autentikasi: Tidak Diketahui';

  @override
  String get downloadNotificationsUnavailable =>
      'Pemberitahuan unduhan sistem tidak tersedia. Unduhan berlanjut di latar belakang.';

  @override
  String get downloadOpenFailed => 'Gagal membuka berkas yang diunduh.';

  @override
  String get dockerActionPending =>
      'Tindakan sudah berlangsung untuk kontainer ini';

  @override
  String get dockerNoLogs => '(Tidak ada log)';

  @override
  String get serverReboot => 'Mulai Ulang Server';

  @override
  String get serverRebootDialogTitle => 'Konfirmasi Mulai Ulang Server';

  @override
  String get serverRebootDialogMessage =>
      'Anda yakin ingin memulai ulang server ini? Semua koneksi aktif dan layanan latar belakang akan dihentikan.';

  @override
  String get serverRebootConfirmButton => 'Mulai Ulang Sekarang';

  @override
  String get serverRebootPasswordTitle => 'Kata Sandi Sudo Diperlukan';

  @override
  String get serverRebootPasswordMessage =>
      'Hak istimewa root diperlukan untuk memulai ulang server. Silakan masukkan kata sandi sudo (digunakan sekali, tidak disimpan):';

  @override
  String get serverRebootPasswordHint => 'Kata Sandi Sudo';

  @override
  String get serverRebootSubmitting => 'Mengirim perintah mulai ulang...';

  @override
  String get serverRebootAccepted =>
      'Perintah mulai ulang diterima; penyelesaian belum diverifikasi. Silakan hubungkan ulang saat server kembali online.';

  @override
  String get serverRebootVerified =>
      'Mulai ulang server telah diverifikasi; sistem kembali online.';

  @override
  String get serverRebootUnknown =>
      'Hasil mulai ulang tidak pasti. Perintah telah dikirim, tetapi penyelesaian tidak dapat dikonfirmasi. Harap periksa koneksi secara manual.';

  @override
  String get serverRebootReconnect => 'Hubungkan Ulang';

  @override
  String get serverRebootServerChanged =>
      'Server target berubah, mulai ulang dibatalkan';

  @override
  String get navCliChat => 'Obrolan CLI';

  @override
  String get cliChatTitle => 'Sesi CLI';

  @override
  String get cliChatSubtitle => 'Sesi Agen CLI asli di server jarak jauh';

  @override
  String get cliSelectAgent => 'Pilih Agen';

  @override
  String get cliNoAgentsConfigured =>
      'Tidak ada agen yang ditambahkan untuk server ini';

  @override
  String get cliAgentNeedsSetup => 'Lingkungan agen hilang atau belum masuk';

  @override
  String get cliManageAgentsGuide => 'Konfigurasikan di Manajemen Agen';

  @override
  String get cliNewDraft => 'Draf Baru';

  @override
  String get cliNewDraftTooltip =>
      'Buat draf kosong (sesi dibuat pada pesan pertama)';

  @override
  String get cliDeleteSessionTitle => 'Hapus Riwayat Sesi CLI Jarak Jauh';

  @override
  String get cliDeleteSessionMessage =>
      'Tindakan ini akan menghapus riwayat sesi CLI secara permanen di server jarak jauh. Anda yakin ingin melanjutkan?';

  @override
  String get cliDeleteConfirmButton => 'Hapus Sesi';

  @override
  String get cliCannotDeleteTooltip =>
      'Penghapusan sesi jarak jauh tidak didukung atau dinonaktifkan';

  @override
  String get cliSessionsHeader => 'Sesi';

  @override
  String get cliNoSessions => 'Tidak ada sesi CLI ditemukan';

  @override
  String get cliFilterCwdHint => 'Filter berdasarkan jalur CWD...';

  @override
  String get cliFilterCwdAction => 'Filter';

  @override
  String get cliClearCwdAction => 'Bersihkan';

  @override
  String get cliLoadMoreSessions => 'Muat Lebih Banyak Sesi';

  @override
  String get cliRefreshSessions => 'Segarkan';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Riwayat Claude bersifat hanya-baca. Lanjutkan percakapan di terminal nyata.';

  @override
  String get cliContinueInTerminal => 'Lanjutkan di Terminal';

  @override
  String get cliOpenTerminal => 'Buka Terminal';

  @override
  String get cliCloseTerminal => 'Tutup Terminal';

  @override
  String get cliTerminalRunning => 'Terminal CLI Interaktif';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Agen ini tidak mendukung sinkronisasi riwayat terstruktur. Silakan gunakan terminal CLI asli untuk interaksi dan pemilihan sesi.';

  @override
  String get cliInstallSdkTitle => 'Instal SDK Riwayat Claude Resmi';

  @override
  String get cliInstallSdkMessage =>
      'Claude Code History SDK resmi tidak ditemukan di server jarak jauh. Apakah Anda ingin menginstalnya sekarang?';

  @override
  String get cliInstallSdkAction => 'Instal SDK Resmi';

  @override
  String get cliApprovalsTitle => 'Persetujuan Tertunda';

  @override
  String get cliApprovalDetails => 'Detail';

  @override
  String get cliApprovalAllow => 'Izinkan';

  @override
  String get cliApprovalDecline => 'Tolak';

  @override
  String get cliInputHint => 'Ketik pesan ke agen CLI...';

  @override
  String get cliSend => 'Kirim';

  @override
  String get cliStop => 'Hentikan';

  @override
  String get cliBusy => 'Operasi sedang berlangsung, harap tunggu...';

  @override
  String get cliDisconnected => 'SSH tidak terhubung';

  @override
  String get cliServerChanged => 'Server target berubah';

  @override
  String get cliTurnFailed => 'Eksekusi giliran CLI gagal';

  @override
  String get cliUseTerminal =>
      'Perintah interaktif diperlukan, silakan buka terminal untuk melanjutkan';

  @override
  String get cliDeleteFailed => 'Gagal menghapus sesi jarak jauh';

  @override
  String get cliDeleteUnsupported =>
      'Menghapus sesi jarak jauh tidak didukung oleh CLI ini';

  @override
  String get cliOperationFailed => 'Operasi CLI gagal';

  @override
  String get cliHistorySdkMissing => 'History SDK resmi tidak ada di server';

  @override
  String get cliHistoryRuntimeMissing =>
      'Riwayat Claude memerlukan Node.js/npm di server. Silakan instal Node.js secara manual; Anda tetap dapat menggunakan CLI nyata di terminal.';

  @override
  String get cliLoginRequired =>
      'Login agen diperlukan. Silakan masuk melalui Manajemen Agen.';

  @override
  String get cliNotInstalled =>
      'Agen CLI belum diinstal. Silakan instal melalui Manajemen Agen.';

  @override
  String get cliVersionUnsupported =>
      'Versi agen CLI tidak didukung. Harap perbarui atau instal ulang melalui Manajemen Agen.';

  @override
  String get settingsNavigation => 'Navigasi';

  @override
  String get settingsNavigationDesc =>
      'Konfigurasikan halaman startup default dan bilah navigasi bawah';

  @override
  String get settingsStartupPage => 'Halaman Startup';

  @override
  String get settingsStartupPageDesc =>
      'Halaman yang ditampilkan saat aplikasi dibuka';

  @override
  String get settingsBottomNav => 'Bilah Navigasi Bawah';

  @override
  String get settingsBottomNavDesc =>
      'Pilih bagian yang ditampilkan di bilah bawah ponsel (mendukung 0 hingga 9 item)';

  @override
  String get settingsResetSuccess => 'Semua pengaturan dikembalikan ke default';

  @override
  String get metricsTrendSubtitle => '~3 menit terakhir (hingga 60 sampel)';

  @override
  String get metricsCurrent => 'Saat Ini';

  @override
  String get metricsPeak => 'Puncak';

  @override
  String get metricsValley => 'Lembah';

  @override
  String get metricsTrendWaiting => 'Mengumpulkan data metrik...';

  @override
  String get metricsTrendStopped =>
      'Pengumpulan data dihentikan (SSH terputus)';

  @override
  String get dockerActionTerminal => 'Terminal Exec';

  @override
  String get dockerTerminalTitle => 'Terminal Kontainer';

  @override
  String get dockerTerminalNotRunning => 'Kontainer tidak berjalan';

  @override
  String get setDefaultAgent => 'Tetapkan sebagai default';

  @override
  String get defaultBadge => 'Default';

  @override
  String get isDefaultAgent => 'Agen Default';

  @override
  String get setAsDefaultAgent =>
      'Tetapkan sebagai agen default untuk server ini';

  @override
  String get agentGroupBasic => 'Informasi Dasar';

  @override
  String get agentGroupCommands => 'Perintah';

  @override
  String get agentGroupAuth => 'Instalasi & Autentikasi';

  @override
  String get agentPresetTitle => 'Templat Preset';

  @override
  String get resourceProcessList => 'Proses';

  @override
  String get resourceDiskScanning =>
      'Memindai direktori root, ini mungkin memerlukan beberapa detik...';

  @override
  String get resourceDiskScanPartial =>
      'Beberapa direktori tidak dapat dipindai karena izin atau batas waktu';

  @override
  String get resourceDiskDirectories => 'Penggunaan Direktori Tingkat Atas';

  @override
  String get resourceSortCpu => 'Urutkan berdasarkan CPU';

  @override
  String get resourceSortMemory => 'Urutkan berdasarkan Memori';

  @override
  String get resourceRss => 'Memori RSS';

  @override
  String get resourceUsed => 'Digunakan';

  @override
  String get resourceAvailable => 'Tersedia';

  @override
  String get resourceTotal => 'Total';

  @override
  String get settingsBottomNavOrderTitle =>
      'Item Terpilih (Tarik untuk menyusun ulang)';

  @override
  String get langSystem => 'Ikuti Sistem';

  @override
  String get serverFieldRequired => 'Diperlukan';

  @override
  String get serverPortInvalid => 'Port harus antara 1 dan 65535';

  @override
  String get serverTestReachability => 'Uji Keterjangkauan';

  @override
  String get serverSaveFailedGeneric =>
      'Gagal menyimpan server. Harap periksa konfigurasi Anda dan coba lagi.';

  @override
  String get serverViewPrivateKey => 'Lihat Kunci Privat';

  @override
  String get serverHidePrivateKey => 'Sembunyikan Kunci Privat';

  @override
  String get dockerBashFallbackNotice =>
      'Bash tidak tersedia di kontainer, beralih ke Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Direktori Kerja';

  @override
  String get cliDefaultWorkingDir => 'Bawaan (/)';

  @override
  String get cliPickWorkingDirTitle => 'Pilih Direktori Kerja';

  @override
  String get cliClearWorkingDir => 'Atur Ulang ke Bawaan';

  @override
  String get cliBrowseWorkingDir => 'Jelajahi';

  @override
  String get cliSelectCurrentDir => 'Pilih Direktori Ini';

  @override
  String get cliNavigateUp => 'Naik ke atas';

  @override
  String get chatSessionsTooltip => 'Sesi';

  @override
  String get hardwareSpecsTitle => 'Perangkat Keras & Sistem';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Memori';

  @override
  String get hardwareDisk => 'Disk Root';

  @override
  String get hardwareDistribution => 'OS';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Memuat spesifikasi perangkat keras...';

  @override
  String get hardwareUnavailable =>
      'Spesifikasi perangkat keras tidak tersedia';

  @override
  String get hardwareUnknown => 'Tidak Diketahui';

  @override
  String get systemInfoTitle => 'Info Sistem';

  @override
  String get systemInfoTapHint => 'Ketuk untuk melihat seni ASCII';

  @override
  String get systemInfoHost => 'Host';

  @override
  String get serverShutdown => 'Matikan';

  @override
  String get serverShutdownDialogTitle => 'Konfirmasi Matikan Server';

  @override
  String get serverShutdownDialogMessage =>
      'Anda yakin ingin mematikan server ini? Sistem akan dimatikan sepenuhnya dan tidak dapat diakses dari jarak jauh hingga dinyalakan secara manual.';

  @override
  String get serverShutdownConfirmButton => 'Matikan Sekarang';

  @override
  String get serverShutdownSubmitting => 'Mengirim perintah matikan...';

  @override
  String get serverShutdownAccepted =>
      'Perintah matikan diterima; penyelesaian matikan belum diverifikasi.';

  @override
  String get serverShutdownUnknown =>
      'Hasil matikan tidak diketahui: Perintah mungkin telah dikirim tetapi tidak dapat dikonfirmasi. Harap periksa secara manual; tidak akan dicoba lagi secara otomatis.';

  @override
  String get serverShutdownPasswordTitle =>
      'Kata Sandi Sudo Diperlukan untuk Mematikan';

  @override
  String get serverShutdownPasswordMessage =>
      'Hak istimewa root diperlukan untuk mematikan server. Silakan masukkan kata sandi sudo (digunakan sekali, tidak disimpan):';

  @override
  String get serverShutdownPasswordHint => 'Kata Sandi Sudo';

  @override
  String get serverShutdownServerChanged =>
      'Server target berubah, proses matikan dibatalkan';

  @override
  String get metricsNetwork => 'Kecepatan Jaringan';

  @override
  String get networkModalTitle => 'Detail Antarmuka Jaringan';

  @override
  String get networkDownloadRate => 'Unduh (RX)';

  @override
  String get networkUploadRate => 'Unggah (TX)';

  @override
  String get networkTotalRx => 'Total RX';

  @override
  String get networkTotalTx => 'Total TX';

  @override
  String get networkPrimary => 'Rute Default';

  @override
  String get networkRatesEmpty =>
      'Tidak ada antarmuka jaringan aktif yang terdeteksi';

  @override
  String get networkWaitingSecondSample => 'Menunggu sampel kedua';

  @override
  String get networkUnavailable => 'Tidak Tersedia';

  @override
  String get networkNoDefaultInterface => 'Tidak ada rute default';

  @override
  String get selectThemeModeTitle => 'Pilih Mode Tema';

  @override
  String get selectLanguageTitle => 'Pilih Bahasa';

  @override
  String get selectStartupPageTitle => 'Pilih Halaman Startup';

  @override
  String get selectAutoConnectModeTitle => 'Pilih Mode Sambung Otomatis';

  @override
  String get accentColorDialogTitle => 'Sesuaikan Warna Aksen';

  @override
  String get accentColorLightMode => 'Mode Terang';

  @override
  String get accentColorDarkMode => 'Mode Gelap';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Preset';

  @override
  String get accentColorHsvPicker => 'Roda Warna';

  @override
  String get accentColorHexCode => 'Kode Warna Hex';

  @override
  String get accentColorPreview => 'Pratinjau';

  @override
  String get accentColorSampleButton => 'Tombol Sampel Aksen';

  @override
  String get accentColorInvalidHex =>
      'Format heksadesimal tidak valid (mis. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Tindakan Cepat Dasbor';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Konfigurasikan pintasan cepat yang ditampilkan di dasbor. Menghapusnya akan menyembunyikan bagian tindakan cepat.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Tindakan cepat disembunyikan (tidak ada pintasan yang dipilih)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Tarik untuk Mengatur Ulang Pintasan';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Pilih Pintasan yang Terlihat';

  @override
  String get terminalCopySelection => 'Salin';

  @override
  String get terminalSelectionCopied => 'Pilihan disalin ke papan klip';

  @override
  String get editAgent => 'Edit Agen';

  @override
  String get agentExecutionTarget => 'Lingkungan Eksekusi';

  @override
  String get agentExecutionHost => 'Sistem Host';

  @override
  String get agentExecutionDocker => 'Kontainer Docker';

  @override
  String get agentContainerBinding => 'Mode Pengikatan Kontainer';

  @override
  String get agentContainerBindingId => 'Berdasarkan ID Kontainer';

  @override
  String get agentContainerBindingName => 'Berdasarkan Nama Kontainer';

  @override
  String get agentContainerReference => 'Kontainer Target';

  @override
  String get agentContainerReferenceHint =>
      'Pilih atau masukkan ID atau nama kontainer';

  @override
  String get agentContainerRequired =>
      'Kontainer target diperlukan untuk eksekusi Docker';

  @override
  String get agentLoadingContainers => 'Menanyakan kontainer di server...';

  @override
  String get agentNoContainersFound =>
      'Tidak ada kontainer ditemukan di server ini';

  @override
  String get agentContainerUser => 'Pengguna Eksekusi Kontainer (Opsional)';

  @override
  String get agentContainerUserHint => 'mis. dev';

  @override
  String get agentContainerUserHelper =>
      'Biarkan kosong untuk menggunakan pengguna default gambar; mis. dev; mendukung pengguna, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Pilih pengguna kontainer';

  @override
  String get agentContainerUsersLoading => 'Memuat pengguna...';

  @override
  String get agentContainerUsersEmpty => 'Tidak ada pengguna passwd ditemukan';

  @override
  String get agentViewDiagnosticLog => 'Lihat Log Diagnostik';

  @override
  String get agentDiagnosticLogCopied => 'Log diagnostik disalin ke papan klip';

  @override
  String get agentDiagnosticLogCopy => 'Salin';

  @override
  String get agentDiagnosticLogClose => 'Tutup';

  @override
  String get settingsCliHistoryPageSize => 'Ukuran Halaman Riwayat CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Jumlah pesan lama yang dimuat per halaman saat menggulir ke atas (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Pilih Ukuran Halaman Riwayat CLI';

  @override
  String get cliLoadingOlderMessages => 'Memuat pesan lama...';

  @override
  String get chatLoadOlderMessages => 'Muat pesan sebelumnya';

  @override
  String get chatCommandsTooltip => 'Perintah';

  @override
  String get chatAttachTooltip => 'Lampirkan berkas';

  @override
  String get chatAttachImage => 'Lampirkan gambar lokal';

  @override
  String get chatAttachLocalText => 'Lampirkan berkas teks lokal';

  @override
  String get chatAttachRemoteText => 'Lampirkan berkas teks jarak jauh';

  @override
  String get chatAttachRemotePathTitle => 'Lampirkan Berkas Teks Jarak Jauh';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => 'Berkas melebihi batas ukuran';

  @override
  String get chatUsageAndDiagnostics => 'Penggunaan & Diagnostik';

  @override
  String get chatWorkingDirTooltip => 'Direktori Kerja Draf';

  @override
  String get chatAttachFailed => 'Gagal melampirkan berkas';

  @override
  String get chatInvalidRemotePath =>
      'Jalur berkas jarak jauh tidak valid (harus dimulai dengan /)';

  @override
  String get chatRemoteReadFailed => 'Gagal membaca berkas jarak jauh';

  @override
  String get chatInvalidDirPath =>
      'Jalur direktori tidak valid (harus dimulai dengan /)';

  @override
  String get chatNoSubdirectories => 'Tidak ada subdirektori';

  @override
  String get chatUsageTitle => 'Penggunaan Token & Biaya';

  @override
  String get chatUsageUsed => 'Token Digunakan';

  @override
  String get chatUsageSize => 'Ukuran Konteks';

  @override
  String get chatUsageCost => 'Biaya';

  @override
  String get chatDiagnosticsTitle => 'Log Diagnostik';

  @override
  String get chatNoDiagnostics => 'Tidak ada log diagnostik yang tersedia';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Ini hanya menghapus catatan lokal di Valhalla dan tidak akan menghapus riwayat sesi agen asli di server.';

  @override
  String get chatSearchSessionsHint => 'Cari sesi...';

  @override
  String get chatLoadMoreSessions => 'Muat lebih banyak sesi';

  @override
  String get chatLoadingMoreSessions => 'Memuat lebih banyak sesi...';

  @override
  String get chatExportSession => 'Ekspor Sesi (Markdown)';

  @override
  String get chatExportSuccess => 'Sesi berhasil diekspor';

  @override
  String get chatExportFailed => 'Gagal mengekspor sesi';

  @override
  String get chatRemoteSessions => 'Sesi Jarak Jauh';

  @override
  String get chatRemoteSessionsTitle => 'Sesi Agen Jarak Jauh';

  @override
  String get chatRemoteSessionsDesc =>
      'Lihat dan impor riwayat sesi asli dari agen jarak jauh';

  @override
  String get chatRemoteSessionsEmpty => 'Tidak ada sesi jarak jauh ditemukan';

  @override
  String get chatRemoteImporting => 'Mengimpor riwayat sesi jarak jauh...';

  @override
  String get chatRemoteImportFailed => 'Gagal mengimpor sesi jarak jauh';

  @override
  String get chatStatusInterrupted => 'Terganggu';

  @override
  String get chatStatusFailed => 'Gagal';

  @override
  String get chatStatusAwaitingAuth => 'Menunggu Autentikasi ACP';

  @override
  String get chatShowFullOutput => 'Tampilkan output lengkap';

  @override
  String get chatShowLessOutput => 'Tampilkan lebih sedikit';

  @override
  String get chatToolLocations => 'Jalur yang terpengaruh';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Masukkan nilai untuk $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Proses $pid dihentikan';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Tindakan $action pada $service berhasil';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Aturan terpicu: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Kode Keluar: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Berhasil terhubung ke $server melalui SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Koneksi SSH gagal: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Menghubungkan ke $host ($type) untuk pertama kalinya.\n\nSidik Jari SHA-256:\n$fingerprint\n\nPercayai sidik jari ini dan hubungkan?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Masukkan kata sandi untuk $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Anda yakin ingin menghapus server \'$name\'? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Anda yakin ingin menghapus Agen \'$name\'? Ini akan menghapus konfigurasi dan status runtime-nya di server ini tanpa memengaruhi riwayat sesi obrolan atau kredensial SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Terakhir diperiksa: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Pilih cara masuk ke $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Menghubungkan ulang… (percobaan $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n sesi aktif';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Ikat sesi ini ke server \"$serverName\"? Setelah terikat, sesi ini akan dikaitkan dengan server ini.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Anda yakin ingin menghapus sesi \"$title\"? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Kontainer $name $action berhasil';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Tindakan gagal: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Server Target: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Sesi Terminal: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Sesi Agen: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Transfer Aktif: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Mulai ulang gagal: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Gagal menghapus sesi jarak jauh: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Tren $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Peringatan: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Bahaya: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count titik data';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Penggunaan Sumber Daya $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'Port TCP $port dapat dijangkau';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Koneksi gagal: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Gagal menyimpan server: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Core';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Gagal mematikan: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Antarmuka: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Gagal memuat kontainer: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Gagal memuat pengguna kontainer: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Log Diagnostik - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'Deteksi Docker/kontainer gagal';

  @override
  String get chatCopiedAllMessages => 'Semua pesan disalin';

  @override
  String get chatCopyAllMessages => 'Salin semua pesan';

  @override
  String get cliModelAtCapacity =>
      'Model yang dipilih sedang dalam kapasitas penuh. Coba model lain.';

  @override
  String get chatLaunchBlankDraft => 'Draf kosong';

  @override
  String get chatLaunchFixedSession => 'Sesi tetap';

  @override
  String get chatLaunchRememberLast => 'Ingat sesi terakhir';

  @override
  String get chatPermissionAskEveryTime => 'Tanya setiap saat';

  @override
  String get chatPermissionAutoAllowAll => 'Izinkan semua secara otomatis';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Agen akan mengeksekusi semua operasi tanpa bertanya. Lanjutkan?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle => 'Izinkan semua operasi?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Izinkan operasi aman secara otomatis';

  @override
  String get chatRunSettingsDefault => 'Default';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI Interaktif';

  @override
  String get chatRunSettingsModel => 'Model';

  @override
  String get chatRunSettingsPermissions => 'Izin';

  @override
  String get chatRunSettingsReasoning => 'Tingkat penalaran';

  @override
  String get chatRunSettingsTitle => 'Pengaturan jalan';

  @override
  String get cliActionInsertCommand => 'Sisipkan perintah';

  @override
  String get cliActionInsertFile => 'Sisipkan berkas';

  @override
  String get cliActionInsertWorkdir => 'Sisipkan direktori kerja';

  @override
  String get cliComposerInsertAction => 'Sisipkan';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Operasi CLI gagal: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Pilih perintah';

  @override
  String get defaultAgentTitle => 'Agen default';

  @override
  String get insertSkills => 'Sisipkan keahlian';

  @override
  String get isDefaultSession => 'Sesi default';

  @override
  String get sessionLaunchMode => 'Mode peluncuran sesi';

  @override
  String get setAsDefaultSession => 'Tetapkan sebagai sesi default';

  @override
  String get navNas => 'Media NAS';

  @override
  String get nasAddExcludePath => 'Tambah jalur yang dikecualikan';

  @override
  String get nasAddIncludePath => 'Tambah jalur pemindaian';

  @override
  String get nasCancelScan => 'Batalkan pemindaian';

  @override
  String get nasClearSearch => 'Bersihkan pencarian';

  @override
  String get nasConfigDialogTitle => 'Pengaturan pustaka media';

  @override
  String get nasConfigure => 'Konfigurasi';

  @override
  String get nasConfigureScanDirs => 'Konfigurasi folder pemindaian';

  @override
  String get nasCreatePlaylist => 'Buat daftar putar';

  @override
  String get nasEmptyConfigDesc =>
      'Tambahkan setidaknya satu folder untuk mulai membangun pustaka media Anda.';

  @override
  String get nasEmptyConfigTitle =>
      'Tidak ada folder pemindaian yang dikonfigurasi';

  @override
  String get nasExcludePaths => 'Folder yang dikecualikan';

  @override
  String get nasExcludedBadge => 'Dikecualikan';

  @override
  String get nasFilterImages => 'Gambar';

  @override
  String get nasFilterVideos => 'Video';

  @override
  String get nasIncludePaths => 'Folder pemindaian';

  @override
  String nasItemCount(Object value) {
    return '$value item';
  }

  @override
  String nasLastScan(Object value) {
    return 'Pemindaian terakhir: $value';
  }

  @override
  String get nasLibrarySettings => 'Pengaturan pustaka';

  @override
  String nasMediaOpening(Object value) {
    return 'Membuka $value…';
  }

  @override
  String get nasMiniPlayer => 'Pemutar mini';

  @override
  String get nasNoExcludePaths => 'Tidak ada folder yang dikecualikan';

  @override
  String get nasNoFavorites => 'Belum ada favorit';

  @override
  String get nasNoIncludePaths => 'Tidak ada folder pemindaian';

  @override
  String get nasNoIndexDesc =>
      'Konfigurasikan folder dan jalankan pemindaian untuk mengindeks media Anda.';

  @override
  String get nasNoIndexTitle => 'Pustaka media kosong';

  @override
  String get nasNoPlaylists => 'Belum ada daftar putar';

  @override
  String get nasNoSearchResults => 'Tidak ada media yang cocok';

  @override
  String get nasNotScanned => 'Belum dipindai';

  @override
  String get nasNowPlaying => 'Sedang memutar';

  @override
  String get nasOpenMethodPrompt => 'Bagaimana Anda ingin membuka berkas ini?';

  @override
  String get nasOpenPolicyAsk => 'Tanya setiap saat';

  @override
  String get nasOpenPolicyExternal => 'Buka dengan aplikasi lain';

  @override
  String get nasOpenPolicyInApp => 'Buka di aplikasi';

  @override
  String get nasOpeningPolicy => 'Metode buka default';

  @override
  String get nasPlaylistName => 'Nama daftar putar';

  @override
  String get nasQuickStats => 'Ringkasan pustaka';

  @override
  String get nasScan => 'Pindai sekarang';

  @override
  String get nasScanCancelled => 'Pemindaian dibatalkan';

  @override
  String nasScanFailed(Object value) {
    return 'Pemindaian gagal: $value';
  }

  @override
  String get nasScanning => 'Memindai…';

  @override
  String get nasScopeBadge => 'Cakupan pemindaian';

  @override
  String get nasSearchHint => 'Cari media';

  @override
  String get nasStatMusic => 'Musik';

  @override
  String get nasStatPhotos => 'Foto';

  @override
  String get nasStatTotal => 'Total';

  @override
  String get nasStatVideos => 'Video';

  @override
  String get nasTabFavorites => 'Favorit';

  @override
  String get nasTabFolders => 'Folder';

  @override
  String get nasTabHome => 'Beranda';

  @override
  String get nasTabMusic => 'Musik';

  @override
  String get nasTabPhotos => 'Foto';

  @override
  String get nasTabPlaylists => 'Daftar Putar';

  @override
  String get nasTabVideos => 'Video';

  @override
  String get nasSources => 'Sumber media';

  @override
  String get nasAddSource => 'Tambah sumber media';

  @override
  String get nasEditSource => 'Edit sumber media';

  @override
  String get nasRemoveSource => 'Hapus sumber media';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Anda yakin ingin menghapus sumber media \'$name\'? Ini akan menghapus konfigurasinya tanpa menghapus berkas jarak jauh.';
  }

  @override
  String get nasNoSources => 'Tidak ada sumber media yang dikonfigurasi';

  @override
  String get nasNoSourcesDesc =>
      'Tambahkan SFTP, SMB, WebDAV, Jellyfin, atau Emby untuk mulai menjelajahi media.';

  @override
  String get nasSourceType => 'Jenis sumber';

  @override
  String get nasSourceName => 'Nama sumber';

  @override
  String get nasProbe => 'Uji koneksi';

  @override
  String get nasProbeSuccess => 'Koneksi berhasil';

  @override
  String get nasProbeFailed => 'Uji koneksi gagal';

  @override
  String get nasEndpoint => 'Endpoint / URL';

  @override
  String get nasRootPath => 'Jalur root';

  @override
  String get nasUsername => 'Nama pengguna';

  @override
  String get nasPassword => 'Kata sandi';

  @override
  String get nasDomain => 'Domain (opsional)';

  @override
  String get nasAuthenticate => 'Autentikasi';

  @override
  String get nasAuthSuccess => 'Autentikasi berhasil';

  @override
  String get nasAuthFailed => 'Autentikasi gagal';

  @override
  String get nasTabDownloads => 'Unduhan';

  @override
  String get nasNoDownloads => 'Tidak ada tugas unduhan';

  @override
  String get nasDownloadQueued => 'Dalam antrean';

  @override
  String get nasDownloadDownloading => 'Mengunduh';

  @override
  String get nasDownloadCompleted => 'Selesai';

  @override
  String get nasDownloadCancelled => 'Dibatalkan';

  @override
  String get nasDownloadFailed => 'Unduhan gagal';

  @override
  String get nasRetryDownload => 'Coba lagi';

  @override
  String get nasCancelDownload => 'Batal';

  @override
  String get nasOpenDownloadedFile => 'Buka berkas';

  @override
  String get nasQueue => 'Antrean putar';

  @override
  String get nasNoQueue => 'Antrean kosong';

  @override
  String get nasSpeed => 'Kecepatan';

  @override
  String get nasQuality => 'Kualitas';

  @override
  String get nasAudioTrack => 'Trek audio';

  @override
  String get nasSubtitleTrack => 'Subtitel';

  @override
  String get nasRepeatOff => 'Ulangi mati';

  @override
  String get nasRepeatAll => 'Ulangi semua';

  @override
  String get nasRepeatOne => 'Ulangi satu';

  @override
  String get nasShuffle => 'Acak';

  @override
  String get nasCast => 'Cast';

  @override
  String get nasCastUnavailable => 'Tidak ada perangkat cast yang tersedia';

  @override
  String get nasSlideshow => 'Tayangan slide';

  @override
  String get nasByFolder => 'Folder';

  @override
  String get nasByArtist => 'Artis';

  @override
  String get nasByAlbum => 'Album';

  @override
  String get nasAllTracks => 'Semua trek';

  @override
  String get nasPlayAll => 'Putar semua';

  @override
  String get nasPreviousPage => 'Sebelumnya';

  @override
  String get nasNextPage => 'Berikutnya';

  @override
  String get nasClearScope => 'Kembali ke semua';

  @override
  String get nasRenamePlaylist => 'Ubah nama daftar putar';

  @override
  String get nasRemoveFromPlaylist => 'Hapus dari daftar putar';

  @override
  String get nasMoveUp => 'Pindah ke atas';

  @override
  String get nasMoveDown => 'Pindah ke bawah';

  @override
  String get nasSshServer => 'Server SSH';

  @override
  String get nasSelectSshServer => 'Pilih server SSH tersimpan';

  @override
  String get nasQualityOriginal => 'Asli';

  @override
  String get nasQualityAuto => 'Otomatis';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Perangkat DLNA yang Tersedia';

  @override
  String get nasCastDiscovering => 'Mencari perangkat DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'Meneruskan streaming melalui aplikasi latar depan. Biarkan Valhalla tetap terbuka.';

  @override
  String get nasCastStop => 'Hentikan Casting';

  @override
  String get nasCastVolume => 'Volume';

  @override
  String get nasCastRetry => 'Coba Lagi Pencarian';

  @override
  String get nasInstallTitle => 'Terapkan Server Media NAS';

  @override
  String get nasInstallProduct => 'Produk';

  @override
  String get nasInstallMediaPath => 'Direktori Media (Hanya-Baca)';

  @override
  String get nasInstallDataRoot => 'Direktori Data & Konfigurasi';

  @override
  String get nasInstallPort => 'Port';

  @override
  String get nasInstallBindAddress => 'Alamat Ikat';

  @override
  String get nasInstallWebdavUser => 'Nama Pengguna WebDAV';

  @override
  String get nasInstallWebdavPassword => 'Kata Sandi WebDAV (min 12 karakter)';

  @override
  String get nasInstallPreparePlan => 'Tinjau Rencana Penerapan';

  @override
  String get nasInstallPlanTitle => 'Tinjauan Teknis & Konfirmasi';

  @override
  String get nasInstallBlockersTitle => 'Penghambat Penerapan';

  @override
  String get nasInstallConfirmDeploy => 'Konfirmasi & Instal';

  @override
  String get nasInstallDeploying => 'Menerapkan kontainer...';

  @override
  String get nasInstallSuccess => 'Berhasil Diterapkan';

  @override
  String get nasInstallSuccessDesc =>
      'Layanan sekarang berjalan. Selesaikan penyiapan awal server sebelum menambahkannya sebagai sumber media.';

  @override
  String get nasInstallContainerId => 'ID Kontainer';

  @override
  String get nasInstallEndpoint => 'Endpoint';

  @override
  String get nasUseSshTunnel => 'Gunakan Terowongan SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'Rute lalu lintas melalui server SSH tersimpan (mis. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Endpoint harus dapat diakses dari server SSH, mis. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Biarkan kosong untuk mempertahankan kata sandi / token yang ada';

  @override
  String get nasSourceNameRequired => 'Nama sumber diperlukan';

  @override
  String get nasInvalidEndpoint => 'URL atau skema endpoint tidak valid';

  @override
  String get nasSourceUnreachable => 'Tidak dapat menjangkau sumber media';

  @override
  String get nasSshTunnelFailed => 'Koneksi terowongan SSH gagal';

  @override
  String get nasOperationFailed => 'Operasi gagal';

  @override
  String get nasInstallStepCreateDir => 'Buat direktori privat';

  @override
  String get nasInstallStepWriteCompose =>
      'Tulis konfigurasi docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Tulis kredensial privat';

  @override
  String get nasInstallStepPullImage =>
      'Tarik gambar kontainer yang dipasangi pin';

  @override
  String get nasInstallStepStartService => 'Mulai layanan dalam kontainer';

  @override
  String get nasInstallStepCheckHttp => 'Periksa kesehatan HTTP layanan';

  @override
  String get nasInstallBlockerDocker =>
      'Docker Engine diperlukan di server target';

  @override
  String get nasInstallBlockerCompose => 'Plugin Docker Compose diperlukan';

  @override
  String get nasInstallBlockerIdentity =>
      'Identitas server target tidak dapat diverifikasi';

  @override
  String get nasInstallBlockerTools =>
      'Alat yang diperlukan (curl, ss, realpath) tidak ada di server target';

  @override
  String get nasInstallBlockerMedia =>
      'Direktori media tidak ada atau tidak dapat dibaca';

  @override
  String get nasInstallBlockerParent =>
      'Direktori induk data root tidak dapat ditulis';

  @override
  String get nasInstallBlockerOverlap =>
      'Direktori media dan direktori data tidak boleh tumpang tindih';

  @override
  String get nasInstallBlockerCollision =>
      'Direktori data target sudah ada atau merupakan tautan simbolik';

  @override
  String get nasInstallBlockerPort =>
      'Port yang dipilih sudah digunakan di server target';

  @override
  String get nasInstallBlockerContainer =>
      'Kontainer dengan nama proyek ini sudah ada';

  @override
  String get nasInstallBlockerImage =>
      'Gagal memverifikasi gambar kontainer. Periksa nama gambar, konektivitas jaringan, dan arsitektur server, lalu coba lagi.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Pengikatan loopback (127.0.0.1) memerlukan terowongan SSH untuk akses jarak jauh';

  @override
  String get nasInstallGuidanceTls =>
      'Pengikatan publik disarankan diamankan di belakang proksi terbalik TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Selesaikan penyiapan akun admin awal di browser pada peluncuran pertama';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Direktori media dipasang sebagai hanya-baca untuk melindungi berkas Anda';

  @override
  String get nasInstallGuidancePreserved =>
      'Direktori data akan dipertahankan saat terjadi kegagalan untuk pemecahan masalah';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Diunduh (Gagal membuka secara eksternal)';

  @override
  String get nasRetryOpen => 'Coba Buka Lagi';

  @override
  String get nasExternalOpenFailed =>
      'Gagal membuka berkas di aplikasi eksternal';

  @override
  String get nasTitle => 'Media NAS';

  @override
  String get nasLoadMoreGroups => 'Muat lebih banyak grup';

  @override
  String get nasMetadataEnriching => 'Memperkaya tag musik...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Memperkaya tag musik ($count diproses)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Mengunduh $value…';
  }

  @override
  String get nasSubtitleNone => 'Tidak ada';

  @override
  String get nasLibraryId => 'ID Pustaka';

  @override
  String get nasLibraryIdHint => 'Default: semua (/), atau tentukan ID pustaka';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relatif terhadap root sumber ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Sumber berubah saat mengonfigurasi, penyimpanan dibatalkan';

  @override
  String get nasInvalidLibraryId => 'ID pustaka tidak valid';

  @override
  String get startupFailed => 'Aplikasi gagal dimulai';

  @override
  String get startupFailedDesc =>
      'Terjadi kesalahan tak terduga saat memulai. Anda dapat mencoba lagi atau mengekspor log diagnostik.';

  @override
  String get retryStartup => 'Coba Lagi Memulai';

  @override
  String get viewDiagnostics => 'Lihat Diagnostik';

  @override
  String get exportDiagnostics => 'Ekspor Diagnostik';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnostik diekspor ke $path';
  }

  @override
  String get diagnosticsExportFailed => 'Gagal mengekspor diagnostik';

  @override
  String get diagnosticsTitle => 'Diagnostik Aplikasi';

  @override
  String get settingsDiagnostics => 'Diagnostik & Log';

  @override
  String get settingsDiagnosticsDesc =>
      'Lihat dan ekspor log aplikasi lokal yang telah dibersihkan';

  @override
  String get diagnosticsEmpty => 'Tidak ada rekaman diagnostik ditemukan';

  @override
  String diagnosticsStorageError(String error) {
    return 'Kesalahan penyimpanan diagnostik: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Insiden yang dapat dipulihkan dilaporkan: $category';
  }

  @override
  String get diagnosticsRefresh => 'Segarkan Log';

  @override
  String get nasInstallTaskTitle => 'Tugas Penerapan';

  @override
  String get nasInstallStagePreflight => 'Pemeriksaan Awal';

  @override
  String get nasInstallStageReview => 'Tinjauan Rencana';

  @override
  String get nasInstallStageWriting => 'Menulis Konfigurasi';

  @override
  String get nasInstallStagePulling => 'Menarik Gambar';

  @override
  String get nasInstallStageStarting => 'Memulai Kontainer';

  @override
  String get nasInstallStageHealth => 'Pemeriksaan Kesehatan';

  @override
  String get nasInstallStageCleanup => 'Membersihkan';

  @override
  String get nasInstallStageSucceeded => 'Penerapan Berhasil';

  @override
  String get nasInstallStageFailed => 'Penerapan Gagal';

  @override
  String get nasInstallStageCancelled => 'Penerapan Dibatalkan';

  @override
  String get nasInstallStageNeedsInspection => 'Memerlukan Inspeksi';

  @override
  String get nasInstallStageReconciling => 'Rekonsiliasi Status';

  @override
  String get nasInstallCancel => 'Batalkan Penerapan';

  @override
  String get nasInstallReconcile => 'Rekonsiliasi Status';

  @override
  String get nasInstallServerNotFound => 'Server yang dipilih tidak ditemukan';

  @override
  String get nasInstallPortRangeError => 'Port harus antara 1 dan 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Berlalu: $time';
  }

  @override
  String get nasInstallLogTail => 'Log Terbaru';

  @override
  String get nasInstallCleanupCompleted => 'Pembersihan rollback selesai';

  @override
  String get nasInstallCleanupIncomplete =>
      'Pembersihan rollback tidak lengkap';

  @override
  String get nasInstallNewDeployment => 'Penerapan Baru';

  @override
  String get nasInstallBackEdit => 'Kembali / Edit Formulir';

  @override
  String get nasInstallClose => 'Tutup';

  @override
  String get nasInstallMediaPathHint =>
      'Mount ikat hanya-baca pada host (mis. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Direktori data & konfigurasi privat (belum boleh ada)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 untuk terowongan, 0.0.0.0 untuk LAN';

  @override
  String get nasInstallWebdavPasswordHint => 'Diperlukan minimal 12 karakter';

  @override
  String get nasInstallTargetServer => 'Server Target';

  @override
  String get nasInstallTargetImage => 'Gambar Target';

  @override
  String get nasInstallContainerName => 'Nama Kontainer';

  @override
  String get nasInstallBindAndPort => 'Ikat & Port';

  @override
  String get nasInstallComposePreview => 'Pratinjau docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Langkah yang Direncanakan';

  @override
  String get nasInstallGuidanceNotes => 'Catatan & Panduan Penerapan';

  @override
  String get nasInstallNoLogsYet => 'Belum ada log';

  @override
  String get sftpPreviewTooLarge =>
      'Berkas melebihi batas pratinjau 1 MiB. Silakan unduh dan buka secara eksternal.';

  @override
  String get sftpSaveFailed =>
      'Gagal menyimpan berkas. Periksa izin atau koneksi jaringan.';

  @override
  String get sftpSaving => 'Menyimpan...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Koneksi server target berubah; verifikasi status jarak jauh sebelum melanjutkan';

  @override
  String get nasInstallBlockerCancelled =>
      'Penerapan dibatalkan oleh pengguna. Tinjau pengaturan dan coba lagi jika diperlukan.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'Inspeksi gagal menanyakan kontainer jarak jauh. Periksa konektivitas server atau inspeksi secara manual.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Langkah penerapan batas waktu habis. Periksa beban server atau koneksi jaringan dan coba lagi.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Penerapan terganggu; tinjau status jarak jauh sebelum melanjutkan.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Layanan dimulai tetapi pemeriksaan kesehatan HTTP batas waktu habis. Verifikasi log layanan atau ketersediaan port.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Rekonsiliasi gagal. Verifikasi status kontainer jarak jauh secara manual atau mulai penerapan baru.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Status kontainer jarak jauh tidak pasti. Diperlukan inspeksi manual dan rekonsiliasi.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Proses kontainer keluar sebelum waktunya. Periksa log untuk kesalahan konfigurasi atau izin.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Gagal menulis berkas penerapan di server target. Periksa ruang disk dan izin.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Rencana penerapan sudah basi. Harap jalankan kembali pemeriksaan pra-penerapan.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Kontainer yang ada tidak dibuat oleh aplikasi ini. Periksa secara manual untuk mencegah penimpaan.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Koneksi SSH aktif ke server target diperlukan.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Status jarak jauh berbeda dari status lokal. Harap rekonsiliasi sebelum melanjutkan.';

  @override
  String get nasInstallBlockerFailed =>
      'Penerapan mengalami kesalahan. Periksa log dan coba lagi.';

  @override
  String get nasInstallBlockerBusy =>
      'Tugas instalasi sudah berlangsung. Harap periksa progres tugas saat ini.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Gagal mempertahankan status penerapan. Harap periksa ruang penyimpanan lokal dan izin berkas.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Hasil perintah jarak jauh tidak diketahui. Harap jalankan inspeksi hanya-baca daripada mencoba ulang penerapan secara langsung.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Pemeriksaan lingkungan pra-penerapan gagal. Harap selesaikan penghambat sebelum melanjutkan.';

  @override
  String serverDeleteFailed(String error) {
    return 'Gagal menghapus server: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Mode Agen';

  @override
  String get chatRunSettingsApprovalPolicy => 'Kebijakan Persetujuan Lokal';

  @override
  String get chatRunSettingsExtraSettings => 'Pengaturan Tambahan';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Mengizinkan operasi yang diketahui aman secara otomatis; meminta konfirmasi setiap kali keamanan operasi tidak dapat ditentukan.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Gagal menerapkan pengaturan jalan: $error';
  }

  @override
  String get chatMessageCopied => 'Pesan disalin ke papan klip';

  @override
  String get copy => 'Salin';

  @override
  String get rename => 'Ubah Nama';

  @override
  String get refresh => 'Segarkan';

  @override
  String get sessionTitle => 'Judul Sesi';

  @override
  String get chatSettingsStale => 'Basi';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Pengaturan tersedia setelah pesan pertama';

  @override
  String get chatReimportAsCopy => 'Impor Ulang sebagai Salinan';

  @override
  String get chatSearchCommandsHint => 'Cari perintah atau keterampilan...';

  @override
  String get chatCommandsTab => 'Perintah';

  @override
  String get chatSkillsTab => 'Keahlian';

  @override
  String get chatAccountAndQuotaTitle => 'Akun & Kuota';

  @override
  String get chatAccountSectionTitle => 'Akun';

  @override
  String get chatAccountNotProvided => 'Tidak ada detail akun yang dilaporkan';

  @override
  String get chatAccountKind => 'Jenis';

  @override
  String get chatAccountLabel => 'Label';

  @override
  String get chatAccountPlan => 'Paket';

  @override
  String get chatAccountEmail => 'Email';

  @override
  String get chatAccountUpdatedAt => 'Diperbarui';

  @override
  String get chatQuotaSectionTitle => 'Kuota & Status';

  @override
  String get chatStatusSourceNote => 'Output /status Mentah Agen';

  @override
  String get chatStatusNotQueried => 'Status belum ditanyakan';

  @override
  String get chatQueryStatusAction => 'Tanyakan Status (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Kueri status tidak tersedia dalam sesi saat ini';

  @override
  String get chatAttachmentMissing =>
      'Berkas lampiran hilang atau tidak tersedia';

  @override
  String get chatViewModeList => 'Daftar';

  @override
  String get chatViewModeCards => 'Kartu';

  @override
  String get chatViewModeGrid => 'Gambar';

  @override
  String get chatRemoteBrowserTitle => 'Ruang Kerja Jarak Jauh';

  @override
  String get chatSelectDirectory => 'Pilih Direktori';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Lampirkan yang Dipilih ($count)';
  }

  @override
  String get chatNoFilesFound => 'Tidak ada berkas yang ditemukan';

  @override
  String get chatRootDirectory => 'Root';

  @override
  String get chatSelectThisDirectory => 'Gunakan direktori ini';

  @override
  String get chatAgentVersion => 'Versi Agen';

  @override
  String get chatParentDirectory => 'Direktori Induk';

  @override
  String get chatSearchFilesHint => 'Cari berkas...';

  @override
  String get chatCommandsEmpty =>
      'Tidak ada perintah garis miring yang disediakan oleh agen';

  @override
  String get chatSkillsEmpty => 'Tidak ada keahlian yang disediakan oleh agen';

  @override
  String get chatFileUnsupported =>
      'Jenis berkas tidak didukung untuk lampiran';

  @override
  String get chatStatusNotProvided => 'Kueri status tidak disediakan oleh agen';

  @override
  String get sessionRecoveryReconnecting => 'Menghubungkan ulang...';

  @override
  String get sessionRecoverySyncing => 'Menyinkronkan output...';

  @override
  String get sessionRecoveryIncomplete =>
      'Beberapa output tidak dapat dipulihkan';

  @override
  String get sessionRecoveryFailed => 'Pemulihan gagal';

  @override
  String get sessionRecoveryRetry => 'Coba Lagi';

  @override
  String get dashboardUpdatesPaused => 'Pembaruan dijeda';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'Katalog model CLI saat ini tidak tersedia. Model mungkin di-cache atau dibatasi oleh versi CLI; Anda juga dapat memasukkan nama model secara manual.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Model ditanyakan dari app-server CLI menggunakan login CLI Anda saat ini. Katalog mungkin di-cache atau terbatas versi; Anda dapat menyegarkan secara manual atau beralih ke input manual.';

  @override
  String get chatModelCatalogError403 =>
      'Akses kueri model CLI ditolak (403). Periksa login CLI dan konektivitas layanan, atau masukkan nama model secara manual.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Kesalahan katalog model: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Otorisasi Katalog Model';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Otorisasi Katalog Model';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Ini akan memulai otorisasi browser untuk katalog model pada host/kontainer target. Login Codex dan sesi terminal yang ada akan tetap tidak tersentuh sepenuhnya. Lanjutkan?';

  @override
  String get chatModelAuthorizing => 'Mengotorisasi melalui browser...';

  @override
  String get chatModelAuthorizeCancel => 'Batalkan Otorisasi';

  @override
  String get chatCommandsFirstTurnNote =>
      'Perintah garis miring akan diiklankan oleh runtime agen setelah sesi diinisialisasi, tanpa memerlukan percakapan biasa sebelumnya; draf tidak secara otomatis membuat sesi.';

  @override
  String get chatCommandsClientActionRunSettings => 'Pengaturan Jalan';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Direktori Kerja';

  @override
  String get chatCommandsClientActionsSection => 'Tindakan Lokal';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Daftar Model';

  @override
  String get chatRunSettingsModelSourceCustom => 'Input Manual';

  @override
  String get chatRunSettingsCustomModelHint => 'Masukkan ID model';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Nama model manual belum diverifikasi dan akan dikirim langsung ke runtime agen, yang mungkin menolak model yang tidak didukung.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Nama model tidak boleh kosong';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Nama model maksimal 256 karakter tanpa spasi atau karakter kontrol';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Perintah diverifikasi untuk versi adaptor saat ini. Memilih akan menyisipkan teks ke dalam draf; Kirim akan menginisialisasi sesi sesuai permintaan dan menjalankan perintah secara langsung.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Gagal menemukan perintah atau keahlian';

  @override
  String get chatAuthWaitingForBrowser => 'Menunggu otorisasi di browser...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Tidak dapat membuka browser eksternal. Silakan buka kembali atau salin tautan otorisasi di bawah.';

  @override
  String get chatAuthReopenBrowser => 'Buka Kembali Browser';

  @override
  String get chatAuthCopyLink => 'Salin Tautan';

  @override
  String get chatAuthManualCallback => 'Callback Manual';

  @override
  String get chatAuthManualCallbackTitle => 'Masukkan URL Callback Otorisasi';

  @override
  String get chatAuthManualCallbackDesc =>
      'Tempelkan URL pengalihan lengkap (http://127.0.0.1:PORT/...?code=...&state=...) dari browser untuk menyelesaikan otorisasi. Kode otorisasi mentah tidak diterima.';

  @override
  String get chatAuthCallbackInputLabel => 'URL Callback';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Format URL callback tidak valid atau pengiriman gagal';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP memerlukan otorisasi akun resmi, terpisah dari login CLI terminal.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Giliran ini memerlukan autentikasi ACP. Hubungkan kembali dan minta otorisasi untuk melanjutkan.';

  @override
  String get chatRequestAuthButton => 'Minta Autentikasi';

  @override
  String get agentActionAcpLogin => 'Masuk ACP';

  @override
  String get agentActionCliLogin => 'Login CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Kredensial ACP tidak ada (diperlukan masuk ACP)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Kredensial ACP disimpan (belum diverifikasi)';

  @override
  String get chatAuthMethodUnavailable =>
      'Metode autentikasi yang dipilih tidak tersedia.';

  @override
  String get chatAuthConnectionExpired =>
      'Koneksi autentikasi kedaluwarsa. Silakan coba lagi.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Gagal mengirimkan callback otorisasi ke server.';

  @override
  String get agentTargetChangedNotice =>
      'Server target telah berubah. Silakan buka kembali manajemen agen di server saat ini.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Pemeriksaan autentikasi Antigravity tidak tersedia';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Respons pemeriksaan autentikasi Antigravity tidak valid';

  @override
  String get sftpDownloadDisconnected => 'Unduhan terputus';

  @override
  String get sftpDownloadPermissionDenied => 'Izin ditolak';

  @override
  String get sftpDownloadNotFound => 'Berkas jarak jauh tidak ditemukan';

  @override
  String get sftpDownloadTimeout => 'Batas waktu unduhan habis';

  @override
  String get sftpDownloadLocalSpace =>
      'Ruang penyimpanan lokal tidak mencukupi';

  @override
  String get sftpDownloadLocalIo => 'Gagal menulis ke penyimpanan lokal';

  @override
  String get sftpDownloadIncomplete => 'Unduhan tidak lengkap';

  @override
  String get transferStatusWaitingConnection => 'Menunggu koneksi';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Gagal memulai pendengar callback otorisasi lokal. Silakan coba autentikasi lagi.';

  @override
  String get settingsExperimentalFeatures => 'Fitur Eksperimental';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Coba kemampuan pratinjau dan eksperimental';

  @override
  String get settingsExperimentalCliChatTitle => 'Obrolan Pintar CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Aktifkan antarmuka obrolan agen baris perintah khusus';

  @override
  String get settingsExperimentalDialogClose => 'Tutup';

  @override
  String get settingsExperimentalSaveFailed =>
      'Gagal memperbarui pengaturan fitur eksperimental';

  @override
  String get settingsExperimentalNasTitle => 'Media NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'Aktifkan pustaka media, pindai folder, dan pemutaran audio';

  @override
  String get settingsLanguageSaveFailed =>
      'Gagal memperbarui pengaturan bahasa';

  @override
  String get settingsAboutPrivacy => 'Tentang dan privasi';

  @override
  String get privacyPolicyTitle => 'Kebijakan privasi';

  @override
  String get privacyPolicyDescription => 'Penggunaan data dan pilihan Anda';

  @override
  String get privacyContactTitle => 'Kontak privasi';

  @override
  String get privacyCopyEmail => 'Salin alamat email';

  @override
  String get privacyEmailCopied => 'Alamat email disalin';

  @override
  String get privacyOnlineVersion => 'Lihat versi online';

  @override
  String get privacyLinkFailed =>
      'Tautan tidak dapat dibuka. Anda dapat menyalin alamat email.';

  @override
  String get privacyLoadFailed =>
      'Kebijakan tidak dapat dimuat. Lihat versi online.';

  @override
  String get privacyVersionUnknown => 'Versi tidak tersedia';

  @override
  String get aboutWebsite => 'Situs web resmi';

  @override
  String get aboutLicense => 'Lisensi aplikasi';

  @override
  String get aboutThirdPartyLicenses => 'Lisensi sumber terbuka pihak ketiga';

  @override
  String get aboutLicenseSummary =>
      'Materi asli Valhalla dilisensikan untuk penggunaan nonkomersial berdasarkan PolyForm Noncommercial 1.0.0. Penggunaan komersial di luar izin lisensi memerlukan izin terpisah. Komponen pihak ketiga tetap menggunakan lisensinya masing-masing. Ketentuan lengkap di bawah mengatur penggunaan.';

  @override
  String get aboutCopyrightNotice => 'Pemberitahuan hak cipta';

  @override
  String get aboutLicenseLoadFailed =>
      'Lisensi tidak dapat dimuat. Hubungi norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Tautan tidak dapat dibuka. Buka https://norns.cc.cd di browser Anda.';

  @override
  String get downloadReveal => 'Tampilkan di File Explorer';

  @override
  String get downloadRevealFailed =>
      'Folder unduhan tidak dapat dibuka. Folder mungkin telah dipindahkan atau dihapus.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count kunci host tepercaya';
  }

  @override
  String get settingsKnownHostsEmpty =>
      'Tidak ada kunci host tepercaya yang ditemukan';

  @override
  String get settingsKnownHostsDialogTitle => 'Kunci Host yang Dikenal';

  @override
  String get settingsHostKeyRevoke => 'Cabut';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'Cabut Kunci Host';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return 'Cabut kunci host untuk $hostPort? Koneksi SSH aktif ke host ini akan terputus dan Anda harus memverifikasi kunci pada koneksi berikutnya.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Sidik jari kunci host disalin ke papan klip';

  @override
  String get settingsHostKeyRevoked => 'Kunci host dicabut';

  @override
  String get settingsClearStorageSubtitle =>
      'Hapus kata sandi dan kunci privat tersimpan untuk server terpilih';

  @override
  String get settingsClearStorageDialogTitle => 'Atur Ulang Kredensial Server';

  @override
  String get settingsClearStorageDesc =>
      'Pilih server untuk menghapus kata sandi SSH dan kunci privat dari penyimpanan aman. Konfigurasi server dan riwayat obrolan tidak akan dihapus.';

  @override
  String get settingsClearStorageNoServers => 'Tidak ada server yang tersedia';

  @override
  String get settingsClearStorageSelectAll => 'Pilih Semua';

  @override
  String get settingsClearStorageDeselectAll => 'Batalkan Semua';

  @override
  String get settingsClearStorageConfirmTitle =>
      'Konfirmasi Penghapusan Kredensial';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'Yakin ingin menghapus kredensial untuk $count server terpilih? Koneksi aktif akan segera diputus.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Hapus Terpilih ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Kredensial server terpilih berhasil dihapus';

  @override
  String get settingsClearStorageError =>
      'Gagal menghapus kredensial untuk beberapa server. Silakan coba lagi.';

  @override
  String get settingsDefaultAcpAgent => 'Agen ACP Default';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Agen default untuk obrolan ACP di server ini';

  @override
  String get settingsDefaultCliAgent => 'Agen CLI Default';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Agen default untuk obrolan CLI di server ini';

  @override
  String get settingsDefaultAgentAutomatic =>
      'Otomatis (pertama yang tersedia)';

  @override
  String get settingsDefaultAgentSelectTitle => 'Pilih Agen Default';

  @override
  String get settingsDefaultAgentNoServer => 'Tidak ada server yang dipilih';

  @override
  String get settingsDefaultAgentNoAgents =>
      'Tidak ada agen yang dikonfigurasi untuk server ini';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Gagal memperbarui pengaturan agen default';

  @override
  String get dockerViewGroupContainers => 'Kontainer';

  @override
  String get dockerViewGroupProjects => 'Proyek Compose';

  @override
  String get dockerProjectActionStart => 'Mulai Proyek';

  @override
  String get dockerProjectActionStop => 'Hentikan Proyek';

  @override
  String get dockerProjectActionRestart => 'Mulai Ulang Proyek';

  @override
  String get dockerProjectConfirmStopTitle => 'Hentikan Proyek Compose';

  @override
  String get dockerProjectConfirmRestartTitle => 'Mulai Ulang Proyek Compose';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'Apakah Anda yakin ingin $action proyek \"$project\"? $count kontainer berikut akan terpengaruh:';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'Proyek \"$project\" $action berhasil diselesaikan';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'Proyek \"$project\" $action selesai dengan $failedCount kegagalan';
  }

  @override
  String get dockerNoProjects =>
      'Tidak ada proyek Docker Compose yang ditemukan';

  @override
  String get dockerMountsTitle => 'Titik Mount';

  @override
  String get dockerMountReadOnly => 'Hanya baca';

  @override
  String get dockerMountReadWrite => 'Baca/Tulis';

  @override
  String get sftpBookmarksTitle => 'Bookmark Direktori';

  @override
  String get sftpNoBookmarks => 'Belum ada bookmark tersimpan';

  @override
  String get sftpAddBookmark => 'Tambah Bookmark';

  @override
  String get sftpRemoveBookmark => 'Hapus Bookmark';

  @override
  String get sftpCurrentDirectory => 'Direktori Saat Ini';

  @override
  String get sftpSelectMode => 'Mode Pilih Banyak';

  @override
  String sftpSelectedCount(int count) {
    return '$count dipilih';
  }

  @override
  String get sftpSelectAll => 'Pilih Semua';

  @override
  String get sftpDeselectAll => 'Batal Pilih Semua';

  @override
  String get sftpBatchCopy => 'Salin';

  @override
  String get sftpBatchMove => 'Pindahkan';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Konfirmasi Penghapusan Massal';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'Yakin ingin menghapus $count item yang dipilih?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Catatan: Direktori yang tidak kosong tidak dapat dihapus secara rekursif dan akan dilewati.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Konfirmasi Salin Massal';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'Salin $count item yang dipilih ke \"$directory\"?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Konfirmasi Pindah Massal';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'Pindahkan $count item yang dipilih ke \"$directory\"?';
  }

  @override
  String get sftpBatchResultsTitle => 'Hasil Operasi Massal';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Dilewati (target sudah ada atau tidak didukung)';

  @override
  String get sftpBatchTargetRestricted =>
      'Tidak dapat memilih direktori ini atau sub-direktorinya sebagai tujuan';

  @override
  String get sftpSelectCurrentDir => 'Pilih Direktori Ini';

  @override
  String sftpBatchOperationSuccess(int count) {
    return 'Berhasil memproses $count item';
  }

  @override
  String get configMigrationTitle => 'Pencadangan & Migrasi Konfigurasi';

  @override
  String get configExportTitle => 'Ekspor Konfigurasi';

  @override
  String get configExportSubtitle =>
      'Ekspor server, agen, perintah, bookmark, dan preferensi ke JSON';

  @override
  String get configExportDialogTitle => 'Ekspor Konfigurasi Valhalla';

  @override
  String get configExportSuccess => 'Konfigurasi berhasil diekspor';

  @override
  String configExportError(String error) {
    return 'Gagal mengekspor konfigurasi: $error';
  }

  @override
  String get configImportTitle => 'Impor Konfigurasi';

  @override
  String get configImportSubtitle =>
      'Impor konfigurasi dari file JSON cadangan';

  @override
  String get configBackupTooLarge =>
      'File cadangan melebihi batas ukuran maksimum (8 MB)';

  @override
  String get configImportPreviewTitle => 'Pratinjau Impor Konfigurasi';

  @override
  String get configImportPreviewDesc =>
      'Tinjau konten sebelum mengimpor. Item yang ada akan dipertahankan dan digabungkan.';

  @override
  String configImportServersCount(int count) {
    return 'Server ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'Agen ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'Perintah Cepat ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'Bookmark ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'Perintah kustom mungkin berisi skrip sensitif atau kredensial tertanam. Tidak ada kata sandi, kunci privat, atau sidik jari host tepercaya yang ditransfer.';

  @override
  String get configImportGlobalPreferences =>
      'Impor preferensi aplikasi global';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Menimpa pengaturan tema, terminal, dan navigasi saat ini';

  @override
  String get configImportConfirmAction => 'Konfirmasi Impor';

  @override
  String get configImportSuccess => 'Konfigurasi berhasil diimpor';

  @override
  String get configImportErrorTitle => 'File Cadangan Konfigurasi Tidak Valid';

  @override
  String configImportErrorGeneric(String error) {
    return 'Gagal mengimpor konfigurasi: $error';
  }

  @override
  String get configImportErrorCopyDetails => 'Salin Detail Diagnostik';

  @override
  String get configImportErrorCopied =>
      'Detail diagnostik disalin ke papan klip';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Format atau versi cadangan tidak didukung';

  @override
  String get configImportErrorMalformed =>
      'JSON konfigurasi rusak atau tidak sesuai format';
}
