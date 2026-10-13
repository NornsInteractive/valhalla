import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/application_center.dart';

String resolveAppCenterErrorMessage(
  BuildContext context,
  String code, [
  String? detail,
]) {
  final l10n = context.l10n;
  if (code.startsWith('APP_CENTER_TEMPLATE_UNSUPPORTED:')) {
    final feature = code.substring('APP_CENTER_TEMPLATE_UNSUPPORTED:'.length);
    return l10n.appCenterBlockerTemplateUnsupported(feature);
  }
  var actualCode = code;
  var actualDetail = detail;
  if (code.contains(':')) {
    final idx = code.indexOf(':');
    actualCode = code.substring(0, idx).trim();
    final extra = code.substring(idx + 1).trim();
    actualDetail = actualDetail != null && actualDetail.isNotEmpty
        ? '$actualDetail ($extra)'
        : extra;
  }
  if (actualCode.startsWith('APP_CENTER_CLEANUP_')) {
    final suffix = actualCode.substring('APP_CENTER_CLEANUP_'.length);
    return switch (suffix) {
      'CRITICAL_PATH' => l10n.appCenterCleanupCriticalPath,
      'PERMISSION_DENIED' => l10n.appCenterCleanupPermissionDenied,
      'VOLUME_DELETE_FAILED' => l10n.appCenterCleanupVolumeDeleteFailed,
      'PATH_INVALID' ||
      'PROTECTED_PATH' ||
      'SYMLINK_PATH' ||
      'MOUNTPOINT_PROTECTED' ||
      'SHARED_PATH' ||
      'OVERLAPPING_MOUNT' ||
      'NOT_DIRECTORY' ||
      'VOLUME_PROTECTED' ||
      'CLEANUP_LIMIT' ||
      'NOT_PREVIOUSLY_SELECTED' => l10n.appCenterCleanupProtected,
      'CAPABILITY_UNAVAILABLE' ||
      'INSPECTION_INCOMPLETE' => l10n.appCenterCleanupUnavailable,
      'CONFIG_CHANGED' ||
      'OWNERSHIP_CHANGED' ||
      'TARGET_CHANGED' ||
      'PATH_CHANGED' => l10n.appCenterCleanupChanged,
      'SELECTION_INVALID' ||
      'ACKNOWLEDGEMENT_REQUIRED' => l10n.appCenterCleanupConfirmationRequired,
      'RETRY_UNAVAILABLE' => l10n.appCenterCleanupRetryUnavailable,
      'ALREADY_ABSENT' => l10n.appCenterCleanupAlreadyAbsent,
      'DELETE_FAILED' => l10n.appCenterCleanupDeleteFailed,
      _ => l10n.appCenterCleanupUnconfirmed,
    };
  }
  if (actualCode == 'APP_CENTER_PATH_INVALID') {
    final fieldLabel = switch (actualDetail) {
      'dataRoot' => l10n.appCenterDataDirectory,
      'mountSource' => l10n.appCenterMountSource,
      'mountTarget' => l10n.appCenterMountTarget,
      _ => l10n.appCenterTaskDirectory,
    };
    return l10n.appCenterErrorPathInvalid(fieldLabel);
  }
  final base = switch (actualCode) {
    'APP_CENTER_NOT_CONNECTED' => l10n.appCenterErrorNotConnected,
    'APP_CENTER_ENVIRONMENT_REQUIRED' => l10n.appCenterErrorEnvironmentRequired,
    'APP_CENTER_PLAN_EXPIRED' => l10n.appCenterErrorPlanExpired,
    'APP_CENTER_TARGET_CHANGED' => l10n.appCenterErrorTargetChanged,
    'APP_CENTER_CONFIG_INVALID' => l10n.appCenterErrorConfigInvalid,
    'APP_CENTER_SOURCE_INVALID' => l10n.appCenterErrorSourceInvalid,
    'APP_CENTER_SOURCE_DNS' => context.appCenterSourceDnsLabel,
    'APP_CENTER_SOURCE_TIMEOUT' => context.appCenterSourceTimeoutLabel,
    'APP_CENTER_SOURCE_NETWORK' => context.appCenterSourceNetworkLabel,
    'APP_CENTER_SOURCE_TLS' => context.appCenterSourceTlsLabel,
    'APP_CENTER_SOURCE_UNAVAILABLE' => context.appCenterSourceUnavailableLabel,
    'APP_CENTER_NO_WEB_ENTRY' => l10n.appCenterErrorNoWebEntry,
    'APP_CENTER_HTTPS_DIRECT_REQUIRED' =>
      l10n.appCenterErrorHttpsDirectRequired,
    'APP_CENTER_OPEN_FAILED' => l10n.appCenterErrorOpenFailed,
    'APP_CENTER_LOCAL_DOCKER_REQUIRED' =>
      l10n.appCenterBlockerLocalDockerRequired,
    'APP_CENTER_TOOLS_REQUIRED' => l10n.appCenterBlockerToolsRequired,
    'APP_CENTER_LINUX_REQUIRED' => l10n.appCenterBlockerLinuxRequired,
    'APP_CENTER_DISK_CHECK_FAILED' => context.appCenterDiskCheckFailedLabel,
    'APP_CENTER_DISK_FULL' => context.appCenterDiskFullLabel,
    'APP_CENTER_CONTAINER_NAME_INVALID' => l10n.appCenterContainerNameInvalid,
    'NAS_BROWSE_UNAVAILABLE' => l10n.nasBrowseUnavailable,
    'NAS_INVALID_DIRECTORY_ENTRY' => l10n.nasInvalidDirectoryEntry,
    'NAS_INVALID_LIBRARY_RESPONSE' => l10n.nasInvalidLibraryResponse,
    'NAS_SCAN_FILTER_UNRESOLVED' => l10n.nasScanFilterUnresolved,
    'NAS_SOURCE_SAVE_INCOMPLETE' => l10n.nasSourceSaveIncomplete,
    'REMOTE_BROWSER_DISCONNECTED' => l10n.remoteBrowserDisconnected,
    'REMOTE_BROWSER_TARGET_CHANGED' => l10n.remoteBrowserTargetChanged,
    'REMOTE_BROWSER_PATH_INVALID' => l10n.remoteBrowserPathInvalid,
    'REMOTE_BROWSER_PATH_OUTSIDE_ROOT' => l10n.remoteBrowserPathOutsideRoot,
    'REMOTE_BROWSER_ENTRY_UNAVAILABLE' => l10n.remoteBrowserEntryUnavailable,
    _ => l10n.appCenterErrorGeneric(actualCode),
  };
  if (actualDetail != null && actualDetail.isNotEmpty) {
    return '$base: $actualDetail';
  }
  return base;
}

String resolveAppCenterBlockerMessage(BuildContext context, String blocker) {
  return resolveAppCenterErrorMessage(context, blocker);
}

String resolveApplicationOperationLabel(
  BuildContext context,
  ApplicationOperation op,
) {
  final l10n = context.l10n;
  return switch (op) {
    ApplicationOperation.install => l10n.appCenterInstall,
    ApplicationOperation.configure => l10n.appCenterConfig,
    ApplicationOperation.update => l10n.appCenterUpdate,
    ApplicationOperation.start => l10n.appCenterStart,
    ApplicationOperation.stop => l10n.appCenterStop,
    ApplicationOperation.restart => l10n.appCenterRestart,
    ApplicationOperation.uninstall => l10n.appCenterUninstall,
    ApplicationOperation.restore => l10n.appCenterRestore,
    ApplicationOperation.bootstrap => l10n.appCenterBootstrapButton,
  };
}

String resolveApplicationTaskStageLabel(
  BuildContext context,
  ApplicationTaskStage stage,
) {
  final l10n = context.l10n;
  return switch (stage) {
    ApplicationTaskStage.queued => l10n.appCenterTaskStageQueued,
    ApplicationTaskStage.preparing => l10n.appCenterTaskStagePreparing,
    ApplicationTaskStage.pulling => l10n.appCenterTaskStagePulling,
    ApplicationTaskStage.applying => l10n.appCenterTaskStageApplying,
    ApplicationTaskStage.checking => l10n.appCenterTaskStageChecking,
    ApplicationTaskStage.succeeded => l10n.appCenterTaskStageSucceeded,
    ApplicationTaskStage.failed => l10n.appCenterTaskStageFailed,
    ApplicationTaskStage.cancelled => l10n.appCenterTaskStageCancelled,
    ApplicationTaskStage.needsInspection =>
      l10n.appCenterTaskStageNeedsInspection,
  };
}

String resolveDeploymentStatusLabel(BuildContext context, String status) {
  return switch (status.toLowerCase()) {
    'running' => context.appCenterStatusRunningLabel,
    'stopped' => context.appCenterStatusStoppedLabel,
    'installing' => context.appCenterStatusInstallingLabel,
    _ => context.appCenterStatusUnknownLabel,
  };
}

String resolveServiceHealthLabel(BuildContext context, String health) {
  return switch (health.toLowerCase()) {
    'healthy' => context.appCenterHealthHealthyLabel,
    'unhealthy' => context.appCenterHealthUnhealthyLabel,
    'starting' => context.appCenterHealthStartingLabel,
    'none' => context.appCenterHealthNoCheckLabel,
    _ => health,
  };
}

extension AppCenterL10n on BuildContext {
  String get _loc => l10n.localeName.split('_').first;
  bool get _isHant => l10n.localeName.contains('Hant');

  String get appCenterDiskCheckFailedLabel => switch (_loc) {
    'zh' => _isHant ? '無法驗證伺服器上的可用磁碟空間' : '无法验证服务器上的可用磁盘空间',
    'de' =>
      'Verfügbarer Speicherplatz auf dem Server konnte nicht ermittelt werden',
    'fr' => 'Impossible de vérifier l\'espace disque disponible sur le serveur',
    'es' => 'No se pudo verificar el espacio disponible en disco del servidor',
    'pt' =>
      'Não foi possível verificar o espaço em disco disponível no servidor',
    'it' => 'Impossibile verificare lo spazio su disco disponibile sul server',
    'id' => 'Tidak dapat memverifikasi ruang disk yang tersedia di server',
    'ja' => 'サーバー上の空きディスク容量を確認できませんでした',
    'ko' => '서버의 사용 가능한 디스크 공간을 확인할 수 없습니다',
    'ru' => 'Не удалось проверить доступное дисковое пространство на сервере',
    'ar' => 'تعذر التحقق من المساحة المتوفرة على قرص الخادم',
    'hi' => 'सर्वर पर उपलब्ध डिस्क स्थान की पुष्टि नहीं की जा सकी',
    'tr' => 'Sunucudaki kullanılabilir disk alanı doğrulanamadı',
    'vi' => 'Không thể kiểm tra dung lượng ổ đĩa còn trống trên máy chủ',
    'th' => 'ไม่สามารถตรวจสอบพื้นที่ว่างในดิสก์บนเซิร์ฟเวอร์ได้',
    _ => 'Could not verify available disk space on server',
  };

