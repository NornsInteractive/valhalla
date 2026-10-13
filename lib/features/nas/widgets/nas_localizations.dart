import 'package:flutter/widgets.dart';
import '../../../core/services/nas_install_service.dart';
import '../../../l10n/app_localizations.dart';

extension NasLocalizations on BuildContext {
  AppLocalizations get _loc => AppLocalizations.of(this);

  String get nasSources => _loc.nasSources;
  String get nasAddSource => _loc.nasAddSource;
  String get nasEditSource => _loc.nasEditSource;
  String get nasRemoveSource => _loc.nasRemoveSource;
  String nasRemoveSourceConfirm(String name) =>
      _loc.nasRemoveSourceConfirm(name);
  String get nasNoSources => _loc.nasNoSources;
  String get nasNoSourcesDesc => _loc.nasNoSourcesDesc;
  String get nasSourceType => _loc.nasSourceType;
  String get nasSourceName => _loc.nasSourceName;
  String get nasProbe => _loc.nasProbe;
  String get nasProbeSuccess => _loc.nasProbeSuccess;
  String get nasProbeFailed => _loc.nasProbeFailed;
  String get nasEndpoint => _loc.nasEndpoint;
  String get nasRootPath => _loc.nasRootPath;
  String get nasUsername => _loc.nasUsername;
  String get nasPassword => _loc.nasPassword;
  String get nasDomain => _loc.nasDomain;
  String get nasAuthenticate => _loc.nasAuthenticate;
  String get nasAuthSuccess => _loc.nasAuthSuccess;
  String get nasAuthFailed => _loc.nasAuthFailed;
  String get nasBrowseUnavailable => _loc.nasBrowseUnavailable;
  String get nasInvalidDirectoryEntry => _loc.nasInvalidDirectoryEntry;
  String get nasInvalidLibraryResponse => _loc.nasInvalidLibraryResponse;
  String get nasScanFilterUnresolved => _loc.nasScanFilterUnresolved;
  String get nasSourceSaveIncomplete => _loc.nasSourceSaveIncomplete;

  String get nasTabDownloads => _loc.nasTabDownloads;
  String get nasNoDownloads => _loc.nasNoDownloads;
  String get nasDownloadQueued => _loc.nasDownloadQueued;
  String get nasDownloadDownloading => _loc.nasDownloadDownloading;
  String get nasDownloadCompleted => _loc.nasDownloadCompleted;
  String get nasDownloadCancelled => _loc.nasDownloadCancelled;
  String get nasDownloadFailed => _loc.nasDownloadFailed;
  String get nasRetryDownload => _loc.nasRetryDownload;
  String get nasCancelDownload => _loc.nasCancelDownload;
  String get nasOpenDownloadedFile => _loc.nasOpenDownloadedFile;
  String nasDownloading(String name) => _loc.nasDownloading(name);

  String get nasQueue => _loc.nasQueue;
  String get nasNoQueue => _loc.nasNoQueue;
  String get nasSpeed => _loc.nasSpeed;
  String get nasQuality => _loc.nasQuality;
  String get nasAudioTrack => _loc.nasAudioTrack;
  String get nasSubtitleTrack => _loc.nasSubtitleTrack;
  String get nasSubtitleNone => _loc.nasSubtitleNone;
  String get nasRepeatOff => _loc.nasRepeatOff;
  String get nasRepeatAll => _loc.nasRepeatAll;
  String get nasRepeatOne => _loc.nasRepeatOne;
  String get nasShuffle => _loc.nasShuffle;
  String get nasCast => _loc.nasCast;
  String get nasCastUnavailable => _loc.nasCastUnavailable;
  String get nasSlideshow => _loc.nasSlideshow;

  String get nasByFolder => _loc.nasByFolder;
  String get nasByArtist => _loc.nasByArtist;
  String get nasByAlbum => _loc.nasByAlbum;
  String get nasAllTracks => _loc.nasAllTracks;
  String get nasPlayAll => _loc.nasPlayAll;
  String get nasPreviousPage => _loc.nasPreviousPage;
  String get nasNextPage => _loc.nasNextPage;
  String get nasClearScope => _loc.nasClearScope;
  String get nasRenamePlaylist => _loc.nasRenamePlaylist;
  String get nasRemoveFromPlaylist => _loc.nasRemoveFromPlaylist;
  String get nasMoveUp => _loc.nasMoveUp;
  String get nasMoveDown => _loc.nasMoveDown;
  String get nasSshServer => _loc.nasSshServer;
  String get nasSelectSshServer => _loc.nasSelectSshServer;
  String get nasQualityOriginal => _loc.nasQualityOriginal;
  String get nasQualityAuto => _loc.nasQualityAuto;
  String get nasQuality4Mbps => _loc.nasQuality4Mbps;
  String get nasQuality10Mbps => _loc.nasQuality10Mbps;
  String get nasQuality20Mbps => _loc.nasQuality20Mbps;

  String get nasCastDevices => _loc.nasCastDevices;
  String get nasCastDiscovering => _loc.nasCastDiscovering;
  String get nasCastRelayingNotice => _loc.nasCastRelayingNotice;
  String get nasCastStop => _loc.nasCastStop;
  String get nasCastVolume => _loc.nasCastVolume;
  String get nasCastRetry => _loc.nasCastRetry;

  String get nasInstallTitle => _loc.nasInstallTitle;
  String get nasInstallProduct => _loc.nasInstallProduct;
  String get nasInstallMediaPath => _loc.nasInstallMediaPath;
  String get nasInstallDataRoot => _loc.nasInstallDataRoot;
  String get nasInstallPort => _loc.nasInstallPort;
  String get nasInstallBindAddress => _loc.nasInstallBindAddress;
  String get nasInstallWebdavUser => _loc.nasInstallWebdavUser;
  String get nasInstallWebdavPassword => _loc.nasInstallWebdavPassword;
  String get nasInstallPreparePlan => _loc.nasInstallPreparePlan;
  String get nasInstallPlanTitle => _loc.nasInstallPlanTitle;
  String get nasInstallBlockersTitle => _loc.nasInstallBlockersTitle;
  String get nasInstallConfirmDeploy => _loc.nasInstallConfirmDeploy;
  String get nasInstallDeploying => _loc.nasInstallDeploying;
  String get nasInstallSuccess => _loc.nasInstallSuccess;
  String get nasInstallSuccessDesc => _loc.nasInstallSuccessDesc;
  String get nasInstallContainerId => _loc.nasInstallContainerId;
  String get nasInstallEndpoint => _loc.nasInstallEndpoint;

  String get nasUseSshTunnel => _loc.nasUseSshTunnel;
  String get nasUseSshTunnelDesc => _loc.nasUseSshTunnelDesc;
  String get nasSshTunnelHint => _loc.nasSshTunnelHint;
  String get nasKeepEmptyPassword => _loc.nasKeepEmptyPassword;
  String get nasSourceNameRequired => _loc.nasSourceNameRequired;
  String get nasInvalidEndpoint => _loc.nasInvalidEndpoint;
  String get nasSourceUnreachable => _loc.nasSourceUnreachable;
  String get nasSshTunnelFailed => _loc.nasSshTunnelFailed;
  String get nasOperationFailed => _loc.nasOperationFailed;

