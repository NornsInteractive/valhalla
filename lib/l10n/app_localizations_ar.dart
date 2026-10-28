// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get nasPlaylistLoadFailed =>
      'قوائم التشغيل غير متاحة مؤقتًا. لا تزال قائمة الوسائط المحفوظة متاحة. حدّث لإعادة المحاولة.';

  @override
  String get nasAllLibraries => 'كل المكتبات';

  @override
  String get nasDiagnosticsTitle => 'تشخيص مصدر الوسائط';

  @override
  String get nasDiagnosticsConnection => 'الاتصال';

  @override
  String get nasDiagnosticsScan => 'فحص المكتبة';

  @override
  String get nasDiagnosticsLastSuccess => 'آخر اتصال ناجح';

  @override
  String get nasDiagnosticsCredentials =>
      'جارٍ التحقق من بيانات الاعتماد المحفوظة';

  @override
  String get nasDiagnosticsFinalizing => 'جارٍ إكمال الفهرس';

  @override
  String get nasDiagnosticsNotChecked => 'لم يتم التحقق';

  @override
  String get nasCacheLegacy => 'صور مصغّرة قديمة (غير مرتبطة بمصدر)';

  @override
  String get nasCacheGlobalBudget => 'حد تخزين الصور المصغّرة (جميع المصادر)';

  @override
  String get nasCacheNoSource => 'اختر مصدر وسائط لإدارة ذاكرته المؤقتة.';

  @override
  String get nasOfflineRecordedHint =>
      'هذه أحجام التنزيلات المسجّلة بالبايت، وليست قياسًا لاستخدام القرص. لا يؤدي مسح الصور المصغّرة إلى حذف الملفات المتاحة دون اتصال.';

  @override
  String nasCacheClearConfirm(String scope) {
    return 'هل تريد مسح الصور المصغّرة الخاصة بـ $scope؟ ستُحفظ الملفات المتاحة دون اتصال والوسائط البعيدة.';
  }

  @override
  String nasOfflineRecordedBytes(String size) {
    return 'التنزيلات المسجّلة: $size';
  }

  @override
  String get nasDeployDockerTitle => 'تطبيق Docker';

  @override
  String get nasDeployDockerDesc =>
      'افتح تطبيق Jellyfin الرسمي في مركز التطبيقات. راجع إعداداته قبل التثبيت.';

  @override
  String get nasDeployNativeDesc =>
      'ثبّت Jellyfin مباشرة على هذا الخادم باستخدام حزمه الرسمية. لن تتغير التثبيتات الحالية.';

  @override
  String get nasDeployEnableAppCenter =>
      'هل تريد تفعيل مركز التطبيقات التجريبي للمتابعة؟ لن يتغير ترتيب القائمة.';

  @override
  String get nasDeployCatalogUnavailable =>
      'تطبيق Jellyfin الرسمي غير متاح. تأكد من تفعيل المصدر الرسمي ثم أعد المحاولة.';

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle =>
      'إدارة الخوادم والوكلاء المعتمدة على الذكاء الاصطناعي';

  @override
  String get navAiChat => 'عمليات الذكاء الاصطناعي';

  @override
  String get navTerminal => 'الطرفية';

  @override
  String get navFiles => 'ملفات SFTP';

  @override
  String get navCommands => 'الأوامر';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get serverConnected => 'متصل';

  @override
  String get serverOnline => 'متصل بالإنترنت';

  @override
  String get serverOffline => 'غير متصل';

  @override
  String get latencyMs => 'مللي ثانية';

  @override
  String get reconnect => 'إعادة الاتصال';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get quickDisconnect => 'قطع سريع';

  @override
  String get newSession => 'جلسة جديدة';

  @override
  String get historySessions => 'سجل الجلسات';

  @override
  String get switchAgent => 'تبديل الوكيل';

  @override
  String get agentClaudeCode => 'Claude Code';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'الوكيل النشط';

  @override
  String get inputPromptHint =>
      'اطلب من الوكيل التشخيص أو تشغيل الأدوات أو كتابة الأوامر... (اضغط Enter للإرسال)';

  @override
  String get thinking => 'عملية التفكير';

  @override
  String get executionPlan => 'خطة التنفيذ';

  @override
  String get toolCall => 'استدعاء الأداة';

  @override
  String get toolStatusPending => 'قيد الانتظار';

  @override
  String get toolStatusRunning => 'جارٍ التشغيل...';

  @override
  String get toolStatusCompleted => 'اكتمل';

  @override
  String get toolStatusFailed => 'فشل';

  @override
  String get permissionRequired => 'مطلوب إذن';

  @override
  String get permissionDescription => 'يريد الوكيل تنفيذ هذا الأمر على الخادم:';

  @override
  String get permissionReject => 'رفض';

  @override
  String get permissionAllowOnce => 'السماح لمرة واحدة';

  @override
  String get permissionAllowAlways => 'السماح دائماً';

  @override
  String get quickTroubleshootCpu => 'استكشاف أخطاء استهلاك المعالج';

  @override
  String get quickDockerHealth => 'فحص حالة Docker';

  @override
  String get quickCleanCache => 'تنظيف ذاكرة التخزين المؤقت';

  @override
  String get quickNginxLogs => 'التحقق من سجلات أخطاء Nginx';

  @override
  String get terminalNewTab => 'علامة تبويب جديدة';

  @override
  String get terminalCloseTab => 'إغلاق التبويب';

  @override
  String get terminalClear => 'مسح';

  @override
  String get terminalQuickCmds => 'لوحة الأوامر';

  @override
  String get terminalPaste => 'لصق';

  @override
  String get terminalConfirmPasteTitle => 'تأكيد اللصق';

  @override
  String terminalConfirmPasteMessage(int count) {
    return 'لصق $count من أسطر النص في الطرفية. هل تريد المتابعة؟';
  }

  @override
  String get settingsTerminalPinnedKeys => 'مفاتيح شريط الطرفية';

  @override
  String get settingsTerminalPinnedKeysSubtitle =>
      'تخصيص وإعادة ترتيب مفاتيح شريط الأدوات';

  @override
  String get terminalResetPinnedKeys => 'إعادة الضبط إلى الافتراضي';

  @override
  String get terminalToggleKeyboard => 'تبديل لوحة المفاتيح';

  @override
  String get terminalKeyArrows => 'مفاتيح الأسهم';

  @override
  String get terminalDirectionPad => 'لوحة الاتجاهات';

  @override
  String get terminalCloseDirectionPad => 'إغلاق لوحة الاتجاهات';

  @override
  String get terminalDirectionPadModeFixed => 'ثابت على اليمين';

  @override
  String get terminalDirectionPadModeFlow => 'التمرير مع المفاتيح';

  @override
  String get terminalDirectionPadModeHidden => 'مخفي';

  @override
  String get terminalDirectionKeyColor => 'لون مفاتيح الاتجاه';

  @override
  String get terminalDirectionKeyColorDefault => 'اتباع السمة';

  @override
  String get terminalDirectionKeyColorReset => 'إعادة التعيين إلى السمة';

  @override
  String get terminalAccessorySaveFailed => 'فشل حفظ إعدادات شريط الأدوات';

  @override
  String get terminalDirectionKeyNormal => 'عادي';

  @override
  String get terminalDirectionKeyPressed => 'مضغوط';

  @override
  String terminalPinnedKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مثبتة ($count)',
      many: 'مثبتة ($count)',
      few: 'مثبتة ($count)',
      two: 'مثبتة (2)',
      one: 'مثبتة (1)',
      zero: 'مثبتة (0)',
    );
    return '$_temp0';
  }

  @override
  String get terminalNoPinnedKeys => 'لا توجد مفاتيح مثبتة';

  @override
  String terminalAvailableKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'متاح للإضافة ($count)',
      many: 'متاح للإضافة ($count)',
      few: 'متاح للإضافة ($count)',
      two: 'متاح للإضافة (2)',
      one: 'متاح للإضافة (1)',
      zero: 'متاح للإضافة (0)',
    );
    return '$_temp0';
  }

  @override
  String get sftpCurrentPath => 'المسار الحالي';

  @override
  String get sftpUpload => 'رفع';

  @override
  String get sftpNewFolder => 'مجلد جديد';

  @override
  String get sftpNewFile => 'ملف جديد';

  @override
  String get sftpRefresh => 'تحديث';

  @override
  String get sftpSearchHint => 'البحث في الملفات أو المجلدات...';

  @override
  String get sftpEmpty => 'الدليل فارغ';

  @override
  String get sftpFileName => 'الاسم';

  @override
  String get sftpFileSize => 'الحجم';

  @override
  String get sftpFilePerm => 'الأذونات';

  @override
  String get sftpFileModified => 'تاريخ التعديل';

  @override
  String get cmdCategoryDocker => 'حاوية DOCKER';

  @override
  String get cmdCategorySystem => 'صيانة النظام';

  @override
  String get cmdCategoryNetwork => 'الشبكة والمنافذ';

  @override
  String get cmdExecute => 'تشغيل';

  @override
  String get cmdDangerous => 'أمر خطير';

  @override
  String get cmdDangerousWarning =>
      'هذه العملية لا يمكن التراجع عنها وقد تسبب انقطاع الخدمة. هل تريد بالتأكيد المتابعة؟';

  @override
  String get cmdParamRequired => 'مطلوب إدخال معلمات';

  @override
  String get cmdConfirm => 'تأكيد وتشغيل';

  @override
  String get cmdCancel => 'إلغاء';

  @override
  String get settingsAppearance => 'المظهر والسمات';

  @override
  String get settingsThemeMode => 'وضع السمة';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get themeSystemDesc => 'تكيف تلقائي';

  @override
  String get themeLight => 'الوضع الفاتح';

  @override
  String get themeLightDesc => 'ورقي عالي الإضاءة';

  @override
  String get themeDark => 'داكن تقني';

  @override
  String get themeDarkDesc => 'فحمي عميق';

  @override
  String get themeAmoled => 'أسود AMOLED';

  @override
  String get themeAmoledDesc => 'أسود حقيقي 0x000000';

  @override
  String get settingsAccentColor => 'لون التمييز';

  @override
  String get accentCyberEmerald => 'زمرد سايبر';

  @override
  String get accentTechBlue => 'أزرق تقني';

  @override
  String get accentElectricViolet => 'بنفسجي كهربائي';

  @override
  String get accentCrimsonRed => 'أحمر قرمزي';

  @override
  String get accentAmberOrange => 'برتقالي عنبري';

  @override
  String get settingsLanguage => 'اللغة والمنطقة';

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
  String get settingsAiOps => 'عمليات ومحرك الذكاء الاصطناعي';

  @override
  String get settingsSecurity => 'الاتصال والأمان';

  @override
  String get settingsKnownHosts => 'مفاتيح المضيفين المعروفين';

  @override
  String get settingsClearStorage => 'إعادة ضبط بيانات الاعتماد';

  @override
  String get settingsResetDefault => 'استعادة الإعدادات الافتراضية';

  @override
  String get settingsTerminalUseTmux => 'وضع إنشاء الطرفية يدويًا';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'تشغيل جلسات الطرفية داخل tmux على الخادم البعيد';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'ينطبق فقط على الطرفيات التي يتم إنشاؤها يدويًا. تستخدم الطرفيات التلقائية الجديدة دائمًا وضع SSH القياسي بدون سجل قابل للاسترداد؛ عند تمكين tmux، يمكن استعادة الجلسات المنشأة يدويًا بعد انقطاع الاتصال (يتطلب tmux على الخادم البعيد). لا يتأثر استرداد السجل الحالي.';

  @override
  String get settingsTerminalFontSize => 'حجم خط الطرفية';

  @override
  String get settingsTerminalFontSizeSubtitle => 'تعديل حجم خط طرفية SSH و CLI';

  @override
  String get version => 'الإصدار';

  @override
  String get addServer => 'إضافة خادم';

  @override
  String get editServer => 'تعديل الخادم';

  @override
  String get serverName => 'اسم الخادم';

  @override
  String get serverHost => 'المضيف / IP';

  @override
  String get serverPort => 'المنفذ';

  @override
  String get serverUsername => 'اسم المستخدم';

  @override
  String get serverAuthType => 'نوع المصادقة';

  @override
  String get serverPassword => 'كلمة المرور';

  @override
  String get serverPrivateKey => 'المفتاح الخاص';

  @override
  String get serverSave => 'حفظ الخادم';

  @override
  String get serverDelete => 'حذف الخادم';

  @override
  String get fileEditor => 'محرر الملفات';

  @override
  String get fileEditorSave => 'حفظ التغييرات';

  @override
  String get fileSavedSuccess => 'تم حفظ الملف بنجاح';

  @override
  String get addCommand => 'أمر جديد';

  @override
  String get commandTitle => 'عنوان الأمر';

  @override
  String get commandContent => 'نص الأمر';

  @override
  String get commandCategory => 'الفئة';

  @override
  String get commandDescription => 'الوصف';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get cmdExecutionChannel => 'قناة التنفيذ';

  @override
  String get cmdChannelTerminal => 'مباشرة إلى طرفية SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'يتم إدخال الأمر مباشرة في جلسة الطرفية النشطة';

  @override
  String get cmdChannelBackground => 'تشغيل في جلسة خلفية';

  @override
  String get cmdChannelBackgroundDesc =>
      'يتم التنفيذ عبر جلسة تسجيل دخول SSH والتقاط المخرجات';

  @override
  String get cmdInjectedToTerminal => 'تم إرسال الأمر إلى الطرفية';

  @override
  String get cmdExecutionCompleted => 'اكتمل التنفيذ';

  @override
  String get cmdExecutionFailed => 'فشل التنفيذ';

  @override
  String get cmdExecutingRemote => 'جارٍ تنفيذ الأمر البعيد...';

  @override
  String get cmdClose => 'إغلاق';

  @override
  String get navDashboard => 'لوحة القيادة';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'النظام';

  @override
  String get navMore => 'المزيد';

  @override
  String get dashboardTitle => 'لوحة قيادة الخادم';

  @override
  String get metricsCpu => 'استهلاك المعالج';

  @override
  String get metricsMemory => 'استهلاك الذاكرة';

  @override
  String get metricsLoadAvg => 'متوسط الحمل';

  @override
  String get metricsUptime => 'مدة تشغيل النظام';

  @override
  String get metricsRootDisk => 'استهلاك القرص الجذري';

  @override
  String get quickActions => 'التنقل السريع';

  @override
  String get activeServerStatus => 'حالة الخادم النشط';

  @override
  String get noServerSelected =>
      'لم يتم تحديد خادم حالياً. يرجى اختيار خادم أولاً.';

  @override
  String get serverDisconnected => 'غير متصل';

  @override
  String get serverConnecting => 'جارٍ الاتصال...';

  @override
  String get connectNow => 'اتصل الآن';

  @override
  String get serverSpecs => 'معلومات ومواصفات الخادم';

  @override
  String get dockerTitle => 'حاويات Docker';

  @override
  String get dockerSearchHint => 'البحث في الحاويات بالاسم أو الصورة...';

  @override
  String get dockerFilterAll => 'الكل';

  @override
  String get dockerFilterRunning => 'قيد التشغيل';

  @override
  String get dockerFilterExited => 'متوقفة';

  @override
  String get dockerFilterPaused => 'موقفة مؤقتاً';

  @override
  String get dockerActionStart => 'بدء';

  @override
  String get dockerActionStop => 'إيقاف';

  @override
  String get dockerActionRestart => 'إعادة تشغيل';

  @override
  String get dockerActionPause => 'إيقاف مؤقت';

  @override
  String get dockerActionUnpause => 'استئناف';

  @override
  String get dockerActionRm => 'إزالة';

  @override
  String get dockerActionLogs => 'السجلات';

  @override
  String get dockerActionInspect => 'فحص';

  @override
  String get dockerLogsTitle => 'سجلات الحاوية';

  @override
  String get dockerInspectTitle => 'تفاصيل فحص الحاوية';

  @override
  String get dockerNoContainers => 'لم يتم العثور على حاويات على الخادم';

  @override
  String get dockerEmptyRunning => 'لا توجد حاويات قيد التشغيل';

  @override
  String get dockerPorts => 'المنافذ';

  @override
  String get dockerCreated => 'تاريخ الإنشاء';

  @override
  String get dockerImage => 'الصورة';

  @override
  String get systemTitle => 'العمليات والخدمات';

  @override
  String get tabProcesses => 'العمليات';

  @override
  String get tabServices => 'خدمات Systemd';

  @override
  String get processSearchHint => 'البحث باسم العملية أو PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% المعالج';

  @override
  String get processMem => '% الذاكرة';

  @override
  String get processStat => 'الحالة';

  @override
  String get processCommand => 'الأمر';

  @override
  String get processTerminate => 'إنهاء (SIGTERM)';

  @override
  String get processForceKill => 'إنهاء إجباري (SIGKILL)';

  @override
  String get processKillForbidden =>
      'تم رفض إنهاء عملية تهيئة النظام (PID <= 1)';

  @override
  String get serviceSearchHint => 'البحث في الخدمات بالاسم...';

  @override
  String get serviceName => 'الخدمة';

  @override
  String get serviceDescription => 'الوصف';

  @override
  String get serviceStatus => 'الحالة';

  @override
  String get serviceStartup => 'بدء التشغيل';

  @override
  String get serviceActionStart => 'بدء';

  @override
  String get serviceActionStop => 'إيقاف';

  @override
  String get serviceActionRestart => 'إعادة تشغيل';

  @override
  String get serviceActionReload => 'إعادة تحميل';

  @override
  String get serviceActionEnable => 'تمكين';

  @override
  String get serviceActionDisable => 'تعطيل';

  @override
  String get serviceNoServices => 'لم يتم العثور على خدمات systemd';

  @override
  String get riskDangerTitle => 'تأكيد عملية عالية الخطورة';

  @override
  String get riskWarningTitle => 'تأكيد تحذير العملية';

  @override
  String get riskSafeTitle => 'تأكيد الإجراء';

  @override
  String get riskIrreversibleWarning =>
      'تم تصنيف هذه العملية على أنها عالية الخطورة ولا يمكن التراجع عنها. قد تتسبب في فقدان البيانات أو تعطل الخدمة.';

  @override
  String get riskWarningDescription =>
      'قد تؤثر هذه العملية على الخدمات النشطة أو تعيد تشغيل العمليات. تابع بحذر.';

  @override
  String get riskCommandPreview => 'معاينة الأمر';

  @override
  String get riskConfirmButton => 'تأكيد ومتابعة';

  @override
  String get riskCancelButton => 'إلغاء';

  @override
  String get stateLoading => 'جارٍ تحميل البيانات البعيدة...';

  @override
  String get stateOffline => 'الخادم غير متصل';

  @override
  String get stateOfflineDesc =>
      'أنشئ اتصال SSH نشطاً لإدارة الموارد وبث المقاييس.';

  @override
  String get stateError => 'حدث خطأ';

  @override
  String get stateRetry => 'إعادة المحاولة';

  @override
  String get stateEmpty => 'لم يتم العثور على عناصر';

  @override
  String get inspectorTitle => 'الفاحص';

  @override
  String get inspectorClose => 'إغلاق';

  @override
  String get inspectorDetails => 'تفاصيل الفحص';

  @override
  String get selectServerTitle => 'اختر الخادم المستهدف';

  @override
  String get sshDisconnectedSuccess => 'تم قطع اتصال SSH بنجاح';

  @override
  String get trustHostFingerprintTitle => 'هل تثق في بصمة المضيف؟';

  @override
  String get trustAndConnect => 'وثوق واتصال';

  @override
  String get reject => 'رفض';

  @override
  String get confirmDeleteServerTitle => 'حذف الخادم';

  @override
  String get noServersFound => 'لم يتم تكوين أي خوادم بعد';

  @override
  String get agentNotReadyError =>
      'الوكيل المحدد غير جاهز. يرجى التحقق من بيئته وإعداده.';

  @override
  String get sshDisconnectedError =>
      'SSH غير متصل. يرجى الاتصال بخادم قبل استخدام عمليات الذكاء الاصطناعي.';

  @override
  String get noAgentAvailable => 'لا يوجد وكيل متاح';

  @override
  String get noAgentAvailablePrompt =>
      'لا يوجد وكيل نشط متاح. يرجى تكوين أو تجهيز وكيل أولاً.';

  @override
  String get noAgentAvailableHint =>
      'حدد أو قم بإعداد وكيل متاح للبدء بالمحادثة...';

  @override
  String get manageAgents => 'إدارة الوكلاء';

  @override
  String get noReadyAgentsTitle => 'لا يوجد وكلاء جاهزون';

  @override
  String get noReadyAgentsDesc =>
      'لم يجتز أي وكيل على هذا الخادم فحوصات البيئة.';

  @override
  String get agentStatusReady => 'جاهز';

  @override
  String get agentStatusChecking => 'جارٍ التحقق...';

  @override
  String get agentStatusCliMissing => 'لم يتم اكتشاف التثبيت';

  @override
  String get agentStatusAcpMissing => 'لم يتم اكتشاف مكوّن ACP';

  @override
  String get agentStatusNotLoggedIn => 'لم يتم تسجيل الدخول';

  @override
  String get agentStatusError => 'خطأ';

  @override
  String get agentStatusUnknown => 'غير معروف';

  @override
  String get agentActionInstall => 'تثبيت';

  @override
  String get agentActionLogin => 'تسجيل الدخول';

  @override
  String get agentActionRefresh => 'التحقق من الحالة';

  @override
  String get noConfiguredAgents => 'لا يوجد وكلاء مكوّنون على هذا الخادم';

  @override
  String get agentManagementTitle => 'إدارة الوكلاء';

  @override
  String get settingsAgentManagement => 'إدارة الوكلاء';

  @override
  String get settingsAgentManagementSubtitle =>
      'تكوين واكتشاف وإدارة وكلاء ACP للخادم الحالي';

  @override
  String get addAgentButton => 'إضافة وكيل';

  @override
  String get noServerSelectedForAgents =>
      'لم يتم تحديد خادم. يرجى تحديد خادم من الواجهة الرئيسية أولاً.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH غير متصل. يتم تعطيل الاكتشاف والتثبيت وتسجيل الدخول حتى إنشاء الاتصال.';

  @override
  String get noAgentsConfiguredTitle => 'لا يوجد وكلاء مكوّنون';

  @override
  String get noAgentsConfiguredDesc =>
      'أضف Claude Code أو Codex أو OpenCode أو AGY أو وكلاء ACP مخصصين لتمكين عمليات الذكاء الاصطناعي.';

  @override
  String get agentPresetLabel => 'القالب الجاهز';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'مخصص';

  @override
  String get agentNameLabel => 'اسم الوكيل';

  @override
  String get agentNameHint => 'مثال: Production Codex';

  @override
  String get agentDescriptionLabel => 'الوصف';

  @override
  String get agentDescriptionHint => 'وصف موجز للوكيل';

  @override
  String get agentCliCommandLabel => 'أمر فحص CLI';

  @override
  String get agentCliCommandHint => 'مثال: claude, codex';

  @override
  String get agentAcpCommandLabel => 'أمر تشغيل ACP';

  @override
  String get agentAcpCommandHint => 'مثال: codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'أمر التثبيت (اختياري)';

  @override
  String get agentInstallCommandHint => 'مثال: npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => 'أمر فحص تسجيل الدخول (اختياري)';

  @override
  String get agentLoginCheckCommandHint => 'مثال: codex --version';

  @override
  String get agentLoginCommandLabel => 'أمر تسجيل الدخول (اختياري)';

  @override
  String get agentLoginCommandHint => 'مثال: codex login';

  @override
  String get agentSaveButton => 'حفظ واكتشاف';

  @override
  String get agentCliRequired => 'أمر فحص CLI مطلوب';

  @override
  String get agentAcpRequired => 'أمر تشغيل ACP مطلوب';

  @override
  String get agentNameRequired => 'اسم الوكيل مطلوب';

  @override
  String get confirmInstallAgentTitle => 'تأكيد تثبيت الوكيل';

  @override
  String get confirmLoginAgentTitle => 'تأكيد تسجيل دخول الوكيل';

  @override
  String get agentCommandRiskWarning =>
      'سيتم تنفيذ هذا الأمر مباشرة على الخادم البعيد بامتيازات المستخدم الحالي. قد يثبت حزماً أو يعدل بيئات النظام.';

  @override
  String get targetServerLabel => 'الخادم المستهدف';

  @override
  String get commandPreviewLabel => 'معاينة الأمر';

  @override
  String get executeButton => 'تنفيذ';

  @override
  String get deleteAgentTitle => 'حذف الوكيل';

  @override
  String get deleteAgentConfirm => 'حذف';

  @override
  String get agentStatusCheckingDesc =>
      'جارٍ اكتشاف البيئة على الخادم البعيد...';

  @override
  String get agentStatusInstalling => 'جارٍ تثبيت التبعيات على الخادم...';

  @override
  String get agentStatusLoggingIn =>
      'جارٍ تنفيذ أمر تسجيل الدخول على الخادم...';

  @override
  String get agentNoLoginCheckProvided => 'لم يتم تحديد أمر فحص تسجيل الدخول';

  @override
  String get agentInstallPrompt =>
      'لم يتم اكتشاف التثبيت. هل تريد التثبيت التلقائي الآن؟';

  @override
  String get agentActionAutoInstall => 'تثبيت تلقائي';

  @override
  String get agentLoginPrompt =>
      'لم يتم تسجيل الدخول. هل تريد تسجيل الدخول الآن؟';

  @override
  String get agentActionExecuteLogin => 'تسجيل الدخول الآن';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'الوكلاء على هذا الخادم غير مثبتين أو غير جاهزين بعد. يرجى إدارة إعداد البيئة وإكمالها.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'قم بتثبيت وتجهيز وكيل لبدء المحادثة...';

  @override
  String get agentAcpInstallPrompt =>
      'لم يتم اكتشاف مكوّن ACP. هل تريد التثبيت التلقائي الآن؟';

  @override
  String get agentInstallCommandAcpLabel => 'أمر تثبيت ACP (اختياري)';

  @override
  String get agentInstallCommandAcpHint =>
      'مثال: npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand => 'لم يتم تكوين أمر تثبيت لهذا الوكيل';

  @override
  String get agentInstallLogTitle => 'مخرجات التثبيت';

  @override
  String get agentInstallLogEmpty => 'في انتظار مخرجات التثبيت…';

  @override
  String get agentInstallLogTruncated =>
      'المخرجات طويلة جداً؛ يتم عرض أحدث الأسطر';

  @override
  String get agentAcpOptional => 'اختياري؛ اتركه فارغاً للاقتصار على CLI فقط';

  @override
  String get acpStreaming => 'بث ACP...';

  @override
  String get aiOpsAgentTitle => 'وكيل Valhalla AI Ops';

  @override
  String get aiOpsEmptySubtitle => 'متصل عبر ACP stdio عبر قناة SSH';

  @override
  String get agentAuthRequiredTitle => 'المصادقة مطلوبة';

  @override
  String get agentAuthRequiredDesc =>
      'يتطلب الوكيل المصادقة قبل أن يتمكن من معالجة طلبك.';

  @override
  String get agentAuthMethodLabel => 'طريقة المصادقة';

  @override
  String get agentAuthNoMethodsNotice =>
      'لم يوفر الوكيل طريقة لتسجيل الدخول. يرجى التحقق من إعداده على الخادم.';

  @override
  String get agentAuthProceedButton => 'تسجيل الدخول';

  @override
  String get agentAuthCancelButton => 'إلغاء';

  @override
  String get agentAuthRetryHint => 'بعد تسجيل الدخول، أعد إرسال رسالتك.';

  @override
  String get agentAuthRequiredError =>
      'المصادقة مطلوبة. يرجى تسجيل الدخول للمتابعة.';

  @override
  String get agentLoginTerminalTitle => 'طرفية تسجيل الدخول التفاعلية';

  @override
  String get agentLoginTerminalSubtitle =>
      'أكمل خطوات تسجيل الدخول في الطرفية أدناه. اتبع أي رابط URL أو رمز معروض.';

  @override
  String get agentLoginTerminalRunning =>
      'أمر تسجيل الدخول قيد التشغيل في الطرفية...';

  @override
  String get agentLoginTerminalDisconnected =>
      'فُقد اتصال SSH. تمت مقاطعة جلسة تسجيل الدخول.';

  @override
  String get agentLoginTerminalRetry => 'إعادة توصيل الطرفية';

  @override
  String get agentLoginTerminalFinish => 'إنهاء وتحقق';

  @override
  String get agentLoginTerminalClose => 'إغلاق';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'إذا تطلب الوكيل لصق رمز، فاضغط مطولاً على الطرفية للصق أو استخدم مفتاح اللصق.';

  @override
  String get agentLoginTerminalUrlLabel => 'تم اكتشاف رابط تسجيل الدخول';

  @override
  String get agentLoginTerminalUrlCopy => 'نسخ الرابط';

  @override
  String get agentLoginTerminalUrlCopied =>
      'تم نسخ رابط تسجيل الدخول إلى الحافظة';

  @override
  String get agentLoginTerminalCopyAll => 'نسخ كل المخرجات';

  @override
  String get agentLoginTerminalCopiedAll => 'تم نسخ مخرجات الطرفية إلى الحافظة';

  @override
  String get sshStatusReconnected => 'تمت استعادة الاتصال';

  @override
  String get sshStatusDisconnectedRetrying =>
      'فُقد الاتصال، جارٍ إعادة المحاولة';

  @override
  String get sshStatusDisconnectedManual => 'تم قطع الاتصال';

  @override
  String get sshStatusHostKeyChanged => 'تغير مفتاح المضيف — تم رفض الاتصال';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla يحافظ على استمرار جلساتك';

  @override
  String get terminalTmuxMissingNotice =>
      'لم يتم العثور على tmux — لن تصمد الجلسات بعد الانقطاع';

  @override
  String get terminalTmuxSessionRestored => 'تمت استعادة جلسة الطرفية';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'تمكين Mosh — طرفية متجولة تصمد أمام انقطاع الاتصال وتغيرات IP';

  @override
  String get moshServerPathLabel => 'مسار mosh-server';

  @override
  String get moshPortRangeLabel => 'نطاق منافذ UDP';

  @override
  String get moshNewSession => 'جلسة Mosh جديدة';

  @override
  String get moshNotInstalled =>
      'لم يتم العثور على mosh-server على الخادم البعيد. قم بتثبيته عبر: sudo apt install mosh (Debian/Ubuntu) أو sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'فشل بدء جلسة Mosh: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'انتهت مهلة اتصال Mosh — تأكد من أن حركة مرور UDP غير محظورة بجدار الحماية.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'تمت استعادة جلسة الوكيل';

  @override
  String get acpSessionRestartNotice =>
      'تمت إعادة تشغيل جلسة الوكيل — السياق السابق غير متوفر';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'هل تريد تثبيت tmux على الخادم البعيد؟';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'يلزم وجود tmux للحفاظ على جلسات الطرفية عبر فترات انقطاع الاتصال. هل ترغب في تثبيته الآن؟';

  @override
  String get terminalTmuxInstallCommandLabel => 'الأمر المراد تنفيذه:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'لم يتم اكتشاف مدير حزم مدعوم على الخادم البعيد. يرجى تثبيت tmux يدوياً.';

  @override
  String get terminalTmuxInstallFailed =>
      'فشل تثبيت tmux. يرجى التحقق من أذونات الخادم والشبكة.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'فُقد اتصال SSH. يرجى إعادة الاتصال لتثبيت tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'جارٍ تثبيت tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'تثبيت tmux';

  @override
  String get terminalTmuxInstallSkip => 'تخطي (استخدام الصدفة العادية)';

  @override
  String get sftpDownload => 'تنزيل';

  @override
  String get sftpOpen => 'فتح';

  @override
  String get sftpUploadFailed => 'فشل الرفع. تحقق من الأذونات وحاول مرة أخرى.';

  @override
  String get sftpDownloadFailed => 'فشل التنزيل';

  @override
  String get sftpOpenUnsupported => 'لا يمكن فتح هذا التنسيق من الملفات.';

  @override
  String get sftpReadFailed =>
      'فشلت قراءة الملف. تحقق من الأذونات وحاول مرة أخرى.';

  @override
  String get sftpTransferFailed => 'فشلت عملية الملف. يرجى المحاولة مرة أخرى.';

  @override
  String get sftpDownloadSuccess => 'تم التنزيل بنجاح';

  @override
  String get sftpUploading => 'جارٍ الرفع...';

  @override
  String get sftpDownloading => 'جارٍ التنزيل...';

  @override
  String get sftpUpDirectory => 'الانتقال إلى المجلد الأصلي';

  @override
  String get sftpShowHiddenFiles => 'إظهار الملفات المخفية';

  @override
  String get sftpHideHiddenFiles => 'إخفاء الملفات المخفية';

  @override
  String get sftpHiddenPreferenceSaveFailed => 'فشل حفظ تفضيل الملفات المخفية';

  @override
  String get sftpViewModeList => 'عرض القائمة';

  @override
  String get sftpViewModeGrid => 'عرض الشبكة';

  @override
  String get sftpViewPreferenceSaveFailed => 'فشل حفظ تفضيل وضع العرض';

  @override
  String get sftpSymlink => 'رابط رمزي';

  @override
  String get sftpLinkTargetUnavailable => 'هدف الرابط الرمزي تالف أو غير متوفر';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'تم رفض الإذن للوصول إلى هدف الرابط الرمزي';

  @override
  String get settingsAutoConnect => 'الاتصال التلقائي عند التشغيل';

  @override
  String get settingsAutoConnectFixed => 'خادم SSH افتراضي محدد';

  @override
  String get settingsAutoConnectFixedDesc =>
      'الاتصال دائماً بالخادم الذي تختاره أدناه';

  @override
  String get settingsAutoConnectLast => 'تذكر آخر اتصال';

  @override
  String get settingsAutoConnectLastDesc =>
      'الاتصال بآخر خادم تم الاتصال به بنجاح';

  @override
  String get settingsAutoConnectPickServer => 'الخادم';

  @override
  String get settingsAutoConnectNoServer => 'لم يتم تحديد خادم بعد';

  @override
  String get sftpSort => 'فرز';

  @override
  String get sftpSortName => 'الاسم';

  @override
  String get sftpSortSize => 'الحجم';

  @override
  String get sftpSortDate => 'تاريخ التعديل';

  @override
  String get sftpSortAscending => 'تصاعدي';

  @override
  String get sftpSortDescending => 'تنازلي';

  @override
  String get themeQuickSwitch => 'السمة';

  @override
  String get transferList => 'عمليات النقل';

  @override
  String get transferEmpty => 'لا توجد عمليات نقل حتى الآن';

  @override
  String get transferUpload => 'رفع';

  @override
  String get transferDownload => 'تنزيل';

  @override
  String get transferStatusQueued => 'في قائمة الانتظار';

  @override
  String get transferStatusRunning => 'جارٍ النقل';

  @override
  String get transferStatusPaused => 'موقف مؤقتاً';

  @override
  String get transferStatusCompleted => 'اكتمل';

  @override
  String get transferStatusFailed => 'فشل';

  @override
  String get transferStatusCanceled => 'ملغى';

  @override
  String get transferPause => 'إيقاف مؤقت';

  @override
  String get transferResume => 'استئناف';

  @override
  String get transferCancel => 'إلغاء';

  @override
  String get transferRemove => 'إزالة';

  @override
  String get transferClearFinished => 'مسح المكتملة';

  @override
  String get transferSizeUnknown => 'الحجم غير معروف';

  @override
  String get transferFailedUpload => 'فشل الرفع';

  @override
  String get transferFailedDownload => 'فشل التنزيل';

  @override
  String get transferPhasePreparing => 'جارٍ التحضير...';

  @override
  String get transferPhaseVerifyingPartial => 'جارٍ التحقق من الملف الجزئي...';

  @override
  String get transferPhaseVerifying => 'جارٍ التحقق من التكامل...';

  @override
  String get stopGeneration => 'إيقاف';

  @override
  String get chatServerBindingRequired =>
      'هذه الجلسة غير مرتبطة بخادم. يرجى ربطها بالخادم الحالي للمتابعة.';

  @override
  String get chatSessionUnboundNotice => 'هذه الجلسة غير مرتبطة بأي خادم.';

  @override
  String get bindServerAction => 'ربط الخادم';

  @override
  String get bindServerDialogTitle => 'ربط الجلسة بالخادم';

  @override
  String get bindServerConfirmAction => 'تأكيد الربط';

  @override
  String get chatSessionIdentityMismatch =>
      'الخادم الحالي أو الوكيل لا يطابق الهوية المرتبطة بهذه الجلسة. قم بالتبديل إلى الخادم والوكيل المطابقين للمتابعة.';

  @override
  String get deleteSessionTitle => 'حذف الجلسة';

  @override
  String get deleteSessionConfirmAction => 'حذف';

  @override
  String get shareAgentSessionsTitle => 'مشاركة جلسات الوكيل';

  @override
  String get shareAgentSessionsSubtitle =>
      'مشاركة الجلسات عبر وكلاء مختلفين على هذا الخادم';

  @override
  String get shareAgentSessionsEnabled => 'تم تمكين مشاركة جلسات الوكيل';

  @override
  String get shareAgentSessionsDisabled => 'تم تعطيل مشاركة جلسات الوكيل';

  @override
  String get agentCliStatusInstalled => 'CLI: مثبت';

  @override
  String get agentCliStatusMissing => 'CLI: مفقود';

  @override
  String get agentCliStatusChecking => 'CLI: جارٍ الفحص...';

  @override
  String get agentCliStatusUnknown => 'CLI: غير معروف';

  @override
  String get agentCliStatusError => 'CLI: خطأ';

  @override
  String get agentAcpStatusReady => 'ACP: جاهز';

  @override
  String get agentAcpStatusMissing => 'ACP: مفقود';

  @override
  String get agentAcpStatusChecking => 'ACP: جارٍ الفحص...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: بانتظار CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: غير معروف';

  @override
  String get agentAcpStatusError => 'ACP: خطأ';

  @override
  String get agentAcpStatusNa => 'ACP: غير متاح';

  @override
  String get agentAuthStatusAuthenticated => 'المصادقة: مسجل الدخول';

  @override
  String get agentAuthStatusUnauthenticated => 'المصادقة: غير مسجل الدخول';

  @override
  String get agentAuthStatusUnknown => 'المصادقة: غير معروف';

  @override
  String get downloadNotificationsUnavailable =>
      'إشعارات تنزيل النظام غير متوفرة. تستمر التنزيلات في الخلفية.';

  @override
  String get downloadOpenFailed => 'فشل فتح الملف المنزّل.';

  @override
  String get dockerActionPending =>
      'هناك إجراء قيد التنفيذ بالفعل لهذه الحاوية';

  @override
  String get dockerNoLogs => '(لا توجد سجلات)';

  @override
  String get serverReboot => 'إعادة تشغيل الخادم';

  @override
  String get serverRebootDialogTitle => 'تأكيد إعادة تشغيل الخادم';

  @override
  String get serverRebootDialogMessage =>
      'هل أنت متأكد أنك تريد إعادة تشغيل هذا الخادم؟ سيتم إنهاء جميع الاتصالات النشطة والخدمات في الخلفية.';

  @override
  String get serverRebootConfirmButton => 'إعادة التشغيل الآن';

  @override
  String get serverRebootPasswordTitle => 'مطلوب كلمة مرور Sudo';

  @override
  String get serverRebootPasswordMessage =>
      'امتيازات الجذر مطلوبة لإعادة تشغيل الخادم. يرجى إدخال كلمة مرور sudo (تستخدم لمرة واحدة ولا تحفظ):';

  @override
  String get serverRebootPasswordHint => 'كلمة مرور Sudo';

  @override
  String get serverRebootSubmitting => 'جارٍ إرسال أمر إعادة التشغيل...';

  @override
  String get serverRebootAccepted =>
      'تم قبول أمر إعادة التشغيل؛ لم يتم التحقق من الاكتمال بعد. يرجى إعادة الاتصال عندما يعود الخادم إلى الاتصال.';

  @override
  String get serverRebootVerified =>
      'تم التحقق من إعادة تشغيل الخادم؛ عاد النظام إلى العمل.';

  @override
  String get serverRebootUnknown =>
      'نتيجة إعادة التشغيل غير مؤكدة. تم إرسال الأمر ولكن تعذر تأكيد الاكتمال. يرجى فحص الاتصال يدوياً.';

  @override
  String get serverRebootReconnect => 'إعادة الاتصال';

  @override
  String get serverRebootServerChanged =>
      'تم تغيير الخادم المستهدف، تم إلغاء إعادة التشغيل';

  @override
  String get navCliChat => 'محادثة CLI';

  @override
  String get cliChatTitle => 'جلسات CLI';

  @override
  String get cliChatSubtitle => 'جلسات وكيل CLI الأصلية على الخادم البعيد';

  @override
  String get cliSelectAgent => 'اختر الوكيل';

  @override
  String get cliNoAgentsConfigured => 'لم تتم إضافة وكلاء لهذا الخادم';

  @override
  String get cliAgentNeedsSetup => 'بيئة الوكيل مفقودة أو لم يتم تسجيل الدخول';

  @override
  String get cliManageAgentsGuide => 'قم بالتكوين في إدارة الوكلاء';

  @override
  String get cliNewDraft => 'مسودة جديدة';

  @override
  String get cliNewDraftTooltip =>
      'إنشاء مسودة فارغة (يتم إنشاء الجلسة عند أول رسالة)';

  @override
  String get cliDeleteSessionTitle => 'حذف سجل جلسة CLI البعيدة';

  @override
  String get cliDeleteSessionMessage =>
      'سيؤدي هذا إلى حذف سجل جلسة CLI نهائياً على الخادم البعيد. هل أنت متأكد من المتابعة؟';

  @override
  String get cliDeleteConfirmButton => 'حذف الجلسة';

  @override
  String get cliCannotDeleteTooltip => 'حذف الجلسة البعيدة غير مدعوم أو معطل';

  @override
  String get cliSessionsHeader => 'الجلسات';

  @override
  String get cliNoSessions => 'لم يتم العثور على جلسات CLI';

  @override
  String get cliFilterCwdHint => 'تصفية حسب مسار دليل العمل...';

  @override
  String get cliFilterCwdAction => 'تصفية';

  @override
  String get cliClearCwdAction => 'مسح';

  @override
  String get cliLoadMoreSessions => 'تحميل المزيد من الجلسات';

  @override
  String get cliRefreshSessions => 'تحديث';

  @override
  String get cliClaudeReadOnlyNotice =>
      'سجل Claude للقراءة فقط. تابع المحادثة في الطرفية الحقيقية.';

  @override
  String get cliContinueInTerminal => 'المتابعة في الطرفية';

  @override
  String get cliOpenTerminal => 'فتح الطرفية';

  @override
  String get cliCloseTerminal => 'إغلاق الطرفية';

  @override
  String get cliTerminalRunning => 'طرفية CLI التفاعلية';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'لا يدعم هذا الوكيل مزامنة السجل المنظم. يرجى استخدام طرفية CLI الأصلية للتفاعل واختيار الجلسات.';

  @override
  String get cliInstallSdkTitle => 'تثبيت Claude History SDK الرسمي';

  @override
  String get cliInstallSdkMessage =>
      'حزمة Claude Code History SDK الرسمية مفقودة على الخادم البعيد. هل ترغب في تثبيتها الآن؟';

  @override
  String get cliInstallSdkAction => 'تثبيت SDK الرسمي';

  @override
  String get cliApprovalsTitle => 'الموافقات المعلقة';

  @override
  String get cliApprovalDetails => 'التفاصيل';

  @override
  String get cliApprovalAllow => 'سماح';

  @override
  String get cliApprovalDecline => 'رفض';

  @override
  String get cliInputHint => 'اكتب رسالة إلى وكيل CLI...';

  @override
  String get cliSend => 'إرسال';

  @override
  String get cliStop => 'إيقاف';

  @override
  String get cliBusy => 'العملية قيد التنفيذ، يرجى الانتظار...';

  @override
  String get cliDisconnected => 'SSH غير متصل';

  @override
  String get cliServerChanged => 'تم تغيير الخادم المستهدف';

  @override
  String get cliTurnFailed => 'فشل تنفيذ جولة CLI';

  @override
  String get cliUseTerminal => 'مطلوب موجه تفاعلي، يرجى فتح الطرفية للمتابعة';

  @override
  String get cliDeleteFailed => 'فشل حذف الجلسة البعيدة';

  @override
  String get cliDeleteUnsupported =>
      'حذف الجلسات البعيدة غير مدعوم بواسطة هذا الـ CLI';

  @override
  String get cliOperationFailed => 'فشلت عملية CLI';

  @override
  String get cliHistorySdkMissing =>
      'حزمة History SDK الرسمية مفقودة على الخادم';

  @override
  String get cliHistoryRuntimeMissing =>
      'يتطلب سجل Claude وجود Node.js/npm على الخادم. يرجى تثبيت Node.js يدوياً؛ لا يزال بإمكانك استخدام CLI الحقيقي في الطرفية.';

  @override
  String get cliLoginRequired =>
      'تسجيل دخول الوكيل مطلوب. يرجى تسجيل الدخول عبر إدارة الوكلاء.';

  @override
  String get cliNotInstalled =>
      'وكيل CLI غير مثبت. يرجى تثبيته عبر إدارة الوكلاء.';

  @override
  String get cliVersionUnsupported =>
      'إصدار وكيل CLI غير مدعوم. يرجى الترقية أو إعادة التثبيت عبر إدارة الوكلاء.';

  @override
  String get settingsNavigation => 'التنقل';

  @override
  String get settingsNavigationDesc =>
      'تكوين صفحة بدء التشغيل الافتراضية وشريط التنقل السفلي';

  @override
  String get settingsStartupPage => 'صفحة بدء التشغيل';

  @override
  String get settingsStartupPageDesc => 'الصفحة المعروضة عند فتح التطبيق';

  @override
  String get settingsBottomNav => 'شريط التنقل السفلي';

  @override
  String get settingsBottomNavDesc =>
      'تحديد الأقسام المعروضة في شريط الجوال السفلي (يدعم من 0 إلى 9 عناصر)';

  @override
  String get settingsResetSuccess =>
      'تمت استعادة جميع الإعدادات إلى الافتراضية';

  @override
  String get metricsTrendSubtitle => 'آخر ~3 دقائق (حتى 60 عينة)';

  @override
  String get metricsCurrent => 'الحالي';

  @override
  String get metricsPeak => 'الذروة';

  @override
  String get metricsValley => 'القاع';

  @override
  String get metricsTrendWaiting => 'جارٍ جمع بيانات المقاييس...';

  @override
  String get metricsTrendStopped => 'توقف جمع البيانات (SSH غير متصل)';

  @override
  String get dockerActionTerminal => 'طرفية Exec';

  @override
  String get dockerTerminalTitle => 'طرفية الحاوية';

  @override
  String get dockerTerminalNotRunning => 'الحاوية لا تعمل';

  @override
  String get setDefaultAgent => 'تعيين كافتراضي';

  @override
  String get defaultBadge => 'افتراضي';

  @override
  String get isDefaultAgent => 'الوكيل الافتراضي';

  @override
  String get setAsDefaultAgent => 'تعيين كوكيل افتراضي لهذا الخادم';

  @override
  String get agentGroupBasic => 'المعلومات الأساسية';

  @override
  String get agentGroupCommands => 'الأوامر';

  @override
  String get agentGroupAuth => 'التثبيت والمصادقة';

  @override
  String get agentPresetTitle => 'قالب مسبق الإعداد';

  @override
  String get resourceProcessList => 'العمليات';

  @override
  String get resourceDiskScanning =>
      'جارٍ فحص الدلائل الجذرية، قد يستغرق هذا بضع ثوانٍ...';

  @override
  String get resourceDiskScanPartial =>
      'تعذر فحص بعض الدلائل بسبب الأذونات أو انتهاء المهلة';

  @override
  String get resourceDiskDirectories => 'استهلاك دلائل المستوى الأعلى';

  @override
  String get resourceSortCpu => 'فرز حسب المعالج';

  @override
  String get resourceSortMemory => 'فرز حسب الذاكرة';

  @override
  String get resourceRss => 'ذاكرة RSS';

  @override
  String get resourceUsed => 'المستخدم';

  @override
  String get resourceAvailable => 'المتاح';

  @override
  String get resourceTotal => 'الإجمالي';

  @override
  String get settingsBottomNavOrderTitle =>
      'العناصر المحددة (اسحب لإعادة الترتيب)';

  @override
  String get langSystem => 'حسب النظام';

  @override
  String get serverFieldRequired => 'مطلوب';

  @override
  String get serverPortInvalid => 'يجب أن يكون المنفذ بين 1 و 65535';

  @override
  String get serverTestReachability => 'اختبار إمكانية الوصول';

  @override
  String get serverSaveFailedGeneric =>
      'فشل حفظ الخادم. يرجى التحقق من الإعدادات وإعادة المحاولة.';

  @override
  String get serverViewPrivateKey => 'عرض المفتاح الخاص';

  @override
  String get serverHidePrivateKey => 'إخفاء المفتاح الخاص';

  @override
  String get dockerBashFallbackNotice =>
      'Bash غير متوفر في الحاوية، جارٍ الرجوع إلى Sh';

  @override
  String get dockerShellLabel => 'الصدفة';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'دليل العمل';

  @override
  String get cliDefaultWorkingDir => 'الافتراضي (/)';

  @override
  String get cliPickWorkingDirTitle => 'اختر دليل العمل';

  @override
  String get cliClearWorkingDir => 'إعادة التعيين للافتراضي';

  @override
  String get cliBrowseWorkingDir => 'استعراض';

  @override
  String get cliSelectCurrentDir => 'اختيار هذا الدليل';

  @override
  String get cliNavigateUp => 'الانتقال للأعلى';

  @override
  String get chatSessionsTooltip => 'الجلسات';

  @override
  String get hardwareSpecsTitle => 'العتاد والنظام';

  @override
  String get hardwareCpu => 'المعالج';

  @override
  String get hardwareMemory => 'الذاكرة';

  @override
  String get hardwareDisk => 'القرص الجذري';

  @override
  String get hardwareDistribution => 'نظام التشغيل';

  @override
  String get hardwareKernel => 'النواة';

  @override
  String get hardwareLoading => 'جارٍ تحميل مواصفات العتاد...';

  @override
  String get hardwareUnavailable => 'مواصفات العتاد غير متوفرة';

  @override
  String get hardwareUnknown => 'غير معروف';

  @override
  String get systemInfoTitle => 'معلومات النظام';

  @override
  String get systemInfoTapHint => 'انقر لعرض فن ASCII';

  @override
  String get systemInfoHost => 'المضيف';

  @override
  String get serverShutdown => 'إيقاف التشغيل';

  @override
  String get serverShutdownDialogTitle => 'تأكيد إيقاف تشغيل الخادم';

  @override
  String get serverShutdownDialogMessage =>
      'هل أنت متأكد من رغبتك في إيقاف تشغيل هذا الخادم؟ سيتم إيقاف تشغيل النظام بالكامل ولا يمكن الوصول إليه عن بُعد حتى يتم تشغيله يدوياً.';

  @override
  String get serverShutdownConfirmButton => 'إيقاف التشغيل الآن';

  @override
  String get serverShutdownSubmitting => 'جارٍ إرسال أمر إيقاف التشغيل...';

  @override
  String get serverShutdownAccepted =>
      'تم قبول أمر إيقاف التشغيل؛ لم يتم التحقق من اكتمال إيقاف التشغيل.';

  @override
  String get serverShutdownUnknown =>
      'نتيجة إيقاف التشغيل غير معروفة: قد يكون الأمر قد أُرسل ولكن تعذر تأكيده. يرجى التحقق يدوياً؛ لن تتم إعادة المحاولة تلقائياً.';

  @override
  String get serverShutdownPasswordTitle =>
      'مطلوب كلمة مرور Sudo لإيقاف التشغيل';

  @override
  String get serverShutdownPasswordMessage =>
      'امتيازات الجذر مطلوبة لإيقاف تشغيل الخادم. يرجى إدخال كلمة مرور sudo (تستخدم لمرة واحدة ولا تحفظ):';

  @override
  String get serverShutdownPasswordHint => 'كلمة مرور Sudo';

  @override
  String get serverShutdownServerChanged =>
      'تم تغيير الخادم المستهدف، تم إلغاء إيقاف التشغيل';

  @override
  String get metricsNetwork => 'معدل الشبكة';

  @override
  String get networkModalTitle => 'تفاصيل واجهات الشبكة';

  @override
  String get networkDownloadRate => 'التنزيل (RX)';

  @override
  String get networkUploadRate => 'الرفع (TX)';

  @override
  String get networkTotalRx => 'إجمالي RX';

  @override
  String get networkTotalTx => 'إجمالي TX';

  @override
  String get networkPrimary => 'المسار الافتراضي';

  @override
  String get networkRatesEmpty => 'لم يتم اكتشاف واجهات شبكة نشطة';

  @override
  String get networkWaitingSecondSample => 'في انتظار العينة الثانية';

  @override
  String get networkUnavailable => 'غير متوفر';

  @override
  String get networkNoDefaultInterface => 'لا يوجد مسار افتراضي';

  @override
  String get selectThemeModeTitle => 'اختر وضع السمة';

  @override
  String get selectLanguageTitle => 'اختر اللغة';

  @override
  String get selectStartupPageTitle => 'اختر صفحة البدء';

  @override
  String get selectAutoConnectModeTitle => 'اختر وضع الاتصال التلقائي';

  @override
  String get accentColorDialogTitle => 'تخصيص ألوان التمييز';

  @override
  String get accentColorLightMode => 'الوضع الفاتح';

  @override
  String get accentColorDarkMode => 'الوضع الداكن';

  @override
  String get accentColorAmoledMode => 'AMOLED (تقني)';

  @override
  String get accentColorPresets => 'الإعدادات المسبقة';

  @override
  String get accentColorHsvPicker => 'عجلة الألوان';

  @override
  String get accentColorHexCode => 'رمز اللون الست عشري';

  @override
  String get accentColorPreview => 'معاينة';

  @override
  String get accentColorSampleButton => 'زر عينة التمييز';

  @override
  String get accentColorInvalidHex => 'تنسيق ست عشري غير صالح (مثال: #10B981)';

  @override
  String get settingsDashboardQuickActions => 'إجراءات لوحة القيادة السريعة';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'تكوين اختصارات الوصول السريع المعروضة على لوحة القيادة. سيؤدي المسح إلى إخفاء قسم الإجراءات السريعة.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'الإجراءات السريعة مخفية (لم يتم تحديد اختصارات)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'اسحب لإعادة ترتيب الاختصارات';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'حدد الاختصارات المرئية';

  @override
  String get terminalCopySelection => 'نسخ';

  @override
  String get terminalSelectionCopied => 'تم نسخ التحديد إلى الحافظة';

  @override
  String get editAgent => 'تعديل الوكيل';

  @override
  String get agentExecutionTarget => 'بيئة التنفيذ';

  @override
  String get agentExecutionHost => 'النظام المضيف';

  @override
  String get agentExecutionDocker => 'حاوية Docker';

  @override
  String get agentContainerBinding => 'وضع ربط الحاوية';

  @override
  String get agentContainerBindingId => 'حسب معرف الحاوية';

  @override
  String get agentContainerBindingName => 'حسب اسم الحاوية';

  @override
  String get agentContainerReference => 'الحاوية المستهدفة';

  @override
  String get agentContainerReferenceHint => 'حدد أو أدخل معرف الحاوية أو اسمها';

  @override
  String get agentContainerRequired => 'الحاوية المستهدفة مطلوبة لتنفيذ Docker';

  @override
  String get agentLoadingContainers =>
      'جارٍ الاستعلام عن الحاويات على الخادم...';

  @override
  String get agentNoContainersFound =>
      'لم يتم العثور على حاويات على هذا الخادم';

  @override
  String get agentContainerUser => 'مستخدم تنفيذ الحاوية (اختياري)';

  @override
  String get agentContainerUserHint => 'مثال: dev';

  @override
  String get agentContainerUserHelper =>
      'اتركه فارغاً لاستخدام المستخدم الافتراضي للصورة؛ مثال: dev؛ يدعم user أو UID أو user:group أو UID:GID';

  @override
  String get agentContainerUserSelect => 'اختر مستخدم الحاوية';

  @override
  String get agentContainerUsersLoading => 'جارٍ تحميل المستخدمين...';

  @override
  String get agentContainerUsersEmpty => 'لم يتم العثور على مستخدمين في passwd';

  @override
  String get agentViewDiagnosticLog => 'عرض سجل التشخيص';

  @override
  String get agentDiagnosticLogCopied => 'تم نسخ سجل التشخيص إلى الحافظة';

  @override
  String get agentDiagnosticLogCopy => 'نسخ';

  @override
  String get agentDiagnosticLogClose => 'إغلاق';

  @override
  String get settingsCliHistoryPageSize => 'حجم صفحة سجل CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'عدد الرسائل القديمة المحملة في كل صفحة عند التمرير لأعلى (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle => 'اختر حجم صفحة سجل CLI';

  @override
  String get cliLoadingOlderMessages => 'جارٍ تحميل الرسائل الأقدم...';

  @override
  String get chatLoadOlderMessages => 'تحميل الرسائل السابقة';

  @override
  String get chatCommandsTooltip => 'الأوامر';

  @override
  String get chatAttachTooltip => 'إرفاق ملف';

  @override
  String get chatAttachImage => 'إرفاق صورة محلية';

  @override
  String get chatAttachLocalText => 'إرفاق ملف نصي محلي';

  @override
  String get chatAttachRemoteText => 'إرفاق ملف نصي بعيد';

  @override
  String get chatAttachRemotePathTitle => 'إرفاق ملف نصي بعيد';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => 'يتجاوز الملف الحد الأقصى للحجم';

  @override
  String get chatUsageAndDiagnostics => 'الاستخدام والتشخيص';

  @override
  String get chatWorkingDirTooltip => 'دليل عمل المسودة';

  @override
  String get chatAttachFailed => 'فشل إرفاق الملف';

  @override
  String get chatInvalidRemotePath =>
      'مسار ملف بعيد غير صالح (يجب أن يبدأ بـ /)';

  @override
  String get chatRemoteReadFailed => 'فشلت قراءة الملف البعيد';

  @override
  String get chatInvalidDirPath => 'مسار دليل غير صالح (يجب أن يبدأ بـ /)';

  @override
  String get chatNoSubdirectories => 'لا توجد أدلة فرعية';

  @override
  String get chatUsageTitle => 'استهلاك الرموز والتكلفة';

  @override
  String get chatUsageUsed => 'الرموز المستخدمة';

  @override
  String get chatUsageSize => 'حجم السياق';

  @override
  String get chatUsageCost => 'التكلفة';

  @override
  String get chatDiagnosticsTitle => 'سجل التشخيص';

  @override
  String get chatNoDiagnostics => 'لا توجد سجلات تشخيص متاحة';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'يؤدي هذا فقط إلى إزالة السجل المحلي في Valhalla ولن يحذف سجل جلسة الوكيل الأصلية على الخادم.';

  @override
  String get chatSearchSessionsHint => 'البحث في الجلسات...';

  @override
  String get chatLoadMoreSessions => 'تحميل المزيد من الجلسات';

  @override
  String get chatLoadingMoreSessions => 'جارٍ تحميل المزيد من الجلسات...';

  @override
  String get chatExportSession => 'تصدير الجلسة (Markdown)';

  @override
  String get chatExportSuccess => 'تم تصدير الجلسة بنجاح';

  @override
  String get chatExportFailed => 'فشل تصدير الجلسة';

  @override
  String get chatRemoteSessions => 'الجلسات البعيدة';

  @override
  String get chatRemoteSessionsTitle => 'جلسات الوكيل البعيدة';

  @override
  String get chatRemoteSessionsDesc =>
      'عرض واستيراد سجل الجلسات الأصلي من الوكيل البعيد';

  @override
  String get chatRemoteSessionsEmpty => 'لم يتم العثور على جلسات بعيدة';

  @override
  String get chatRemoteImporting => 'جارٍ استيراد سجل الجلسة البعيدة...';

  @override
  String get chatRemoteImportFailed => 'فشل استيراد الجلسة البعيدة';

  @override
  String get chatStatusInterrupted => 'تمت المقاطعة';

  @override
  String get chatStatusFailed => 'فشل';

  @override
  String get chatStatusAwaitingAuth => 'بانتظار مصادقة ACP';

  @override
  String get chatShowFullOutput => 'عرض المخرجات كاملة';

  @override
  String get chatShowLessOutput => 'عرض أقل';

  @override
  String get chatToolLocations => 'المسارات المتأثرة';

  @override
  String cmdParamPlaceholder(String param) {
    return 'أدخل القيمة لـ $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'تم إنهاء العملية $pid';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'نجح الإجراء $action على $service';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'القاعدة المطابقة: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'رمز الخروج: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'تم الاتصال بنجاح بـ $server عبر SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'فشل اتصال SSH: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'الاتصال بـ $host ($type) لأول مرة.\n\nبصمة SHA-256:\n$fingerprint\n\nهل تثق في هذه البصمة وتتصل؟';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'أدخل كلمة المرور لـ $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'هل أنت متأكد من حذف الخادم \'$name\'؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'هل أنت متأكد من حذف الوكيل \'$name\'؟ يؤدي هذا إلى إزالة تكوينه وحالة التشغيل على هذا الخادم دون التأثير على جلسات المحادثة السابقة أو بيانات اعتماد SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'آخر فحص: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'اختر طريقة تسجيل الدخول إلى $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'جارٍ إعادة الاتصال… (المحاولة $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n جلسة (جلسات) نشطة';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'هل تريد ربط هذه الجلسة بالخادم \"$serverName\"؟ بمجرد الربط، ستكون الجلسة مرتبطة بهذا الخادم.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'هل أنت متأكد من حذف الجلسة \"$title\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'نجح الإجراء $action للحاوية $name';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'فشل الإجراء: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'الخادم المستهدف: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'جلسات الطرفية: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'جلسات الوكيل: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'عمليات النقل النشطة: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'فشلت إعادة التشغيل: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'فشل حذف الجلسة البعيدة: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'اتجاه $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'تحذير: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'خطر: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count نقطة بيانات';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'استهلاك المورد $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'منفذ TCP $port متاح للوصول';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'فشل الاتصال: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'فشل حفظ الخادم: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores أنوية';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'فشل إيقاف التشغيل: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'الواجهة: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'فشل تحميل الحاويات: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'فشل تحميل مستخدمي الحاوية: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'سجل التشخيص - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'فشل اكتشاف Docker/الحاويات';

  @override
  String get chatCopiedAllMessages => 'تم نسخ جميع الرسائل';

  @override
  String get chatCopyAllMessages => 'نسخ جميع الرسائل';

  @override
  String get cliModelAtCapacity =>
      'النموذج المحدد بكامل طاقته الاستيعابية. جرب نموذجاً آخر.';

  @override
  String get chatLaunchBlankDraft => 'مسودة فارغة';

  @override
  String get chatLaunchFixedSession => 'جلسة محددة';

  @override
  String get chatLaunchRememberLast => 'تذكر آخر جلسة';

  @override
  String get chatPermissionAskEveryTime => 'السؤال في كل مرة';

  @override
  String get chatPermissionAutoAllowAll => 'السماح للكل تلقائياً';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'سيقوم الوكيل بتنفيذ جميع العمليات دون سؤال. هل تريد المتابعة؟';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle => 'السماح بجميع العمليات؟';

  @override
  String get chatPermissionAutoAllowSafe => 'السماح بالعمليات الآمنة تلقائياً';

  @override
  String get chatRunSettingsDefault => 'افتراضي';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI تفاعلي';

  @override
  String get chatRunSettingsModel => 'النموذج';

  @override
  String get chatRunSettingsPermissions => 'الأذونات';

  @override
  String get chatRunSettingsReasoning => 'مستوى الاستدلال';

  @override
  String get chatRunSettingsTitle => 'إعدادات التشغيل';

  @override
  String get cliActionInsertCommand => 'إدراج أمر';

  @override
  String get cliActionInsertFile => 'إدراج ملف';

  @override
  String get cliActionInsertWorkdir => 'إدراج دليل العمل';

  @override
  String get cliComposerInsertAction => 'إدراج';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'فشلت عملية CLI: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'اختر الأمر';

  @override
  String get defaultAgentTitle => 'الوكيل الافتراضي';

  @override
  String get insertSkills => 'إدراج المهارات';

  @override
  String get isDefaultSession => 'الجلسة الافتراضية';

  @override
  String get sessionLaunchMode => 'وضع بدء تشغيل الجلسة';

  @override
  String get setAsDefaultSession => 'تعيين كجلسة افتراضية';

  @override
  String get navNas => 'وسائط NAS';

  @override
  String get nasAddExcludePath => 'إضافة مسار مستبعد';

  @override
  String get nasAddIncludePath => 'إضافة مسار فحص';

  @override
  String get nasCancelScan => 'إلغاء الفحص';

  @override
  String get nasClearSearch => 'مسح البحث';

  @override
  String get nasConfigDialogTitle => 'إعدادات مكتبة الوسائط';

  @override
  String get nasConfigure => 'تكوين';

  @override
  String get nasConfigureScanDirs => 'تكوين مجلدات الفحص';

  @override
  String get nasCreatePlaylist => 'إنشاء قائمة تشغيل';

  @override
  String get nasEmptyConfigDesc =>
      'أضف مجلداً واحداً على الأقل لبدء بناء مكتبة الوسائط الخاصة بك.';

  @override
  String get nasEmptyConfigTitle => 'لم يتم تكوين مجلدات فحص';

  @override
  String get nasExcludePaths => 'المجلدات المستبعدة';

  @override
  String get nasExcludedBadge => 'مستبعد';

  @override
  String get nasFilterImages => 'الصور';

  @override
  String get nasFilterVideos => 'مقاطع الفيديو';

  @override
  String get nasIncludePaths => 'مجلدات الفحص';

  @override
  String nasItemCount(Object value) {
    return '$value عنصر';
  }

  @override
  String nasLastScan(Object value) {
    return 'آخر فحص: $value';
  }

  @override
  String get nasLibrarySettings => 'إعدادات المكتبة';

  @override
  String nasMediaOpening(Object value) {
    return 'جارٍ فتح $value…';
  }

  @override
  String get nasMiniPlayer => 'مشغل مصغر';

  @override
  String get nasNoExcludePaths => 'لا توجد مجلدات مستبعدة';

  @override
  String get nasNoFavorites => 'لا توجد مفضلات حتى الآن';

  @override
  String get nasNoIncludePaths => 'لا توجد مجلدات فحص';

  @override
  String get nasNoIndexDesc => 'قم بتكوين المجلدات وتشغيل الفحص لفهرسة وسائطك.';

  @override
  String get nasNoIndexTitle => 'مكتبة الوسائط فارغة';

  @override
  String get nasNoPlaylists => 'لا توجد قوائم تشغيل حتى الآن';

  @override
  String get nasNoSearchResults => 'لا توجد وسائط مطابقة';

  @override
  String get nasNotScanned => 'لم يتم الفحص بعد';

  @override
  String get nasNowPlaying => 'قيد التشغيل الآن';

  @override
  String get nasOpenMethodPrompt => 'كيف ترغب في فتح هذا الملف؟';

  @override
  String get nasOpenPolicyAsk => 'السؤال في كل مرة';

  @override
  String get nasOpenPolicyExternal => 'فتح بواسطة تطبيق آخر';

  @override
  String get nasOpenPolicyInApp => 'فتح داخل التطبيق';

  @override
  String get nasOpeningPolicy => 'طريقة الفتح الافتراضية';

  @override
  String get nasPlaylistName => 'اسم قائمة التشغيل';

  @override
  String get nasQuickStats => 'نظرة عامة على المكتبة';

  @override
  String get nasScan => 'فحص الآن';

  @override
  String get nasScanCancelled => 'تم إلغاء الفحص';

  @override
  String nasScanFailed(Object value) {
    return 'فشل الفحص: $value';
  }

  @override
  String get nasScanning => 'جارٍ الفحص…';

  @override
  String get nasScopeBadge => 'نطاق الفحص';

  @override
  String get nasSearchHint => 'البحث في الوسائط';

  @override
  String get nasStatMusic => 'الموسيقى';

  @override
  String get nasStatPhotos => 'الصور';

  @override
  String get nasStatTotal => 'الإجمالي';

  @override
  String get nasStatVideos => 'مقاطع الفيديو';

  @override
  String get nasTabFavorites => 'المفضلة';

  @override
  String get nasTabFolders => 'المجلدات';

  @override
  String get nasTabHome => 'الرئيسية';

  @override
  String get nasTabMusic => 'الموسيقى';

  @override
  String get nasTabPhotos => 'الصور';

  @override
  String get nasTabPlaylists => 'قوائم التشغيل';

  @override
  String get nasTabVideos => 'الفيديو';

  @override
  String get nasSources => 'مصادر الوسائط';

  @override
  String get nasAddSource => 'إضافة مصدر وسائط';

  @override
  String get nasEditSource => 'تعديل مصدر الوسائط';

  @override
  String get nasRemoveSource => 'إزالة مصدر الوسائط';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'هل أنت متأكد من رغبتك في إزالة مصدر الوسائط \'$name\'؟ يؤدي هذا إلى إزالة تكوينه دون حذف الملفات البعيدة.';
  }

  @override
  String get nasNoSources => 'لم يتم تكوين مصادر وسائط';

  @override
  String get nasNoSourcesDesc =>
      'أضف SFTP أو SMB أو WebDAV أو Jellyfin أو Emby لبدء تصفح الوسائط.';

  @override
  String get nasSourceType => 'نوع المصدر';

  @override
  String get nasSourceName => 'اسم المصدر';

  @override
  String get nasProbe => 'اختبار الاتصال';

  @override
  String get nasProbeSuccess => 'الاتصال ناجح';

  @override
  String get nasProbeFailed => 'فشل اختبار الاتصال';

  @override
  String get nasEndpoint => 'نقطة النهاية / الرابط';

  @override
  String get nasRootPath => 'المسار الجذري';

  @override
  String get nasUsername => 'اسم المستخدم';

  @override
  String get nasPassword => 'كلمة المرور';

  @override
  String get nasDomain => 'النطاق (اختياري)';

  @override
  String get nasAuthenticate => 'المصادقة';

  @override
  String get nasAuthSuccess => 'تمت المصادقة بنجاح';

  @override
  String get nasAuthFailed => 'فشلت المصادقة';

  @override
  String get nasTabDownloads => 'التنزيلات';

  @override
  String get nasNoDownloads => 'لا توجد مهام تنزيل';

  @override
  String get nasDownloadQueued => 'في قائمة الانتظار';

  @override
  String get nasDownloadDownloading => 'جارٍ التنزيل';

  @override
  String get nasDownloadCompleted => 'مكتمل';

  @override
  String get nasDownloadCancelled => 'ملغى';

  @override
  String get nasDownloadFailed => 'فشل التنزيل';

  @override
  String get nasRetryDownload => 'إعادة المحاولة';

  @override
  String get nasCancelDownload => 'إلغاء';

  @override
  String get nasOpenDownloadedFile => 'فتح الملف';

  @override
  String get nasQueue => 'قائمة التشغيل الحالية';

  @override
  String get nasNoQueue => 'قائمة التشغيل فارغة';

  @override
  String get nasSpeed => 'السرعة';

  @override
  String get nasQuality => 'الجودة';

  @override
  String get nasAudioTrack => 'المسار الصوتي';

  @override
  String get nasSubtitleTrack => 'الترجمة';

  @override
  String get nasRepeatOff => 'إيقاف التكرار';

  @override
  String get nasRepeatAll => 'تكرار الكل';

  @override
  String get nasRepeatOne => 'تكرار واحد';

  @override
  String get nasShuffle => 'خلط';

  @override
  String get nasCast => 'بث (Cast)';

  @override
  String get nasCastUnavailable => 'لا توجد أجهزة بث متاحة';

  @override
  String get nasSlideshow => 'عرض شرائح';

  @override
  String get nasByFolder => 'المجلدات';

  @override
  String get nasByArtist => 'الفنانون';

  @override
  String get nasByAlbum => 'الألبومات';

  @override
  String get nasAllTracks => 'جميع المقاطع';

  @override
  String get nasPlayAll => 'تشغيل الكل';

  @override
  String get nasPreviousPage => 'السابق';

  @override
  String get nasNextPage => 'التالي';

  @override
  String get nasClearScope => 'العودة للكل';

  @override
  String get nasRenamePlaylist => 'إعادة تسمية قائمة التشغيل';

  @override
  String get nasRemoveFromPlaylist => 'إزالة من قائمة التشغيل';

  @override
  String get nasMoveUp => 'تحريك لأعلى';

  @override
  String get nasMoveDown => 'تحريك لأسفل';

  @override
  String get nasSshServer => 'خادم SSH';

  @override
  String get nasSelectSshServer => 'اختر خادم SSH المحفوظ';

  @override
  String get nasQualityOriginal => 'الأصلي';

  @override
  String get nasQualityAuto => 'تلقائي';

  @override
  String get nasQuality4Mbps => '4 ميجابت/ث';

  @override
  String get nasQuality10Mbps => '10 ميجابت/ث';

  @override
  String get nasQuality20Mbps => '20 ميجابت/ث';

  @override
  String get nasCastDevices => 'أجهزة DLNA المتاحة';

  @override
  String get nasCastDiscovering => 'البحث عن أجهزة DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'يتم ترحيل البث عبر التطبيق في الواجهة. اترك Valhalla مفتوحاً.';

  @override
  String get nasCastStop => 'إيقاف البث';

  @override
  String get nasCastVolume => 'مستوى الصوت';

  @override
  String get nasCastRetry => 'إعادة محاولة البحث';

  @override
  String get nasInstallTitle => 'نشر خادم وسائط NAS';

  @override
  String get nasInstallProduct => 'المنتج';

  @override
  String get nasInstallMediaPath => 'دليل الوسائط (للقراءة فقط)';

  @override
  String get nasInstallDataRoot => 'دليل البيانات والتكوين';

  @override
  String get nasInstallPort => 'المنفذ';

  @override
  String get nasInstallBindAddress => 'عنوان الربط';

  @override
  String get nasInstallWebdavUser => 'اسم مستخدم WebDAV';

  @override
  String get nasInstallWebdavPassword => 'كلمة مرور WebDAV (12 حرفاً كحد أدنى)';

  @override
  String get nasInstallPreparePlan => 'مراجعة خطة النشر';

  @override
  String get nasInstallPlanTitle => 'المراجعة التقنية والتأكيد';

  @override
  String get nasInstallBlockersTitle => 'معوقات النشر';

  @override
  String get nasInstallConfirmDeploy => 'تأكيد وتثبيت';

  @override
  String get nasInstallDeploying => 'جارٍ نشر الحاوية...';

  @override
  String get nasInstallSuccess => 'تم النشر بنجاح';

  @override
  String get nasInstallSuccessDesc =>
      'الخدمة تعمل الآن. أكمل الإعداد الأولي للخادم قبل إضافته كمصدر وسائط.';

  @override
  String get nasInstallContainerId => 'معرف الحاوية';

  @override
  String get nasInstallEndpoint => 'نقطة النهاية';

  @override
  String get nasUseSshTunnel => 'استخدام نفق SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'توجيه حركة المرور عبر خادم SSH محفوظ (مثل: http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'يجب أن تكون نقطة النهاية قابلة للوصول من خادم SSH، مثل: http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'اتركه فارغاً للاحتفاظ بكلمة المرور / الرمز الحالي';

  @override
  String get nasSourceNameRequired => 'اسم المصدر مطلوب';

  @override
  String get nasInvalidEndpoint => 'رابط نقطة النهاية أو المخطط غير صالح';

  @override
  String get nasSourceUnreachable => 'تعذر الوصول إلى مصدر الوسائط';

  @override
  String get nasSshTunnelFailed => 'فشل اتصال نفق SSH';

  @override
  String get nasOperationFailed => 'فشلت العملية';

  @override
  String get nasInstallStepCreateDir => 'إنشاء الدليل الخاص';

  @override
  String get nasInstallStepWriteCompose => 'كتابة تكوين docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'كتابة بيانات الاعتماد الخاصة';

  @override
  String get nasInstallStepPullImage => 'سحب صورة الحاوية المثبتة';

  @override
  String get nasInstallStepStartService => 'بدء تشغيل الخدمة في الحاوية';

  @override
  String get nasInstallStepCheckHttp => 'فحص صحة HTTP للخدمة';

  @override
  String get nasInstallBlockerDocker => 'محرك Docker مطلوب على الخادم المستهدف';

  @override
  String get nasInstallBlockerCompose => 'المكوّن الإضافي Docker Compose مطلوب';

  @override
  String get nasInstallBlockerIdentity => 'تعذر التحقق من هوية الخادم المستهدف';

  @override
  String get nasInstallBlockerTools =>
      'الأدوات المطلوبة (curl, ss, realpath) مفقودة على الخادم المستهدف';

  @override
  String get nasInstallBlockerMedia =>
      'دليل الوسائط غير موجود أو غير قابل للقراءة';

  @override
  String get nasInstallBlockerParent =>
      'الدليل الأصلي لجذر البيانات غير قابل للكتابة';

  @override
  String get nasInstallBlockerOverlap =>
      'لا يمكن أن يتداخل دليل الوسائط مع دليل البيانات';

  @override
  String get nasInstallBlockerCollision =>
      'دليل البيانات المستهدف موجود بالفعل أو رابط رمزي';

  @override
  String get nasInstallBlockerPort =>
      'المنفذ المحدد قيد الاستخدام بالفعل على الخادم المستهدف';

  @override
  String get nasInstallBlockerContainer => 'توجد حاوية باسم هذا المشروع بالفعل';

  @override
  String get nasInstallBlockerImage =>
      'فشل التحقق من صورة الحاوية. تحقق من اسم الصورة والاتصال بالشبكة ومعمارية الخادم، ثم حاول ثانية.';

  @override
  String get nasInstallGuidanceTunnel =>
      'ربط الاسترجاع (127.0.0.1) يتطلب نفق SSH للوصول عن بُعد';

  @override
  String get nasInstallGuidanceTls =>
      'يوصى بتأمين الربط العام خلف وكيل عكسي بتشفير TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'أكمل إعداد حساب المسؤول الأولي في المتصفح عند أول تشغيل';

  @override
  String get nasInstallGuidanceReadOnly =>
      'يتم تركيب دليل الوسائط للقراءة فقط لحماية ملفاتك';

  @override
  String get nasInstallGuidancePreserved =>
      'سيتم الاحتفاظ بدليل البيانات عند الفشل للمساعدة في استكشاف الأخطاء';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'تم التنزيل (فشل الفتح بواسطة تطبيق خارجي)';

  @override
  String get nasRetryOpen => 'إعادة محاولة الفتح';

  @override
  String get nasExternalOpenFailed => 'فشل فتح الملف في التطبيق الخارجي';

  @override
  String get nasTitle => 'وسائط NAS';

  @override
  String get nasLoadMoreGroups => 'تحميل المزيد من المجموعات';

  @override
  String get nasMetadataEnriching => 'جارٍ إثراء وسوم الموسيقى...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'جارٍ إثراء وسوم الموسيقى (تمت معالجة $count)...';
  }

  @override
  String nasDownloading(String value) {
    return 'جارٍ تنزيل $value…';
  }

  @override
  String get nasSubtitleNone => 'بدون';

  @override
  String get nasLibraryId => 'معرف المكتبة';

  @override
  String get nasLibraryIdHint => 'افتراضي: الكل (/)، أو حدد معرف المكتبة';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'بالنسبة لجذر المصدر ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'تم تغيير المصدر أثناء التكوين، تم إلغاء الحفظ';

  @override
  String get nasInvalidLibraryId => 'معرف المكتبة غير صالح';

  @override
  String get startupFailed => 'فشل تشغيل التطبيق';

  @override
  String get startupFailedDesc =>
      'حدث خطأ غير متوقع أثناء بدء التشغيل. يمكنك إعادة المحاولة أو تصدير سجلات التشخيص.';

  @override
  String get retryStartup => 'إعادة محاولة التشغيل';

  @override
  String get viewDiagnostics => 'عرض التشخيصات';

  @override
  String get exportDiagnostics => 'تصدير التشخيصات';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'تم تصدير التشخيصات إلى $path';
  }

  @override
  String get diagnosticsExportFailed => 'فشل تصدير التشخيصات';

  @override
  String get diagnosticsTitle => 'تشخيصات التطبيق';

  @override
  String get settingsDiagnostics => 'التشخيصات والسجلات';

  @override
  String get settingsDiagnosticsDesc =>
      'عرض وتصدير سجلات التطبيق المحلية المنقحة';

  @override
  String get diagnosticsEmpty => 'لم يتم العثور على سجلات تشخيصية';

  @override
  String diagnosticsStorageError(String error) {
    return 'خطأ في تخزين التشخيصات: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'تم الإبلاغ عن حادثة قابلة للاسترداد: $category';
  }

  @override
  String get diagnosticsRefresh => 'تحديث السجلات';

  @override
  String get nasInstallTaskTitle => 'مهمة النشر';

  @override
  String get nasInstallStagePreflight => 'فحص ما قبل التشغيل';

  @override
  String get nasInstallStageReview => 'مراجعة الخطة';

  @override
  String get nasInstallStageWriting => 'كتابة التكوين';

  @override
  String get nasInstallStagePulling => 'سحب الصورة';

  @override
  String get nasInstallStageStarting => 'بدء تشغيل الحاوية';

  @override
  String get nasInstallStageHealth => 'فحص الصحة';

  @override
  String get nasInstallStageCleanup => 'جارٍ التنظيف';

  @override
  String get nasInstallStageSucceeded => 'نجح النشر';

  @override
  String get nasInstallStageFailed => 'فشل النشر';

  @override
  String get nasInstallStageCancelled => 'تم إلغاء النشر';

  @override
  String get nasInstallStageNeedsInspection => 'يتطلب الفحص';

  @override
  String get nasInstallStageReconciling => 'تسوية الحالة';

  @override
  String get nasInstallCancel => 'إلغاء النشر';

  @override
  String get nasInstallReconcile => 'تسوية الحالة';

  @override
  String get nasInstallServerNotFound => 'لم يتم العثور على الخادم المحدد';

  @override
  String get nasInstallPortRangeError => 'يجب أن يكون المنفذ بين 1 و 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'الوقت المنقضي: $time';
  }

  @override
  String get nasInstallLogTail => 'أحدث السجلات';

  @override
  String get nasInstallCleanupCompleted => 'اكتمل تنظيف التراجع';

  @override
  String get nasInstallCleanupIncomplete => 'تنظيف التراجع غير مكتمل';

  @override
  String get nasInstallNewDeployment => 'نشر جديد';

  @override
  String get nasInstallBackEdit => 'رجوع / تعديل النموذج';

  @override
  String get nasInstallClose => 'إغلاق';

  @override
  String get nasInstallMediaPathHint =>
      'تثبيت ربط للقراءة فقط على المضيف (مثل /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'دليل البيانات والتكوين الخاص (يجب ألا يكون موجوداً بعد)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 للنفق، 0.0.0.0 للشبكة المحلية LAN';

  @override
  String get nasInstallWebdavPasswordHint => 'يلزم 12 حرفاً كحد أدنى';

  @override
  String get nasInstallTargetServer => 'الخادم المستهدف';

  @override
  String get nasInstallTargetImage => 'الصورة المستهدفة';

  @override
  String get nasInstallContainerName => 'اسم الحاوية';

  @override
  String get nasInstallBindAndPort => 'الربط والمنفذ';

  @override
  String get nasInstallComposePreview => 'معاينة docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'الخطوات المخطط لها';

  @override
  String get nasInstallGuidanceNotes => 'ملاحظات وإرشادات النشر';

  @override
  String get nasInstallNoLogsYet => 'لا توجد سجلات بعد';

  @override
  String get sftpPreviewTooLarge =>
      'يتجاوز الملف حد المعاينة 1 ميجابايت. يرجى تنزيله وفتحه خارجياً.';

  @override
  String get sftpSaveFailed =>
      'فشل حفظ الملف. تحقق من الأذونات أو اتصال الشبكة.';

  @override
  String get sftpSaving => 'جارٍ الحفظ...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'تغير اتصال الخادم المستهدف؛ تحقق من الحالة البعيدة قبل المتابعة';

  @override
  String get nasInstallBlockerCancelled =>
      'تم إلغاء النشر بواسطة المستخدم. راجع الإعدادات وأعد المحاولة إذا لزم الأمر.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'فشل الفحص في الاستعلام عن الحاوية البعيدة. تحقق من اتصال الخادم أو قم بالفحص يدوياً.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'انتهت مهلة خطوة النشر. تحقق من حمل الخادم أو اتصال الشبكة وأعد المحاولة.';

  @override
  String get nasInstallBlockerInterrupted =>
      'تمت مقاطعة النشر؛ راجع الحالة البعيدة قبل المتابعة.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'بدأت الخدمة ولكن انتهت مهلة فحص صحة HTTP. تحقق من سجلات الخدمة أو توفر المنفذ.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'فشلت التسوية. تحقق من حالة الحاوية البعيدة يدوياً أو ابدأ نشراً جديداً.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'حالة الحاوية البعيدة غير مؤكدة. يلزم الفحص والتسوية اليدوية.';

  @override
  String get nasInstallBlockerServiceExited =>
      'تم إنهاء عملية الحاوية قبل الأوان. تحقق من السجلات لأخطاء التكوين أو الأذونات.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'فشلت كتابة ملفات النشر على الخادم المستهدف. تحقق من مساحة القرص والأذونات.';

  @override
  String get nasInstallBlockerPlanStale =>
      'خطة النشر قديمة. يرجى إعادة تشغيل فحوصات ما قبل التشغيل.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'الحاوية الحالية لم يتم إنشاؤها بواسطة هذا التطبيق. افحص يدوياً لمنع الكتابة فوقها.';

  @override
  String get nasInstallBlockerSshRequired =>
      'يلزم وجود اتصال SSH نشط بالخادم المستهدف.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'تختلف الحالة البعيدة عن الحالة المحلية. يرجى التسوية قبل المتابعة.';

  @override
  String get nasInstallBlockerFailed =>
      'واجه النشر خطأ. راجع السجلات وأعد المحاولة.';

  @override
  String get nasInstallBlockerBusy =>
      'هناك مهمة تثبيت قيد التنفيذ بالفعل. يرجى التحقق من تقدم المهمة الحالية.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'فشل حفظ حالة النشر. يرجى التحقق من مساحة التخزين المحلية وأذونات الملفات.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'نتيجة الأمر البعيد غير معروفة. يرجى تشغيل فحص للقراءة فقط بدلاً من إعادة محاولة النشر مباشرة.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'فشل فحص البيئة قبل النشر. يرجى حل المعوقات قبل المتابعة.';

  @override
  String serverDeleteFailed(String error) {
    return 'فشل حذف الخادم: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'وضع الوكيل';

  @override
  String get chatRunSettingsApprovalPolicy => 'سياسة الموافقة المحلية';

  @override
  String get chatRunSettingsExtraSettings => 'إعدادات إضافية';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'يسمح تلقائياً بالعمليات المعروفة بأنها آمنة؛ يسأل كلما تعذر تحديد أمان العملية.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'فشل تطبيق إعدادات التشغيل: $error';
  }

  @override
  String get chatMessageCopied => 'تم نسخ الرسالة إلى الحافظة';

  @override
  String get copy => 'نسخ';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get refresh => 'تحديث';

  @override
  String get sessionTitle => 'عنوان الجلسة';

  @override
  String get chatSettingsStale => 'قديم';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'تتوفر الإعدادات بعد الرسالة الأولى';

  @override
  String get chatReimportAsCopy => 'إعادة استيراد كنسخة';

  @override
  String get chatSearchCommandsHint => 'البحث في الأوامر أو المهارات...';

  @override
  String get chatCommandsTab => 'الأوامر';

  @override
  String get chatSkillsTab => 'المهارات';

  @override
  String get chatAccountAndQuotaTitle => 'الحساب والحصة';

  @override
  String get chatAccountSectionTitle => 'الحساب';

  @override
  String get chatAccountNotProvided => 'لم يتم الإبلاغ عن تفاصيل الحساب';

  @override
  String get chatAccountKind => 'النوع';

  @override
  String get chatAccountLabel => 'التسمية';

  @override
  String get chatAccountPlan => 'الخطة';

  @override
  String get chatAccountEmail => 'البريد الإلكتروني';

  @override
  String get chatAccountUpdatedAt => 'تاريخ التحديث';

  @override
  String get chatQuotaSectionTitle => 'الحصة والحالة';

  @override
  String get chatStatusSourceNote => 'مخرجات /status الخام للوكيل';

  @override
  String get chatStatusNotQueried => 'لم يتم الاستعلام عن الحالة بعد';

  @override
  String get chatQueryStatusAction => 'الاستعلام عن الحالة (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'الاستعلام عن الحالة غير متوفر في الجلسة الحالية';

  @override
  String get chatAttachmentMissing => 'ملف المرفق مفقود أو غير متوفر';

  @override
  String get chatViewModeList => 'قائمة';

  @override
  String get chatViewModeCards => 'بطاقات';

  @override
  String get chatViewModeGrid => 'صور';

  @override
  String get chatRemoteBrowserTitle => 'مساحة العمل البعيدة';

  @override
  String get chatSelectDirectory => 'اختر الدليل';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'إرفاق المحدد ($count)';
  }

  @override
  String get chatNoFilesFound => 'لم يتم العثور على ملفات';

  @override
  String get chatRootDirectory => 'الجذر';

  @override
  String get chatSelectThisDirectory => 'استخدام هذا الدليل';

  @override
  String get chatAgentVersion => 'إصدار الوكيل';

  @override
  String get chatParentDirectory => 'الدليل الأصلي';

  @override
  String get chatSearchFilesHint => 'البحث في الملفات...';

  @override
  String get chatCommandsEmpty => 'لا توجد أوامر شرطة مائلة يوفرها الوكيل';

  @override
  String get chatSkillsEmpty => 'لا توجد مهارات يوفرها الوكيل';

  @override
  String get chatFileUnsupported => 'نوع الملف غير مدعوم للإرفاق';

  @override
  String get chatStatusNotProvided => 'الاستعلام عن الحالة غير مقدم من الوكيل';

  @override
  String get sessionRecoveryReconnecting => 'جارٍ إعادة الاتصال...';

  @override
  String get sessionRecoverySyncing => 'جارٍ مزامنة المخرجات...';

  @override
  String get sessionRecoveryIncomplete => 'تعذر استرداد بعض المخرجات';

  @override
  String get sessionRecoveryFailed => 'فشل الاسترداد';

  @override
  String get sessionRecoveryRetry => 'إعادة المحاولة';

  @override
  String get dashboardUpdatesPaused => 'تم إيقاف التحديثات مؤقتاً';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'كتالوج نماذج CLI غير متوفر حالياً. قد تكون النماذج مخزنة مؤقتاً أو محدودة بإصدار CLI؛ يمكنك أيضاً إدخال اسم النموذج يدوياً.';

  @override
  String get chatSettingsModelCatalogNote =>
      'يتم الاستعلام عن النماذج من خادم تطبيق CLI باستخدام تسجيل دخول CLI الحالي. قد يكون الكتالوج مخزناً مؤقتاً أو محدود الإصدار؛ يمكنك التحديث يدوياً أو التبديل إلى الإدخال اليدوي.';

  @override
  String get chatModelCatalogError403 =>
      'تم رفض الوصول للاستعلام عن نماذج CLI (403). تحقق من تسجيل دخول CLI والاتصال بالخدمة، أو أدخل اسم النموذج يدوياً.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'خطأ في كتالوج النماذج: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'تفويض كتالوج النماذج';

  @override
  String get chatModelAuthorizeConfirmTitle => 'تفويض كتالوج النماذج';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'سيؤدي هذا إلى بدء تفويض المتصفح لكتالوج النماذج على المضيف/الحاوية المستهدفة. سيبقى تسجيل دخول Codex وجلسات الطرفية الحالية دون مساس تماماً. هل تريد المتابعة؟';

  @override
  String get chatModelAuthorizing => 'جارٍ التفويض عبر المتصفح...';

  @override
  String get chatModelAuthorizeCancel => 'إلغاء التفويض';

  @override
  String get chatCommandsFirstTurnNote =>
      'سيتم الإعلان عن أوامر الشرطة المائلة بواسطة وقت تشغيل الوكيل بمجرد تهيئة الجلسة، دون الحاجة إلى محادثة عادية مسبقة؛ لا تنشئ المسودات جلسات تلقائياً.';

  @override
  String get chatCommandsClientActionRunSettings => 'إعدادات التشغيل';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'دليل العمل';

  @override
  String get chatCommandsClientActionsSection => 'الإجراءات المحلية';

  @override
  String get chatRunSettingsModelSourceCatalog => 'قائمة النماذج';

  @override
  String get chatRunSettingsModelSourceCustom => 'إدخال يدوي';

  @override
  String get chatRunSettingsCustomModelHint => 'أدخل معرف النموذج';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'أسماء النماذج اليدوية غير مؤكدة وسيتم إرسالها مباشرة إلى وقت تشغيل الوكيل، والذي قد يرفض النماذج غير المدعومة.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'لا يمكن أن يكون اسم النموذج فارغاً';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'يجب ألا يتجاوز اسم النموذج 256 حرفاً بدون مسافات أو أحرف تحكم';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'تم التحقق من الأوامر لإصدار المحول الحالي. يؤدي التحديد إلى إدراج نص في المسودة؛ سيقوم الإرسال بتهيئة الجلسة عند الطلب وتشغيل الأمر مباشرة.';

  @override
  String get chatCommandsDiscoveryFailed => 'فشل اكتشاف الأوامر أو المهارات';

  @override
  String get chatAuthWaitingForBrowser => 'في انتظار التفويض في المتصفح...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'تعذر فتح المتصفح الخارجي. يرجى إعادة الفتح أو نسخ رابط التفويض أدناه.';

  @override
  String get chatAuthReopenBrowser => 'إعادة فتح المتصفح';

  @override
  String get chatAuthCopyLink => 'نسخ الرابط';

  @override
  String get chatAuthManualCallback => 'رد الاتصال اليدوي';

  @override
  String get chatAuthManualCallbackTitle => 'أدخل رابط رد الاتصال للتفويض';

  @override
  String get chatAuthManualCallbackDesc =>
      'الصق عنوان URL الكامل لإعادة التوجيه (http://127.0.0.1:PORT/...?code=...&state=...) من المتصفح لإكمال التفويض. لا تُقبل رموز التفويض المجردة.';

  @override
  String get chatAuthCallbackInputLabel => 'رابط رد الاتصال';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'تنسيق رابط رد الاتصال غير صالح أو فشل التسليم';

  @override
  String get agentAuthAgYNotice =>
      'يتطلب Antigravity ACP تفويضاً رسمياً للحساب، منفصلاً عن تسجيل دخول طرفية CLI.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'تتطلب هذه الجولة مصادقة ACP. أعد الاتصال واطلب التفويض للمتابعة.';

  @override
  String get chatRequestAuthButton => 'طلب المصادقة';

  @override
  String get agentActionAcpLogin => 'تسجيل دخول ACP';

  @override
  String get agentActionCliLogin => 'تسجيل دخول CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'بيانات اعتماد ACP مفقودة (يلزم تسجيل دخول ACP)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'تم حفظ بيانات اعتماد ACP (غير مؤكدة)';

  @override
  String get chatAuthMethodUnavailable => 'طريقة المصادقة المحددة غير متوفرة.';

  @override
  String get chatAuthConnectionExpired =>
      'انتهت صلاحية اتصال المصادقة. يرجى المحاولة مرة أخرى.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'فشل تسليم رد الاتصال للتفويض إلى الخادم.';

  @override
  String get agentTargetChangedNotice =>
      'تم تغيير الخادم المستهدف. يرجى إعادة فتح إدارة الوكلاء على الخادم الحالي.';

  @override
  String get agentAgyAuthCheckUnavailable => 'فحص مصادقة Antigravity غير متاح';

  @override
  String get agentAgyAuthCheckInvalid =>
      'استجابة فحص مصادقة Antigravity غير صالحة';

  @override
  String get sftpDownloadDisconnected => 'تم قطع اتصال التنزيل';

  @override
  String get sftpDownloadPermissionDenied => 'تم رفض الإذن';

  @override
  String get sftpDownloadNotFound => 'الملف البعيد غير موجود';

  @override
  String get sftpDownloadTimeout => 'انتهت مهلة التنزيل';

  @override
  String get sftpDownloadLocalSpace => 'مساحة التخزين المحلية غير كافية';

  @override
  String get sftpDownloadLocalIo => 'فشلت الكتابة في التخزين المحلي';

  @override
  String get sftpDownloadIncomplete => 'تنزيل غير مكتمل';

  @override
  String get transferStatusWaitingConnection => 'في انتظار الاتصال';

  @override
  String get chatAuthCallbackListenerFailed =>
      'فشل بدء مستمع رد اتصال المصادقة المحلي. يرجى إعادة محاولة المصادقة.';

  @override
  String get settingsExperimentalFeatures => 'الميزات التجريبية';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'تجربة الإمكانات المعاينة والتجريبية';

  @override
  String get settingsExperimentalCliChatTitle => 'محادثة CLI الذكية';

  @override
  String get settingsExperimentalCliChatDesc =>
      'تمكين واجهة محادثة مخصصة لوكلاء سطر الأوامر';

  @override
  String get settingsExperimentalDialogClose => 'إغلاق';

  @override
  String get settingsExperimentalSaveFailed =>
      'فشل تحديث إعدادات الميزات التجريبية';

  @override
  String get settingsExperimentalNasTitle => 'وسائط NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'تمكين مكتبة الوسائط، وفحص المجلدات، وتشغيل الصوتيات';

  @override
  String get settingsLanguageSaveFailed => 'فشل تحديث إعدادات اللغة';

  @override
  String get settingsAboutPrivacy => 'حول التطبيق والخصوصية';

  @override
  String get privacyPolicyTitle => 'سياسة الخصوصية';

  @override
  String get privacyPolicyDescription => 'استخدام البيانات وخياراتك';

  @override
  String get privacyContactTitle => 'جهة اتصال الخصوصية';

  @override
  String get privacyCopyEmail => 'نسخ عنوان البريد';

  @override
  String get privacyEmailCopied => 'تم نسخ عنوان البريد';

  @override
  String get privacyOnlineVersion => 'عرض النسخة عبر الإنترنت';

  @override
  String get privacyLinkFailed => 'تعذر فتح الرابط. يمكنك نسخ عنوان البريد.';

  @override
  String get privacyLoadFailed =>
      'تعذر تحميل السياسة. اعرض النسخة عبر الإنترنت.';

  @override
  String get privacyVersionUnknown => 'الإصدار غير متاح';

  @override
  String get aboutWebsite => 'الموقع الرسمي';

  @override
  String get aboutLicense => 'ترخيص التطبيق';

  @override
  String get aboutThirdPartyLicenses =>
      'تراخيص المكونات الخارجية مفتوحة المصدر';

  @override
  String get aboutLicenseSummary =>
      'المحتوى الأصلي لتطبيق Valhalla مرخص للاستخدام غير التجاري بموجب PolyForm Noncommercial 1.0.0. يتطلب الاستخدام التجاري خارج نطاق أذونات الترخيص تصريحًا منفصلًا. تحتفظ المكونات الخارجية بتراخيصها الخاصة. يخضع الاستخدام للشروط الكاملة أدناه.';

  @override
  String get aboutCopyrightNotice => 'إشعارات حقوق النشر';

  @override
  String get aboutLicenseLoadFailed =>
      'تعذر تحميل الترخيص. يرجى التواصل عبر norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'تعذر فتح الرابط. افتح https://norns.cc.cd في المتصفح.';

  @override
  String get downloadReveal => 'إظهار في مستكشف الملفات';

  @override
  String get downloadRevealFailed =>
      'تعذر فتح مجلد التنزيل. ربما تم نقله أو حذفه.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count من مفاتيح المضيفين الموثوقين';
  }

  @override
  String get settingsKnownHostsEmpty =>
      'لم يتم العثور على مفاتيح مضيفين موثوقين';

  @override
  String get settingsKnownHostsDialogTitle => 'مفاتيح المضيفين المعروفين';

  @override
  String get settingsHostKeyRevoke => 'إلغاء الثقة';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'إلغاء الثقة بمفتاح المضيف';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return 'هل تريد بالتأكيد إلغاء مفتاح المضيف لـ $hostPort؟ سيتم فصل اتصالات SSH النشطة بهذا المضيف وسيلزم التحقق منه عند الاتصال القادم.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'تم نسخ بصمة مفتاح المضيف إلى الحافظة';

  @override
  String get settingsHostKeyRevoked => 'تم إلغاء مفتاح المضيف';

  @override
  String get settingsClearStorageSubtitle =>
      'مسح كلمات المرور والمفاتيح الخاصة المحفوظة للخوادم المحددة';

  @override
  String get settingsClearStorageDialogTitle =>
      'إعادة ضبط بيانات اعتماد الخوادم';

  @override
  String get settingsClearStorageDesc =>
      'حدد الخوادم لمسح كلمات مرور SSH والمفاتيح الخاصة من التخزين الآمن المحلي. لن يتم حذف إعدادات الخادم أو سجل المحادثات.';

  @override
  String get settingsClearStorageNoServers => 'لا توجد خوادم متاحة';

  @override
  String get settingsClearStorageSelectAll => 'تحديد الكل';

  @override
  String get settingsClearStorageDeselectAll => 'إلغاء تحديد الكل';

  @override
  String get settingsClearStorageConfirmTitle =>
      'تأكيد إعادة ضبط بيانات الاعتماد';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'هل أنت متأكد من مسح بيانات الاعتماد لـ $count خادم(خوادم) محدد؟ سيتم قطع الاتصالات النشطة بها على الفور.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'مسح المحدد ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'تم مسح بيانات اعتماد الخوادم المحددة بنجاح';

  @override
  String get settingsClearStorageError =>
      'فشل مسح بيانات اعتماد بعض الخوادم. يرجى المحاولة مرة أخرى.';

  @override
  String get settingsDefaultAcpAgent => 'وكيل ACP الافتراضي';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'الوكيل الافتراضي لمحادثة ACP على هذا الخادم';

  @override
  String get settingsDefaultCliAgent => 'وكيل CLI الافتراضي';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'الوكيل الافتراضي لمحادثة CLI على هذا الخادم';

  @override
  String get settingsDefaultAgentAutomatic => 'تلقائي (أول وكيل متاح)';

  @override
  String get settingsDefaultAgentSelectTitle => 'تحديد الوكيل الافتراضي';

  @override
  String get settingsDefaultAgentNoServer => 'لم يتم تحديد خادم';

  @override
  String get settingsDefaultAgentNoAgents => 'لا توجد وكلاء مهيأة لهذا الخادم';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'فشل تحديث إعداد الوكيل الافتراضي';

  @override
  String get dockerViewGroupContainers => 'الحاويات';

  @override
  String get dockerViewGroupProjects => 'مشاريع Compose';

  @override
  String get dockerProjectActionStart => 'بدء المشروع';

  @override
  String get dockerProjectActionStop => 'إيقاف المشروع';

  @override
  String get dockerProjectActionRestart => 'إعادة تشغيل المشروع';

  @override
  String get dockerProjectConfirmStopTitle => 'إيقاف مشروع Compose';

  @override
  String get dockerProjectConfirmRestartTitle => 'إعادة تشغيل مشروع Compose';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'هل أنت متأكد من رغبتك في $action المشروع \"$project\"؟ ستتأثر الحاويات التالية ($count):';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'تم $action المشروع \"$project\" بنجاح';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'اكتمل $action المشروع \"$project\" مع فشل $failedCount';
  }

  @override
  String get dockerNoProjects => 'لم يتم العثور على أي مشاريع Docker Compose';

  @override
  String get dockerMountsTitle => 'نقاط التوصيل';

  @override
  String get dockerMountReadOnly => 'قراءة فقط';

  @override
  String get dockerMountReadWrite => 'قراءة/كتابة';

  @override
  String get sftpBookmarksTitle => 'إشارات المجلدات المرجعية';

  @override
  String get sftpNoBookmarks => 'لا توجد إشارات مرجعية محفوظة بعد';

  @override
  String get sftpAddBookmark => 'إضافة إشارة مرجعية';

  @override
  String get sftpRemoveBookmark => 'إزالة الإشارة المرجعية';

  @override
  String get sftpCurrentDirectory => 'المجلد الحالي';

  @override
  String get sftpSelectMode => 'وضع التحديد المتعدد';

  @override
  String sftpSelectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get sftpSelectAll => 'تحديد الكل';

  @override
  String get sftpDeselectAll => 'إلغاء تحديد الكل';

  @override
  String get sftpBatchCopy => 'نسخ';

  @override
  String get sftpBatchMove => 'نقل';

  @override
  String get sftpBatchDeleteConfirmTitle => 'تأكيد الحذف المجمع';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'هل أنت متأكد من حذف $count من العناصر المحددة؟';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'ملاحظة: لا يمكن حذف المجلدات غير الفارغة بشكل متكرر وسيتم تخطيها.';

  @override
  String get sftpBatchCopyConfirmTitle => 'تأكيد النسخ المجمع';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'نسخ $count من العناصر المحددة إلى \"$directory\"؟';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'تأكيد النقل المجمع';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'نقل $count من العناصر المحددة إلى \"$directory\"؟';
  }

  @override
  String get sftpBatchResultsTitle => 'نتائج العملية المجمعة';

  @override
  String get sftpBatchOutcomeSkipped => 'تم التخطي (الهدف موجود أو غير مدعوم)';

  @override
  String get sftpBatchTargetRestricted =>
      'لا يمكن تحديد المجلد الحالي أو أحد مجلداته الفرعية كوجهة';

  @override
  String get sftpSelectCurrentDir => 'اختيار هذا المجلد';

  @override
  String sftpBatchOperationSuccess(int count) {
    return 'تمت معالجة $count عنصر بنجاح';
  }

  @override
  String get configMigrationTitle => 'النسخ الاحتياطي ونقل الإعدادات';

  @override
  String get configExportTitle => 'تصدير الإعدادات';

  @override
  String get configExportSubtitle =>
      'تصدير الخوادم والوكلاء والأوامر والإشارات والتفضيلات إلى JSON';

  @override
  String get configExportDialogTitle => 'تصدير إعدادات Valhalla';

  @override
  String get configExportSuccess => 'تم تصدير الإعدادات بنجاح';

  @override
  String configExportError(String error) {
    return 'فشل تصدير الإعدادات: $error';
  }

  @override
  String get configImportTitle => 'استيراد الإعدادات';

  @override
  String get configImportSubtitle =>
      'استيراد الإعدادات من ملف نسخة احتياطية بتنسيق JSON';

  @override
  String get configBackupTooLarge =>
      'يتجاوز ملف النسخة الاحتياطية الحد الأقصى المسموح به للحجم (8 ميغابايت)';

  @override
  String get configImportPreviewTitle => 'معاينة استيراد الإعدادات';

  @override
  String get configImportPreviewDesc =>
      'راجع المحتويات قبل الاستيراد. سيتم الاحتفاظ بالعناصر الحالية ودمجها.';

  @override
  String configImportServersCount(int count) {
    return 'الخوادم ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'الوكلاء ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'الأوامر السريعة ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'الإشارات المرجعية ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'قد تحتوي الأوامر المخصصة على نصوص برمجية حساسة أو بيانات اعتماد مضمنة. لا يتم نقل أي كلمات مرور أو مفاتيح خاصة أو بصمات خوادم موثوقة.';

  @override
  String get configImportGlobalPreferences => 'استيراد تفضيلات التطبيق العامة';

  @override
  String get configImportGlobalPreferencesDesc =>
      'الكتابة فوق إعدادات السمة والطرفية والتنقل الحالية';

  @override
  String get configImportConfirmAction => 'تأكيد الاستيراد';

  @override
  String get configImportSuccess => 'تم استيراد الإعدادات بنجاح';

  @override
  String get configImportErrorTitle => 'ملف نسخة احتياطية غير صالح';

  @override
  String configImportErrorGeneric(String error) {
    return 'فشل استيراد الإعدادات: $error';
  }

  @override
  String get configImportErrorCopyDetails => 'نسخ تفاصيل التشخيص';

  @override
  String get configImportErrorCopied => 'تم نسخ تفاصيل التشخيص إلى الحافظة';

  @override
  String get configImportErrorUnsupportedVersion =>
      'تنسيق أو إصدار النسخة الاحتياطية غير مدعوم';

  @override
  String get configImportErrorMalformed =>
      'ملف JSON للإعدادات تالف أو غير صالح';

  @override
  String get aboutRepository => 'مستودع GitHub';

  @override
  String get updateCheckTitle => 'التحقق من وجود تحديثات';

  @override
  String get updateChecking => 'جارٍ التحقق من وجود تحديثات...';

  @override
  String get updateCheckNow => 'تحقق الآن';

  @override
  String get updateUpToDate => 'Valhalla محدث إلى آخر إصدار';

  @override
  String updateInstalledVersion(String version) {
    return 'المثبت: v$version';
  }

  @override
  String updateAvailableBadge(String version) {
    return 'يتوفر إصدار جديد: v$version';
  }

  @override
  String get updateViewUpdate => 'عرض التحديث';

  @override
  String updateLastChecked(String time) {
    return 'آخر فحص: $time';
  }

  @override
  String get updateNeverChecked => 'لم يتم الفحص من قبل';

  @override
  String get updateAutoCheckTitle => 'التحقق التلقائي من التحديثات';

  @override
  String get updateAutoCheckSubtitle =>
      'التحقق يوميًا من التحديثات عندما يكون التطبيق نشطًا';

  @override
  String get updateAutoCheckSaveFailed =>
      'فشل حفظ إعداد التحقق التلقائي من التحديثات';

  @override
  String get updateDialogTitle => 'تحديث البرنامج';

  @override
  String updateCurrentVersion(String version) {
    return 'الحالي: $version';
  }

  @override
  String updateTargetVersion(String version) {
    return 'الأحدث: v$version';
  }

  @override
  String updateBuildNumber(String build) {
    return 'البناء $build';
  }

  @override
  String updateCommit(String commit) {
    return 'الالتزام: $commit';
  }

  @override
  String get updateArtifactDetails => 'حزمة التثبيت';

  @override
  String updateArtifactName(String name) {
    return 'الملف: $name';
  }

  @override
  String updateArtifactSize(String size) {
    return 'الحجم: $size';
  }

  @override
  String updateArtifactHash(String hash) {
    return 'تجزئة SHA-256: $hash';
  }

  @override
  String get updateCopyHash => 'نسخ تجزئة SHA-256';

  @override
  String get updateHashCopied => 'تم نسخ تجزئة SHA-256 إلى الحافظة';

  @override
  String get updateCopyCommit => 'نسخ تجزئة الالتزام';

  @override
  String get updateCommitCopied => 'تم نسخ تجزئة الالتزام إلى الحافظة';

  @override
  String get updateReleaseNotes => 'ملاحظات الإصدار';

  @override
  String get updateNoReleaseNotes => 'لا توجد ملاحظات إصدار مقدمة.';

  @override
  String get updateNoArtifactForPlatform =>
      'لا توجد حزمة تثبيت مباشرة متاحة لمنصة/معمارية هذا الجهاز.';

  @override
  String get updateOpenReleasePage => 'فتح صفحة الإصدارات';

  @override
  String get updateDownload => 'تنزيل التحديث';

  @override
  String updateDownloading(String progress) {
    return 'جارٍ التنزيل... $progress%';
  }

  @override
  String get updatePause => 'إيقاف مؤقت';

  @override
  String get updateResume => 'استئناف';

  @override
  String get updateRetry => 'إعادة المحاولة';

  @override
  String get updateDownloadPaused => 'تم إيقاف التنزيل مؤقتًا';

  @override
  String get updateDownloadCompleted => 'اكتمل التنزيل وتم التحقق منه';

  @override
  String get updatePhaseResolving => 'جارٍ الاتصال بخادم التحديث...';

  @override
  String get updatePhaseVerifying => 'جارٍ التحقق من حزمة التحديث...';

  @override
  String get updateOpeningInstaller => 'جارٍ تجهيز التثبيت...';

  @override
  String get updateInstall => 'تثبيت التحديث';

  @override
  String get updateRevealInFolder => 'إظهار في المجلد';

  @override
  String get updateOpenFolder => 'فتح موقع التنزيل';

  @override
  String get updateRetryInstall => 'إعادة محاولة التثبيت';

  @override
  String get updateDesktopInstructions =>
      'استخرج الأرشيف الذي تم تنزيله واستبدل التطبيق بعد إغلاقه. لا تقم أبدًا بالكتابة فوق البرنامج قيد التشغيل.';

  @override
  String get updateCopyErrorDetails => 'نسخ تفاصيل الخطأ';

  @override
  String get updateErrorCopied => 'تم نسخ تفاصيل الخطأ إلى الحافظة';

  @override
  String get updateErrorRateLimited =>
      'تم تجاوز حد معدل خدمة التحديث. يرجى المحاولة مرة أخرى لاحقًا.';

  @override
  String get updateErrorNetwork =>
      'فشل الاتصال بالشبكة. يرجى التحقق من اتصالك بالإنترنت.';

  @override
  String get updateErrorManifest =>
      'بيان التحديث غير صالح أو تنقصه بيانات وصفية مطلوبة.';

  @override
  String get updateErrorIntegrity =>
      'فشل التحقق من سلامة التنزيل. المجموع التحققي للملف غير متطابق.';

  @override
  String get updateErrorSignatureMismatch =>
      'عدم تطابق توقيع التثبيت: تم توقيع حزمة التحديث بمفتاح مختلف عن هذا التطبيق. لا يمكن الكتابة فوق توقيعات مختلفة. لتجنب فقدان البيانات، لا تقم مطلقًا بإلغاء التثبيت أو مسح بيانات التطبيق.';

  @override
  String get updateErrorPermissionRequired =>
      'إذن التثبيت مطلوب. يرجى السماح بتثبيت التطبيقات غير المعروفة لـ Valhalla في إعدادات النظام، ثم النقر فوق إعادة محاولة التثبيت.';

  @override
  String get updateErrorPermission => 'تم رفض إذن التخزين أو النظام.';

  @override
  String get updateErrorPackageInvalid => 'مسار الحزمة أو هويتها غير صالحة.';

  @override
  String get updateErrorStoreInstall =>
      'تم تثبيت هذا التطبيق من متجر تطبيقات. يرجى التحديث عبر المتجر.';

  @override
  String get updateErrorPlatform => 'فشل فتح برنامج التثبيت أو تشغيله.';

  @override
  String get updateErrorGeneric =>
      'فشلت عملية التحديث. يرجى المحاولة مرة أخرى أو زيارة صفحة الإصدارات.';

  @override
  String get servicePermissionDenied => 'تم رفض إذن إدارة الخدمة';

  @override
  String get serviceUnsupported => 'الإجراء غير مدعوم لهذه الخدمة';

  @override
  String get serviceQueryFailed => 'فشل الاستعلام عن حالة الخدمة';

  @override
  String get serviceTargetChanged => 'تغير الخادم المستهدف؛ تم إلغاء العملية';

  @override
  String get serviceActionInProgress =>
      'هناك إجراء آخر قيد التنفيذ لهذه الخدمة';

  @override
  String get processIdentityChanged =>
      'تمت إعادة تشغيل العملية؛ تم إلغاء الإنهاء';

  @override
  String get processIdentityUnavailable =>
      'وقت بدء العملية غير متاح؛ تم رفض الإنهاء';

  @override
  String get serviceLogsTitle => 'سجلات الخدمة';

  @override
  String get serviceLogsLoadOlder => 'تحميل سجلات أقدم';

  @override
  String get serviceLogsEmpty => 'لم يتم العثور على سجلات';

  @override
  String get serviceLogsCopied => 'تم نسخ السجلات إلى الحافظة';

  @override
  String get fileEditorUnsavedTitle => 'تغييرات غير محفوظة';

  @override
  String get fileEditorUnsavedMessage =>
      'لديك تغييرات غير محفوظة. اختر إجراءً قبل المغادرة:';

  @override
  String get fileEditorKeepDraft => 'الاحتفاظ بالمسودة';

  @override
  String get fileEditorDiscard => 'تجاهل';

  @override
  String get fileEditorDiscardConfirmTitle => 'تجاهل المسودة؟';

  @override
  String get fileEditorDiscardConfirmMessage =>
      'هل أنت متأكد من رغبتك في تجاهل المسودة المحلية وإعادة تحميل أحدث ملف من الخادم؟';

  @override
  String get fileEditorConflictBanner =>
      'تم تعديل الملف على الخادم أو يتعارض مع المسودة المحلية.';

  @override
  String get fileEditorCopyDraft => 'نسخ المسودة';

  @override
  String get fileEditorDraftCopied => 'تم نسخ المسودة إلى الحافظة';

  @override
  String get fileEditorReload => 'إعادة تحميل';

  @override
  String get sftpAtomicSaveUnsupported => 'الخادم لا يدعم الحفظ الذري الآمن';

  @override
  String get sftpEditorExpired => 'انتهت صلاحية جلسة المحرر';

  @override
  String get sftpDraftSaveFailed => 'فشل حفظ المسودة المحلية';

  @override
  String get sftpEditConflict =>
      'تم تعديل الملف على الخادم؛ يرجى إعادة التحميل أو نسخ المسودة';

  @override
  String get sftpEditDraftConflict => 'المسودة المحلية تتعارض مع ملف الخادم';

  @override
  String get sftpTransferSourceChanged => 'تم تغيير الملف المصدر أثناء النقل';

  @override
  String get sftpTransferPartialInvalid => 'ملف النقل الجزئي غير صالح أو تالف';

  @override
  String get sftpTransferCommitting =>
      'النقل قيد التنفيذ بالفعل؛ لا يمكن إعادة التشغيل';

  @override
  String get sftpTransferCleanupFailed =>
      'فشل في تنظيف عملية النقل غير المكتملة';

  @override
  String get sftpUploadTargetExists => 'الملف الهدف موجود بالفعل';

  @override
  String get sftpUploadCommitFailed => 'فشل في إنهاء الرفع عن بُعد';

  @override
  String get sftpUploadSourceInvalid =>
      'تم تغيير ملف المصدر المحلي أو أنه غير صالح';

  @override
  String cachedDataNotice(String time) {
    return 'تم التخزين المؤقت في $time';
  }

  @override
  String get serviceLogsCapReached => 'الحد الأقصى: الاحتفاظ بـ 1000 سجل';

  @override
  String get nasThumbnailCacheUsage => 'ذاكرة التخزين المؤقت للصور المصغرة';

  @override
  String get nasThumbnailCacheBudget => 'السعة المخصصة لذاكرة التخزين المؤقت';

  @override
  String get nasThumbnailCacheClear => 'مسح ذاكرة التخزين المؤقت';

  @override
  String get nasThumbnailCacheCleared =>
      'تم مسح ذاكرة التخزين المؤقت للصور المصغرة';

  @override
  String get nasThumbnailCacheOff => 'إيقاف';

  @override
  String get navAppCenter => 'مركز التطبيقات';

  @override
  String get settingsExperimentalAppCenterTitle => 'مركز التطبيقات (Docker)';

  @override
  String get settingsExperimentalAppCenterDesc =>
      'متجر تطبيقات تجريبي وإدارة نشر الحاويات';

  @override
  String get appCenterTitle => 'مركز التطبيقات';

  @override
  String get appCenterTabStore => 'المتجر';

  @override
  String get appCenterTabInstalled => 'المثبتة';

  @override
  String get appCenterTabTasks => 'المهام';

  @override
  String get appCenterSources => 'المصادر';

  @override
  String get appCenterManageSources => 'إدارة المصادر';

  @override
  String get appCenterAddSource => 'إضافة مصدر';

  @override
  String get appCenterSourceName => 'اسم المصدر';

  @override
  String get appCenterSourceUrl => 'رابط المصدر (HTTPS)';

  @override
  String get appCenterDeleteSource => 'حذف المصدر';

  @override
  String get appCenterRefresh => 'تحديث';

  @override
  String get appCenterSearchHint => 'البحث في التطبيقات...';

  @override
  String get appCenterFilterAllCategories => 'جميع الفئات';

  @override
  String get appCenterFilterAllSources => 'جميع المصادر';

  @override
  String get appCenterNoApps => 'لم يتم العثور على تطبيقات';

  @override
  String get appCenterNoInstalled => 'لا توجد تطبيقات مثبتة';

  @override
  String get appCenterNoTasks => 'لا توجد مهام نشطة أو حديثة';

  @override
  String get appCenterInstall => 'تثبيت';

  @override
  String get appCenterInstalledBadge => 'مثبت';

  @override
  String get appCenterIncompatibleBadge => 'غير متوافق';

  @override
  String get appCenterUpdateAvailable => 'يتوفر تحديث';

  @override
  String get appCenterArchitectureBlocker => 'المعمارية غير مدعومة';

  @override
  String get appCenterAppDetails => 'تفاصيل التطبيق';

  @override
  String get appCenterVersion => 'الإصدار';

  @override
  String get appCenterCategory => 'الفئة';

  @override
  String get appCenterSource => 'المصدر';

  @override
  String get appCenterArchitectures => 'المعماريات المدعومة';

  @override
  String get appCenterScreenshots => 'لقطات الشاشة';

  @override
  String get appCenterDescription => 'الوصف';

  @override
  String appCenterWizardTitle(String appName) {
    return 'تثبيت $appName';
  }

  @override
  String appCenterConfigureTitle(String appName) {
    return 'تكوين $appName';
  }

  @override
  String appCenterUpdateTitle(String appName) {
    return 'تحديث $appName';
  }

  @override
  String get appCenterStepEnvironment => 'البيئة';

  @override
  String get appCenterStepConfig => 'التكوين';

  @override
  String get appCenterStepReview => 'مراجعة الخطة';

  @override
  String get appCenterStepProgress => 'التقدم';

  @override
  String get appCenterInstanceName => 'اسم المثيل';

  @override
  String get appCenterDataDirectory => 'دليل البيانات';

  @override
  String get appCenterBrowseDirectory => 'تصفح الدليل';

  @override
  String get appCenterNetworkAndPorts => 'الشبكة والمنافذ';

  @override
  String get appCenterBindAddress => 'عنوان الربط';

  @override
  String get appCenterBindLoopback => 'المضيف المحلي فقط (127.0.0.1)';

  @override
  String get appCenterBindAll => 'جميع الواجهات (0.0.0.0)';

  @override
  String get appCenterPortMapping => 'تعيين المنافذ';

  @override
  String get appCenterMounts => 'نقاط التوصيل';

  @override
  String get appCenterMountSource => 'مسار المضيف';

  @override
  String get appCenterMountTarget => 'مسار الحاوية';

  @override
  String get appCenterMountReadOnly => 'للقراءة فقط';

  @override
  String get appCenterVariables => 'المتغيرات';

  @override
  String get appCenterEnvironmentVariables => 'متغيرات البيئة';

  @override
  String get appCenterNext => 'التالي';

  @override
  String get appCenterBack => 'السابق';

  @override
  String get appCenterConfirmAndExecute => 'تنفيذ الخطة';

  @override
  String get appCenterPlanPreview => 'معاينة خطة النشر';

  @override
  String get appCenterPlanSanitizedNotice =>
      'راجع خطة النشر التي تم إنشاؤها قبل التنفيذ:';

  @override
  String get appCenterEnvironmentCheck => 'بيئة Docker';

  @override
  String get appCenterDockerFound => 'Docker متاح';

  @override
  String get appCenterDockerMissing => 'Docker غير مثبت';

  @override
  String get appCenterComposeFound => 'Docker Compose متاح';

  @override
  String get appCenterComposeMissing => 'Docker Compose غير مثبت';

  @override
  String get appCenterBootstrapPrompt =>
      'يمكن تثبيت Docker و Compose تلقائيًا على هذا الخادم. يتطلب إذن root/sudo.';

  @override
  String get appCenterBootstrapButton => 'تثبيت Docker و Compose';

  @override
  String get appCenterSudoPassword => 'كلمة مرور Sudo (اختياري / عند الحاجة)';

  @override
  String get appCenterSudoPasswordHint =>
      'أدخل كلمة مرور sudo للعمليات ذات الصلاحيات';

  @override
  String get appCenterOpen => 'فتح واجهة الويب';

  @override
  String get appCenterStart => 'بدء';

  @override
  String get appCenterStop => 'إيقاف';

  @override
  String get appCenterRestart => 'إعادة التشغيل';

  @override
  String get appCenterLogs => 'السجلات';

  @override
  String get appCenterConfig => 'تكوين';

  @override
  String get appCenterUpdate => 'تحديث';

  @override
  String get appCenterRestore => 'استعادة';

  @override
  String get appCenterUninstall => 'إلغاء التثبيت';

  @override
  String appCenterUninstallConfirmTitle(String appName) {
    return 'إلغاء تثبيت $appName؟';
  }

  @override
  String appCenterUninstallConfirmMessage(String appName) {
    return 'هل أنت متأكد من إلغاء تثبيت $appName؟ ستتم إزالة الحاويات، ولكن سيتم الاحتفاظ بدليل بيانات التطبيق.';
  }

  @override
  String get appCenterUninstallKeepData => 'إلغاء التثبيت (الاحتفاظ بالبيانات)';

  @override
  String get appCenterUninstallDeleteSelected => 'إلغاء التثبيت وحذف المحدد';

  @override
  String get appCenterUninstallInspecting => 'جارٍ فحص دلائل بيانات التطبيق...';

  @override
  String get appCenterUninstallInspectionFailedWarning =>
      'فشل فحص تنظيف البيانات. لا يزال بإمكانك إلغاء تثبيت حاويات التطبيق مع الاحتفاظ بجميع البيانات بأمان.';

  @override
  String get appCenterUninstallDirectoriesTitle =>
      'مجلدات البيانات ووحدات Docker';

  @override
  String get appCenterUninstallNoDirectories =>
      'لم يتم اكتشاف دلائل بيانات مرتبطة. ستتم إزالة الحاويات مع الاحتفاظ بالبيانات.';

  @override
  String get appCenterUninstallDefaultPreservedHint =>
      'تُحفظ كل البيانات افتراضياً. حدد فقط المجلدات أو الوحدات التي تريد حذفها نهائياً.';

  @override
  String get appCenterUninstallPermanentLossWarning =>
      'ستُحذف البيانات المحددة نهائياً من الخادم دون سلة محذوفات.';

  @override
  String get appCenterUninstallSelectedPathsTitle =>
      'البيانات المطلوب حذفها نهائياً:';

  @override
  String get appCenterUninstallRiskAck =>
      'أفهم المخاطر وتأثيرها على التطبيقات الأخرى وأؤكد الحذف النهائي لهذه البيانات.';

  @override
  String get remoteBrowserAllFileTypes => 'كل الصيغ';

  @override
  String get remoteBrowserDocuments => 'النصوص والمستندات';

  @override
  String get remoteBrowserFileFormat => 'صيغة الملف';

  @override
  String get appCenterUninstallRiskSystem => 'مسار النظام';

  @override
  String get appCenterUninstallRiskShared => 'مشترك مع تطبيقات أخرى';

  @override
  String get appCenterUninstallRiskVolume => 'وحدة تخزين Docker';

  @override
  String get appCenterCleanupVolumeDeleteFailed =>
      'تعذر حذف وحدة تخزين Docker. أزل استخدامها من الحاويات الأخرى ثم أعد الفحص والمحاولة.';

  @override
  String get appCenterCleanupPermissionDenied =>
      'تم رفض الوصول. استخدم حساباً يمكنه الوصول إلى البيانات أو sudo.';

  @override
  String get appCenterCleanupCriticalPath =>
      'لا يمكن حذف جذر الخادم أو مجلدات تشغيل النظام وإدارته عند إزالة تطبيق.';

  @override
  String appCenterUninstallTypeAppNameHint(String appName) {
    return 'اكتب اسم التطبيق بدقة لتأكيد الحذف النهائي: $appName';
  }

  @override
  String get appCenterUninstallRiskLegacy => 'ملكية حصرية غير موثقة';

  @override
  String get appCenterUninstallRiskExternal =>
      'خارج الدليل الجذري لبيانات التطبيق';

  @override
  String get appCenterUninstallRiskMedia => 'مسار وسائط أو للقراءة فقط';

  @override
  String get appCenterUninstallTargetBlocked => 'دليل محمي، لا يمكن حذفه';

  @override
  String get appCenterCleanupProtected =>
      'تم الاحتفاظ بدليل البيانات لأنه محمي أو غير آمن للحذف';

  @override
  String get appCenterCleanupUnavailable =>
      'فحص التنظيف غير متوفر؛ لا يزال من الممكن إلغاء التثبيت العادي مع الاحتفاظ بالبيانات';

  @override
  String get appCenterCleanupChanged =>
      'تغير الدليل أو هدف النشر؛ يرجى الفحص والتأكيد مرة أخرى';

  @override
  String get appCenterCleanupConfirmationRequired =>
      'يرجى تأكيد الدلائل المحددة والمخاطر واسم التطبيق الدقيق مرة أخرى';

  @override
  String get appCenterCleanupRetryUnavailable =>
      'لا يمكن إعادة محاولة التنظيف بشكل آمن؛ تحقق من تفاصيل المهمة';

  @override
  String get appCenterCleanupAlreadyAbsent =>
      'الدليل غير موجود بالفعل؛ لا يلزم الحذف';

  @override
  String get appCenterCleanupDeleteFailed =>
      'الحذف غير مكتمل؛ ربما تمت إزالة بعض الملفات بالفعل. تحقق من المسارات المتبقية.';

  @override
  String get appCenterCleanupUnconfirmed =>
      'تعذر تأكيد نتيجة التنظيف أو سلامته؛ افحص المهمة وأعد التحقق قبل المتابعة';

  @override
  String appCenterCleanupRetryTitle(String appName) {
    return 'إعادة محاولة تنظيف البيانات المتبقية لـ $appName؟';
  }

  @override
  String get appCenterCleanupRetryDescription =>
      'تم إلغاء تثبيت التطبيق بالفعل. حدد فقط دلائل البيانات غير المكتملة؛ لن تؤدي إعادة المحاولة إلى إلغاء تثبيته مرة أخرى.';

  @override
  String get appCenterCleanupRetrySelected => 'حذف البيانات المتبقية المحددة';

  @override
  String get appCenterCleanupResultsTitle => 'نتائج تنظيف الدلائل';

  @override
  String get appCenterCleanupPartialSummary =>
      'تم إلغاء تثبيت التطبيق؛ لم يتم مسح بعض البيانات بالكامل.';

  @override
  String get appCenterCleanupPending => 'لم يتم تأكيد اكتماله';

  @override
  String get appCenterCleanupRemoved => 'تمت الإزالة';

  @override
  String get appCenterCleanupRetained => 'تم الاحتفاظ به';

  @override
  String get appCenterCleanupRetryAction =>
      'إعادة محاولة تنظيف البيانات المتبقية';

  @override
  String get appCenterJellyfinSoftwareTitle => 'وضع فك التشفير البرمجي';

  @override
  String get appCenterJellyfinSoftwareDesc =>
      'يعطل تحويل ترميز GPU، ويزيل تعيينات أجهزة GPU التي تمت مراجعتها، ويثبت /Media للقراءة فقط.';

  @override
  String get appCenterJellyfinProfileUnavailable =>
      'ملف تعريف فك التشفير البرمجي غير متوفر لهذا القالب';

  @override
  String get appCenterJellyfinSoftwareChanges => 'تغييرات ملف التعريف المطبقة:';

  @override
  String get nasNativeInstallTitle => 'تثبيت Jellyfin (حزمة أصلية)';

  @override
  String get nasNativeStepVerifyRepo => 'التحقق من المستودع الرسمي الموقّع';

  @override
  String get nasNativeStepPreventAutostart =>
      'منع تشغيل الخدمة تلقائيًا قبل إعدادها';

  @override
  String get nasNativeStepInstallPackages => 'تثبيت حزم موقّعة بإصدارات محددة';

  @override
  String get nasNativeStepConfigureLoopback =>
      'إعداد الاستماع على localhost فقط';

  @override
  String get nasNativeStageInstalling => 'جارٍ تثبيت حزم بإصدارات محددة';

  @override
  String get nasNativeStageStarting => 'جارٍ بدء خدمة systemd';

  @override
  String get nasNativeGuidanceMediaAccess =>
      'لن تتغير أذونات ملفات الوسائط أو ملكيتها. تأكد من أن مستخدم خدمة Jellyfin لديه صلاحية القراءة.';

  @override
  String get nasNativeGuidanceNoUpgrade =>
      'لن تتم إدارة تثبيتات Jellyfin الحالية أو تعديلها أو ترقيتها.';

  @override
  String get nasNativeSupportedRequirements =>
      'يتطلب Debian أو Ubuntu بمعمارية amd64 أو arm64، مع systemd وصلاحيات root أو sudo دون كلمة مرور.';

  @override
  String get nasNativeExistingInstallTitle =>
      'تم اكتشاف تثبيت حالي لـ Jellyfin';

  @override
  String get nasNativeExistingInstallExplanation =>
      'يوجد تثبيت لـ Jellyfin على هذا الخادم. لن يعدّله Valhalla أو يعيد تثبيته. تحقق من اتصاله مباشرة.';

  @override
  String get nasNativeCancelExplanation =>
      'تم طلب الإلغاء عند نقطة توقف آمنة. ستُستكمل عمليات الحزم الجارية بأمان.';

  @override
  String get nasNativeMediaPathLabel => 'مسار مجلد الوسائط';

  @override
  String get nasNativeMediaPathHint =>
      'مسار مطلق موجود على الخادم (مثل /media/library). لن تتغير الأذونات.';

  @override
  String get nasNativeSudoRequired =>
      'يتطلب تثبيت حزم النظام صلاحيات root أو sudo دون كلمة مرور';

  @override
  String appCenterLogsTitle(String appName) {
    return 'سجلات $appName';
  }

  @override
  String get appCenterLogsEmpty => 'لا توجد سجلات مسجلة لهذا النشر';

  @override
  String get appCenterLogsCopied => 'تم نسخ السجلات إلى الحافظة';

  @override
  String get appCenterTaskStageQueued => 'في قائمة الانتظار';

  @override
  String get appCenterTaskStagePreparing => 'جارٍ التحضير';

  @override
  String get appCenterTaskStagePulling => 'جارٍ سحب الصور';

  @override
  String get appCenterTaskStageApplying => 'جارٍ تطبيق التكوين';

  @override
  String get appCenterTaskStageChecking => 'جارٍ التحقق من الصحة';

  @override
  String get appCenterTaskStageSucceeded => 'نجح';

  @override
  String get appCenterTaskStageFailed => 'فشل';

  @override
  String get appCenterTaskStageCancelled => 'تم الإلغاء';

  @override
  String get appCenterTaskStageNeedsInspection => 'يحتاج إلى فحص';

  @override
  String get appCenterCancelTask => 'إلغاء المهمة';

  @override
  String get appCenterCopyLog => 'نسخ السجل';

  @override
  String get appCenterErrorNotConnected => 'الخادم غير متصل';

  @override
  String get appCenterErrorEnvironmentRequired => 'فحص بيئة Docker مطلوب';

  @override
  String get appCenterErrorPlanExpired =>
      'خطة النشر منتهية الصلاحية أو غير صالحة';

  @override
  String get appCenterErrorTargetChanged =>
      'تغير الخادم الهدف؛ تم إلغاء العملية';

  @override
  String get appCenterErrorConfigInvalid => 'تكوين التطبيق غير صالح';

  @override
  String appCenterErrorPathInvalid(String field) {
    return 'يجب أن يكون $field مسارًا مطلقًا غير الجذر (/)، ولا يمكن أن يحتوي على مقاطع . أو ..';
  }

  @override
  String get appCenterErrorSourceInvalid => 'مصدر متجر التطبيقات غير صالح';

  @override
  String get appCenterErrorNoWebEntry => 'هذا التطبيق لا يوفر واجهة ويب';

  @override
  String get appCenterErrorHttpsDirectRequired =>
      'لا يمكن نفق نقطة نهاية HTTPS عبر SSH؛ يرجى الفتح مباشرة';

  @override
  String get appCenterErrorOpenFailed => 'فشل تشغيل رابط التطبيق';

  @override
  String appCenterErrorGeneric(String error) {
    return 'خطأ في مركز التطبيقات: $error';
  }

  @override
  String get appCenterSourceCommunityHint => 'مثال: متجر المجتمع';

  @override
  String get appCenterSourceUrlInvalidHttps => 'يجب أن يكون رابط HTTPS صالحاً';

  @override
  String get appCenterDirectUrlLabel => 'الرابط المباشر';

  @override
  String get appCenterErrorSourceRemoved =>
      'مصدر التطبيق لم يعد متوفراً في الدليل. يتعذر تحديث القالب.';

  @override
  String appCenterRestoreConfirmTitle(String appName) {
    return 'استعادة $appName؟';
  }

  @override
  String appCenterRestoreConfirmMessage(String appName) {
    return 'هل أنت متأكد من استعادة $appName إلى تكوين النشر السابق؟';
  }

  @override
  String appCenterHostPortLabel(String target) {
    return 'منفذ المضيف (-> $target)';
  }

  @override
  String appCenterHostMountLabel(String target) {
    return 'المضيف: $target';
  }

  @override
  String get appCenterVersionLatest => 'الأحدث';

  @override
  String get appCenterWaitingForLogs => 'في انتظار سجلات المهمة...';

  @override
  String get appCenterNoPreviewAvailable => 'لا توجد معاينة متاحة';

  @override
  String get appCenterBlockerLocalDockerRequired =>
      'يلزم وجود خادم Docker محلي (لا يُدعم DOCKER_HOST البعيد)';

  @override
  String get appCenterBlockerToolsRequired =>
      'أدوات مطلوبة مفقودة على الخادم (bash, setsid, flock, base64, realpath, ss, awk)';

  @override
  String get appCenterBlockerLinuxRequired => 'نظام التشغيل Linux مطلوب';

  @override
  String appCenterBlockerTemplateUnsupported(String feature) {
    return 'ميزة قالب غير مدعومة: $feature';
  }

  @override
  String get appCenterFieldRequired => 'هذا الحقل مطلوب';

  @override
  String get appCenterContinueInstall => 'متابعة التثبيت';

  @override
  String get appCenterOperation => 'العملية';

  @override
  String get nasTabLibrary => 'المكتبة';

  @override
  String get nasContinueWatching => 'متابعة المشاهدة';

  @override
  String get nasRecentPhotos => 'الصور الأخيرة';

  @override
  String get nasRecentVideos => 'الفيديوهات الأخيرة';

  @override
  String get nasRecentMusic => 'الموسيقى الأخيرة';

  @override
  String get nasDownloadPaused => 'متوقف مؤقتاً';

  @override
  String get nasDownloadDeleteConfirmTitle => 'حذف الملف غير المتصل';

  @override
  String get nasDownloadDeleteConfirmMessage =>
      'سيؤدي هذا إلى حذف الملف المحلي المحمّل من جهازك. لن يتم حذف الملف الأصلي الموجود على الخادم البعيد.';

  @override
  String get nasDownloadDeleteConfirmButton => 'حذف النسخة غير المتصلة';

  @override
  String get nasDownloadSourceChangedMessage =>
      'تغيرت إعدادات المصدر البعيد منذ بدء التنزيل. هل ترغب في إعادة التنزيل من البداية؟';

  @override
  String get nasDownloadRestartFromScratch => 'إعادة البدء من البداية';

  @override
  String get nasDownloadErrorSourceChanged => 'تغيرت إعدادات المصدر';

  @override
  String get nasDownloadErrorOfflineFileInvalid =>
      'الملف المحمّل تالف أو غير مكتمل';

  @override
  String get nasDownloadErrorStorageFailed => 'فشلت الكتابة إلى وحدة التخزين';

  @override
  String get nasDownloadErrorHlsUnsupported =>
      'التنزيل في وضع عدم الاتصال غير مدعوم لتدفقات البث';

  @override
  String get nasDownloadErrorPathInvalid => 'مسار حفظ التنزيل غير صالح';

  @override
  String get nasOpenInApp => 'فتح في التطبيق';

  @override
  String get nasOpenSystem => 'فتح باستخدام النظام';

  @override
  String get sftpRecentDirectories => 'المجلدات الأخيرة';

  @override
  String get sftpNoRecentDirectories => 'لا توجد مجلدات أخيرة';

  @override
  String get sftpRetryFailed => 'إعادة محاولة العمليات الفاشلة';

  @override
  String get appCenterDiskCheckFailed =>
      'تعذر التحقق من المساحة المتوفرة على قرص الخادم';

  @override
  String get appCenterDiskFull => 'قرص الخادم ممتلئ؛ لا يمكن متابعة العملية';

  @override
  String get appCenterHealthInvalid =>
      'فشل فحص صحة الحاوية أو تم الإبلاغ عن حالة غير صالحة';

  @override
  String get appCenterPreflightSummary => 'ملخص الفحص الأولي';

  @override
  String get appCenterMeasuredAvailableSpace =>
      'المساحة المتاحة المقاسة على القرص';

  @override
  String get appCenterUpdateComparison => 'مقارنة التحديث';

  @override
  String get appCenterNoChangesDetected => 'لم يتم اكتشاف أي تغييرات هيكلية';

  @override
  String get appCenterSectionImage => 'صورة الحاوية';

  @override
  String get appCenterSectionPorts => 'تعيين المنافذ';

  @override
  String get appCenterSectionVolumes => 'نقاط التثبيت';

  @override
  String get appCenterSectionEnvironment => 'متغيرات البيئة';

  @override
  String get appCenterSectionHealthcheck => 'فحص السلامة';

  @override
  String get appCenterSectionRestart => 'سياسة إعادة التشغيل';

  @override
  String get appCenterSectionServices => 'الخدمات';

  @override
  String get appCenterHealthNoCheck => 'بدون فحص سلامة';

  @override
  String get appCenterHealthHealthy => 'سليم';

  @override
  String get appCenterHealthUnhealthy => 'غير سليم';

  @override
  String get appCenterHealthStarting => 'قيد التشغيل';

  @override
  String get appCenterNoSources => 'لا توجد مصادر تطبيقات مفعلة';

  @override
  String get appCenterNoMatchingApps =>
      'لا توجد تطبيقات تطابق البحث أو الفلاتر';

  @override
  String get appCenterClearFilters => 'مسح الفلاتر';

  @override
  String get appCenterSourceLoadFailed => 'فشل تحميل مصدر التطبيقات';

  @override
  String get appCenterRetry => 'إعادة المحاولة';

  @override
  String get appCenterRecheck => 'إعادة الفحص';

  @override
  String get appCenterRecheckTask => 'إعادة فحص حالة المهمة';

  @override
  String get appCenterTaskNeedsInspectionTitle => 'حالة المهمة غير مؤكدة';

  @override
  String get appCenterTaskNeedsInspectionMessage =>
      'نتيجة المهمة على الخادم غير معروفة. يرجى إعادة فحص الحالة أو مراجعة السجلات وتجنب إعادة التشغيل عشوائيًا.';

  @override
  String appCenterStopConfirmTitle(String appName) {
    return 'إيقاف $appName؟';
  }

  @override
  String appCenterStopConfirmMessage(String appName, String serverName) {
    return 'هل أنت متأكد من رغبتك في إيقاف $appName على الخادم $serverName؟ سيتم إيقاف الحاويات المشغلة.';
  }

  @override
  String appCenterRestartConfirmTitle(String appName) {
    return 'إعادة تشغيل $appName؟';
  }

  @override
  String appCenterRestartConfirmMessage(String appName, String serverName) {
    return 'هل أنت متأكد من رغبتك في إعادة تشغيل $appName على الخادم $serverName؟';
  }

  @override
  String get appCenterBrowseStore => 'تصفح المتجر';

  @override
  String get appCenterViewTasks => 'عرض المهام';

  @override
  String get appCenterViewInstalled => 'عرض التطبيق المثبت';

  @override
  String get appCenterRunInBackground => 'تشغيل في الخلفية';

  @override
  String get appCenterTaskDetails => 'تفاصيل المهمة';

  @override
  String get appCenterTaskTarget => 'الهدف';

  @override
  String get appCenterTaskDirectory => 'الدليل';

  @override
  String get appCenterTaskCreatedAt => 'تاريخ الإنشاء';

  @override
  String appCenterTaskExitCode(int code) {
    return 'رمز الخروج: $code';
  }

  @override
  String get appCenterStatusRunning => 'قيد التشغيل';

  @override
  String get appCenterStatusStopped => 'متوقف';

  @override
  String get appCenterStatusInstalling => 'قيد التثبيت';

  @override
  String get appCenterStatusUnknown => 'غير معروف';

  @override
  String get appCenterEnvReady => 'بيئة Docker و Compose جاهزة';

  @override
  String get appCenterEnvNotReady => 'بيئة Docker غير جاهزة';

  @override
  String get appCenterEnvInspecting => 'جارٍ فحص بيئة Docker للخادم...';

  @override
  String get appCenterUninstallWholeDataRoot => 'جذر البيانات بالكامل';

  @override
  String get appCenterUninstallWholeDataRootWarning =>
      'يتضمن ذلك الملفات غير المثبتة والأدلة الفرعية المخزنة تحت جذر بيانات التطبيق.';

  @override
  String get appCenterUninstallCoveredByParent => 'مغطى بواسطة الدليل الأصل';

  @override
  String get appCenterContainerNameInvalid =>
      'يجب أن يبدأ اسم المثيل بحرف أبجدي رقمي ويحتوي فقط على أحرف وأرقام وشرطات سفلية ونقاط وشرطات (حتى 120 حرفًا).';

  @override
  String get appCenterMainService => 'الخدمة الرئيسية';

  @override
  String get appCenterContainerNamesPreview => 'معاينة أسماء الحاويات';

  @override
  String get appCenterContainersRecreationNotice =>
      'سيؤدي تغيير أسماء حاويات المثيل إلى إعادة إنشاء حاويات التطبيق الحالية.';

  @override
  String get remoteBrowserTitle => 'متصفح الملفات البعيد';

  @override
  String get remoteBrowserSelectDirectory => 'تحديد الدليل';

  @override
  String get remoteBrowserSelectCurrentDirectory => 'تحديد الدليل الحالي';

  @override
  String get remoteBrowserSearchHint => 'البحث في الملفات والمجلدات...';

  @override
  String get remoteBrowserNoEntries => 'لم يتم العثور على ملفات أو أدلة مطابقة';

  @override
  String get remoteBrowserEmptyDirectory => 'هذا الدليل فارغ';

  @override
  String remoteBrowserSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count عنصر',
      many: 'تم تحديد $count عنصرًا',
      few: 'تم تحديد $count عناصر',
      two: 'تم تحديد عنصرين',
      one: 'تم تحديد عنصر واحد',
      zero: 'لم يتم تحديد أي عنصر',
    );
    return '$_temp0';
  }

  @override
  String get remoteBrowserParentDirectory => 'الدليل الأصل';

  @override
  String get remoteBrowserLibrariesTitle => 'مكتبات الوسائط';

  @override
  String get remoteBrowserDisconnected =>
      'فُقد الاتصال عن بُعد أو أنه غير متاح.';

  @override
  String get remoteBrowserTargetChanged =>
      'تغيرت البيئة المستهدفة أو الخادم النشط.';

  @override
  String get remoteBrowserPathInvalid =>
      'المسار المطلوب غير صالح أو لا يمكن الوصول إليه.';

  @override
  String get remoteBrowserPathOutsideRoot =>
      'المسار المطلوب خارج الدليل الجذر المسموح به.';

  @override
  String get remoteBrowserPathDisplayMode => 'وضع عرض المسار';

  @override
  String get remoteBrowserPathDisplayModeScroll => 'التمرير أفقياً';

  @override
  String get remoteBrowserPathDisplayModeCollapsed => 'طي المسار';

  @override
  String get remoteBrowserEntryUnavailable =>
      'العنصر المحدد غير متاح أو غير صالح.';

  @override
  String get nasBrowseUnavailable => 'خدمة تصفح NAS غير متاحة حاليًا.';

  @override
  String get nasInvalidDirectoryEntry =>
      'تمت مصادفة إدخال دليل غير صالح أثناء تصفح NAS.';

  @override
  String get nasInvalidLibraryResponse =>
      'استجابة مكتبة الوسائط غير صالحة أو مشوهة.';

  @override
  String get nasScanFilterUnresolved => 'تعذر حل مسار مرشح الفحص.';

  @override
  String get nasSourceSaveIncomplete =>
      'تم استمرار حفظ المصدر السابق جزئيًا فقط. يرجى إعادة إدخال بيانات الاعتماد والحفظ بنجاح قبل التصفح.';

  @override
  String get terminalHistoryTitle => 'سجل الجلسات';

  @override
  String get terminalHistoryButton => 'سجل الجلسات';

  @override
  String get terminalHistoryEmpty =>
      'لا يوجد سجل جلسات. تتطلب الجلسات الدائمة وجود tmux على الخادم البعيد.';

  @override
  String get terminalHistoryRefresh => 'تحديث السجل';

  @override
  String get terminalStartupSession => 'جلسة بدء التشغيل';

  @override
  String get terminalStartupSessionSubtitle =>
      'اختر الجلسة التي تفتح عند تشغيل الطرفية';

  @override
  String get terminalStartupSessionFresh => 'جلسة جديدة (افتراضي)';

  @override
  String get terminalStatusOpen => 'مفتوحة';

  @override
  String get terminalStatusAvailable => 'متاحة';

  @override
  String get terminalStatusEnded => 'منتهية';

  @override
  String get terminalStatusOffline => 'غير متصل';

  @override
  String get terminalDefaultBadge => 'افتراضي';

  @override
  String get terminalLegacyBadge => 'غير مستورد';

  @override
  String get terminalRestoreSession => 'استعادة الجلسة';

  @override
  String get terminalSetDefault => 'تعيين كافتراضي';

  @override
  String get terminalClearDefault => 'إلغاء الافتراضي';

  @override
  String get terminalRename => 'إعادة تسمية الجلسة';

  @override
  String get terminalRenameDialogTitle => 'إعادة تسمية الجلسة';

  @override
  String get terminalRenameInputLabel => 'اسم الجلسة';

  @override
  String get terminalTitleInvalid =>
      'يجب أن يتراوح العنوان بين 1 و64 حرفًا دون أحرف تحكم';

  @override
  String get terminalErrorHistoryLoadFailed => 'فشل تحميل سجل الطرفية';

  @override
  String get terminalErrorHistorySaveFailed => 'فشل حفظ سجل الطرفية';

  @override
  String get terminalErrorHistoryRefreshFailed => 'فشل تحديث سجل الطرفية';

  @override
  String get terminalErrorStartFailed => 'فشل بدء جلسة الطرفية';

  @override
  String get terminalErrorRestoreFailed => 'فشل استعادة جلسة الطرفية';

  @override
  String get terminalErrorDefaultSaveFailed =>
      'فشل حفظ جلسة بدء التشغيل الافتراضية';

  @override
  String get terminalErrorCommandFailed => 'فشل تنفيذ أمر الطرفية';

  @override
  String get terminalErrorTitleInvalid =>
      'عنوان الجلسة غير صالح (يلزم من 1 إلى 64 حرفًا)';

  @override
  String get terminalErrorSshDisconnected => 'تم فقد اتصال SSH';

  @override
  String get terminalNoticeDefaultMissing =>
      'جلسة بدء التشغيل الافتراضية مفقودة أو منتهية؛ تم فتح طرفية جديدة';

  @override
  String get terminalNoticeSessionMissing =>
      'جلسة tmux المطلوبة لم تعد موجودة على الخادم البعيد';

  @override
  String get terminalNoticePlainInterrupted =>
      'انقطع الاتصال. تعذر استئناف عمليات الصدفة غير المستندة إلى tmux';

  @override
  String get terminalHistoryDeleteDialogTitle => 'حذف سجل الجلسة';

  @override
  String get terminalHistoryTerminateRemote => 'إنهاء جلسة الخادم البعيد أيضاً';

  @override
  String get terminalHistoryTerminateConfirmTitle => 'إنهاء الجلسة البعيدة؟';

  @override
  String get terminalHistoryTerminateConfirmMessage =>
      'سيؤدي هذا إلى إنهاء جلسة tmux البعيدة وإيقاف جميع العمليات التي تعمل بداخلها.';

  @override
  String get terminalErrorHistoryDeleteFailed => 'فشل حذف سجل الطرفية';

  @override
  String get terminalErrorHistoryTerminateFailed => 'فشل إنهاء الجلسة البعيدة';

  @override
  String get terminalErrorTargetChanged =>
      'تغير الخادم المستهدف. يرجى إعادة فتح الجلسة على الخادم الحالي.';

  @override
  String get terminalModeStandard => 'طرفية SSH قياسية (افتراضي، بدون سجل)';

  @override
  String get terminalModeTmux => 'طرفية tmux (تحتفظ بالجلسة عن بعد والسجل)';

  @override
  String get terminalModeSaveFailed =>
      'فشل حفظ وضع الطرفية، يرجى إعادة المحاولة';

  @override
  String get sftpNew => 'جديد';

  @override
  String get terminalHistorySearchHint => 'البحث في اسم الجلسة…';

  @override
  String get configMigrationBoundaryNote =>
      'تكوين الجهاز المحلي فقط. لا يتم تعديل بيانات الخادم البعيد.';

  @override
  String get configMigrationSubtitle =>
      'تصدير أو استيراد إعدادات التطبيق المحلية وملفات تعريف الخادم';

  @override
  String get installAppId => 'معرّف التطبيق';

  @override
  String get installArchitecture => 'البنية';

  @override
  String get installPlatform => 'المنصة';

  @override
  String get settingsAboutPrivacyDesc =>
      'الإصدار وتراخيص البرمجيات مفتوحة المصدر وسياسة الخصوصية';

  @override
  String get settingsAccentColorDesc => 'تخصيص ألوان سمة التطبيق';

  @override
  String get settingsSearchHint => 'البحث في الإعدادات…';

  @override
  String get settingsSearchNoResults => 'لم يتم العثور على إعدادات مطابقة';

  @override
  String get settingsSecurityDesc =>
      'المضيفون المعروفون وبيانات الاعتماد وإجراءات الأمان';

  @override
  String get agentExpandDetails => 'التفاصيل';

  @override
  String get agentCollapseDetails => 'طي';

  @override
  String get transferPauseAll => 'إيقاف الكل مؤقتًا';

  @override
  String get transferResumePaused => 'استئناف المتوقف';

  @override
  String get transferFilterAll => 'الكل';

  @override
  String get transferFilterActive => 'النشطة';

  @override
  String get transferFilterFailed => 'الفاشلة';

  @override
  String get transferFilterCompleted => 'المكتملة';

  @override
  String get transferPauseReasonUser => 'تم الإيقاف بواسطة المستخدم';

  @override
  String get transferPauseReasonNetwork => 'تم الإيقاف بسبب انقطاع الشبكة';

  @override
  String get transferPauseReasonAppRestart =>
      'تم الإيقاف بعد إعادة تشغيل التطبيق';

  @override
  String get transferRemotePath => 'المسار البعيد';

  @override
  String get transferLocalPath => 'المسار المحلي';

  @override
  String get transferErrorDetail => 'تفاصيل الخطأ';

  @override
  String get chatFailureKindAuth => 'المصادقة مطلوبة';

  @override
  String get chatFailureKindModelUnavailable => 'النموذج غير متوفر';

  @override
  String get chatFailureKindConnection => 'فشل الاتصال';

  @override
  String get chatFailureKindHistory => 'فشل في السجل';

  @override
  String get chatFailureKindOther => 'فشل الطلب';

  @override
  String get chatFailureActionLogin => 'تسجيل الدخول';

  @override
  String get chatFailureActionRunSettings => 'إعدادات النموذج';

  @override
  String get chatFailureActionReconnect => 'إعادة الاتصال';

  @override
  String get chatFailureActionReloadHistory => 'إعادة المحاولة';

  @override
  String get chatFailureActionDetails => 'التفاصيل';

  @override
  String get sftpConfigureToolbar => 'تخصيص شريط الأدوات';

  @override
  String get sftpConfigureToolbarDesc =>
      'اختر الإجراءات المراد تثبيتها مباشرة في شريط الأدوات. ستظهر الإجراءات الأخرى في قائمة المزيد.';

  @override
  String get sftpToolbarPreferenceSaveFailed => 'فشل حفظ تفضيلات شريط الأدوات';

  @override
  String get sftpToolbarActionView => 'تبديل طريقة العرض';

  @override
  String agentUpdateNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تحديث متاح للوكيل',
      many: '$count تحديثًا متاحًا للوكيل',
      few: '$count تحديثات متاحة للوكيل',
      two: 'تحديثان متاحان للوكيل',
      one: 'تحديث واحد متاح للوكيل',
      zero: 'لا توجد تحديثات متاحة للوكيل',
    );
    return '$_temp0';
  }

  @override
  String get agentUpdateViewAction => 'عرض';

  @override
  String get agentUpdateCheckAll => 'التحقق من التحديثات';

  @override
  String get agentUpdateCheck => 'التحقق من التحديث';

  @override
  String get agentUpdateChecking => 'جارٍ التحقق...';

  @override
  String get agentUpdateAvailable => 'تحديث متوفر';

  @override
  String get agentUpdateUpToDate => 'محدّث';

  @override
  String get agentUpdateDialogTitle => 'تحديث الوكيل';

  @override
  String get agentUpdateConfirmButton => 'تأكيد وتحديث';

  @override
  String get agentUpdateCancelButton => 'إلغاء';

  @override
  String get agentUpdateTargetServer => 'الخادم';

  @override
  String get agentUpdateTargetEnvironment => 'البيئة';

  @override
  String get agentUpdateTargetIdentity => 'الهوية';

  @override
  String get agentUpdateCommandPreview => 'معاينة الأمر';

  @override
  String get agentUpdateClaudeMigrationNotice =>
      'يقوم هذا التحديث بترحيل محول Claude القديم (claude-code-acp) إلى محول claude-agent-acp الرسمي. يتم الاحتفاظ بالسجل وبيانات الاعتماد الحالية.';

  @override
  String get agentUpdateAgyNotice =>
      'يتم تحديث AgY CLI عبر قناة الإصدار المستقر الرسمية. قد يكون الإصدار المثبت أحدث من اللقطة المعروضة في وقت التأكيد.';

  @override
  String get agentUpdateLogs => 'سجلات التحديث';

  @override
  String get agentUpdateCopyLog => 'نسخ السجل';

  @override
  String get agentUpdateLogCopied => 'تم نسخ سجل التحديث إلى الحافظة';

  @override
  String get agentUpdateSuccess => 'تم تحديث الوكيل بنجاح';

  @override
  String get agentUpdateFailed => 'فشل التحديث';

  @override
  String get agentUpdateInterrupted =>
      'تمت مقاطعة التحديث أو فقد الاتصال. يرجى التحقق من الإصدار الفعلي قبل إعادة المحاولة؛ تم تعطيل عمليات إعادة المحاولة التلقائية للأمان.';

  @override
  String get agentUpdateInProgress =>
      'هناك تحديث قيد التنفيذ حاليًا على هذا الخادم.';

  @override
  String get agentUpdateBusy =>
      'الخادم أو الوكيل مشغول. يرجى الانتظار حتى تنتهي المهام النشطة.';

  @override
  String get agentUpdateVersionUnknown => 'غير معروف';

  @override
  String get agentUpdateSource => 'المصدر';

  @override
  String get agentUpdateLastChecked => 'آخر تحقق';

  @override
  String get agentUpdateNeverChecked => 'لم يتم التحقق مطلقًا';

  @override
  String get agentUpdateCodexMigrationTitle =>
      'تثبيت المحول الجديد والتبديل إلى هذا الوكيل';

  @override
  String get agentUpdateCodexMigrationNotice =>
      'سيتم الاحتفاظ بالبرنامج والإعدادات الحالية، وتثبيت محول جديد مستقل ثم تحويل الاتصال، مع إمكانية التراجع بأمان في حالة حدوث مشاكل.';

  @override
  String get agentUpdateReplacementCommand => 'الأمر البديل';

  @override
  String get terminalGridEditLayout => 'تعديل تخطيط الأزرار';

  @override
  String get terminalGridSave => 'حفظ';

  @override
  String get terminalGridCancel => 'إلغاء';

  @override
  String get terminalGridUndo => 'تراجع';

  @override
  String get terminalGridDiscardConfirm =>
      'هل تريد تجاهل التغييرات غير المحفوظة؟';

  @override
  String get terminalGridSaveFailed => 'فشل حفظ تخطيط شريط الأزرار';

  @override
  String get terminalGridCorruptedPrompt =>
      'تكوين شريط الأزرار تالف. هل تريد استعادة التخطيط الافتراضي؟';

  @override
  String get terminalGridCorruptedReset => 'إعادة ضبط';

  @override
  String get terminalGridAddTab => 'إضافة';

  @override
  String get terminalGridKeyTab => 'زر';

  @override
  String get terminalGridSetTab => 'الإعدادات';

  @override
  String get terminalGridCurrentPage => 'الصفحة';

  @override
  String get terminalGridAddPage => '＋ إضافة صفحة';

  @override
  String get terminalGridDeletePage => 'حذف الصفحة';

  @override
  String terminalGridDeletePageConfirm(int page) {
    return 'هل تريد حذف الصفحة $page وجميع أزرارها؟';
  }

  @override
  String get terminalGridDeleteKey => 'حذف الزر';

  @override
  String get terminalGridRows => 'صفوف لوحة المفاتيح';

  @override
  String get terminalGridRowsSubtitle => '1–5 صفوف، الافتراضي 2 صف';

  @override
  String get terminalGridInvertedT => 'مجموعة أسهم حرف T مقلوب';

  @override
  String get terminalGridInvertedTSubtitle => 'عطّل للفصل إلى 4 أزرار مستقلة';

  @override
  String get terminalGridSplitArrows => 'فصل إلى أزرار مستقلة';

  @override
  String get terminalGridDeleteArrows => 'حذف مجموعة الأسهم';

  @override
  String get terminalGridReset => 'استعادة التخطيط الافتراضي';

  @override
  String get terminalGridResetConfirm =>
      'هل تريد إعادة التعيين إلى تخطيط الأزرار الافتراضي؟';

  @override
  String get terminalGridNoSpace =>
      'لا توجد مساحة شاغرة في الصفحة الحالية. أضف صفحة، زد الصفوف، أو احذف أزراراً.';

  @override
  String get terminalGridArrowsNeedTwoRows =>
      'تتطلب أسهم T المقلوب صفين على الأقل. افصل الأسهم أولاً في الإعدادات.';

  @override
  String get terminalGridArrowsNeedSpace =>
      'تتطلب أسهم T المقلوب مساحة 3×2 في الصفحة الحالية.';

  @override
  String get terminalGridKeepAtLeastOnePage =>
      'يجب الاحتفاظ بصفحة واحدة على الأقل';

  @override
  String terminalGridPageSpaceInsufficient(int page) {
    return 'المساحة في الصفحة $page غير كافية. احذف أو انقل بعض الأزرار أولاً.';
  }

  @override
  String get terminalGridMetaNotSupported =>
      'زر Meta غير مدعوم في بروتوكول الطرفية';

  @override
  String get terminalGridSelectKeyHint =>
      'اضغط على زر لتعديل خصائصه\nاضغط مطولاً واسحب لتغيير موضعه';

  @override
  String get terminalGridDisplayName => 'الاسم المعروض';

  @override
  String get terminalGridActionSend => 'إرسال';

  @override
  String get terminalGridWidth => 'العرض (خانات)';

  @override
  String get terminalGridCustomCombo => 'اختصار مخصص';

  @override
  String get terminalGridCustomComboHint =>
      'حدد المفاتيح التبديلية + أدخل الزر';

  @override
  String get terminalGridKeyHint => 'زر، مثل C / F5 / Tab';

  @override
  String get terminalGridDisplayNameOptional => 'الاسم المعروض (اختياري)';

  @override
  String get terminalGridPleaseEnterKey => 'يرجى إدخال الزر';

  @override
  String get terminalGridTextMacro => 'ماكرو نصي';

  @override
  String get terminalGridTextMacroSubtitle => 'نقرة واحدة لإرسال نص محدد';

  @override
  String get terminalGridMacroTextHint => 'مثل ls -la';

  @override
  String get terminalGridMacroAppendEnter => 'إدخال';

  @override
  String get terminalGridPleaseEnterText => 'يرجى إدخال النص';

  @override
  String get terminalGridSingleKey => 'زر مفرد';

  @override
  String get terminalGridComboKey => 'اختصار مركب';

  @override
  String get terminalGridMacroKey => 'ماكرو';

  @override
  String get terminalCategoryCommon => 'شائعة';

  @override
  String get terminalCategoryNav => 'التنقل';

  @override
  String get terminalCategoryEdit => 'تحرير';

  @override
  String get terminalCategorySym => 'رموز';

  @override
  String get terminalCategoryModifiers => 'مفاتيح التبديل';

  @override
  String get terminalCategoryCustom => 'مخصص';

  @override
  String get terminalSearchPresets => 'البحث في الأزرار الجاهزة...';

  @override
  String get terminalGridActionEdit => 'تعديل إجراء الإرسال';

  @override
  String get terminalGridActionKey => 'الزر المراد إرساله';

  @override
  String get terminalGridActionModifiers => 'مفاتيح التبديل';

  @override
  String get terminalGridActionText => 'النص المراد إرساله';

  @override
  String get terminalSearchNoMatch => 'لا توجد مفاتيح مطابقة';

  @override
  String get terminalStatusEndedUnrecoverable => 'منتهية · لا يمكن الاستعادة';

  @override
  String get terminalStatusUnavailable => 'المصدر غير متاح';

  @override
  String get terminalGroupUnconfirmed => 'غير مؤكد';

  @override
  String get terminalGroupUnavailable => 'المصدر غير متاح';

  @override
  String get terminalExternalBadge => 'خارجي';

  @override
  String terminalAttachedClients(int count) {
    return 'العملاء: $count';
  }

  @override
  String get terminalHideSession => 'إخفاء من السجل';

  @override
  String get terminalUnhideSession => 'إلغاء الإخفاء';

  @override
  String get terminalHiddenSessionsTitle => 'الجلسات المخفية';

  @override
  String get terminalNoHiddenSessions => 'لا توجد جلسات مخفية';

  @override
  String get terminalSocketSources => 'مصادر المقبس';

  @override
  String get terminalSourceBuiltin => 'مدمج';

  @override
  String get terminalSourceCustom => 'مخصص';

  @override
  String get terminalAddSocketSource => 'إضافة مصدر مقبس';

  @override
  String get terminalSocketKindNamed => 'مقبس مسمى (-L)';

  @override
  String get terminalSocketKindPath => 'مقبس المسار (-S)';

  @override
  String get terminalSocketInputHint => 'اسم المقبس أو المسار المطلق';

  @override
  String get terminalSocketInvalid =>
      'تنسيق المقبس غير صالح. المقابس المسماة تستخدم 1-64 حرفًا وأرقامًا؛ مقابس المسار يجب أن تبدأ بـ / ولا تحتوي على \'..\'';

  @override
  String get terminalSocketExists => 'مصدر المقبس هذا مضاف بالفعل.';

  @override
  String terminalTerminateClientsWarning(int count) {
    return 'تحذير: يوجد حاليًا $count عميل متصل بهذه الجلسة. الإنهاء سيقطع اتصال الجميع.';
  }

  @override
  String get terminalTerminateSession => 'إنهاء الجلسة';

  @override
  String get terminalSocketLabel => 'مقبس';

  @override
  String get terminalServerLabel => 'الخادم';

  @override
  String terminalSocketErrorsBanner(int count) {
    return '$count خطأ في مصدر المقبس';
  }

  @override
  String get persistentRuntimeDialogTitle => 'بيئة تشغيل الوكيل الدائمة';

  @override
  String get persistentRuntimeDialogDescription =>
      'قم بتمكين التشغيل في الخلفية لمواصلة المهام عند إغلاق التطبيق أو انقطاع الاتصال.';

  @override
  String get persistentRuntimeFeaturePythonTitle => 'خدمة على مستوى المستخدم';

  @override
  String get persistentRuntimeFeaturePythonDesc =>
      'تعمل عبر Python 3.9+ القياسي تحت حسابك دون الحاجة لصلاحيات root.';

  @override
  String get persistentRuntimeFeatureSshTitle => 'عبر SSH فقط';

  @override
  String get persistentRuntimeFeatureSshDesc =>
      'لا يتم فتح أي منافذ عامة. معزول بالكامل عبر اتصال SSH الحالي.';

  @override
  String get persistentRuntimeFeatureRetentionTitle =>
      'الاحتفاظ بالمخرجات لمدة 7 أيام';

  @override
  String get persistentRuntimeFeatureRetentionDesc =>
      'يتم حفظ المخرجات وسجلات التنفيذ على الخادم لمدة 7 أيام بعد الانتهاء.';

  @override
  String get persistentRuntimeFeatureDetachedTitle => 'تشغيل مستقل في الخلفية';

  @override
  String get persistentRuntimeFeatureDetachedDesc =>
      'يستمر الوكيل في العمل بسلاسة حتى لو تم إغلاق التطبيق.';

  @override
  String get persistentRuntimeEnableAction => 'تمكين بيئة التشغيل';

  @override
  String get persistentRuntimeSettingUp =>
      'جارٍ إعداد بيئة التشغيل على الخادم...';

  @override
  String get dismissRecoveryNoticeTooltip => 'تجاهل الإشعار';

  @override
  String get terminalReconnectTab => 'إعادة توصيل الطرفية';

  @override
  String get terminalCloseTabConfirmTitle => 'إغلاق علامة التبويب';

  @override
  String get terminalClosePlainConfirmMessage =>
      'سيؤدي إغلاق علامة التبويب هذه إلى قطع الاتصال. قد يتم إنهاء أي عملية قيد التشغيل في الواجهة.';

  @override
  String get terminalCloseTmuxConfirmMessage =>
      'هذه الطرفية تعمل داخل tmux. إغلاق علامة التبويب سيفصلها فقط عن العرض الحالي؛ ستستمر الجلسة في الخلفية.';

  @override
  String get terminalCloseActionTerminate => 'إنهاء وإغلاق';

  @override
  String get terminalCloseActionDetach => 'فصل وإغلاق';

  @override
  String acpRunningSessionIndicator(String agentName) {
    return 'مهمة قيد التشغيل: $agentName';
  }

  @override
  String get acpReturnToRunningSession => 'العودة إلى الجلسة النشطة';

  @override
  String get acpServerBusySendDisabled =>
      'الخادم ينفذ مهمة أخرى حاليًا. يرجى الانتظار حتى تكتمل.';

  @override
  String get deleteSessionLocalOnlyOption => 'حذف السجل المحلي فقط';

  @override
  String get deleteSessionStopAndPurgeOption =>
      'إيقاف التشغيل وتطهير بيانات بيئة التشغيل البعيدة';

  @override
  String get deleteSessionPurgeRemoteWarning =>
      'سيؤدي هذا إلى إيقاف العملية في الخلفية على الخادم وتطهير ذاكرة التخزين المؤقت الخاصة بالتطبيق.';

  @override
  String get permissionViewDetails => 'عرض التفاصيل';

  @override
  String get permissionDetailsTitle => 'تفاصيل طلب الإذن';

  @override
  String get permissionToolLabel => 'الأداة المطلوبة';

  @override
  String get permissionCommandLabel => 'الأمر المراد تنفيذه';

  @override
  String get permissionCopyCommand => 'نسخ الأمر';

  @override
  String get permissionCommandCopied => 'تم نسخ الأمر إلى الحافظة';

  @override
  String get chatScrollToLatest => 'الانتقال إلى الأحدث';

  @override
  String get deleteSessionNoManagedRuntimes =>
      'لم يتم العثور على مثيلات وقت تشغيل مُدارة لهذه الجلسة.';

  @override
  String get deleteSessionAffectedRuntimes => 'مثيلات وقت التشغيل المتأثرة:';

  @override
  String get deleteSessionInspectingRuntimes =>
      'جارٍ فحص بيئات التشغيل عن بُعد...';

  @override
  String get deleteSessionOfflineNotice =>
      'الخادم غير متصل. الحذف المحلي فقط هو المتاح.';

  @override
  String get chatWorkbench => 'مساحة العمل';

  @override
  String get chatWorkbenchFiles => 'الملفات';

  @override
  String get chatWorkbenchTasks => 'المهام والأدوات';

  @override
  String get chatWorkbenchContext => 'السياق';

  @override
  String get chatWorkspaceProjects => 'المشاريع';

  @override
  String get chatWorkspaceEditAlias => 'تعديل اسم المشروع المستعار';

  @override
  String get chatWorkspaceAliasLabel => 'اسم المشروع المستعار';

  @override
  String get chatWorkspaceFavorite => 'تفضيل المشروع';

  @override
  String get chatWorkspaceUnfavorite => 'إلغاء تفضيل المشروع';

  @override
  String get chatLoopbackConfirmTitle => 'فتح عنوان الاسترجاع البعيد';

  @override
  String get chatLoopbackConfirmMessage =>
      'يشير هذا الرابط إلى المضيف المحلي البعيد. هل تريد فتحه في متصفحك؟';

  @override
  String get chatConfirmSaveFile => 'تأكيد الحفظ';

  @override
  String get chatConfirmSaveFileMessage => 'حفظ التغييرات في هذا الملف؟';

  @override
  String get chatFileReadOnly => 'للقراءة فقط';

  @override
  String get chatCopyError => 'نسخ الخطأ';

  @override
  String get chatFileOutsideWorkspace =>
      'الملف خارج دليل مساحة العمل. هل تريد فتحه؟';

  @override
  String get chatUnsavedChangesTitle => 'تغييرات غير محفوظة';

  @override
  String get chatUnsavedChangesMessage =>
      'لديك تغييرات غير محفوظة. هل تريد تجاهلها؟';

  @override
  String get chatDiscard => 'تجاهل';

  @override
  String get chatNoChangesToSave => 'لا توجد تغييرات لحفظها';

  @override
  String get chatFileSaved => 'تم حفظ الملف بنجاح';

  @override
  String get chatLoadingFile => 'جارٍ تحميل الملف...';

  @override
  String get chatEditorUnavailable => 'محرر الحاوية غير متوفر (يتطلب python3).';

  @override
  String get chatFileNotEditable =>
      'لا يمكن تعديل الملفات الثنائية أو الكبيرة جدًا.';

  @override
  String get chatFailedToOpenLink => 'فشل فتح الرابط';

  @override
  String get chatNoActiveTasks => 'لا توجد مهام نشطة أو عمليات تنفيذ للأدوات';

  @override
  String get chatNoFilesInDirectory => 'لا توجد ملفات في هذا الدليل';

  @override
  String get chatViewCurrentRun => 'عرض التشغيل الحالي';

  @override
  String get chatExecutionChangedPrompt =>
      'تغيرت بيئة تنفيذ الجلسة. يرجى إنشاء جلسة جديدة للمتابعة.';

  @override
  String get chatLinkCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get chatFileEditorEdit => 'تعديل';

  @override
  String get chatFileEditorDiff => 'الفروق';

  @override
  String terminalLastChecked(String time) {
    return 'آخر فحص: $time';
  }

  @override
  String get terminalNotChecked => 'لم يتم الفحص';

  @override
  String get terminalLastCheckedTitle => 'آخر فحص';

  @override
  String chatExpandCode(String lines) {
    return 'توسيع التعليمات البرمجية ($lines سطرًا)';
  }

  @override
  String get chatCollapseCode => 'طي التعليمات البرمجية';

  @override
  String get chatCodeReaderTitle => 'قارئ التعليمات البرمجية';

  @override
  String get chatCodeCopied => 'تم نسخ التعليمات البرمجية إلى الحافظة';

  @override
  String get acpAgentOfflineRunning => 'غير متصل (المهمة تعمل في الخلفية)';

  @override
  String get acpAgentOfflineTaskRunning =>
      'اتصال SSH غير متصل. قد تظل مهمة الوكيل قيد التشغيل في الخلفية.';

  @override
  String get chatCloseBanner => 'إغلاق';

  @override
  String get chatSearchTitle => 'البحث في سجل المحادثات';

  @override
  String get chatSearchHint => 'البحث في الرسائل ومخرجات الأدوات...';

  @override
  String get chatSearchScopeCurrent => 'الجلسة الحالية';

  @override
  String get chatSearchScopeAll => 'الخادم الحالي';

  @override
  String get chatSearchNoResults => 'لم يتم العثور على رسائل مطابقة';

  @override
  String get chatSearchNoQuery => 'اكتب للبحث في السجل';

  @override
  String chatSearchResultsCount(String count) {
    return 'تم العثور على $count نتيجة';
  }

  @override
  String get chatSearchReaderTitle => 'معاينة سياق الرسالة';

  @override
  String get chatSearchGoToSession => 'فتح الجلسة الأصلية';

  @override
  String get chatSearchBackToResults => 'العودة إلى النتائج';

  @override
  String get chatSearchSourceMessage => 'رسالة';

  @override
  String get chatSearchSourceTool => 'مخرجات الأداة';

  @override
  String get chatSearchRemoteFileDisabled =>
      'لا يمكن فتح الملفات البعيدة من معاينة البحث. افتح الجلسة الأصلية للعرض.';

  @override
  String get chatSearchTargetChanged => 'تغيرت الجلسة أو الخادم أثناء البحث';

  @override
  String get terminalSearch => 'بحث في الطرفية';

  @override
  String get terminalSearchHint => 'بحث...';

  @override
  String get terminalSearchPrev => 'المطابقة السابقة';

  @override
  String get terminalSearchNext => 'المطابقة التالية';

  @override
  String get terminalSearchFollowLatest => 'العودة إلى الأحدث';

  @override
  String terminalSearchCount(String current, String total) {
    return '$current من $total';
  }

  @override
  String terminalSearchCountOverflow(String current) {
    return '$current من أكثر من 1000';
  }

  @override
  String get terminalSearchNoMatches => 'لا توجد مطابقات';

  @override
  String get chatRoleUser => 'المستخدم';

  @override
  String get chatRoleAssistant => 'المساعد';

  @override
  String get chatRoleSystem => 'النظام';

  @override
  String get chatCommandFilterAll => 'الكل';

  @override
  String get chatCommandFilterFavorites => 'المفضلة';

  @override
  String get chatCommandFilterRecent => 'الأخيرة';

  @override
  String get chatCommandFavoriteAdd => 'إضافة إلى المفضلة';

  @override
  String get chatCommandFavoriteRemove => 'إزالة من المفضلة';

  @override
  String get chatCommandUnavailable => 'غير متوفر في الوكيل الحالي';

  @override
  String get chatCommandPreferencesSaveFailed => 'فشل حفظ تفضيلات الأوامر';

  @override
  String get chatResetDraftWorkingDir => 'إعادة تعيين دليل العمل إلى الافتراضي';

  @override
  String get terminalClearAllModifiers => 'مسح جميع مفاتيح التعديل';

  @override
  String get terminalSavedCommandsTitle => 'الأوامر المحفوظة';

  @override
  String get terminalSavedCommandsRun => 'تشغيل الأمر';

  @override
  String get terminalSavedCommandsEmpty => 'لا توجد أوامر محفوظة';

  @override
  String get terminalSavedCommandsPreview => 'معاينة الأمر';

  @override
  String get terminalSavedCommandsMultilineWarning =>
      'يحتوي هذا الأمر على أسطر متعددة. هل أنت متأكد أنك تريد تشغيله؟';

  @override
  String get terminalModifierHelp =>
      'اضغط على مفتاح التعديل للاستخدام لمرة واحدة؛ اضغط مطولاً للقفل. استمر في الضغط لتكرار الإدخال.';

  @override
  String get serverWorkspaceTitle => 'مساحة عمل الخادم';

  @override
  String get serverWorkspaceSubtitle =>
      'مزامنة الحالة متعددة الأجهزة ومسودات الأجهزة';

  @override
  String get serverWorkspaceOriginServer => 'الخادم النشط';

  @override
  String get serverWorkspaceOriginUser => 'المستخدم البعيد';

  @override
  String get serverWorkspaceNoActiveServer => 'لم يتم تحديد أو اتصال خادم نشط';

  @override
  String get serverWorkspacePhaseLocal => 'محلي فقط';

  @override
  String get serverWorkspacePhaseDiscovering => 'جارٍ الاكتشاف...';

  @override
  String get serverWorkspacePhaseAvailable => 'متاح للتمكين';

  @override
  String get serverWorkspacePhaseSyncing => 'جارٍ المزامنة...';

  @override
  String get serverWorkspacePhaseReady => 'متزامن';

  @override
  String get serverWorkspacePhaseOffline => 'غير متصل';

  @override
  String get serverWorkspacePhaseError => 'خطأ في المزامنة';

  @override
  String serverWorkspaceLastSynced(String time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String get serverWorkspaceNeverSynced => 'لم تتم المزامنة من قبل';

  @override
  String serverWorkspacePendingChanges(int count) {
    return '$count من التغييرات المعلقة';
  }

  @override
  String get serverWorkspaceNoPendingChanges => 'تمت مزامنة جميع التغييرات';

  @override
  String get serverWorkspaceEnable => 'تمكين مساحة عمل الخادم';

  @override
  String get serverWorkspaceEnableDialogTitle => 'تمكين مساحة عمل الخادم';

  @override
  String get serverWorkspaceEnableDialogMessage =>
      'سيؤدي التمكين إلى نقل الإعدادات المحلية إلى الخادم. سيتم الحفاظ على إعداداتك المحلية بالكامل.';

  @override
  String get serverWorkspaceMigrationPreviewTitle => 'معاينة النقل';

  @override
  String get serverWorkspaceEnableConfirm => 'تأكيد وتمكين';

  @override
  String get serverWorkspaceNoDataToMigrate => 'لا توجد بيانات محلية للنقل';

  @override
  String get serverWorkspaceSyncNow => 'مزامنة الآن';

  @override
  String get serverWorkspaceDisable => 'تعطيل المزامنة';

  @override
  String get serverWorkspaceDisableDialogTitle => 'تعطيل مساحة عمل الخادم';

  @override
  String get serverWorkspaceDisableDialogMessage =>
      'سيؤدي التعطيل إلى إيقاف المزامنة على هذا الجهاز. سيتم الاحتفاظ بالبيانات المحلية والبعيدة ولن يتم حذفها.';

  @override
  String get serverWorkspaceDisableConfirm => 'تعطيل';

  @override
  String get serverWorkspacePreferenceSource => 'استخدام كمصدر التفضيلات';

  @override
  String get serverWorkspacePreferenceSourceDesc =>
      'مزامنة إعدادات التطبيق العامة من هذا الخادم';

  @override
  String serverWorkspaceConflictsTitle(int count) {
    return 'تعارضات المزامنة ($count)';
  }

  @override
  String get serverWorkspaceConflictKeepLocal => 'الاحتفاظ بالمحلي';

  @override
  String get serverWorkspaceConflictKeepServer => 'الاحتفاظ بالخادم';

  @override
  String get serverWorkspaceDeviceDraftsTitle => 'مسودات الأجهزة الأخرى';

  @override
  String get serverWorkspaceRestoreDraft => 'استعادة المسودة';

  @override
  String get serverWorkspaceRestoreDraftConfirmTitle => 'استعادة مسودة الجهاز';

  @override
  String get serverWorkspaceRestoreDraftConfirmMessage =>
      'ستؤدي استعادة هذه المسودة إلى استبدال مدخلات الدردشة الحالية. سيتم حفظ مسودتك الحالية في قائمة المسودات البعيدة.';

  @override
  String get serverWorkspaceRestoreDraftConfirm => 'استعادة';

  @override
  String get serverWorkspaceNoDeviceDrafts => 'لا توجد مسودات من أجهزة أخرى';

  @override
  String get serverWorkspaceClearCache =>
      'مسح ذاكرة التخزين المؤقت للمزامنة المحلية';

  @override
  String get serverWorkspaceClearCacheConfirmTitle =>
      'مسح ذاكرة التخزين المؤقت للمزامنة المحلية';

  @override
  String get serverWorkspaceClearCacheConfirmMessage =>
      'سيؤدي هذا الإجراء إلى مسح ذاكرة التخزين المؤقت وحالة المزامنة المحلية فقط. لن يتم مطلقاً حذف بيانات الخادم أو اتصالات SSH.';

  @override
  String get serverWorkspaceClearCacheConfirm => 'مسح الذاكرة المؤقتة';

  @override
  String get serverWorkspaceCacheCleared =>
      'تم مسح ذاكرة التخزين المؤقت للمزامنة المحلية';

  @override
  String get serverWorkspaceErrorSetupFailed => 'فشل تهيئة مساحة عمل الخادم';

  @override
  String get serverWorkspaceErrorPythonRequired =>
      'يتطلب الخادم إصدار Python 3.9 أو أحدث';

  @override
  String get serverWorkspaceErrorPathUnsafe =>
      'مسار مساحة عمل الخادم غير آمن أو أذوناته غير صحيحة';

  @override
  String get serverWorkspaceErrorConflict =>
      'تم اكتشاف تعارض في البيانات أثناء المزامنة';

  @override
  String get serverWorkspaceErrorControlHeld =>
      'التحكم في الجلسة مشغول بواسطة جهاز آخر';

  @override
  String get serverWorkspaceErrorResponseTooLarge =>
      'تجاوزت استجابة الخادم الحد الأقصى المسموح به';

  @override
  String serverWorkspaceErrorGeneric(String code) {
    return 'خطأ في مساحة العمل ($code)';
  }

  @override
  String get chatWorkspaceControlActive => 'تحت السيطرة';

  @override
  String get chatWorkspaceControlActiveTooltip =>
      'يتحكم هذا الجهاز حالياً في الجلسة';

  @override
  String get chatWorkspaceReadOnly => 'للقراءة فقط';

  @override
  String chatWorkspaceReadOnlyDevice(String device) {
    return 'للقراءة فقط ($device)';
  }

  @override
  String get chatWorkspaceAcquireControl => 'اكتساب التحكم';

  @override
  String get chatWorkspaceTakeover => 'استلام التحكم';

  @override
  String get chatWorkspaceTakeoverDialogTitle => 'استلام التحكم في الجلسة';

  @override
  String get chatWorkspaceTakeoverDialogMessage =>
      'يتيح استلام التحكم لهذا الجهاز إرسال الرسائل وتشغيل الجلسة الحالية. لن يتم إنهاء الوكيل المشغل ولن يتم تبديل الجلسة.';

  @override
  String get chatWorkspaceTakeoverConfirm => 'تأكيد الاستلام';

  @override
  String get chatWorkspaceControlFailed =>
      'فشل الحصول على التحكم في مساحة العمل';

  @override
  String get serverWorkspaceErrorRuntimeUpgradeRequired =>
      'يوجد مكون وقت تشغيل قديم يعمل حالياً. يرجى إنهاؤه على الجهاز الأصلي قبل الترقية.';

  @override
  String get serverWorkspaceErrorNotEnabled => 'مساحة عمل الخادم غير ممكّنة';

  @override
  String get serverWorkspaceErrorPendingChanges =>
      'لا يمكن مسح الذاكرة المؤقتة مع وجود تغييرات معلقة. يرجى المزامنة أولاً.';

  @override
  String get serverWorkspaceDraftTypeFile => 'مسودة ملف';

  @override
  String get serverWorkspaceDraftTypeChat => 'مسودة دردشة';

  @override
  String get serverWorkspaceRestoreFileDraftConfirmTitle =>
      'استعادة مسودة الملف';

  @override
  String get serverWorkspaceRestoreFileDraftConfirmMessage =>
      'ستؤدي استعادة مسودة الملف هذه إلى تحميلها في مسودات المحرر المحلي. سيتم حفظ مسودتك الحالية في المسودات البعيدة.';

  @override
  String get persistentRuntimeFeatureWorkspaceTitle =>
      'مساحة عمل الخادم ومزامنة الحالة';

  @override
  String get persistentRuntimeFeatureWorkspaceDesc =>
      'تحتفظ بيئة التشغيل الخاصة بالمستخدم بالمخرجات عند إغلاق التطبيق؛ تظل بيانات اعتماد ومفاتيح SSH محلية ولا تتم مزامنتها مطلقاً.';

  @override
  String get serverWorkspaceMigrationPendingHint =>
      'يجري ترحيل البيانات السابقة في الخلفية. تمت مزامنة الإعدادات بينما يكتمل ترحيل السجل في الخلفية.';

  @override
  String get serverWorkspaceLoadMoreDrafts => 'تحميل المزيد من المسودات';

  @override
  String get serverWorkspaceLoadingDrafts => 'جارٍ تحميل المسودات...';
}