  String get appCenterDiskFullLabel => switch (_loc) {
    'zh' => _isHant ? '伺服器磁碟已滿，無法繼續操作' : '服务器磁盘已满，无法继续操作',
    'de' => 'Serverspeicher ist voll; Vorgang kann nicht fortgesetzt werden',
    'fr' => 'Disque du serveur plein ; impossible de continuer',
    'es' => 'El disco del servidor está lleno; no se puede continuar',
    'pt' => 'O disco do servidor está cheio; não é possível prosseguir',
    'it' =>
      'Il disco del server è pieno; impossibile procedere con l\'operazione',
    'id' => 'Disk server penuh; tidak dapat melanjutkan operasi',
    'ja' => 'サーバーのディスク容量が一杯です。操作を続行できません',
    'ko' => '서버 디스크 공간이 부족하여 작업을 진행할 수 없습니다',
    'ru' => 'Диск сервера переполнен; невозможно продолжить операцию',
    'ar' => 'قرص الخادم ممتلئ؛ لا يمكن متابعة العملية',
    'hi' => 'सर्वर डिस्क पूरी भर गई है; संचालन जारी नहीं रखा जा सकता',
    'tr' => 'Sunucu diski dolu; işleme devam edilemiyor',
    'vi' => 'Ổ đĩa máy chủ đã đầy; không thể tiếp tục thao tác',
    'th' => 'ดิสก์ของเซิร์ฟเวอร์เต็ม ไม่สามารถดำเนินการต่อได้',
    _ => 'Server disk is full; cannot proceed with operation',
  };

  String get appCenterHealthInvalidLabel => switch (_loc) {
    'zh' => _isHant ? '容器健康狀態檢查失敗或回報無效狀態' : '容器健康检查失败或报告无效状态',
    'de' =>
      'Container-Integritätsprüfung fehlgeschlagen oder ungültiger Zustand gemeldet',
    'fr' => 'Vérification de santé du conteneur échouée ou état invalide',
    'es' =>
      'La comprobación de salud del contenedor falló o reportó un estado no válido',
    'pt' =>
      'Verificação de saúde do contêiner falhou ou reportou estado inválido',
    'it' => 'Controllo dello stato del container fallito o stato non valido',
    'id' =>
      'Pemeriksaan kesehatan kontainer gagal atau melaporkan status tidak valid',
    'ja' => 'コンテナのヘルスチェックに失敗したか、無効な状態が報告されました',
    'ko' => '컨테이너 상태 검사에 실패했거나 잘못된 상태가 보고되었습니다',
    'ru' =>
      'Проверка состояния контейнера не пройдена или возвращено недопустимое состояние',
    'ar' => 'فشل فحص صحة الحاوية أو تم الإبلاغ عن حالة غير صالحة',
    'hi' => 'कंटेनर स्वास्थ्य जांच विफल रही या अमान्य स्थिति रिपोर्ट की गई',
    'tr' =>
      'Kapsayıcı sağlık denetimi başarısız oldu veya geçersiz durum bildirildi',
    'vi' =>
      'Kiểm tra tình trạng vùng chứa thất bại hoặc báo cáo trạng thái không hợp lệ',
    'th' => 'การตรวจสอบสถานะคอนเทนเนอร์ล้มเหลวหรือรายงานสถานะไม่ถูกต้อง',
    _ => 'Container healthcheck failed or reported invalid state',
  };

  String get appCenterPreflightSummaryLabel => switch (_loc) {
    'zh' => _isHant ? '預檢摘要' : '预检摘要',
    'de' => 'Vorabprüfungs-Übersicht',
    'fr' => 'Résumé des vérifications préalables',
    'es' => 'Resumen de comprobación previa',
    'pt' => 'Resumo da verificação prévia',
    'it' => 'Riepilogo verifica preliminare',
    'id' => 'Ringkasan Pra-Pemeriksaan',
    'ja' => '事前チェック概要',
    'ko' => '사전 점검 요약',
    'ru' => 'Сводка предварительной проверки',
    'ar' => 'ملخص الفحص الأولي',
    'hi' => 'पूर्व-जांच सारांश',
    'tr' => 'Ön Denetim Özeti',
    'vi' => 'Tóm tắt kiểm tra sơ bộ',
    'th' => 'สรุปการตรวจสอบเบื้องต้น',
    _ => 'Preflight Summary',
  };

  String get appCenterMeasuredAvailableSpaceLabel => switch (_loc) {
    'zh' => _isHant ? '實測可用磁碟空間' : '实测可用磁盘空间',
    'de' => 'Gemessener freier Speicherplatz',
    'fr' => 'Espace disque disponible mesuré',
    'es' => 'Espacio en disco medido disponible',
    'pt' => 'Espaço em disco medido disponível',
    'it' => 'Spazio su disco disponibile misurato',
    'id' => 'Ruang Disk Tersedia Terukur',
    'ja' => '計測された空き容量',
    'ko' => '측정된 디스크 여유 공간',
    'ru' => 'Измеренное свободное место',
    'ar' => 'المساحة المتاحة المقاسة على القرص',
    'hi' => 'मापा गया उपलब्ध डिस्क स्थान',
    'tr' => 'Ölçülen Kullanılabilir Disk Alanı',
    'vi' => 'Dung lượng đĩa trống đo được',
    'th' => 'พื้นที่ว่างในดิสก์ที่วัดได้',
    _ => 'Available Disk Space',
  };

  String get appCenterUpdateComparisonLabel => switch (_loc) {
    'zh' => _isHant ? '更新差異比較' : '更新对比',
    'de' => 'Update-Vergleich',
    'fr' => 'Comparaison de mise à jour',
    'es' => 'Comparativa de actualización',
    'pt' => 'Comparação de atualização',
    'it' => 'Confronto aggiornamento',
    'id' => 'Perbandingan Pembaruan',
    'ja' => 'アップデート比較',
    'ko' => '업데이트 변경 사항 비교',
    'ru' => 'Сравнение обновления',
    'ar' => 'مقارنة التحديث',
    'hi' => 'अद्यतन तुलना',
    'tr' => 'Güncelleme Karşılaştırması',
    'vi' => 'So sánh bản cập nhật',
    'th' => 'การเปรียบเทียบการอัปเดต',
    _ => 'Update Comparison',
  };

  String get appCenterNoChangesDetectedLabel => switch (_loc) {
    'zh' => _isHant ? '未檢測到結構性變更' : '未检测到配置结构变动',
    'de' => 'Keine strukturellen Änderungen erkannt',
    'fr' => 'Aucun changement structurel détecté',
    'es' => 'No se detectaron cambios estructurales',
    'pt' => 'Nenhuma alteração estrutural detectada',
    'it' => 'Nessuna modifica strutturale rilevata',
    'id' => 'Tidak ada perubahan struktural yang terdeteksi',
    'ja' => '構造上の変更は検出されませんでした',
    'ko' => '구조적 변경 사항이 감지되지 않았습니다',
    'ru' => 'Структурных изменений не обнаружено',
    'ar' => 'لم يتم اكتشاف أي تغييرات هيكلية',
    'hi' => 'कोई संरचनात्मक परिवर्तन नहीं मिला',
    'tr' => 'Yapısal bir değişiklik algılanmadı',
    'vi' => 'Không phát hiện thay đổi cấu trúc nào',
    'th' => 'ตรวจไม่พบการเปลี่ยนแปลงโครงสร้าง',
    _ => 'No structural changes detected',
  };

