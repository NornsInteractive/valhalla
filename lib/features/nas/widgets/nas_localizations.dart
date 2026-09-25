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

  String nasSanitizedError(dynamic error) {
    final str = error.toString();
    if (str.contains('NAS_SOURCE_NAME_REQUIRED')) return nasSourceNameRequired;
    if (str.contains('NAS_INVALID_ENDPOINT')) return nasInvalidEndpoint;
    if (str.contains('NAS_AUTH_FAILED')) return nasAuthFailed;
    if (str.contains('NAS_SSH_TUNNEL_FAILED')) return nasSshTunnelFailed;
    if (str.contains('NAS_EXTERNAL_OPEN_FAILED')) return nasExternalOpenFailed;
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
    if (str.contains('NAS_SOURCE_UNREACHABLE') ||
        str.contains('SocketException') ||
        str.contains('Connection refused')) {
      return nasSourceUnreachable;
    }
    return str
        .replaceAll(RegExp(r':[^@/]+@'), ':***@')
        .replaceAll(RegExp(r'token=[^&\s]+'), 'token=***');
  }
}
