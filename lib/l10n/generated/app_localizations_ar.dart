// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'DynaOps';

  @override
  String get shellLoading => 'جارٍ تحميل DynaOps…';

  @override
  String get shellOfflineTitle => 'لا يوجد اتصال';

  @override
  String get shellOfflineMessage =>
      'تحقق من اتصالك بالإنترنت. سيُعاد تحميل DynaOps تلقائيًا عند عودة الاتصال.';

  @override
  String get shellLoadErrorTitle => 'تعذّر تحميل DynaOps';

  @override
  String get shellLoadErrorMessage =>
      'لم يستجب الخادم. حاول مرة أخرى بعد قليل.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get exitTitle => 'مغادرة DynaOps؟';

  @override
  String get exitMessage => 'يمكنك العودة في أي وقت.';

  @override
  String get exitConfirm => 'مغادرة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get trackingChannelName => 'تتبّع الموقع';

  @override
  String get trackingChannelDescription =>
      'يظهر أثناء مشاركة DynaOps لموقعك خلال العمل.';

  @override
  String get trackingNotificationTitle => 'DynaOps';

  @override
  String get trackingNotificationRunning => 'تتم مشاركة موقعك أثناء العمل';

  @override
  String get trackingNotificationPaused => 'تتبّع الموقع متوقف مؤقتًا';

  @override
  String get trackingNotificationOutsideShift =>
      'خارج وقت ورديتك — يُستأنف التتبّع عند بدايتها';

  @override
  String get trackingNotificationPermission =>
      'مطلوب إذن الموقع — اضغط لفتح DynaOps';

  @override
  String get trackingNotificationLocationOff => 'شغّل الموقع لمتابعة التتبّع';

  @override
  String get permissionsTitle => 'إعداد تتبّع الموقع';

  @override
  String permissionsStepCounter(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get stepLocationTitle => 'السماح بالموقع';

  @override
  String get stepLocationBody =>
      'يسجّل DynaOps مسارك وزياراتك أثناء العمل. اختر \"أثناء استخدام التطبيق\" وأبقِ \"الموقع الدقيق\" مفعّلًا.';

  @override
  String get stepBackgroundTitle => 'السماح بالموقع طوال الوقت';

  @override
  String get stepBackgroundBody =>
      'يجمع DynaOps موقعك حتى عندما يكون التطبيق مغلقًا أو غير مستخدم، خلال وقت العمل فقط، لتسجيل مسارك وزياراتك لمشرفك. في الشاشة التالية اختر \"السماح طوال الوقت\".';

  @override
  String get stepPreciseTitle => 'شغّل الموقع الدقيق';

  @override
  String get stepPreciseBody =>
      'لدى DynaOps موقعك التقريبي فقط، وقد يبعد كيلومترات عن موقعك الحقيقي، لذا لا يمكن تسجيل مسارك. في الإعدادات افتح الأذونات ← الموقع وشغّل \"استخدام الموقع الدقيق\".';

  @override
  String get stepLocationServiceTitle => 'شغّل الموقع';

  @override
  String get stepLocationServiceBody =>
      'خدمة الموقع في هاتفك متوقفة، لذا لا يستطيع DynaOps تسجيل مسارك. شغّل الموقع للمتابعة.';

  @override
  String get stepNotificationsTitle => 'السماح بالإشعارات';

  @override
  String get stepNotificationsBody =>
      'يظهر إشعار صغير أثناء التتبّع لتعرف دائمًا متى تتم مشاركة موقعك.';

  @override
  String get stepBatteryTitle => 'إبقاء DynaOps قيد التشغيل';

  @override
  String get stepBatteryBody =>
      'اسمح لتطبيق DynaOps بتجاهل تحسين البطارية حتى لا يوقف أندرويد التتبّع عند قفل الهاتف.';

  @override
  String get stepOemTitle => 'إعداد إضافي في هاتفك';

  @override
  String get oemSamsung =>
      'افتح الإعدادات ← البطارية ← حدود الاستخدام في الخلفية وأضف DynaOps إلى \"التطبيقات التي لا تدخل في السكون أبدًا\".';

  @override
  String get oemXiaomi =>
      'افتح إعدادات التطبيق، فعّل \"التشغيل التلقائي\" واجعل موفّر البطارية \"بلا قيود\".';

  @override
  String get oemHuawei =>
      'افتح الإعدادات ← البطارية ← تشغيل التطبيقات، ثم اختر DynaOps واسمح بالإدارة اليدوية مع تفعيل المفاتيح الثلاثة.';

  @override
  String get oemOppo =>
      'افتح إعدادات التطبيق ← البطارية واسمح بالنشاط في الخلفية والتشغيل التلقائي.';

  @override
  String get oemVivo =>
      'افتح الإعدادات ← البطارية ← استهلاك الطاقة في الخلفية واسمح لتطبيق DynaOps بالعمل في الخلفية.';

  @override
  String get permissionAllow => 'سماح';

  @override
  String get permissionOpenSettings => 'فتح الإعدادات';

  @override
  String get permissionTurnOnLocation => 'تشغيل الموقع';

  @override
  String get permissionNext => 'التالي';

  @override
  String get permissionDone => 'تم';

  @override
  String get openDiagnostics => 'التشخيص';

  @override
  String get diagnosticsTitle => 'التشخيص';

  @override
  String get diagTracking => 'التتبّع';

  @override
  String get diagSync => 'الرفع';

  @override
  String get diagPolicy => 'إعدادات التتبّع';

  @override
  String get diagDevice => 'الجهاز';

  @override
  String get diagLogs => 'السجل الأخير';

  @override
  String get diagState => 'الحالة';

  @override
  String get diagReason => 'السبب';

  @override
  String get diagError => 'الخطأ';

  @override
  String get diagService => 'خدمة الخلفية';

  @override
  String get diagLocationPermission => 'إذن الموقع';

  @override
  String get diagBackgroundPermission => 'الموقع في الخلفية';

  @override
  String get diagLastFix => 'آخر موقع';

  @override
  String get diagPending => 'بانتظار الرفع';

  @override
  String get diagFailed => 'فشل';

  @override
  String get diagLastUpload => 'آخر رفع';

  @override
  String get diagLastError => 'آخر خطأ';

  @override
  String get diagEnabled => 'مفعّل من المسؤول';

  @override
  String get diagMode => 'الوضع';

  @override
  String get diagShift => 'الوردية';

  @override
  String get diagAppVersion => 'إصدار التطبيق';

  @override
  String get diagModel => 'الطراز';

  @override
  String get diagAndroid => 'إصدار أندرويد (SDK)';

  @override
  String get diagYes => 'نعم';

  @override
  String get diagNo => 'لا';

  @override
  String get diagNone => '—';

  @override
  String get diagSyncNow => 'ارفع الآن';

  @override
  String get diagRetryFailed => 'إعادة محاولة الفاشل';

  @override
  String get diagExportLogs => 'مشاركة السجل';

  @override
  String get diagClearCache => 'مسح ذاكرة الويب المؤقتة';

  @override
  String get diagNoticeSyncStarted => 'بدأ الرفع';

  @override
  String diagNoticeRequeued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُعيدت $count نقطة إلى الطابور',
      many: 'أُعيدت $count نقطة إلى الطابور',
      few: 'أُعيدت $count نقاط إلى الطابور',
      two: 'أُعيدت نقطتان إلى الطابور',
      one: 'أُعيدت نقطة واحدة إلى الطابور',
      zero: 'لا يوجد ما يُعاد',
    );
    return '$_temp0';
  }

  @override
  String get diagNoticeCacheCleared => 'تم مسح ذاكرة الويب المؤقتة';

  @override
  String get diagNoticeActionFailed => 'لم ينجح ذلك. حاول مرة أخرى.';

  @override
  String get reqInspectorTitle => 'مراقب الطلبات';

  @override
  String get reqInspectorOpen => 'فتح مراقب الطلبات';

  @override
  String reqTabRequests(int count) {
    return 'الطلبات ($count)';
  }

  @override
  String reqTabQueue(int count) {
    return 'الطابور ($count)';
  }

  @override
  String get reqEmpty => 'لم تُسجَّل أي طلبات بعد';

  @override
  String get reqQueueEmpty => 'لا يوجد ما ينتظر الرفع';

  @override
  String get reqClear => 'مسح السجل';

  @override
  String get reqRefresh => 'تحديث';

  @override
  String get reqGeneral => 'عام';

  @override
  String get reqUrl => 'الرابط';

  @override
  String get reqMethod => 'الطريقة';

  @override
  String get reqStatus => 'الحالة';

  @override
  String get reqDuration => 'المدة';

  @override
  String reqDurationMs(int ms) {
    return '$ms مللي ثانية';
  }

  @override
  String get reqTime => 'الوقت';

  @override
  String get reqSource => 'أُرسل من';

  @override
  String get reqSourceUi => 'التطبيق';

  @override
  String get reqSourceService => 'خدمة التتبع';

  @override
  String reqPings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      many: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا نقاط',
    );
    return '$_temp0';
  }

  @override
  String get reqRequestHeaders => 'ترويسات الطلب';

  @override
  String get reqRequestBody => 'البيانات المرسلة';

  @override
  String get reqResponseBody => 'الاستجابة';

  @override
  String get reqNoBody => '(فارغ)';

  @override
  String get reqCopy => 'نسخ';

  @override
  String get reqCopied => 'تم النسخ';

  @override
  String get reqNoStatus => 'لا توجد استجابة';

  @override
  String get reqCapturedAt => 'وقت الالتقاط';

  @override
  String get reqAccuracy => 'الدقة';

  @override
  String get reqAttempts => 'المحاولات';

  @override
  String get reqBatch => 'الدفعة';

  @override
  String get reqRetryable => 'قابل لإعادة المحاولة';

  @override
  String get reqUploadRunning => 'الرفع جارٍ';

  @override
  String get reqWirePayload => 'سيُرسل بالشكل';

  @override
  String get reqNoticeSyncBusy => 'هناك عملية رفع جارية بالفعل';

  @override
  String get reqNoticeCleared => 'تم مسح السجل';

  @override
  String get reqLoadFailed => 'تعذّرت قراءة سجل الطلبات';

  @override
  String get permissionsRequiredNote =>
      'يحتاج DynaOps إلى كل هذه الأذونات ليعمل. يمكنك استخدام التطبيق بمجرد السماح بها.';
}