  String resolveSectionLabel(String section) {
    switch (section) {
      case 'image':
        return switch (_loc) {
          'zh' => _isHant ? '容器映像檔' : '容器镜像',
          'de' => 'Container-Image',
          'fr' => 'Image de conteneur',
          'es' => 'Imagen de contenedor',
          'pt' => 'Imagem do contêiner',
          'it' => 'Immagine container',
          'id' => 'Gambar Kontainer',
          'ja' => 'コンテナイメージ',
          'ko' => '컨테이너 이미지',
          'ru' => 'Образ контейнера',
          'ar' => 'صورة الحاوية',
          'hi' => 'कंटेनर इमेज',
          'tr' => 'Kapsayıcı İmajı',
          'vi' => 'Ảnh vùng chứa',
          'th' => 'อิมเมจคอนเทนเนอร์',
          _ => 'Container Image',
        };
      case 'ports':
        return switch (_loc) {
          'zh' => _isHant ? '連接埠對應' : '端口映射',
          'de' => 'Port-Weiterleitungen',
          'fr' => 'Mappages de ports',
          'es' => 'Mapeo de puertos',
          'pt' => 'Mapeamentos de portas',
          'it' => 'Mappature porte',
          'id' => 'Pemetaan Port',
          'ja' => 'ポートマッピング',
          'ko' => '포트 매핑',
          'ru' => 'Сопоставление портов',
          'ar' => 'تعيين المنافذ',
          'hi' => 'पोर्ट मैपिंग',
          'tr' => 'Bağlantı Noktası Eşlemeleri',
          'vi' => 'Ánh xạ cổng',
          'th' => 'การแมปพอร์ต',
          _ => 'Port Mappings',
        };
      case 'volumes':
        return switch (_loc) {
          'zh' => _isHant ? '儲存空間掛載' : '存储挂载',
          'de' => 'Speicher-Mounts',
          'fr' => 'Points de montage',
          'es' => 'Puntos de montaje',
          'pt' => 'Montagens de armazenamento',
          'it' => 'Punti di montaggio',
          'id' => 'Pemasangan Penyimpanan',
          'ja' => 'ストレージマウント',
          'ko' => '스토리지 마운트',
          'ru' => 'Точки монтирования',
          'ar' => 'نقاط التثبيت',
          'hi' => 'स्टोरेज माउंट्स',
          'tr' => 'Depolama Bağlama Noktaları',
          'vi' => 'Điểm gắn kết lưu trữ',
          'th' => 'จุดเมานต์พื้นที่จัดเก็บ',
          _ => 'Storage Mounts',
        };
      case 'environment':
        return switch (_loc) {
          'zh' => _isHant ? '環境變數' : '环境变量',
          'de' => 'Umgebungsvariablen',
          'fr' => 'Variables d\'environnement',
          'es' => 'Variables de entorno',
          'pt' => 'Variáveis de ambiente',
          'it' => 'Variabili d\'ambiente',
          'id' => 'Variabel Lingkungan',
          'ja' => '環境変数',
          'ko' => '환경 변수',
          'ru' => 'Переменные окружения',
          'ar' => 'متغيرات البيئة',
          'hi' => 'पर्यावरण चर',
          'tr' => 'Ortam Değişkenleri',
          'vi' => 'Biến môi trường',
          'th' => 'ตัวแปรสภาพแวดล้อม',
          _ => 'Environment Variables',
        };
      case 'healthcheck':
        return switch (_loc) {
          'zh' => _isHant ? '健康狀態檢查' : '健康检查',
          'de' => 'Zustandsprüfung',
          'fr' => 'Contrôle de santé',
          'es' => 'Comprobación de salud',
          'pt' => 'Verificação de integridade',
          'it' => 'Controllo integrità',
          'id' => 'Pemeriksaan Kesehatan',
          'ja' => 'ヘルスチェック',
          'ko' => '상태 검사',
          'ru' => 'Проверка работоспособности',
          'ar' => 'فحص السلامة',
          'hi' => 'स्वास्थ्य जांच',
          'tr' => 'Sağlık Denetimi',
          'vi' => 'Kiểm tra tình trạng',
          'th' => 'การตรวจสุขภาพระบบ',
          _ => 'Health Check',
        };
      case 'restart':
        return switch (_loc) {
          'zh' => _isHant ? '重新啟動策略' : '重启策略',
          'de' => 'Neustart-Richtlinie',
          'fr' => 'Politique de redémarrage',
          'es' => 'Política de reinicio',
          'pt' => 'Política de reinicialização',
          'it' => 'Criterio di riavvio',
          'id' => 'Kebijakan Mulai Ulang',
          'ja' => '再起動ポリシー',
          'ko' => '재시작 정책',
          'ru' => 'Политика перезапуска',
          'ar' => 'سياسة إعادة التشغيل',
          'hi' => 'पुनः आरंभ नीति',
          'tr' => 'Yeniden Başlatma İlkesi',
          'vi' => 'Chính sách khởi động lại',
          'th' => 'นโยบายการรีสตาร์ต',
          _ => 'Restart Policy',
        };
      case 'services':
        return switch (_loc) {
          'zh' => _isHant ? '服務項目' : '多服务编排',
          'de' => 'Dienste',
          'fr' => 'Services',
          'es' => 'Servicios',
          'pt' => 'Serviços',
          'it' => 'Servizi',
          'id' => 'Layanan',
          'ja' => 'サービス一覧',
          'ko' => '서비스 목록',
          'ru' => 'Службы',
          'ar' => 'الخدمات',
          'hi' => 'सेवाएं',
          'tr' => 'Hizmetler',
          'vi' => 'Các dịch vụ',
          'th' => 'บริการต่างๆ',
          _ => 'Services',
        };
      default:
        return section;
    }
  }

  String get appCenterHealthHealthyLabel => switch (_loc) {
    'zh' => '健康',
    'de' => 'Fehlerfrei',
    'fr' => 'En bonne santé',
    'es' => 'Saludable',
    'pt' => 'Saudável',
    'it' => 'Sano',
    'id' => 'Sehat',
    'ja' => '正常',
    'ko' => '정상',
    'ru' => 'Исправен',
    'ar' => 'سليم',
    'hi' => 'स्वस्थ',
    'tr' => 'Sağlıklı',
    'vi' => 'Hoạt động tốt',
    'th' => 'สมบูรณ์',
    _ => 'Healthy',
  };

  String get appCenterHealthUnhealthyLabel => switch (_loc) {
    'zh' => '异常',
    'de' => 'Fehlerhaft',
    'fr' => 'Défaillant',
    'es' => 'No saludable',
    'pt' => 'Não saudável',
    'it' => 'Non integro',
    'id' => 'Tidak sehat',
    'ja' => '異常',
    'ko' => '비정상',
    'ru' => 'Неисправен',
    'ar' => 'غير سليم',
    'hi' => 'अस्वस्थ',
    'tr' => 'Sağlıksız',
    'vi' => 'Bất thường',
    'th' => 'ไม่สมบูรณ์',
    _ => 'Unhealthy',
  };

  String get appCenterHealthStartingLabel => switch (_loc) {
    'zh' => '启动中',
    'de' => 'Startet',
    'fr' => 'Démarrage',
    'es' => 'Iniciando',
    'pt' => 'Iniciando',
    'it' => 'In avvio',
    'id' => 'Memulai',
    'ja' => '起動中',
    'ko' => '시작 중',
    'ru' => 'Запуск',
    'ar' => 'قيد البدء',
    'hi' => 'आरंभ हो रहा है',
    'tr' => 'Başlatılıyor',
    'vi' => 'Đang khởi động',
    'th' => 'กำลังเริ่ม',
    _ => 'Starting',
  };

  String get appCenterHealthNoCheckLabel => switch (_loc) {
    'zh' => '无健康检查',
    'de' => 'Keine Prüfung',
    'fr' => 'Pas de contrôle',
    'es' => 'Sin comprobación',
    'pt' => 'Sem verificação',
    'it' => 'Nessun controllo',
    'id' => 'Tanpa pemeriksaan',
    'ja' => 'ヘルスチェックなし',
    'ko' => '상태 검사 없음',
    'ru' => 'Без проверки',
    'ar' => 'بدون فحص',
    'hi' => 'कोई जांच नहीं',
    'tr' => 'Denetim yok',
    'vi' => 'Không kiểm tra',
    'th' => 'ไม่มีการตรวจสอบ',
    _ => 'No check',
  };

  String get appCenterStatusRunningLabel => switch (_loc) {
    'zh' => '运行中',
    'de' => 'Läuft',
    'fr' => 'En cours d\'exécution',
    'es' => 'En ejecución',
    'pt' => 'Em execução',
    'it' => 'In esecuzione',
    'id' => 'Berjalan',
    'ja' => '実行中',
    'ko' => '실행 중',
    'ru' => 'Работает',
    'ar' => 'قيد التشغيل',
    'hi' => 'चल रहा है',
    'tr' => 'Çalışıyor',
    'vi' => 'Đang chạy',
    'th' => 'กำลังทำงาน',
    _ => 'Running',
  };

  String get appCenterStatusStoppedLabel => switch (_loc) {
    'zh' => '已停止',
    'de' => 'Gestoppt',
    'fr' => 'Arrêté',
    'es' => 'Detenido',
    'pt' => 'Parado',
    'it' => 'Arrestato',
    'id' => 'Berhenti',
    'ja' => '停止中',
    'ko' => '중지됨',
    'ru' => 'Остановлен',
    'ar' => 'متوقف',
    'hi' => 'रुक गया',
    'tr' => 'Durduruldu',
    'vi' => 'Đã dừng',
    'th' => 'หยุดแล้ว',
    _ => 'Stopped',
  };

  String get appCenterStatusInstallingLabel => switch (_loc) {
    'zh' => '安装中',
    'de' => 'Wird installiert',
    'fr' => 'Installation',
    'es' => 'Instalando',
    'pt' => 'Instalando',
    'it' => 'Installazione',
    'id' => 'Menginstal',
    'ja' => 'インストール中',
    'ko' => '설치 중',
    'ru' => 'Установка',
    'ar' => 'قيد التثبيت',
    'hi' => 'इंस्टॉल हो रहा है',
    'tr' => 'Yükleniyor',
    'vi' => 'Đang cài đặt',
    'th' => 'กำลังติดตั้ง',
    _ => 'Installing',
  };

  String get appCenterStatusUnknownLabel => switch (_loc) {
    'zh' => '未知',
    'de' => 'Unbekannt',
    'fr' => 'Inconnu',
    'es' => 'Desconocido',
    'pt' => 'Desconhecido',
    'it' => 'Sconosciuto',
    'id' => 'Tidak diketahui',
    'ja' => '不明',
    'ko' => '알 수 없음',
    'ru' => 'Неизвестно',
    'ar' => 'غير معروف',
    'hi' => 'अज्ञात',
    'tr' => 'Bilinmiyor',
    'vi' => 'Không xác định',
    'th' => 'ไม่ทราบ',
    _ => 'Unknown',
  };

  String get appCenterNoSourcesLabel => switch (_loc) {
    'zh' => _isHant ? '尚未啟用任何應用程式來源' : '尚未启用任何应用源',
    'de' => 'Keine Anwendungsquellen aktiviert',
    'fr' => 'Aucune source d\'application activée',
    'es' => 'No hay fuentes de aplicaciones habilitadas',
    'pt' => 'Nenhuma fonte de aplicativos ativada',
    'it' => 'Nessuna sorgente di applicazioni abilitata',
    'id' => 'Tidak ada sumber aplikasi yang diaktifkan',
    'ja' => '有効なアプリソースがありません',
    'ko' => '활성화된 앱 소스가 없습니다',
    'ru' => 'Нет включенных источников приложений',
    'ar' => 'لا توجد مصادر تطبيقات مفعلة',
    'hi' => 'कोई ऐप स्रोत सक्षम नहीं है',
    'tr' => 'Etkin uygulama kaynağı yok',
    'vi' => 'Chưa bật nguồn ứng dụng nào',
    'th' => 'ไม่มีแหล่งแอปพลิเคชันที่เปิดใช้งาน',
    _ => 'No application sources enabled',
  };

  String get appCenterNoMatchingAppsLabel => switch (_loc) {
    'zh' => _isHant ? '找不到符合搜尋或篩選條件的應用程式' : '未找到符合搜索或筛选条件的应用',
    'de' => 'Keine Anwendungen entsprechen der Suche oder den Filtern',
    'fr' => 'Aucune application ne correspond à votre recherche ou vos filtres',
    'es' => 'Ninguna aplicación coincide con la búsqueda o filtros',
    'pt' => 'Nenhum aplicativo corresponde à pesquisa ou filtros',
    'it' => 'Nessuna applicazione corrisponde alla ricerca o ai filtri',
    'id' => 'Tidak ada aplikasi yang cocok dengan pencarian atau filter',
    'ja' => '検索またはフィルタ条件に一致するアプリがありません',
    'ko' => '검색 또는 필터 조건과 일치하는 앱이 없습니다',
    'ru' => 'Нет приложений, соответствующих поиску или фильтрам',
    'ar' => 'لا توجد تطبيقات تطابق البحث أو الفلاتر',
    'hi' => 'खोज या फ़िल्टर से मेल खाने वाले कोई ऐप नहीं मिले',
    'tr' => 'Arama veya filtrelerle eşleşen uygulama yok',
    'vi' => 'Không có ứng dụng nào khớp với tìm kiếm hoặc bộ lọc',
    'th' => 'ไม่พบแอปพลิเคชันที่ตรงกับการค้นหาหรือตัวกรอง',
    _ => 'No applications match your search or filters',
  };