  String get nasInstallStepCreateDir => _loc.nasInstallStepCreateDir;
  String get nasInstallStepWriteCompose => _loc.nasInstallStepWriteCompose;
  String get nasInstallStepWriteCreds => _loc.nasInstallStepWriteCreds;
  String get nasInstallStepPullImage => _loc.nasInstallStepPullImage;
  String get nasInstallStepStartService => _loc.nasInstallStepStartService;
  String get nasInstallStepCheckHttp => _loc.nasInstallStepCheckHttp;

  String get nasInstallBlockerDocker => _loc.nasInstallBlockerDocker;
  String get nasInstallBlockerCompose => _loc.nasInstallBlockerCompose;
  String get nasInstallBlockerIdentity => _loc.nasInstallBlockerIdentity;
  String get nasInstallBlockerTools => _loc.nasInstallBlockerTools;
  String get nasInstallBlockerMedia => _loc.nasInstallBlockerMedia;
  String get nasInstallBlockerParent => _loc.nasInstallBlockerParent;
  String get nasInstallBlockerOverlap => _loc.nasInstallBlockerOverlap;
  String get nasInstallBlockerCollision => _loc.nasInstallBlockerCollision;
  String get nasInstallBlockerPort => _loc.nasInstallBlockerPort;
  String get nasInstallBlockerContainer => _loc.nasInstallBlockerContainer;
  String get nasInstallBlockerImage => _loc.nasInstallBlockerImage;

  String get nasInstallGuidanceTunnel => _loc.nasInstallGuidanceTunnel;
  String get nasInstallGuidanceTls => _loc.nasInstallGuidanceTls;
  String get nasInstallGuidanceSetup => _loc.nasInstallGuidanceSetup;
  String get nasInstallGuidanceReadOnly => _loc.nasInstallGuidanceReadOnly;
  String get nasInstallGuidancePreserved => _loc.nasInstallGuidancePreserved;

  String get nasDownloadCompletedWithOpenError =>
      _loc.nasDownloadCompletedWithOpenError;
  String get nasRetryOpen => _loc.nasRetryOpen;
  String get nasExternalOpenFailed => _loc.nasExternalOpenFailed;
  String get nasLoadMoreGroups => _loc.nasLoadMoreGroups;
  String get nasLibraryId => _loc.nasLibraryId;
  String get nasLibraryIdHint => _loc.nasLibraryIdHint;
  String nasScanPathRelativeHint(String value) =>
      _loc.nasScanPathRelativeHint(value);
  String get nasSourceChangedError => _loc.nasSourceChangedError;
  String get nasInvalidLibraryId => _loc.nasInvalidLibraryId;

  String nasInstallStepText(String code) => switch (code) {
    'NAS_INSTALL_CREATE_PRIVATE_DIRECTORY' => nasInstallStepCreateDir,
    'NAS_INSTALL_WRITE_COMPOSE' => nasInstallStepWriteCompose,
    'NAS_INSTALL_WRITE_PRIVATE_CREDENTIALS' => nasInstallStepWriteCreds,
    'NAS_INSTALL_PULL_PINNED_IMAGE' => nasInstallStepPullImage,
    'NAS_INSTALL_START_SERVICE' => nasInstallStepStartService,
    'NAS_INSTALL_CHECK_HTTP' => nasInstallStepCheckHttp,
    _ => code,
  };

  String nasInstallBlockerText(String code) => switch (code) {
    'NAS_INSTALL_DOCKER_REQUIRED' ||
    'NAS_INSTALL_LOCAL_DOCKER_REQUIRED' => nasInstallBlockerDocker,
    'NAS_INSTALL_COMPOSE_REQUIRED' => nasInstallBlockerCompose,
    'NAS_INSTALL_IDENTITY_UNAVAILABLE' => nasInstallBlockerIdentity,
    'NAS_INSTALL_TOOLS_REQUIRED' => nasInstallBlockerTools,
    'NAS_INSTALL_MEDIA_UNREADABLE' => nasInstallBlockerMedia,
    'NAS_INSTALL_PARENT_UNWRITABLE' => nasInstallBlockerParent,
    'NAS_INSTALL_MEDIA_DATA_OVERLAP' => nasInstallBlockerOverlap,
    'NAS_INSTALL_DIRECTORY_COLLISION' => nasInstallBlockerCollision,
    'NAS_INSTALL_PORT_CHECK_FAILED' => nasInstallBlockerPort,
    'NAS_INSTALL_PORT_IN_USE' => nasInstallBlockerPort,
    'NAS_INSTALL_CONTAINER_CHECK_FAILED' => nasInstallBlockerContainer,
    'NAS_INSTALL_CONTAINER_COLLISION' => nasInstallBlockerContainer,
    'NAS_INSTALL_IMAGE_UNAVAILABLE' => nasInstallBlockerImage,
    'NAS_INSTALL_CONNECTION_CHANGED' => _loc.nasInstallBlockerConnectionChanged,
    'NAS_INSTALL_CANCELLED' => _loc.nasInstallBlockerCancelled,
    'NAS_INSTALL_INSPECT_FAILED' => _loc.nasInstallBlockerInspectFailed,
    'NAS_INSTALL_DEADLINE_EXCEEDED' ||
    'NAS_INSTALL_COMMAND_TIMEOUT' => _loc.nasInstallBlockerDeadlineExceeded,
    'NAS_INSTALL_INTERRUPTED' => _loc.nasInstallBlockerInterrupted,
    'NAS_INSTALL_HEALTH_TIMEOUT' => _loc.nasInstallBlockerHealthTimeout,
    'NAS_INSTALL_RECONCILIATION_FAILED' =>
      _loc.nasInstallBlockerReconciliationFailed,
    'NAS_INSTALL_REMOTE_INSPECTION_REQUIRED' =>
      _loc.nasInstallBlockerRemoteInspectionRequired,
    'NAS_INSTALL_SERVICE_EXITED' => _loc.nasInstallBlockerServiceExited,
    'NAS_INSTALL_WRITE_FAILED' => _loc.nasInstallBlockerWriteFailed,
    'NAS_INSTALL_PLAN_STALE' => _loc.nasInstallBlockerPlanStale,
    'NAS_INSTALL_OWNERSHIP_CHANGED' => _loc.nasInstallBlockerOwnershipChanged,
    'NAS_INSTALL_SSH_REQUIRED' => _loc.nasInstallBlockerSshRequired,
    'NAS_INSTALL_RECONCILIATION_REQUIRED' =>
      _loc.nasInstallBlockerReconciliationRequired,
    'NAS_INSTALL_FAILED' => _loc.nasInstallBlockerFailed,
    'NAS_INSTALL_BUSY' => _loc.nasInstallBlockerBusy,
    'NAS_INSTALL_STATE_SAVE_FAILED' => _loc.nasInstallBlockerStateSaveFailed,
    'NAS_INSTALL_COMMAND_RESULT_UNKNOWN' =>
      _loc.nasInstallBlockerCommandResultUnknown,
    'NAS_INSTALL_PREFLIGHT_FAILED' => _loc.nasInstallBlockerPreflightFailed,
    _ => code,
  };

  String nasInstallGuidanceText(String code) => switch (code) {
    'NAS_INSTALL_SSH_TUNNEL_REQUIRED' => nasInstallGuidanceTunnel,
    'NAS_INSTALL_TLS_PROXY_RECOMMENDED' => nasInstallGuidanceTls,
    'NAS_INSTALL_COMPLETE_SERVER_SETUP' => nasInstallGuidanceSetup,
    'NAS_INSTALL_MEDIA_READ_ONLY' => nasInstallGuidanceReadOnly,
    'NAS_INSTALL_DATA_PRESERVED_ON_FAILURE' => nasInstallGuidancePreserved,
    _ => code,
  };

  String nasInstallStageText(NasInstallStage stage) => switch (stage) {
    NasInstallStage.preflight => _loc.nasInstallStagePreflight,
    NasInstallStage.review => _loc.nasInstallStageReview,
    NasInstallStage.writing => _loc.nasInstallStageWriting,
    NasInstallStage.pulling => _loc.nasInstallStagePulling,
    NasInstallStage.starting => _loc.nasInstallStageStarting,
    NasInstallStage.health => _loc.nasInstallStageHealth,
    NasInstallStage.cleanup => _loc.nasInstallStageCleanup,
    NasInstallStage.succeeded => _loc.nasInstallStageSucceeded,
    NasInstallStage.failed => _loc.nasInstallStageFailed,
    NasInstallStage.cancelled => _loc.nasInstallStageCancelled,
    NasInstallStage.needsInspection => _loc.nasInstallStageNeedsInspection,
    NasInstallStage.reconciling => _loc.nasInstallStageReconciling,
  };

  String get nasInstallTaskTitle => _loc.nasInstallTaskTitle;
  String get nasInstallCancel => _loc.nasInstallCancel;
  String get nasInstallReconcile => _loc.nasInstallReconcile;
  String get nasInstallServerNotFound => _loc.nasInstallServerNotFound;
  String get nasInstallPortRangeError => _loc.nasInstallPortRangeError;
  String nasInstallElapsedTime(String time) => _loc.nasInstallElapsedTime(time);
  String get nasInstallLogTail => _loc.nasInstallLogTail;
  String get nasInstallCleanupCompleted => _loc.nasInstallCleanupCompleted;
  String get nasInstallCleanupIncomplete => _loc.nasInstallCleanupIncomplete;
  String get nasInstallNewDeployment => _loc.nasInstallNewDeployment;
  String get nasInstallBackEdit => _loc.nasInstallBackEdit;
  String get nasInstallClose => _loc.nasInstallClose;
  String get nasInstallMediaPathHint => _loc.nasInstallMediaPathHint;
  String get nasInstallDataRootHint => _loc.nasInstallDataRootHint;
  String get nasInstallBindAddressHint => _loc.nasInstallBindAddressHint;
  String get nasInstallWebdavPasswordHint => _loc.nasInstallWebdavPasswordHint;
  String get nasInstallTargetServer => _loc.nasInstallTargetServer;
  String get nasInstallTargetImage => _loc.nasInstallTargetImage;
  String get nasInstallContainerName => _loc.nasInstallContainerName;
  String get nasInstallBindAndPort => _loc.nasInstallBindAndPort;
  String get nasInstallComposePreview => _loc.nasInstallComposePreview;
  String get nasInstallPlannedSteps => _loc.nasInstallPlannedSteps;
  String get nasInstallGuidanceNotes => _loc.nasInstallGuidanceNotes;
  String get nasInstallNoLogsYet => _loc.nasInstallNoLogsYet;
  String get nasInstallBlockerBusy => _loc.nasInstallBlockerBusy;
  String get nasInstallBlockerStateSaveFailed =>
      _loc.nasInstallBlockerStateSaveFailed;
  String get nasInstallBlockerCommandResultUnknown =>
      _loc.nasInstallBlockerCommandResultUnknown;
  String get nasInstallBlockerPreflightFailed =>
      _loc.nasInstallBlockerPreflightFailed;

  String get nasMetadataEnriching => _loc.nasMetadataEnriching;
  String nasMetadataEnrichingWithCount(int count) =>
      _loc.nasMetadataEnrichingWithCount(count);
  String nasMetadataEnrichingStatus(int count) =>
      count > 0 ? nasMetadataEnrichingWithCount(count) : nasMetadataEnriching;