  String get appCenterClearFiltersLabel => switch (_loc) {
    'zh' => _isHant ? '清除篩選' : '清除筛选',
    'de' => 'Filter zurücksetzen',
    'fr' => 'Effacer les filtres',
    'es' => 'Borrar filtros',
    'pt' => 'Limpar filtros',
    'it' => 'Cancella filtri',
    'id' => 'Hapus Filter',
    'ja' => 'フィルターをクリア',
    'ko' => '필터 초기화',
    'ru' => 'Очистить фильтры',
    'ar' => 'مسح الفلاتر',
    'hi' => 'फ़िल्टर हटाएं',
    'tr' => 'Filtreleri Temizle',
    'vi' => 'Xóa bộ lọc',
    'th' => 'ล้างตัวกรอง',
    _ => 'Clear Filters',
  };

  String get appCenterSourceLoadFailedLabel => switch (_loc) {
    'zh' => _isHant ? '應用程式來源載入失敗' : '应用源加载失败',
    'de' => 'Laden der Anwendungsquelle fehlgeschlagen',
    'fr' => 'Échec du chargement de la source d\'applications',
    'es' => 'Error al cargar la fuente de aplicaciones',
    'pt' => 'Falha ao carregar fonte de aplicativos',
    'it' => 'Impossibile caricare la sorgente di applicazioni',
    'id' => 'Gagal memuat sumber aplikasi',
    'ja' => 'アプリソースの読み込みに失敗しました',
    'ko' => '앱 소스를 불러오지 못했습니다',
    'ru' => 'Не удалось загрузить источник приложений',
    'ar' => 'فشل تحميل مصدر التطبيقات',
    'hi' => 'ऐप स्रोत लोड करने में विफल',
    'tr' => 'Uygulama kaynağı yüklenemedi',
    'vi' => 'Tải nguồn ứng dụng thất bại',
    'th' => 'โหลดแหล่งแอปพลิเคชันไม่สำเร็จ',
    _ => 'Failed to load application source',
  };

  String get appCenterRetryLabel => switch (_loc) {
    'zh' => _isHant ? '重試' : '重试',
    'de' => 'Wiederholen',
    'fr' => 'Réessayer',
    'es' => 'Reintentar',
    'pt' => 'Tentar novamente',
    'it' => 'Riprova',
    'id' => 'Coba lagi',
    'ja' => '再試行',
    'ko' => '재시도',
    'ru' => 'Повторить',
    'ar' => 'إعادة المحاولة',
    'hi' => 'पुनः प्रयास करें',
    'tr' => 'Yeniden dene',
    'vi' => 'Thử lại',
    'th' => 'ลองใหม่',
    _ => 'Retry',
  };

  String get appCenterRecheckLabel => switch (_loc) {
    'zh' => _isHant ? '重新檢查' : '重新检查',
    'de' => 'Erneut prüfen',
    'fr' => 'Revérifier',
    'es' => 'Volver a comprobar',
    'pt' => 'Reverificar',
    'it' => 'Ricontrolla',
    'id' => 'Periksa Ulang',
    'ja' => '再チェック',
    'ko' => '다시 확인',
    'ru' => 'Перепроверить',
    'ar' => 'إعادة الفحص',
    'hi' => 'पुनः जांचें',
    'tr' => 'Yeniden Denetle',
    'vi' => 'Kiểm tra lại',
    'th' => 'ตรวจสอบอีกครั้ง',
    _ => 'Recheck',
  };

  String get appCenterRecheckTaskLabel => switch (_loc) {
    'zh' => _isHant ? '重新檢查任務狀態' : '重新检查任务状态',
    'de' => 'Aufgabenstatus erneut prüfen',
    'fr' => 'Revérifier le statut de la tâche',
    'es' => 'Volver a comprobar estado de la tarea',
    'pt' => 'Reverificar status da tarefa',
    'it' => 'Ricontrolla stato attività',
    'id' => 'Periksa Ulang Status Tugas',
    'ja' => 'タスク状態を再確認',
    'ko' => '작업 상태 다시 확인',
    'ru' => 'Перепроверить статус задачи',
    'ar' => 'إعادة فحص حالة المهمة',
    'hi' => 'कार्य स्थिति पुनः जांचें',
    'tr' => 'Görev Durumunu Yeniden Denetle',
    'vi' => 'Kiểm tra lại trạng thái tác vụ',
    'th' => 'ตรวจสอบสถานะงานอีกครั้ง',
    _ => 'Recheck Task Status',
  };

  String get appCenterTaskNeedsInspectionTitleLabel => switch (_loc) {
    'zh' => _isHant ? '任務狀態未確認' : '任务状态待确认',
    'de' => 'Aufgabenstatus unbestätigt',
    'fr' => 'Statut de tâche non confirmé',
    'es' => 'Estado de la tarea no confirmado',
    'pt' => 'Status da tarefa não confirmado',
    'it' => 'Stato dell\'attività non confermato',
    'id' => 'Status Tugas Belum Terkonfirmasi',
    'ja' => 'タスク結果が未確認です',
    'ko' => '작업 결과 미확인',
    'ru' => 'Статус задачи не подтвержден',
    'ar' => 'حالة المهمة غير مؤكدة',
    'hi' => 'कार्य स्थिति अपुष्ट है',
    'tr' => 'Görev Durumu Doğrulanmadı',
    'vi' => 'Chưa xác nhận trạng thái tác vụ',
    'th' => 'ยังไม่ยืนยันสถานะงาน',
    _ => 'Task outcome unknown',
  };

  String get appCenterTaskNeedsInspectionMessageLabel => switch (_loc) {
    'zh' =>
      _isHant
          ? '伺服器端任務執行結果未知（可能連線中斷或狀態未回報）。請重新檢查狀態或檢視日誌，切勿盲目重複執行。'
          : '服务器端任务执行结果未知（可能连接中断或状态未回传）。请重新检查状态或查看日志，切勿盲目重复执行。',
    'de' =>
      'Aufgabenergebnis auf dem Server ist unbekannt. Bitte Status prüfen oder Protokolle einsehen; Vorgang nicht blind wiederholen.',
    'fr' =>
      'Résultat de la tâche sur le serveur inconnu. Veuillez vérifier le statut ou consulter les journaux sans réexécuter aveuglément.',
    'es' =>
      'El resultado en el servidor es desconocido. Compruebe el estado o revise registros; no repita la operación a ciegas.',
    'pt' =>
      'Resultado da tarefa no servidor desconhecido. Verifique o status ou consulte logs antes de repetir a operação.',
    'it' =>
      'Esito attività sul server sconosciuto. Ricontrolla lo stato o esamina i log; non rieseguire ciecamente.',
    'id' =>
      'Hasil tugas di server tidak diketahui. Harap periksa ulang status atau lihat log; jangan mengulang operasi tanpa verifikasi.',
    'ja' => 'サーバーでのタスク結果が不明です。むやみに再実行せず、状態を再確認するかログを確認してください。',
    'ko' => '서버 작업 결과를 확인할 수 없습니다. 무작정 재실행하지 마시고 상태를 다시 확인하거나 로그를 점검하세요.',
    'ru' =>
      'Результат задачи на сервере неизвестен. Проверьте статус или просмотрите логи; не повторяйте операцию вслепую.',
    'ar' =>
      'نتيجة المهمة على الخادم غير معروفة. يرجى إعادة فحص الحالة أو مراجعة السجلات وتجنب إعادة التشغيل عشوائيًا.',
    'hi' =>
      'सर्वर पर कार्य का परिणाम अज्ञात है। कृपया पुनः जांचें या लॉग देखें; बिना सोचे-समझे दोबारा न चलाएं।',
    'tr' =>
      'Sunucudaki görev sonucu bilinmiyor. Lütfen durumu yeniden denetleyin veya günlükleri inceleyin; işlemi körü körüne tekrarlamayın.',
    'vi' =>
      'Kết quả tác vụ trên máy chủ không xác định. Vui lòng kiểm tra lại trạng thái hoặc xem nhật ký, không lặp lại thao tác tùy tiện.',
    'th' =>
      'ไม่ทราบผลลัพธ์ของงานบนเซิร์ฟเวอร์ โปรดตรวจสอบสถานะหรือดูบันทึก อย่ากดทำซ้ำโดยไม่ตรวจสอบ',
    _ =>
      'The task outcome on the server is unknown. Please recheck task status or inspect logs before retrying.',
  };

  String appCenterStopConfirmTitleLabel(String appName) => switch (_loc) {
    'zh' => '停止 $appName？',
    'de' => '$appName stoppen?',
    'fr' => 'Arrêter $appName ?',
    'es' => '¿Detener $appName?',
    'pt' => 'Parar $appName?',
    'it' => 'Arrestare $appName?',
    'id' => 'Hentikan $appName?',
    'ja' => '$appName を停止しますか？',
    'ko' => '$appName 중지하시겠습니까?',
    'ru' => 'Остановить $appName?',
    'ar' => 'إيقاف $appName؟',
    'hi' => 'क्या $appName को रोकें?',
    'tr' => '$appName durdurulsun mu?',
    'vi' => 'Dừng $appName?',
    'th' => 'หยุด $appName หรือไม่?',
    _ => 'Stop $appName?',
  };

  String appCenterStopConfirmMessageLabel(
    String appName,
    String serverName,
  ) => switch (_loc) {
    'zh' => '确定要在服务器 $serverName 上停止 $appName 吗？所有运行中的容器将被终止。',
    'de' =>
      'Möchten Sie $appName auf Server $serverName wirklich stoppen? Laufende Container werden angehalten.',
    'fr' =>
      'Voulez-vous vraiment arrêter $appName sur le serveur $serverName ? Les conteneurs en cours seront arrêtés.',
    'es' =>
      '¿Seguro que deseas detener $appName en el servidor $serverName? Se detendrán los contenedores en ejecución.',
    'pt' =>
      'Tem certeza de que deseja parar $appName no servidor $serverName? Os contêineres em execução serão interrompidos.',
    'it' =>
      'Vuoi davvero arrestare $appName sul server $serverName? I container in esecuzione verranno arrestati.',
    'id' =>
      'Yakin ingin menghentikan $appName di server $serverName? Kontainer yang sedang berjalan akan dihentikan.',
    'ja' => 'サーバー $serverName 上の $appName を停止してもよろしいですか？実行中のコンテナが停止します。',
    'ko' => '서버 $serverName에서 $appName을(를) 중지하시겠습니까? 실행 중인 컨테이너가 중단됩니다.',
    'ru' =>
      'Вы уверены, что хотите остановить $appName на сервере $serverName? Работающие контейнеры будут остановлены.',
    'ar' =>
      'هل أنت متأكد من رغبتك في إيقاف $appName على الخادم $serverName؟ سيتم إيقاف الحاويات المشغلة.',
    'hi' =>
      'क्या आप वाकई सर्वर $serverName पर $appName को रोकना चाहते हैं? चल रहे कंटेनर बंद हो जाएंगे।',
    'tr' =>
      '$appName uygulamasını $serverName sunucusunda durdurmak istediğinize emin misiniz? Çalışan kapsayıcılar durdurulacaktır.',
    'vi' =>
      'Bạn có chắc chắn muốn dừng $appName trên máy chủ $serverName không? Các vùng chứa đang chạy sẽ bị dừng.',
    'th' =>
      'คุณแน่ใจหรือไม่ว่าต้องการหยุด $appName บนเซิร์ฟเวอร์ $serverName? คอนเทนเนอร์ที่กำลังทำงานจะถูกหยุด',
    _ =>
      'Are you sure you want to stop $appName on server $serverName? Running containers will be stopped.',
  };

  String appCenterRestartConfirmTitleLabel(String appName) => switch (_loc) {
    'zh' => '重启 $appName？',
    'de' => '$appName neu starten?',
    'fr' => 'Redémarrer $appName ?',
    'es' => '¿Reiniciar $appName?',
    'pt' => 'Reiniciar $appName?',
    'it' => 'Riavviare $appName?',
    'id' => 'Mulai ulang $appName?',
    'ja' => '$appName を再起動しますか？',
    'ko' => '$appName 다시 시작하시겠습니까?',
    'ru' => 'Перезапустить $appName?',
    'ar' => 'إعادة تشغيل $appName؟',
    'hi' => 'क्या $appName को पुनः आरंभ करें?',
    'tr' => '$appName yeniden başlatılsın mı?',
    'vi' => 'Khởi động lại $appName?',
    'th' => 'รีสตาร์ต $appName หรือไม่?',
    _ => 'Restart $appName?',
  };

  String appCenterRestartConfirmMessageLabel(
    String appName,
    String serverName,
  ) => switch (_loc) {
    'zh' => '确定要在服务器 $serverName 上重启 $appName 吗？',
    'de' => 'Möchten Sie $appName auf Server $serverName wirklich neu starten?',
    'fr' =>
      'Voulez-vous vraiment redémarrer $appName sur le serveur $serverName ?',
    'es' => '¿Seguro que deseas reiniciar $appName en el servidor $serverName?',
    'pt' =>
      'Tem certeza de que deseja reiniciar $appName no servidor $serverName?',
    'it' => 'Vuoi davvero riavviare $appName sul server $serverName?',
    'id' => 'Yakin ingin memulai ulang $appName di server $serverName?',
    'ja' => 'サーバー $serverName 上の $appName を再起動してもよろしいですか？',
    'ko' => '서버 $serverName에서 $appName을(를) 다시 시작하시겠습니까?',
    'ru' =>
      'Вы уверены, что хотите перезапустить $appName на сервере $serverName?',
    'ar' =>
      'هل أنت متأكد من رغبتك في إعادة تشغيل $appName على الخادم $serverName؟',
    'hi' =>
      'क्या आप वाकई सर्वर $serverName पर $appName को पुनः आरंभ करना चाहते हैं?',
    'tr' =>
      '$appName uygulamasını $serverName sunucusunda yeniden başlatmak istediğinize emin misiniz?',
    'vi' =>
      'Bạn có chắc chắn muốn khởi động lại $appName trên máy chủ $serverName không?',
    'th' =>
      'คุณแน่ใจหรือไม่ว่าต้องการรีสตาร์ต $appName บนเซิร์ฟเวอร์ $serverName?',
    _ => 'Are you sure you want to restart $appName on server $serverName?',
  };

  String get appCenterBrowseStoreLabel => switch (_loc) {
    'zh' => _isHant ? '前往應用商店瀏覽' : '浏览应用商店',
    'de' => 'App-Store durchsuchen',
    'fr' => 'Parcourir le Store',
    'es' => 'Explorar tienda',
    'pt' => 'Navegar na loja',
    'it' => 'Sfoglia App Store',
    'id' => 'Jelajahi Toko Aplikasi',
    'ja' => 'アプリストアを見る',
    'ko' => '앱 스토어 둘러보기',
    'ru' => 'Перейти в магазин',
    'ar' => 'تصفح المتجر',
    'hi' => 'ऐप स्टोर ब्राउज़ करें',
    'tr' => 'Mağazaya Göz At',
    'vi' => 'Duyệt cửa hàng',
    'th' => 'เลือกดูในร้านแอป',
    _ => 'Browse App Store',
  };

  String get appCenterViewTasksLabel => switch (_loc) {
    'zh' => _isHant ? '查看任務' : '查看任务',
    'de' => 'Aufgaben ansehen',
    'fr' => 'Voir les tâches',
    'es' => 'Ver tareas',
    'pt' => 'Ver tarefas',
    'it' => 'Visualizza attività',
    'id' => 'Lihat Tugas',
    'ja' => 'タスクを表示',
    'ko' => '작업 보기',
    'ru' => 'Просмотреть задачи',
    'ar' => 'عرض المهام',
    'hi' => 'कार्य देखें',
    'tr' => 'Görevleri Gör',
    'vi' => 'Xem tác vụ',
    'th' => 'ดูงาน',
    _ => 'View Tasks',
  };

  String get appCenterViewInstalledLabel => switch (_loc) {
    'zh' => _isHant ? '查看已安裝應用' : '查看已安装应用',
    'de' => 'Installierte App ansehen',
    'fr' => 'Voir l\'application installée',
    'es' => 'Ver aplicación instalada',
    'pt' => 'Ver aplicativo instalado',
    'it' => 'Visualizza app installata',
    'id' => 'Lihat Aplikasi Terinstal',
    'ja' => 'インストール済みアプリを表示',
    'ko' => '설치된 앱 보기',
    'ru' => 'Просмотреть установленное приложение',
    'ar' => 'عرض التطبيق المثبت',
    'hi' => 'इंस्टॉल किए गए ऐप देखें',
    'tr' => 'Yüklü Uygulamayı Gör',
    'vi' => 'Xem ứng dụng đã cài',
    'th' => 'ดูแอปที่ติดตั้งแล้ว',
    _ => 'View Installed App',
  };

  String get appCenterRunInBackgroundLabel => switch (_loc) {
    'zh' => _isHant ? '後台運行' : '后台运行',
    'de' => 'Im Hintergrund ausführen',
    'fr' => 'Exécuter en arrière-plan',
    'es' => 'Ejecutar en segundo plano',
    'pt' => 'Executar em segundo plano',
    'it' => 'Esegui in background',
    'id' => 'Jalankan di Latar Belakang',
    'ja' => 'バックグラウンドで実行',
    'ko' => '백그라운드에서 실행',
    'ru' => 'Выполнять в фоне',
    'ar' => 'تشغيل في الخلفية',
    'hi' => 'पृष्ठभूमि में चलाएं',
    'tr' => 'Arka Planda Çalıştır',
    'vi' => 'Chạy dưới nền',
    'th' => 'ทำงานในเบื้องหลัง',
    _ => 'Run in Background',
  };

  String get appCenterTaskDetailsLabel => switch (_loc) {
    'zh' => _isHant ? '任務詳情' : '任务详情',
    'de' => 'Aufgabendetails',
    'fr' => 'Détails de la tâche',
    'es' => 'Detalles de la tarea',
    'pt' => 'Detalhes da tarefa',
    'it' => 'Dettagli attività',
    'id' => 'Detail Tugas',
    'ja' => 'タスク詳細',
    'ko' => '작업 상세 정보',
    'ru' => 'Подробности задачи',
    'ar' => 'تفاصيل المهمة',
    'hi' => 'कार्य विवरण',
    'tr' => 'Görev Ayrıntıları',
    'vi' => 'Chi tiết tác vụ',
    'th' => 'รายละเอียดงาน',
    _ => 'Task Details',
  };

  String get appCenterTaskTargetLabel => switch (_loc) {
    'zh' => '目标',
    'de' => 'Ziel',
    'fr' => 'Cible',
    'es' => 'Objetivo',
    'pt' => 'Alvo',
    'it' => 'Destinazione',
    'id' => 'Target',
    'ja' => '対象',
    'ko' => '대상',
    'ru' => 'Цель',
    'ar' => 'الهدف',
    'hi' => 'लक्ष्य',
    'tr' => 'Hedef',
    'vi' => 'Mục tiêu',
    'th' => 'เป้าหมาย',
    _ => 'Target',
  };

  String get appCenterTaskDirectoryLabel => switch (_loc) {
    'zh' => '目录',
    'de' => 'Verzeichnis',
    'fr' => 'Répertoire',
    'es' => 'Directorio',
    'pt' => 'Diretório',
    'it' => 'Directory',
    'id' => 'Direktori',
    'ja' => 'ディレクトリ',
    'ko' => '디렉터리',
    'ru' => 'Каталог',
    'ar' => 'الدليل',
    'hi' => 'निर्देशिका',
    'tr' => 'Dizin',
    'vi' => 'Thư mục',
    'th' => 'ไดเรกทอรี',
    _ => 'Directory',
  };

  String get appCenterTaskCreatedAtLabel => switch (_loc) {
    'zh' => '创建时间',
    'de' => 'Erstellt am',
    'fr' => 'Créé le',
    'es' => 'Creado el',
    'pt' => 'Criado em',
    'it' => 'Creato il',
    'id' => 'Dibuat pada',
    'ja' => '作成日時',
    'ko' => '생성 일시',
    'ru' => 'Создано',
    'ar' => 'تاريخ الإنشاء',
    'hi' => 'बनाने का समय',
    'tr' => 'Oluşturulma Tarihi',
    'vi' => 'Thời gian tạo',
    'th' => 'สร้างเมื่อ',
    _ => 'Created At',
  };

  String appCenterTaskExitCodeLabel(int code) => switch (_loc) {
    'zh' => '退出代码: $code',
    'de' => 'Exit-Code: $code',
    'fr' => 'Code de sortie : $code',
    'es' => 'Código de salida: $code',
    'pt' => 'Código de saída: $code',
    'it' => 'Codice di uscita: $code',
    'id' => 'Kode keluar: $code',
    'ja' => '終了コード: $code',
    'ko' => '종료 코드: $code',
    'ru' => 'Код завершения: $code',
    'ar' => 'رمز الخروج: $code',
    'hi' => 'निकास कोड: $code',
    'tr' => 'Çıkış kodu: $code',
    'vi' => 'Mã thoát: $code',
    'th' => 'รหัสออก: $code',
    _ => 'Exit code: $code',
  };