  String get nasTabLibrary {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '媒體庫' : '媒体库',
      'de' => 'Mediathek',
      'fr' => 'Bibliothèque',
      'es' => 'Biblioteca',
      'pt' => 'Biblioteca',
      'it' => 'Libreria',
      'id' => 'Pustaka',
      'ja' => 'ライブラリ',
      'ko' => '라이브러리',
      'ru' => 'Медиатека',
      'ar' => 'المكتبة',
      'hi' => 'लाइब्रेरी',
      'tr' => 'Kitaplık',
      'vi' => 'Thư viện',
      'th' => 'คลังสื่อ',
      _ => 'Library',
    };
  }

  String get nasContinueWatching {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '繼續觀看' : '继续观看',
      'de' => 'Weiter ansehen',
      'fr' => 'Reprendre la lecture',
      'es' => 'Continuar viendo',
      'pt' => 'Continuar assistindo',
      'it' => 'Continua a guardare',
      'id' => 'Lanjutkan Menonton',
      'ja' => '続きを見る',
      'ko' => '이어보기',
      'ru' => 'Продолжить просмотр',
      'ar' => 'متابعة المشاهدة',
      'hi' => 'देखना जारी रखें',
      'tr' => 'İzlemeye Devam Et',
      'vi' => 'Tiếp tục xem',
      'th' => 'ดูต่อ',
      _ => 'Continue Watching',
    };
  }

  String get nasContinueListening {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '繼續收聽' : '继续收听',
      'de' => 'Weiter anhören',
      'fr' => 'Reprendre l\'écoute',
      'es' => 'Continuar escuchando',
      'pt' => 'Continuar ouvindo',
      'it' => 'Continua ad ascoltare',
      'id' => 'Lanjutkan Mendengarkan',
      'ja' => '続きを聴く',
      'ko' => '이어서 듣기',
      'ru' => 'Продолжить прослушивание',
      'ar' => 'متابعة الاستماع',
      'hi' => 'सुनना जारी रखें',
      'tr' => 'Dinlemeye Devam Et',
      'vi' => 'Tiếp tục nghe',
      'th' => 'ฟังต่อ',
      _ => 'Continue Listening',
    };
  }

  String get nasRecentPhotos {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '最近照片',
      'de' => 'Neueste Fotos',
      'fr' => 'Photos récentes',
      'es' => 'Fotos recientes',
      'pt' => 'Fotos recentes',
      'it' => 'Foto recenti',
      'id' => 'Foto Terbaru',
      'ja' => '最近の写真',
      'ko' => '최근 사진',
      'ru' => 'Недавние фото',
      'ar' => 'الصور الأخيرة',
      'hi' => 'हाल के फोटो',
      'tr' => 'Son Fotoğraflar',
      'vi' => 'Ảnh gần đây',
      'th' => 'รูปล่าสุด',
      _ => 'Recent Photos',
    };
  }

  String get nasRecentVideos {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '最近影片' : '最近视频',
      'de' => 'Neueste Videos',
      'fr' => 'Vidéos récentes',
      'es' => 'Videos recientes',
      'pt' => 'Vídeos recentes',
      'it' => 'Video recenti',
      'id' => 'Video Terbaru',
      'ja' => '最近の動画',
      'ko' => '최근 동영상',
      'ru' => 'Недавние видео',
      'ar' => 'الفيديوهات الأخيرة',
      'hi' => 'हाल के वीडियो',
      'tr' => 'Son Videolar',
      'vi' => 'Video gần đây',
      'th' => 'วิดีโอล่าสุด',
      _ => 'Recent Videos',
    };
  }

  String get nasRecentMusic {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '最近音樂' : '最近音乐',
      'de' => 'Neueste Musik',
      'fr' => 'Musique récente',
      'es' => 'Música reciente',
      'pt' => 'Músicas recentes',
      'it' => 'Musica recente',
      'id' => 'Musik Terbaru',
      'ja' => '最近の音楽',
      'ko' => '최근 음악',
      'ru' => 'Недавняя музыка',
      'ar' => 'الموسيقى الأخيرة',
      'hi' => 'हाल का संगीत',
      'tr' => 'Son Müzikler',
      'vi' => 'Nhạc gần đây',
      'th' => 'เพลงล่าสุด',
      _ => 'Recent Music',
    };
  }

  String get nasDownloadPaused {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '已暂停',
      'de' => 'Pausiert',
      'fr' => 'En pause',
      'es' => 'En pausa',
      'pt' => 'Pausado',
      'it' => 'In pausa',
      'id' => 'Dijeda',
      'ja' => '一時停止中',
      'ko' => '일시 중지됨',
      'ru' => 'Приостановлено',
      'ar' => 'متوقف مؤقتاً',
      'hi' => 'रोका गया',
      'tr' => 'Duraklatıldı',
      'vi' => 'Đã tạm dừng',
      'th' => 'หยุดชั่วคราวแล้ว',
      _ => 'Paused',
    };
  }

  String get nasDownloadDeleteConfirmTitle {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '刪除離線檔案' : '删除离线文件',
      'de' => 'Offline-Datei löschen',
      'fr' => 'Supprimer le fichier hors-ligne',
      'es' => 'Eliminar archivo sin conexión',
      'pt' => 'Excluir arquivo offline',
      'it' => 'Elimina file offline',
      'id' => 'Hapus Berkas Offline',
      'ja' => 'オフラインファイルの削除',
      'ko' => '오프라인 파일 삭제',
      'ru' => 'Удалить офлайн-файл',
      'ar' => 'حذف الملف غير المتصل',
      'hi' => 'ऑफ़लाइन फ़ाइल हटाएं',
      'tr' => 'Çevrimdışı Dosyayı Sil',
      'vi' => 'Xóa tệp ngoại tuyến',
      'th' => 'ลบไฟล์ออฟไลน์',
      _ => 'Delete Offline File',
    };
  }

  String get nasDownloadDeleteConfirmMessage {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' =>
        loc.contains('Hant')
            ? '這將從您的裝置中刪除已下載的本地離線檔案，遠端伺服器上的原始檔案不會被刪除。'
            : '这将从您的设备上删除已下载的本地离线文件，远程服务器上的原始文件不会被删除。',
      'de' =>
        'Dadurch wird die heruntergeladene lokale Offline-Datei von Ihrem Gerät gelöscht. Die Originaldatei auf dem Remote-Server bleibt erhalten.',
      'fr' =>
        'Cela supprimera le fichier local hors-ligne de votre appareil. Le fichier d\'origine sur le serveur distant ne sera pas supprimé.',
      'es' =>
        'Esto eliminará el archivo local descargado de su dispositivo. El archivo original en el servidor remoto no se eliminará.',
      'pt' =>
        'Isso excluirá o arquivo offline baixado no seu dispositivo. O arquivo original no servidor remoto não será excluído.',
      'it' =>
        'Questo eliminerà il file offline scaricato dal dispositivo. Il file originale sul server remoto non verrà eliminato.',
      'id' =>
        'Tindakan ini akan menghapus berkas offline lokal dari perangkat Anda. Berkas asli di server jarak jauh tidak akan dihapus.',
      'ja' => '端末にダウンロードされたローカルのオフラインファイルを削除します。リモートサーバーの元ファイルは削除されません。',
      'ko' => '기기에 다운로드된 로컬 오프라인 파일을 삭제합니다. 원격 서버의 원본 파일은 삭제되지 않습니다.',
      'ru' =>
        'Это действие удалит скачанный офлайн-файл с вашего устройства. Исходный файл на сервере останется без изменений.',
      'ar' =>
        'سيؤدي هذا إلى حذف الملف المحلي المحمّل من جهازك. لن يتم حذف الملف الأصلي الموجود على الخادم البعيد.',
      'hi' =>
        'यह आपके डिवाइस से डाउनलोड की गई स्थानीय ऑफ़लाइन फ़ाइल को हटा देगा। दूरस्थ सर्वर पर मूल फ़ाइल नहीं हटाई जाएगी।',
      'tr' =>
        'Bu işlem indirilen yerel çevrimdışı dosyayı cihazınızdan siler. Uzak sunucudaki orijinal dosya silinmez.',
      'vi' =>
        'Thao tác này sẽ xóa tệp ngoại tuyến đã tải về khỏi thiết bị của bạn. Tệp gốc trên máy chủ từ xa sẽ không bị xóa.',
      'th' =>
        'การดำเนินการนี้จะลบไฟล์ออฟไลน์ที่ดาวน์โหลดไว้ออกจากอุปกรณ์ของคุณ ไฟล์ต้นฉบับบนเซิร์ฟเวอร์ระยะไกลจะไม่ถูกลบ',
      _ =>
        'This will delete the local downloaded file from your device. The original file on the remote server will not be deleted.',
    };
  }

  String get nasDownloadDeleteConfirmButton {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '刪除離線副本' : '删除离线副本',
      'de' => 'Offline-Kopie löschen',
      'fr' => 'Supprimer la copie locale',
      'es' => 'Eliminar copia local',
      'pt' => 'Excluir cópia offline',
      'it' => 'Elimina copia offline',
      'id' => 'Hapus Salinan Offline',
      'ja' => 'オフラインコピーを削除',
      'ko' => '오프라인 복사본 삭제',
      'ru' => 'Удалить локальную копию',
      'ar' => 'حذف النسخة غير المتصلة',
      'hi' => 'ऑफ़लाइन प्रति हटाएं',
      'tr' => 'Çevrimdışı Kopyayı Sil',
      'vi' => 'Xóa bản sao ngoại tuyến',
      'th' => 'ลบสำเนาออฟไลน์',
      _ => 'Delete Offline Copy',
    };
  }

  String get nasDownloadSourceChangedMessage {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' =>
        loc.contains('Hant')
            ? '自此下載開始以來，遠端來源設定已變更。是否要從頭重新開始下載？'
            : '自此下载开始以来，远程源配置已发生更改。是否要从头重新开始下载？',
      'de' =>
        'Die Konfiguration der Remote-Quelle hat sich seit dem Start geändert. Möchten Sie den Download von vorne neu starten?',
      'fr' =>
        'La configuration de la source distante a changé depuis le lancement du téléchargement. Voulez-vous recommencer depuis le début ?',
      'es' =>
        'La configuración del origen remoto ha cambiado desde que se inició la descarga. ¿Desea reiniciar la descarga desde el principio?',
      'pt' =>
        'A configuração da origem remota mudou desde o início do download. Deseja reiniciar o download do início?',
      'it' =>
        'La configurazione della sorgente remota è cambiata dall\'avvio del download. Vuoi riavviare il download dall\'inizio?',
      'id' =>
        'Konfigurasi sumber jarak jauh telah berubah sejak unduhan dimulai. Apakah Anda ingin mengulang unduhan dari awal?',
      'ja' => 'ダウンロード開始後にリモートソースの設定が変更されました。最初から再ダウンロードしますか？',
      'ko' => '다운로드가 시작된 후 원격 소스 설정이 변경되었습니다. 처음부터 다시 다운로드하시겠습니까?',
      'ru' =>
        'Конфигурация удаленного источника изменилась с момента начала загрузки. Хотите перезапустить скачивание сначала?',
      'ar' =>
        'تغيرت إعدادات المصدر البعيد منذ بدء التنزيل. هل ترغب في إعادة التنزيل من البداية؟',
      'hi' =>
        'डाउनलोड शुरू होने के बाद से दूरस्थ स्रोत कॉन्फ़िगरेशन बदल गया है। क्या आप शुरुआत से दोबारा डाउनलोड करना चाहते हैं?',
      'tr' =>
        'İndirme başladığından bu yana uzak kaynak yapılandırması değişti. İndirmeyi baştan yeniden başlatmak ister misiniz?',
      'vi' =>
        'Cấu hình nguồn từ xa đã thay đổi kể từ khi quá trình tải về bắt đầu. Bạn có muốn bắt đầu lại từ đầu không?',
      'th' =>
        'การกำหนดค่าแหล่งที่มาระยะไกลมีการเปลี่ยนแปลงตั้งแต่เริ่มดาวน์โหลด คุณต้องการเริ่มดาวน์โหลดใหม่ตั้งแต่ต้นหรือไม่?',
      _ =>
        'The remote source configuration has changed since this download started. Would you like to restart the download from the beginning?',
    };
  }

  String get nasDownloadRestartFromScratch {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '從頭重新開始' : '从头重新开始',
      'de' => 'Von vorne neu starten',
      'fr' => 'Recommencer depuis le début',
      'es' => 'Reiniciar desde el principio',
      'pt' => 'Reiniciar do início',
      'it' => 'Riavvia dall\'inizio',
      'id' => 'Mulai Ulang dari Awal',
      'ja' => '最初から再開',
      'ko' => '처음부터 다시 시작',
      'ru' => 'Начать сначала',
      'ar' => 'إعادة البدء من البداية',
      'hi' => 'शुरुआत से पुनः प्रारंभ करें',
      'tr' => 'Baştan Yeniden Başlat',
      'vi' => 'Bắt đầu lại từ đầu',
      'th' => 'เริ่มใหม่ตั้งแต่ต้น',
      _ => 'Restart from Beginning',
    };
  }

  String get nasOpenInApp {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '於應用程式中開啟' : '在应用内打开',
      'de' => 'In der App öffnen',
      'fr' => 'Ouvrir dans l\'application',
      'es' => 'Abrir en la aplicación',
      'pt' => 'Abrir no aplicativo',
      'it' => 'Apri nell\'app',
      'id' => 'Buka di Aplikasi',
      'ja' => 'アプリ内で開く',
      'ko' => '앱에서 열기',
      'ru' => 'Открыть в приложении',
      'ar' => 'فتح في التطبيق',
      'hi' => 'ऐप में खोलें',
      'tr' => 'Uygulamada Aç',
      'vi' => 'Mở trong ứng dụng',
      'th' => 'เปิดในแอป',
      _ => 'Open in App',
    };
  }

  String get nasOpenSystem {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '使用系統開啟' : '使用系统打开',
      'de' => 'Mit System öffnen',
      'fr' => 'Ouvrir avec le système',
      'es' => 'Abrir con el sistema',
      'pt' => 'Abrir com o sistema',
      'it' => 'Apri con il sistema',
      'id' => 'Buka dengan Sistem',
      'ja' => 'システムで開く',
      'ko' => '시스템에서 열기',
      'ru' => 'Открыть через систему',
      'ar' => 'فتح باستخدام النظام',
      'hi' => 'सिस्टम के साथ खोलें',
      'tr' => 'Sistemle Aç',
      'vi' => 'Mở bằng hệ thống',
      'th' => 'เปิดด้วยระบบ',
      _ => 'Open with System',
    };
  }

  String get nasDownloadErrorSourceChanged {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '媒体源配置已更改',
      'de' => 'Quellkonfiguration geändert',
      'fr' => 'Configuration de la source modifiée',
      'es' => 'Configuración de origen modificada',
      'pt' => 'Configuração da origem alterada',
      'it' => 'Configurazione della sorgente modificata',
      'id' => 'Konfigurasi sumber berubah',
      'ja' => 'ソース設定が変更されました',
      'ko' => '소스 설정이 변경됨',
      'ru' => 'Конфигурация источника изменилась',
      'ar' => 'تغيرت إعدادات المصدر',
      'hi' => 'स्रोत कॉन्फ़िगरेशन बदला गया',
      'tr' => 'Kaynak yapılandırması değişti',
      'vi' => 'Cấu hình nguồn đã thay đổi',
      'th' => 'การกำหนดค่าแหล่งที่มาเปลี่ยนไป',
      _ => 'Source configuration changed',
    };
  }

  String get nasDownloadErrorOfflineFileInvalid {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '下载的文件损坏或不完整',
      'de' => 'Heruntergeladene Datei ist beschädigt oder unvollständig',
      'fr' => 'Le fichier téléchargé est corrompu ou incomplet',
      'es' => 'El archivo descargado está dañado o incompleto',
      'pt' => 'O arquivo baixado está corrompido ou incompleto',
      'it' => 'Il file scaricato è corrotto o incompleto',
      'id' => 'Berkas yang diunduh rusak atau tidak lengkap',
      'ja' => 'ダウンロードされたファイルが破損しているか不完全です',
      'ko' => '다운로드된 파일이 손상되었거나 완전하지 않습니다',
      'ru' => 'Скачанный файл поврежден или неполон',
      'ar' => 'الملف المحمّل تالف أو غير مكتمل',
      'hi' => 'डाउनलोड की गई फ़ाइल दूषित या अधूरी है',
      'tr' => 'İndirilen dosya bozuk veya eksik',
      'vi' => 'Tệp đã tải về bị hỏng hoặc không hoàn chỉnh',
      'th' => 'ไฟล์ที่ดาวน์โหลดเสียหายหรือไม่สมบูรณ์',
      _ => 'Downloaded file is corrupted or incomplete',
    };
  }

  String get nasDownloadErrorStorageFailed {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '写入下载存储失败',
      'de' => 'Speichern auf Datenträger fehlgeschlagen',
      'fr' => 'Échec de l\'écriture sur le stockage',
      'es' => 'Error al escribir la descarga en el almacenamiento',
      'pt' => 'Falha ao gravar no armazenamento',
      'it' => 'Scrittura su disco non riuscita',
      'id' => 'Gagal menulis ke penyimpanan',
      'ja' => 'ストレージへの保存に失敗しました',
      'ko' => '스토리지 저장 실패',
      'ru' => 'Ошибка записи файла в хранилище',
      'ar' => 'فشلت الكتابة إلى وحدة التخزين',
      'hi' => 'स्टोरेज में लिखने में विफल',
      'tr' => 'Depolamaya yazma başarısız oldu',
      'vi' => 'Ghi vào bộ nhớ thất bại',
      'th' => 'บันทึกลงพื้นที่จัดเก็บข้อมูลไม่สำเร็จ',
      _ => 'Failed to write download to storage',
    };
  }

  String get nasDownloadErrorHlsUnsupported {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '流式切片不支持离线下载',
      'de' => 'Offline-Download für Streaming-Streams nicht unterstützt',
      'fr' => 'Téléchargement hors-ligne non pris en charge pour ce flux',
      'es' =>
        'La descarga sin conexión no es compatible con flujos de transmisión',
      'pt' => 'Download offline não é suportado para transmissões contínuas',
      'it' => 'Download offline non supportato per flussi in streaming',
      'id' => 'Unduhan offline tidak didukung untuk streaming',
      'ja' => 'ストリーミング配信のオフライン保存には非対応です',
      'ko' => '스트리밍 포맷은 오프라인 다운로드를 지원하지 않습니다',
      'ru' => 'Офлайн-загрузка потоковых трансляций не поддерживается',
      'ar' => 'التنزيل في وضع عدم الاتصال غير مدعوم لتدفقات البث',
      'hi' => 'स्ट्रीमिंग धाराओं के लिए ऑफ़लाइन डाउनलोड समर्थित नहीं है',
      'tr' => 'Akış formatları için çevrimdışı indirme desteklenmiyor',
      'vi' => 'Không hỗ trợ tải ngoại tuyến đối với luồng phát trực tiếp',
      'th' => 'ไม่รองรับการดาวน์โหลดออฟไลน์สำหรับสตรีมแบบแบ่งส่วน',
      _ => 'Offline download is not supported for streaming streams',
    };
  }

  String get nasDownloadErrorPathInvalid {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => '下载存储路径无效',
      'de' => 'Download-Speicherpfad ist ungültig',
      'fr' => 'Chemin de stockage du téléchargement non valide',
      'es' => 'La ruta de almacenamiento de la descarga no es válida',
      'pt' => 'Caminho de armazenamento do download inválido',
      'it' => 'Percorso di salvataggio del download non valido',
      'id' => 'Jalur penyimpanan unduhan tidak valid',
      'ja' => 'ダウンロード保存先パスが無効です',
      'ko' => '다운로드 저장 경로가 유효하지 않습니다',
      'ru' => 'Недопустимый путь сохранения загрузки',
      'ar' => 'مسار حفظ التنزيل غير صالح',
      'hi' => 'डाउनलोड भंडारण पथ अमान्य है',
      'tr' => 'İndirme depolama yolu geçersiz',
      'vi' => 'Đường dẫn lưu trữ tải về không hợp lệ',
      'th' => 'เส้นทางจัดเก็บข้อมูลดาวน์โหลดไม่ถูกต้อง',
      _ => 'Download storage path is invalid',
    };
  }

  String get nasDownloadErrorTargetExists => _loc.sftpUploadTargetExists;

  String get nasDownloadErrorIncomplete => _loc.sftpDownloadIncomplete;

  String get nasDownloadErrorQueueFull {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '下載隊列已滿' : '下载队列已满',
      'de' => 'Download-Warteschlange ist voll',
      'fr' => 'File de téléchargement pleine',
      'es' => 'La cola de descargas está llena',
      'pt' => 'Fila de download cheia',
      'it' => 'Coda di download piena',
      'id' => 'Antrean unduhan penuh',
      'ja' => 'ダウンロードキューが一杯です',
      'ko' => '다운로드 대기열이 가득 찼습니다',
      'ru' => 'Очередь загрузок заполнена',
      'ar' => 'قائمة انتظار التنزيل ممتلئة',
      'hi' => 'डाउनलोड कतार भरी हुई है',
      'tr' => 'İndirme kuyruğu dolu',
      'vi' => 'Hàng đợi tải xuống đã đầy',
      'th' => 'คิวดาวน์โหลดเต็มแล้ว',
      _ => 'Download queue is full',
    };
  }

  String get nasDownloadErrorNotComplete {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '下載尚未完成' : '下载尚未完成',
      'de' => 'Download noch nicht abgeschlossen',
      'fr' => 'Téléchargement non terminé',
      'es' => 'La descarga aún no ha terminado',
      'pt' => 'O download ainda não foi concluído',
      'it' => 'Download non ancora completato',
      'id' => 'Unduhan belum selesai',
      'ja' => 'ダウンロードがまだ完了していません',
      'ko' => '다운로드가 아직 완료되지 않았습니다',
      'ru' => 'Загрузка еще не завершена',
      'ar' => 'لم يكتمل التنزيل بعد',
      'hi' => 'डाउनलोड अभी पूरा नहीं हुआ है',
      'tr' => 'İndirme henüz tamamlanmadı',
      'vi' => 'Tải xuống chưa hoàn tất',
      'th' => 'การดาวน์โหลดยังไม่เสร็จสมบูรณ์',
      _ => 'Download has not finished yet',
    };
  }

  String get nasDownloadErrorServiceClosed {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '下載服務已關閉' : '下载服务已关闭',
      'de' => 'Download-Dienst wurde beendet',
      'fr' => 'Service de téléchargement fermé',
      'es' => 'El servicio de descargas está cerrado',
      'pt' => 'Serviço de download encerrado',
      'it' => 'Servizio di download chiuso',
      'id' => 'Layanan unduhan ditutup',
      'ja' => 'ダウンロードサービスは終了しました',
      'ko' => '다운로드 서비스가 종료되었습니다',
      'ru' => 'Служба загрузки остановлена',
      'ar' => 'خدمة التنزيل مغلقة',
      'hi' => 'डाउनलोड सेवा बंद है',
      'tr' => 'İndirme hizmeti kapalı',
      'vi' => 'Dịch vụ tải xuống đã đóng',
      'th' => 'บริการดาวน์โหลดปิดอยู่',
      _ => 'Download service is closed',
    };
  }

  String nasBrowserError(Object error) {
    final text = error.toString();
    const known = [
      'NAS_SOURCE_SAVE_INCOMPLETE',
      'NAS_SOURCE_NAME_REQUIRED',
      'NAS_INVALID_ENDPOINT',
      'NAS_AUTH_FAILED',
      'NAS_SSH_TUNNEL_FAILED',
      'NAS_BROWSE_UNAVAILABLE',
      'NAS_INVALID_DIRECTORY_ENTRY',
      'NAS_INVALID_LIBRARY_RESPONSE',
      'NAS_SCAN_FILTER_UNRESOLVED',
      'REMOTE_BROWSER_DISCONNECTED',
      'REMOTE_BROWSER_TARGET_CHANGED',
      'REMOTE_BROWSER_PATH_INVALID',
      'REMOTE_BROWSER_PATH_OUTSIDE_ROOT',
      'REMOTE_BROWSER_ENTRY_UNAVAILABLE',
      'NAS_INVALID_LIBRARY_ID',
      'NAS_SOURCE_UNREACHABLE',
    ];
    return known.any(text.contains)
        ? nasSanitizedError(error)
        : nasBrowseUnavailable;
  }

  String nasSanitizedError(dynamic error) {
    final str = error.toString();
    if (str.contains('NAS_SOURCE_NAME_REQUIRED')) return nasSourceNameRequired;
    if (str.contains('NAS_INVALID_ENDPOINT')) return nasInvalidEndpoint;
    if (str.contains('NAS_AUTH_FAILED')) return nasAuthFailed;
    if (str.contains('NAS_SSH_TUNNEL_FAILED')) return nasSshTunnelFailed;
    if (str.contains('NAS_EXTERNAL_OPEN_FAILED')) return nasExternalOpenFailed;
    if (str.contains('NAS_BROWSE_UNAVAILABLE')) return nasBrowseUnavailable;
    if (str.contains('NAS_INVALID_DIRECTORY_ENTRY')) {
      return nasInvalidDirectoryEntry;
    }
    if (str.contains('NAS_INVALID_LIBRARY_RESPONSE')) {
      return nasInvalidLibraryResponse;
    }
    if (str.contains('NAS_SCAN_FILTER_UNRESOLVED')) {
      return nasScanFilterUnresolved;
    }
    if (str.contains('NAS_SOURCE_SAVE_INCOMPLETE')) {
      return nasSourceSaveIncomplete;
    }
    if (str.contains('REMOTE_BROWSER_DISCONNECTED')) {
      return _loc.remoteBrowserDisconnected;
    }
    if (str.contains('REMOTE_BROWSER_TARGET_CHANGED')) {
      return _loc.remoteBrowserTargetChanged;
    }
    if (str.contains('REMOTE_BROWSER_PATH_INVALID')) {
      return _loc.remoteBrowserPathInvalid;
    }
    if (str.contains('REMOTE_BROWSER_PATH_OUTSIDE_ROOT')) {
      return _loc.remoteBrowserPathOutsideRoot;
    }
    if (str.contains('REMOTE_BROWSER_ENTRY_UNAVAILABLE')) {
      return _loc.remoteBrowserEntryUnavailable;
    }
    if (str.contains('NAS_INVALID_LIBRARY_ID')) return nasInvalidLibraryId;
    if (str.contains('NAS_INSTALL_BUSY')) return nasInstallBlockerBusy;
    if (str.contains('NAS_INSTALL_STATE_SAVE_FAILED')) {
      return nasInstallBlockerStateSaveFailed;
    }
    if (str.contains('NAS_INSTALL_COMMAND_RESULT_UNKNOWN')) {
      return nasInstallBlockerCommandResultUnknown;
    }
    if (str.contains('NAS_INSTALL_PREFLIGHT_FAILED')) {
      return nasInstallBlockerPreflightFailed;
    }
    if (str.contains('NAS_DOWNLOAD_SOURCE_CHANGED')) {
      return nasDownloadErrorSourceChanged;
    }
    if (str.contains('NAS_OFFLINE_FILE_INVALID')) {
      return nasDownloadErrorOfflineFileInvalid;
    }
    if (str.contains('NAS_DOWNLOAD_STORAGE_FAILED')) {
      return nasDownloadErrorStorageFailed;
    }
    if (str.contains('NAS_OFFLINE_HLS_UNSUPPORTED')) {
      return nasDownloadErrorHlsUnsupported;
    }
    if (str.contains('NAS_DOWNLOAD_PATH_INVALID')) {
      return nasDownloadErrorPathInvalid;
    }
    if (str.contains('NAS_DOWNLOAD_TARGET_EXISTS')) {
      return nasDownloadErrorTargetExists;
    }
    if (str.contains('NAS_DOWNLOAD_QUEUE_FULL')) {
      return nasDownloadErrorQueueFull;
    }
    if (str.contains('NAS_DOWNLOAD_SERVICE_CLOSED')) {
      return nasDownloadErrorServiceClosed;
    }
    if (str.contains('NAS_DOWNLOAD_NOT_COMPLETE')) {
      return nasDownloadErrorNotComplete;
    }
    if (str.contains('NAS_INCOMPLETE_DOWNLOAD')) {
      return nasDownloadErrorIncomplete;
    }
    if (str.contains('NAS_DOWNLOAD_FAILED')) {
      return nasDownloadFailed;
    }
    if (str.contains('NAS_SOURCE_UNREACHABLE') ||
        str.contains('SocketException') ||
        str.contains('Connection refused')) {
      return nasSourceUnreachable;
    }
    return str
        .replaceAll(RegExp(r':[^@/]+@'), ':***@')
        .replaceAll(RegExp(r'token=[^&\s]+'), 'token=***');
  }

  String get nasAddToPlaylist {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '加入播放清單' : '加入播放列表',
      'de' => 'Zur Wiedergabeliste hinzufügen',
      'fr' => 'Ajouter à la playlist',
      'es' => 'Añadir a la lista de reproducción',
      'pt' => 'Adicionar à playlist',
      'it' => 'Aggiungi alla playlist',
      'id' => 'Tambahkan ke Daftar Putar',
      'ja' => 'プレイリストに追加',
      'ko' => '재생목록에 추가',
      'ru' => 'Добавить в плейлист',
      'ar' => 'إضافة إلى قائمة التشغيل',
      'hi' => 'प्लेलिस्ट में जोड़ें',
      'tr' => 'Çalma Listesine Ekle',
      'vi' => 'Thêm vào danh sách phát',
      'th' => 'เพิ่มในเพลย์ลิสต์',
      _ => 'Add to Playlist',
    };
  }

  String get nasDownloadResume => _loc.transferResume;

  String get nasSort {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '排序' : '排序',
      'de' => 'Sortieren',
      'fr' => 'Trier',
      'es' => 'Ordenar',
      'pt' => 'Ordenar',
      'it' => 'Ordina',
      'id' => 'Urutkan',
      'ja' => '並び替え',
      'ko' => '정렬',
      'ru' => 'Сортировка',
      'ar' => 'ترتيب',
      'hi' => 'क्रमबद्ध करें',
      'tr' => 'Sırala',
      'vi' => 'Sắp xếp',
      'th' => 'เรียงลำดับ',
      _ => 'Sort',
    };
  }

  String get nasSortModified {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '修改日期' : '修改时间',
      'de' => 'Änderungsdatum',
      'fr' => 'Date de modification',
      'es' => 'Fecha de modificación',
      'pt' => 'Data de modificação',
      'it' => 'Data di modifica',
      'id' => 'Waktu Dimodifikasi',
      'ja' => '更新日時',
      'ko' => '수정일',
      'ru' => 'Дата изменения',
      'ar' => 'تاريخ التعديل',
      'hi' => 'संशोधन तिथि',
      'tr' => 'Değiştirilme Tarihi',
      'vi' => 'Ngày sửa đổi',
      'th' => 'วันที่แก้ไข',
      _ => 'Date Modified',
    };
  }

  String get nasSortName {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '名稱' : '名称',
      'de' => 'Name',
      'fr' => 'Nom',
      'es' => 'Nombre',
      'pt' => 'Nome',
      'it' => 'Nome',
      'id' => 'Nama',
      'ja' => '名前',
      'ko' => '이름',
      'ru' => 'Имя',
      'ar' => 'الاسم',
      'hi' => 'नाम',
      'tr' => 'Ad',
      'vi' => 'Tên',
      'th' => 'ชื่อ',
      _ => 'Name',
    };
  }

  String get nasSortSize {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '檔案大小' : '文件大小',
      'de' => 'Größe',
      'fr' => 'Taille',
      'es' => 'Tamaño',
      'pt' => 'Tamanho',
      'it' => 'Dimensione',
      'id' => 'Ukuran',
      'ja' => 'サイズ',
      'ko' => '크기',
      'ru' => 'Размер',
      'ar' => 'الحجم',
      'hi' => 'आकार',
      'tr' => 'Boyut',
      'vi' => 'Kích thước',
      'th' => 'ขนาด',
      _ => 'Size',
    };
  }

  String get nasSortAscending {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '遞增' : '升序',
      'de' => 'Aufsteigend',
      'fr' => 'Croissant',
      'es' => 'Ascendente',
      'pt' => 'Crescente',
      'it' => 'Crescente',
      'id' => 'Menaik',
      'ja' => '昇順',
      'ko' => '오름차순',
      'ru' => 'По возрастанию',
      'ar' => 'تصاعدي',
      'hi' => 'आरोही',
      'tr' => 'Artan',
      'vi' => 'Tăng dần',
      'th' => 'จากน้อยไปมาก',
      _ => 'Ascending',
    };
  }

  String get nasSortDescending {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '遞減' : '降序',
      'de' => 'Absteigend',
      'fr' => 'Décroissant',
      'es' => 'Descendente',
      'pt' => 'Decrescente',
      'it' => 'Decrescente',
      'id' => 'Menurun',
      'ja' => '降順',
      'ko' => '내림차순',
      'ru' => 'По убыванию',
      'ar' => 'تنازلي',
      'hi' => 'अवरोही',
      'tr' => 'Azalan',
      'vi' => 'Giảm dần',
      'th' => 'จากมากไปน้อย',
      _ => 'Descending',
    };
  }

  String get nasSelectMode {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '多選' : '多选',
      'de' => 'Auswählen',
      'fr' => 'Sélectionner',
      'es' => 'Seleccionar',
      'pt' => 'Selecionar',
      'it' => 'Seleziona',
      'id' => 'Pilih',
      'ja' => '選択',
      'ko' => '선택',
      'ru' => 'Выбрать',
      'ar' => 'تحديد',
      'hi' => 'चुनें',
      'tr' => 'Seç',
      'vi' => 'Chọn',
      'th' => 'เลือก',
      _ => 'Select',
    };
  }

  String get nasSelectAll {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '全選' : '全选',
      'de' => 'Alle auswählen',
      'fr' => 'Tout sélectionner',
      'es' => 'Seleccionar todo',
      'pt' => 'Selecionar tudo',
      'it' => 'Seleziona tutto',
      'id' => 'Pilih Semua',
      'ja' => 'すべて選択',
      'ko' => '전체 선택',
      'ru' => 'Выбрать все',
      'ar' => 'تحديد الكل',
      'hi' => 'सभी चुनें',
      'tr' => 'Tümünü Seç',
      'vi' => 'Chọn tất cả',
      'th' => 'เลือกทั้งหมด',
      _ => 'Select All',
    };
  }

  String nasSelectedCount(int count) {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '已選擇 $count 項' : '已选择 $count 项',
      'de' => '$count ausgewählt',
      'fr' => '$count sélectionné(s)',
      'es' => '$count seleccionado(s)',
      'pt' => '$count selecionado(s)',
      'it' => '$count selezionato/i',
      'id' => '$count dipilih',
      'ja' => '$count 件選択中',
      'ko' => '$count개 선택됨',
      'ru' => 'Выбрано: $count',
      'ar' => 'تم تحديد $count',
      'hi' => '$count चयनित',
      'tr' => '$count seçildi',
      'vi' => 'Đã chọn $count',
      'th' => 'เลือกแล้ว $count รายการ',
      _ => '$count selected',
    };
  }

  String get nasBatchUnfavorite {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '取消收藏' : '取消收藏',
      'de' => 'Aus Favoriten entfernen',
      'fr' => 'Retirer des favoris',
      'es' => 'Quitar de favoritos',
      'pt' => 'Remover dos favoritos',
      'it' => 'Rimuovi dai preferiti',
      'id' => 'Hapus dari Favorit',
      'ja' => 'お気に入り解除',
      'ko' => '즐겨찾기 해제',
      'ru' => 'Удалить из избранного',
      'ar' => 'إزالة من المفضلة',
      'hi' => 'पसंदीदा से हटाएं',
      'tr' => 'Favorilerden Çıkar',
      'vi' => 'Bỏ thích',
      'th' => 'ยกเลิกรายการโปรด',
      _ => 'Unfavorite',
    };
  }

  String nasBatchSummary(int succeeded, int failed) {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' =>
        loc.contains('Hant')
            ? '成功 $succeeded 項，失敗 $failed 項'
            : '成功 $succeeded 项，失败 $failed 项',
      'de' => '$succeeded erfolgreich, $failed fehlgeschlagen',
      'fr' => '$succeeded réussi(s), $failed échoué(s)',
      'es' => '$succeeded correcto(s), $failed fallido(s)',
      'pt' => '$succeeded concluído(s), $failed com falha',
      'it' => '$succeeded riuscito/i, $failed non riuscito/i',
      'id' => '$succeeded berhasil, $failed gagal',
      'ja' => '$succeeded 件成功、$failed 件失敗',
      'ko' => '$succeeded개 성공, $failed개 실패',
      'ru' => 'Успешно: $succeeded, Ошибок: $failed',
      'ar' => 'نجح $succeeded، فشل $failed',
      'hi' => '$succeeded सफल, $failed विफल',
      'tr' => '$succeeded başarılı, $failed başarısız',
      'vi' => '$succeeded thành công, $failed thất bại',
      'th' => 'สำเร็จ $succeeded, ล้มเหลว $failed',
      _ => '$succeeded succeeded, $failed failed',
    };
  }

  String get nasBatchRetryFailed {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '重試失敗項' : '重试失败项',
      'de' => 'Fehlgeschlagene wiederholen',
      'fr' => 'Réessayer les échecs',
      'es' => 'Reintentar fallidos',
      'pt' => 'Tentar novamente as falhas',
      'it' => 'Riprova non riusciti',
      'id' => 'Coba Lagi yang Gagal',
      'ja' => '失敗分を再試行',
      'ko' => '실패 항목 재시도',
      'ru' => 'Повторить неудачные',
      'ar' => 'إعادة محاولة الفاشلة',
      'hi' => 'विफल पुनः प्रयास करें',
      'tr' => 'Başarısızları Yeniden Dene',
      'vi' => 'Thử lại mục thất bại',
      'th' => 'ลองใหม่ที่ล้มเหลว',
      _ => 'Retry Failed',
    };
  }

  String get nasMediaDetails {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '媒體詳細資訊' : '媒体详情',
      'de' => 'Medien-Details',
      'fr' => 'Détails du média',
      'es' => 'Detalles del medio',
      'pt' => 'Detalhes da mídia',
      'it' => 'Dettagli multimediali',
      'id' => 'Detail Media',
      'ja' => 'メディア詳細',
      'ko' => '미디어 상세 정보',
      'ru' => 'Сведения о файле',
      'ar' => 'تفاصيل الوسائط',
      'hi' => 'मीडिया विवरण',
      'tr' => 'Medya Ayrıntıları',
      'vi' => 'Chi tiết phương tiện',
      'th' => 'รายละเอียดสื่อ',
      _ => 'Media Details',
    };
  }

  String get nasMediaResolution {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '解析度' : '分辨率',
      'de' => 'Auflösung',
      'fr' => 'Résolution',
      'es' => 'Resolución',
      'pt' => 'Resolução',
      'it' => 'Risoluzione',
      'id' => 'Resolusi',
      'ja' => '解像度',
      'ko' => '해상도',
      'ru' => 'Разрешение',
      'ar' => 'الدقة',
      'hi' => 'रिज़ॉल्यूशन',
      'tr' => 'Çözünürlük',
      'vi' => 'Độ phân giải',
      'th' => 'ความละเอียด',
      _ => 'Resolution',
    };
  }

  String get nasMediaDuration {
    final loc = _loc.localeName;
    return switch (loc.split('_').first) {
      'zh' => loc.contains('Hant') ? '長度' : '时长',
      'de' => 'Dauer',
      'fr' => 'Durée',
      'es' => 'Duración',
      'pt' => 'Duração',
      'it' => 'Durata',
      'id' => 'Durasi',
      'ja' => '長さ',
      'ko' => '재생 시간',
      'ru' => 'Длительность',
      'ar' => 'المدة',
      'hi' => 'अवधि',
      'tr' => 'Süre',
      'vi' => 'Thời lượng',
      'th' => 'ระยะเวลา',
      _ => 'Duration',
    };
  }
}