  String get appCenterEnvReadyLabel => switch (_loc) {
    'zh' => 'Docker 与 Compose 运行环境就绪',
    'de' => 'Docker- & Compose-Umgebung bereit',
    'fr' => 'Environnement Docker et Compose prêt',
    'es' => 'Entorno Docker y Compose listo',
    'pt' => 'Ambiente Docker e Compose pronto',
    'it' => 'Ambiente Docker e Compose pronto',
    'id' => 'Lingkungan Docker & Compose Siap',
    'ja' => 'Docker & Compose 環境は準備完了です',
    'ko' => 'Docker 및 Compose 환경 준비됨',
    'ru' => 'Среда Docker и Compose готова',
    'ar' => 'بيئة Docker و Compose جاهزة',
    'hi' => 'Docker और Compose वातावरण तैयार है',
    'tr' => 'Docker ve Compose Ortamı Hazır',
    'vi' => 'Môi trường Docker & Compose đã sẵn sàng',
    'th' => 'สภาพแวดล้อม Docker และ Compose พร้อมแล้ว',
    _ => 'Docker & Compose Ready',
  };

  String get appCenterEnvNotReadyLabel => switch (_loc) {
    'zh' => 'Docker 环境未就绪',
    'de' => 'Docker-Umgebung nicht bereit',
    'fr' => 'Environnement Docker non prêt',
    'es' => 'Entorno Docker no preparado',
    'pt' => 'Ambiente Docker não está pronto',
    'it' => 'Ambiente Docker non pronto',
    'id' => 'Lingkungan Docker Belum Siap',
    'ja' => 'Docker 環境の準備ができていません',
    'ko' => 'Docker 환경이 준비되지 않았습니다',
    'ru' => 'Среда Docker не готова',
    'ar' => 'بيئة Docker غير جاهزة',
    'hi' => 'Docker वातावरण तैयार नहीं है',
    'tr' => 'Docker Ortamı Hazır Değil',
    'vi' => 'Môi trường Docker chưa sẵn sàng',
    'th' => 'สภาพแวดล้อม Docker ยังไม่พร้อม',
    _ => 'Docker Environment Not Ready',
  };

  String get appCenterEnvInspectingLabel => switch (_loc) {
    'zh' => '正在检测服务器 Docker 环境...',
    'de' => 'Docker-Umgebung wird geprüft...',
    'fr' => 'Vérification de l\'environnement Docker...',
    'es' => 'Comprobando entorno Docker...',
    'pt' => 'Verificando ambiente Docker...',
    'it' => 'Verifica ambiente Docker...',
    'id' => 'Memeriksa lingkungan Docker server...',
    'ja' => 'Docker 環境を検出中...',
    'ko' => 'Docker 환경 점검 중...',
    'ru' => 'Проверка среды Docker...',
    'ar' => 'جارٍ فحص بيئة Docker للخادم...',
    'hi' => 'Docker वातावरण की जांच की जा रही है...',
    'tr' => 'Docker ortamı denetleniyor...',
    'vi' => 'Đang kiểm tra môi trường Docker...',
    'th' => 'กำลังตรวจสอบสภาพแวดล้อม Docker...',
    _ => 'Inspecting Docker environment...',
  };

  String get appCenterSourceDnsLabel => switch (_loc) {
    'zh' => _isHant ? '應用程式來源 DNS 解析失敗' : '应用源 DNS 解析失败',
    'ja' => 'アプリソースの DNS 解決に失敗しました',
    'ko' => '앱 소스 DNS 확인에 실패했습니다',
    'de' => 'DNS-Auflösung für Anwendungsquelle fehlgeschlagen',
    'fr' => 'Échec de la résolution DNS de la source d\'applications',
    'es' => 'Falló la resolución DNS de la fuente de aplicaciones',
    'pt' => 'Falha na resolução DNS da fonte de aplicativos',
    'it' => 'Risoluzione DNS non riuscita per la sorgente di applicazioni',
    'ru' => 'Ошибка разрешения DNS для источника приложений',
    'ar' => 'فشل تحليل DNS لمصدر التطبيقات',
    'hi' => 'ऐप स्रोत के लिए DNS रिज़ॉल्यूशन विफल',
    'id' => 'Resolusi DNS gagal untuk sumber aplikasi',
    'tr' => 'Uygulama kaynağı için DNS çözümlemesi başarısız oldu',
    'vi' => 'Phân giải DNS thất bại cho nguồn ứng dụng',
    'th' => 'การแปลง DNS สำหรับแหล่งแอปพลิเคชันล้มเหลว',
    _ => 'DNS resolution failed for application source',
  };

  String get appCenterSourceTimeoutLabel => switch (_loc) {
    'zh' => _isHant ? '連線應用程式來源逾時' : '连接应用源超时',
    'ja' => 'アプリソースへの接続がタイムアウトしました',
    'ko' => '앱 소스 연결 시간이 초과되었습니다',
    'de' => 'Zeitüberschreitung beim Verbinden mit der Anwendungsquelle',
    'fr' => 'Délai d\'attente dépassé pour la source d\'applications',
    'es' =>
      'Tiempo de espera agotado al conectar con la fuente de aplicaciones',
    'pt' => 'Tempo limite esgotado ao conectar à fonte de aplicativos',
    'it' => 'Timeout di connessione alla sorgente di applicazioni',
    'ru' => 'Время ожидания подключения к источнику приложений истекло',
    'ar' => 'انتهت مهلة الاتصال بمصدر التطبيقات',
    'hi' => 'ऐप स्रोत से कनेक्ट करने का समय समाप्त हो गया',
    'id' => 'Batas waktu koneksi ke sumber aplikasi habis',
    'tr' => 'Uygulama kaynağına bağlanırken zaman aşımı oluştu',
    'vi' => 'Hết thời gian kết nối đến nguồn ứng dụng',
    'th' => 'หมดเวลาการเชื่อมต่อไปยังแหล่งแอปพลิเคชัน',
    _ => 'Connection timed out reaching application source',
  };

  String get appCenterSourceNetworkLabel => switch (_loc) {
    'zh' => _isHant ? '連線應用程式來源網路錯誤' : '连接应用源网络错误',
    'ja' => 'アプリソースへのネットワーク接続エラーです',
    'ko' => '앱 소스 네트워크 연결 오류입니다',
    'de' => 'Netzwerkfehler beim Erreichen der Anwendungsquelle',
    'fr' => 'Erreur de connexion réseau à la source d\'applications',
    'es' => 'Error de conexión de red con la fuente de aplicaciones',
    'pt' => 'Erro de conexão de rede com a fonte de aplicativos',
    'it' => 'Errore di connessione di rete alla sorgente di applicazioni',
    'ru' => 'Сетевая ошибка при подключении к источнику приложений',
    'ar' => 'خطأ في اتصال الشبكة بمصدر التطبيقات',
    'hi' => 'ऐप स्रोत से कनेक्ट करने में नेटवर्क त्रुटि',
    'id' => 'Kesalahan koneksi jaringan ke sumber aplikasi',
    'tr' => 'Uygulama kaynağına bağlanırken ağ hatası oluştu',
    'vi' => 'Lỗi kết nối mạng đến nguồn ứng dụng',
    'th' => 'เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่ายไปยังแหล่งแอปพลิเคชัน',
    _ => 'Network connection error reaching application source',
  };

  String get appCenterSourceTlsLabel => switch (_loc) {
    'zh' => _isHant ? '應用程式來源 TLS 安全連線失敗' : '应用源 TLS 安全连接失败',
    'ja' => 'アプリソースへの TLS セキュア接続に失敗しました',
    'ko' => '앱 소스에 대한 TLS 보안 연결에 실패했습니다',
    'de' => 'Sichere TLS-Verbindung zur Anwendungsquelle fehlgeschlagen',
    'fr' => 'Échec de la connexion sécurisée TLS à la source d\'applications',
    'es' => 'Falló la conexión segura TLS con la fuente de aplicaciones',
    'pt' => 'Falha na conexão segura TLS com a fonte de aplicativos',
    'it' => 'Connessione sicura TLS alla sorgente di applicazioni non riuscita',
    'ru' =>
      'Не удалось установить безопасное TLS-соединение с источником приложений',
    'ar' => 'فشل اتصال TLS الآمن بمصدر التطبيقات',
    'hi' => 'ऐप स्रोत से सुरक्षित TLS कनेक्शन विफल रहा',
    'id' => 'Koneksi aman TLS ke sumber aplikasi gagal',
    'tr' => 'Uygulama kaynağına güvenli TLS bağlantısı kurulamadı',
    'vi' => 'Kết nối an toàn TLS đến nguồn ứng dụng thất bại',
    'th' => 'การเชื่อมต่อ TLS ที่ปลอดภัยไปยังแหล่งแอปพลิเคชันล้มเหลว',
    _ => 'Secure TLS connection to application source failed',
  };

  String get appCenterSourceUnavailableLabel => switch (_loc) {
    'zh' => _isHant ? '應用程式來源暫時無法使用' : '应用源暂时不可用',
    'ja' => 'アプリソースは一時的に利用できません',
    'ko' => '앱 소스를 일시적으로 사용할 수 없습니다',
    'de' => 'Anwendungsquelle ist vorübergehend nicht verfügbar',
    'fr' => 'La source d\'applications est temporairement indisponible',
    'es' => 'La fuente de aplicaciones no está disponible temporalmente',
    'pt' => 'A fonte de aplicativos está temporariamente indisponível',
    'it' => 'La sorgente di applicazioni è temporaneamente non disponibile',
    'ru' => 'Источник приложений временно недоступен',
    'ar' => 'مصدر التطبيقات غير متاح مؤقتًا',
    'hi' => 'ऐप स्रोत अस्थायी रूप से अनुपलब्ध है',
    'id' => 'Sumber aplikasi sementara tidak tersedia',
    'tr' => 'Uygulama kaynağı geçici olarak kullanılamıyor',
    'vi' => 'Nguồn ứng dụng tạm thời không khả dụng',
    'th' => 'แหล่งแอปพลิเคชันไม่พร้อมใช้งานชั่วคราว',
    _ => 'Application source is temporarily unavailable',
  };

  String get appCenterCurrentCommandLabel => switch (_loc) {
    'zh' => _isHant ? '目前執行指令' : '当前执行命令',
    'ja' => '現在実行中のコマンド',
    'ko' => '현재 실행 명령',
    'de' => 'Aktueller Befehl',
    'fr' => 'Commande en cours',
    'es' => 'Comando actual',
    'pt' => 'Comando atual',
    'it' => 'Comando corrente',
    'ru' => 'Текущая команда',
    'ar' => 'الأمر الحالي',
    'hi' => 'वर्तमान कमांड',
    'id' => 'Perintah Saat Ini',
    'tr' => 'Geçerli Komut',
    'vi' => 'Lệnh hiện tại',
    'th' => 'คำสั่งปัจจุบัน',
    _ => 'Current Command',
  };

  String get appCenterFollowLatestLogsLabel => switch (_loc) {
    'zh' => _isHant ? '追蹤最新' : '跟踪最新',
    'ja' => '最新を追従',
    'ko' => '최신 로그 따라가기',
    'de' => 'Neuesten folgen',
    'fr' => 'Suivre le direct',
    'es' => 'Seguir en directo',
    'pt' => 'Acompanhar recente',
    'it' => 'Segui ultimi',
    'ru' => 'Следить за новыми',
    'ar' => 'متابعة الأحدث',
    'hi' => 'नवीनतम का अनुसरण करें',
    'id' => 'Ikuti terbaru',
    'tr' => 'En yeniyi takip et',
    'vi' => 'Theo dõi mới nhất',
    'th' => 'ติดตามล่าสุด',
    _ => 'Follow latest',
  };

  String get appCenterSyncUnavailableLabel => switch (_loc) {
    'zh' => _isHant ? '同步暫時無法使用' : '同步暂时不可用',
    'ja' => '同期は利用できません',
    'ko' => '동기화 일시 불가',
    'de' => 'Synchronisierung nicht verfügbar',
    'fr' => 'Synchronisation indisponible',
    'es' => 'Sincronización no disponible',
    'pt' => 'Sincronização indisponível',
    'it' => 'Sincronizzazione non disponibile',
    'ru' => 'Синхронизация недоступна',
    'ar' => 'المزامنة غير متاحة',
    'hi' => 'सिंक अनुपलब्ध',
    'id' => 'Sinkronisasi tidak tersedia',
    'tr' => 'Eşitleme kullanılamıyor',
    'vi' => 'Đồng bộ không khả dụng',
    'th' => 'การซิงค์ไม่พร้อมใช้งาน',
    _ => 'Sync unavailable',
  };

  String get appCenterElapsedLabel => switch (_loc) {
    'zh' => _isHant ? '已耗時' : '已耗时',
    'ja' => '経過時間',
    'ko' => '경과 시간',
    'de' => 'Verstrichen',
    'fr' => 'Écoulé',
    'es' => 'Transcurrido',
    'pt' => 'Decorrido',
    'it' => 'Trascorso',
    'ru' => 'Прошло времени',
    'ar' => 'الوقت المنقضي',
    'hi' => 'बीता समय',
    'id' => 'Berlalu',
    'tr' => 'Geçen süre',
    'vi' => 'Đã trôi qua',
    'th' => 'ผ่านไปแล้ว',
    _ => 'Elapsed',
  };

  String get appCenterLastOutputLabel => switch (_loc) {
    'zh' => _isHant ? '最後輸出' : '最后输出',
    'ja' => '最終出力',
    'ko' => '마지막 출력',
    'de' => 'Letzte Ausgabe',
    'fr' => 'Dernière sortie',
    'es' => 'Última salida',
    'pt' => 'Última saída',
    'it' => 'Ultimo output',
    'ru' => 'Последний вывод',
    'ar' => 'آخر مخرجات',
    'hi' => 'अंतिम आउटपुट',
    'id' => 'Output terakhir',
    'tr' => 'Son çıktı',
    'vi' => 'Đầu ra cuối',
    'th' => 'เอาต์พุตล่าสุด',
    _ => 'Last output',
  };

  String get appCenterAccessInfoLabel => switch (_loc) {
    'zh' => _isHant ? '存取資訊與診斷' : '访问信息与诊断',
    'ja' => 'アクセス情報と診断',
    'ko' => '접속 정보 및 진단',
    'de' => 'Zugriffsinformationen & Diagnose',
    'fr' => 'Informations d\'accès et diagnostic',
    'es' => 'Información de acceso y diagnóstico',
    'pt' => 'Informações de acesso e diagnóstico',
    'it' => 'Informazioni di accesso e diagnostica',
    'ru' => 'Информация о доступе и диагностика',
    'ar' => 'معلومات الوصول والتشخيص',
    'hi' => 'पहुंच जानकारी और निदान',
    'id' => 'Informasi Akses & Diagnostik',
    'tr' => 'Erişim Bilgileri ve Tanılama',
    'vi' => 'Thông tin truy cập & chẩn đoán',
    'th' => 'ข้อมูลการเข้าถึงและการวินิจฉัย',
    _ => 'Access Information',
  };

  String get appCenterExternalPortWarningLabel => switch (_loc) {
    'zh' =>
      _isHant
          ? '繫結至所有介面 (0.0.0.0) 將向外部網路公開連接埠。請確保防火牆與服務驗證安全。'
          : '绑定到所有接口 (0.0.0.0) 将向外部网络开放端口。请确保防火墙及服务认证安全。',
    'ja' =>
      'すべてのインターフェース (0.0.0.0) にバインドすると外部ネットワークに公開されます。ファイアウォールと認証の安全性を確認してください。',
    'ko' => '모든 인터페이스 (0.0.0.0)에 바인딩하면 포트가 외부 네트워크에 노출됩니다. 방화벽과 인증 보안을 확인하세요.',
    'de' =>
      'Die Bindung an alle Schnittstellen (0.0.0.0) gibt Ports für externe Netzwerke frei. Prüfen Sie Firewall und Authentifizierung.',
    'fr' =>
      'La liaison à toutes les interfaces (0.0.0.0) expose les ports au réseau externe. Assurez-vous de la sécurité du pare-feu et de l\'authentification.',
    'es' =>
      'Vincular a todas las interfaces (0.0.0.0) expone los puertos a la red externa. Compruebe la seguridad del cortafuegos y la autenticación.',
    'pt' =>
      'Vincular a todas as interfaces (0.0.0.0) expõe as portas à rede externa. Verifique a segurança do firewall e da autenticação.',
    'it' =>
      'Il binding su tutte le interfacce (0.0.0.0) espone le porte alla rete esterna. Verificare la sicurezza del firewall e dell\'autenticazione.',
    'ru' =>
      'Привязка ко всем интерфейсам (0.0.0.0) открывает порты для внешней сети. Проверьте параметры брандмауэра и аутентификации.',
    'ar' =>
      'ربط جميع الواجهات (0.0.0.0) يعرض المنافذ للشبكة الخارجية. يرجى التأكد من أمان جدار الحماية والمصادقة.',
    'hi' =>
      'सभी इंटरफेस (0.0.0.0) से बाइंड करने पर पोर्ट बाहरी नेटवर्क पर खुल जाते हैं। फ़ायरवॉल और प्रमाणीकरण सुरक्षा जांचें।',
    'id' =>
      'Mengikat ke semua antarmuka (0.0.0.0) mengekspos port ke jaringan eksternal. Pastikan keamanan firewall dan autentikasi.',
    'tr' =>
      'Tüm arayüzlere (0.0.0.0) bağlamak bağlantı noktalarını dış ağa açar. Güvenlik duvarı ve kimlik doğrulama güvenliğini sağlayın.',
    'vi' =>
      'Liên kết với tất cả giao diện (0.0.0.0) sẽ mở cổng ra mạng bên ngoài. Hãy đảm bảo an toàn tường lửa và xác thực.',
    'th' =>
      'การผูกกับทุกอินเทอร์เฟซ (0.0.0.0) จะเปิดพอร์ตสู่เครือข่ายภายนอก โปรดตรวจสอบความปลอดภัยของไฟร์วอลล์และการยืนยันตัวตน',
    _ =>
      'Binding to all interfaces (0.0.0.0) exposes ports to the external network. Ensure firewall and authentication security.',
  };

  String get appCenterPortBindInheritLabel => switch (_loc) {
    'zh' => _isHant ? '預設繼承' : '默认继承',
    'ja' => 'デフォルト継承',
    'ko' => '기본 상속',
    'de' => 'Standard',
    'fr' => 'Par défaut',
    'es' => 'Por defecto',
    'pt' => 'Padrão',
    'it' => 'Predefinito',
    'ru' => 'По умолчанию',
    'ar' => 'افتراضي',
    'hi' => 'डिफ़ॉल्ट',
    'id' => 'Default',
    'tr' => 'Varsayılan',
    'vi' => 'Mặc định',
    'th' => 'ค่าเริ่มต้น',
    _ => 'Default',
  };

  String get appCenterSourceRefreshedAtLabel => switch (_loc) {
    'zh' => _isHant ? '上次成功更新' : '上次成功更新',
    'ja' => '最終更新',
    'ko' => '최근 업데이트',
    'de' => 'Zuletzt aktualisiert',
    'fr' => 'Dernière mise à jour',
    'es' => 'Última actualización',
    'pt' => 'Última atualização',
    'it' => 'Ultimo aggiornamento',
    'ru' => 'Последнее обновление',
    'ar' => 'آخر تحديث ناجح',
    'hi' => 'अंतिम सफल अपडेट',
    'id' => 'Terakhir diperbarui',
    'tr' => 'Son güncelleme',
    'vi' => 'Cập nhật lần cuối',
    'th' => 'อัปเดตล่าสุด',
    _ => 'Last updated',
  };

  String get appCenterProbeLabel => switch (_loc) {
    'zh' => _isHant ? '探測狀態' : '探测状态',
    'ja' => 'プローブ',
    'ko' => '프로브',
    'de' => 'Sonde',
    'fr' => 'Sonde',
    'es' => 'Sondeo',
    'pt' => 'Sonda',
    'it' => 'Sonda',
    'ru' => 'Проверка',
    'ar' => 'الفحص',
    'hi' => 'जांच',
    'id' => 'Pemeriksaan',
    'tr' => 'Yoklama',
    'vi' => 'Thăm dò',
    'th' => 'การสำรวจ',
    _ => 'Probe',
  };

  String get appCenterCheckedLabel => switch (_loc) {
    'zh' => _isHant ? '檢查時間' : '检查时间',
    'ja' => '確認日時',
    'ko' => '확인 시간',
    'de' => 'Geprüft',
    'fr' => 'Vérifié',
    'es' => 'Comprobado',
    'pt' => 'Verificado',
    'it' => 'Controllato',
    'ru' => 'Проверено',
    'ar' => 'تم الفحص',
    'hi' => 'जांचा गया',
    'id' => 'Diperiksa',
    'tr' => 'Kontrol edildi',
    'vi' => 'Đã kiểm tra',
    'th' => 'ตรวจสอบแล้ว',
    _ => 'Checked',
  };

  String get appCenterAccessEndpointsLabel => switch (_loc) {
    'zh' => _isHant ? '存取端點' : '访问端点',
    'ja' => 'アクセスエンドポイント',
    'ko' => '접속 엔드포인트',
    'de' => 'Zugriffsendpunkte',
    'fr' => 'Points de terminaison d\'accès',
    'es' => 'Puntos de conexión de acceso',
    'pt' => 'Pontos de extremidade de acesso',
    'it' => 'Endpoint di accesso',
    'ru' => 'Точки доступа',
    'ar' => 'نقاط نهاية الوصول',
    'hi' => 'पहुंच एंडपॉइंट',
    'id' => 'Titik Akhir Akses',
    'tr' => 'Erişim Uç Noktaları',
    'vi' => 'Điểm cuối truy cập',
    'th' => 'จุดเชื่อมต่อการเข้าถึง',
    _ => 'Access Endpoints',
  };

  String get appCenterSshPortForwardingLabel => switch (_loc) {
    'zh' => _isHant ? 'SSH 埠轉發' : 'SSH 端口转发',
    'ja' => 'SSH ポートフォワーディング',
    'ko' => 'SSH 포트 포워딩',
    'de' => 'SSH-Portweiterleitung',
    'fr' => 'Redirection de port SSH',
    'es' => 'Reenvío de puertos SSH',
    'pt' => 'Redirecionamento de porta SSH',
    'it' => 'Inoltro porta SSH',
    'ru' => 'Проброс портов SSH',
    'ar' => 'إعادة توجيه منفذ SSH',
    'hi' => 'SSH पोर्ट अग्रेषण',
    'id' => 'Penerusan Port SSH',
    'tr' => 'SSH Bağlantı Noktası Yönlendirme',
    'vi' => 'Chuyển tiếp cổng SSH',
    'th' => 'การส่งต่อพอร์ต SSH',
    _ => 'SSH Port Forwarding',
  };

  String get appCenterExternalAccessCandidateLabel => switch (_loc) {
    'zh' => _isHant ? '外部存取位址' : '外部访问候选地址',
    'ja' => '外部アクセス候補',
    'ko' => '외부 접속 후보',
    'de' => 'Externer Zugriffskandidat',
    'fr' => 'Candidat d\'accès externe',
    'es' => 'Candidato de acceso externo',
    'pt' => 'Candidato a acesso externo',
    'it' => 'Candidato di accesso esterno',
    'ru' => 'Внешний адрес доступа',
    'ar' => 'مرشح الوصول الخارجي',
    'hi' => 'बाहरी पहुंच उम्मीदवार',
    'id' => 'Kandidat Akses Eksternal',
    'tr' => 'Harici Erişim Adayı',
    'vi' => 'Ứng viên truy cập bên ngoài',
    'th' => 'ที่อยู่สำหรับการเข้าถึงภายนอก',
    _ => 'External Access Candidate',
  };

  String get appCenterHostInputLabel => switch (_loc) {
    'zh' => _isHant ? '伺服器主機名 / 網域 / IP' : '服务器主机名 / 域名 / IP',
    'ja' => 'サーバーホスト / ドメイン / IP',
    'ko' => '서버 호스트 / 도메인 / IP',
    'de' => 'Server-Host / Domain / IP',
    'fr' => 'Hôte / Domaine / IP du serveur',
    'es' => 'Host / Dominio / IP del servidor',
    'pt' => 'Host / Domínio / IP do servidor',
    'it' => 'Host / Dominio / IP del server',
    'ru' => 'Хост / Домен / IP сервера',
    'ar' => 'مضيف الخادم / النطاق / IP',
    'hi' => 'सर्वर होस्ट / डोमेन / आईपी',
    'id' => 'Host Server / Domain / IP',
    'tr' => 'Sunucu Ana Bilgisayarı / Alan Adı / IP',
    'vi' => 'Máy chủ / Tên miền / IP',
    'th' => 'โฮสต์ของเซิร์ฟเวอร์ / โดเมน / IP',
    _ => 'Server Host / Domain / IP',
  };

  String get appCenterExternalAccessWarningLabel => switch (_loc) {
    'zh' =>
      _isHant
          ? '外部連通性取決於伺服器防火牆與網路路由，直接存取不會修改主機防火牆規則。'
          : '外部连通性取决于服务器防火墙与网络路由，直接访问不会修改主机防火墙规则。',
    'ja' => '外部接続性はファイアウォールとルーティングに依存します。直接接続でホストのファイアウォール規則は変更されません。',
    'ko' => '외부 연결성은 서버 방화벽 및 라우팅에 따라 달라집니다. 직접 접속 시 방화벽 규칙이 자동 변경되지 않습니다.',
    'de' =>
      'Externe Erreichbarkeit erfordert passende Firewall- und Routing-Regeln auf dem Host.',
    'fr' =>
      'L\'accessibilité externe dépend du pare-feu et du routage de l\'hôte.',
    'es' =>
      'La disponibilidad externa depende del cortafuegos y el enrutamiento del host.',
    'pt' =>
      'A conectividade externa depende do firewall e do roteamento do servidor.',
    'it' =>
      'La disponibilità esterna dipende dal firewall e dall\'instradamento dell\'host.',
    'ru' =>
      'Внешняя доступность зависит от настроек брандмауэра и маршрутизации на хосте.',
    'ar' => 'يعتمد الوصول الخارجي على جدار حماية الخادم وتوجيه الشبكة.',
    'hi' => 'बाहरी पहुंच सर्वर फ़ायरवॉल और नेटवर्क रूटिंग पर निर्भर करती है।',
    'id' =>
      'Ketersediaan eksternal tergantung pada firewall server dan perutean jaringan.',
    'tr' =>
      'Harici erişim sunucu güvenlik duvarı ve ağ yönlendirmesine bağlıdır.',
    'vi' =>
      'Khả năng truy cập bên ngoài phụ thuộc vào tường lửa và định tuyến mạng của máy chủ.',
    'th' =>
      'การเข้าถึงภายนอกขึ้นอยู่กับไฟร์วอลล์และการกำหนดเส้นทางเครือข่ายของเซิร์ฟเวอร์',
    _ => 'External availability is subject to host firewall and routing rules.',
  };

  String get appCenterSshOnlyNoticeLabel => switch (_loc) {
    'zh' =>
      _isHant
          ? '管理連接埠僅繫結至本地回環 (127.0.0.1)，請透過安全 SSH 管道存取。'
          : '管理端口仅绑定在本地回环 (127.0.0.1)，请通过安全 SSH 隧道访问。',
    'ja' =>
      '管理ポートはローカルループバック (127.0.0.1) にのみバインドされています。安全な SSH トンネル経由でアクセスしてください。',
    'ko' => '관리 포트가 로컬 루프백 (127.0.0.1)에만 바인딩되어 있습니다. 보안 SSH 터널을 통해 접속하세요.',
    'de' =>
      'Der Verwaltungsport ist nur an Loopback (127.0.0.1) gebunden. Zugriff erfolgt sicher über den SSH-Tunnel.',
    'fr' =>
      'Le port de gestion est lié uniquement à la boucle locale (127.0.0.1). Accédez-y via le tunnel SSH.',
    'es' =>
      'El puerto de administración solo está vinculado a bucle local (127.0.0.1). Acceda de forma segura mediante túnel SSH.',
    'pt' =>
      'A porta de gerenciamento está vinculada apenas ao loopback local (127.0.0.1). Acesse pelo túnel SSH.',
    'it' =>
      'La porta di gestione è associata solo al loopback locale (127.0.0.1). Accedere tramite tunnel SSH.',
    'ru' =>
      'Порт управления привязан только к локальному loopback (127.0.0.1). Доступ осуществляется через туннель SSH.',
    'ar' =>
      'منفذ الإدارة مرتبط فقط بالاسترجاع المحلي (127.0.0.1). يرجى الوصول بأمان عبر نفق SSH.',
    'hi' =>
      'प्रबंधन पोर्ट केवल स्थानीय लूपबैक (127.0.0.1) पर बाउंड है। सुरक्षित SSH टनल से पहुंचें।',
    'id' =>
      'Port manajemen hanya terikat ke loopback lokal (127.0.0.1). Akses dengan aman melalui terowongan SSH.',
    'tr' =>
      'Yönetim bağlantı noktası yalnızca yerel geri döngüye (127.0.0.1) bağlıdır. Güvenli SSH tüneliyle erişin.',
    'vi' =>
      'Cổng quản lý chỉ được liên kết với vòng lặp cục bộ (127.0.0.1). Hãy truy cập an toàn qua đường hầm SSH.',
    'th' =>
      'พอร์ตการจัดการถูกผูกไว้กับลูปแบ็กภายในเครื่อง (127.0.0.1) เท่านั้น โปรดเข้าถึงอย่างปลอดภัยผ่านทันเนล SSH',
    _ =>
      'Management port is bound to loopback only (127.0.0.1). Access securely via SSH tunnel.',
  };

  String get appCenterTargetLabel => switch (_loc) {
    'zh' => _isHant ? '容器內部' : '容器内部',
    'ja' => 'コンテナ内部',
    'ko' => '컨테이너 내부',
    'de' => 'Container',
    'fr' => 'Conteneur',
    'es' => 'Contenedor',
    'pt' => 'Contêiner',
    'it' => 'Container',
    'ru' => 'Контейнер',
    'ar' => 'داخل الحاوية',
    'hi' => 'कंटेनर',
    'id' => 'Kontainer',
    'tr' => 'Kapsayıcı',
    'vi' => 'Vùng chứa',
    'th' => 'คอนเทนเนอร์',
    _ => 'Target',
  };

  String get appCenterExternalLabel => switch (_loc) {
    'zh' => _isHant ? '外部' : '外部',
    'ja' => '外部',
    'ko' => '외부',
    'de' => 'Extern',
    'fr' => 'Externe',
    'es' => 'Externo',
    'pt' => 'Externo',
    'it' => 'Esterno',
    'ru' => 'Внешний',
    'ar' => 'خارجي',
    'hi' => 'बाहरी',
    'id' => 'Eksternal',
    'tr' => 'Harici',
    'vi' => 'Bên ngoài',
    'th' => 'ภายนอก',
    _ => 'External',
  };
}
