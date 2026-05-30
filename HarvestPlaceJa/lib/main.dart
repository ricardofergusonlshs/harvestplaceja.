import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const appName = 'The Harvest Place Ja';
  static const supabaseUrl = 'https://zvgvvsgjzfygbsqwawoh.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_fBvBBFqJMlIOm1I3d5Oy-w_AbBGuJKH';

  // Password reset links must go to the FlutLab PREVIEW app, not the editor
  // and not localhost. This exact URL is now in Supabase Auth URL Configuration.
  static const flutLabPreviewUrl =
      'https://preview.flutlab.io/ricardo_ferguson/farm/';

  static const passwordResetUrl =
      'https://preview.flutlab.io/ricardo_ferguson/farm/?resetPassword=true';

  static String? get passwordResetRedirectTo {
    if (!kIsWeb) return null;
    return passwordResetUrl;
  }

  static String? get passwordRecoveryCode {
    if (!kIsWeb) return null;

    try {
      final href = Uri.base.toString();
      final uri = Uri.tryParse(href);
      final queryCode = uri?.queryParameters['code'];
      if (queryCode != null && queryCode.trim().isNotEmpty) {
        return queryCode.trim();
      }

      final match = RegExp(r'(?:[?#&])code=([^&#]+)').firstMatch(href);
      final rawCode = match?.group(1);
      if (rawCode == null || rawCode.trim().isEmpty) return null;
      return Uri.decodeComponent(rawCode.trim());
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> get passwordRecoveryParams {
    final params = <String, String>{};

    void addParams(String raw) {
      var clean = raw.trim();
      if (clean.startsWith('?') || clean.startsWith('#')) {
        clean = clean.substring(1);
      }
      if (clean.isEmpty) return;
      params.addAll(Uri.splitQueryString(clean));
    }

    try {
      addParams(Uri.base.query);
      addParams(Uri.base.fragment);
    } catch (_) {}

    return params;
  }

  static String? get passwordRecoveryAccessToken {
    final token = passwordRecoveryParams['access_token'];
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  static String? get passwordRecoveryRefreshToken {
    final token = passwordRecoveryParams['refresh_token'];
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  static bool get hasPasswordRecoveryCallback {
    if (!kIsWeb) return false;

    final href = Uri.base.toString().toLowerCase();
    final hash = Uri.base.fragment.toLowerCase();
    final search = Uri.base.query.toLowerCase();

    // Supabase may redirect password reset links in PKCE format:
    // https://your-app/?code=...
    // It may also return access/refresh tokens in the URL hash.
    // Those values must create a session before updateUser(password) works.
    return href.contains('resetpassword=true') ||
        passwordRecoveryCode != null ||
        passwordRecoveryRefreshToken != null ||
        href.contains('type=recovery') ||
        hash.contains('type=recovery') ||
        search.contains('type=recovery');
  }

  static void cleanPasswordRecoveryUrl() {
    if (!kIsWeb) return;

    try {
      SystemNavigator.routeInformationUpdated(location: '/', replace: true);
    } catch (_) {}
  }
}

class AppPerformanceConfig {
  static const debounce = Duration(milliseconds: 180);
  static const realtimeDebounce = Duration(milliseconds: 650);
  static const productRailCacheExtent = 420.0;
}

void _syncKeyboardStateSafely() {
  if (!kIsWeb) return;
  try {
    HardwareKeyboard.instance.syncKeyboardState().catchError((_) {});
  } catch (_) {}
}

bool _isFlutLabKeyboardAssertion(Object error, StackTrace? stack) {
  final errorText = error.toString();
  final stackText = stack?.toString() ?? '';

  return errorText.contains('hardware_keyboard.dart') ||
      stackText.contains('hardware_keyboard.dart') ||
      errorText.contains('_pressedKeys') ||
      errorText.contains('KeyDownEvent') ||
      errorText.contains('KeyUpEvent') ||
      errorText.contains('mouse_tracker.dart') ||
      stackText.contains('mouse_tracker.dart') ||
      errorText.contains('MouseTracker') ||
      stackText.contains('MouseTracker') ||
      errorText.contains('_dependents.isEmpty') ||
      stackText.contains('_dependents.isEmpty') ||
      errorText.contains('framework.dart') &&
          errorText.contains('Assertion failed') ||
      stackText.contains('framework.dart') &&
          errorText.contains('Assertion failed') ||
      errorText
          .contains('Tried to build dirty widget in the wrong build scope') ||
      errorText.contains('Unexpected null value');
}

void _installFlutLabKeyboardWorkaround() {
  if (!kIsWeb) return;

  final previousErrorWidgetBuilder = ErrorWidget.builder;
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (_isFlutLabKeyboardAssertion(details.exception, details.stack)) {
      _syncKeyboardStateSafely();
      return const SizedBox.shrink();
    }
    return previousErrorWidgetBuilder(details);
  };

  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isFlutLabKeyboardAssertion(details.exception, details.stack)) {
      _syncKeyboardStateSafely();
      return;
    }

    if (previousFlutterErrorHandler != null) {
      previousFlutterErrorHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_isFlutLabKeyboardAssertion(error, stack)) {
      _syncKeyboardStateSafely();
      return true;
    }

    if (previousPlatformErrorHandler != null) {
      return previousPlatformErrorHandler(error, stack);
    }

    return false;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installFlutLabKeyboardWorkaround();
  _syncKeyboardStateSafely();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const FamilyFarmApp());
}

class FamilyFarmApp extends StatelessWidget {
  const FamilyFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _syncKeyboardStateSafely(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: FarmColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FarmColors.primary,
          primary: FarmColors.primary,
          secondary: FarmColors.accent,
          surface: FarmColors.card,
          background: FarmColors.background,
          brightness: Brightness.light,
        ).copyWith(
          onPrimary: Colors.white,
          onSecondary: FarmColors.ink,
          onSurface: FarmColors.ink,
        ),
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardThemeData(
          color: FarmColors.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: FarmColors.line),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: FarmColors.card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: FarmColors.background,
          foregroundColor: FarmColors.ink,
          iconTheme: IconThemeData(color: FarmColors.ink),
          actionsIconTheme: IconThemeData(color: FarmColors.ink),
          titleTextStyle: TextStyle(
            color: FarmColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: FarmColors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          labelStyle: const TextStyle(color: FarmColors.muted),
          hintStyle: const TextStyle(color: FarmColors.muted),
          prefixIconColor: FarmColors.primary,
          suffixIconColor: FarmColors.muted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: FarmColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: FarmColors.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: FarmColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: FarmColors.error, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FarmColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: FarmColors.line,
            disabledForegroundColor: FarmColors.muted,
            elevation: 0,
            shadowColor: FarmColors.primary.withOpacity(0.22),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: FarmColors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: FarmColors.surface,
          selectedColor: FarmColors.chipBackground,
          secondarySelectedColor: FarmColors.chipBackground,
          disabledColor: FarmColors.line,
          labelStyle: const TextStyle(color: FarmColors.ink),
          secondaryLabelStyle: const TextStyle(color: FarmColors.green),
          brightness: Brightness.light,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: const BorderSide(color: FarmColors.line),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: FarmColors.surface,
          elevation: 0,
          indicatorColor: FarmColors.primarySoft,
          labelTextStyle: MaterialStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(MaterialState.selected)
                  ? FontWeight.w900
                  : FontWeight.w700,
              color: states.contains(MaterialState.selected)
                  ? FarmColors.green
                  : FarmColors.muted,
            ),
          ),
          iconTheme: MaterialStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(MaterialState.selected)
                  ? FarmColors.green
                  : FarmColors.muted,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: FarmColors.deepGreen,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class FarmColors {
  // Soft premium farm-market palette.
  // The background is only a very light mint so white cards stay dominant.
  static const background = Color(0xFFF4F9F2);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFFFFEFC);
  static const primary = Color(0xFF2F6B45);
  static const primaryDark = Color(0xFF214B31);
  static const primarySoft = Color(0xFFEAF5E7);
  static const olive = Color(0xFF72835D);
  static const accent = Color(0xFFDFA75A);
  static const accentSoft = Color(0xFFFFF3D9);
  static const text = Color(0xFF1E2A21);
  static const mutedText = Color(0xFF6B756D);
  static const border = Color(0xFFE4ECE1);
  static const chipBackground = Color(0xFFEAF5E7);
  static const success = Color(0xFF4F8A5B);
  static const successSoft = Color(0xFFEAF5E7);
  static const warning = Color(0xFFA76E1B);
  static const warningSoft = Color(0xFFFFF3D9);
  static const danger = Color(0xFFB44A3A);
  static const dangerSoft = Color(0xFFFFECE8);
  static const shadow = Color(0xFF1B2A1D);

  // Backward-compatible aliases used throughout the existing single-file app.
  static const cream = background;
  static const green = primary;
  static const deepGreen = primaryDark;
  static const lightGreen = primarySoft;
  static const gold = accent;
  static const ink = text;
  static const muted = mutedText;
  static const line = border;
  static const error = danger;
  static const surface = card;
}

const List<String> productCategoryOptions = [
  'Vegetables',
  'Fruits',
  'Ground Provisions',
  'Herbs',
  'Eggs',
  'Honey',
  'Dairy',
  'Drinks',
  'Prepared Foods',
  'Other',
];

String normalizeProductCategory(String? value) {
  final clean = (value ?? '').trim();
  if (clean.isEmpty) return productCategoryOptions.first;

  for (final option in productCategoryOptions) {
    if (option.toLowerCase() == clean.toLowerCase()) return option;
  }

  final lower = clean.toLowerCase();
  if (lower == 'others') return 'Other';

  return titleCaseWords(clean);
}

String titleCaseWords(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String shortIdLabel(String id, {int length = 6}) {
  final clean = id.trim();
  if (clean.length <= length) return clean.toUpperCase();
  return clean.substring(0, length).toUpperCase();
}

String formatJmd(double value) => 'J\$${value.toStringAsFixed(2)}';

double? parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String friendlyLabel(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return clean;
  return clean
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String formatPaymentStatus(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'Unpaid';
  return friendlyLabel(clean);
}

String formatPaymentMethod(String value) {
  switch (value.trim()) {
    case 'cash_on_pickup':
      return 'Cash on Pickup';
    case 'cash_on_delivery':
      return 'Cash on Delivery';
    case 'bank_transfer':
      return 'Bank Transfer';
    case 'stripe_card':
      return 'Card';
    default:
      return 'Payment on collection';
  }
}

String formatFulfillmentType(String value) {
  return value.trim() == 'delivery' ? 'Home Delivery' : 'Farm Pickup';
}

String formatScheduleText(String? scheduledDate, String? scheduledTime) {
  final date = scheduledDate?.trim() ?? '';
  final time = scheduledTime?.trim() ?? '';
  if (date.isEmpty && time.isEmpty) return 'Not scheduled';
  if (date.isEmpty) return time;
  if (time.isEmpty) return date;
  return '$date • $time';
}

String formatCustomerDateTime(DateTime? value) {
  if (value == null) return 'Just now';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  final month = months[local.month - 1];

  return '$month ${local.day}, ${local.year} • $hour:$minute $meridiem';
}

bool isValidHostedImageUrl(String? value) {
  final clean = value?.trim() ?? '';
  if (clean.isEmpty) return false;

  final lower = clean.toLowerCase();
  const blockedFragments = [
    'your-supabase-url',
    'image.network',
    'example.com',
    'placeholder',
    'null',
  ];

  if (blockedFragments.any(lower.contains)) return false;

  final uri = Uri.tryParse(clean);
  if (uri == null || uri.host.trim().isEmpty) return false;
  if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;

  return true;
}

String? cleanHostedImageUrl(String? value) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return null;
  return isValidHostedImageUrl(clean) ? clean : null;
}

DateTime startOfCurrentHarvestWeek([DateTime? date]) {
  final now = date ?? DateTime.now();
  final localDateOnly = DateTime(now.year, now.month, now.day);

  // Monday is 1 in Dart. This makes Monday the beginning of the harvest week.
  return localDateOnly.subtract(Duration(days: localDateOnly.weekday - 1));
}

DateTime endOfCurrentHarvestWeek([DateTime? date]) {
  return startOfCurrentHarvestWeek(date).add(const Duration(days: 7));
}

String harvestWeekRangeLabel([DateTime? date]) {
  final start = startOfCurrentHarvestWeek(date);
  final endInclusive = endOfCurrentHarvestWeek(date).subtract(
    const Duration(days: 1),
  );

  String shortDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
  }

  return '${shortDate(start)} - ${shortDate(endInclusive)}';
}

DateTime? parseProductDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

bool isDateInCurrentHarvestWeek(DateTime? date) {
  if (date == null) return false;

  final localDate = DateTime(date.year, date.month, date.day);
  final start = startOfCurrentHarvestWeek();
  final end = endOfCurrentHarvestWeek();

  return !localDate.isBefore(start) && localDate.isBefore(end);
}

bool isProductHarvestedThisWeek(Product product) {
  return isDateInCurrentHarvestWeek(product.harvestDate ?? product.createdAt);
}

String todayIsoDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String todayIsoDateFrom(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String shortProductDate(DateTime? date) {
  if (date == null) return 'No date';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String safeStorageFileName(String value) {
  final clean = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  return clean.isEmpty ? 'product' : clean;
}

Future<String?> pickAndUploadProductImage({required String productName}) async {
  // Android builds cannot import browser-only dart:html APIs.
  // Keep this function safe for Google Play builds; product image upload
  // remains unavailable outside the web editor/preview environment.
  throw Exception('Image upload is currently enabled for the web preview.');
}

Widget productImagePreviewFromUrl({
  required String? imageUrl,
  required String fallbackIcon,
  double height = 130,
}) {
  final cleanUrl = cleanHostedImageUrl(imageUrl);

  Widget fallbackPreview() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FarmColors.cardSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(fallbackIcon, style: const TextStyle(fontSize: 48)),
      ),
    );
  }

  if (cleanUrl == null) return fallbackPreview();

  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.network(
      cleanUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      cacheWidth: 700,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          color: FarmColors.cardSoft,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) => fallbackPreview(),
    ),
  );
}

int productFreshnessScore(Product product) {
  final date = product.harvestDate ?? product.createdAt;
  if (date == null) return 75;

  final now = DateTime.now();
  final productDate = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final ageDays = today.difference(productDate).inDays;

  if (ageDays <= 1) return 100;
  if (ageDays <= 3) return 94;
  if (ageDays <= 7) return 88;
  if (ageDays <= 14) return 76;
  if (ageDays <= 30) return 64;
  return 52;
}

String productFreshnessLabel(Product product) {
  final score = productFreshnessScore(product);
  if (score >= 85) return 'Fresh';
  if (score >= 70) return 'Good';
  return 'Pantry Stable';
}

String productFreshnessDescription(Product product) {
  final score = productFreshnessScore(product);
  if (score >= 85) return 'Fresh pick with strong freshness quality.';
  if (score >= 70) return 'Good quality item. Use soon for best flavor.';
  return 'Still available, but best checked before buying if it is a delicate item.';
}

Color productFreshnessColor(Product product) {
  final score = productFreshnessScore(product);
  if (score >= 85) return FarmColors.success;
  if (score >= 70) return FarmColors.warning;
  return FarmColors.mutedText;
}

Future<bool> requestBrowserNotifications() async {
  // Browser notification permission uses web-only APIs, so keep this safe
  // for Android builds.
  return false;
}

void showBrowserNotification({
  required String title,
  required String body,
}) {
  // Browser notifications use web-only APIs. No-op on Android builds.
}

Future<void> saveNotificationPreference({required bool enabled}) async {
  if (!isLoggedIn) return;

  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    await supabase.from('notification_preferences').upsert({
      'user_id': user.id,
      'email': user.email,
      'browser_notifications_enabled': enabled,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  } catch (error) {
    debugPrint('Notification preference save skipped: $error');
  }
}

class SecureCartLineQuote {
  final Product product;
  final int quantity;
  final double unitPrice;
  final int availableStock;
  final bool isAvailable;

  const SecureCartLineQuote({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.availableStock,
    required this.isAvailable,
  });

  double get lineTotal => unitPrice * quantity;
}

class SecureCartQuote {
  final List<SecureCartLineQuote> lines;

  const SecureCartQuote({required this.lines});

  double get subtotal {
    return lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
  }

  SecureCartLineQuote? lineForProduct(String productId) {
    try {
      return lines.firstWhere((line) => line.product.id == productId);
    } catch (_) {
      return null;
    }
  }
}

Future<SecureCartQuote> fetchSecureCartQuote(List<CartLine> lines) async {
  final validLines = lines
      .where((line) => line.product.id.trim().isNotEmpty && line.quantity > 0)
      .toList();

  if (validLines.isEmpty) {
    throw Exception('Your farm box is empty.');
  }

  final ids = validLines.map((line) => line.product.id).toSet().toList();

  final response = await supabase
      .from('products')
      .select(
          'id, name, price, stock_quantity, is_available, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent')
      .inFilter('id', ids);

  final rowsById = <String, Map<String, dynamic>>{};
  for (final row in response as List) {
    final data = Map<String, dynamic>.from(row as Map);
    rowsById[(data['id'] ?? '').toString()] = data;
  }

  final quoteLines = <SecureCartLineQuote>[];

  for (final line in validLines) {
    final row = rowsById[line.product.id];
    if (row == null) {
      throw Exception('${line.product.name} is no longer available.');
    }

    final serverProduct = Product.fromSupabase(row);
    final isAvailable = serverProduct.canAddToCart;
    final stock = serverProduct.stockQuantity;
    final serverPrice = serverProduct.effectivePrice;

    if (!isAvailable || stock <= 0) {
      throw Exception('${line.product.name} is not available for checkout.');
    }

    if (line.quantity > stock) {
      throw Exception(
        'Only $stock ${line.product.name} available. Please reduce quantity.',
      );
    }

    quoteLines.add(
      SecureCartLineQuote(
        product: serverProduct,
        quantity: line.quantity,
        unitPrice: serverPrice,
        availableStock: stock,
        isAvailable: isAvailable,
      ),
    );
  }

  return SecureCartQuote(lines: quoteLines);
}

class LoyaltySummary {
  final int points;
  final int lifetimePoints;
  final String tier;

  const LoyaltySummary({
    required this.points,
    required this.lifetimePoints,
    required this.tier,
  });

  String get nextTierLabel {
    if (tier == 'Platinum') return 'Top tier unlocked';
    if (lifetimePoints >= 1000) return 'Platinum unlocked';
    if (lifetimePoints >= 500)
      return '${1000 - lifetimePoints} points to Platinum';
    return '${500 - lifetimePoints} points to Gold';
  }
}

String loyaltyTierForPoints(int lifetimePoints) {
  if (lifetimePoints >= 1000) return 'Platinum';
  if (lifetimePoints >= 500) return 'Gold';
  return 'Green';
}

Future<LoyaltySummary> fetchLoyaltySummary() async {
  if (!isLoggedIn) {
    return const LoyaltySummary(points: 0, lifetimePoints: 0, tier: 'Green');
  }

  final user = supabase.auth.currentUser;
  if (user == null) {
    return const LoyaltySummary(points: 0, lifetimePoints: 0, tier: 'Green');
  }

  try {
    final response = await supabase
        .from('customer_loyalty_points')
        .select('points, lifetime_points, tier')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response != null) {
      final points = Product._toInt(response['points']);
      final lifetime = Product._toInt(response['lifetime_points']);
      final tier =
          (response['tier'] ?? loyaltyTierForPoints(lifetime)).toString();

      return LoyaltySummary(
        points: points,
        lifetimePoints: lifetime,
        tier: tier,
      );
    }
  } catch (error) {
    debugPrint('Loyalty table unavailable, using paid order estimate: $error');
  }

  try {
    final orders = await fetchOrders();
    final paidTotal = orders
        .where((order) => order.paymentStatus == 'paid')
        .fold<double>(0, (sum, order) => sum + order.total);
    final points = (paidTotal / 100).floor();
    return LoyaltySummary(
      points: points,
      lifetimePoints: points,
      tier: loyaltyTierForPoints(points),
    );
  } catch (_) {
    return const LoyaltySummary(points: 0, lifetimePoints: 0, tier: 'Green');
  }
}

Future<void> awardLoyaltyPointsForOrder({
  required String orderId,
  required double total,
}) async {
  if (!isLoggedIn) return;

  final user = supabase.auth.currentUser;
  if (user == null || orderId.isEmpty || total <= 0) return;

  final points = (total / 100).floor();
  if (points <= 0) return;

  try {
    await supabase.rpc('award_loyalty_points', params: {
      'p_user_id': user.id,
      'p_order_id': orderId,
      'p_points': points,
      'p_reason': 'order',
    });
  } catch (rpcError) {
    debugPrint(
        'Loyalty RPC unavailable, using safe client fallback: $rpcError');

    // Loyalty points should not block checkout. Stock is already reduced
    // inside the secure_checkout RPC before this runs.
    try {
      await supabase.from('loyalty_transactions').insert({
        'user_id': user.id,
        'order_id': orderId,
        'points': points,
        'reason': 'order',
      });
    } catch (error) {
      debugPrint('Loyalty award skipped: $error');
    }
  }
}

class ProductTraceRecord {
  final String id;
  final String traceCode;
  final String productName;
  final String farmLocation;
  final String harvestDate;
  final String harvestTime;
  final String farmerName;
  final String farmingMethod;
  final String batchNotes;
  final int qrScanCount;

  const ProductTraceRecord({
    required this.id,
    required this.traceCode,
    required this.productName,
    required this.farmLocation,
    required this.harvestDate,
    required this.harvestTime,
    required this.farmerName,
    required this.farmingMethod,
    required this.batchNotes,
    required this.qrScanCount,
  });

  factory ProductTraceRecord.fromSupabase(Map<String, dynamic> data) {
    return ProductTraceRecord(
      id: (data['id'] ?? '').toString(),
      traceCode: (data['trace_code'] ?? '').toString(),
      productName: (data['product_name'] ?? 'Product').toString(),
      farmLocation: (data['farm_location'] ?? '').toString(),
      harvestDate: (data['harvest_date'] ?? '').toString(),
      harvestTime: (data['harvest_time'] ?? '').toString(),
      farmerName: (data['farmer_name'] ?? '').toString(),
      farmingMethod: (data['farming_method'] ?? '100% Natural').toString(),
      batchNotes: (data['batch_notes'] ?? '').toString(),
      qrScanCount: Product._toInt(data['qr_scan_count']),
    );
  }
}

Future<ProductTraceRecord?> fetchTraceRecordByCode(String code) async {
  final cleanCode = code.trim().toUpperCase();
  if (cleanCode.isEmpty) return null;

  try {
    final response = await supabase
        .from('product_trace_records')
        .select(
            'id, trace_code, product_name, farm_location, harvest_date, harvest_time, farmer_name, farming_method, batch_notes, qr_scan_count')
        .eq('trace_code', cleanCode)
        .maybeSingle();

    if (response == null) return null;

    final record = ProductTraceRecord.fromSupabase(
      Map<String, dynamic>.from(response),
    );

    await supabase
        .from('product_trace_records')
        .update({'qr_scan_count': record.qrScanCount + 1}).eq('id', record.id);

    return record;
  } catch (error) {
    debugPrint('Trace lookup failed: $error');
    return null;
  }
}

Future<List<ProductTraceRecord>> fetchTraceRecordsForProductName(
    String productName) async {
  final cleanName = productName.trim();
  if (cleanName.isEmpty) return [];

  try {
    final response = await supabase
        .from('product_trace_records')
        .select(
            'id, trace_code, product_name, farm_location, harvest_date, harvest_time, farmer_name, farming_method, batch_notes, qr_scan_count')
        .ilike('product_name', '%$cleanName%')
        .order('harvest_date', ascending: false)
        .limit(5);

    return (response as List)
        .map((item) =>
            ProductTraceRecord.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Product trace lookup failed: $error');
    return [];
  }
}

String _traceSlug(String value) {
  final cleaned = value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  if (cleaned.isEmpty) return 'ITEM';

  final parts = cleaned
      .split('-')
      .where((part) => part.trim().isNotEmpty)
      .take(3)
      .toList();

  return parts.isEmpty ? 'ITEM' : parts.join('-');
}

String _nonEmptyTraceValue(String value, String fallback) {
  final clean = value.trim();
  return clean.isEmpty ? fallback : clean;
}

ProductTraceRecord generatedTraceRecordForProduct(Product product) {
  final productCode = _traceSlug(product.name);
  final idCode = _traceSlug(product.id);
  final uniqueCode = idCode == 'ITEM' ? productCode : idCode;

  final farmName = (product.farmName ?? '').trim();
  final farmerName = (product.farmerName ?? '').trim();
  final parish = (product.parish ?? '').trim();

  final location = [
    if (farmName.isNotEmpty) farmName,
    if (parish.isNotEmpty) parish,
  ].join(' • ');

  return ProductTraceRecord(
    id: 'generated-trace-${product.id.isEmpty ? productCode : product.id}',
    traceCode: 'NHM-$productCode-$uniqueCode',
    productName: product.name,
    farmLocation:
        location.isEmpty ? 'The Harvest Place Ja partner farm' : location,
    harvestDate: 'Available item profile',
    harvestTime: '',
    farmerName: farmerName.isEmpty ? 'The Harvest Place Ja farmer' : farmerName,
    farmingMethod: product.category.toLowerCase().contains('egg')
        ? 'Naturally raised / farm fresh'
        : 'Naturally grown / farm fresh',
    batchNotes:
        'General item tracker shown for every product. Add a row in product_trace_records for this product to show exact batch harvest details.',
    qrScanCount: 0,
  );
}

bool isGeneratedTraceRecord(ProductTraceRecord record) {
  return record.id.startsWith('generated-trace-');
}

Future<List<ProductTraceRecord>> traceRecordsForProduct(Product product) async {
  final records = await fetchTraceRecordsForProductName(product.name);
  if (records.isEmpty) {
    return [generatedTraceRecordForProduct(product)];
  }
  return records;
}

Future<List<ProductTraceRecord>> fetchAllProductTraceRecords() async {
  try {
    final response = await supabase
        .from('product_trace_records')
        .select(
            'id, trace_code, product_name, farm_location, harvest_date, harvest_time, farmer_name, farming_method, batch_notes, qr_scan_count')
        .order('harvest_date', ascending: false)
        .limit(500);

    return (response as List)
        .map((item) =>
            ProductTraceRecord.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('All product trace lookup failed: $error');
    return [];
  }
}

class ProductTraceOverviewItem {
  final Product product;
  final List<ProductTraceRecord> records;

  const ProductTraceOverviewItem({
    required this.product,
    required this.records,
  });

  ProductTraceRecord get primaryRecord {
    if (records.isEmpty) return generatedTraceRecordForProduct(product);
    return records.first;
  }

  bool get hasVerifiedBatch {
    return records.any((record) => !isGeneratedTraceRecord(record));
  }
}

Future<List<ProductTraceOverviewItem>>
    fetchTraceOverviewForAllProducts() async {
  final products = await fetchProducts();
  final traceRecords = await fetchAllProductTraceRecords();

  final visibleProducts = products.isEmpty ? fallbackProducts : products;

  return visibleProducts.map((product) {
    final productName = product.name.trim().toLowerCase();

    final matches = traceRecords
        .where((record) {
          final recordName = record.productName.trim().toLowerCase();
          if (productName.isEmpty || recordName.isEmpty) return false;
          return recordName.contains(productName) ||
              productName.contains(recordName);
        })
        .take(5)
        .toList();

    return ProductTraceOverviewItem(
      product: product,
      records:
          matches.isEmpty ? [generatedTraceRecordForProduct(product)] : matches,
    );
  }).toList();
}

String buildSalesCsv(List<AdminOrder> orders) {
  final rows = <String>[
    'Order ID,Customer,Phone,Fulfillment,Payment Method,Payment Status,Order Status,Total,Date',
  ];

  for (final order in orders) {
    rows.add([
      order.shortId,
      order.customerName.replaceAll(',', ' '),
      order.customerPhone.replaceAll(',', ' '),
      order.formattedType,
      order.formattedPaymentMethod,
      order.formattedPaymentStatus,
      _friendlyStatus(order.status),
      order.total.toStringAsFixed(2),
      order.createdAt?.toIso8601String() ?? '',
    ].join(','));
  }

  return rows.join('\n');
}

String buildSalesReportText(List<AdminOrder> orders) {
  final paidOrders =
      orders.where((order) => order.paymentStatus == 'paid').toList();
  final unpaidOrders =
      orders.where((order) => order.paymentStatus != 'paid').toList();
  final paidTotal =
      paidOrders.fold<double>(0, (sum, order) => sum + order.total);
  final allTotal = orders.fold<double>(0, (sum, order) => sum + order.total);

  return '''
The Harvest Place Ja Sales Report

Total Orders: ${orders.length}
Paid Orders: ${paidOrders.length}
Unpaid Orders: ${unpaidOrders.length}
Gross Total: J\$${allTotal.toStringAsFixed(2)}
Paid Total: J\$${paidTotal.toStringAsFixed(2)}

CSV Export:
${buildSalesCsv(orders)}
''';
}

class Product {
  final String id;
  final String name;
  final double price;
  final String icon;
  final String category;
  final String? description;
  final String? unit;
  final String? imageUrl;
  final int stockQuantity;
  final bool isAvailable;
  final bool isOrganic;
  final DateTime? harvestDate;
  final DateTime? createdAt;
  final String? farmerId;
  final String? farmerName;
  final String? farmName;
  final String? parish;
  final String approvalStatus;
  final double platformCommissionPercent;
  final double? originalPrice;
  final double? discountPrice;
  final double? discountPercent;
  final String? discountLabel;
  final DateTime? discountStartsAt;
  final DateTime? discountEndsAt;
  final bool isDiscountActive;
  final String productStatus;
  final bool readySoon;
  final DateTime? estimatedReadyDate;
  final int? expectedStockQuantity;
  final bool isDealOfDay;
  final int dealRank;
  final bool subscribeSaveEnabled;
  final double subscribeSaveDiscountPercent;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.category,
    this.description,
    this.unit,
    this.imageUrl,
    this.stockQuantity = 0,
    this.isAvailable = true,
    this.isOrganic = false,
    this.harvestDate,
    this.createdAt,
    this.farmerId,
    this.farmerName,
    this.farmName,
    this.parish,
    this.approvalStatus = 'approved',
    this.platformCommissionPercent = 10,
    this.originalPrice,
    this.discountPrice,
    this.discountPercent,
    this.discountLabel,
    this.discountStartsAt,
    this.discountEndsAt,
    this.isDiscountActive = false,
    this.productStatus = 'available',
    this.readySoon = false,
    this.estimatedReadyDate,
    this.expectedStockQuantity,
    this.isDealOfDay = false,
    this.dealRank = 999,
    this.subscribeSaveEnabled = false,
    this.subscribeSaveDiscountPercent = 5,
  });

  double get originalPriceValue {
    final base =
        originalPrice == null || originalPrice! <= 0 ? price : originalPrice!;
    return base < 0 ? 0 : base;
  }

  bool get hasActiveDiscount {
    if (!isDiscountActive) return false;
    final now = DateTime.now();
    if (discountStartsAt != null && now.isBefore(discountStartsAt!))
      return false;
    if (discountEndsAt != null && now.isAfter(discountEndsAt!)) return false;
    return effectivePrice < originalPriceValue;
  }

  double get effectivePrice {
    final original = originalPriceValue;
    double candidate = price;

    if (discountPrice != null) {
      candidate = discountPrice!;
    } else if (discountPercent != null && discountPercent! > 0) {
      final percent = discountPercent!.clamp(0, 100).toDouble();
      candidate = original * (1 - (percent / 100));
    }

    if (!isDiscountActive) return price < 0 ? 0 : price;
    if (candidate < 0) return 0;
    if (candidate > original) return original;
    return candidate;
  }

  String get formattedPrice => formatJmd(effectivePrice);
  String get formattedEffectivePrice => formatJmd(effectivePrice);
  String get formattedOriginalPrice => formatJmd(originalPriceValue);

  int get discountPercentDisplay {
    if (!hasActiveDiscount || originalPriceValue <= 0) return 0;
    final percent =
        ((originalPriceValue - effectivePrice) / originalPriceValue * 100)
            .round();
    return percent.clamp(0, 100).toInt();
  }

  bool get isReadySoon =>
      readySoon || productStatus.trim().toLowerCase() == 'ready_soon';
  bool get isHidden => productStatus.trim().toLowerCase() == 'hidden';
  bool get canAddToCart =>
      !isReadySoon && !isHidden && isAvailable && stockQuantity > 0;

  bool get isLowStock =>
      canAddToCart && stockQuantity > 0 && stockQuantity <= 5;

  String get lowStockLabel {
    if (!isLowStock) return '';
    if (stockQuantity == 1) return 'Only 1 left';
    return 'Only $stockQuantity left';
  }

  bool get hasSubscribeSave => subscribeSaveEnabled && canAddToCart;

  double get subscribeSavePercentValue {
    final value = subscribeSaveDiscountPercent <= 0
        ? 5.0
        : subscribeSaveDiscountPercent.clamp(0, 50).toDouble();
    return value;
  }

  double get subscribeSavePrice {
    final price = effectivePrice * (1 - subscribeSavePercentValue / 100);
    if (price < 0) return 0;
    return price;
  }

  String get formattedSubscribeSavePrice => formatJmd(subscribeSavePrice);

  bool get showAsDealOfDay {
    final label = (discountLabel ?? '').toLowerCase();
    return isDealOfDay ||
        label.contains('deal of the day') ||
        label.contains('today');
  }

  String get readySoonLabel {
    if (estimatedReadyDate != null) {
      return 'Available from ${shortProductDate(estimatedReadyDate)}';
    }
    if (isReadySoon) return 'Ready soon';
    return 'Notify me when available';
  }

  factory Product.fromSupabase(Map<String, dynamic> data) {
    final name = (data['name'] ?? 'Product').toString();
    final categoryName = normalizeProductCategory(
      data['category'] ??
          data['product_category'] ??
          (data['categories'] is Map ? data['categories']['name'] : null) ??
          'Vegetables',
    );

    final cleanImageUrl = cleanHostedImageUrl(data['image_url']?.toString());

    final status = (data['product_status'] ?? 'available').toString();
    final readySoonValue = data['ready_soon'] == true || status == 'ready_soon';

    return Product(
      id: (data['id'] ?? '').toString(),
      name: name,
      price: _toDouble(data['price']),
      icon: _emojiForProduct(name, categoryName),
      category: categoryName,
      description: data['description']?.toString(),
      unit: data['unit']?.toString(),
      imageUrl: cleanImageUrl,
      stockQuantity: _toInt(data['stock_quantity']),
      isAvailable:
          data['is_available'] == null ? true : data['is_available'] == true,
      isOrganic: data['is_organic'] == true || data['organic'] == true,
      harvestDate: parseProductDate(data['harvest_date']),
      createdAt: parseProductDate(data['created_at']),
      farmerId: data['farmer_id']?.toString(),
      farmerName: data['farmer_name']?.toString(),
      farmName: data['farm_name']?.toString(),
      parish: data['parish']?.toString(),
      approvalStatus: (data['approval_status'] ?? 'approved').toString(),
      platformCommissionPercent:
          _toDouble(data['platform_commission_percent'] ?? 10),
      originalPrice: parseNullableDouble(data['original_price']),
      discountPrice: parseNullableDouble(data['discount_price']),
      discountPercent: parseNullableDouble(data['discount_percent']),
      discountLabel: data['discount_label']?.toString(),
      discountStartsAt: parseProductDate(data['discount_starts_at']),
      discountEndsAt: parseProductDate(data['discount_ends_at']),
      isDiscountActive: data['is_discount_active'] == true,
      productStatus: status,
      readySoon: readySoonValue,
      estimatedReadyDate: parseProductDate(data['estimated_ready_date']),
      expectedStockQuantity: data['expected_stock_quantity'] == null
          ? null
          : _toInt(data['expected_stock_quantity']),
      isDealOfDay: data['is_deal_of_day'] == true,
      dealRank: _toInt(data['deal_rank'] ?? 999),
      subscribeSaveEnabled: data['subscribe_save_enabled'] == true,
      subscribeSaveDiscountPercent:
          parseNullableDouble(data['subscribe_save_discount_percent']) ?? 5,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static String _emojiForProduct(String name, String category) {
    final text = '$name $category'.toLowerCase();

    if (text.contains('lettuce')) return '';
    if (text.contains('callaloo')) return '';
    if (text.contains('corn')) return '';
    if (text.contains('okra')) return '';
    if (text.contains('pumpkin')) return '';
    if (text.contains('pepper')) return '';
    if (text.contains('egg')) return '';
    if (text.contains('honey')) return '';
    if (text.contains('fruit')) return '';
    if (text.contains('herb')) return '';
    return '🥬';
  }
}

bool isVisibleCustomerProduct(Product product) {
  return product.approvalStatus == 'approved' &&
      !product.isHidden &&
      product.canAddToCart;
}

List<Product> uniqueVisibleProducts(
  Iterable<Product> products, {
  int limit = 10,
  Set<String>? excludeIds,
}) {
  final excluded = excludeIds ?? <String>{};
  final seen = <String>{};
  final output = <Product>[];

  for (final product in products) {
    final id = product.id.trim();
    if (id.isEmpty) continue;
    if (excluded.contains(id)) continue;
    if (!isVisibleCustomerProduct(product)) continue;
    if (!seen.add(id)) continue;
    output.add(product);
    if (output.length >= limit) break;
  }

  return output;
}

List<Product> cleanRecentlyViewedProducts(List<Product> products) {
  return uniqueVisibleProducts(products, limit: 10);
}

bool areSameProductLists(List<Product> a, List<Product> b) {
  final cleanA = cleanRecentlyViewedProducts(a);
  final cleanB = cleanRecentlyViewedProducts(b);

  if (cleanA.isEmpty || cleanB.isEmpty) return false;
  if (cleanA.length != cleanB.length) return false;

  for (var i = 0; i < cleanA.length; i++) {
    if (cleanA[i].id != cleanB[i].id) return false;
  }

  return true;
}

class ProductTrustBadges extends StatelessWidget {
  final Product product;
  final bool compact;

  const ProductTrustBadges({
    super.key,
    required this.product,
    this.compact = false,
  });

  Widget badge({
    required IconData icon,
    required String label,
    Color color = FarmColors.green,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 10.5 : 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (product.isReadySoon)
        badge(
          icon: Icons.schedule_outlined,
          label: 'Ready Soon',
          color: FarmColors.warning,
        ),
      if (product.showAsDealOfDay)
        badge(
          icon: Icons.flash_on_outlined,
          label: 'Deal of the Day',
          color: FarmColors.warning,
        ),
      if (product.hasActiveDiscount)
        badge(
          icon: Icons.local_offer_outlined,
          label: '${product.discountPercentDisplay}% Off',
          color: FarmColors.warning,
        ),
      if (product.hasSubscribeSave)
        badge(
          icon: Icons.repeat_outlined,
          label: 'Subscribe & Save',
          color: FarmColors.success,
        ),
      badge(
        icon: Icons.speed_outlined,
        label: productFreshnessLabel(product),
        color: productFreshnessColor(product),
      ),
    ];

    if (product.isOrganic) {
      badges.add(badge(icon: Icons.eco_outlined, label: 'Organic'));
    }

    if ((product.farmName ?? '').trim().isNotEmpty ||
        (product.farmerName ?? '').trim().isNotEmpty) {
      badges.add(
          badge(icon: Icons.storefront_outlined, label: 'Farmer Verified'));
    }

    if (product.stockQuantity > 0 && product.stockQuantity <= 5) {
      badges.add(
        badge(
          icon: Icons.local_fire_department_outlined,
          label: 'Limited Stock',
          color: FarmColors.gold,
        ),
      );
    }

    if (isProductHarvestedThisWeek(product)) {
      badges.add(
          badge(icon: Icons.agriculture_outlined, label: 'Recently Harvested'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }
}

class FreshnessScoreCard extends StatelessWidget {
  final Product product;

  const FreshnessScoreCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final score = productFreshnessScore(product);
    final color = productFreshnessColor(product);

    return FarmCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 58,
                width: 58,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 7,
                  backgroundColor: FarmColors.line,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productFreshnessLabel(product),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  productFreshnessDescription(product),
                  style: TextStyle(color: FarmColors.mutedText, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final List<Product> fallbackProducts = [
  const Product(
    id: '1',
    name: 'Lettuce',
    price: 2.50,
    icon: '🥬',
    category: 'Vegetables',
    stockQuantity: 50,
    isAvailable: true,
  ),
  const Product(
    id: '2',
    name: 'Callaloo',
    price: 2.00,
    icon: '🌿',
    category: 'Vegetables',
    stockQuantity: 50,
    isAvailable: true,
  ),
  const Product(
    id: '3',
    name: 'Sweet Corn',
    price: 1.50,
    icon: '🌽',
    category: 'Vegetables',
    stockQuantity: 50,
    isAvailable: true,
  ),
  const Product(
    id: '4',
    name: 'Okra',
    price: 2.00,
    icon: '🥒',
    category: 'Vegetables',
    stockQuantity: 50,
    isAvailable: true,
  ),
  const Product(
    id: '5',
    name: 'Pumpkin',
    price: 2.50,
    icon: '🎃',
    category: 'Vegetables',
    stockQuantity: 50,
    isAvailable: true,
  ),
  const Product(
    id: '6',
    name: 'Bell Pepper',
    price: 2.50,
    icon: '🫑',
    category: 'Vegetables',
    stockQuantity: 50,
    isAvailable: true,
  ),
  const Product(
    id: '7',
    name: 'Eggs',
    price: 6.00,
    icon: '🥚',
    category: 'Eggs',
    stockQuantity: 30,
    isAvailable: true,
  ),
  const Product(
    id: '8',
    name: 'Honey',
    price: 8.00,
    icon: '🍯',
    category: 'Honey',
    stockQuantity: 20,
    isAvailable: true,
  ),
];

final supabase = Supabase.instance.client;

String friendlyAppError(Object error) {
  final text = error.toString();
  if (text.contains('over_email_send_rate_limit')) {
    return 'Too many reset emails were sent. Please wait a few minutes and try again.';
  }
  if (text.contains('Failed host lookup') || text.contains('SocketException')) {
    return 'Connection problem. Please check your internet and try again.';
  }
  if (text.contains('JWT') || text.contains('Auth')) {
    return 'Your session needs to be refreshed. Please sign in again.';
  }
  if (text.contains('permission') || text.contains('policy')) {
    return 'This action is not available for your account yet.';
  }
  return text.replaceAll('Exception: ', '').trim();
}

class FarmDataCache {
  static const Duration productTtl = Duration(minutes: 4);
  static const Duration orderTtl = Duration(minutes: 2);
  static const Duration notificationTtl = Duration(seconds: 45);

  static List<Product>? _products;
  static DateTime? _productsAt;

  static List<Product>? _readySoonProducts;
  static DateTime? _readySoonAt;

  static List<Product>? _deals;
  static DateTime? _dealsAt;

  static List<FarmOrder>? _orders;
  static DateTime? _ordersAt;

  static List<Product>? _buyAgain;
  static DateTime? _buyAgainAt;

  static List<FarmNotification>? _notifications;
  static DateTime? _notificationsAt;

  static bool _fresh(DateTime? savedAt, Duration ttl) {
    if (savedAt == null) return false;
    return DateTime.now().difference(savedAt) < ttl;
  }

  static List<Product>? get products =>
      _fresh(_productsAt, productTtl) ? List<Product>.from(_products!) : null;

  static set products(List<Product>? value) {
    _products = value == null ? null : List<Product>.from(value);
    _productsAt = value == null ? null : DateTime.now();
  }

  static List<Product>? get readySoonProducts =>
      _fresh(_readySoonAt, productTtl)
          ? List<Product>.from(_readySoonProducts!)
          : null;

  static set readySoonProducts(List<Product>? value) {
    _readySoonProducts = value == null ? null : List<Product>.from(value);
    _readySoonAt = value == null ? null : DateTime.now();
  }

  static List<Product>? get deals =>
      _fresh(_dealsAt, productTtl) ? List<Product>.from(_deals!) : null;

  static set deals(List<Product>? value) {
    _deals = value == null ? null : List<Product>.from(value);
    _dealsAt = value == null ? null : DateTime.now();
  }

  static List<FarmOrder>? get orders =>
      _fresh(_ordersAt, orderTtl) ? List<FarmOrder>.from(_orders!) : null;

  static set orders(List<FarmOrder>? value) {
    _orders = value == null ? null : List<FarmOrder>.from(value);
    _ordersAt = value == null ? null : DateTime.now();
  }

  static List<Product>? get buyAgain =>
      _fresh(_buyAgainAt, orderTtl) ? List<Product>.from(_buyAgain!) : null;

  static set buyAgain(List<Product>? value) {
    _buyAgain = value == null ? null : List<Product>.from(value);
    _buyAgainAt = value == null ? null : DateTime.now();
  }

  static List<FarmNotification>? get notifications =>
      _fresh(_notificationsAt, notificationTtl)
          ? List<FarmNotification>.from(_notifications!)
          : null;

  static set notifications(List<FarmNotification>? value) {
    _notifications = value == null ? null : List<FarmNotification>.from(value);
    _notificationsAt = value == null ? null : DateTime.now();
  }

  static void clearProducts() {
    _products = null;
    _productsAt = null;
    _readySoonProducts = null;
    _readySoonAt = null;
    _deals = null;
    _dealsAt = null;
  }

  static void clearOrders() {
    _orders = null;
    _ordersAt = null;
    _buyAgain = null;
    _buyAgainAt = null;
    _notifications = null;
    _notificationsAt = null;
  }

  static void clearAll() {
    clearProducts();
    clearOrders();
  }
}

bool get hasSupabaseSession =>
    supabase.auth.currentSession != null || supabase.auth.currentUser != null;

bool _metadataValueIsTrue(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  return value == true || text == 'true' || text == '1' || text == 'yes';
}

bool get isAnonymousSupabaseUser {
  final user = supabase.auth.currentUser;
  if (user == null) return false;

  final appMetadata = user.appMetadata;
  final userMetadata = user.userMetadata ?? const <String, dynamic>{};
  final provider =
      (appMetadata['provider'] ?? '').toString().trim().toLowerCase();
  final providersValue = appMetadata['providers'];

  final hasAnonymousProvider = providersValue is List
      ? providersValue
          .map((item) => item.toString().trim().toLowerCase())
          .contains('anonymous')
      : providersValue.toString().trim().toLowerCase().contains('anonymous');

  return provider == 'anonymous' ||
      hasAnonymousProvider ||
      _metadataValueIsTrue(appMetadata['is_anonymous']) ||
      _metadataValueIsTrue(appMetadata['isAnonymous']) ||
      _metadataValueIsTrue(userMetadata['is_anonymous']) ||
      _metadataValueIsTrue(userMetadata['isAnonymous']);
}

bool get isLoggedIn => hasSupabaseSession && !isAnonymousSupabaseUser;

void _clearSupabaseAuthStorageForGuestBrowsing() {
  // Direct browser localStorage/sessionStorage access requires dart:html.
  // Supabase signOut above clears the active session safely for Android builds.
}

Future<void> clearPrivateSessionStateForGuestBrowsing() async {
  FarmDataCache.clearAll();

  if (hasSupabaseSession) {
    try {
      await supabase.auth.signOut();
    } catch (error) {
      debugPrint('Supabase sign out skipped while entering guest mode: $error');
    }
  }

  _clearSupabaseAuthStorageForGuestBrowsing();
}

// Backward-compatible helper name for guest browsing.
// Keep this wrapper so older call sites can still clear the private session
// before showing the public market.
Future<void> clearStoredSupabaseSessionForGuest() {
  return clearPrivateSessionStateForGuestBrowsing();
}

Future<List<Product>> fetchProducts({bool forceRefresh = false}) async {
  if (!forceRefresh) {
    final cached = FarmDataCache.products;
    if (cached != null) return cached;
  }
  final products = await _fetchProductsUncached();
  FarmDataCache.products = products;
  return products;
}

Future<List<Product>> _fetchProductsUncached() async {
  final extendedSelect =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent';
  final compatibleSelect =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at';

  Future<List<Product>> runQuery(String selectFields) async {
    final response = await supabase
        .from('products')
        .select(selectFields)
        .eq('is_available', true)
        .gt('stock_quantity', 0)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Product.fromSupabase(Map<String, dynamic>.from(item)))
        .where((product) =>
            product.approvalStatus == 'approved' &&
            !product.isReadySoon &&
            !product.isHidden)
        .toList();
  }

  try {
    final products = await runQuery(extendedSelect);
    return products.isEmpty ? fallbackProducts : products;
  } catch (error) {
    debugPrint(
        'Extended product fetch unavailable, using compatible fetch: $error');
    try {
      final products = await runQuery(compatibleSelect);
      return products.isEmpty ? fallbackProducts : products;
    } catch (compatibleError) {
      debugPrint('Failed to fetch products: $compatibleError');
      return fallbackProducts;
    }
  }
}

class FarmOrder {
  final String id;
  final String status;
  final String fulfillmentType;
  final double total;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime? createdAt;

  const FarmOrder({
    required this.id,
    required this.status,
    required this.fulfillmentType,
    required this.total,
    required this.paymentStatus,
    required this.paymentMethod,
    this.createdAt,
  });

  String get shortId => shortIdLabel(id);

  String get formattedTotal => formatJmd(total);

  String get formattedPaymentStatus => formatPaymentStatus(paymentStatus);

  String get formattedPaymentMethod => formatPaymentMethod(paymentMethod);

  String get formattedType => formatFulfillmentType(fulfillmentType);

  factory FarmOrder.fromSupabase(Map<String, dynamic> data) {
    return FarmOrder(
      id: (data['id'] ?? '').toString(),
      status: (data['order_status'] ?? 'pending').toString(),
      fulfillmentType: (data['fulfillment_type'] ?? 'pickup').toString(),
      total: Product._toDouble(data['total']),
      paymentStatus: (data['payment_status'] ?? 'unpaid').toString(),
      paymentMethod: (data['payment_method'] ?? 'cash_on_pickup').toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }
}

Future<List<Product>> fetchReadySoonProducts(
    {bool forceRefresh = false}) async {
  if (!forceRefresh) {
    final cached = FarmDataCache.readySoonProducts;
    if (cached != null) return cached;
  }
  final products = await _fetchReadySoonProductsUncached();
  FarmDataCache.readySoonProducts = products;
  return products;
}

Future<List<Product>> _fetchReadySoonProductsUncached() async {
  const selectFields =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent';

  try {
    // Customer-facing Ready Soon list. Only products explicitly marked
    // ready-soon should appear here. Out-of-stock or unavailable products stay
    // out of this rail unless the admin also marks them as Ready Soon.
    final response = await supabase
        .from('products')
        .select(selectFields)
        .or('ready_soon.eq.true,product_status.eq.ready_soon')
        .order('estimated_ready_date', ascending: true);

    return (response as List)
        .map((item) => Product.fromSupabase(Map<String, dynamic>.from(item)))
        .where((product) =>
            product.approvalStatus == 'approved' &&
            !product.isHidden &&
            product.isReadySoon)
        .toList();
  } catch (error) {
    debugPrint('Ready soon product lookup unavailable: $error');
    return [];
  }
}

Future<Product?> fetchProductById(String productId) async {
  if (productId.trim().isEmpty) return null;
  const selectFields =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent';

  try {
    final response = await supabase
        .from('products')
        .select(selectFields)
        .eq('id', productId)
        .maybeSingle();
    if (response == null) return null;
    return Product.fromSupabase(Map<String, dynamic>.from(response));
  } catch (error) {
    debugPrint('Product lookup by id unavailable: $error');
    return null;
  }
}

Future<List<Product>> fetchDealOfTheDayProducts(
    {bool forceRefresh = false}) async {
  if (!forceRefresh) {
    final cached = FarmDataCache.deals;
    if (cached != null) return cached;
  }
  final products = await _fetchDealOfTheDayProductsUncached();
  FarmDataCache.deals = products;
  return products;
}

Future<List<Product>> _fetchDealOfTheDayProductsUncached() async {
  const selectFields =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent';

  try {
    final response = await supabase
        .from('products')
        .select(selectFields)
        .or('is_deal_of_day.eq.true,is_discount_active.eq.true')
        .eq('is_available', true)
        .gt('stock_quantity', 0)
        .order('deal_rank', ascending: true)
        .limit(12);

    final products = (response as List)
        .map((item) => Product.fromSupabase(Map<String, dynamic>.from(item)))
        .where((product) =>
            product.approvalStatus == 'approved' &&
            !product.isHidden &&
            product.canAddToCart &&
            (product.showAsDealOfDay || product.hasActiveDiscount))
        .toList();

    products.sort((a, b) {
      final rank = a.dealRank.compareTo(b.dealRank);
      if (rank != 0) return rank;
      return b.discountPercentDisplay.compareTo(a.discountPercentDisplay);
    });
    return products;
  } catch (error) {
    debugPrint('Deal of the day lookup unavailable: $error');
    try {
      final products = await fetchProducts();
      final deals = products
          .where(
              (product) => product.hasActiveDiscount || product.showAsDealOfDay)
          .toList();
      deals.sort((a, b) =>
          b.discountPercentDisplay.compareTo(a.discountPercentDisplay));
      return deals.take(8).toList();
    } catch (_) {
      return [];
    }
  }
}

Future<List<Product>> fetchFrequentlyBoughtTogetherProducts(
    Product product) async {
  final products = await fetchProducts();
  return buildFrequentlyBoughtTogetherProducts(
      product: product, products: products);
}

List<Product> buildFrequentlyBoughtTogetherProducts({
  required Product product,
  required List<Product> products,
}) {
  final targetCategory = product.category.trim().toLowerCase();
  final targetName = product.name.trim().toLowerCase();
  final seen = <String>{product.id};
  final output = <Product>[];

  void add(Product item) {
    if (item.id.trim().isEmpty || seen.contains(item.id)) return;
    if (!item.canAddToCart) return;
    seen.add(item.id);
    output.add(item);
  }

  final companionKeywords = <String, List<String>>{
    'vegetables': ['herb', 'pepper', 'tomato', 'onion', 'okra'],
    'fruits': ['honey', 'juice', 'drink'],
    'eggs': ['honey', 'bread', 'dairy'],
    'honey': ['fruit', 'tea', 'egg'],
    'herbs': ['vegetable', 'pepper', 'tomato'],
    'ground provisions': ['vegetable', 'herb', 'pepper'],
  };

  final keywords = companionKeywords.entries
      .where((entry) =>
          targetCategory.contains(entry.key) || targetName.contains(entry.key))
      .expand((entry) => entry.value)
      .toList();

  for (final item in products) {
    final text = '${item.name} ${item.category}'.toLowerCase();
    if (keywords.any(text.contains)) add(item);
    if (output.length >= 3) return output;
  }

  for (final item in products) {
    if (item.category.trim().toLowerCase() == targetCategory) add(item);
    if (output.length >= 3) return output;
  }

  for (final item in products) {
    add(item);
    if (output.length >= 3) return output;
  }

  return output;
}

Future<List<FarmOrder>> fetchOrders({bool forceRefresh = false}) async {
  if (!forceRefresh) {
    final cached = FarmDataCache.orders;
    if (cached != null) return cached;
  }
  final orders = await _fetchOrdersUncached();
  FarmDataCache.orders = orders;
  return orders;
}

Future<List<FarmOrder>> _fetchOrdersUncached() async {
  if (!isLoggedIn) return [];

  final user = supabase.auth.currentUser;
  if (user == null) return [];

  const fields =
      'id, order_status, fulfillment_type, total, payment_status, payment_method, created_at';

  try {
    final response = await supabase
        .from('orders')
        .select(fields)
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);

    return (response as List)
        .map((item) => FarmOrder.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (userIdError) {
    debugPrint(
        'Order lookup by user_id unavailable, using customer_id fallback: $userIdError');
  }

  try {
    final profile = await fetchCurrentCustomerProfile();
    if (profile?.id == null || profile!.id!.isEmpty) return [];

    final response = await supabase
        .from('orders')
        .select(fields)
        .eq('customer_id', profile.id!)
        .order('created_at', ascending: false)
        .limit(20);

    return (response as List)
        .map((item) => FarmOrder.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Failed to fetch only this customer orders: $error');
    return [];
  }
}

Future<List<Product>> fetchBuyAgainProducts({bool forceRefresh = false}) async {
  if (!forceRefresh) {
    final cached = FarmDataCache.buyAgain;
    if (cached != null) return cached;
  }
  final products = await _fetchBuyAgainProductsUncached();
  FarmDataCache.buyAgain = products;
  return products;
}

Future<List<Product>> _fetchBuyAgainProductsUncached() async {
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  final orders = await fetchOrders();
  final orderIds = orders
      .map((order) => order.id.trim())
      .where((id) => id.isNotEmpty)
      .toList();

  if (orderIds.isEmpty) return const [];

  List<Map<String, dynamic>> itemRows = [];

  try {
    final response = await supabase
        .from('order_items')
        .select('order_id, product_id, product_name, created_at')
        .inFilter('order_id', orderIds);

    itemRows = (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  } catch (error) {
    debugPrint('Buy Again product_id lookup unavailable: $error');
    try {
      final response = await supabase
          .from('order_items')
          .select('order_id, product_name, created_at')
          .inFilter('order_id', orderIds);

      itemRows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (fallbackError) {
      debugPrint('Buy Again order item lookup failed: $fallbackError');
      return const [];
    }
  }

  if (itemRows.isEmpty) return const [];

  final orderRank = <String, int>{};
  for (var i = 0; i < orderIds.length; i++) {
    orderRank[orderIds[i]] = i;
  }

  itemRows.sort((a, b) {
    final aOrder = (a['order_id'] ?? '').toString();
    final bOrder = (b['order_id'] ?? '').toString();
    final byOrder =
        (orderRank[aOrder] ?? 999999).compareTo(orderRank[bOrder] ?? 999999);
    if (byOrder != 0) return byOrder;
    return (b['created_at'] ?? '').toString().compareTo(
          (a['created_at'] ?? '').toString(),
        );
  });

  final orderedProductIds = <String>[];
  final orderedNames = <String>[];

  for (final row in itemRows) {
    final productId = (row['product_id'] ?? '').toString().trim();
    final productName = (row['product_name'] ?? '').toString().trim();

    if (productId.isNotEmpty && !orderedProductIds.contains(productId)) {
      orderedProductIds.add(productId);
    }

    if (productName.isNotEmpty &&
        !orderedNames.any(
            (name) => name.trim().toLowerCase() == productName.toLowerCase())) {
      orderedNames.add(productName);
    }
  }

  const selectFields =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent';

  final productsById = <String, Product>{};

  if (orderedProductIds.isNotEmpty) {
    try {
      final response = await supabase
          .from('products')
          .select(selectFields)
          .inFilter('id', orderedProductIds);

      for (final item in response as List) {
        final product = Product.fromSupabase(Map<String, dynamic>.from(item));
        if (isVisibleCustomerProduct(product)) {
          productsById[product.id] = product;
        }
      }
    } catch (error) {
      debugPrint('Buy Again product lookup by id failed: $error');
    }
  }

  final productsByName = <String, Product>{};

  if (orderedNames.isNotEmpty) {
    try {
      final response = await supabase
          .from('products')
          .select(selectFields)
          .eq('is_available', true)
          .gt('stock_quantity', 0)
          .limit(250);

      for (final item in response as List) {
        final product = Product.fromSupabase(Map<String, dynamic>.from(item));
        if (isVisibleCustomerProduct(product)) {
          productsByName[product.name.trim().toLowerCase()] = product;
        }
      }
    } catch (error) {
      debugPrint('Buy Again product lookup by name failed: $error');
    }
  }

  final result = <Product>[];
  final seen = <String>{};

  for (final row in itemRows) {
    final productId = (row['product_id'] ?? '').toString().trim();
    final productName = (row['product_name'] ?? '').toString().trim();
    final product =
        productsById[productId] ?? productsByName[productName.toLowerCase()];

    if (product == null) continue;
    if (!isVisibleCustomerProduct(product)) continue;
    if (!seen.add(product.id)) continue;

    result.add(product);
    if (result.length >= 10) break;
  }

  return result;
}

class FarmNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final String? orderId;

  const FarmNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.createdAt,
    this.orderId,
  });

  String get timeLabel => formatCustomerDateTime(createdAt);

  bool get hasOrderLink =>
      (orderId ?? '').trim().isNotEmpty ||
      notificationOrderShortId(this) != null;

  IconData get icon {
    switch (type) {
      case 'payment':
        return Icons.verified_outlined;
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  factory FarmNotification.fromSupabase(Map<String, dynamic> data) {
    return FarmNotification(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? 'Notification').toString(),
      message: (data['message'] ?? '').toString(),
      type: (data['type'] ?? 'order').toString(),
      isRead: data['is_read'] == true,
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
      orderId: data['order_id']?.toString(),
    );
  }
}

String? notificationOrderShortId(FarmNotification notification) {
  final text = '${notification.title} ${notification.message}';
  final match = RegExp(r'#([A-Za-z0-9]+)').firstMatch(text);
  return match?.group(1)?.trim().toUpperCase();
}

Future<String?> findOrderIdForNotification(
    FarmNotification notification) async {
  final directId = notification.orderId?.trim();
  if (directId != null && directId.isNotEmpty) return directId;

  final shortId = notificationOrderShortId(notification);
  if (shortId == null || shortId.isEmpty) return null;

  final orders = await fetchOrders();
  for (final order in orders) {
    final fullId = order.id.trim().toUpperCase();
    final displayId = order.shortId.trim().toUpperCase();

    if (displayId == shortId ||
        fullId == shortId ||
        fullId.startsWith(shortId)) {
      return order.id;
    }
  }

  return null;
}

Future<void> createFarmNotification({
  required String title,
  required String message,
  String type = 'order',
  String? userEmail,
  String? userId,
  String? orderId,
}) async {
  final targetUserId = (userId ?? supabase.auth.currentUser?.id)?.trim();
  final targetEmail =
      (userEmail ?? supabase.auth.currentUser?.email)?.trim().toLowerCase();
  final cleanOrderId = orderId?.trim();

  // Never create anonymous/global private notifications from the client.
  // Use an admin Edge Function for broadcast notifications.
  if ((targetUserId == null || targetUserId.isEmpty) &&
      (targetEmail == null || targetEmail.isEmpty)) {
    debugPrint('Notification skipped because no target user was supplied.');
    return;
  }

  final notificationPayload = <String, dynamic>{
    'user_id': targetUserId,
    'user_email': targetEmail,
    'title': title,
    'message': message,
    'type': type,
    'is_read': false,
    if (cleanOrderId != null && cleanOrderId.isNotEmpty)
      'order_id': cleanOrderId,
  };

  try {
    await supabase.from('notifications').insert(notificationPayload);
  } catch (error) {
    try {
      if (targetEmail == null || targetEmail.isEmpty) return;
      final legacyPayload = Map<String, dynamic>.from(notificationPayload)
        ..remove('user_id')
        ..remove('order_id');
      await supabase.from('notifications').insert(legacyPayload);
    } catch (legacyError) {
      debugPrint('Notification save skipped: $error / $legacyError');
    }
  }
}

class NotificationTarget {
  final String? userId;
  final String? userEmail;

  const NotificationTarget({this.userId, this.userEmail});

  bool get hasTarget {
    return (userId != null && userId!.trim().isNotEmpty) ||
        (userEmail != null && userEmail!.trim().isNotEmpty);
  }
}

Future<NotificationTarget> fetchOrderNotificationTarget(String orderId) async {
  final cleanOrderId = orderId.trim();
  if (cleanOrderId.isEmpty) return const NotificationTarget();

  String? clean(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  NotificationTarget parseTarget(Map<String, dynamic> data) {
    final directUserId = clean(data['user_id']);
    final directEmail = clean(data['user_email'] ?? data['customer_email']);
    final customerData = data['customers'];
    final customer = customerData is Map<String, dynamic>
        ? customerData
        : customerData is Map
            ? Map<String, dynamic>.from(customerData)
            : <String, dynamic>{};

    return NotificationTarget(
      userId: directUserId ?? clean(customer['user_id']),
      userEmail: directEmail ?? clean(customer['email']),
    );
  }

  try {
    final response = await supabase
        .from('orders')
        .select('user_id, customer_email, customers(user_id, email)')
        .eq('id', cleanOrderId)
        .maybeSingle();

    if (response != null) {
      final target = parseTarget(Map<String, dynamic>.from(response));
      if (target.hasTarget) return target;
    }
  } catch (error) {
    debugPrint('Order notification target joined lookup failed: $error');
  }

  try {
    final order = await supabase
        .from('orders')
        .select('user_id, customer_id')
        .eq('id', cleanOrderId)
        .maybeSingle();

    if (order == null) return const NotificationTarget();
    final orderData = Map<String, dynamic>.from(order);
    final directUserId = clean(orderData['user_id']);
    final customerId = clean(orderData['customer_id']);

    if (customerId == null) {
      return NotificationTarget(userId: directUserId);
    }

    try {
      final customer = await supabase
          .from('customers')
          .select('user_id, email')
          .eq('id', customerId)
          .maybeSingle();

      if (customer != null) {
        final customerData = Map<String, dynamic>.from(customer);
        return NotificationTarget(
          userId: directUserId ?? clean(customerData['user_id']),
          userEmail: clean(customerData['email']),
        );
      }
    } catch (customerError) {
      debugPrint('Customer notification target lookup failed: $customerError');
    }

    return NotificationTarget(userId: directUserId);
  } catch (error) {
    debugPrint('Order notification target lookup failed: $error');
    return const NotificationTarget();
  }
}

Future<void> createOrderCustomerNotification({
  required String orderId,
  required String title,
  required String message,
  String type = 'order',
}) async {
  final target = await fetchOrderNotificationTarget(orderId);
  if (!target.hasTarget) {
    debugPrint('Order notification skipped: no customer target for $orderId.');
    return;
  }

  await createFarmNotification(
    title: title,
    message: message,
    type: type,
    userId: target.userId,
    userEmail: target.userEmail,
    orderId: orderId,
  );
}

Future<void> createOrderConfirmationSupport({
  required String orderId,
  required String customerName,
  required String customerPhone,
  required String? customerEmail,
  required double total,
}) async {
  final payload = {
    'order_id': orderId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_email': customerEmail,
    'total': total,
    'email_status':
        customerEmail == null || customerEmail.isEmpty ? 'no_email' : 'pending',
    'sms_status': customerPhone.isEmpty ? 'no_phone' : 'pending',
    'message':
        'Thank you for your order from The Harvest Place Ja. Your order has been received.',
  };

  try {
    await supabase.from('order_confirmations').insert({
      ...payload,
      'user_id': supabase.auth.currentUser?.id,
    });
  } catch (userIdError) {
    try {
      await supabase.from('order_confirmations').insert(payload);
    } catch (legacyError) {
      debugPrint(
          'Order confirmation support skipped: $userIdError / $legacyError');
    }
  }
}

Future<List<FarmNotification>> fetchFarmNotifications(
    {bool forceRefresh = false}) async {
  if (!forceRefresh) {
    final cached = FarmDataCache.notifications;
    if (cached != null) return cached;
  }
  final notifications = await _fetchFarmNotificationsUncached();
  FarmDataCache.notifications = notifications;
  return notifications;
}

Future<List<FarmNotification>> _fetchFarmNotificationsUncached() async {
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  List<FarmNotification> cleanRows(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final output = <FarmNotification>[];

    for (final row in rows) {
      final notice = FarmNotification.fromSupabase(row);
      final key = [
        notice.title.trim().toLowerCase(),
        notice.message.trim().toLowerCase(),
        notice.type.trim().toLowerCase(),
        notice.orderId?.trim().toLowerCase() ?? '',
      ].join('|');

      if (seen.add(key)) output.add(notice);
    }

    return output;
  }

  try {
    final response = await supabase
        .from('notifications')
        .select(
            'id, user_id, user_email, title, message, type, is_read, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);

    final rows = (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final notices = cleanRows(rows);
    if (notices.isNotEmpty) return notices;
  } catch (userIdError) {
    debugPrint('Notification lookup by user_id unavailable: $userIdError');
  }

  try {
    final userEmail = user.email?.trim().toLowerCase();
    if (userEmail == null || userEmail.isEmpty) return const [];

    final response = await supabase
        .from('notifications')
        .select('id, user_email, title, message, type, is_read, created_at')
        .eq('user_email', userEmail)
        .order('created_at', ascending: false)
        .limit(50);

    final rows = (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return cleanRows(rows);
  } catch (emailError) {
    debugPrint('Notification lookup by email unavailable: $emailError');
  }

  // Do not create repeated order/admin-style notifications from dashboard data.
  // Only show records that actually exist in the notifications table.
  return const [];
}

Future<int> fetchUnreadNotificationCount() async {
  final notifications = await fetchFarmNotifications();
  return notifications.where((notice) => !notice.isRead).length;
}

Future<void> markNotificationsRead() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    await supabase
        .from('notifications')
        .update({'is_read': true}).eq('user_id', user.id);
  } catch (userIdError) {
    try {
      final userEmail = user.email?.trim().toLowerCase();
      if (userEmail == null || userEmail.isEmpty) return;
      await supabase
          .from('notifications')
          .update({'is_read': true}).eq('user_email', userEmail);
    } catch (emailError) {
      debugPrint('Mark notifications read skipped: $userIdError / $emailError');
    }
  }
}

Future<bool> subscribeToProductReadyAlert(Product product) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception(
        'Please sign in so we can notify you when this item is ready.');
  }

  final email = user.email?.trim().toLowerCase();
  try {
    final existing = await supabase
        .from('product_ready_subscriptions')
        .select('id')
        .eq('product_id', product.id)
        .eq('user_id', user.id)
        .eq('is_notified', false)
        .maybeSingle();

    if (existing != null) return false;

    await supabase.from('product_ready_subscriptions').insert({
      'user_id': user.id,
      'user_email': email,
      'product_id': product.id,
      'product_name': product.name,
      'is_notified': false,
    });
    return true;
  } catch (error) {
    debugPrint('Product ready subscription skipped: $error');
    throw Exception(
        'Ready alerts are not set up yet. Please run the Supabase SQL migration first.');
  }
}

Future<bool> isSubscribedToProductReadyAlert(Product product) async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;
  try {
    final existing = await supabase
        .from('product_ready_subscriptions')
        .select('id')
        .eq('product_id', product.id)
        .eq('user_id', user.id)
        .eq('is_notified', false)
        .maybeSingle();
    return existing != null;
  } catch (_) {
    return false;
  }
}

Future<void> notifySubscribedCustomersProductReady(Product product) async {
  if (product.id.trim().isEmpty || !product.canAddToCart) return;

  try {
    final response = await supabase
        .from('product_ready_subscriptions')
        .select('id, user_id, user_email')
        .eq('product_id', product.id)
        .eq('is_notified', false);

    final currentUser = supabase.auth.currentUser;
    final currentUserId = currentUser?.id.trim();
    final currentUserEmail = currentUser?.email?.trim().toLowerCase();
    var shouldShowLocalBrowserNotification = false;

    for (final item in response as List) {
      final row = Map<String, dynamic>.from(item as Map);
      final subId = (row['id'] ?? '').toString();
      final userId = row['user_id']?.toString();
      final email = row['user_email']?.toString();
      final hasSubscriptionTarget =
          (userId != null && userId.trim().isNotEmpty) ||
              (email != null && email.trim().isNotEmpty);

      if (!hasSubscriptionTarget) {
        debugPrint(
            'Skipped product-ready notification with no customer target for ${product.id}.');
        continue;
      }

      await createFarmNotification(
        title: '${product.name} is ready',
        message:
            'Good news! ${product.name} is now available at The Harvest Place Ja.',
        type: 'product_ready',
        userId: userId,
        userEmail: email,
      );

      final normalizedEmail = email?.trim().toLowerCase();
      if ((currentUserId != null &&
              currentUserId.isNotEmpty &&
              currentUserId == userId?.trim()) ||
          (currentUserEmail != null &&
              currentUserEmail.isNotEmpty &&
              currentUserEmail == normalizedEmail)) {
        shouldShowLocalBrowserNotification = true;
      }

      if (subId.isNotEmpty) {
        await supabase.from('product_ready_subscriptions').update({
          'is_notified': true,
          'notified_at': DateTime.now().toIso8601String(),
        }).eq('id', subId);
      }
    }

    if (shouldShowLocalBrowserNotification) {
      showBrowserNotification(
        title: '${product.name} is ready',
        body: 'Good news! ${product.name} is now available.',
      );
    }
  } catch (error) {
    debugPrint('Product ready notifications skipped: $error');
  }
}

Future<void> maybeNotifyProductReady(String productId) async {
  final product = await fetchProductById(productId);
  if (product == null || !product.canAddToCart) return;
  await notifySubscribedCustomersProductReady(product);
}

Future<bool> subscribeToSaveProduct(
  Product product, {
  int intervalDays = 7,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Please sign in to start Subscribe & Save.');
  }

  if (!product.hasSubscribeSave) {
    throw Exception('Subscribe & Save is not available for this item yet.');
  }

  final safeInterval = intervalDays <= 0 ? 7 : intervalDays;
  final nextOrderDate = DateTime.now().add(Duration(days: safeInterval));
  final email = user.email?.trim().toLowerCase();

  try {
    final existing = await supabase
        .from('customer_product_subscriptions')
        .select('id')
        .eq('product_id', product.id)
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

    if (existing != null) return false;

    await supabase.from('customer_product_subscriptions').insert({
      'user_id': user.id,
      'user_email': email,
      'product_id': product.id,
      'product_name': product.name,
      'interval_days': safeInterval,
      'discount_percent': product.subscribeSavePercentValue,
      'next_order_date': todayIsoDateFrom(nextOrderDate),
      'status': 'active',
    });
    return true;
  } catch (error) {
    debugPrint('Subscribe & Save setup skipped: $error');
    throw Exception(
        'Subscribe & Save is not set up yet. Please run the Supabase SQL migration first.');
  }
}

class OrderDetailsItem {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const OrderDetailsItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory OrderDetailsItem.fromSupabase(Map<String, dynamic> data) {
    return OrderDetailsItem(
      productName: (data['product_name'] ?? 'Product').toString(),
      quantity: Product._toInt(data['quantity']),
      unitPrice: Product._toDouble(data['unit_price']),
      lineTotal: Product._toDouble(data['line_total']),
    );
  }
}

class OrderDetails {
  final String id;
  final String status;
  final String fulfillmentType;
  final String paymentStatus;
  final String paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String? deliveryAddress;
  final String? deliveryZone;
  final String? scheduledDate;
  final String? scheduledTime;
  final String? notes;
  final DateTime? createdAt;
  final List<OrderDetailsItem> items;

  const OrderDetails({
    required this.id,
    required this.status,
    required this.fulfillmentType,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.deliveryAddress,
    this.deliveryZone,
    this.scheduledDate,
    this.scheduledTime,
    this.notes,
    this.createdAt,
    required this.items,
  });

  String get shortId => shortIdLabel(id);
  String get formattedTotal => formatJmd(total);
  String get formattedSubtotal => formatJmd(subtotal);
  String get formattedDeliveryFee => formatJmd(deliveryFee);

  String get formattedPaymentStatus => formatPaymentStatus(paymentStatus);

  String get formattedOrderStatus => friendlyLabel(status);

  String get formattedPaymentMethod => formatPaymentMethod(paymentMethod);

  String get formattedType => formatFulfillmentType(fulfillmentType);

  String get scheduleText => formatScheduleText(scheduledDate, scheduledTime);

  factory OrderDetails.fromSupabase(Map<String, dynamic> data) {
    final rawItems = data['order_items'];
    final parsedItems = rawItems is List
        ? rawItems
            .map((item) => OrderDetailsItem.fromSupabase(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList()
        : <OrderDetailsItem>[];

    return OrderDetails(
      id: (data['id'] ?? '').toString(),
      status: (data['order_status'] ?? 'pending').toString(),
      fulfillmentType: (data['fulfillment_type'] ?? 'pickup').toString(),
      paymentStatus: (data['payment_status'] ?? 'unpaid').toString(),
      paymentMethod: (data['payment_method'] ?? 'cash_on_pickup').toString(),
      subtotal: Product._toDouble(data['subtotal']),
      deliveryFee: Product._toDouble(data['delivery_fee']),
      total: Product._toDouble(data['total']),
      deliveryAddress: data['delivery_address']?.toString(),
      deliveryZone: data['delivery_zone']?.toString(),
      scheduledDate: data['scheduled_date']?.toString(),
      scheduledTime: data['scheduled_time']?.toString(),
      notes: data['notes']?.toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
      items: parsedItems,
    );
  }
}

String _friendlyStatus(String value) => friendlyLabel(value);

Future<OrderDetails?> fetchOrderDetails(String orderId) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  const fields =
      'id, order_status, fulfillment_type, subtotal, delivery_fee, total, payment_status, payment_method, delivery_address, delivery_zone, scheduled_date, scheduled_time, notes, created_at, order_items(product_name, quantity, unit_price, line_total)';

  try {
    final isAdmin = await isCurrentUserAdminFromDatabase();
    if (isAdmin) {
      final response = await supabase
          .from('orders')
          .select(fields)
          .eq('id', orderId)
          .maybeSingle();
      return response == null
          ? null
          : OrderDetails.fromSupabase(Map<String, dynamic>.from(response));
    }

    try {
      final response = await supabase
          .from('orders')
          .select(fields)
          .eq('id', orderId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (response != null) {
        return OrderDetails.fromSupabase(Map<String, dynamic>.from(response));
      }
    } catch (userIdError) {
      debugPrint('Order detail lookup by user_id unavailable: $userIdError');
    }

    final profile = await fetchCurrentCustomerProfile();
    if (profile?.id == null || profile!.id!.isEmpty) return null;

    final response = await supabase
        .from('orders')
        .select(fields)
        .eq('id', orderId)
        .eq('customer_id', profile.id!)
        .maybeSingle();

    return response == null
        ? null
        : OrderDetails.fromSupabase(Map<String, dynamic>.from(response));
  } catch (error) {
    debugPrint('Failed to fetch private order details: $error');
    return null;
  }
}

class AuditLogEntry {
  final String id;
  final String actorUserId;
  final String action;
  final String tableName;
  final String recordId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const AuditLogEntry({
    required this.id,
    required this.actorUserId,
    required this.action,
    required this.tableName,
    required this.recordId,
    required this.metadata,
    required this.createdAt,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> data) {
    return AuditLogEntry(
      id: (data['id'] ?? '').toString(),
      actorUserId: (data['actor_user_id'] ?? '').toString(),
      action: (data['action'] ?? '').toString(),
      tableName: (data['table_name'] ?? '').toString(),
      recordId: (data['record_id'] ?? '').toString(),
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : <String, dynamic>{},
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }

  String get formattedAction => friendlyLabel(action);
  String get shortRecordId =>
      recordId.trim().isEmpty ? 'N/A' : shortIdLabel(recordId);

  String get shortActorId => actorUserId.trim().isEmpty
      ? 'Unknown'
      : shortIdLabel(actorUserId, length: 8);
}

Future<List<AuditLogEntry>> fetchAdminAuditLogs({
  int limit = 50,
  String? action,
  String? tableName,
}) async {
  await requireAdminAccess();

  final response = await supabase.rpc(
    'admin_fetch_audit_logs',
    params: {
      'p_limit': limit,
      'p_action': action,
      'p_table_name': tableName,
    },
  );

  return (response as List)
      .map((item) => AuditLogEntry.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

class AdminOrder {
  final String id;
  final String status;
  final String fulfillmentType;
  final double total;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime? createdAt;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? bankReference;
  final String? deliveryStatus;
  final String? deliveryAddress;
  final String? deliveryZone;
  final String? scheduledDate;
  final String? scheduledTime;
  final List<AdminOrderItem> items;

  const AdminOrder({
    required this.id,
    required this.status,
    required this.fulfillmentType,
    required this.total,
    required this.paymentStatus,
    required this.paymentMethod,
    this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.bankReference,
    this.deliveryStatus,
    this.deliveryAddress,
    this.deliveryZone,
    this.scheduledDate,
    this.scheduledTime,
    required this.items,
  });

  String get shortId => shortIdLabel(id);

  String get formattedTotal => formatJmd(total);

  String get formattedPaymentStatus => formatPaymentStatus(paymentStatus);

  String get formattedPaymentMethod => formatPaymentMethod(paymentMethod);

  String get formattedType => formatFulfillmentType(fulfillmentType);

  String get formattedDeliveryStatus {
    return friendlyLabel(deliveryStatus ?? 'pending');
  }

  String get scheduleText => formatScheduleText(scheduledDate, scheduledTime);

  factory AdminOrder.fromSupabase(Map<String, dynamic> data) {
    final customerData = data['customers'];
    final customer = customerData is Map<String, dynamic>
        ? customerData
        : customerData is Map
            ? Map<String, dynamic>.from(customerData)
            : <String, dynamic>{};

    final rawItems = data['order_items'];
    final parsedItems = rawItems is List
        ? rawItems
            .map((item) => AdminOrderItem.fromSupabase(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList()
        : <AdminOrderItem>[];

    return AdminOrder(
      id: (data['id'] ?? '').toString(),
      status: (data['order_status'] ?? 'pending').toString(),
      fulfillmentType: (data['fulfillment_type'] ?? 'pickup').toString(),
      total: Product._toDouble(data['total']),
      paymentStatus: (data['payment_status'] ?? 'unpaid').toString(),
      paymentMethod: (data['payment_method'] ?? 'cash_on_pickup').toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
      customerName: (customer['full_name'] ?? 'Customer').toString(),
      customerPhone: (customer['phone'] ?? '').toString(),
      customerAddress: (customer['address'] ?? '').toString(),
      bankReference: data['bank_reference']?.toString(),
      deliveryStatus: data['delivery_status']?.toString(),
      deliveryAddress: data['delivery_address']?.toString(),
      deliveryZone: data['delivery_zone']?.toString(),
      scheduledDate: data['scheduled_date']?.toString(),
      scheduledTime: data['scheduled_time']?.toString(),
      items: parsedItems,
    );
  }
}

class AdminOrderItem {
  final String productName;
  final int quantity;
  final double lineTotal;

  const AdminOrderItem({
    required this.productName,
    required this.quantity,
    required this.lineTotal,
  });

  factory AdminOrderItem.fromSupabase(Map<String, dynamic> data) {
    return AdminOrderItem(
      productName: (data['product_name'] ?? 'Product').toString(),
      quantity: Product._toInt(data['quantity']),
      lineTotal: Product._toDouble(data['line_total']),
    );
  }
}

Future<List<AdminOrder>> fetchAdminOrders() async {
  final allowed = await isCurrentUserAdminFromDatabase();
  if (!allowed) return [];

  try {
    final response = await supabase
        .from('orders')
        .select(
          'id, order_status, fulfillment_type, total, payment_status, payment_method, bank_reference, delivery_status, delivery_address, delivery_zone, scheduled_date, scheduled_time, created_at, customers(full_name, phone, address), order_items(product_name, quantity, line_total)',
        )
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((item) => AdminOrder.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Failed to fetch admin orders: $error');
    return [];
  }
}

Future<void> updateOrderStatus(String orderId, String status) async {
  await requireAdminAccess();
  await supabase
      .from('orders')
      .update({'order_status': status}).eq('id', orderId);

  await createOrderCustomerNotification(
    orderId: orderId,
    title: 'Order status updated',
    message:
        'Order #${orderId.length <= 6 ? orderId : orderId.substring(0, 6).toUpperCase()} is now ${_friendlyStatus(status)}.',
    type: 'order',
  );
}

Future<void> updatePaymentStatus(String orderId, String status) async {
  await requireAdminAccess();
  await supabase
      .from('orders')
      .update({'payment_status': status}).eq('id', orderId);
}

Future<void> quickUpdateOrderStatus(String orderId, String status) async {
  await updateOrderStatus(orderId, status);
}

Future<void> markOrderPaid(String orderId) async {
  await requireAdminAccess();
  final adminEmail = supabase.auth.currentUser?.email ?? 'admin';

  await supabase.from('orders').update({
    'payment_status': 'paid',
    'payment_verified_at': DateTime.now().toIso8601String(),
    'payment_verified_by': adminEmail,
  }).eq('id', orderId);

  await createOrderCustomerNotification(
    orderId: orderId,
    title: 'Payment verified',
    message:
        'Payment for order #${orderId.length <= 6 ? orderId : orderId.substring(0, 6).toUpperCase()} was marked paid.',
    type: 'payment',
  );
}

Future<void> updateDeliveryStatus(String orderId, String deliveryStatus) async {
  await requireAdminAccess();
  final orderStatus = deliveryStatus == 'delivered'
      ? 'delivered'
      : deliveryStatus == 'out_for_delivery'
          ? 'out_for_delivery'
          : deliveryStatus == 'ready_for_pickup'
              ? 'ready'
              : 'preparing';

  await supabase.from('orders').update({
    'delivery_status': deliveryStatus,
    'order_status': orderStatus,
  }).eq('id', orderId);

  await createOrderCustomerNotification(
    orderId: orderId,
    title: 'Delivery update',
    message:
        'Order #${orderId.length <= 6 ? orderId : orderId.substring(0, 6).toUpperCase()} is ${_friendlyStatus(deliveryStatus)}.',
    type: 'delivery',
  );
}

Future<List<Product>> fetchAllProducts() async {
  final extendedSelect =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent';
  final compatibleSelect =
      'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at';
  Future<List<Product>> runQuery(String selectFields) async {
    final response = await supabase
        .from('products')
        .select(selectFields)
        .order('created_at', ascending: false);
    return (response as List)
        .map((item) => Product.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  }

  try {
    return await runQuery(extendedSelect);
  } catch (error) {
    debugPrint(
        'Extended all-products fetch unavailable, using compatible fetch: $error');
    try {
      return await runQuery(compatibleSelect);
    } catch (compatibleError) {
      debugPrint('Failed to fetch all products: $compatibleError');
      return fallbackProducts;
    }
  }
}

Future<Map<String, dynamic>?> adminUpdateProduct({
  required String productId,
  String? name,
  String? description,
  double? price,
  String? unit,
  String? imageUrl,
  bool? isAvailable,
  int? stockQuantity,
  String? approvalStatus,
  String? adminNote,
  String? category,
  bool? isOrganic,
  DateTime? harvestDate,
  double? originalPrice,
  double? discountPrice,
  double? discountPercent,
  String? discountLabel,
  DateTime? discountStartsAt,
  DateTime? discountEndsAt,
  bool? isDiscountActive,
  String? productStatus,
  bool? readySoon,
  DateTime? estimatedReadyDate,
  int? expectedStockQuantity,
  bool? isDealOfDay,
  int? dealRank,
  bool? subscribeSaveEnabled,
  double? subscribeSaveDiscountPercent,
}) async {
  await requireAdminAccess();
  if (productId.trim().isEmpty) {
    throw Exception('Missing product ID.');
  }

  try {
    final response = await supabase.rpc(
      'admin_update_product',
      params: {
        'p_product_id': productId,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_unit': unit,
        'p_image_url': imageUrl,
        'p_is_available': isAvailable,
        'p_stock_quantity': stockQuantity,
        'p_approval_status': approvalStatus,
        'p_admin_note': adminNote,
        'p_category': category,
        'p_is_organic': isOrganic,
        'p_harvest_date': harvestDate?.toIso8601String().split('T').first,
        'p_original_price': originalPrice,
        'p_discount_price': discountPrice,
        'p_discount_percent': discountPercent,
        'p_discount_label': discountLabel,
        'p_discount_starts_at': discountStartsAt?.toIso8601String(),
        'p_discount_ends_at': discountEndsAt?.toIso8601String(),
        'p_is_discount_active': isDiscountActive,
        'p_product_status': productStatus,
        'p_ready_soon': readySoon,
        'p_estimated_ready_date':
            estimatedReadyDate?.toIso8601String().split('T').first,
        'p_expected_stock_quantity': expectedStockQuantity,
        'p_is_deal_of_day': isDealOfDay,
        'p_deal_rank': dealRank,
        'p_subscribe_save_enabled': subscribeSaveEnabled,
        'p_subscribe_save_discount_percent': subscribeSaveDiscountPercent,
      },
    );

    FarmDataCache.clearProducts();

    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    return null;
  } catch (error) {
    final cleanMessage = friendlyAppError(error);
    debugPrint('Admin product RPC failed: $cleanMessage');
    throw Exception(cleanMessage);
  }
}

Future<void> updateProductAvailability(
    String productId, bool isAvailable) async {
  await adminUpdateProduct(
    productId: productId,
    isAvailable: isAvailable,
    adminNote: isAvailable
        ? 'Admin made product visible from app'
        : 'Admin hid product from app',
  );
  await maybeNotifyProductReady(productId);
}

Future<void> createProduct({
  required String name,
  required double price,
  required int stockQuantity,
  required bool isAvailable,
  required String category,
  required bool isOrganic,
  String? description,
  String? unit,
  String? imageUrl,
  bool isDiscountActive = false,
  double? originalPrice,
  double? discountPrice,
  double? discountPercent,
  String? discountLabel,
  String? discountStartsAt,
  String? discountEndsAt,
  String productStatus = 'available',
  bool readySoon = false,
  String? estimatedReadyDate,
  int? expectedStockQuantity,
  bool isDealOfDay = false,
  int? dealRank,
  bool subscribeSaveEnabled = false,
  double? subscribeSaveDiscountPercent,
}) async {
  await requireAdminAccess();
  final payload = {
    'name': name,
    'price': price,
    'stock_quantity': stockQuantity,
    'is_available': isAvailable,
    'category': normalizeProductCategory(category),
    'is_organic': isOrganic,
    'harvest_date': todayIsoDate(),
    'description': description,
    'unit': unit,
    'image_url': imageUrl,
    'original_price': originalPrice,
    'discount_price': discountPrice,
    'discount_percent': discountPercent,
    'discount_label': discountLabel,
    'discount_starts_at': discountStartsAt,
    'discount_ends_at': discountEndsAt,
    'is_discount_active': isDiscountActive,
    'product_status': readySoon ? 'ready_soon' : productStatus,
    'ready_soon': readySoon,
    'estimated_ready_date': estimatedReadyDate,
    'expected_stock_quantity': expectedStockQuantity,
    'is_deal_of_day': isDealOfDay,
    'deal_rank': dealRank,
    'subscribe_save_enabled': subscribeSaveEnabled,
    'subscribe_save_discount_percent': subscribeSaveDiscountPercent,
  };

  try {
    final inserted = await supabase
        .from('products')
        .insert(payload)
        .select('id')
        .maybeSingle();
    final productId = inserted == null ? '' : (inserted['id'] ?? '').toString();
    if (productId.isNotEmpty) await maybeNotifyProductReady(productId);
  } catch (error) {
    final errorText = error.toString().toLowerCase();
    final missingNewColumns = errorText.contains('schema cache') ||
        errorText.contains('pgrst204') ||
        errorText.contains('column');
    if (!missingNewColumns) rethrow;
    debugPrint(
        'Discount/ready-soon columns unavailable, using compatible insert: $error');
    await supabase.from('products').insert({
      'name': name,
      'price': price,
      'stock_quantity': stockQuantity,
      'is_available': isAvailable,
      'category': normalizeProductCategory(category),
      'is_organic': isOrganic,
      'harvest_date': todayIsoDate(),
      'description': description,
      'unit': unit,
      'image_url': imageUrl,
    });
  }
}

Future<void> updateProductDetails({
  required String productId,
  required String name,
  required double price,
  required int stockQuantity,
  required bool isAvailable,
  required String category,
  required bool isOrganic,
  String? description,
  String? unit,
  String? imageUrl,
  bool isDiscountActive = false,
  double? originalPrice,
  double? discountPrice,
  double? discountPercent,
  String? discountLabel,
  String? discountStartsAt,
  String? discountEndsAt,
  String productStatus = 'available',
  bool readySoon = false,
  String? estimatedReadyDate,
  int? expectedStockQuantity,
  bool isDealOfDay = false,
  int? dealRank,
  bool subscribeSaveEnabled = false,
  double? subscribeSaveDiscountPercent,
}) async {
  await adminUpdateProduct(
    productId: productId,
    name: name,
    description: description,
    price: price,
    unit: unit,
    imageUrl: imageUrl,
    isAvailable: isAvailable,
    stockQuantity: stockQuantity,
    approvalStatus: 'approved',
    adminNote: 'Admin edited product details from app',
    category: normalizeProductCategory(category),
    isOrganic: isOrganic,
    harvestDate: DateTime.now(),
    originalPrice: originalPrice,
    discountPrice: discountPrice,
    discountPercent: discountPercent,
    discountLabel: discountLabel,
    discountStartsAt: parseProductDate(discountStartsAt),
    discountEndsAt: parseProductDate(discountEndsAt),
    isDiscountActive: isDiscountActive,
    productStatus: readySoon ? 'ready_soon' : productStatus,
    readySoon: readySoon,
    estimatedReadyDate: parseProductDate(estimatedReadyDate),
    expectedStockQuantity: expectedStockQuantity,
    isDealOfDay: isDealOfDay,
    dealRank: dealRank,
    subscribeSaveEnabled: subscribeSaveEnabled,
    subscribeSaveDiscountPercent: subscribeSaveDiscountPercent,
  );

  await maybeNotifyProductReady(productId);
}

Future<Map<String, int>> fetchProductStockByIds(List<String> productIds) async {
  final ids = productIds.where((id) => id.isNotEmpty).toSet().toList();
  if (ids.isEmpty) return {};

  final response = await supabase
      .from('products')
      .select('id, stock_quantity, is_available')
      .inFilter('id', ids);

  final stock = <String, int>{};
  for (final item in response as List) {
    final data = Map<String, dynamic>.from(item as Map);
    final isAvailable =
        data['is_available'] == null ? true : data['is_available'] == true;
    stock[(data['id'] ?? '').toString()] =
        isAvailable ? Product._toInt(data['stock_quantity']) : 0;
  }
  return stock;
}

Future<String?> validateStockBeforeCheckout(List<CartLine> lines) async {
  final stockById = await fetchProductStockByIds(
    lines.map((line) => line.product.id).toList(),
  );

  for (final line in lines) {
    final productId = line.product.id;
    if (productId.isEmpty) continue;
    final availableStock = stockById[productId] ?? 0;
    if (availableStock <= 0) {
      return '${line.product.name} is out of stock.';
    }
    if (line.quantity > availableStock) {
      return 'Only $availableStock ${line.product.name} available. Please reduce quantity.';
    }
  }
  return null;
}

Future<void> reduceStockForOrder(String orderId) async {
  final cleanOrderId = orderId.trim();
  if (cleanOrderId.isEmpty) {
    throw Exception('Missing order ID for stock confirmation.');
  }

  try {
    await supabase.rpc(
      'reduce_stock_for_order',
      params: {'p_order_id': cleanOrderId},
    );
  } catch (error) {
    final cleanMessage = error.toString().replaceFirst('Exception: ', '');
    debugPrint('Server-side stock reduction failed: $cleanMessage');
    throw Exception(cleanMessage);
  }
}

Future<void> restockProduct(String productId, int amount) async {
  await requireAdminAccess();
  if (productId.isEmpty || amount <= 0) return;

  final current = await supabase
      .from('products')
      .select('stock_quantity')
      .eq('id', productId)
      .maybeSingle();

  final currentStock =
      current == null ? 0 : Product._toInt(current['stock_quantity']);

  await adminUpdateProduct(
    productId: productId,
    stockQuantity: currentStock + amount,
    isAvailable: true,
    approvalStatus: 'approved',
    adminNote: 'Admin restocked product from app by $amount',
  );
  await maybeNotifyProductReady(productId);
}

Future<void> reuseProductThisWeek({
  required String productId,
  required int stockQuantity,
}) async {
  await requireAdminAccess();
  if (productId.isEmpty) return;

  final safeStock = stockQuantity < 0 ? 0 : stockQuantity;

  await adminUpdateProduct(
    productId: productId,
    stockQuantity: safeStock,
    isAvailable: safeStock > 0,
    approvalStatus: 'approved',
    harvestDate: DateTime.now(),
    adminNote: 'Admin marked product recently harvested from app',
  );

  await maybeNotifyProductReady(productId);
}

bool get isSignedIn => isLoggedIn;

String? get currentUserId => isLoggedIn ? supabase.auth.currentUser?.id : null;

String? get currentUserEmail =>
    isLoggedIn ? supabase.auth.currentUser?.email?.trim().toLowerCase() : null;

String get currentUserRole {
  if (!isLoggedIn) return 'customer';

  final user = supabase.auth.currentUser;
  final data = user?.userMetadata ?? const {};
  final role = data['role']?.toString().toLowerCase();

  // Security note: admin access is never granted from user metadata or
  // hardcoded emails. Admin privileges are checked against the database by
  // isCurrentUserAdminFromDatabase(), and must also be enforced with Supabase RLS.
  if (role == 'farmer') return 'farmer';
  return 'customer';
}

bool get isAdminUser => false;
bool get isFarmerUser => currentUserRole == 'farmer';

Future<bool> isCurrentUserAdminFromDatabase() async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;

  try {
    // Preferred secure schema: admin_users.id is the auth.users.id value.
    final response = await supabase
        .from('admin_users')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    return response != null;
  } catch (firstError) {
    try {
      // Compatible secure schema: admin_users.user_id references auth.users(id).
      final response = await supabase
          .from('admin_users')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      return response != null;
    } catch (secondError) {
      debugPrint('Admin check failed: $firstError / $secondError');
      return false;
    }
  }
}

Future<bool> isCurrentUserFarmerFromDatabase() async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;

  try {
    final response = await supabase
        .from('farmer_profiles')
        .select('id, verification_status')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return false;
    final status = (response['verification_status'] ?? '').toString();
    return status == 'approved' || status == 'pending';
  } catch (error) {
    debugPrint('Farmer role check failed: $error');
    return currentUserRole == 'farmer';
  }
}

Future<void> requireAdminAccess() async {
  final allowed = await isCurrentUserAdminFromDatabase();
  if (!allowed) {
    throw Exception('Admin permission required.');
  }
}

Future<String?> currentCustomerIdForSignedInUser() async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final response = await supabase
        .from('customers')
        .select('id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response == null ? null : (response['id'] ?? '').toString();
  } catch (error) {
    debugPrint('Secure customer id lookup failed: $error');
    return null;
  }
}

Future<String?> secureSaveCurrentCustomerAndGetId({
  required String fullName,
  required String phone,
  required String address,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final payload = {
    'full_name': fullName,
    'phone': phone,
    'address': address.isEmpty ? null : address,
    'email': user.email,
    'user_id': user.id,
  };

  try {
    final response = await supabase
        .from('customers')
        .upsert(payload, onConflict: 'user_id')
        .select('id')
        .single();
    return (response['id'] ?? '').toString();
  } catch (upsertError) {
    debugPrint(
        'Customer upsert by user_id failed, using safe fallback: $upsertError');
    final existingId = await currentCustomerIdForSignedInUser();
    if (existingId != null && existingId.isNotEmpty) {
      await supabase.from('customers').update(payload).eq('id', existingId);
      return existingId;
    }

    final response =
        await supabase.from('customers').insert(payload).select('id').single();
    return (response['id'] ?? '').toString();
  }
}

class CustomerProfile {
  final String? id;
  final String fullName;
  final String phone;
  final String address;

  const CustomerProfile({
    this.id,
    required this.fullName,
    required this.phone,
    required this.address,
  });

  factory CustomerProfile.fromSupabase(Map<String, dynamic> data) {
    return CustomerProfile(
      id: data['id']?.toString(),
      fullName: (data['full_name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
    );
  }
}

Future<CustomerProfile?> fetchCurrentCustomerProfile() async {
  if (!isLoggedIn) return null;

  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final response = await supabase
        .from('customers')
        .select('id, full_name, phone, address, user_id, email')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return CustomerProfile.fromSupabase(Map<String, dynamic>.from(response));
  } catch (error) {
    debugPrint('Failed to fetch current user customer profile: $error');
    return null;
  }
}

Future<void> saveCurrentCustomerProfile({
  required String fullName,
  required String phone,
  required String address,
}) async {
  await secureSaveCurrentCustomerAndGetId(
    fullName: fullName,
    phone: phone,
    address: address,
  );
}

/*
Suggested Supabase marketplace tables:

farmer_profiles:
- id uuid primary key
- user_id uuid
- email text
- farm_name text
- farmer_name text
- phone text
- parish text
- address text
- bio text
- verification_status text default 'pending'
- payout_method text
- payout_details text
- created_at timestamp

farmer_payouts:
- id uuid primary key
- farmer_id uuid
- order_id uuid
- gross_amount numeric
- commission_amount numeric
- net_amount numeric
- payout_status text default 'pending'
- payout_method text
- payout_reference text
- released_at timestamp
- created_at timestamp

products additional columns:
- farmer_id uuid
- farmer_name text
- farm_name text
- parish text
- approval_status text default 'approved'
- platform_commission_percent numeric default 10

order_items additional columns:
- farmer_id uuid
- farmer_name text
- farm_name text
- commission_amount numeric
- farmer_earning_amount numeric
*/

class FarmerProfile {
  final String id;
  final String userId;
  final String email;
  final String farmName;
  final String farmerName;
  final String phone;
  final String parish;
  final String address;
  final String bio;
  final String verificationStatus;
  final String payoutMethod;
  final String payoutDetails;
  final DateTime? createdAt;

  const FarmerProfile({
    required this.id,
    required this.userId,
    required this.email,
    required this.farmName,
    required this.farmerName,
    required this.phone,
    required this.parish,
    required this.address,
    required this.bio,
    required this.verificationStatus,
    required this.payoutMethod,
    required this.payoutDetails,
    this.createdAt,
  });

  bool get isApproved => verificationStatus == 'approved';
  String get statusLabel => _friendlyStatus(verificationStatus);

  factory FarmerProfile.fromSupabase(Map<String, dynamic> data) {
    return FarmerProfile(
      id: (data['id'] ?? '').toString(),
      userId: (data['user_id'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      farmName: (data['farm_name'] ?? 'Farm').toString(),
      farmerName: (data['farmer_name'] ?? 'Farmer').toString(),
      phone: (data['phone'] ?? '').toString(),
      parish: (data['parish'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      verificationStatus: (data['verification_status'] ?? 'pending').toString(),
      payoutMethod: (data['payout_method'] ?? '').toString(),
      payoutDetails: (data['payout_details'] ?? '').toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }
}

class FarmerPayout {
  final String id;
  final String farmerId;
  final String orderId;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final String payoutStatus;
  final String payoutMethod;
  final String payoutReference;
  final DateTime? releasedAt;
  final DateTime? createdAt;

  const FarmerPayout({
    required this.id,
    required this.farmerId,
    required this.orderId,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.payoutStatus,
    required this.payoutMethod,
    required this.payoutReference,
    this.releasedAt,
    this.createdAt,
  });

  factory FarmerPayout.fromSupabase(Map<String, dynamic> data) {
    return FarmerPayout(
      id: (data['id'] ?? '').toString(),
      farmerId: (data['farmer_id'] ?? '').toString(),
      orderId: (data['order_id'] ?? '').toString(),
      grossAmount: Product._toDouble(data['gross_amount']),
      commissionAmount: Product._toDouble(data['commission_amount']),
      netAmount: Product._toDouble(data['net_amount']),
      payoutStatus: (data['payout_status'] ?? 'pending').toString(),
      payoutMethod: (data['payout_method'] ?? '').toString(),
      payoutReference: (data['payout_reference'] ?? '').toString(),
      releasedAt: DateTime.tryParse((data['released_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }
}

class FarmerOrderSummary {
  final String orderId;
  final String productName;
  final int quantity;
  final double lineTotal;
  final double farmerEarningAmount;

  const FarmerOrderSummary({
    required this.orderId,
    required this.productName,
    required this.quantity,
    required this.lineTotal,
    required this.farmerEarningAmount,
  });

  String get shortOrderId =>
      orderId.length <= 6 ? orderId : orderId.substring(0, 6).toUpperCase();

  factory FarmerOrderSummary.fromSupabase(Map<String, dynamic> data) {
    return FarmerOrderSummary(
      orderId: (data['order_id'] ?? '').toString(),
      productName: (data['product_name'] ?? 'Product').toString(),
      quantity: Product._toInt(data['quantity']),
      lineTotal: Product._toDouble(data['line_total']),
      farmerEarningAmount: Product._toDouble(data['farmer_earning_amount']),
    );
  }
}

Future<List<FarmerOrderSummary>> fetchFarmerOrderSummaries(
    String farmerId) async {
  if (farmerId.isEmpty) return [];
  try {
    final response = await supabase
        .from('order_items')
        .select(
            'order_id, product_name, quantity, line_total, farmer_earning_amount, farmer_id')
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List)
        .map((item) =>
            FarmerOrderSummary.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Farmer order summaries unavailable: $error');
    return [];
  }
}

Future<FarmerProfile?> fetchCurrentFarmerProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  try {
    final response = await supabase
        .from('farmer_profiles')
        .select(
            'id, user_id, email, farm_name, farmer_name, phone, parish, address, bio, verification_status, payout_method, payout_details, created_at')
        .eq('user_id', user.id)
        .maybeSingle();
    if (response == null) return null;
    return FarmerProfile.fromSupabase(Map<String, dynamic>.from(response));
  } catch (error) {
    debugPrint('Farmer profile unavailable: $error');
    return null;
  }
}

Future<List<FarmerProfile>> fetchFarmerProfiles() async {
  final allowed = await isCurrentUserAdminFromDatabase();
  if (!allowed) return [];
  try {
    final response = await supabase
        .from('farmer_profiles')
        .select(
            'id, user_id, email, farm_name, farmer_name, phone, parish, address, bio, verification_status, payout_method, payout_details, created_at')
        .order('created_at', ascending: false);
    return (response as List)
        .map((item) =>
            FarmerProfile.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Farmer profiles unavailable: $error');
    return [];
  }
}

Future<void> saveFarmerProfile({
  required String farmName,
  required String farmerName,
  required String phone,
  required String parish,
  required String address,
  required String bio,
  required String payoutMethod,
  required String payoutDetails,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;
  final payload = {
    'user_id': user.id,
    'email': user.email,
    'farm_name': farmName,
    'farmer_name': farmerName,
    'phone': phone,
    'parish': parish,
    'address': address,
    'bio': bio,
    'verification_status': 'pending',
    'payout_method': payoutMethod,
    'payout_details': payoutDetails,
  };
  final existing = await fetchCurrentFarmerProfile();
  if (existing == null || existing.id.isEmpty) {
    await supabase.from('farmer_profiles').insert(payload);
  } else {
    await supabase
        .from('farmer_profiles')
        .update(payload)
        .eq('id', existing.id);
  }
}

Future<void> updateFarmerVerification(String farmerId, String status) async {
  await requireAdminAccess();
  await supabase
      .from('farmer_profiles')
      .update({'verification_status': status}).eq('id', farmerId);
}

Future<List<Product>> fetchFarmerProducts(String farmerId) async {
  if (farmerId.isEmpty) return [];
  try {
    final response = await supabase
        .from('products')
        .select(
            'id, name, description, price, unit, image_url, is_available, stock_quantity, created_at, category, is_organic, harvest_date, farmer_id, farmer_name, farm_name, parish, approval_status, platform_commission_percent, original_price, discount_price, discount_percent, discount_label, discount_starts_at, discount_ends_at, is_discount_active, product_status, ready_soon, estimated_ready_date, expected_stock_quantity, is_deal_of_day, deal_rank, subscribe_save_enabled, subscribe_save_discount_percent')
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((item) => Product.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Farmer products unavailable: $error');
    return [];
  }
}

Future<void> createFarmerProduct({
  required FarmerProfile farmer,
  required String name,
  required double price,
  required int stockQuantity,
  required String category,
  required bool isOrganic,
  String? description,
  String? unit,
  String? imageUrl,
  bool isDiscountActive = false,
  double? originalPrice,
  double? discountPrice,
  double? discountPercent,
  String? discountLabel,
  String? discountStartsAt,
  String? discountEndsAt,
  bool readySoon = false,
  String? estimatedReadyDate,
  int? expectedStockQuantity,
  bool isDealOfDay = false,
  int? dealRank,
  bool subscribeSaveEnabled = false,
  double? subscribeSaveDiscountPercent,
}) async {
  final cleanName = name.trim();
  if (cleanName.isEmpty) {
    throw Exception('Please enter a product name.');
  }
  if (price <= 0) {
    throw Exception('Please enter a valid product price.');
  }
  if (stockQuantity < 0) {
    throw Exception('Stock quantity cannot be negative.');
  }

  final marketplacePayload = {
    'name': cleanName,
    'price': price,
    'stock_quantity': stockQuantity,
    'is_available': false,
    'category': normalizeProductCategory(category),
    'is_organic': isOrganic,
    'harvest_date': todayIsoDate(),
    'description':
        description?.trim().isEmpty == true ? null : description?.trim(),
    'unit': unit?.trim().isEmpty == true ? null : unit?.trim(),
    'image_url': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
    'farmer_id': farmer.id,
    'farmer_name': farmer.farmerName,
    'farm_name': farmer.farmName,
    'parish': farmer.parish,
    'approval_status': 'pending',
    'platform_commission_percent': 10,
    'original_price': originalPrice,
    'discount_price': discountPrice,
    'discount_percent': discountPercent,
    'discount_label': discountLabel,
    'discount_starts_at': discountStartsAt,
    'discount_ends_at': discountEndsAt,
    'is_discount_active': isDiscountActive,
    'product_status': readySoon ? 'ready_soon' : 'available',
    'ready_soon': readySoon,
    'estimated_ready_date': estimatedReadyDate,
    'expected_stock_quantity': expectedStockQuantity,
    'is_deal_of_day': isDealOfDay,
    'deal_rank': dealRank,
    'subscribe_save_enabled': subscribeSaveEnabled,
    'subscribe_save_discount_percent': subscribeSaveDiscountPercent,
  };

  try {
    await supabase.from('products').insert(marketplacePayload);
  } catch (error) {
    final errorText = error.toString().toLowerCase();

    final looksLikeMissingMarketplaceColumn = errorText.contains('column') ||
        errorText.contains('schema cache') ||
        errorText.contains('pgrst204');

    if (!looksLikeMissingMarketplaceColumn) {
      debugPrint('Farmer product insert failed: $error');
      throw Exception(
          'Could not submit product. Please make sure your farmer profile is approved and linked to this account.');
    }

    debugPrint(
      'Marketplace columns unavailable, using compatible product insert: $error',
    );

    try {
      await createProduct(
        name: cleanName,
        price: price,
        stockQuantity: stockQuantity,
        isAvailable: false,
        category: normalizeProductCategory(category),
        isOrganic: isOrganic,
        description:
            description?.trim().isEmpty == true ? null : description?.trim(),
        unit: unit?.trim().isEmpty == true ? null : unit?.trim(),
        imageUrl: imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
      );
    } catch (fallbackError) {
      debugPrint('Compatible farmer product insert failed: $fallbackError');
      throw Exception(
          'Could not submit product. Please make sure your account has permission to add products.');
    }
  }
}

Future<void> updateProductApproval(String productId, String status) async {
  await adminUpdateProduct(
    productId: productId,
    approvalStatus: status,
    isAvailable: status == 'approved',
    adminNote: 'Admin changed product approval to $status from app',
  );
}

Future<List<FarmerPayout>> fetchFarmerPayouts({String? farmerId}) async {
  try {
    dynamic query = supabase
        .from('farmer_payouts')
        .select(
            'id, farmer_id, order_id, gross_amount, commission_amount, net_amount, payout_status, payout_method, payout_reference, released_at, created_at')
        .order('created_at', ascending: false);
    if (farmerId != null && farmerId.isNotEmpty)
      query = query.eq('farmer_id', farmerId);
    final response = await query;
    return (response as List)
        .map((item) =>
            FarmerPayout.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Farmer payouts unavailable: $error');
    return [];
  }
}

Future<void> updateFarmerPayoutStatus({
  required String payoutId,
  required String status,
  String? reference,
}) async {
  await requireAdminAccess();
  final update = {
    'payout_status': status,
    if (reference != null && reference.trim().isNotEmpty)
      'payout_reference': reference.trim(),
    if (status == 'released') 'released_at': DateTime.now().toIso8601String(),
  };
  await supabase.from('farmer_payouts').update(update).eq('id', payoutId);
}

Map<String, double> marketplaceAmounts(Product product, int quantity) {
  final gross = product.effectivePrice * quantity;
  final rate = product.platformCommissionPercent <= 0
      ? 10
      : product.platformCommissionPercent;
  final commission = gross * (rate / 100);
  return {
    'gross': gross,
    'commission': commission,
    'farmer': gross - commission,
  };
}

class Coupon {
  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final bool isActive;
  final double? minimumOrder;

  const Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.isActive,
    this.minimumOrder,
  });

  factory Coupon.fromSupabase(Map<String, dynamic> data) {
    return Coupon(
      id: (data['id'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      discountType: (data['discount_type'] ?? 'fixed').toString(),
      discountValue: Product._toDouble(data['discount_value']),
      isActive: data['is_active'] == null ? true : data['is_active'] == true,
      minimumOrder: data['minimum_order'] == null
          ? null
          : Product._toDouble(data['minimum_order']),
    );
  }

  double discountFor(double subtotal) {
    if (!isActive) return 0;
    final minimum = minimumOrder ?? 0;
    if (minimum > 0 && subtotal < minimum) return 0;
    if (discountType == 'percent') {
      return subtotal * (discountValue / 100);
    }
    return discountValue > subtotal ? subtotal : discountValue;
  }

  String get label {
    if (discountType == 'percent') {
      return '${discountValue.toStringAsFixed(0)}% off';
    }
    return 'J\$${discountValue.toStringAsFixed(2)} off';
  }
}

class CouponValidationResult {
  final bool valid;
  final String message;
  final String? couponId;
  final String? code;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double originalTotal;
  final double finalTotal;

  const CouponValidationResult({
    required this.valid,
    required this.message,
    this.couponId,
    this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.originalTotal,
    required this.finalTotal,
  });

  factory CouponValidationResult.fromMap(Map<String, dynamic> data) {
    return CouponValidationResult(
      valid: data['valid'] == true,
      message: (data['message'] ?? '').toString(),
      couponId: data['coupon_id']?.toString(),
      code: data['code']?.toString(),
      discountType: (data['discount_type'] ?? 'fixed').toString(),
      discountValue: Product._toDouble(data['discount_value']),
      discountAmount: Product._toDouble(data['discount_amount']),
      originalTotal: Product._toDouble(data['original_total']),
      finalTotal: Product._toDouble(data['final_total']),
    );
  }

  String get label {
    if (discountType == 'percent') {
      return '${discountValue.toStringAsFixed(0)}% off';
    }
    return 'J\$${discountAmount.toStringAsFixed(2)} off';
  }
}

Future<CouponValidationResult> validateCouponForCheckout({
  required String code,
  required double orderTotal,
}) async {
  final response = await supabase.rpc(
    'validate_coupon_for_checkout',
    params: {
      'p_code': code.trim().toUpperCase(),
      'p_order_total': orderTotal,
    },
  );

  return CouponValidationResult.fromMap(
    Map<String, dynamic>.from(response as Map),
  );
}

Future<Coupon?> fetchActiveCoupon(String code) async {
  final cleanCode = code.trim().toUpperCase();
  if (cleanCode.isEmpty) return null;

  try {
    final response = await supabase
        .from('coupons')
        .select(
            'id, code, discount_type, discount_value, minimum_order, is_active')
        .eq('code', cleanCode)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return Coupon.fromSupabase(Map<String, dynamic>.from(response));
  } catch (error) {
    debugPrint('Coupon lookup failed: $error');
    return null;
  }
}

Future<List<Coupon>> fetchCoupons() async {
  final allowed = await isCurrentUserAdminFromDatabase();
  if (!allowed) return [];

  try {
    final response = await supabase
        .from('coupons')
        .select(
            'id, code, discount_type, discount_value, minimum_order, is_active')
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Coupon.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Failed to fetch coupons: $error');
    return [];
  }
}

Future<void> createCoupon({
  required String code,
  required String discountType,
  required double discountValue,
  required double? minimumOrder,
  required bool isActive,
}) async {
  await requireAdminAccess();
  await supabase.rpc(
    'admin_upsert_coupon',
    params: {
      'p_coupon_id': null,
      'p_code': code.trim().toUpperCase(),
      'p_discount_type': discountType,
      'p_discount_value': discountValue,
      'p_minimum_order': minimumOrder ?? 0,
      'p_is_active': isActive,
      'p_starts_at': null,
      'p_ends_at': null,
      'p_usage_limit': null,
      'p_description': 'Created from admin dashboard',
      'p_admin_note': 'Coupon created from Flutter admin dashboard',
    },
  );
}

Future<void> updateCouponAvailability(String couponId, bool isActive) async {
  await requireAdminAccess();
  await supabase.rpc(
    'admin_upsert_coupon',
    params: {
      'p_coupon_id': couponId,
      'p_code': null,
      'p_discount_type': null,
      'p_discount_value': null,
      'p_minimum_order': null,
      'p_is_active': isActive,
      'p_starts_at': null,
      'p_ends_at': null,
      'p_usage_limit': null,
      'p_description': null,
      'p_admin_note': isActive
          ? 'Coupon reactivated from Flutter admin dashboard'
          : 'Coupon disabled from Flutter admin dashboard',
    },
  );
}

class SupportTicket {
  final String id;
  final String email;
  final String subject;
  final String message;
  final String status;
  final String? adminReply;
  final DateTime? createdAt;

  const SupportTicket({
    required this.id,
    required this.email,
    required this.subject,
    required this.message,
    required this.status,
    this.adminReply,
    this.createdAt,
  });

  factory SupportTicket.fromSupabase(Map<String, dynamic> data) {
    return SupportTicket(
      id: (data['id'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      subject: (data['subject'] ?? 'Support request').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? 'open').toString(),
      adminReply: data['admin_reply']?.toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }

  String get formattedStatus => _friendlyStatus(status);
  String get shortId => id.length <= 6 ? id : id.substring(0, 6).toUpperCase();
}

Future<void> createSupportTicket({
  required String subject,
  required String message,
}) async {
  final user = supabase.auth.currentUser;
  await supabase.from('support_tickets').insert({
    'user_id': user?.id,
    'email': user?.email ?? '',
    'subject': subject,
    'message': message,
    'status': 'open',
  });
}

Future<List<SupportTicket>> fetchMySupportTickets() async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  try {
    final response = await supabase
        .from('support_tickets')
        .select('id, email, subject, message, status, admin_reply, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(30);

    return (response as List)
        .map((item) =>
            SupportTicket.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Failed to fetch this user support tickets: $error');
    return [];
  }
}

Future<List<SupportTicket>> fetchAdminSupportTickets() async {
  final allowed = await isCurrentUserAdminFromDatabase();
  if (!allowed) return [];

  try {
    final response = await supabase
        .from('support_tickets')
        .select('id, email, subject, message, status, admin_reply, created_at')
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((item) =>
            SupportTicket.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Failed to fetch admin support tickets: $error');
    return [];
  }
}

Future<void> updateSupportTicket({
  required String ticketId,
  required String status,
  String? adminReply,
}) async {
  await requireAdminAccess();
  await supabase.from('support_tickets').update({
    'status': status,
    'admin_reply': adminReply,
  }).eq('id', ticketId);
}

class ProductReview {
  final String id;
  final String productId;
  final String productName;
  final String email;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.email,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory ProductReview.fromSupabase(Map<String, dynamic> data) {
    final productData = data['products'];
    final product = productData is Map<String, dynamic>
        ? productData
        : productData is Map
            ? Map<String, dynamic>.from(productData)
            : <String, dynamic>{};

    return ProductReview(
      id: (data['id'] ?? '').toString(),
      productId: (data['product_id'] ?? '').toString(),
      productName:
          (product['name'] ?? data['product_name'] ?? 'Product').toString(),
      email: (data['email'] ?? '').toString(),
      rating: Product._toInt(data['rating']).clamp(1, 5),
      comment: (data['comment'] ?? '').toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }
}

Future<void> createProductReview({
  required String productId,
  required String productName,
  required int rating,
  required String comment,
}) async {
  final user = supabase.auth.currentUser;
  await supabase.from('product_reviews').insert({
    'product_id': productId.isEmpty ? null : productId,
    'product_name': productName,
    'user_id': user?.id,
    'email': user?.email ?? '',
    'rating': rating,
    'comment': comment,
  });
}

Future<List<ProductReview>> fetchProductReviews() async {
  try {
    final response = await supabase
        .from('product_reviews')
        .select(
            'id, product_id, product_name, email, rating, comment, created_at, products(name)')
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((item) =>
            ProductReview.fromSupabase(Map<String, dynamic>.from(item)))
        .toList();
  } catch (error) {
    debugPrint('Failed to fetch product reviews: $error');
    return [];
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // If the app opens from a Supabase reset link, show the password screen
  // immediately. Flutter web still loads the same app page, so the app must
  // route this URL internally instead of waiting for a separate web page.
  bool hasEnteredMarket = AppConfig.hasPasswordRecoveryCallback;
  bool isPasswordRecovery = AppConfig.hasPasswordRecoveryCallback;
  String? passwordRecoveryError;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          isPasswordRecovery = true;
          hasEnteredMarket = true;
          passwordRecoveryError = null;
        });
        return;
      }

      setState(() {});
    });

    if (AppConfig.hasPasswordRecoveryCallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          isPasswordRecovery = true;
          hasEnteredMarket = true;
          passwordRecoveryError = null;
        });
      });
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void enterMarket() {
    if (!mounted) return;
    unawaited(_enterMarketAsGuest());
  }

  Future<void> _enterMarketAsGuest() async {
    await clearPrivateSessionStateForGuestBrowsing();
    if (!mounted) return;
    setState(() => hasEnteredMarket = true);
  }

  Future<void> openAuth({bool createAccount = false}) async {
    final didSignIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          returnToPrevious: true,
          startInRegister: createAccount,
        ),
      ),
    );

    if (!mounted) return;
    if (didSignIn == true || isLoggedIn) {
      setState(() => hasEnteredMarket = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is the important fix: the password reset URL is not a separate
    // physical web page. When the URL contains resetPassword=true, code=..., or
    // recovery tokens, show UpdatePasswordScreen before the splash/landing page.
    if (AppConfig.hasPasswordRecoveryCallback || isPasswordRecovery) {
      return UpdatePasswordScreen(
        onPasswordUpdated: () {
          AppConfig.cleanPasswordRecoveryUrl();
          if (!mounted) return;
          setState(() {
            isPasswordRecovery = false;
            hasEnteredMarket = true;
          });
        },
      );
    }

    if (passwordRecoveryError != null && !hasEnteredMarket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || passwordRecoveryError == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset link error: $passwordRecoveryError')),
        );
        passwordRecoveryError = null;
      });
    }

    // The welcome page is only the first splash screen. Once the user enters
    // the market, stay in the market even if auth later becomes null.
    if (!hasEnteredMarket) {
      return PublicLandingScreen(
        onEnterMarket: enterMarket,
        onAuth: () {
          openAuth();
        },
      );
    }

    return const MainNavigation();
  }
}

class PublicLandingScreen extends StatelessWidget {
  final VoidCallback onEnterMarket;
  final VoidCallback onAuth;

  const PublicLandingScreen({
    super.key,
    required this.onEnterMarket,
    required this.onAuth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 18),
            Center(
              child: Image.asset(
                'lib/assets/images/logo.png',
                height: 106,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  '🌿',
                  style: TextStyle(fontSize: 76),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'The Harvest Place Ja',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Fresh natural food, local harvests, and easy ordering.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: FarmColors.mutedText),
            ),
            const SizedBox(height: 10),
            Text(
              'Browse freely. Sign in only when you’re ready to checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: FarmColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Explore the Vegan Ingredient Book'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VeganIngredientBookScreen(
                      onShopTap: onEnterMarket,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'What you can do',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  TraceRow(
                    icon: Icons.storefront_outlined,
                    title: 'Shop fresh food',
                    value: 'Browse available harvests and natural products.',
                  ),
                  TraceRow(
                    icon: Icons.local_shipping_outlined,
                    title: 'Pickup or delivery',
                    value: 'Choose a convenient schedule and delivery option.',
                  ),
                  TraceRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Track your order',
                    value: 'Follow order, payment, and delivery status.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            PrimaryFarmButton(
              label: 'Enter Market',
              onPressed: onEnterMarket,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text('Login or Create Account'),
              onPressed: onAuth,
            ),
            const SizedBox(height: 8),
            Text(
              'No account needed to browse.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FarmColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.lock_reset_outlined),
              label: const Text('Forgot password?'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                  child: const Text('Terms'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                  child: const Text('Privacy'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RefundPolicyScreen(),
                      ),
                    );
                  },
                  child: const Text('Refund Policy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController emailController;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetLink() async {
    final email = emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: AppConfig.passwordResetRedirectTo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset link sent to $email. Open the newest email, then create your new password.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset failed: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 14),
            const HeroCard(),
            const SizedBox(height: 26),
            const Text(
              'Reset your password',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your email and we will send a secure password reset link.',
              style: TextStyle(color: FarmColors.mutedText, fontSize: 15),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 22),
            PrimaryFarmButton(
              label: loading ? 'Sending reset link...' : 'Send reset link',
              onPressed: loading ? null : sendResetLink,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}

class GuestSignInPrompt extends StatelessWidget {
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;
  final VoidCallback onContinueBrowsing;

  const GuestSignInPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onLogin,
    required this.onCreateAccount,
    required this.onContinueBrowsing,
  });

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            color: FarmColors.green,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: FarmColors.mutedText, height: 1.35),
          ),
          const SizedBox(height: 18),
          PrimaryFarmButton(label: primaryLabel, onPressed: onLogin),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(secondaryLabel),
            onPressed: onCreateAccount,
          ),
          TextButton(
            onPressed: onContinueBrowsing,
            child: const Text('Continue browsing'),
          ),
        ],
      ),
    );
  }
}

Future<bool> requireLoginForCheckout(BuildContext context) async {
  if (isLoggedIn) return true;

  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: GuestSignInPrompt(
            title: 'Sign in to complete your order',
            message:
                'Your farm box is saved. Log in or create an account to place your order.',
            primaryLabel: 'Log in',
            secondaryLabel: 'Create account',
            onLogin: () => Navigator.pop(sheetContext, 'login'),
            onCreateAccount: () => Navigator.pop(sheetContext, 'register'),
            onContinueBrowsing: () => Navigator.pop(sheetContext, 'cancel'),
          ),
        ),
      );
    },
  );

  if (action != 'login' && action != 'register') return false;
  if (!context.mounted) return false;

  final signedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => LoginScreen(
        returnToPrevious: true,
        startInRegister: action == 'register',
      ),
    ),
  );

  return signedIn == true || isLoggedIn;
}

class GuestProtectedScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String message;
  final IconData icon;

  const GuestProtectedScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.message,
    this.icon = Icons.lock_outline,
  });

  @override
  State<GuestProtectedScreen> createState() => _GuestProtectedScreenState();
}

class _GuestProtectedScreenState extends State<GuestProtectedScreen> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openLogin({bool createAccount = false}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          returnToPrevious: true,
          startInRegister: createAccount,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Header(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: 18),
          GuestSignInPrompt(
            title: widget.title,
            message: widget.message,
            primaryLabel: 'Log in',
            secondaryLabel: 'Create account',
            onLogin: () => _openLogin(),
            onCreateAccount: () => _openLogin(createAccount: true),
            onContinueBrowsing: () {
              Navigator.maybePop(context);
            },
          ),
        ],
      ),
    );
  }
}

class UpdatePasswordScreen extends StatefulWidget {
  final VoidCallback onPasswordUpdated;

  const UpdatePasswordScreen({
    super.key,
    required this.onPasswordUpdated,
  });

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  bool preparingRecoverySession = AppConfig.hasPasswordRecoveryCallback;
  bool recoverySessionReady = !AppConfig.hasPasswordRecoveryCallback;
  String? recoverySessionError;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareRecoverySession());
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _prepareRecoverySession() async {
    if (!AppConfig.hasPasswordRecoveryCallback) {
      if (!mounted) return;
      setState(() {
        preparingRecoverySession = false;
        recoverySessionReady = true;
        recoverySessionError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        preparingRecoverySession = true;
        recoverySessionError = null;
      });
    }

    try {
      final code = AppConfig.passwordRecoveryCode;
      final refreshToken = AppConfig.passwordRecoveryRefreshToken;
      final accessToken = AppConfig.passwordRecoveryAccessToken;
      final currentSession = supabase.auth.currentSession;

      if (code != null && code.isNotEmpty) {
        await supabase.auth.exchangeCodeForSession(code);
      } else if (refreshToken != null && refreshToken.isNotEmpty) {
        if (accessToken != null && accessToken.isNotEmpty) {
          await supabase.auth.setSession(
            refreshToken,
            accessToken: accessToken,
          );
        } else {
          await supabase.auth.setSession(refreshToken);
        }
      } else if (currentSession == null) {
        throw Exception(
          'Open the newest password reset email link. The test URL without code=... can show this page, but it cannot change the password.',
        );
      }

      if (!mounted) return;
      setState(() {
        preparingRecoverySession = false;
        recoverySessionReady = true;
        recoverySessionError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        preparingRecoverySession = false;
        recoverySessionReady = false;
        recoverySessionError = friendlyAppError(error);
      });
    }
  }

  Future<void> updatePassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a password with at least 6 characters.'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (!recoverySessionReady) {
      await _prepareRecoverySession();
      if (!mounted) return;
      if (!recoverySessionReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recoverySessionError ??
                  'Open the newest password reset email link and try again.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => loading = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );

      AppConfig.cleanPasswordRecoveryUrl();
      widget.onPasswordUpdated();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Could not update password: ${friendlyAppError(error)}')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 28),
            Center(
              child: Image.asset(
                'lib/assets/images/logo.png',
                height: 88,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  '🌿',
                  style: TextStyle(fontSize: 64),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Create New Password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: FarmColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a new password for your account at The Harvest Place Ja.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FarmColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (preparingRecoverySession) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
              Text(
                'Verifying your reset link...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FarmColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (recoverySessionError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FarmColors.dangerSoft,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: FarmColors.danger.withOpacity(0.25)),
                ),
                child: Text(
                  recoverySessionError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FarmColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FarmCard(
              child: Column(
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => hidePassword = !hidePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: hidePassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryFarmButton(
                    label: loading ? 'Updating...' : 'Update Password',
                    icon: Icons.check_circle_outline,
                    onPressed: loading ? null : updatePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'If your reset link says it expired, request a new reset email and open the newest link only once.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FarmColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final bool returnToPrevious;
  final bool startInRegister;

  const LoginScreen({
    super.key,
    this.returnToPrevious = false,
    this.startInRegister = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  bool loading = false;
  bool isRegister = false;
  String selectedRole = 'customer';

  @override
  void initState() {
    super.initState();
    isRegister = widget.startInRegister;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final fullName = fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty || (isRegister && fullName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      if (isRegister) {
        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'role': selectedRole,
          },
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Account created. You are signed in, or check your email if confirmation is enabled.')),
        );

        if (widget.returnToPrevious) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        if (widget.returnToPrevious) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;

      final message = isRegister
          ? 'Could not create account. Please check your details and try again.'
          : 'Invalid password.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: widget.returnToPrevious
          ? AppBar(
              title: Text(isRegister ? 'Create Account' : 'Sign In'),
              backgroundColor: FarmColors.background,
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 28),
            const HeroCard(),
            const SizedBox(height: 26),
            Text(
              isRegister ? 'Create your account' : 'Welcome back',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isRegister
                  ? 'Sign up as a customer.'
                  : 'Login to continue shopping fresh farm produce.',
              style: TextStyle(color: FarmColors.mutedText),
            ),
            const SizedBox(height: 22),
            if (isRegister) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'customer',
                    icon: Icon(Icons.person_outline),
                    label: Text('Customer'),
                  ),
                  ButtonSegment(
                    value: 'farmer',
                    icon: Icon(Icons.agriculture_outlined),
                    label: Text('Farmer'),
                  ),
                ],
                selected: {selectedRole},
                onSelectionChanged: (values) {
                  setState(() => selectedRole = values.first);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (!isRegister) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.lock_reset_outlined, size: 18),
                  label: const Text('Forgot Password?'),
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(
                                initialEmail: emailController.text.trim(),
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryFarmButton(
              label: loading
                  ? 'Please wait...'
                  : (isRegister ? 'Create Account' : 'Login'),
              onPressed: loading ? null : submit,
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () => setState(() => isRegister = !isRegister),
              child: Text(isRegister
                  ? 'Already have an account? Login'
                  : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  final List<Product> favoriteProducts;
  final List<Product> recentlyViewedProducts;
  final VoidCallback onShopTap;
  final bool showAdmin;
  final VoidCallback? onSignedOut;

  const AccountScreen({
    super.key,
    this.favoriteProducts = const [],
    this.recentlyViewedProducts = const [],
    required this.onShopTap,
    this.showAdmin = false,
    this.onSignedOut,
  });

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    if (!isLoggedIn || user == null) {
      return const GuestProtectedScreen(
        title: 'Account',
        subtitle: 'Profile, rewards & tools',
        message:
            'Sign in or create an account to view your profile, rewards, saved details, and private account tools.',
      );
    }

    final name = user.userMetadata?['full_name']?.toString() ?? 'Farm Customer';
    final role = currentUserRole;
    final roleLabel = showAdmin
        ? 'Admin'
        : role == 'farmer'
            ? 'Farmer'
            : 'Customer';

    return FarmPage(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Header(title: 'Account', subtitle: 'Profile, rewards & tools'),
          const SizedBox(height: 18),
          FarmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(user?.email ?? ''),
                const SizedBox(height: 6),
                Chip(label: Text(roleLabel)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const LoyaltySummaryCard(),
          const SizedBox(height: 18),
          FarmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enable browser notifications for order confirmations and farm updates on this device.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Enable Notifications'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final allowed = await requestBrowserNotifications();
                    await saveNotificationPreference(enabled: allowed);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          allowed
                              ? 'Notifications enabled on this device.'
                              : 'Notifications were not enabled.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FarmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Shopping Tools',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.favorite_outline),
                      label: Text('Favorites (${favoriteProducts.length})'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FavoritesScreen(
                              products: favoriteProducts,
                              onShopTap: onShopTap,
                            ),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: Text(
                          'Recently Viewed (${recentlyViewedProducts.length})'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecentlyViewedScreen(
                              products: recentlyViewedProducts,
                              onShopTap: onShopTap,
                            ),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI Assistant'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AIShoppingAssistantScreen(),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Rewards'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoyaltyRewardsScreen(),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Vegan Ingredient Book'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VeganIngredientBookScreen(
                              onShopTap: onShopTap,
                            ),
                          ),
                        );
                      },
                    ),
                    if (showAdmin)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Admin Dashboard'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminDashboardScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryFarmButton(
            label: 'Edit Customer Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          PrimaryFarmButton(
            label: 'Contact Farm Support',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Reviews & Feedback'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          FarmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Policies & Legal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Terms of Service'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: const Text('Privacy Policy'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.replay_circle_filled_outlined),
                      label: const Text('Refund Policy'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RefundPolicyScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryFarmButton(
            label: 'Sign Out',
            onPressed: () async {
              await clearPrivateSessionStateForGuestBrowsing();
              onSignedOut?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Signed out. You can keep browsing as a guest.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class FarmerAccessGate extends StatelessWidget {
  const FarmerAccessGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FarmerProfile?>(
      future: fetchCurrentFarmerProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null) return const FarmerOnboardingScreen();
        return FarmerMarketplaceShell(profile: profile);
      },
    );
  }
}

class FarmerOnboardingScreen extends StatefulWidget {
  const FarmerOnboardingScreen({super.key});

  @override
  State<FarmerOnboardingScreen> createState() => _FarmerOnboardingScreenState();
}

class _FarmerOnboardingScreenState extends State<FarmerOnboardingScreen> {
  final farmNameController = TextEditingController();
  final farmerNameController = TextEditingController();
  final phoneController = TextEditingController();
  final parishController = TextEditingController();
  final addressController = TextEditingController();
  final bioController = TextEditingController();
  final payoutMethodController = TextEditingController();
  final payoutDetailsController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    farmNameController.dispose();
    farmerNameController.dispose();
    phoneController.dispose();
    parishController.dispose();
    addressController.dispose();
    bioController.dispose();
    payoutMethodController.dispose();
    payoutDetailsController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (farmNameController.text.trim().isEmpty ||
        farmerNameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        parishController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please complete farm name, farmer name, phone, and parish.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await saveFarmerProfile(
        farmName: farmNameController.text.trim(),
        farmerName: farmerNameController.text.trim(),
        phone: phoneController.text.trim(),
        parish: parishController.text.trim(),
        address: addressController.text.trim(),
        bio: bioController.text.trim(),
        payoutMethod: payoutMethodController.text.trim(),
        payoutDetails: payoutDetailsController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Farmer profile submitted for admin approval.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FarmerAccessGate()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save farmer profile: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          const Header(
            title: 'Farmer Onboarding',
            subtitle: 'Apply to sell on The Harvest Place Ja',
          ),
          const SizedBox(height: 18),
          FarmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your farm marketplace profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: farmNameController,
                    decoration: const InputDecoration(labelText: 'Farm name')),
                const SizedBox(height: 12),
                TextField(
                    controller: farmerNameController,
                    decoration:
                        const InputDecoration(labelText: 'Farmer name')),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextField(
                    controller: parishController,
                    decoration: const InputDecoration(labelText: 'Parish')),
                const SizedBox(height: 12),
                TextField(
                    controller: addressController,
                    decoration:
                        const InputDecoration(labelText: 'Farm address')),
                const SizedBox(height: 12),
                TextField(
                    controller: bioController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Short farm bio')),
                const SizedBox(height: 12),
                TextField(
                    controller: payoutMethodController,
                    decoration:
                        const InputDecoration(labelText: 'Payout method')),
                const SizedBox(height: 12),
                TextField(
                    controller: payoutDetailsController,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Payout details')),
                const SizedBox(height: 16),
                PrimaryFarmButton(
                    label: loading ? 'Saving...' : 'Submit for Approval',
                    onPressed: loading ? null : submit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FarmerMarketplaceShell extends StatefulWidget {
  final FarmerProfile profile;
  const FarmerMarketplaceShell({super.key, required this.profile});

  @override
  State<FarmerMarketplaceShell> createState() => _FarmerMarketplaceShellState();
}

class _FarmerMarketplaceShellState extends State<FarmerMarketplaceShell> {
  int selectedIndex = 0;
  int refreshKey = 0;

  void refresh() => setState(() => refreshKey++);

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final pages = [
      FarmerDashboardScreen(profile: profile, refreshKey: refreshKey),
      FarmerProductsScreen(
          profile: profile, refreshKey: refreshKey, onChanged: refresh),
      FarmerOrdersScreen(profile: profile, refreshKey: refreshKey),
      FarmerEarningsScreen(profile: profile, refreshKey: refreshKey),
      FarmerAccountScreen(profile: profile),
    ];
    final destinations = <FarmBottomOption>[
      const FarmBottomOption(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      const FarmBottomOption(
        icon: Icon(Icons.eco_outlined),
        selectedIcon: Icon(Icons.eco),
        label: 'Products',
      ),
      const FarmBottomOption(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
      const FarmBottomOption(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments),
        label: 'Earnings',
      ),
      const FarmBottomOption(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Account',
      ),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: FarmBottomOptionsBar(
        selectedIndex: selectedIndex,
        destinations: destinations,
        onSelected: (index) => setState(() => selectedIndex = index),
      ),
    );
  }
}

class FarmerDashboardScreen extends StatelessWidget {
  final FarmerProfile profile;
  final int refreshKey;
  const FarmerDashboardScreen(
      {super.key, required this.profile, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: FutureBuilder<List<Product>>(
        key: ValueKey('farmer-dashboard-$refreshKey'),
        future: fetchFarmerProducts(profile.id),
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
            children: [
              Header(
                  title: profile.farmName,
                  subtitle: 'Farmer marketplace dashboard'),
              const SizedBox(height: 16),
              FarmerStatusCard(profile: profile),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  MarketplaceStatCard(
                      icon: Icons.eco,
                      label: 'Products',
                      value: products.length.toString()),
                  MarketplaceStatCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock units',
                      value: products
                          .fold<int>(0, (sum, item) => sum + item.stockQuantity)
                          .toString()),
                  MarketplaceStatCard(
                      icon: Icons.verified_outlined,
                      label: 'Approved',
                      value: products
                          .where((p) => p.approvalStatus == 'approved')
                          .length
                          .toString()),
                ],
              ),
              const SizedBox(height: 16),
              FarmCard(
                child: Text(
                  profile.isApproved
                      ? 'You are approved to list products. Add fresh produce and keep stock updated.'
                      : 'Your farm is ${profile.statusLabel}. Admin approval is required before your listings can go live.',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FarmerProductsScreen extends StatelessWidget {
  final FarmerProfile profile;
  final int refreshKey;
  final VoidCallback onChanged;
  const FarmerProductsScreen(
      {super.key,
      required this.profile,
      required this.refreshKey,
      required this.onChanged});

  Future<void> openProductForm(BuildContext context) async {
    if (!profile.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin must approve your farm before products can be submitted.',
          ),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final unitController = TextEditingController(text: 'each');
    final descriptionController = TextEditingController();
    final imageController = TextEditingController();
    final originalPriceController = TextEditingController();
    final discountPriceController = TextEditingController();
    final discountPercentController = TextEditingController();
    final discountLabelController = TextEditingController();
    final estimatedReadyDateController = TextEditingController();
    final expectedStockController = TextEditingController();
    final subscribeSavePercentController = TextEditingController(text: '5');
    final dealRankController = TextEditingController(text: '10');

    String selectedCategory = productCategoryOptions.first;
    bool isOrganic = false;
    bool isDiscountActive = false;
    bool readySoon = false;
    bool isDealOfDay = false;
    bool subscribeSaveEnabled = false;
    bool uploadingImage = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                decoration: const BoxDecoration(
                  color: FarmColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Submit Product Listing',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Product name'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: productCategoryOptions
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: isOrganic,
                        title: const Text('Organic item'),
                        subtitle: Text(
                          isOrganic
                              ? 'This item will show as organic in the shop.'
                              : 'Turn on only if this item is organic.',
                        ),
                        activeColor: FarmColors.green,
                        onChanged: (value) {
                          setSheetState(() {
                            isOrganic = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Price'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Stock quantity'),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: readySoon,
                        title: const Text('Ready soon item'),
                        subtitle: const Text(
                            'Let customers request a ready alert before this item is available.'),
                        activeColor: FarmColors.warning,
                        onChanged: (value) =>
                            setSheetState(() => readySoon = value),
                      ),
                      if (readySoon) ...[
                        TextField(
                          controller: estimatedReadyDateController,
                          decoration: const InputDecoration(
                              labelText: 'Estimated ready date',
                              helperText: 'Use YYYY-MM-DD'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: expectedStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Expected quantity'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SwitchListTile(
                        value: isDiscountActive,
                        title: const Text('Discount / deal active'),
                        activeColor: FarmColors.warning,
                        onChanged: (value) =>
                            setSheetState(() => isDiscountActive = value),
                      ),
                      if (isDiscountActive) ...[
                        TextField(
                          controller: originalPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Original price'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: discountPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Discount price'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: discountPercentController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Discount percent'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: discountLabelController,
                          decoration:
                              const InputDecoration(labelText: 'Deal label'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SwitchListTile(
                        value: isDealOfDay,
                        title: const Text('Deal of the Day'),
                        subtitle: const Text(
                            'Feature this item in the customer deal section.'),
                        activeColor: FarmColors.warning,
                        onChanged: (value) =>
                            setSheetState(() => isDealOfDay = value),
                      ),
                      if (isDealOfDay) ...[
                        TextField(
                          controller: dealRankController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Deal display rank',
                            helperText: 'Lower numbers show first',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SwitchListTile(
                        value: subscribeSaveEnabled,
                        title: const Text('Subscribe & Save'),
                        subtitle: const Text(
                            'Let customers set up repeat orders for this item.'),
                        activeColor: FarmColors.success,
                        onChanged: (value) =>
                            setSheetState(() => subscribeSaveEnabled = value),
                      ),
                      if (subscribeSaveEnabled) ...[
                        TextField(
                          controller: subscribeSavePercentController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Subscribe & Save discount %'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'each, bundle, dozen, lb...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FarmColors.cream,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: FarmColors.lightGreen),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Image',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            productImagePreviewFromUrl(
                              imageUrl: imageController.text,
                              fallbackIcon: '🥬',
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: imageController,
                              onChanged: (_) => setSheetState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Image URL',
                                helperText:
                                    'Paste a URL or upload an image from this device.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  icon: uploadingImage
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file_outlined),
                                  label: Text(uploadingImage
                                      ? 'Uploading...'
                                      : 'Upload Image'),
                                  onPressed: uploadingImage
                                      ? null
                                      : () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          setSheetState(
                                              () => uploadingImage = true);
                                          try {
                                            final uploadedUrl =
                                                await pickAndUploadProductImage(
                                              productName: nameController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? 'farmer-product'
                                                  : nameController.text.trim(),
                                            );

                                            if (uploadedUrl != null &&
                                                uploadedUrl.isNotEmpty) {
                                              imageController.text =
                                                  uploadedUrl;
                                              setSheetState(() {});
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Image uploaded successfully.',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (error) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  error.toString().replaceFirst(
                                                        'Exception: ',
                                                        '',
                                                      ),
                                                ),
                                              ),
                                            );
                                          } finally {
                                            if (sheetContext.mounted) {
                                              setSheetState(
                                                  () => uploadingImage = false);
                                            }
                                          }
                                        },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear Image'),
                                  onPressed: uploadingImage
                                      ? null
                                      : () {
                                          imageController.clear();
                                          setSheetState(() {});
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 14),
                      PrimaryFarmButton(
                        label: 'Submit for Admin Approval',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await createFarmerProduct(
                              farmer: profile,
                              name: nameController.text.trim(),
                              price: double.tryParse(
                                      priceController.text.trim()) ??
                                  0,
                              stockQuantity:
                                  int.tryParse(stockController.text.trim()) ??
                                      0,
                              category: selectedCategory,
                              isOrganic: isOrganic,
                              unit: unitController.text.trim(),
                              imageUrl: imageController.text.trim().isEmpty
                                  ? null
                                  : imageController.text.trim(),
                              description: descriptionController.text.trim(),
                              isDiscountActive: isDiscountActive,
                              originalPrice: double.tryParse(
                                  originalPriceController.text.trim()),
                              discountPrice: double.tryParse(
                                  discountPriceController.text.trim()),
                              discountPercent: double.tryParse(
                                  discountPercentController.text.trim()),
                              discountLabel:
                                  discountLabelController.text.trim().isEmpty
                                      ? null
                                      : discountLabelController.text.trim(),
                              readySoon: readySoon,
                              estimatedReadyDate: estimatedReadyDateController
                                      .text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : estimatedReadyDateController.text.trim(),
                              expectedStockQuantity: int.tryParse(
                                  expectedStockController.text.trim()),
                              isDealOfDay: isDealOfDay,
                              dealRank:
                                  int.tryParse(dealRankController.text.trim()),
                              subscribeSaveEnabled: subscribeSaveEnabled,
                              subscribeSaveDiscountPercent: double.tryParse(
                                  subscribeSavePercentController.text.trim()),
                            );

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Product submitted for admin approval.'),
                                ),
                              );
                            }

                            onChanged();
                          } catch (error) {
                            if (sheetContext.mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error
                                        .toString()
                                        .replaceFirst('Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    unitController.dispose();
    descriptionController.dispose();
    imageController.dispose();
    originalPriceController.dispose();
    discountPriceController.dispose();
    discountPercentController.dispose();
    discountLabelController.dispose();
    estimatedReadyDateController.dispose();
    expectedStockController.dispose();
    subscribeSavePercentController.dispose();
    dealRankController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          Header(
              title: 'My Products', subtitle: '${profile.farmName} listings'),
          const SizedBox(height: 16),
          FarmerStatusCard(profile: profile),
          const SizedBox(height: 14),
          PrimaryFarmButton(
              label: '+ Add Product',
              onPressed: () => openProductForm(context)),
          const SizedBox(height: 16),
          FutureBuilder<List<Product>>(
            key: ValueKey('farmer-products-$refreshKey'),
            future: fetchFarmerProducts(profile.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 420, child: SkeletonList(count: 3));
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const FarmEmptyState(
                  icon: Icons.eco_outlined,
                  title: 'No products yet',
                  message:
                      'Approved farmers can submit listings for admin approval.',
                );
              }
              return Column(
                children: products
                    .map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FarmerProductListingCard(product: product),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FarmerOrdersScreen extends StatelessWidget {
  final FarmerProfile profile;
  final int refreshKey;
  const FarmerOrdersScreen(
      {super.key, required this.profile, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: FutureBuilder<List<FarmerOrderSummary>>(
        key: ValueKey('farmer-orders-$refreshKey'),
        future: fetchFarmerOrderSummaries(profile.id),
        builder: (context, snapshot) {
          final orders = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
            children: [
              const Header(
                  title: 'Farmer Orders',
                  subtitle: 'Orders containing your farm products'),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                const FarmEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No farmer orders yet',
                  message:
                      'Orders containing your products will appear here once the marketplace columns are enabled.',
                )
              else
                ...orders.take(20).map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FarmCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${order.shortOrderId}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(order.productName,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(
                                'Qty ${order.quantity} • Line J\$${order.lineTotal.toStringAsFixed(2)} • Earn J\$${order.farmerEarningAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: const [
                              Chip(label: Text('Received')),
                              Chip(label: Text('Preparing')),
                              Chip(label: Text('Ready')),
                              Chip(label: Text('Completed')),
                            ]),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class FarmerEarningsScreen extends StatelessWidget {
  final FarmerProfile profile;
  final int refreshKey;
  const FarmerEarningsScreen(
      {super.key, required this.profile, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: FutureBuilder<List<FarmerPayout>>(
        key: ValueKey('farmer-payouts-$refreshKey'),
        future: fetchFarmerPayouts(farmerId: profile.id),
        builder: (context, snapshot) {
          final payouts = snapshot.data ?? [];
          final pending = payouts
              .where((p) => p.payoutStatus == 'pending')
              .fold<double>(0, (sum, p) => sum + p.netAmount);
          final released = payouts
              .where((p) => p.payoutStatus == 'released')
              .fold<double>(0, (sum, p) => sum + p.netAmount);
          final held = payouts
              .where((p) => p.payoutStatus == 'held')
              .fold<double>(0, (sum, p) => sum + p.netAmount);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
            children: [
              const Header(
                  title: 'Earnings',
                  subtitle: 'Admin-controlled farmer payouts'),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                MarketplaceStatCard(
                    icon: Icons.pending_actions,
                    label: 'Pending',
                    value: 'J\$${pending.toStringAsFixed(2)}'),
                MarketplaceStatCard(
                    icon: Icons.verified,
                    label: 'Released',
                    value: 'J\$${released.toStringAsFixed(2)}'),
                MarketplaceStatCard(
                    icon: Icons.pause_circle_outline,
                    label: 'Held',
                    value: 'J\$${held.toStringAsFixed(2)}'),
              ]),
              const SizedBox(height: 16),
              if (payouts.isEmpty)
                const FarmEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No payouts yet',
                  message:
                      'Payouts appear after customer orders are paid and admin prepares farmer releases.',
                )
              else
                ...payouts.map((payout) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PayoutCard(payout: payout),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class FarmerAccountScreen extends StatelessWidget {
  final FarmerProfile profile;
  const FarmerAccountScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          const Header(
              title: 'Farmer Account', subtitle: 'Marketplace profile'),
          const SizedBox(height: 16),
          FarmerStatusCard(profile: profile),
          const SizedBox(height: 16),
          FarmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TraceRow(
                    icon: Icons.person_outline,
                    title: 'Farmer',
                    value: profile.farmerName),
                TraceRow(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: profile.phone),
                TraceRow(
                    icon: Icons.location_on_outlined,
                    title: 'Parish',
                    value: profile.parish),
                TraceRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Payout method',
                    value: profile.payoutMethod.isEmpty
                        ? 'Not provided'
                        : profile.payoutMethod),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryFarmButton(
            label: 'Sign Out',
            onPressed: () async {
              await clearPrivateSessionStateForGuestBrowsing();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainNavigation()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class FarmerStatusCard extends StatelessWidget {
  final FarmerProfile profile;
  const FarmerStatusCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final color = profile.isApproved
        ? FarmColors.green
        : profile.verificationStatus == 'rejected'
            ? FarmColors.danger
            : FarmColors.warning;
    return FarmCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: FarmColors.lightGreen,
            child: Icon(Icons.agriculture_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.farmName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${profile.farmerName} • ${profile.parish}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Chip(
                    label: Text(profile.statusLabel),
                    labelStyle:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MarketplaceStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const MarketplaceStatCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: FarmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FarmColors.green),
            const SizedBox(height: 10),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class FarmerProductListingCard extends StatelessWidget {
  final Product product;
  const FarmerProductListingCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductVisual(product: product, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    product.description?.trim().isEmpty == false
                        ? product.description!.trim()
                        : 'Fresh farm listing.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(
                      label:
                          DiscountPriceText(product: product, compact: true)),
                  Chip(label: Text(product.category)),
                  if (product.isOrganic) const Chip(label: Text('Organic')),
                  Chip(label: Text('Stock: ${product.stockQuantity}')),
                  Chip(label: Text(_friendlyStatus(product.approvalStatus))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PayoutCard extends StatelessWidget {
  final FarmerPayout payout;
  final VoidCallback? onChanged;
  const PayoutCard({super.key, required this.payout, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    'Order #${payout.orderId.length <= 6 ? payout.orderId : payout.orderId.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Chip(label: Text(_friendlyStatus(payout.payoutStatus))),
            ],
          ),
          const SizedBox(height: 8),
          TraceRow(
              icon: Icons.shopping_bag_outlined,
              title: 'Gross',
              value: 'J\$${payout.grossAmount.toStringAsFixed(2)}'),
          TraceRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Platform commission',
              value: 'J\$${payout.commissionAmount.toStringAsFixed(2)}'),
          TraceRow(
              icon: Icons.payments_outlined,
              title: 'Farmer payout',
              value: 'J\$${payout.netAmount.toStringAsFixed(2)}'),
          if (onChanged != null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                  onPressed: () async {
                    await updateFarmerPayoutStatus(
                        payoutId: payout.id, status: 'released');
                    onChanged?.call();
                  },
                  child: const Text('Release')),
              OutlinedButton(
                  onPressed: () async {
                    await updateFarmerPayoutStatus(
                        payoutId: payout.id, status: 'held');
                    onChanged?.call();
                  },
                  child: const Text('Hold')),
              OutlinedButton(
                  onPressed: () async {
                    await updateFarmerPayoutStatus(
                        payoutId: payout.id, status: 'disputed');
                    onChanged?.call();
                  },
                  child: const Text('Dispute')),
            ]),
          ],
        ],
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const int homeTabIndex = 0;
  static const int shopTabIndex = 1;
  static const int myBoxTabIndex = 2;
  static const int ordersTabIndex = 3;
  static const int adminTabIndex = 4;

  int get accountTabIndex => showAdmin ? 5 : 4;

  int selectedIndex = 0;
  final List<Product> cart = [];
  final Set<String> favoriteProductIds = <String>{};
  final Map<String, Product> favoriteProductCache = <String, Product>{};
  static const String recentlyViewedStorageKey =
      'natural_harvest_recently_viewed_product_ids';

  final List<Product> recentlyViewedProducts = [];
  bool checkingAdmin = true;
  bool showAdmin = false;
  dynamic inventoryRealtimeChannel;
  Timer? inventoryRefreshDebounce;
  StreamSubscription<AuthState>? authStateSubscription;

  int get cartItemCount => cart.length;

  int authViewVersion = 0;

  String get authViewKey {
    if (!isLoggedIn) return 'guest-$authViewVersion';
    return 'user-${currentUserId ?? 'unknown'}-$authViewVersion';
  }

  List<Product> get favoriteProducts => favoriteProductIds
      .map((id) => favoriteProductCache[id])
      .whereType<Product>()
      .toList();

  @override
  void initState() {
    super.initState();
    cart.addAll(OfflineCartStore.restore());
    loadRecentlyViewedProducts();
    loadAdminStatus();
    subscribeToInventoryUpdates();
    authStateSubscription = supabase.auth.onAuthStateChange.listen((_) async {
      if (!mounted) return;

      FarmDataCache.clearOrders();

      if (!isLoggedIn) {
        FarmDataCache.clearAll();
        setState(() {
          authViewVersion++;
          showAdmin = false;
          checkingAdmin = false;
          if (selectedIndex == accountTabIndex ||
              selectedIndex == adminTabIndex) {
            selectedIndex = homeTabIndex;
          }
        });
        return;
      }

      await loadAdminStatus();
      if (mounted) {
        setState(() {
          authViewVersion++;
        });
      }
    });
  }

  @override
  void dispose() {
    inventoryRefreshDebounce?.cancel();
    authStateSubscription?.cancel();
    if (inventoryRealtimeChannel != null) {
      supabase.removeChannel(inventoryRealtimeChannel);
    }
    super.dispose();
  }

  void subscribeToInventoryUpdates() {
    try {
      inventoryRealtimeChannel = supabase
          .channel('natural-harvest-products-realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (_) {
              inventoryRefreshDebounce?.cancel();
              inventoryRefreshDebounce = Timer(
                AppPerformanceConfig.realtimeDebounce,
                () {
                  if (mounted) setState(() {});
                },
              );
            },
          )
          .subscribe();
    } catch (error) {
      debugPrint('Realtime inventory unavailable: $error');
    }
  }

  Future<void> loadAdminStatus() async {
    if (!isLoggedIn) {
      if (!mounted) return;
      setState(() {
        showAdmin = false;
        checkingAdmin = false;
      });
      return;
    }

    final result = await isCurrentUserAdminFromDatabase();
    if (!mounted) return;
    setState(() {
      showAdmin = result;
      checkingAdmin = false;
    });
  }

  void persistCart() {
    OfflineCartStore.save(cart);
  }

  int quantityForProduct(Product product) {
    return cart.where((item) => item.id == product.id).length;
  }

  bool isFavorite(Product product) => favoriteProductIds.contains(product.id);

  void toggleFavorite(Product product) {
    setState(() {
      if (favoriteProductIds.contains(product.id)) {
        favoriteProductIds.remove(product.id);
        favoriteProductCache.remove(product.id);
      } else {
        favoriteProductIds.add(product.id);
        favoriteProductCache[product.id] = product;
      }
    });
  }

  void saveRecentlyViewedProducts() {
    if (!kIsWeb) return;
    try {
      final ids = recentlyViewedProducts
          .where(isVisibleCustomerProduct)
          .map((product) => product.id.trim())
          .where((id) => id.isNotEmpty)
          .take(10)
          .join(',');
      debugPrint('Recently viewed saved in memory for this session.');
    } catch (error) {
      debugPrint('Recently viewed save skipped: $error');
    }
  }

  Future<void> loadRecentlyViewedProducts() async {
    if (!kIsWeb) return;
    try {
      final saved = '';
      final ids = saved
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .take(10)
          .toList();

      if (ids.isEmpty) return;

      final fetched = await Future.wait<Product?>(
        ids.map(fetchProductById),
      );
      final loaded =
          fetched.whereType<Product>().where(isVisibleCustomerProduct).toList();

      if (!mounted) return;
      setState(() {
        recentlyViewedProducts
          ..clear()
          ..addAll(cleanRecentlyViewedProducts(loaded));
      });
    } catch (error) {
      debugPrint('Recently viewed load skipped: $error');
    }
  }

  void trackRecentlyViewed(Product product) {
    if (!isVisibleCustomerProduct(product)) return;

    setState(() {
      recentlyViewedProducts.removeWhere((item) => item.id == product.id);
      recentlyViewedProducts.insert(0, product);
      final cleaned = cleanRecentlyViewedProducts(recentlyViewedProducts);
      recentlyViewedProducts
        ..clear()
        ..addAll(cleaned);
    });

    saveRecentlyViewedProducts();
  }

  void increaseProductQuantity(Product product) {
    if (!product.canAddToCart) return;
    setState(() {
      cart.add(product);
      persistCart();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} added to cart')),
    );
  }

  void decreaseProductQuantity(Product product) {
    final index = cart.indexWhere((item) => item.id == product.id);
    if (index == -1) return;

    setState(() {
      cart.removeAt(index);
      persistCart();
    });
  }

  void addToCart(Product product) {
    if (!product.canAddToCart) return;
    increaseProductQuantity(product);
  }

  void removeFromCart(Product product) => decreaseProductQuantity(product);

  Future<void> openSignInFromTab() async {
    final didSignIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnToPrevious: true),
      ),
    );

    if (!mounted) return;
    if (didSignIn == true || isLoggedIn) {
      await loadAdminStatus();
      if (!mounted) return;
      // After the admin check finishes, Account may have shifted to index 5.
      setState(() => selectedIndex = accountTabIndex);
    } else {
      setState(() {});
    }
  }

  void openFloatingCart() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: FarmColors.background,
          appBar: AppBar(
            title: const Text('My Farm Box'),
            backgroundColor: FarmColors.background,
          ),
          body: FarmBoxScreen(
            cart: cart,
            onRemoveFromCart: removeFromCart,
            onOrderPlaced: () {
              if (!mounted) return;
              setState(() {
                cart.clear();
                persistCart();
                selectedIndex = ordersTabIndex;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final goToShop = () {
      if (!mounted) return;
      setState(() => selectedIndex = shopTabIndex);
    };

    final pages = <Widget>[
      HomeScreen(
        key: ValueKey('home-$authViewKey'),
        onShopTap: goToShop,
        onCartTap: openFloatingCart,
        cartItemCount: cartItemCount,
        recentlyViewedProducts: recentlyViewedProducts,
        favoriteProducts: favoriteProducts,
        onAddToCart: increaseProductQuantity,
        onRemoveFromCart: decreaseProductQuantity,
        quantityForProduct: quantityForProduct,
        onViewed: trackRecentlyViewed,
      ),
      ShopScreen(
        onAddToCart: increaseProductQuantity,
        onRemoveFromCart: decreaseProductQuantity,
        quantityForProduct: quantityForProduct,
        isFavorite: isFavorite,
        onToggleFavorite: toggleFavorite,
        onViewed: trackRecentlyViewed,
        recentlyViewedProducts: recentlyViewedProducts,
      ),
      FarmBoxScreen(
        cart: cart,
        onRemoveFromCart: removeFromCart,
        onOrderPlaced: () {
          if (!mounted) return;
          setState(() {
            cart.clear();
            persistCart();
            FarmDataCache.clearOrders();
            selectedIndex = ordersTabIndex;
          });
        },
      ),
      OrdersScreen(key: ValueKey('orders-$authViewKey')),
      if (showAdmin)
        AdminDashboardScreen(
          onHomeTap: () {
            if (!mounted) return;
            setState(() => selectedIndex = homeTabIndex);
          },
        ),
      AccountScreen(
        favoriteProducts: favoriteProducts,
        recentlyViewedProducts: recentlyViewedProducts,
        onShopTap: goToShop,
        showAdmin: showAdmin,
        onSignedOut: () {
          if (!mounted) return;
          setState(() {
            selectedIndex = homeTabIndex;
            showAdmin = false;
            checkingAdmin = false;
          });
        },
      ),
    ];

    final destinations = <FarmBottomOption>[
      const FarmBottomOption(
        icon: Icon(Icons.home_outlined, size: 28),
        selectedIcon: Icon(Icons.home_rounded, size: 28),
        label: 'Home',
      ),
      const FarmBottomOption(
        icon: Icon(Icons.storefront_outlined, size: 28),
        selectedIcon: Icon(Icons.storefront_rounded, size: 28),
        label: 'Shop',
      ),
      FarmBottomOption(
        icon: const Icon(Icons.shopping_bag_outlined, size: 28),
        selectedIcon: const Icon(Icons.shopping_bag_rounded, size: 28),
        label: 'My Box',
        badgeCount: cartItemCount,
      ),
      const FarmBottomOption(
        icon: Icon(Icons.receipt_long_outlined, size: 28),
        selectedIcon: Icon(Icons.receipt_long_rounded, size: 28),
        label: 'Orders',
      ),
      if (showAdmin)
        const FarmBottomOption(
          icon: Icon(Icons.local_offer_outlined, size: 28),
          selectedIcon: Icon(Icons.local_offer_rounded, size: 28),
          label: 'Admin',
        ),
      const FarmBottomOption(
        icon: Icon(Icons.person_outline_rounded, size: 28),
        selectedIcon: Icon(Icons.person_rounded, size: 28),
        label: 'Account',
      ),
    ];

    final safeSelectedIndex =
        selectedIndex >= pages.length ? homeTabIndex : selectedIndex;

    return Scaffold(
      body: IndexedStack(index: safeSelectedIndex, children: pages),
      bottomNavigationBar: FarmBottomOptionsBar(
        selectedIndex: safeSelectedIndex,
        destinations: destinations,
        onSelected: (index) async {
          if (!mounted) return;

          final tappedAccountTab = index == accountTabIndex;
          final tappedAdminTab = showAdmin && index == adminTabIndex;

          if (tappedAccountTab && !isLoggedIn) {
            await openSignInFromTab();
            return;
          }

          if (tappedAdminTab) {
            await loadAdminStatus();
            if (!showAdmin) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Admin permission required.')),
              );
              return;
            }
          }

          setState(() => selectedIndex = index);
        },
      ),
    );
  }
}

class FarmBottomOption {
  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final int badgeCount;

  const FarmBottomOption({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class FarmBottomOptionsBar extends StatelessWidget {
  final int selectedIndex;
  final List<FarmBottomOption> destinations;
  final ValueChanged<int> onSelected;

  const FarmBottomOptionsBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = destinations.isEmpty
        ? 0
        : selectedIndex.clamp(0, destinations.length - 1).toInt();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: FarmColors.surface,
          border: const Border(
            top: BorderSide(color: FarmColors.line),
          ),
          boxShadow: [
            BoxShadow(
              color: FarmColors.shadow.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (index) {
            final option = destinations[index];
            final selected = index == safeIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _syncKeyboardStateSafely(),
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color:
                        selected ? FarmColors.lightGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              color: selected
                                  ? FarmColors.green
                                  : FarmColors.muted,
                              size: 22,
                            ),
                            child: selected ? option.selectedIcon : option.icon,
                          ),
                          if (option.badgeCount > 0)
                            Positioned(
                              top: -8,
                              right: -14,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: FarmColors.accent,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          FarmColors.shadow.withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  option.badgeCount > 99
                                      ? '99+'
                                      : option.badgeCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: FarmColors.ink,
                                    fontSize: 10,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                          color: selected ? FarmColors.green : FarmColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class OfflineCartStore {
  static final List<Product> _sessionCart = <Product>[];

  static List<Product> restore() => List<Product>.from(_sessionCart);

  static void save(List<Product> cart) {
    _sessionCart
      ..clear()
      ..addAll(cart);
  }
}

String personalizedFirstName(CustomerProfile? profile) {
  if (!isLoggedIn) return 'Guest';

  final rawName = (profile?.fullName ?? '').trim();
  final cleanName = rawName.toLowerCase();
  final email = supabase.auth.currentUser?.email ?? '';
  final localPart = email.split('@').first.trim();

  String emailFirstName() {
    if (localPart.isEmpty) return 'there';

    // Prefer a friendly first name instead of showing the whole email handle.
    var cleaned = localPart
        .replaceAll(RegExp(r'[0-9]+'), ' ')
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();

    if (!cleaned.contains(' ') && cleaned.length > 12) {
      // Common school/business handles sometimes join first + last + org code.
      // This keeps the greeting human, e.g. ricardofergusonlshs -> Ricardo.
      final lower = cleaned.toLowerCase();
      if (lower.startsWith('ricardo')) cleaned = 'ricardo';
    }

    final readable = titleCaseWords(cleaned).trim();
    if (readable.isEmpty) return 'there';
    return readable.split(' ').first;
  }

  // Never use role/fallback labels as the customer's display name.
  if (rawName.isEmpty || cleanName == 'admin' || cleanName == 'administrator') {
    return emailFirstName();
  }

  return titleCaseWords(rawName).split(' ').first;
}

String personalizedGreeting(CustomerProfile? profile) {
  final firstName = personalizedFirstName(profile);
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning, $firstName';
  if (hour < 17) return 'Good afternoon, $firstName';
  return 'Good evening, $firstName';
}

String personalizedHeroMessage({
  required CustomerProfile? profile,
  required LoyaltySummary loyalty,
  required List<Product> allProducts,
  required List<Product> buyAgainProducts,
  required List<Product> favoriteProducts,
  required List<Product> recentlyViewedProducts,
}) {
  final firstName = personalizedFirstName(profile);
  final categories = <String>[
    ...buyAgainProducts.map((product) => product.category),
    ...favoriteProducts.map((product) => product.category),
    ...recentlyViewedProducts.map((product) => product.category),
  ].map((value) => value.trim()).where((value) => value.isNotEmpty).toList();

  final favoriteCategory = mostCommonText(categories);
  final freshFavorites = allProducts.where((product) {
    return isProductHarvestedThisWeek(product) &&
        (favoriteCategory == null || product.category == favoriteCategory);
  }).toList();

  if (buyAgainProducts.isEmpty && favoriteProducts.isEmpty) {
    return 'Welcome, $firstName — fresh local picks are ready for your first farm box.';
  }
  if (loyalty.tier == 'Platinum') {
    return '$firstName, your Platinum harvest picks are ready with priority deals.';
  }
  if (freshFavorites.isNotEmpty && favoriteCategory != null) {
    return 'Fresh $favoriteCategory picked for you today, $firstName.';
  }
  if (buyAgainProducts.isNotEmpty) {
    return '${buyAgainProducts.first.name} and more favorites are ready to buy again.';
  }
  if (favoriteProducts.isNotEmpty) {
    return 'Your favorite farm products are waiting, $firstName.';
  }
  return 'Fresh local produce picked for you today, $firstName.';
}

String? mostCommonText(List<String> values) {
  if (values.isEmpty) return null;
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final value in values) {
    final clean = value.trim();
    if (clean.isEmpty) continue;
    final key = clean.toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    labels[key] = clean;
  }
  if (counts.isEmpty) return null;
  final best = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return labels[best.first.key];
}

List<Product> sortProductsForPersonalization({
  required List<Product> products,
  required List<Product> recentlyViewedProducts,
  required List<Product> buyAgainProducts,
  required List<Product> favoriteProducts,
}) {
  final boughtIds = buyAgainProducts.map((product) => product.id).toSet();
  final viewedIds = recentlyViewedProducts.map((product) => product.id).toSet();
  final favoriteIds = favoriteProducts.map((product) => product.id).toSet();
  final signalCategories = <String>{
    ...buyAgainProducts.map((product) => product.category.toLowerCase()),
    ...recentlyViewedProducts.map((product) => product.category.toLowerCase()),
    ...favoriteProducts.map((product) => product.category.toLowerCase()),
  }..removeWhere((category) => category.trim().isEmpty);

  int score(Product product) {
    var value = 0;
    if (boughtIds.contains(product.id)) value += 80;
    if (favoriteIds.contains(product.id)) value += 70;
    if (viewedIds.contains(product.id)) value += 55;
    if (signalCategories.contains(product.category.toLowerCase())) value += 35;
    if (product.showAsDealOfDay || product.hasActiveDiscount) value += 25;
    if (isProductHarvestedThisWeek(product)) value += 20;
    if (product.isLowStock) value += 8;
    return value;
  }

  final output = List<Product>.from(products);
  output.sort((a, b) {
    final byScore = score(b).compareTo(score(a));
    if (byScore != 0) return byScore;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return output;
}

class PersonalizedHomeHeroLoader extends StatelessWidget {
  final Future<CustomerProfile?> profileFuture;
  final Future<LoyaltySummary> loyaltyFuture;
  final List<Product> allProducts;
  final List<Product> buyAgainProducts;
  final List<Product> favoriteProducts;
  final List<Product> recentlyViewedProducts;
  final VoidCallback onShopTap;

  const PersonalizedHomeHeroLoader({
    super.key,
    required this.profileFuture,
    required this.loyaltyFuture,
    required this.allProducts,
    required this.buyAgainProducts,
    required this.favoriteProducts,
    required this.recentlyViewedProducts,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerProfile?>(
      future: profileFuture,
      builder: (context, profileSnapshot) {
        return FutureBuilder<LoyaltySummary>(
          future: loyaltyFuture,
          builder: (context, loyaltySnapshot) {
            final profile = profileSnapshot.data;
            final loyalty = loyaltySnapshot.data ??
                const LoyaltySummary(
                  points: 0,
                  lifetimePoints: 0,
                  tier: 'Green',
                );

            return PersonalizedHomeHeroCard(
              profile: profile,
              loyalty: loyalty,
              allProducts: allProducts,
              buyAgainProducts: buyAgainProducts,
              favoriteProducts: favoriteProducts,
              recentlyViewedProducts: recentlyViewedProducts,
              onShopTap: onShopTap,
            );
          },
        );
      },
    );
  }
}

class PersonalizedHomeHeroCard extends StatelessWidget {
  final CustomerProfile? profile;
  final LoyaltySummary loyalty;
  final List<Product> allProducts;
  final List<Product> buyAgainProducts;
  final List<Product> favoriteProducts;
  final List<Product> recentlyViewedProducts;
  final VoidCallback onShopTap;

  const PersonalizedHomeHeroCard({
    super.key,
    required this.profile,
    required this.loyalty,
    required this.allProducts,
    required this.buyAgainProducts,
    required this.favoriteProducts,
    required this.recentlyViewedProducts,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = mostCommonText([
          ...buyAgainProducts.map((product) => product.category),
          ...favoriteProducts.map((product) => product.category),
          ...recentlyViewedProducts.map((product) => product.category),
        ]) ??
        'vegetables';

    const heroImageUrl =
        'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=900&q=80';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onShopTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            color: FarmColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FarmColors.line),
            boxShadow: [
              BoxShadow(
                color: FarmColors.shadow.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                heroImageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                cacheWidth: 900,
                errorBuilder: (_, __, ___) => Container(
                  color: FarmColors.primarySoft,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFE5F3DF).withOpacity(0.98),
                      const Color(0xFFE5F3DF).withOpacity(0.88),
                      const Color(0xFFE5F3DF).withOpacity(0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.48, 0.72, 1.0],
                  ),
                ),
              ),
              Positioned(
                right: 58,
                top: 16,
                child: Icon(
                  Icons.eco_outlined,
                  color: FarmColors.green.withOpacity(0.22),
                  size: 22,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 108, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fresh ${category.toLowerCase()}\npicked for you today!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FarmColors.deepGreen,
                        fontSize: 16,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    Text(
                      'Hand-picked. Farm fresh. Just for you.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FarmColors.deepGreen.withOpacity(0.72),
                        fontSize: 11.5,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.spa_outlined,
                      color: FarmColors.green.withOpacity(0.72),
                      size: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalizedHeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PersonalizedHeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalizedHomeHeader extends StatelessWidget {
  final Future<CustomerProfile?> profileFuture;
  final Future<LoyaltySummary> loyaltyFuture;
  final VoidCallback onCartTap;
  final int cartItemCount;

  const PersonalizedHomeHeader({
    super.key,
    required this.profileFuture,
    required this.loyaltyFuture,
    required this.onCartTap,
    required this.cartItemCount,
  });

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerProfile?>(
      future: profileFuture,
      builder: (context, profileSnapshot) {
        final firstName = personalizedFirstName(profileSnapshot.data);
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeGreeting(),
                      style: const TextStyle(
                        color: FarmColors.deepGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FarmColors.deepGreen,
                              fontSize: 27,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.65,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.wb_sunny_rounded,
                          color: Color(0xFFFFC928),
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Happy Harvest Day!',
                      style: TextStyle(
                        color: FarmColors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FarmNotificationButton(size: 38),
                    const SizedBox(width: 8),
                    FarmHeaderCartButton(
                      size: 38,
                      itemCount: cartItemCount,
                      onPressed: onCartTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PersonalizedLoyaltyCard extends StatelessWidget {
  final Future<LoyaltySummary> loyaltyFuture;

  const PersonalizedLoyaltyCard({
    super.key,
    required this.loyaltyFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoyaltySummary>(
      future: loyaltyFuture,
      builder: (context, snapshot) {
        final loyalty = snapshot.data ??
            const LoyaltySummary(points: 0, lifetimePoints: 0, tier: 'Green');
        final tier = loyalty.tier.trim().isEmpty ? 'Green' : loyalty.tier;

        return FarmCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: FarmColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco_outlined,
                        color: FarmColors.green,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$tier Member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FarmColors.deepGreen,
                              fontSize: 15,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You’re saving with every order',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: FarmColors.mutedText,
                              fontSize: 10.8,
                              height: 1.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: FarmColors.line,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${loyalty.points}',
                    style: const TextStyle(
                      color: FarmColors.deepGreen,
                      fontSize: 21,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Points Balance',
                    style: TextStyle(
                      color: FarmColors.mutedText,
                      fontSize: 10.2,
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: FarmColors.green,
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }
}

class PersonalizedInsightsLoader extends StatelessWidget {
  final Future<LoyaltySummary> loyaltyFuture;
  final List<Product> allProducts;
  final List<Product> buyAgainProducts;
  final List<Product> favoriteProducts;
  final List<Product> recentlyViewedProducts;

  const PersonalizedInsightsLoader({
    super.key,
    required this.loyaltyFuture,
    required this.allProducts,
    required this.buyAgainProducts,
    required this.favoriteProducts,
    required this.recentlyViewedProducts,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoyaltySummary>(
      future: loyaltyFuture,
      builder: (context, snapshot) {
        final loyalty = snapshot.data ??
            const LoyaltySummary(
              points: 0,
              lifetimePoints: 0,
              tier: 'Green',
            );
        final farmers = <String>{
          ...buyAgainProducts.map((product) => product.farmName ?? ''),
          ...favoriteProducts.map((product) => product.farmName ?? ''),
          ...recentlyViewedProducts.map((product) => product.farmName ?? ''),
        }..removeWhere((value) => value.trim().isEmpty);
        final favoriteCategory = mostCommonText([
              ...buyAgainProducts.map((product) => product.category),
              ...favoriteProducts.map((product) => product.category),
              ...recentlyViewedProducts.map((product) => product.category),
            ]) ??
            'Fresh Produce';
        final favoriteProduct = buyAgainProducts.isNotEmpty
            ? buyAgainProducts.first.name
            : favoriteProducts.isNotEmpty
                ? favoriteProducts.first.name
                : recentlyViewedProducts.isNotEmpty
                    ? recentlyViewedProducts.first.name
                    : 'Explore today';

        return FarmCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Harvest Snapshot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InsightPill(
                    icon: Icons.workspace_premium_outlined,
                    label: '${loyalty.points} points',
                  ),
                  _InsightPill(
                    icon: Icons.category_outlined,
                    label: favoriteCategory,
                  ),
                  _InsightPill(
                    icon: Icons.shopping_bag_outlined,
                    label: favoriteProduct,
                  ),
                  _InsightPill(
                    icon: Icons.storefront_outlined,
                    label: '${farmers.length} local farms',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InsightPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FarmColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FarmColors.green),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FarmColors.green,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalizedPromotionCard extends StatelessWidget {
  final Future<CustomerProfile?> profileFuture;
  final Future<LoyaltySummary> loyaltyFuture;
  final List<Product> buyAgainProducts;
  final List<Product> recommendedProducts;
  final VoidCallback onShopTap;

  const PersonalizedPromotionCard({
    super.key,
    required this.profileFuture,
    required this.loyaltyFuture,
    required this.buyAgainProducts,
    required this.recommendedProducts,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onShopTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        color: FarmColors.deepGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Browse fresh picks and personalized deals we think you’ll love.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FarmColors.mutedText,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: FarmColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: FarmColors.deepGreen,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onShopTap;
  final VoidCallback onCartTap;
  final int cartItemCount;
  final List<Product> recentlyViewedProducts;
  final List<Product> favoriteProducts;
  final void Function(Product product) onAddToCart;
  final void Function(Product product) onRemoveFromCart;
  final int Function(Product product) quantityForProduct;
  final void Function(Product product) onViewed;

  const HomeScreen({
    super.key,
    required this.onShopTap,
    required this.onCartTap,
    required this.cartItemCount,
    this.recentlyViewedProducts = const [],
    this.favoriteProducts = const [],
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.quantityForProduct,
    required this.onViewed,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Product>> homeProductsFuture;
  late Future<List<Product>> buyAgainProductsFuture;
  late Future<CustomerProfile?> customerProfileFuture;
  late Future<LoyaltySummary> loyaltySummaryFuture;
  List<Product> cachedHomeProducts = fallbackProducts;

  @override
  void initState() {
    super.initState();
    homeProductsFuture = loadHomeProducts();
    buyAgainProductsFuture = fetchBuyAgainProducts();
    customerProfileFuture = fetchCurrentCustomerProfile();
    loyaltySummaryFuture = fetchLoyaltySummary();
  }

  Future<List<Product>> loadHomeProducts() async {
    final products = await fetchProducts(forceRefresh: true);
    final visible = products.isEmpty ? fallbackProducts : products;

    visible.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    cachedHomeProducts = visible;
    return cachedHomeProducts;
  }

  void refreshHomeProducts() {
    if (!mounted) return;
    setState(() {
      homeProductsFuture = loadHomeProducts();
      buyAgainProductsFuture = fetchBuyAgainProducts();
      customerProfileFuture = fetchCurrentCustomerProfile();
      loyaltySummaryFuture = fetchLoyaltySummary();
    });
  }

  void openProduct(Product product) {
    widget.onViewed(product);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          quantity: widget.quantityForProduct(product),
          onAdd: () => widget.onAddToCart(product),
          onRemove: () => widget.onRemoveFromCart(product),
          onAddProduct: widget.onAddToCart,
          onViewed: widget.onViewed,
        ),
      ),
    );
  }

  Widget productRail({
    required List<Product> products,
    required int maxItems,
  }) {
    final visible = products.take(maxItems).toList();

    if (visible.isEmpty) {
      return const FarmCard(
        child: Text(
          'No products available yet. Add approved products with image URLs to show them here.',
        ),
      );
    }

    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        cacheExtent: AppPerformanceConfig.productRailCacheExtent,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = visible[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => openProduct(product),
            child: Container(
              width: 136,
              child: FarmCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ProductVisual(product: product, size: 58),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    DiscountPriceText(product: product, compact: true),
                    if (product.isOrganic ||
                        isProductHarvestedThisWeek(product))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          product.isOrganic &&
                                  isProductHarvestedThisWeek(product)
                              ? 'Organic • Recently harvested'
                              : product.isOrganic
                                  ? 'Organic'
                                  : 'Recently harvested',
                          style: const TextStyle(
                            color: FarmColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget loadingRail() {
    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        cacheExtent: AppPerformanceConfig.productRailCacheExtent,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) {
          return Container(
            width: 136,
            child: const FarmCard(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FarmPage(
      child: FutureBuilder<List<Product>>(
        future: homeProductsFuture,
        builder: (context, snapshot) {
          final products = snapshot.data ?? cachedHomeProducts;
          final harvestThisWeekProducts =
              products.where(isProductHarvestedThisWeek).toList();

          final weeklyHarvestProducts = harvestThisWeekProducts.isNotEmpty
              ? harvestThisWeekProducts
              : products.take(8).toList();

          final cleanRecentlyViewed =
              cleanRecentlyViewedProducts(widget.recentlyViewedProducts);

          return FutureBuilder<List<Product>>(
            future: buyAgainProductsFuture,
            builder: (context, buyAgainSnapshot) {
              final rawBuyAgainProducts =
                  buyAgainSnapshot.data ?? const <Product>[];
              final buyAgainProducts =
                  uniqueVisibleProducts(rawBuyAgainProducts, limit: 10);
              final showBuyAgain = buyAgainProducts.isNotEmpty &&
                  !areSameProductLists(buyAgainProducts, cleanRecentlyViewed);
              final showRecentlyViewed = cleanRecentlyViewed.isNotEmpty;
              final recommendedProducts = buildRecommendedForYouProducts(
                allProducts: products,
                recentlyViewedProducts: cleanRecentlyViewed,
                buyAgainProducts: buyAgainProducts,
                favoriteProducts: widget.favoriteProducts,
              );

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  PersonalizedHomeHeader(
                    profileFuture: customerProfileFuture,
                    loyaltyFuture: loyaltySummaryFuture,
                    onCartTap: widget.onCartTap,
                    cartItemCount: widget.cartItemCount,
                  ),
                  const SizedBox(height: 14),
                  PersonalizedLoyaltyCard(
                    loyaltyFuture: loyaltySummaryFuture,
                  ),
                  const SizedBox(height: 14),
                  PersonalizedHomeHeroLoader(
                    profileFuture: customerProfileFuture,
                    loyaltyFuture: loyaltySummaryFuture,
                    allProducts: products,
                    buyAgainProducts: buyAgainProducts,
                    favoriteProducts: widget.favoriteProducts,
                    recentlyViewedProducts: cleanRecentlyViewed,
                    onShopTap: widget.onShopTap,
                  ),
                  const SizedBox(height: 14),
                  PersonalizedPromotionCard(
                    profileFuture: customerProfileFuture,
                    loyaltyFuture: loyaltySummaryFuture,
                    buyAgainProducts: buyAgainProducts,
                    recommendedProducts: recommendedProducts,
                    onShopTap: widget.onShopTap,
                  ),
                  if (!snapshot.hasError && recommendedProducts.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(
                      title: 'Recommended For You',
                      subtitle: 'Fresh picks selected for your basket',
                      actionLabel: 'See all',
                      onAction: widget.onShopTap,
                    ),
                    const SizedBox(height: 12),
                    ProductMiniRail(
                      products: recommendedProducts,
                      onProductTap: openProduct,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DealOfTheDaySection(
                    onViewed: widget.onViewed,
                    onAddProduct: widget.onAddToCart,
                  ),
                  ReadySoonHomeSection(onViewed: widget.onViewed),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Vegan Ingredient Book'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VeganIngredientBookScreen(
                                  onShopTap: widget.onShopTap,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SectionTitle('Recently Harvested'),
                      ),
                      TextButton(
                        onPressed: widget.onShopTap,
                        child: const Text('Shop all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  snapshot.connectionState == ConnectionState.waiting
                      ? loadingRail()
                      : productRail(
                          products: weeklyHarvestProducts, maxItems: 8),
                  if (showBuyAgain) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Buy Again',
                      subtitle: 'Items from your past orders',
                      actionLabel: 'View shop',
                      onAction: widget.onShopTap,
                    ),
                    const SizedBox(height: 12),
                    buyAgainSnapshot.connectionState == ConnectionState.waiting
                        ? loadingRail()
                        : productRail(products: buyAgainProducts, maxItems: 8),
                  ],
                  if (buyAgainProducts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      title:
                          'Because You Bought ${buyAgainProducts.first.name}',
                      subtitle: 'Helpful pairings for your next farm box',
                      actionLabel: 'Shop',
                      onAction: widget.onShopTap,
                    ),
                    const SizedBox(height: 12),
                    ProductMiniRail(
                      products: buildFrequentlyBoughtTogetherProducts(
                        product: buyAgainProducts.first,
                        products: products,
                      ),
                      onProductTap: openProduct,
                    ),
                  ],
                  if (showRecentlyViewed) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Recently Viewed',
                      subtitle: 'Items you looked at recently',
                      actionLabel: 'Shop',
                      onAction: widget.onShopTap,
                    ),
                    const SizedBox(height: 12),
                    ProductMiniRail(
                      products: cleanRecentlyViewed,
                      onProductTap: openProduct,
                    ),
                  ],
                  if (widget.favoriteProducts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: SectionTitle('Favorites')),
                        TextButton(
                          onPressed: widget.onShopTap,
                          child: const Text('View'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProductMiniRail(
                      products: widget.favoriteProducts,
                      onTap: widget.onShopTap,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const SectionTitle('Popular Categories'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      CategoryPill(icon: '', label: 'Vegetables'),
                      CategoryPill(icon: '', label: 'Fruits'),
                      CategoryPill(icon: '', label: 'Eggs'),
                      CategoryPill(icon: '', label: 'Herbs'),
                      CategoryPill(icon: '', label: 'Honey'),
                    ]
                        .map(
                          (pill) => InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: widget.onShopTap,
                            child: pill,
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class VeganIngredient {
  final String name;
  final String emoji;
  final String category;
  final String description;
  final String benefits;
  final String cookingUses;
  final String storageTips;
  final List<String> keywords;

  const VeganIngredient({
    required this.name,
    required this.emoji,
    required this.category,
    required this.description,
    required this.benefits,
    required this.cookingUses,
    required this.storageTips,
    required this.keywords,
  });
}

const List<VeganIngredient> veganIngredients = [
  VeganIngredient(
    name: 'Callaloo',
    emoji: '🌿',
    category: 'Leafy Greens',
    description:
        'A Jamaican leafy green that works beautifully in soups, sautés, patties, and breakfast bowls.',
    benefits:
        'Rich in plant-based iron, fiber, vitamin A, vitamin C, and minerals that support everyday wellness.',
    cookingUses:
        'Steam lightly, sauté with garlic and onion, add to rice bowls, or mix into vegan patties and wraps.',
    storageTips:
        'Keep leaves dry in a breathable bag in the refrigerator and use within 3–5 days for best freshness.',
    keywords: ['callaloo', 'greens', 'vegetables', 'leafy'],
  ),
  VeganIngredient(
    name: 'Lettuce',
    emoji: '🥬',
    category: 'Salad Greens',
    description:
        'A crisp, hydrating base for salads, wraps, sandwiches, and light plant-based meals.',
    benefits:
        'Low calorie, hydrating, and useful for adding volume, crunch, and freshness to meals.',
    cookingUses:
        'Use raw in salads, wraps, tacos, veggie bowls, or as a fresh side with herbs and citrus.',
    storageTips:
        'Store chilled with a paper towel to absorb moisture and keep leaves crisp.',
    keywords: ['lettuce', 'salad', 'greens', 'vegetables'],
  ),
  VeganIngredient(
    name: 'Sweet Corn',
    emoji: '🌽',
    category: 'Whole Food Carbs',
    description:
        'Naturally sweet, filling, and great for hearty vegan bowls, soups, and side dishes.',
    benefits:
        'Provides fiber, natural carbohydrates, and antioxidants that help make meals satisfying.',
    cookingUses:
        'Boil, grill, roast, add to soups, mix into salsa, or pair with beans and peppers.',
    storageTips:
        'Keep husks on until cooking and refrigerate for best sweetness.',
    keywords: ['corn', 'sweet corn', 'vegetables'],
  ),
  VeganIngredient(
    name: 'Okra',
    emoji: '🥒',
    category: 'Vegetables',
    description:
        'A tender pod vegetable often used in stews, soups, and Caribbean-inspired vegan meals.',
    benefits:
        'Contains fiber and plant nutrients that support digestion and help thicken dishes naturally.',
    cookingUses:
        'Add to stews, roast with spices, sauté quickly, or use in soups and vegetable medleys.',
    storageTips:
        'Keep dry in the refrigerator and use within a few days to avoid softness.',
    keywords: ['okra', 'vegetables'],
  ),
  VeganIngredient(
    name: 'Pumpkin',
    emoji: '🎃',
    category: 'Squash',
    description:
        'A hearty, naturally sweet ingredient for soups, stews, curries, and vegan baking.',
    benefits:
        'High in beta carotene, fiber, and slow-digesting carbohydrates for filling plant-based meals.',
    cookingUses:
        'Roast, boil into soup, mash into porridge, add to curry, or blend into sauces.',
    storageTips:
        'Store whole pumpkin in a cool dry place; refrigerate cut pieces in a sealed container.',
    keywords: ['pumpkin', 'squash', 'vegetables'],
  ),
  VeganIngredient(
    name: 'Bell Pepper',
    emoji: '🫑',
    category: 'Color Vegetables',
    description:
        'A colorful vegetable that adds sweetness, crunch, and freshness to vegan dishes.',
    benefits:
        'Excellent source of vitamin C and antioxidants with bright flavor and natural color.',
    cookingUses:
        'Slice into salads, stir-fries, wraps, roasted trays, pasta, or stuffed pepper meals.',
    storageTips:
        'Refrigerate whole peppers and keep cut pieces sealed for freshness.',
    keywords: ['pepper', 'bell pepper', 'vegetables'],
  ),
  VeganIngredient(
    name: 'Fresh Herbs',
    emoji: '🌱',
    category: 'Herbs',
    description:
        'Herbs add flavor without relying on heavy sauces, salt, or processed seasonings.',
    benefits:
        'Adds antioxidants, aroma, and depth to simple plant-based meals.',
    cookingUses:
        'Use in marinades, salads, soups, dressings, teas, sauces, and finishing oils.',
    storageTips:
        'Wrap gently in a damp towel or stand stems in water and refrigerate.',
    keywords: ['herbs', 'seasoning', 'fresh herbs'],
  ),
  VeganIngredient(
    name: 'Fruit',
    emoji: '🍎',
    category: 'Fruit',
    description:
        'Fresh fruit is perfect for snacks, smoothies, breakfast bowls, and naturally sweet desserts.',
    benefits:
        'Provides fiber, hydration, vitamins, and natural sweetness for everyday energy.',
    cookingUses:
        'Eat fresh, blend into smoothies, add to oats, bake, or pair with nuts and seeds.',
    storageTips:
        'Store ripe fruit chilled and keep ethylene-producing fruit separate when needed.',
    keywords: ['fruit', 'fruits', 'apple', 'smoothie'],
  ),
];

class VeganIngredientBookScreen extends StatefulWidget {
  final VoidCallback onShopTap;

  const VeganIngredientBookScreen({
    super.key,
    required this.onShopTap,
  });

  @override
  State<VeganIngredientBookScreen> createState() =>
      _VeganIngredientBookScreenState();
}

class _VeganIngredientBookScreenState extends State<VeganIngredientBookScreen> {
  final searchController = TextEditingController();
  String selectedCategory = 'All';

  List<String> get categories {
    return ['All', ...veganIngredients.map((item) => item.category).toSet()];
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<VeganIngredient> get filteredIngredients {
    final query = searchController.text.trim().toLowerCase();
    return veganIngredients.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;
      final text =
          '${item.name} ${item.category} ${item.description} ${item.benefits} ${item.keywords.join(' ')}'
              .toLowerCase();
      final matchesSearch = query.isEmpty || text.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredIngredients;

    return Scaffold(
      backgroundColor: FarmColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: Header(
                    title: 'Vegan Ingredient Book',
                    subtitle: 'Benefits, cooking ideas & farm-fresh guidance',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F6B2A), Color(0xFF4B9B45)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: FarmColors.green.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Text('🥗', style: TextStyle(fontSize: 54)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plant-powered learning',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Discover how to cook, store, and shop fresh vegan ingredients from the farm.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FarmCard(
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search ingredients, benefits, or uses...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                searchController.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: FarmColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final selected = selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => selectedCategory = category),
                          selectedColor: FarmColors.green,
                          backgroundColor: FarmColors.lightGreen,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : FarmColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected
                                  ? FarmColors.green
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const FarmEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No ingredients found',
                message: 'Try another search or category.',
              )
            else
              ...items.map((ingredient) {
                return VeganIngredientCard(
                  ingredient: ingredient,
                  onShopTap: widget.onShopTap,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class VeganIngredientCard extends StatelessWidget {
  final VeganIngredient ingredient;
  final VoidCallback onShopTap;

  const VeganIngredientCard({
    super.key,
    required this.ingredient,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  color: FarmColors.lightGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(ingredient.emoji,
                      style: const TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(ingredient.category),
                      backgroundColor: FarmColors.lightGreen,
                      labelStyle: const TextStyle(color: FarmColors.green),
                    ),
                    const SizedBox(height: 4),
                    Text(ingredient.description),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IngredientInfoRow(
            icon: Icons.favorite_outline,
            title: 'Health benefits',
            body: ingredient.benefits,
          ),
          IngredientInfoRow(
            icon: Icons.restaurant_menu_outlined,
            title: 'Cooking uses',
            body: ingredient.cookingUses,
          ),
          IngredientInfoRow(
            icon: Icons.inventory_2_outlined,
            title: 'Storage tips',
            body: ingredient.storageTips,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredient.keywords.map((keyword) {
              return Chip(
                label: Text(keyword),
                backgroundColor: Colors.white,
                side: BorderSide(color: FarmColors.border),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onShopTap();
              },
              icon: const Icon(Icons.storefront_outlined),
              label: Text('Shop related ${ingredient.name} products'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IngredientInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const IngredientInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FarmColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShopScreen extends StatefulWidget {
  final void Function(Product product) onAddToCart;
  final void Function(Product product) onRemoveFromCart;
  final int Function(Product product) quantityForProduct;
  final bool Function(Product product) isFavorite;
  final void Function(Product product) onToggleFavorite;
  final void Function(Product product) onViewed;
  final List<Product> recentlyViewedProducts;

  const ShopScreen({
    super.key,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.quantityForProduct,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onViewed,
    this.recentlyViewedProducts = const [],
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final searchController = TextEditingController();
  String selectedCategory = 'All';
  List<Product> products = fallbackProducts;
  List<Product> readySoonProducts = const [];
  List<Product> buyAgainProducts = const [];
  bool loadingProducts = true;
  String? productLoadMessage;
  Timer? searchDebounce;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      searchDebounce?.cancel();
      searchDebounce = Timer(AppPerformanceConfig.debounce, () {
        if (mounted) setState(() {});
      });
    });
    loadProducts();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    if (!mounted) return;

    setState(() {
      loadingProducts = true;
      productLoadMessage = null;
    });

    try {
      final results = await Future.wait<List<Product>>([
        fetchProducts(forceRefresh: true),
        fetchReadySoonProducts(forceRefresh: true),
        fetchBuyAgainProducts(forceRefresh: true),
      ]);
      final fetchedProducts = results[0];
      final fetchedReadySoon = results[1];
      final fetchedBuyAgain = results[2];
      final cleanProducts = fetchedProducts.where((product) {
        return product.name.trim().isNotEmpty && product.price >= 0;
      }).toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      final cleanReadySoon = fetchedReadySoon.where((product) {
        return product.name.trim().isNotEmpty;
      }).toList();

      if (!mounted) return;
      setState(() {
        products = cleanProducts.isEmpty ? fallbackProducts : cleanProducts;
        readySoonProducts = cleanReadySoon;
        buyAgainProducts = uniqueVisibleProducts(fetchedBuyAgain, limit: 10);
        loadingProducts = false;
      });
    } catch (error) {
      debugPrint('Shop product load failed: $error');
      if (!mounted) return;
      setState(() {
        products = fallbackProducts;
        loadingProducts = false;
        productLoadMessage =
            'Using sample products while the shop refreshes. Pull refresh to try again.';
      });
    }
  }

  List<String> get categories {
    final values = <String>{'All'};

    for (final product in products) {
      final category = product.category.trim();
      if (category.isNotEmpty) values.add(category);
    }

    final list = values.toList();
    list.sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    return list;
  }

  List<Product> filteredProducts(String activeCategory) {
    final query = searchController.text.trim().toLowerCase();
    final activeCategoryLower = activeCategory.toLowerCase();

    return products.where((product) {
      final category = product.category.trim().toLowerCase();
      final name = product.name.trim().toLowerCase();
      final description = (product.description ?? '').trim().toLowerCase();
      final unit = (product.unit ?? '').trim().toLowerCase();

      final matchesCategory = activeCategory == 'All' ||
          category == activeCategoryLower ||
          name.contains(activeCategoryLower);

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          category.contains(query) ||
          description.contains(query) ||
          unit.contains(query);

      // When the customer types in the search box, search the whole shop.
      // This prevents a selected category chip from hiding valid search results.
      if (query.isNotEmpty) return matchesSearch;

      return matchesCategory;
    }).toList();
  }

  Widget _buildStickySearchAndFilters(
    List<String> availableCategories,
    String activeCategory,
  ) {
    return Container(
      color: FarmColors.background,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FarmColors.line.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: FarmColors.shadow.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                if (mounted) setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search fresh produce...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: searchController.clear,
                      ),
                filled: true,
                fillColor: FarmColors.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = availableCategories[index];
                  final selected = activeCategory == category;

                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => selectedCategory = category);
                    },
                    selectedColor: FarmColors.green,
                    backgroundColor: FarmColors.lightGreen,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : FarmColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: selected ? FarmColors.green : Colors.transparent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableCategories = categories;
    final activeCategory = availableCategories.contains(selectedCategory)
        ? selectedCategory
        : 'All';
    final visibleProducts = filteredProducts(activeCategory);
    final cleanRecentlyViewed =
        cleanRecentlyViewedProducts(widget.recentlyViewedProducts);
    final favoriteProducts =
        products.where((product) => widget.isFavorite(product)).toList();
    final availableNowProducts = sortProductsForPersonalization(
      products: visibleProducts
          .where((product) => isVisibleCustomerProduct(product))
          .toList(),
      recentlyViewedProducts: cleanRecentlyViewed,
      buyAgainProducts: buyAgainProducts,
      favoriteProducts: favoriteProducts,
    );
    final suggestedForYouProducts = buildRecommendedForYouProducts(
      allProducts: products,
      recentlyViewedProducts: cleanRecentlyViewed,
      buyAgainProducts: buyAgainProducts,
      favoriteProducts: favoriteProducts,
      selectedCategory: activeCategory,
    );

    final contentSections = <Widget>[
      if (!loadingProducts && suggestedForYouProducts.isNotEmpty) ...[
        SectionHeader(
          title: 'Suggested for You',
          subtitle: 'Personalized using your views, favorites, and orders',
        ),
        const SizedBox(height: 12),
        ProductMiniRail(
          products: suggestedForYouProducts,
          onProductTap: (product) {
            widget.onViewed(product);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: product,
                  quantity: widget.quantityForProduct(product),
                  onAdd: () => widget.onAddToCart(product),
                  onRemove: () => widget.onRemoveFromCart(product),
                  onAddProduct: widget.onAddToCart,
                  onViewed: widget.onViewed,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
      ],
      if (!loadingProducts) ...[
        DealOfTheDaySection(
          onViewed: widget.onViewed,
          onAddProduct: widget.onAddToCart,
          compact: true,
        ),
        const SizedBox(height: 18),
      ],
      if (!loadingProducts && availableNowProducts.isNotEmpty) ...[
        const SectionHeader(
          title: 'Availability',
          subtitle: 'Fresh items currently ready for your box',
        ),
        const SizedBox(height: 12),
      ],
      if (productLoadMessage != null) ...[
        FarmCard(
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: FarmColors.green),
              const SizedBox(width: 10),
              Expanded(child: Text(productLoadMessage!)),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (loadingProducts) ...[
        const FarmSkeletonCard(height: 180),
        const FarmSkeletonCard(height: 180),
        const FarmSkeletonCard(height: 180),
      ] else if (availableNowProducts.isEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: FarmCard(
            child: Column(
              children: [
                const Icon(
                  Icons.eco_outlined,
                  size: 42,
                  color: FarmColors.green,
                ),
                const SizedBox(height: 10),
                Text(
                  activeCategory == 'All'
                      ? 'No products match your search.'
                      : 'No items are currently available in $activeCategory. Try another category or refresh the shop.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ] else ...[
        ...availableNowProducts.map((product) {
          final quantity = widget.quantityForProduct(product);

          return SafeShopProductTile(
            key: ValueKey('shop-${product.id}-${product.name}'),
            product: product,
            quantity: quantity,
            isFavorite: widget.isFavorite(product),
            onFavorite: () => widget.onToggleFavorite(product),
            onAdd: () => widget.onAddToCart(product),
            onRemove: () => widget.onRemoveFromCart(product),
            onOpenDetails: () {
              widget.onViewed(product);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    product: product,
                    quantity: quantity,
                    onAdd: () => widget.onAddToCart(product),
                    onRemove: () => widget.onRemoveFromCart(product),
                    onAddProduct: widget.onAddToCart,
                    onViewed: widget.onViewed,
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 90),
      ],
    ];

    return FarmPage(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Header(
                    title: 'Shop',
                    subtitle: 'Fresh natural produce',
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh shop',
                  onPressed: loadProducts,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          _buildStickySearchAndFilters(
            availableCategories,
            activeCategory,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadProducts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                children: contentSections,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopSearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  const _ShopSearchHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: FarmColors.background,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: FarmColors.shadow.withOpacity(0.14),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ShopSearchHeaderDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        child != oldDelegate.child;
  }
}

class _FreshnessChip extends StatelessWidget {
  const _FreshnessChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Freshness guaranteed',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SafeShopProductTile extends StatelessWidget {
  final Product product;
  final int quantity;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onOpenDetails;

  const SafeShopProductTile({
    super.key,
    required this.product,
    required this.quantity,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAdd,
    required this.onRemove,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final name = product.name.trim().isEmpty ? 'Product' : product.name.trim();
    final description = (product.description ?? '').trim().isEmpty
        ? 'Fresh natural harvest from the farm.'
        : product.description!.trim();
    final category =
        product.category.trim().isEmpty ? 'Fresh Produce' : product.category;
    final unit = (product.unit ?? '').trim();
    final inStock = product.canAddToCart;

    return FarmCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductVisual(product: product, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onFavorite,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? FarmColors.danger
                                : FarmColors.green,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FarmColors.mutedText,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallShopChip(label: category),
                        if (product.isOrganic)
                          const _SmallShopChip(label: 'Organic'),
                        _SmallShopChip(
                          label:
                              '${product.stockQuantity < 0 ? 0 : product.stockQuantity} in stock',
                        ),
                        if (product.isLowStock)
                          _SmallShopChip(label: product.lowStockLabel),
                        if (unit.isNotEmpty) _SmallShopChip(label: unit),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DiscountPriceText(
                              product: product, compact: true),
                        ),
                        if (quantity <= 0)
                          SizedBox(
                            width: 150,
                            child: inStock
                                ? ElevatedButton.icon(
                                    onPressed: onAdd,
                                    icon: const Icon(Icons.add, size: 17),
                                    label: const Text('Add'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  )
                                : NotifyMeWhenReadyButton(
                                    product: product, compact: true),
                          )
                        else
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: FarmColors.lightGreen,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onRemove,
                                  icon: const Icon(Icons.remove),
                                  color: FarmColors.green,
                                ),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: FarmColors.green,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: inStock ? onAdd : null,
                                  icon: const Icon(Icons.add),
                                  color: FarmColors.green,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallShopChip extends StatelessWidget {
  final String label;

  const _SmallShopChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FarmColors.lightGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FarmColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<Product> buildRecommendedForYouProducts({
  required List<Product> allProducts,
  required List<Product> recentlyViewedProducts,
  required List<Product> buyAgainProducts,
  required List<Product> favoriteProducts,
  String selectedCategory = 'All',
  Set<String> excludeIds = const {},
}) {
  final visibleProducts = uniqueVisibleProducts(allProducts, limit: 500);
  final excludedIds = <String>{
    ...excludeIds,
    ...recentlyViewedProducts.map((product) => product.id),
    ...buyAgainProducts.map((product) => product.id),
  };
  final seen = <String>{};
  final output = <Product>[];

  void add(Product product) {
    if (output.length >= 8) return;
    if (!isVisibleCustomerProduct(product)) return;
    if (excludedIds.contains(product.id)) return;
    if (!seen.add(product.id)) return;
    output.add(product);
  }

  final signalCategories = <String>{
    ...recentlyViewedProducts.map((product) => product.category.toLowerCase()),
    ...favoriteProducts.map((product) => product.category.toLowerCase()),
    ...buyAgainProducts.map((product) => product.category.toLowerCase()),
  }..removeWhere((category) => category.trim().isEmpty);

  for (final product in visibleProducts) {
    if (product.showAsDealOfDay || product.hasActiveDiscount) add(product);
  }

  for (final product in visibleProducts) {
    if (signalCategories.contains(product.category.toLowerCase())) add(product);
  }

  if (selectedCategory != 'All') {
    final selected = selectedCategory.toLowerCase();
    for (final product in visibleProducts) {
      if (product.category.toLowerCase() == selected ||
          product.name.toLowerCase().contains(selected)) {
        add(product);
      }
    }
  }

  for (final product in visibleProducts) {
    if (isProductHarvestedThisWeek(product) || product.isLowStock) add(product);
  }

  for (final product in visibleProducts) {
    add(product);
  }

  return output;
}

List<Product> buildSmartRecommendations({
  required List<Product> products,
  required List<Product> recentlyViewed,
  required String selectedCategory,
}) {
  return buildRecommendedForYouProducts(
    allProducts: products,
    recentlyViewedProducts: recentlyViewed,
    buyAgainProducts: const [],
    favoriteProducts: const [],
    selectedCategory: selectedCategory,
  );
}

class ProductMiniRail extends StatelessWidget {
  final List<Product> products;
  final VoidCallback? onTap;
  final void Function(Product product)? onProductTap;

  const ProductMiniRail({
    super.key,
    required this.products,
    this.onTap,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final visible = products.take(8).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        cacheExtent: AppPerformanceConfig.productRailCacheExtent,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = visible[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (onProductTap != null) {
                onProductTap!(product);
              } else {
                onTap?.call();
              }
            },
            child: Container(
              width: 118,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: FarmColors.shadow.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ProductVisual(product: product, size: 34),
                  const Spacer(),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      color: FarmColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FarmBoxScreen extends StatelessWidget {
  final List<Product> cart;
  final void Function(Product product) onRemoveFromCart;
  final VoidCallback onOrderPlaced;

  const FarmBoxScreen({
    super.key,
    required this.cart,
    required this.onRemoveFromCart,
    required this.onOrderPlaced,
  });

  Map<String, CartLine> get groupedCart {
    final grouped = <String, CartLine>{};

    for (final product in cart) {
      if (grouped.containsKey(product.id)) {
        grouped[product.id] = grouped[product.id]!.copyWith(
          quantity: grouped[product.id]!.quantity + 1,
        );
      } else {
        grouped[product.id] = CartLine(product: product, quantity: 1);
      }
    }

    return grouped;
  }

  double get subtotal {
    return groupedCart.values.fold(
      0,
      (total, line) => total + (line.product.effectivePrice * line.quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = groupedCart.values.toList();

    return FarmPage(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Header(
                  title: 'My Farm Box',
                  subtitle: 'Your fresh cart',
                ),
                const SizedBox(height: 16),
                FarmCard(
                  child: Row(
                    children: const [
                      Text('🧺', style: TextStyle(fontSize: 60)),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Tap + in Shop to add produce to your box.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (lines.isEmpty)
                  const FarmCard(
                    child: Text(
                      'Your farm box is empty. Go to Shop and tap + to add fresh produce.',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                else
                  ...lines.map((line) {
                    final product = line.product;
                    return FarmCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          ProductVisual(product: product, size: 38),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                DiscountPriceText(
                                    product: product, compact: true),
                                Text('Quantity: ${line.quantity}'),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => onRemoveFromCart(product),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${line.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FarmColors.green,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${cart.length} items • J\$${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: lines.isEmpty
                      ? null
                      : () async {
                          final allowed =
                              await requireLoginForCheckout(context);
                          if (!context.mounted || !allowed) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                cartLines: lines,
                                subtotal: subtotal,
                                onOrderPlaced: onOrderPlaced,
                              ),
                            ),
                          );
                        },
                  child: const Text('Checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartLine {
  final Product product;
  final int quantity;

  const CartLine({required this.product, required this.quantity});

  CartLine copyWith({Product? product, int? quantity}) {
    return CartLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        FarmDataCache.clearOrders();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const GuestProtectedScreen(
        title: 'My Orders',
        subtitle: 'Track your farm orders',
        message:
            'Sign in to view your orders, receipts, payment status, and delivery tracking.',
      );
    }

    return FarmPage(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Header(title: 'My Orders', subtitle: 'Track your farm orders'),
          const SizedBox(height: 16),
          FutureBuilder<List<FarmOrder>>(
            future: fetchOrders(forceRefresh: true),
            builder: (context, snapshot) {
              final orders = snapshot.data ?? [];

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonList();
              }

              if (orders.isEmpty) {
                return const FarmCard(
                  child: Text('No orders yet.'),
                );
              }

              return Column(
                children: orders.map((order) {
                  return OrderCard(
                    order: '#${order.shortId}',
                    status: _titleCase(order.status),
                    type:
                        '${order.formattedType} • ${order.formattedPaymentMethod} • ${order.formattedPaymentStatus}',
                    total: order.formattedTotal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailsScreen(orderId: order.id),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  int _statusIndex(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'preparing':
        return 1;
      case 'ready':
      case 'ready_for_pickup':
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  Widget _trackingRow({
    required String label,
    required bool active,
    required bool complete,
  }) {
    final icon = complete ? Icons.check_circle : Icons.radio_button_unchecked;
    final color = complete || active ? FarmColors.green : FarmColors.mutedText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const GuestProtectedScreen(
        title: 'Order Details',
        subtitle: 'Private order information',
        message: 'Sign in to view private order details and tracking updates.',
      );
    }

    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: FarmColors.background,
      ),
      body: FutureBuilder<OrderDetails?>(
        future: fetchOrderDetails(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SkeletonList();
          }

          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Order details not found.'));
          }

          final isDelivery = order.fulfillmentType == 'delivery';

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Header(
                title: 'Receipt',
                subtitle: 'Order #${order.shortId}',
              ),
              const SizedBox(height: 16),
              FarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.formattedOrderStatus,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(order.formattedType),
                    Text('Scheduled: ${order.scheduleText}'),
                    if (isDelivery && (order.deliveryZone ?? '').isNotEmpty)
                      Text('Zone: ${order.deliveryZone}'),
                    if (isDelivery && (order.deliveryAddress ?? '').isNotEmpty)
                      Text('Address: ${order.deliveryAddress}'),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(
                          '${order.formattedPaymentMethod} • ${order.formattedPaymentStatus}'),
                      backgroundColor: FarmColors.lightGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumOrderTracker(
                status: order.status,
                isDelivery: isDelivery,
                paymentStatus: order.paymentStatus,
              ),
              const SizedBox(height: 14),
              FarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (order.items.isEmpty)
                      const Text('No item details found.')
                    else
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} x ${item.quantity}',
                                ),
                              ),
                              Text('J\$${item.lineTotal.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(order.formattedSubtotal),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery fee'),
                        Text(order.formattedDeliveryFee),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          order.formattedTotal,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if ((order.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                FarmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Notes',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(order.notes!),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class PremiumOrderTracker extends StatelessWidget {
  final String status;
  final bool isDelivery;
  final String paymentStatus;

  const PremiumOrderTracker({
    super.key,
    required this.status,
    required this.isDelivery,
    required this.paymentStatus,
  });

  int get currentStep {
    switch (status) {
      case 'pending':
        return 0;
      case 'preparing':
        return 1;
      case 'ready':
      case 'ready_for_pickup':
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  List<String> get labels {
    return [
      'Order received',
      'Preparing fresh items',
      isDelivery ? 'Out for delivery' : 'Ready for pickup',
      isDelivery ? 'Delivered' : 'Completed',
    ];
  }

  List<IconData> get icons {
    return [
      Icons.receipt_long_outlined,
      Icons.shopping_basket_outlined,
      isDelivery ? Icons.local_shipping_outlined : Icons.storefront_outlined,
      Icons.check_circle_outline,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final paid = paymentStatus == 'paid';

    return FarmCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live Order Tracker',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: paid ? FarmColors.lightGreen : FarmColors.warningSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  paid ? 'Paid' : 'Payment pending',
                  style: TextStyle(
                    color: paid ? FarmColors.green : FarmColors.warning,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We update this tracker as your order moves through the farm workflow.',
            style: TextStyle(color: FarmColors.mutedText),
          ),
          const SizedBox(height: 18),
          ...List.generate(labels.length, (index) {
            final complete = index < currentStep;
            final active = index == currentStep;
            final isLast = index == labels.length - 1;

            return _PremiumTrackingStep(
              icon: icons[index],
              title: labels[index],
              subtitle: active
                  ? 'Current step'
                  : complete
                      ? 'Completed'
                      : 'Coming next',
              complete: complete,
              active: active,
              showLine: !isLast,
            );
          }),
        ],
      ),
    );
  }
}

class _PremiumTrackingStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool complete;
  final bool active;
  final bool showLine;

  const _PremiumTrackingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.active,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete || active ? FarmColors.green : FarmColors.muted;
    final background =
        complete || active ? FarmColors.lightGreen : FarmColors.cream;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      complete || active ? FarmColors.green : FarmColors.line,
                  width: active ? 2 : 1,
                ),
              ),
              child: Icon(
                complete ? Icons.check : icon,
                color: color,
                size: 21,
              ),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 34,
                color: complete ? FarmColors.green : FarmColors.line,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                    color: active ? FarmColors.ink : color,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: active ? FarmColors.green : FarmColors.muted,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

class AdminAuditLogsScreen extends StatelessWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: const AdminAuditLogsTab(),
    );
  }
}

class AdminAuditLogsTab extends StatefulWidget {
  final int refreshKey;

  const AdminAuditLogsTab({super.key, this.refreshKey = 0});

  @override
  State<AdminAuditLogsTab> createState() => _AdminAuditLogsTabState();
}

class _AdminAuditLogsTabState extends State<AdminAuditLogsTab> {
  late Future<List<AuditLogEntry>> _future;
  String? _actionFilter;
  String? _tableFilter;

  @override
  void initState() {
    super.initState();
    _future = _loadLogs();
  }

  @override
  void didUpdateWidget(covariant AdminAuditLogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _refresh();
    }
  }

  Future<List<AuditLogEntry>> _loadLogs() {
    return fetchAdminAuditLogs(
      limit: 75,
      action: _actionFilter,
      tableName: _tableFilter,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadLogs();
    });
    await _future;
  }

  void _setFilters({String? action, String? tableName}) {
    setState(() {
      _actionFilter = action;
      _tableFilter = tableName;
      _future = _loadLogs();
    });
  }

  Widget _filterChip({
    required String label,
    String? action,
    String? tableName,
  }) {
    final selected = _actionFilter == action && _tableFilter == tableName;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setFilters(action: action, tableName: tableName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<AuditLogEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Header(
                  title: 'Audit Logs',
                  subtitle: 'Admin activity history',
                ),
                const SizedBox(height: 12),
                FarmCard(
                  child: Text(
                    friendlyAppError(snapshot.error!),
                    style: const TextStyle(
                      color: FarmColors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          }

          final logs = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Header(
                title: 'Audit Logs',
                subtitle: 'Order, product, coupon and admin activity history',
              ),
              const SizedBox(height: 12),
              FarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(label: 'All'),
                        _filterChip(
                          label: 'Orders',
                          tableName: 'orders',
                        ),
                        _filterChip(
                          label: 'Products',
                          tableName: 'products',
                        ),
                        _filterChip(
                          label: 'Product updates',
                          action: 'admin_update_product',
                        ),
                        _filterChip(
                          label: 'Order updates',
                          action: 'admin_update_order',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (logs.isEmpty)
                const FarmCard(
                  child: Text(
                    'No audit logs found yet.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else
                ...logs.map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FarmCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 18,
                                  ),
                                  label: Text(log.formattedAction),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.table_rows_outlined,
                                    size: 18,
                                  ),
                                  label: Text(log.tableName),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Record: ${log.shortRecordId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: FarmColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Actor: ${log.shortActorId}',
                              style: const TextStyle(
                                color: FarmColors.mutedText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatCustomerDateTime(log.createdAt),
                              style: const TextStyle(
                                color: FarmColors.mutedText,
                              ),
                            ),
                            if (log.metadata.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: FarmColors.cardSoft,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: FarmColors.line),
                                ),
                                child: SelectableText(
                                  log.metadata.entries
                                      .map((entry) =>
                                          '${entry.key}: ${entry.value}')
                                      .join('\n'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: FarmColors.mutedText,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onHomeTap;

  const AdminDashboardScreen({super.key, this.onHomeTap});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int refreshKey = 0;

  void refresh() {
    setState(() => refreshKey++);
  }

  void goBackHome() {
    if (widget.onHomeTap != null) {
      widget.onHomeTap!();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isCurrentUserAdminFromDatabase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allowed = snapshot.data == true;

        if (!allowed) {
          return FarmPage(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                Header(title: 'Admin Locked', subtitle: 'Farmer access only'),
                SizedBox(height: 18),
                FarmCard(
                  child: Text(
                    'This area is only available to approved admin users.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }

        return FarmPage(
          child: DefaultTabController(
            length: 11,
            initialIndex: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: Header(
                    title: 'Farmer Admin',
                    subtitle: 'Manage orders, delivery, products & sales',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Back to Home'),
                      onPressed: goBackHome,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: const TabBar(
                    isScrollable: true,
                    labelColor: FarmColors.green,
                    indicatorColor: FarmColors.green,
                    tabs: [
                      Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
                      Tab(
                          icon: Icon(Icons.local_shipping_outlined),
                          text: 'Delivery'),
                      Tab(
                          icon: Icon(Icons.analytics_outlined),
                          text: 'Analytics'),
                      Tab(icon: Icon(Icons.eco), text: 'Products'),
                      Tab(
                          icon: Icon(Icons.support_agent_outlined),
                          text: 'Support'),
                      Tab(
                          icon: Icon(Icons.agriculture_outlined),
                          text: 'Farmers'),
                      Tab(icon: Icon(Icons.payments_outlined), text: 'Payouts'),
                      Tab(
                          icon: Icon(Icons.table_chart_outlined),
                          text: 'Reports'),
                      Tab(
                          icon: Icon(Icons.rate_review_outlined),
                          text: 'Reviews'),
                      Tab(
                          icon: Icon(Icons.confirmation_number_outlined),
                          text: 'Coupons'),
                      Tab(icon: Icon(Icons.fact_check_outlined), text: 'Audit'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      AdminOrdersTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      AdminDeliveryTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      AdminAnalyticsTab(refreshKey: refreshKey),
                      AdminProductsTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      AdminSupportTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      AdminFarmerManagementTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      AdminPayoutsTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          FarmCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reports Export',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Generate CSV or report-ready text for sales records.',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                          Icons.table_chart_outlined),
                                      label: const Text('CSV'),
                                      onPressed: () async {
                                        final orders = await fetchAdminOrders();
                                        final csv = buildSalesCsv(orders);
                                        if (!context.mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('CSV Export'),
                                            content: SingleChildScrollView(
                                              child: SelectableText(csv),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.picture_as_pdf_outlined),
                                      label: const Text('Report'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: FarmColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        final orders = await fetchAdminOrders();
                                        final report =
                                            buildSalesReportText(orders);
                                        if (!context.mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Sales Report'),
                                            content: SingleChildScrollView(
                                              child: SelectableText(report),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AdminReviewsTab(refreshKey: refreshKey),
                      AdminCouponsTab(
                          refreshKey: refreshKey, onChanged: refresh),
                      AdminAuditLogsTab(refreshKey: refreshKey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdminOrdersTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onChanged;

  const AdminOrdersTab({
    super.key,
    required this.refreshKey,
    required this.onChanged,
  });

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  String selectedFilter = 'all';

  static const statuses = [
    'pending',
    'preparing',
    'ready',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  static const paymentStatuses = [
    'unpaid',
    'pending_verification',
    'paid',
    'refunded',
  ];

  String formatStatus(String status) {
    return status
        .split('_')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  List<AdminOrder> applyFilter(List<AdminOrder> orders) {
    switch (selectedFilter) {
      case 'pending':
      case 'preparing':
      case 'ready':
      case 'out_for_delivery':
      case 'delivered':
        return orders.where((order) => order.status == selectedFilter).toList();
      case 'unpaid':
        return orders.where((order) => order.paymentStatus != 'paid').toList();
      case 'paid':
        return orders.where((order) => order.paymentStatus == 'paid').toList();
      default:
        return orders;
    }
  }

  Future<void> changeOrderStatus(
      BuildContext context, AdminOrder order, String status) async {
    try {
      await updateOrderStatus(order.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order updated to ${formatStatus(status)}')),
        );
      }
      widget.onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $error')),
        );
      }
    }
  }

  Future<void> changePaymentStatus(
      BuildContext context, AdminOrder order, String status) async {
    try {
      await updatePaymentStatus(order.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment marked ${formatStatus(status)}')),
        );
      }
      widget.onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update payment: $error')),
        );
      }
    }
  }

  Widget summaryTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FarmColors.green),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminOrder>>(
      key: ValueKey(widget.refreshKey),
      future: fetchAdminOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }

        final orders = snapshot.data ?? [];
        final filteredOrders = applyFilter(orders);
        final paidCount =
            orders.where((order) => order.paymentStatus == 'paid').length;
        final unpaidCount =
            orders.where((order) => order.paymentStatus != 'paid').length;
        final totalSales = orders
            .where((order) => order.paymentStatus == 'paid')
            .fold<double>(0, (sum, order) => sum + order.total);

        if (orders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: FarmCard(
              child: Text('No orders found yet.'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today / Recent Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      summaryTile(
                          'Orders', '${orders.length}', Icons.receipt_long),
                      const SizedBox(width: 8),
                      summaryTile(
                          'Unpaid', '$unpaidCount', Icons.pending_actions),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      summaryTile('Paid', '$paidCount', Icons.verified),
                      const SizedBox(width: 8),
                      summaryTile(
                          'Paid Sales',
                          'J\$${totalSales.toStringAsFixed(0)}',
                          Icons.payments),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    selected: selectedFilter == 'all',
                    label: const Text('All'),
                    onSelected: (_) => setState(() => selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ...[
                    'pending',
                    'preparing',
                    'ready',
                    'out_for_delivery',
                    'delivered',
                    'unpaid',
                    'paid'
                  ].map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selectedFilter == filter,
                        label: Text(formatStatus(filter)),
                        onSelected: (_) =>
                            setState(() => selectedFilter = filter),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (filteredOrders.isEmpty)
              const FarmCard(child: Text('No orders match this filter.'))
            else
              ...filteredOrders.map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FarmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${order.shortId}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Chip(
                                label: Text(formatStatus(order.status)),
                                backgroundColor: FarmColors.lightGreen,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(order.formattedType,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              '${order.formattedPaymentMethod} • ${order.formattedPaymentStatus}'),
                          if (order.paymentMethod == 'bank_transfer' &&
                              (order.bankReference ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Bank reference: ${order.bankReference}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                              '${order.customerName} • ${order.customerPhone}'),
                          if (order.customerAddress.isNotEmpty)
                            Text(order.customerAddress),
                          const SizedBox(height: 10),
                          if (order.items.isEmpty)
                            const Text('No item details found.')
                          else
                            ...order.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text(
                                            '${item.productName} x ${item.quantity}')),
                                    Text(
                                        'J\$${item.lineTotal.toStringAsFixed(2)}'),
                                  ],
                                ),
                              ),
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(order.formattedTotal,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (order.status != 'preparing')
                                ActionChip(
                                  avatar: const Icon(Icons.restaurant_menu,
                                      size: 18),
                                  label: const Text('Preparing'),
                                  onPressed: () => changeOrderStatus(
                                      context, order, 'preparing'),
                                ),
                              if (order.status != 'ready')
                                ActionChip(
                                  avatar: const Icon(Icons.check_circle_outline,
                                      size: 18),
                                  label: const Text('Ready'),
                                  onPressed: () => changeOrderStatus(
                                      context, order, 'ready'),
                                ),
                              if (order.status != 'delivered')
                                ActionChip(
                                  avatar: const Icon(Icons.done_all, size: 18),
                                  label: const Text('Delivered'),
                                  onPressed: () => changeOrderStatus(
                                      context, order, 'delivered'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (order.paymentStatus != 'paid')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.verified),
                                label: const Text('Mark Paid'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FarmColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  try {
                                    await markOrderPaid(order.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Payment verified')),
                                      );
                                    }
                                    widget.onChanged();
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Could not verify payment: $error')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: statuses.contains(order.status)
                                ? order.status
                                : 'pending',
                            decoration: const InputDecoration(
                                labelText: 'Update status'),
                            items: statuses
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(formatStatus(status)),
                                    ))
                                .toList(),
                            onChanged: (status) {
                              if (status != null)
                                changeOrderStatus(context, order, status);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: paymentStatuses.contains(order.paymentStatus)
                                ? order.paymentStatus
                                : 'unpaid',
                            decoration: const InputDecoration(
                                labelText: 'Payment status'),
                            items: paymentStatuses
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(formatStatus(status)),
                                    ))
                                .toList(),
                            onChanged: (status) {
                              if (status != null)
                                changePaymentStatus(context, order, status);
                            },
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class AdminAnalyticsTab extends StatelessWidget {
  final int refreshKey;

  const AdminAnalyticsTab({super.key, required this.refreshKey});

  String formatMoney(double value) => 'J\$${value.toStringAsFixed(2)}';

  Widget statCard(String title, String value, IconData icon, {Color? color}) {
    final activeColor = color ?? FarmColors.green;

    return Expanded(
      child: FarmCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: activeColor.withOpacity(0.12),
              foregroundColor: activeColor,
              child: Icon(icon),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget miniListCard({
    required String title,
    required List<Widget> children,
    String emptyText = 'Nothing to show yet.',
  }) {
    return FarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (children.isEmpty) Text(emptyText) else ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey('analytics-$refreshKey'),
      future: Future.wait([
        fetchAdminOrders(),
        fetchAllProducts(),
        fetchFarmerProfiles(),
        fetchFarmerPayouts(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }

        final orders = snapshot.data == null
            ? <AdminOrder>[]
            : List<AdminOrder>.from(snapshot.data![0] as List);
        final products = snapshot.data == null
            ? <Product>[]
            : List<Product>.from(snapshot.data![1] as List);
        final farmers = snapshot.data == null
            ? <FarmerProfile>[]
            : List<FarmerProfile>.from(snapshot.data![2] as List);
        final payouts = snapshot.data == null
            ? <FarmerPayout>[]
            : List<FarmerPayout>.from(snapshot.data![3] as List);

        final paidOrders =
            orders.where((order) => order.paymentStatus == 'paid').toList();
        final pendingOrders =
            orders.where((order) => order.status == 'pending').toList();
        final preparingOrders =
            orders.where((order) => order.status == 'preparing').toList();
        final unpaidOrders =
            orders.where((order) => order.paymentStatus != 'paid').toList();
        final totalSales =
            paidOrders.fold<double>(0, (sum, order) => sum + order.total);
        final unpaidAmount =
            unpaidOrders.fold<double>(0, (sum, order) => sum + order.total);
        final avgOrder = orders.isEmpty
            ? 0.0
            : orders.fold<double>(0, (sum, order) => sum + order.total) /
                orders.length;
        final lowStock = products
            .where(
                (product) => product.isAvailable && product.stockQuantity <= 5)
            .toList();
        final pendingProducts = products
            .where((product) => product.approvalStatus == 'pending')
            .toList();
        final approvedFarmers = farmers
            .where((farmer) => farmer.verificationStatus == 'approved')
            .length;
        final pendingFarmers = farmers
            .where((farmer) => farmer.verificationStatus == 'pending')
            .length;
        final pendingPayouts = payouts
            .where((payout) => payout.payoutStatus == 'pending')
            .toList();
        final payoutAmount = pendingPayouts.fold<double>(
            0, (sum, payout) => sum + payout.netAmount);

        final itemSales = <String, int>{};
        for (final order in orders) {
          for (final item in order.items) {
            itemSales[item.productName] =
                (itemSales[item.productName] ?? 0) + item.quantity;
          }
        }

        final bestSellers = itemSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Header(
              title: 'Elite Admin Dashboard',
              subtitle: 'Revenue, orders, stock, farmers and payouts',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                statCard(
                    'Paid Revenue', formatMoney(totalSales), Icons.payments),
                const SizedBox(width: 10),
                statCard('Orders', '${orders.length}', Icons.receipt_long),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                statCard('Avg Order', formatMoney(avgOrder), Icons.trending_up),
                const SizedBox(width: 10),
                statCard(
                  'Unpaid',
                  formatMoney(unpaidAmount),
                  Icons.pending_actions,
                  color: FarmColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                statCard('Pending Orders', '${pendingOrders.length}',
                    Icons.hourglass_top),
                const SizedBox(width: 10),
                statCard('Preparing', '${preparingOrders.length}',
                    Icons.restaurant_menu),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                statCard('Approved Farmers', '$approvedFarmers',
                    Icons.verified_user_outlined),
                const SizedBox(width: 10),
                statCard(
                  'Pending Farmers',
                  '$pendingFarmers',
                  Icons.agriculture_outlined,
                  color: FarmColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                statCard(
                  'Pending Products',
                  '${pendingProducts.length}',
                  Icons.inventory_2_outlined,
                  color: FarmColors.gold,
                ),
                const SizedBox(width: 10),
                statCard(
                  'Payouts Due',
                  formatMoney(payoutAmount),
                  Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            miniListCard(
              title: 'Low Stock Alerts',
              children: lowStock.take(6).map((product) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProductVisual(product: product, size: 28),
                  title: Text(product.name),
                  subtitle: Text('Stock: ${product.stockQuantity}'),
                  trailing:
                      const Icon(Icons.warning_amber, color: FarmColors.gold),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            miniListCard(
              title: 'Best Sellers',
              children: bestSellers.take(6).map((entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.trending_up, color: FarmColors.green),
                  title: Text(entry.key),
                  trailing: Text('${entry.value} sold'),
                );
              }).toList(),
              emptyText: 'No sales data yet.',
            ),
            const SizedBox(height: 16),
            miniListCard(
              title: 'Pending Product Approvals',
              children: pendingProducts.take(6).map((product) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProductVisual(product: product, size: 28),
                  title: Text(product.name),
                  subtitle: Text(product.category),
                  trailing: const Icon(Icons.approval_outlined),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class AdminDeliveryTab extends StatelessWidget {
  final int refreshKey;
  final VoidCallback onChanged;

  const AdminDeliveryTab({
    super.key,
    required this.refreshKey,
    required this.onChanged,
  });

  static const deliveryStatuses = [
    'pending',
    'preparing',
    'ready_for_pickup',
    'out_for_delivery',
    'delivered',
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminOrder>>(
      key: ValueKey('delivery-$refreshKey'),
      future: fetchAdminOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }

        final orders = (snapshot.data ?? [])
            .where((order) => order.status != 'cancelled')
            .toList();
        final deliveryOrders = orders
            .where((order) => order.fulfillmentType == 'delivery')
            .toList();
        final pickupOrders = orders
            .where((order) => order.fulfillmentType != 'delivery')
            .toList();

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Header(
              title: 'Delivery',
              subtitle: 'Pickup and delivery workflow',
            ),
            const SizedBox(height: 16),
            FarmCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.local_shipping_outlined,
                            color: FarmColors.green),
                        const SizedBox(height: 8),
                        Text('${deliveryOrders.length}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const Text('Delivery orders'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.store_mall_directory_outlined,
                            color: FarmColors.green),
                        const SizedBox(height: 8),
                        Text('${pickupOrders.length}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const Text('Pickup orders'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (orders.isEmpty)
              const FarmCard(
                  child: Text('No active delivery or pickup orders.'))
            else
              ...orders.map((order) {
                final currentDeliveryStatus =
                    deliveryStatuses.contains(order.deliveryStatus)
                        ? order.deliveryStatus!
                        : order.fulfillmentType == 'delivery'
                            ? 'pending'
                            : 'ready_for_pickup';

                return FarmCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Order #${order.shortId}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Chip(
                            label: Text(order.formattedType),
                            backgroundColor: FarmColors.lightGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${order.customerName} • ${order.customerPhone}'),
                      Text('Schedule: ${order.scheduleText}'),
                      if ((order.deliveryZone ?? '').isNotEmpty)
                        Text('Zone: ${order.deliveryZone}'),
                      if ((order.deliveryAddress ?? '').isNotEmpty)
                        Text('Address: ${order.deliveryAddress}'),
                      const SizedBox(height: 8),
                      Text('Current: ${_friendlyStatus(currentDeliveryStatus)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.restaurant_menu, size: 18),
                            label: const Text('Preparing'),
                            onPressed: () async {
                              await updateDeliveryStatus(order.id, 'preparing');
                              onChanged();
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.inventory_2_outlined,
                                size: 18),
                            label: Text(order.fulfillmentType == 'delivery'
                                ? 'Out for Delivery'
                                : 'Ready Pickup'),
                            onPressed: () async {
                              await updateDeliveryStatus(
                                order.id,
                                order.fulfillmentType == 'delivery'
                                    ? 'out_for_delivery'
                                    : 'ready_for_pickup',
                              );
                              onChanged();
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.done_all, size: 18),
                            label: const Text('Delivered'),
                            onPressed: () async {
                              await updateDeliveryStatus(order.id, 'delivered');
                              onChanged();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: currentDeliveryStatus,
                        decoration: const InputDecoration(
                            labelText: 'Delivery / pickup status'),
                        items: deliveryStatuses
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(_friendlyStatus(status)),
                                ))
                            .toList(),
                        onChanged: (status) async {
                          if (status == null) return;
                          await updateDeliveryStatus(order.id, status);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class AdminProductsTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onChanged;

  const AdminProductsTab({
    super.key,
    required this.refreshKey,
    required this.onChanged,
  });

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  int localRefreshKey = 0;

  void refreshProducts() {
    setState(() => localRefreshKey++);
    widget.onChanged();
  }

  String shortDescription(Product product) {
    final description = (product.description ?? '').trim();
    return description.isEmpty
        ? 'Fresh natural harvest from the farm.'
        : description;
  }

  Future<void> openProductEditor(BuildContext context,
      {Product? product}) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(2),
    );
    final stockController = TextEditingController(
      text: product == null ? '0' : product.stockQuantity.toString(),
    );
    final unitController = TextEditingController(text: product?.unit ?? 'each');
    final descriptionController =
        TextEditingController(text: product?.description ?? '');
    final imageUrlController =
        TextEditingController(text: product?.imageUrl ?? '');
    final originalPriceController = TextEditingController(
      text: product?.originalPrice == null
          ? ''
          : product!.originalPrice!.toStringAsFixed(2),
    );
    final discountPriceController = TextEditingController(
      text: product?.discountPrice == null
          ? ''
          : product!.discountPrice!.toStringAsFixed(2),
    );
    final discountPercentController = TextEditingController(
      text: product?.discountPercent == null
          ? ''
          : product!.discountPercent!.toStringAsFixed(0),
    );
    final discountLabelController =
        TextEditingController(text: product?.discountLabel ?? '');
    final discountStartsController = TextEditingController(
      text: product?.discountStartsAt == null
          ? ''
          : product!.discountStartsAt!.toIso8601String(),
    );
    final discountEndsController = TextEditingController(
      text: product?.discountEndsAt == null
          ? ''
          : product!.discountEndsAt!.toIso8601String(),
    );
    final estimatedReadyDateController = TextEditingController(
      text: product?.estimatedReadyDate == null
          ? ''
          : todayIsoDateFrom(product!.estimatedReadyDate!),
    );
    final expectedStockController = TextEditingController(
      text: product?.expectedStockQuantity == null
          ? ''
          : product!.expectedStockQuantity.toString(),
    );
    final subscribeSavePercentController = TextEditingController(
      text: product?.subscribeSaveDiscountPercent == null
          ? '5'
          : product!.subscribeSaveDiscountPercent.toStringAsFixed(0),
    );
    final dealRankController = TextEditingController(
      text: product == null ? '10' : product.dealRank.toString(),
    );
    String selectedCategory =
        normalizeProductCategory(product?.category ?? 'Vegetables');
    String selectedProductStatus = product?.productStatus ?? 'available';
    bool isOrganic = product?.isOrganic ?? false;
    bool isAvailable = product?.isAvailable ?? true;
    bool isDiscountActive = product?.isDiscountActive ?? false;
    bool readySoon = product?.isReadySoon ?? false;
    bool isDealOfDay = product?.isDealOfDay ?? false;
    bool subscribeSaveEnabled = product?.subscribeSaveEnabled ?? false;
    bool uploadingImage = false;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveProduct() async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim());
              final stock = int.tryParse(stockController.text.trim()) ?? 0;
              final unit = unitController.text.trim();
              final description = descriptionController.text.trim();
              final imageUrl = imageUrlController.text.trim();
              final originalPrice =
                  double.tryParse(originalPriceController.text.trim());
              final discountPrice =
                  double.tryParse(discountPriceController.text.trim());
              final discountPercent =
                  double.tryParse(discountPercentController.text.trim());
              final discountLabel = discountLabelController.text.trim();
              final discountStarts = discountStartsController.text.trim();
              final discountEnds = discountEndsController.text.trim();
              final estimatedReadyDate =
                  estimatedReadyDateController.text.trim();
              final expectedStock =
                  int.tryParse(expectedStockController.text.trim());
              final dealRank = int.tryParse(dealRankController.text.trim());
              final subscribeSavePercent =
                  double.tryParse(subscribeSavePercentController.text.trim());
              final status = readySoon
                  ? 'ready_soon'
                  : selectedProductStatus == 'ready_soon'
                      ? 'ready_soon'
                      : selectedProductStatus;

              if (name.isEmpty || price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enter product name and valid price.')),
                );
                return;
              }

              if (dialogContext.mounted) {
                setDialogState(() => saving = true);
              }

              try {
                if (product == null) {
                  await createProduct(
                    name: name,
                    price: price,
                    stockQuantity: stock,
                    isAvailable: isAvailable,
                    category: selectedCategory,
                    isOrganic: isOrganic,
                    description: description.isEmpty ? null : description,
                    unit: unit.isEmpty ? null : unit,
                    imageUrl: imageUrl.isEmpty ? null : imageUrl,
                    isDiscountActive: isDiscountActive,
                    originalPrice: originalPrice,
                    discountPrice: discountPrice,
                    discountPercent: discountPercent,
                    discountLabel: discountLabel.isEmpty ? null : discountLabel,
                    discountStartsAt:
                        discountStarts.isEmpty ? null : discountStarts,
                    discountEndsAt: discountEnds.isEmpty ? null : discountEnds,
                    productStatus: status,
                    readySoon: readySoon,
                    estimatedReadyDate:
                        estimatedReadyDate.isEmpty ? null : estimatedReadyDate,
                    expectedStockQuantity: expectedStock,
                    isDealOfDay: isDealOfDay,
                    dealRank: dealRank,
                    subscribeSaveEnabled: subscribeSaveEnabled,
                    subscribeSaveDiscountPercent: subscribeSavePercent,
                  );
                } else {
                  await updateProductDetails(
                    productId: product.id,
                    name: name,
                    price: price,
                    stockQuantity: stock,
                    isAvailable: isAvailable,
                    category: selectedCategory,
                    isOrganic: isOrganic,
                    description: description.isEmpty ? null : description,
                    unit: unit.isEmpty ? null : unit,
                    imageUrl: imageUrl.isEmpty ? null : imageUrl,
                    isDiscountActive: isDiscountActive,
                    originalPrice: originalPrice,
                    discountPrice: discountPrice,
                    discountPercent: discountPercent,
                    discountLabel: discountLabel.isEmpty ? null : discountLabel,
                    discountStartsAt:
                        discountStarts.isEmpty ? null : discountStarts,
                    discountEndsAt: discountEnds.isEmpty ? null : discountEnds,
                    productStatus: status,
                    readySoon: readySoon,
                    estimatedReadyDate:
                        estimatedReadyDate.isEmpty ? null : estimatedReadyDate,
                    expectedStockQuantity: expectedStock,
                    isDealOfDay: isDealOfDay,
                    dealRank: dealRank,
                    subscribeSaveEnabled: subscribeSaveEnabled,
                    subscribeSaveDiscountPercent: subscribeSavePercent,
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(product == null
                          ? 'Product added successfully'
                          : 'Product updated successfully'),
                    ),
                  );
                  FarmDataCache.clearProducts();
                  refreshProducts();
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Could not save product. Please check the item details and try again.'),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: Text(product == null ? 'Add Product' : 'Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Product name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Stock quantity'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: productCategoryOptions
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedCategory = value;
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedProductStatus,
                      decoration:
                          const InputDecoration(labelText: 'Product status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'available', child: Text('Available')),
                        DropdownMenuItem(
                            value: 'ready_soon', child: Text('Ready Soon')),
                        DropdownMenuItem(
                            value: 'out_of_stock', child: Text('Out of Stock')),
                        DropdownMenuItem(
                            value: 'hidden', child: Text('Hidden')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedProductStatus = value;
                                readySoon = value == 'ready_soon';
                                if (readySoon) isAvailable = false;
                              });
                            },
                    ),
                    SwitchListTile(
                      value: readySoon,
                      title: const Text('Ready soon item'),
                      subtitle: const Text(
                          'Show this item in the Ready Soon section and let customers request alerts.'),
                      activeColor: FarmColors.warning,
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(() {
                                readySoon = value;
                                selectedProductStatus =
                                    value ? 'ready_soon' : 'available';
                                if (value) isAvailable = false;
                              });
                            },
                    ),
                    if (readySoon) ...[
                      TextField(
                        controller: estimatedReadyDateController,
                        decoration: const InputDecoration(
                          labelText: 'Estimated ready date',
                          helperText: 'Use YYYY-MM-DD',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: expectedStockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Expected quantity'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SwitchListTile(
                      value: isDiscountActive,
                      title: const Text('Discount / deal active'),
                      subtitle: const Text(
                          'Show a sale price and deal badge like an online marketplace.'),
                      activeColor: FarmColors.warning,
                      onChanged: saving
                          ? null
                          : (value) =>
                              setDialogState(() => isDiscountActive = value),
                    ),
                    if (isDiscountActive) ...[
                      TextField(
                        controller: originalPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Original price'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Discount price'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountPercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Discount percent'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountLabelController,
                        decoration: const InputDecoration(
                            labelText: 'Deal label',
                            hintText: 'Today’s Deal, Fresh Pick Deal...'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountStartsController,
                        decoration: const InputDecoration(
                            labelText: 'Deal starts at',
                            helperText: 'Optional ISO date/time'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountEndsController,
                        decoration: const InputDecoration(
                            labelText: 'Deal ends at',
                            helperText: 'Optional ISO date/time'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isDealOfDay,
                      title: const Text('Deal of the Day'),
                      subtitle: const Text(
                          'Feature this product in the customer Deal of the Day section.'),
                      activeColor: FarmColors.warning,
                      onChanged: saving
                          ? null
                          : (value) =>
                              setDialogState(() => isDealOfDay = value),
                    ),
                    if (isDealOfDay) ...[
                      TextField(
                        controller: dealRankController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Deal display rank',
                          helperText: 'Lower numbers show first',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SwitchListTile(
                      value: subscribeSaveEnabled,
                      title: const Text('Subscribe & Save'),
                      subtitle: const Text(
                          'Allow customers to create repeat orders for this item.'),
                      activeColor: FarmColors.success,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(
                              () => subscribeSaveEnabled = value),
                    ),
                    if (subscribeSaveEnabled) ...[
                      TextField(
                        controller: subscribeSavePercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Subscribe & Save discount %'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isOrganic,
                      title: const Text('Organic item'),
                      subtitle: Text(
                        isOrganic
                            ? 'Shown as organic in the shop'
                            : 'Turn on only if this item is organic',
                      ),
                      activeColor: FarmColors.green,
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(() {
                                isOrganic = value;
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Short description'),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FarmColors.cream,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: FarmColors.lightGreen),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Image',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          productImagePreviewFromUrl(
                            imageUrl: imageUrlController.text,
                            fallbackIcon: product?.icon ?? '🥬',
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: imageUrlController,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Image URL or uploaded image link',
                              helperText:
                                  'Paste a hosted image URL. Gallery/camera upload can connect here later.',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: uploadingImage
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.upload_file_outlined),
                                label: Text(uploadingImage
                                    ? 'Uploading...'
                                    : 'Upload Image'),
                                onPressed: saving || uploadingImage
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        setDialogState(
                                            () => uploadingImage = true);
                                        try {
                                          final uploadedUrl =
                                              await pickAndUploadProductImage(
                                            productName: nameController.text
                                                    .trim()
                                                    .isEmpty
                                                ? product?.name ?? 'product'
                                                : nameController.text.trim(),
                                          );

                                          if (uploadedUrl != null &&
                                              uploadedUrl.isNotEmpty) {
                                            imageUrlController.text =
                                                uploadedUrl;
                                            setDialogState(() {});
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Image uploaded successfully.',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (error) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                error.toString().replaceFirst(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (dialogContext.mounted) {
                                            setDialogState(
                                                () => uploadingImage = false);
                                          }
                                        }
                                      },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Image'),
                                onPressed: () {
                                  imageUrlController.clear();
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isAvailable,
                      title: const Text('Visible in shop'),
                      activeColor: FarmColors.green,
                      onChanged: (value) {
                        setDialogState(() => isAvailable = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      priceController.dispose();
      stockController.dispose();
      unitController.dispose();
      descriptionController.dispose();
      imageUrlController.dispose();
      originalPriceController.dispose();
      discountPriceController.dispose();
      discountPercentController.dispose();
      discountLabelController.dispose();
      discountStartsController.dispose();
      discountEndsController.dispose();
      estimatedReadyDateController.dispose();
      expectedStockController.dispose();
      subscribeSavePercentController.dispose();
      dealRankController.dispose();
    });
  }

  Future<void> openRestockDialog(BuildContext context, Product product) async {
    final amountController = TextEditingController(text: '10');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Restock ${product.name}'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount to add'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amount = int.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) return;
                try {
                  await restockProduct(product.id, amount);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${product.name} restocked')),
                    );
                    refreshProducts();
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not restock: $error')),
                    );
                  }
                }
              },
              child: const Text('Restock'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountController.dispose();
    });
  }

  Future<void> openReuseThisWeekDialog(
      BuildContext context, Product product) async {
    final stockController = TextEditingController(
      text: product.stockQuantity > 0 ? product.stockQuantity.toString() : '10',
    );

    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Reuse ${product.name} recently harvested'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will move the item into Recently Harvested and make it visible in the shop.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockController,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'New stock quantity',
                      helperText:
                          'Set how many are available recently harvested.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_repeat_outlined),
                  label: Text(saving ? 'Saving...' : 'Mark Recently Harvested'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final stock =
                              int.tryParse(stockController.text.trim()) ?? 0;
                          if (stock < 0) return;

                          setDialogState(() => saving = true);

                          try {
                            await reuseProductThisWeek(
                              productId: product.id,
                              stockQuantity: stock,
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${product.name} added to Recently Harvested',
                                  ),
                                ),
                              );
                              refreshProducts();
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() => saving = false);
                            }

                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not reuse item. Please check permission and try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      stockController.dispose();
    });
  }

  Future<void> toggleAvailability(Product product) async {
    try {
      await updateProductAvailability(product.id, !product.isAvailable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(product.isAvailable
                ? '${product.name} hidden from shop'
                : '${product.name} is visible in shop'),
          ),
        );
        refreshProducts();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update product: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      key: ValueKey('${widget.refreshKey}-$localRefreshKey'),
      future: fetchAllProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }

        final products = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Header(
                    title: 'Product Management',
                    subtitle: 'Add, edit, hide & restock products',
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => openProductEditor(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (products.isEmpty)
              const FarmCard(
                child: Text(
                    'No products found. Tap Add to create your first product.'),
              )
            else
              ...products.map((product) {
                final unit = (product.unit ?? '').trim();
                return FarmCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductVisual(product: product, size: 44),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(product.isAvailable
                                          ? 'Active'
                                          : 'Hidden'),
                                      backgroundColor: product.isAvailable
                                          ? FarmColors.lightGreen
                                          : FarmColors.border,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  shortDescription(product),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: FarmColors.mutedText),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                        label: DiscountPriceText(
                                            product: product, compact: true)),
                                    Chip(
                                        label: Text(
                                            'Stock: ${product.stockQuantity}')),
                                    if (unit.isNotEmpty)
                                      Chip(label: Text('Unit: $unit')),
                                    Chip(label: Text(product.category)),
                                    Chip(
                                      label: Text(
                                        isProductHarvestedThisWeek(product)
                                            ? 'Recently harvested'
                                            : 'Harvest record',
                                      ),
                                    ),
                                    if (product.isOrganic)
                                      const Chip(label: Text('Organic')),
                                    if ((product.farmName ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Chip(
                                          label:
                                              Text(product.farmName!.trim())),
                                    if ((product.parish ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Chip(label: Text(product.parish!.trim())),
                                    Chip(
                                        label: Text(_friendlyStatus(
                                            product.approvalStatus))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            onPressed: () =>
                                openProductEditor(context, product: product),
                          ),
                          OutlinedButton.icon(
                            icon: Icon(product.isAvailable
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            label: Text(product.isAvailable ? 'Hide' : 'Show'),
                            onPressed: () => toggleAvailability(product),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Restock'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FarmColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                openRestockDialog(context, product),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.event_repeat_outlined),
                            label: const Text('Mark Recently Harvested'),
                            onPressed: () => openReuseThisWeekDialog(
                              context,
                              product,
                            ),
                          ),
                          if (product.approvalStatus != 'approved')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve'),
                              onPressed: () async {
                                await updateProductApproval(
                                    product.id, 'approved');
                                refreshProducts();
                              },
                            ),
                          if (product.approvalStatus != 'rejected')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Reject'),
                              onPressed: () async {
                                await updateProductApproval(
                                    product.id, 'rejected');
                                refreshProducts();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class AIShoppingAssistantScreen extends StatefulWidget {
  const AIShoppingAssistantScreen({super.key});

  @override
  State<AIShoppingAssistantScreen> createState() =>
      _AIShoppingAssistantScreenState();
}

class _AIShoppingAssistantScreenState extends State<AIShoppingAssistantScreen> {
  final messageController = TextEditingController();
  final List<String> messages = [
    'Hi! Ask me about fresh produce, vegan ingredients, recipes, delivery, checkout, storage, budget boxes, or what to add to your farm box.',
  ];

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(text);
      messages.add(_localAssistantReply(text));
      messageController.clear();
    });
  }

  String _localAssistantReply(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('delivery') || lower.contains('deliver')) {
      return 'For delivery, choose Home Delivery at checkout, select your parish/zone, add your address, date, and time, then place the order. Your delivery updates will appear in your Orders screen.';
    }

    if (lower.contains('pickup') || lower.contains('collect')) {
      return 'For pickup, choose Farm Pickup at checkout, select your preferred date and time, then bring your order number when collecting your farm box.';
    }

    if (lower.contains('payment') ||
        lower.contains('pay') ||
        lower.contains('cash') ||
        lower.contains('bank')) {
      return 'Payment options depend on your checkout choice. You can use cash on pickup, cash on delivery, or bank transfer if enabled. Bank transfer orders may show as pending until the farm confirms payment.';
    }

    if (lower.contains('order') ||
        lower.contains('status') ||
        lower.contains('track')) {
      return 'To track an order, open Orders and tap the order card. You will see status, delivery or pickup details, payment status, items, and schedule information.';
    }

    if (lower.contains('trace') ||
        lower.contains('qr') ||
        lower.contains('farm')) {
      return 'Use Trace to look up a product code or tap a product detail page when trace information is available. Trace records can show farm location, harvest date, farming method, and batch notes.';
    }

    if (lower.contains('favorite') || lower.contains('like')) {
      return 'Tap the heart on a product to save it as a favorite. You can find favorite items from your Account tools and use them to shop faster next time.';
    }

    if (lower.contains('vegan') ||
        lower.contains('ingredient') ||
        lower.contains('plant')) {
      return 'For vegan choices, start with callaloo, lettuce, okra, pumpkin, peppers, herbs, fruits, and honey alternatives if needed. The Vegan Ingredient Book can help with benefits, cooking uses, and storage tips.';
    }

    if (lower.contains('budget') ||
        lower.contains('cheap') ||
        lower.contains('affordable')) {
      return 'For a budget-friendly farm box, choose 2–3 vegetables first, then add one protein or pantry item only if needed. Callaloo, lettuce, pumpkin, corn, and okra are good value picks when available.';
    }

    if (lower.contains('recipe') ||
        lower.contains('meal') ||
        lower.contains('cook') ||
        lower.contains('dinner') ||
        lower.contains('breakfast')) {
      return 'Meal idea: make a harvest bowl with callaloo or lettuce, sweet corn, peppers, herbs, and eggs if you eat them. For vegan meals, use pumpkin, okra, greens, herbs, and a light citrus dressing.';
    }

    if (lower.contains('fresh') ||
        lower.contains('today') ||
        lower.contains('best')) {
      return 'For the freshest picks, check Recently Harvested, choose products with stock available, and use trace details when shown. Greens and herbs are best used first, while pumpkin and honey keep longer.';
    }

    if (lower.contains('store') ||
        lower.contains('storage') ||
        lower.contains('keep')) {
      return 'Storage tip: keep leafy greens dry and chilled, herbs wrapped lightly, eggs refrigerated, honey sealed at room temperature, and pumpkin in a cool dry place.';
    }

    if (lower.contains('box') ||
        lower.contains('cart') ||
        lower.contains('add')) {
      return 'Tap Add or the plus button to place items in My Box. Tapping the product card opens details instead of adding, so you can review description and trace information first.';
    }

    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('help')) {
      return 'I can help with what to buy, how to cook it, how delivery works, how to track orders, and how to build a fresh farm box for your budget.';
    }

    return 'Here’s a helpful farm-box suggestion: choose one leafy green, one cooking vegetable, one colorful item like pepper or corn, and one add-on such as eggs or honey if it fits your needs. Ask me about recipes, delivery, order status, or vegan ingredients.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('AI Shopping Assistant'),
        backgroundColor: FarmColors.background,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: FarmCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.eco_outlined, size: 18),
                    label: const Text('Vegan ideas'),
                    onPressed: () {
                      messageController.text =
                          'What vegan ingredients should I buy?';
                      sendMessage();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('Delivery help'),
                    onPressed: () {
                      messageController.text = 'How does delivery work?';
                      sendMessage();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.restaurant_menu, size: 18),
                    label: const Text('Meal plan'),
                    onPressed: () {
                      messageController.text = 'Give me a meal idea';
                      sendMessage();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.savings_outlined, size: 18),
                    label: const Text('Budget box'),
                    onPressed: () {
                      messageController.text =
                          'Help me build a budget farm box';
                      sendMessage();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final isUser = index.isOdd;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: isUser ? FarmColors.green : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isUser
                          ? []
                          : [
                              BoxShadow(
                                color: FarmColors.shadow.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Text(
                      messages[index],
                      style: TextStyle(
                          color: isUser ? Colors.white : FarmColors.text),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask about produce, delivery, recipes...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: FarmColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoyaltySummaryCard extends StatelessWidget {
  const LoyaltySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoyaltySummary>(
      future: fetchLoyaltySummary(),
      builder: (context, snapshot) {
        final summary = snapshot.data ??
            const LoyaltySummary(points: 0, lifetimePoints: 0, tier: 'Green');

        return FarmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Farm Rewards',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: FarmColors.lightGreen,
                    foregroundColor: FarmColors.primary,
                    child: const Icon(Icons.card_giftcard, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary.points} points',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: FarmColors.green,
                          ),
                        ),
                        Text(
                          '${summary.tier} tier • ${summary.nextTierLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class LoyaltyRewardsScreen extends StatelessWidget {
  const LoyaltyRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Loyalty Rewards'),
        backgroundColor: FarmColors.background,
      ),
      body: FutureBuilder<LoyaltySummary>(
        future: fetchLoyaltySummary(),
        builder: (context, snapshot) {
          final summary = snapshot.data ??
              const LoyaltySummary(points: 0, lifetimePoints: 0, tier: 'Green');

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              FarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Farm Rewards',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${summary.points} points',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: FarmColors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary.tier} tier • ${summary.nextTierLabel}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Earn 1 point for every J\$100 in completed farm orders.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const FarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reward Ideas',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• 100 points = small discount'),
                    Text('• 250 points = free herbs add-on'),
                    Text('• 500 points = premium harvest box reward'),
                    Text('• 1000 points = Platinum customer tier'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  final List<Product> products;
  final VoidCallback onShopTap;

  const FavoritesScreen({
    super.key,
    required this.products,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return ProductCollectionScreen(
      title: 'Favorites',
      subtitle: 'Saved products you love',
      products: products,
      emptyText: 'No favorites yet. Tap the heart on products in Shop.',
      onShopTap: onShopTap,
    );
  }
}

class RecentlyViewedScreen extends StatelessWidget {
  final List<Product> products;
  final VoidCallback onShopTap;

  const RecentlyViewedScreen({
    super.key,
    required this.products,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return ProductCollectionScreen(
      title: 'Recently Viewed',
      subtitle: 'Products you checked recently',
      products: products,
      emptyText: 'No recently viewed products yet.',
      onShopTap: onShopTap,
    );
  }
}

class ProductCollectionScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Product> products;
  final String emptyText;
  final VoidCallback onShopTap;

  const ProductCollectionScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.emptyText,
    required this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(title: Text(title), backgroundColor: FarmColors.cream),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Header(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          if (products.isEmpty)
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emptyText),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onShopTap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go to Shop'),
                  ),
                ],
              ),
            )
          else
            ...products.map((product) => FarmCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      ProductVisual(product: product, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              (product.description ?? '').trim().isEmpty
                                  ? 'Fresh natural harvest from the farm.'
                                  : product.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(product.formattedPrice,
                                style: const TextStyle(
                                  color: FarmColors.green,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class FarmPage extends StatelessWidget {
  final Widget child;

  const FarmPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FarmColors.background,
      child: SafeArea(child: child),
    );
  }
}

class FarmNotificationButton extends StatelessWidget {
  final double size;
  final bool showBadge;

  const FarmNotificationButton({
    super.key,
    this.size = 38,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: showBadge ? fetchUnreadNotificationCount() : null,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: FarmColors.line),
            boxShadow: [
              BoxShadow(
                color: FarmColors.shadow.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: FarmColors.deepGreen,
                    size: 20,
                  ),
                ),
              ),
              if (showBadge && count > 0)
                Positioned(
                  right: -1,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: FarmColors.danger,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class FarmHeaderCartButton extends StatelessWidget {
  final double size;
  final int itemCount;
  final VoidCallback onPressed;

  const FarmHeaderCartButton({
    super.key,
    this.size = 38,
    required this.itemCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: FarmColors.line),
        boxShadow: [
          BoxShadow(
            color: FarmColors.shadow.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'My Farm Box',
              onPressed: onPressed,
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: FarmColors.deepGreen,
                size: 20,
              ),
            ),
          ),
          if (itemCount > 0)
            Positioned(
              right: -1,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: FarmColors.accent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  itemCount > 99 ? '99+' : '$itemCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int refreshKey = 0;

  Future<void> markReadAndRefresh() async {
    await markNotificationsRead();
    FarmDataCache.notifications = null;
    if (mounted) setState(() => refreshKey++);
  }

  Future<void> refreshNotifications() async {
    FarmDataCache.notifications = null;
    if (mounted) setState(() => refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: FarmColors.background,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: refreshNotifications,
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: markReadAndRefresh,
            child: const Text('Mark read'),
          ),
        ],
      ),
      body: FarmPage(
        child: FutureBuilder<List<FarmNotification>>(
          key: ValueKey(refreshKey),
          future: fetchFarmNotifications(forceRefresh: refreshKey > 0),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SkeletonList();
            }

            final notifications = snapshot.data ?? const <FarmNotification>[];
            final unreadCount =
                notifications.where((notice) => !notice.isRead).length;

            return RefreshIndicator(
              onRefresh: () async => refreshNotifications(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
                children: [
                  Header(
                    title: 'Notifications',
                    subtitle: unreadCount == 0
                        ? 'All caught up'
                        : '$unreadCount unread update${unreadCount == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 16),
                  FarmCard(
                    color: Colors.white,
                    child: Row(
                      children: [
                        const FarmNotificationButton(
                          size: 42,
                          showBadge: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            unreadCount == 0
                                ? 'You are all caught up.'
                                : '$unreadCount unread update${unreadCount == 1 ? '' : 's'} waiting.',
                            style: const TextStyle(
                              color: FarmColors.deepGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (notifications.isEmpty)
                    const FarmCard(
                      child: Text(
                        'No notifications yet. Order updates will appear here.',
                      ),
                    )
                  else
                    ...notifications.map(
                      (notice) => FarmNotificationTile(
                        notice: notice,
                        onTap: notice.hasOrderLink
                            ? () async {
                                final matchedOrderId =
                                    await findOrderIdForNotification(notice);

                                if (!context.mounted) return;

                                if (matchedOrderId == null ||
                                    matchedOrderId.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Order could not be found.'),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailsScreen(
                                      orderId: matchedOrderId.trim(),
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class FarmNotificationTile extends StatelessWidget {
  final FarmNotification notice;
  final VoidCallback? onTap;

  const FarmNotificationTile({
    super.key,
    required this.notice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: FarmCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: FarmColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: FarmColors.line),
              ),
              child: Icon(
                notice.icon,
                color: FarmColors.deepGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FarmColors.deepGreen,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!notice.isRead)
                        Container(
                          height: 9,
                          width: 9,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: FarmColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (notice.hasOrderLink)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: FarmColors.green,
                          size: 22,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notice.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FarmColors.mutedText,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: FarmColors.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notice.timeLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: FarmColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  bool sending = false;
  int refreshKey = 0;

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> sendTicket() async {
    final subject = subjectController.text.trim();
    final message = messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject and message.')),
      );
      return;
    }

    setState(() => sending = true);
    try {
      await createSupportTicket(subject: subject, message: message);
      subjectController.clear();
      messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support message sent to the farm.')),
        );
        setState(() => refreshKey++);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send support message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Farm Support'),
        backgroundColor: FarmColors.background,
      ),
      body: FarmPage(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Header(title: 'Support', subtitle: 'Message the farm'),
            const SizedBox(height: 16),
            FarmCard(
              child: Column(
                children: [
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.subject),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryFarmButton(
                    label: sending ? 'Sending...' : 'Send Message',
                    onPressed: sending ? null : sendTicket,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('My Support Messages'),
            const SizedBox(height: 12),
            FutureBuilder<List<SupportTicket>>(
              key: ValueKey(refreshKey),
              future: fetchMySupportTickets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const SkeletonList();
                }
                final tickets = snapshot.data ?? [];
                if (tickets.isEmpty) {
                  return const FarmCard(
                      child: Text('No support messages yet.'));
                }
                return Column(
                  children: tickets
                      .map((ticket) => FarmCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text(ticket.subject,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16))),
                                    Chip(
                                        label: Text(ticket.formattedStatus),
                                        backgroundColor: FarmColors.lightGreen),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(ticket.message),
                                if ((ticket.adminReply ?? '').isNotEmpty) ...[
                                  const Divider(),
                                  const Text('Farm reply',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(ticket.adminReply!),
                                ],
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Product? selectedProduct;
  int rating = 5;
  final commentController = TextEditingController();
  bool sending = false;
  int refreshKey = 0;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> submitReview() async {
    final product = selectedProduct;
    final comment = commentController.text.trim();

    if (product == null || comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please choose a product and enter feedback.')),
      );
      return;
    }

    setState(() => sending = true);
    try {
      await createProductReview(
        productId: product.id,
        productName: product.name,
        rating: rating,
        comment: comment,
      );
      commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review.')),
        );
        setState(() {
          selectedProduct = null;
          rating = 5;
          refreshKey++;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save review: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: FarmColors.background,
      ),
      body: FarmPage(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Header(title: 'Reviews', subtitle: 'Share feedback'),
            const SizedBox(height: 16),
            FarmCard(
              child: FutureBuilder<List<Product>>(
                future: fetchProducts(),
                builder: (context, snapshot) {
                  final products = snapshot.data ?? fallbackProducts;
                  return Column(
                    children: [
                      DropdownButtonFormField<Product>(
                        value: products.contains(selectedProduct)
                            ? selectedProduct
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          prefixIcon: Icon(Icons.eco_outlined),
                        ),
                        items: products.map((product) {
                          return DropdownMenuItem<Product>(
                            value: product,
                            child: Text(product.name),
                          );
                        }).toList(),
                        onChanged: (Product? product) {
                          if (product == null) return;
                          setState(() {
                            selectedProduct = product;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: rating,
                        decoration: const InputDecoration(
                          labelText: 'Rating',
                          prefixIcon: Icon(Icons.star_outline),
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 stars')),
                          DropdownMenuItem(value: 4, child: Text('4 stars')),
                          DropdownMenuItem(value: 3, child: Text('3 stars')),
                          DropdownMenuItem(value: 2, child: Text('2 stars')),
                          DropdownMenuItem(value: 1, child: Text('1 star')),
                        ],
                        onChanged: (value) =>
                            setState(() => rating = value ?? 5),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Feedback',
                          prefixIcon: Icon(Icons.rate_review_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      PrimaryFarmButton(
                        label: sending ? 'Submitting...' : 'Submit Review',
                        onPressed: sending ? null : submitReview,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Recent Reviews'),
            const SizedBox(height: 12),
            ReviewsList(refreshKey: refreshKey),
          ],
        ),
      ),
    );
  }
}

class ReviewsList extends StatelessWidget {
  final int refreshKey;
  const ReviewsList({super.key, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductReview>>(
      key: ValueKey('reviews-$refreshKey'),
      future: fetchProductReviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }
        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return const FarmCard(child: Text('No reviews yet.'));
        }
        return Column(
          children: reviews
              .take(20)
              .map((review) => FarmCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(review.productName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16))),
                            Text(
                                '${'★' * review.rating}${'☆' * (5 - review.rating)}'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(review.comment),
                        if (review.email.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(review.email,
                              style: TextStyle(
                                  color: FarmColors.mutedText, fontSize: 12)),
                        ],
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class AdminSupportTab extends StatelessWidget {
  final int refreshKey;
  final VoidCallback onChanged;

  const AdminSupportTab(
      {super.key, required this.refreshKey, required this.onChanged});

  Future<void> replyToTicket(BuildContext context, SupportTicket ticket) async {
    final replyController =
        TextEditingController(text: ticket.adminReply ?? '');
    String selectedStatus = ticket.status;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Support #${ticket.shortId}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(ticket.message),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                            value: 'in_progress', child: Text('In progress')),
                        DropdownMenuItem(
                            value: 'closed', child: Text('Closed')),
                      ],
                      onChanged: (value) => setDialogState(
                          () => selectedStatus = value ?? 'open'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: replyController,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Farm reply'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.primary,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      await updateSupportTicket(
                        ticketId: ticket.id,
                        status: selectedStatus,
                        adminReply: replyController.text.trim().isEmpty
                            ? null
                            : replyController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Support ticket updated')));
                      }
                      onChanged();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Could not update support ticket: $error')));
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportTicket>>(
      key: ValueKey('support-$refreshKey'),
      future: fetchAdminSupportTickets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }
        final tickets = snapshot.data ?? [];
        if (tickets.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: FarmCard(child: Text('No support tickets yet.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(ticket.subject,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17))),
                      Chip(
                          label: Text(ticket.formattedStatus),
                          backgroundColor: FarmColors.lightGreen),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(ticket.email),
                  const SizedBox(height: 8),
                  Text(ticket.message),
                  if ((ticket.adminReply ?? '').isNotEmpty) ...[
                    const Divider(),
                    Text('Reply: ${ticket.adminReply}'),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.reply),
                      label: const Text('Reply / Update'),
                      onPressed: () => replyToTicket(context, ticket),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AdminReviewsTab extends StatelessWidget {
  final int refreshKey;
  const AdminReviewsTab({super.key, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Header(title: 'Reviews', subtitle: 'Customer product feedback'),
        const SizedBox(height: 16),
        ReviewsList(refreshKey: refreshKey),
      ],
    );
  }
}

class Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const Header({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: FarmColors.mutedText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    color: FarmColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const FarmNotificationButton(size: 42)
        ],
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      height: 188,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173526),
            Color(0xFF315B43),
            Color(0xFF3F934C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: FarmColors.shadow.withOpacity(0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -34,
              child: Container(
                height: 132,
                width: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.075),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 16,
              child: Icon(
                Icons.eco_outlined,
                size: 86,
                color: Colors.white.withOpacity(0.075),
              ),
            ),
            Positioned(
              left: 22,
              top: 22,
              right: 22,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fresh from\nour fields',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Natural food. Local harvest. Better living.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroTrustChip(
                        icon: Icons.eco_outlined,
                        label: 'Farm fresh',
                      ),
                      _HeroTrustChip(
                        icon: Icons.storefront_outlined,
                        label: 'Local',
                      ),
                      _HeroTrustChip(
                        icon: Icons.local_shipping_outlined,
                        label: 'Delivery',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTrustChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroTrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class FarmSkeletonCard extends StatefulWidget {
  final double height;

  const FarmSkeletonCard({super.key, this.height = 120});

  @override
  State<FarmSkeletonCard> createState() => _FarmSkeletonCardState();
}

class _FarmSkeletonCardState extends State<FarmSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(controller),
      child: Container(
        height: widget.height,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: FarmColors.shadow.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.count = 4,
    this.height = 120,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 120),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => FarmSkeletonCard(height: height),
    );
  }
}

class DiscountPriceText extends StatelessWidget {
  final Product product;
  final bool compact;

  const DiscountPriceText({
    super.key,
    required this.product,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = Text(
      product.formattedEffectivePrice,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 15 : 28,
        fontWeight: FontWeight.w900,
        color: FarmColors.green,
      ),
    );

    if (!product.hasActiveDiscount) {
      return priceText;
    }

    final originalPriceText = Text(
      product.formattedOriginalPrice,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: FarmColors.mutedText,
        fontSize: compact ? 10.5 : 13,
        decoration: TextDecoration.lineThrough,
        fontWeight: FontWeight.w700,
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              priceText,
              DiscountBadge(product: product, compact: true),
            ],
          ),
          const SizedBox(height: 2),
          originalPriceText,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: priceText),
            const SizedBox(width: 8),
            Flexible(child: DiscountBadge(product: product)),
          ],
        ),
        const SizedBox(height: 3),
        originalPriceText,
      ],
    );
  }
}

class DiscountBadge extends StatelessWidget {
  final Product product;
  final bool compact;

  const DiscountBadge({
    super.key,
    required this.product,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!product.hasActiveDiscount) return const SizedBox.shrink();

    final label = compact
        ? '${product.discountPercentDisplay}% OFF'
        : (product.discountLabel ?? '').trim().isEmpty
            ? '${product.discountPercentDisplay}% OFF'
            : '${product.discountPercentDisplay}% OFF • ${product.discountLabel!.trim()}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: FarmColors.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: FarmColors.warning,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class NotifyMeWhenReadyButton extends StatefulWidget {
  final Product product;
  final bool compact;

  const NotifyMeWhenReadyButton({
    super.key,
    required this.product,
    this.compact = false,
  });

  @override
  State<NotifyMeWhenReadyButton> createState() =>
      _NotifyMeWhenReadyButtonState();
}

class _NotifyMeWhenReadyButtonState extends State<NotifyMeWhenReadyButton> {
  bool loading = false;
  bool subscribed = false;

  @override
  void initState() {
    super.initState();
    isSubscribedToProductReadyAlert(widget.product).then((value) {
      if (mounted) setState(() => subscribed = value);
    });
  }

  Future<void> subscribe() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final created = await subscribeToProductReadyAlert(widget.product);
      if (!mounted) return;
      setState(() => subscribed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(created
              ? 'We will notify you when ${widget.product.name} is ready.'
              : 'You are already on the ready alert list for ${widget.product.name}.'),
        ),
      );
      await requestBrowserNotifications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = subscribed
        ? 'Alert Set'
        : widget.compact
            ? 'Notify Me'
            : widget.product.isReadySoon
                ? 'Notify Me When Ready'
                : 'Notify Me When Available';

    return SizedBox(
      height: widget.compact ? 36 : 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: subscribed || loading ? null : subscribe,
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                subscribed
                    ? Icons.notifications_active
                    : Icons.notifications_outlined,
                size: widget.compact ? 16 : 20),
        label:
            Text(label, style: TextStyle(fontSize: widget.compact ? 12 : 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: FarmColors.green,
          side: const BorderSide(color: FarmColors.lightGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.compact ? 14 : 18),
          ),
        ),
      ),
    );
  }
}

class ReadySoonRail extends StatelessWidget {
  final List<Product> products;
  final void Function(Product product) onViewed;

  const ReadySoonRail({
    super.key,
    required this.products,
    required this.onViewed,
  });

  void _openProduct(BuildContext context, Product product) {
    onViewed(product);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          quantity: 0,
          onAdd: () {},
          onRemove: () {},
          onViewed: onViewed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = products
        .where((product) =>
            product.approvalStatus == 'approved' &&
            !product.isHidden &&
            product.isReadySoon)
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Ready Soon',
          subtitle: 'Fresh items coming soon',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            cacheExtent: AppPerformanceConfig.productRailCacheExtent,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = visible[index];
              return ReadySoonProductTile(
                product: product,
                onOpen: () => _openProduct(context, product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReadySoonProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onOpen;
  final double width;

  const ReadySoonProductTile({
    super.key,
    required this.product,
    required this.onOpen,
    this.width = 172,
  });

  @override
  Widget build(BuildContext context) {
    final farm = [product.farmName, product.farmerName, product.parish]
        .where((item) => (item ?? '').trim().isNotEmpty)
        .join(' • ');

    return SizedBox(
      width: width,
      height: 228,
      child: FarmCard(
        padding: const EdgeInsets.all(12),
        color: FarmColors.warningSoft,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: ProductVisual(product: product, size: 56)),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                farm.isEmpty ? 'Fresh items coming soon' : farm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FarmColors.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _SmallShopChip(label: product.readySoonLabel),
                  if ((product.expectedStockQuantity ?? 0) > 0)
                    _SmallShopChip(
                        label: '${product.expectedStockQuantity} expected'),
                ],
              ),
              const SizedBox(height: 9),
              NotifyMeWhenReadyButton(product: product, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class ReadySoonHomeSection extends StatefulWidget {
  final void Function(Product product) onViewed;

  const ReadySoonHomeSection({super.key, required this.onViewed});

  @override
  State<ReadySoonHomeSection> createState() => _ReadySoonHomeSectionState();
}

class _ReadySoonHomeSectionState extends State<ReadySoonHomeSection> {
  late Future<List<Product>> readySoonFuture;

  @override
  void initState() {
    super.initState();
    readySoonFuture = fetchReadySoonProducts();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: readySoonFuture,
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            ReadySoonRail(
              products: products,
              onViewed: widget.onViewed,
            ),
          ],
        );
      },
    );
  }
}

class DealOfTheDaySection extends StatefulWidget {
  final void Function(Product product) onViewed;
  final void Function(Product product)? onAddProduct;
  final bool compact;

  const DealOfTheDaySection({
    super.key,
    required this.onViewed,
    this.onAddProduct,
    this.compact = false,
  });

  @override
  State<DealOfTheDaySection> createState() => _DealOfTheDaySectionState();
}

class _DealOfTheDaySectionState extends State<DealOfTheDaySection> {
  late Future<List<Product>> dealsFuture;

  @override
  void initState() {
    super.initState();
    dealsFuture = fetchDealOfTheDayProducts();
  }

  void openProduct(BuildContext context, Product product) {
    widget.onViewed(product);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          quantity: 0,
          onAdd: () => widget.onAddProduct?.call(product),
          onRemove: () {},
          onAddProduct: widget.onAddProduct,
          onViewed: widget.onViewed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: dealsFuture,
      builder: (context, snapshot) {
        final deals = snapshot.data ?? [];
        if (deals.isEmpty) return const SizedBox.shrink();
        final featured = deals.first;
        final remaining = deals.skip(1).take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(child: SectionTitle('Deal of the Day')),
                Icon(Icons.local_offer_outlined, color: FarmColors.warning),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => openProduct(context, featured),
              child: FarmCard(
                color: FarmColors.warningSoft,
                child: Row(
                  children: [
                    ProductVisual(
                        product: featured, size: widget.compact ? 48 : 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            featured.discountLabel?.trim().isNotEmpty == true
                                ? featured.discountLabel!.trim()
                                : 'Limited time fresh deal',
                            style: const TextStyle(
                              color: FarmColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            featured.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DiscountPriceText(product: featured, compact: true),
                          if (featured.isLowStock) ...[
                            const SizedBox(height: 6),
                            Text(
                              featured.lowStockLabel,
                              style: const TextStyle(
                                color: FarmColors.danger,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: FarmColors.warning),
                  ],
                ),
              ),
            ),
            if (remaining.isNotEmpty) ...[
              const SizedBox(height: 10),
              ProductMiniRail(
                products: remaining,
                onProductTap: (product) => openProduct(context, product),
              ),
            ],
          ],
        );
      },
    );
  }
}

class SubscribeSaveButton extends StatefulWidget {
  final Product product;
  final bool compact;

  const SubscribeSaveButton({
    super.key,
    required this.product,
    this.compact = false,
  });

  @override
  State<SubscribeSaveButton> createState() => _SubscribeSaveButtonState();
}

class _SubscribeSaveButtonState extends State<SubscribeSaveButton> {
  bool loading = false;
  bool subscribed = false;
  int intervalDays = 7;

  Future<void> subscribe() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final created = await subscribeToSaveProduct(
        widget.product,
        intervalDays: intervalDays,
      );
      if (!mounted) return;
      setState(() => subscribed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(created
              ? 'Subscribe & Save started for ${widget.product.name}.'
              : 'You already have an active subscription for ${widget.product.name}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.product.hasSubscribeSave) return const SizedBox.shrink();

    return FarmCard(
      color: FarmColors.successSoft,
      padding: EdgeInsets.all(widget.compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_outlined, color: FarmColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Subscribe & Save ${widget.product.subscribeSavePercentValue.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: FarmColors.success,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.product.formattedSubscribeSavePrice} per repeat order. Cancel anytime.',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: intervalDays,
                  decoration: const InputDecoration(labelText: 'Repeat every'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Week')),
                    DropdownMenuItem(value: 14, child: Text('2 weeks')),
                    DropdownMenuItem(value: 30, child: Text('Month')),
                  ],
                  onChanged: loading || subscribed
                      ? null
                      : (value) => setState(() => intervalDays = value ?? 7),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: loading || subscribed ? null : subscribe,
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(subscribed ? Icons.check_circle : Icons.repeat),
                label: Text(subscribed ? 'Active' : 'Start'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FrequentlyBoughtTogetherSection extends StatelessWidget {
  final Product product;
  final void Function(Product product)? onAddProduct;
  final void Function(Product product)? onViewed;

  const FrequentlyBoughtTogetherSection({
    super.key,
    required this.product,
    this.onAddProduct,
    this.onViewed,
  });

  void openProduct(BuildContext context, Product item) {
    onViewed?.call(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: item,
          quantity: 0,
          onAdd: () => onAddProduct?.call(item),
          onRemove: () {},
          onAddProduct: onAddProduct,
          onViewed: onViewed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: fetchFrequentlyBoughtTogetherProducts(product),
      builder: (context, snapshot) {
        final related = snapshot.data ?? [];
        if (related.isEmpty) return const SizedBox.shrink();
        final bundle = related.take(3).toList();
        final bundleTotal = bundle.fold<double>(
          product.effectivePrice,
          (sum, item) => sum + item.effectivePrice,
        );

        return FarmCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequently Bought Together',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Build a complete farm box with items that pair well.',
                style: TextStyle(color: FarmColors.mutedText),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _BundleProductChip(product: product, label: 'This item'),
                  ...bundle.map((item) => InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openProduct(context, item),
                        child: _BundleProductChip(product: item),
                      )),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Bundle total: ${formatJmd(bundleTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (onAddProduct != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        onAddProduct?.call(product);
                        for (final item in bundle) {
                          onAddProduct?.call(item);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Bundle added to My Box.')),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Add Bundle'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BundleProductChip extends StatelessWidget {
  final Product product;
  final String? label;

  const _BundleProductChip({required this.product, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FarmColors.cardSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProductVisual(product: product, size: 34),
          const SizedBox(height: 6),
          Text(
            label ?? product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          Text(
            product.formattedEffectivePrice,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FarmColors.green,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendedForYouDetailSection extends StatelessWidget {
  final Product currentProduct;
  final void Function(Product product)? onAddProduct;
  final void Function(Product product)? onViewed;

  const RecommendedForYouDetailSection({
    super.key,
    required this.currentProduct,
    this.onAddProduct,
    this.onViewed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: fetchProducts(),
      builder: (context, snapshot) {
        final sourceProducts = snapshot.data ?? fallbackProducts;
        final recommended = buildRecommendedForYouProducts(
          allProducts: sourceProducts,
          recentlyViewedProducts: const [],
          buyAgainProducts: const [],
          favoriteProducts: const [],
          selectedCategory: currentProduct.category,
          excludeIds: {currentProduct.id},
        );

        if (snapshot.connectionState == ConnectionState.waiting &&
            recommended.isEmpty) {
          return const FarmSkeletonCard(height: 150);
        }

        if (recommended.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Recommended for You',
              subtitle: 'More fresh picks that pair well with this item',
            ),
            const SizedBox(height: 10),
            ProductMiniRail(
              products: recommended,
              onProductTap: (recommendedProduct) {
                onViewed?.call(recommendedProduct);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(
                      product: recommendedProduct,
                      quantity: 0,
                      onAdd: () => onAddProduct?.call(recommendedProduct),
                      onRemove: () {},
                      onAddProduct: onAddProduct,
                      onViewed: onViewed,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final void Function(Product product)? onAddProduct;
  final void Function(Product product)? onViewed;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.onAddProduct,
    this.onViewed,
  });

  String get description {
    final text = (product.description ?? '').trim();
    return text.isEmpty ? 'Fresh natural harvest from the farm.' : text;
  }

  String get farmLine {
    final parts = <String>[
      if ((product.farmName ?? '').trim().isNotEmpty) product.farmName!.trim(),
      if ((product.parish ?? '').trim().isNotEmpty) product.parish!.trim(),
    ];

    return parts.isEmpty
        ? 'The Harvest Place Ja partner farm'
        : parts.join(' • ');
  }

  String get farmerLine {
    final farmer = (product.farmerName ?? '').trim();
    return farmer.isEmpty ? 'Verified The Harvest Place Ja seller' : farmer;
  }

  String storageTip() {
    final text = '${product.name} ${product.category}'.toLowerCase();

    if (text.contains('lettuce') ||
        text.contains('callaloo') ||
        text.contains('herb') ||
        text.contains('leaf')) {
      return 'Keep chilled, lightly wrapped, and use within a few days for best freshness.';
    }

    if (text.contains('egg')) {
      return 'Keep refrigerated and store in the carton until ready to use.';
    }

    if (text.contains('yam') ||
        text.contains('potato') ||
        text.contains('pumpkin') ||
        text.contains('plantain') ||
        text.contains('banana')) {
      return 'Store in a cool, dry place away from direct sunlight.';
    }

    if (text.contains('honey')) {
      return 'Store sealed at room temperature. Natural crystallization is normal.';
    }

    return 'Store in a cool place and use while fresh for the best flavor.';
  }

  String recipeIdea() {
    final text = '${product.name} ${product.category}'.toLowerCase();

    if (text.contains('callaloo')) {
      return 'Steam with onion, thyme, sweet pepper, and a little coconut oil.';
    }

    if (text.contains('lettuce')) {
      return 'Use in fresh salads, wraps, sandwiches, or as a crisp side.';
    }

    if (text.contains('egg')) {
      return 'Great for breakfast, baking, fried rice, or protein-rich meal prep.';
    }

    if (text.contains('pumpkin')) {
      return 'Perfect for soup, roasted sides, porridge, or vegetable stews.';
    }

    if (text.contains('pepper')) {
      return 'Add to soups, sauces, seasoning blends, or stir-fried vegetables.';
    }

    if (text.contains('fruit') ||
        text.contains('banana') ||
        text.contains('pineapple') ||
        text.contains('mango')) {
      return 'Enjoy fresh, blend into smoothies, or add to breakfast bowls.';
    }

    return 'Add it to your weekly farm box and pair with other fresh local items.';
  }

  Widget badge({
    required IconData icon,
    required String label,
    Color color = FarmColors.green,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget detailTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return FarmCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: FarmColors.lightGreen,
            foregroundColor: FarmColors.primary,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FarmColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = (product.unit ?? '').trim();
    final inStock = product.canAddToCart;

    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        backgroundColor: FarmColors.background,
        elevation: 0,
        title: Text(product.name),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            Container(
              decoration: BoxDecoration(
                color: FarmColors.surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: FarmColors.shadow.withOpacity(0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Row(
                      children: [
                        badge(
                          icon: Icons.eco_outlined,
                          label: 'Farm Fresh',
                          color: FarmColors.green,
                        ),
                        const SizedBox(width: 8),
                        if (product.isOrganic)
                          badge(
                            icon: Icons.eco_outlined,
                            label: 'Organic',
                            color: FarmColors.green,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                    child: Hero(
                      tag: 'product-${product.id}',
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: ProductVisual(product: product, size: 130),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FarmCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    farmLine,
                    style: const TextStyle(
                      color: FarmColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.42,
                      color: FarmColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ProductTrustBadges(product: product, compact: false),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      badge(
                          icon: Icons.category_outlined,
                          label: product.category),
                      badge(
                        icon: Icons.inventory_2_outlined,
                        label: inStock
                            ? '${product.stockQuantity} in stock'
                            : 'Out of stock',
                        color: inStock ? FarmColors.green : FarmColors.error,
                      ),
                      if (unit.isNotEmpty)
                        badge(icon: Icons.scale_outlined, label: unit),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DiscountPriceText(product: product),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FreshnessScoreCard(product: product),
            if (product.isLowStock) ...[
              const SizedBox(height: 14),
              FarmCard(
                color: FarmColors.dangerSoft,
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_outlined,
                        color: FarmColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${product.lowStockLabel} — order soon while this batch lasts.',
                        style: const TextStyle(
                          color: FarmColors.danger,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (product.hasSubscribeSave) ...[
              const SizedBox(height: 14),
              SubscribeSaveButton(product: product),
            ],
            const SizedBox(height: 14),
            FrequentlyBoughtTogetherSection(
              product: product,
              onAddProduct: onAddProduct,
              onViewed: onViewed,
            ),
            const SizedBox(height: 14),
            RecommendedForYouDetailSection(
              currentProduct: product,
              onAddProduct: onAddProduct,
              onViewed: onViewed,
            ),
            const SizedBox(height: 14),
            detailTile(
              icon: Icons.storefront_outlined,
              title: 'Farm / Seller',
              value: '$farmerLine\n$farmLine',
            ),
            const SizedBox(height: 12),
            detailTile(
              icon: Icons.kitchen_outlined,
              title: 'Storage tip',
              value: storageTip(),
            ),
            const SizedBox(height: 12),
            detailTile(
              icon: Icons.restaurant_menu_outlined,
              title: 'Recipe idea',
              value: recipeIdea(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: FarmColors.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: quantity <= 0
              ? (inStock
                  ? PrimaryFarmButton(
                      label: 'Add to My Box',
                      onPressed: onAdd,
                    )
                  : NotifyMeWhenReadyButton(product: product))
              : Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: FarmColors.lightGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.remove),
                          color: FarmColors.green,
                        ),
                      ),
                      Text(
                        '$quantity in My Box',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: FarmColors.green,
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          onPressed: inStock ? onAdd : null,
                          icon: const Icon(Icons.add),
                          color: FarmColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onFavorite;
  final VoidCallback? onViewed;
  final bool isFavorite;
  final int quantity;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
    required this.onRemove,
    this.onIncrease,
    this.onDecrease,
    this.onFavorite,
    this.onViewed,
    this.isFavorite = false,
    this.quantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    final description = (product.description ?? '').trim().isEmpty
        ? 'Fresh natural harvest from the farm.'
        : product.description!.trim();
    final unit = (product.unit ?? '').trim();
    final inStock = product.canAddToCart;

    return InkWell(
      onTap: () {
        onViewed?.call();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              quantity: quantity,
              onAdd: onIncrease ?? onAdd,
              onRemove: onDecrease ?? onRemove,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: FarmColors.shadow.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: 'product-${product.id}',
                      child: ProductVisual(
                        product: product,
                        size: 58,
                      ),
                    ),
                  ),
                  if (onFavorite != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorite
                                ? FarmColors.danger
                                : FarmColors.green,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ((product.farmName ?? '').trim().isNotEmpty ||
                (product.parish ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                [product.farmName, product.parish]
                    .where((item) => (item ?? '').trim().isNotEmpty)
                    .join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: FarmColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                color: FarmColors.mutedText,
              ),
            ),
            const SizedBox(height: 8),
            ProductTrustBadges(product: product, compact: true),
            if (product.isLowStock) ...[
              const SizedBox(height: 6),
              Text(
                product.lowStockLabel,
                style: const TextStyle(
                  color: FarmColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        inStock ? FarmColors.lightGreen : FarmColors.dangerSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    inStock
                        ? '${product.stockQuantity} in stock'
                        : 'Out of stock',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: inStock ? FarmColors.green : FarmColors.danger,
                    ),
                  ),
                ),
                if (unit.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FarmColors.cream,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FarmColors.mutedText,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DiscountPriceText(product: product, compact: true),
                ),
                const Icon(Icons.star, size: 14, color: Color(0xFFF2B705)),
                const SizedBox(width: 2),
                Text(
                  '4.8',
                  style: TextStyle(
                    fontSize: 11,
                    color: FarmColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (quantity <= 0)
              inStock
                  ? SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 16),
                        label:
                            const Text('Add', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FarmColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    )
                  : NotifyMeWhenReadyButton(product: product, compact: true)
            else
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: FarmColors.lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onDecrease ?? onRemove,
                        icon: const Icon(Icons.remove, size: 18),
                        color: FarmColors.green,
                      ),
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: FarmColors.green,
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: inStock ? (onIncrease ?? onAdd) : null,
                        icon: const Icon(Icons.add, size: 18),
                        color: FarmColors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProductVisual extends StatelessWidget {
  final Product product;
  final double size;

  const ProductVisual({super.key, required this.product, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl = cleanHostedImageUrl(product.imageUrl);
    final visualSize = size + 18;

    Widget fallbackVisual() {
      return Container(
        height: visualSize,
        width: visualSize,
        decoration: BoxDecoration(
          color: FarmColors.chipBackground,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(product.icon, style: TextStyle(fontSize: size)),
        ),
      );
    }

    if (imageUrl == null) return fallbackVisual();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl,
        height: visualSize,
        width: visualSize,
        fit: BoxFit.cover,
        cacheWidth: visualSize.round() * 2,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: visualSize,
            width: visualSize,
            decoration: BoxDecoration(
              color: FarmColors.chipBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => fallbackVisual(),
      ),
    );
  }
}

class MiniProduct extends StatelessWidget {
  final Product product;

  const MiniProduct({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          ProductVisual(product: product, size: 38),
          const Spacer(),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          DiscountPriceText(product: product, compact: true),
        ],
      ),
    );
  }
}

class FarmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? color;

  const FarmCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? FarmColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: FarmColors.line,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 22,
        height: 1.1,
        fontWeight: FontWeight.w900,
        color: FarmColors.ink,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FarmColors.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class CategoryPill extends StatelessWidget {
  final String icon;
  final String label;

  const CategoryPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Text(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      backgroundColor: FarmColors.chipBackground,
      side: const BorderSide(color: FarmColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}

class TraceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const TraceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: FarmColors.green),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
    );
  }
}

class OrderCard extends StatelessWidget {
  final String order;
  final String status;
  final String type;
  final String total;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.status,
    required this.type,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: FarmCard(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order $order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Chip(
                    label: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: FarmColors.lightGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              type,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Tap to view receipt and tracking'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Total'),
                const Spacer(),
                Flexible(
                  child: Text(
                    total,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final double total;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.total,
  });

  String get shortOrderId {
    if (orderId.length <= 6) return orderId;
    return orderId.substring(0, 6).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 110,
                width: 110,
                decoration: const BoxDecoration(
                  color: FarmColors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 62,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Order placed successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Order #$shortOrderId has been sent to the farm.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FarmColors.mutedText,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: J\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: FarmColors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              PrimaryFarmButton(
                label: 'View My Orders',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Back to app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final List<CartLine> cartLines;
  final double subtotal;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cartLines,
    required this.subtotal,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final notesController = TextEditingController();
  final bankReferenceController = TextEditingController();
  final couponController = TextEditingController();

  bool loading = false;
  bool applyingCoupon = false;
  String? appliedCouponCode;
  double discountAmount = 0;
  CustomerProfile? savedProfile;
  String fulfillmentType = 'pickup';
  String paymentMethod = 'cash_on_pickup';
  String deliveryZone = 'Kingston / St. Andrew';
  DateTime? scheduledDate;
  TimeOfDay? scheduledTime;

  final Map<String, double> deliveryFees = const {
    'Kingston / St. Andrew': 800.0,
    'St. Catherine': 1000.0,
    'St. Elizabeth': 1200.0,
    'Manchester': 1300.0,
    'Clarendon': 1400.0,
    'Montego Bay / St. James': 1800.0,
    'Other Parish': 2000.0,
  };

  double get deliveryFee =>
      fulfillmentType == 'delivery' ? (deliveryFees[deliveryZone] ?? 0.0) : 0.0;

  double get checkoutTotal {
    final total = widget.subtotal + deliveryFee - discountAmount;
    return total < 0 ? 0 : total;
  }

  String get scheduledDateText {
    final date = scheduledDate;
    if (date == null) return 'Choose date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get scheduledTimeText {
    if (scheduledTime == null) return 'Choose time';
    final hour = scheduledTime!.hour.toString().padLeft(2, '0');
    final minute = scheduledTime!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    nameController.text = user?.userMetadata?['full_name']?.toString() ?? '';
    final now = DateTime.now();
    final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    final nextFriday = now.add(
      Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday),
    );

    scheduledDate = DateTime(
      nextFriday.year,
      nextFriday.month,
      nextFriday.day,
    );

    scheduledTime = const TimeOfDay(hour: 16, minute: 0);
    loadSavedCustomerProfile();
  }

  Future<void> loadSavedCustomerProfile() async {
    final profile = await fetchCurrentCustomerProfile();
    if (!mounted || profile == null) return;
    setState(() {
      savedProfile = profile;
      if (nameController.text.trim().isEmpty) {
        nameController.text = profile.fullName;
      }
      phoneController.text = profile.phone;
      addressController.text = profile.address;
    });
  }

  void useSavedDeliveryAddress() {
    final profile = savedProfile;
    if (profile == null) return;
    setState(() {
      if (profile.fullName.isNotEmpty) nameController.text = profile.fullName;
      if (profile.phone.isNotEmpty) phoneController.text = profile.phone;
      if (profile.address.isNotEmpty) addressController.text = profile.address;
      fulfillmentType = 'delivery';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved delivery address selected.')),
    );
  }

  Future<void> applyCoupon() async {
    final code = couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a promo code.')),
      );
      return;
    }

    setState(() => applyingCoupon = true);
    try {
      final validation = await validateCouponForCheckout(
        code: code,
        orderTotal: widget.subtotal,
      );

      if (!validation.valid || validation.discountAmount <= 0) {
        setState(() {
          appliedCouponCode = null;
          discountAmount = 0;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              validation.message.isEmpty
                  ? 'Promo code could not be applied.'
                  : validation.message,
            ),
          ),
        );
        return;
      }

      setState(() {
        appliedCouponCode = validation.code ?? code;
        discountAmount = validation.discountAmount;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promo applied: ${validation.label}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Coupon check failed: ${friendlyAppError(error)}')),
      );
    } finally {
      if (mounted) setState(() => applyingCoupon = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
    bankReferenceController.dispose();
    couponController.dispose();
    super.dispose();
  }

  Future<void> placeOrder() async {
    if (!isLoggedIn) {
      final allowed = await requireLoginForCheckout(context);
      if (!mounted || !allowed) return;
    }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final notes = notesController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your name and phone number.')),
      );
      return;
    }

    if (fulfillmentType == 'delivery' && address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address.')),
      );
      return;
    }

    if (scheduledDate == null || scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please choose a pickup or delivery date and time.')),
      );
      return;
    }

    if (paymentMethod == 'bank_transfer' &&
        bankReferenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your bank transfer reference number.'),
        ),
      );
      return;
    }

    SecureCartQuote secureQuote;
    try {
      secureQuote = await fetchSecureCartQuote(widget.cartLines);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final signedInUser = supabase.auth.currentUser;
      if (signedInUser == null) {
        throw Exception('Please sign in before placing an order.');
      }

      final secureSubtotal = secureQuote.subtotal;
      final requestedCouponCode = couponController.text.trim().isEmpty
          ? null
          : couponController.text.trim().toUpperCase();
      var trustedCouponCode = requestedCouponCode == null
          ? null
          : (appliedCouponCode ?? requestedCouponCode);
      var trustedDiscountAmount =
          requestedCouponCode == null ? 0.0 : discountAmount;
      var total = (secureSubtotal + deliveryFee - trustedDiscountAmount)
          .clamp(0, double.infinity)
          .toDouble();
      final selectedPaymentMethod =
          fulfillmentType == 'delivery' && paymentMethod == 'cash_on_pickup'
              ? 'cash_on_delivery'
              : paymentMethod;
      final selectedPaymentStatus = selectedPaymentMethod == 'bank_transfer'
          ? 'pending_verification'
          : 'unpaid';
      final bankReference = selectedPaymentMethod == 'bank_transfer'
          ? bankReferenceController.text.trim()
          : null;

      final customerPayload = <String, dynamic>{
        'full_name': name,
        'name': name,
        'phone': phone,
        'email': signedInUser.email,
        'address': fulfillmentType == 'delivery' ? address : null,
        'fulfillment_type': fulfillmentType,
        'delivery_address': fulfillmentType == 'delivery' ? address : null,
        'delivery_zone': fulfillmentType == 'delivery' ? deliveryZone : null,
        'scheduled_date': scheduledDateText,
        'scheduled_time': scheduledTimeText,
        'delivery_status':
            fulfillmentType == 'delivery' ? 'pending' : 'ready_for_pickup',
        'subtotal': secureSubtotal,
        'delivery_fee': deliveryFee,
        'discount_code': trustedCouponCode,
        'discount_amount': trustedDiscountAmount,
        'payment_status': selectedPaymentStatus,
        'bank_reference': bankReference,
      };

      final rpcItems = secureQuote.lines.map((line) {
        return <String, dynamic>{
          'product_id': line.product.id,
          'quantity': line.quantity,
        };
      }).toList();

      final checkoutNotes = <String>[
        if (notes.isNotEmpty) notes,
        'Fulfillment: ${formatFulfillmentType(fulfillmentType)}',
        if (fulfillmentType == 'delivery') 'Delivery zone: $deliveryZone',
        if (fulfillmentType == 'delivery') 'Delivery address: $address',
        'Scheduled: $scheduledDateText $scheduledTimeText',
        if (bankReference != null && bankReference.isNotEmpty)
          'Bank reference: $bankReference',
        if (requestedCouponCode != null && requestedCouponCode.isNotEmpty)
          'Promo requested: $requestedCouponCode',
      ].join('\n');

      final checkoutRpc = requestedCouponCode == null
          ? 'secure_checkout'
          : 'secure_checkout_with_coupon';
      final checkoutParams = <String, dynamic>{
        'p_customer': customerPayload,
        'p_items': rpcItems,
        'p_payment_method': selectedPaymentMethod,
        'p_notes': checkoutNotes.isEmpty ? null : checkoutNotes,
      };

      if (requestedCouponCode != null) {
        checkoutParams['p_coupon_code'] = requestedCouponCode;
      }

      final checkoutResponse = await supabase.rpc(
        checkoutRpc,
        params: checkoutParams,
      );

      if (checkoutResponse is! Map) {
        throw Exception(
            'Checkout completed, but the server response was invalid.');
      }

      final checkoutResult = Map<String, dynamic>.from(checkoutResponse);
      final orderId = (checkoutResult['order_id'] ?? '').toString();
      if (orderId.isEmpty) {
        throw Exception('Checkout completed, but no order ID was returned.');
      }

      if (checkoutResult['coupon_applied'] == true) {
        trustedCouponCode =
            (checkoutResult['coupon_code'] ?? trustedCouponCode ?? '')
                .toString();
        trustedDiscountAmount = Product._toDouble(
          checkoutResult['discount_amount'],
        );
        total = (secureSubtotal + deliveryFee - trustedDiscountAmount)
            .clamp(0, double.infinity)
            .toDouble();
      } else if (requestedCouponCode == null) {
        trustedCouponCode = null;
        trustedDiscountAmount = 0;
        total = (secureSubtotal + deliveryFee).toDouble();
      }

      final orderMetadata = <String, dynamic>{
        'fulfillment_type': fulfillmentType,
        'delivery_address': fulfillmentType == 'delivery' ? address : null,
        'delivery_zone': fulfillmentType == 'delivery' ? deliveryZone : null,
        'scheduled_date': scheduledDateText,
        'scheduled_time': scheduledTimeText,
        'delivery_status':
            fulfillmentType == 'delivery' ? 'pending' : 'ready_for_pickup',
        'subtotal': secureSubtotal,
        'delivery_fee': deliveryFee,
        'discount_code': trustedCouponCode,
        'discount_amount': trustedDiscountAmount,
        'total': total,
        'payment_status': selectedPaymentStatus,
        'payment_method': selectedPaymentMethod,
        'bank_reference': bankReference,
        'notes': checkoutNotes.isEmpty ? null : checkoutNotes,
      };

      try {
        await supabase.from('orders').update(orderMetadata).eq('id', orderId);
      } catch (error) {
        debugPrint('Checkout metadata update skipped: $error');
      }

      await createOrderConfirmationSupport(
        orderId: orderId,
        customerName: name,
        customerPhone: phone,
        customerEmail: signedInUser.email,
        total: total,
      );

      final orderShortId = orderId.length >= 6
          ? orderId.substring(0, 6).toUpperCase()
          : orderId.toUpperCase();

      showBrowserNotification(
        title: 'Order placed',
        body:
            'Your order #$orderShortId from The Harvest Place Ja was sent to the farm.',
      );

      if (!mounted) return;

      widget.onOrderPlaced();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: orderId,
            total: total,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${friendlyAppError(error)}')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _checkoutRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: strong ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: FarmColors.background,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            const Header(
              title: 'Checkout',
              subtitle: 'Complete your farm order',
            ),
            const SizedBox(height: 18),
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...widget.cartLines.map(
                    (line) => _checkoutRow(
                      '${line.product.name} x ${line.quantity}',
                      'J\$${(line.product.effectivePrice * line.quantity).toStringAsFixed(2)}',
                    ),
                  ),
                  if (deliveryFee > 0)
                    _checkoutRow(
                      'Delivery fee',
                      'J\$${deliveryFee.toStringAsFixed(2)}',
                    ),
                  if (discountAmount > 0)
                    _checkoutRow(
                      'Discount ${appliedCouponCode ?? ''}',
                      '-J\$${discountAmount.toStringAsFixed(2)}',
                    ),
                  const Divider(),
                  _checkoutRow(
                    'Total',
                    'J\$${checkoutTotal.toStringAsFixed(2)}',
                    strong: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Payment status: Unpaid until collected or paid online',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: fulfillmentType,
                    items: const [
                      DropdownMenuItem(
                        value: 'pickup',
                        child: Text('Farm Pickup',
                            overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'delivery',
                        child: Text('Home Delivery',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => fulfillmentType = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Pickup or delivery',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (fulfillmentType == 'delivery') ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: deliveryZone,
                      items: deliveryFees.keys
                          .map(
                            (zone) => DropdownMenuItem(
                              value: zone,
                              child: Text(
                                '$zone • J\$${deliveryFees[zone]!.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => deliveryZone = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Delivery parish / zone',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _selectionButton(
                        icon: Icons.calendar_month,
                        label: scheduledDateText,
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(now.year, now.month, now.day),
                            lastDate: now.add(const Duration(days: 30)),
                            initialDate: scheduledDate ??
                                DateTime(now.year, now.month, now.day),
                          );
                          if (picked != null) {
                            setState(() => scheduledDate = picked);
                          }
                        },
                      ),
                      _selectionButton(
                        icon: Icons.schedule,
                        label: scheduledTimeText,
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: scheduledTime ??
                                const TimeOfDay(hour: 16, minute: 0),
                          );
                          if (picked != null) {
                            setState(() => scheduledTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 180, maxWidth: 520),
                        child: TextField(
                          controller: couponController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Promo code',
                            prefixIcon:
                                Icon(Icons.confirmation_number_outlined),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: applyingCoupon ? null : applyCoupon,
                        child: Text(applyingCoupon ? 'Applying...' : 'Apply'),
                      ),
                    ],
                  ),
                  if (discountAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Promo ${appliedCouponCode ?? ''} applied: -J\$${discountAmount.toStringAsFixed(2)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FarmColors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: paymentMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'cash_on_pickup',
                        child: Text('Cash on Pickup',
                            overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'cash_on_delivery',
                        child: Text('Cash on Delivery',
                            overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Bank Transfer',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => paymentMethod = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  if (paymentMethod == 'bank_transfer') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FarmColors.lightGreen,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bank Transfer Instructions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text('Bank: Add your farm bank name', maxLines: 2),
                          Text('Account Name: The Harvest Place Ja',
                              maxLines: 2),
                          Text('Account Number: Add account number',
                              maxLines: 2),
                          Text('After transfer, enter the reference below.',
                              maxLines: 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: bankReferenceController,
                      decoration: const InputDecoration(
                        labelText: 'Bank transfer reference number',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (savedProfile != null &&
                      (savedProfile!.address.trim().isNotEmpty ||
                          savedProfile!.phone.trim().isNotEmpty)) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FarmColors.lightGreen,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Saved delivery details',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          if (savedProfile!.address.trim().isNotEmpty)
                            Text(
                              savedProfile!.address,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (savedProfile!.phone.trim().isNotEmpty)
                            Text(
                              'Phone: ${savedProfile!.phone}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.location_on_outlined),
                                label: const Text('Use saved address'),
                                onPressed: useSavedDeliveryAddress,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: addressController,
                    enabled: fulfillmentType == 'delivery',
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: fulfillmentType == 'delivery'
                          ? 'Delivery address'
                          : 'Delivery address (not needed for pickup)',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Order notes (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            PrimaryFarmButton(
              label: loading
                  ? 'Placing order...'
                  : 'Place Order • J\$${checkoutTotal.toStringAsFixed(2)}',
              onPressed: loading ? null : placeOrder,
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;
    final profile = await fetchCurrentCustomerProfile();
    if (!mounted) return;
    setState(() {
      nameController.text = profile?.fullName ??
          user?.userMetadata?['full_name']?.toString() ??
          '';
      phoneController.text = profile?.phone ?? '';
      addressController.text = profile?.address ?? '';
      loading = false;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and phone are required.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await saveCurrentCustomerProfile(
        fullName: name,
        phone: phone,
        address: address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const GuestProtectedScreen(
        title: 'Profile',
        subtitle: 'Saved customer details',
        message: 'Sign in to save and manage your customer profile.',
      );
    }

    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: const Text('Customer Profile'),
        backgroundColor: FarmColors.background,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Header(
                  title: 'Profile',
                  subtitle: 'Saved contact & delivery info',
                ),
                const SizedBox(height: 16),
                FarmCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Default delivery address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryFarmButton(
                  label: saving ? 'Saving...' : 'Save Profile',
                  onPressed: saving ? null : saveProfile,
                ),
              ],
            ),
    );
  }
}

class AdminCouponsTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onChanged;

  const AdminCouponsTab({
    super.key,
    required this.refreshKey,
    required this.onChanged,
  });

  @override
  State<AdminCouponsTab> createState() => _AdminCouponsTabState();
}

class _AdminCouponsTabState extends State<AdminCouponsTab> {
  Future<void> openCouponCreator(BuildContext context) async {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final minimumController = TextEditingController();
    String discountType = 'fixed';
    bool isActive = true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveCoupon() async {
              final code = codeController.text.trim().toUpperCase();
              final value = double.tryParse(valueController.text.trim());
              final minimumText = minimumController.text.trim();
              final minimum =
                  minimumText.isEmpty ? null : double.tryParse(minimumText);

              if (code.isEmpty || value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Enter coupon code and valid discount value.'),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                await createCoupon(
                  code: code,
                  discountType: discountType,
                  discountValue: value,
                  minimumOrder: minimum,
                  isActive: isActive,
                );
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coupon created')),
                  );
                }
                widget.onChanged();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not create coupon: $error')),
                  );
                }
              } finally {
                if (context.mounted) setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              title: const Text('Create Coupon'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Code, for example FARM10',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: discountType,
                      decoration:
                          const InputDecoration(labelText: 'Discount type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'fixed', child: Text('Fixed amount')),
                        DropdownMenuItem(
                            value: 'percent', child: Text('Percentage')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => discountType = value ?? 'fixed'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: discountType == 'percent'
                            ? 'Percent value, for example 10'
                            : 'Fixed value, for example 500',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: minimumController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum order amount optional',
                      ),
                    ),
                    SwitchListTile(
                      value: isActive,
                      activeColor: FarmColors.green,
                      title: const Text('Active'),
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : saveCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Coupon>>(
      key: ValueKey('coupons-${widget.refreshKey}'),
      future: fetchCoupons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }

        final coupons = snapshot.data ?? [];
        final activeCount = coupons.where((coupon) => coupon.isActive).length;

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coupon Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${coupons.length} coupons • $activeCount active'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Coupon'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => openCouponCreator(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (coupons.isEmpty)
              const FarmCard(child: Text('No coupons created yet.'))
            else
              ...coupons.map(
                (coupon) => FarmCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: FarmColors.lightGreen,
                        child: Icon(Icons.confirmation_number_outlined,
                            color: FarmColors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coupon.code,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(coupon.label),
                            if ((coupon.minimumOrder ?? 0) > 0)
                              Text(
                                  'Minimum: J\$${coupon.minimumOrder!.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      Switch(
                        value: coupon.isActive,
                        activeColor: FarmColors.green,
                        onChanged: coupon.id.isEmpty
                            ? null
                            : (value) async {
                                try {
                                  await updateCouponAvailability(
                                      coupon.id, value);
                                  widget.onChanged();
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Could not update coupon: $error'),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SecurityAuditScreen extends StatelessWidget {
  const SecurityAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checks = const [
      SecurityAuditItem(
        title: 'Authentication',
        status: 'Active',
        detail:
            'Supabase Auth is used for sign-in, registration, password reset, and protected app access.',
        icon: Icons.lock_outline,
      ),
      SecurityAuditItem(
        title: 'Admin access',
        status: 'Review',
        detail:
            'Admin access checks exist. For production, move fully to the admin_users table and remove hardcoded fallback emails.',
        icon: Icons.admin_panel_settings_outlined,
      ),
      SecurityAuditItem(
        title: 'Customer data',
        status: 'Active',
        detail:
            'Customer profile, order, support, and notification data should remain protected by Supabase Row Level Security policies.',
        icon: Icons.privacy_tip_outlined,
      ),
      SecurityAuditItem(
        title: 'Checkout safety',
        status: 'Active',
        detail:
            'Checkout now uses a secure server RPC so order creation, item inserts, stock reduction, payouts, loyalty, and the order notification happen together.',
        icon: Icons.verified_outlined,
      ),
      SecurityAuditItem(
        title: 'Notifications',
        status: 'Active',
        detail:
            'Notifications are filtered for the current user email when available.',
        icon: Icons.notifications_active_outlined,
      ),
      SecurityAuditItem(
        title: 'Production readiness',
        status: 'Next step',
        detail:
            'Before launch, confirm RLS policies for products, orders, customers, support_tickets, notifications, admin_users, and product_reviews.',
        icon: Icons.shield_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(title: const Text('Security Audit')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [FarmColors.deepGreen, FarmColors.green],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: FarmColors.green.withOpacity(0.20),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_outlined, color: Colors.white, size: 34),
                  SizedBox(height: 14),
                  Text(
                    'Security & trust overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A customer-friendly checklist for safety, privacy, and production readiness.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...checks.map((item) => SecurityAuditTile(item: item)),
            const SizedBox(height: 12),
            FarmCard(
              color: FarmColors.lightGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Recommended final launch checks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 10),
                  Text('• Enable strict Supabase RLS policies.'),
                  Text('• Remove hardcoded admin fallback emails.'),
                  Text('• Rotate keys if they were exposed publicly.'),
                  Text(
                      '• Confirm refund, privacy, and terms pages are visible.'),
                  Text(
                      '• Test checkout, stock reduction, and order notifications.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecurityAuditItem {
  final String title;
  final String status;
  final String detail;
  final IconData icon;

  const SecurityAuditItem({
    required this.title,
    required this.status,
    required this.detail,
    required this.icon,
  });
}

class SecurityAuditTile extends StatelessWidget {
  final SecurityAuditItem item;

  const SecurityAuditTile({super.key, required this.item});

  Color get statusColor {
    switch (item.status.toLowerCase()) {
      case 'active':
        return FarmColors.green;
      case 'review':
        return FarmColors.warning;
      default:
        return FarmColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: FarmColors.lightGreen,
            foregroundColor: FarmColors.primary,
            child: Icon(item.icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.detail,
                  style: TextStyle(color: FarmColors.mutedText, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PolicyScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const PolicyScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: FarmColors.background,
      ),
      body: FarmPage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            Header(title: title, subtitle: subtitle),
            const SizedBox(height: 16),
            FarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const PolicySection({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(height: 1.45, color: FarmColors.text),
          ),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyScreenShell(
      title: 'Terms of Service',
      subtitle: 'How The Harvest Place Ja works',
      children: [
        PolicySection(
          title: 'Using the app',
          body:
              'The Harvest Place Ja connects customers with available farm products, pickup options, delivery options, order tracking, and support tools. You are responsible for keeping your account information accurate and secure.',
        ),
        PolicySection(
          title: 'Product availability and pricing',
          body:
              'Fresh products may change based on harvest, season, weather, and stock. Prices, quantities, descriptions, and availability may be updated at any time before checkout.',
        ),
        PolicySection(
          title: 'Orders, pickup, and delivery',
          body:
              'Orders are accepted based on available stock and selected fulfillment method. Pickup or delivery windows may be adjusted for safety, weather, farm operations, or customer communication needs.',
        ),
        PolicySection(
          title: 'Payment and acceptable use',
          body:
              'Customers agree to provide accurate payment and contact information. Abuse, fraud, false orders, or attempts to disrupt the app may result in account restriction or order cancellation.',
        ),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyScreenShell(
      title: 'Privacy Policy',
      subtitle: 'How customer data is handled',
      children: [
        PolicySection(
          title: 'Information collected',
          body:
              'The app may collect account details, name, email, phone number, delivery address, order history, support messages, reviews, notification status, and product preferences such as favorites.',
        ),
        PolicySection(
          title: 'How information is used',
          body:
              'Information is used to create accounts, process orders, confirm pickup or delivery, provide customer support, send order notifications, improve product availability, and personalize the shopping experience.',
        ),
        PolicySection(
          title: 'Storage and protection',
          body:
              'App data is stored through Supabase/backend services. Access should be protected with authentication, role-based admin controls, and database security rules.',
        ),
        PolicySection(
          title: 'Your rights',
          body:
              'Customers may request updates to their profile information, support history, or account details by contacting farm support through the app.',
        ),
      ],
    );
  }
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyScreenShell(
      title: 'Refund Policy',
      subtitle: 'Fresh goods and order support',
      children: [
        PolicySection(
          title: 'Fresh and perishable goods',
          body:
              'Because many products are fresh or perishable, refund requests are reviewed based on product condition, timing, pickup or delivery status, and available order evidence.',
        ),
        PolicySection(
          title: 'Damaged, missing, or incorrect items',
          body:
              'If an item is damaged, missing, or incorrect, contact support as soon as possible with your order details. The farm may offer replacement, store credit, partial refund, or refund after review.',
        ),
        PolicySection(
          title: 'Cancellations',
          body:
              'Cancellation approval depends on whether the order has already been prepared, packed, picked up, or sent for delivery.',
        ),
        PolicySection(
          title: 'Pickup and delivery issues',
          body:
              'Missed pickup windows, incorrect addresses, unreachable customers, or failed delivery attempts may affect refund eligibility. Contact support for review.',
        ),
      ],
    );
  }
}

class PrimaryFarmButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryFarmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  State<PrimaryFarmButton> createState() => _PrimaryFarmButtonState();
}

class _PrimaryFarmButtonState extends State<PrimaryFarmButton> {
  bool _tapLocked = false;

  void _handlePressed() {
    final action = widget.onPressed;
    if (action == null || _tapLocked) return;

    setState(() => _tapLocked = true);

    try {
      action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyAppError(error))),
        );
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _tapLocked = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !_tapLocked;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: FarmColors.green.withOpacity(0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? FarmColors.green : FarmColors.line,
          foregroundColor: isEnabled ? Colors.white : FarmColors.muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: isEnabled ? _handlePressed : null,
        child: widget.icon == null
            ? Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AdminFarmerManagementTab extends StatelessWidget {
  final int refreshKey;
  final VoidCallback onChanged;
  const AdminFarmerManagementTab(
      {super.key, required this.refreshKey, required this.onChanged});

  Future<void> setStatus(
      BuildContext context, FarmerProfile farmer, String status) async {
    try {
      await updateFarmerVerification(farmer.id, status);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${farmer.farmName} marked ${_friendlyStatus(status)}.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Farmer update failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FarmerProfile>>(
      key: ValueKey('admin-farmers-$refreshKey'),
      future: fetchFarmerProfiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.expand(child: SkeletonList(count: 3));
        }
        final farmers = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            const Header(
                title: 'Farmer Management',
                subtitle: 'Approve Jamaican farmers and farms'),
            const SizedBox(height: 16),
            if (farmers.isEmpty)
              const FarmEmptyState(
                icon: Icons.agriculture_outlined,
                title: 'No farmer applications',
                message:
                    'Farmer applications will appear here after users register as farmers and complete onboarding.',
              )
            else
              ...farmers.map((farmer) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FarmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: FarmColors.lightGreen,
                                child: const Icon(Icons.agriculture_outlined,
                                    color: FarmColors.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(farmer.farmName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${farmer.farmerName} • ${farmer.parish}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    if (farmer.bio.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(farmer.bio,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ),
                              Chip(label: Text(farmer.statusLabel)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TraceRow(
                              icon: Icons.phone_outlined,
                              title: 'Phone',
                              value: farmer.phone),
                          TraceRow(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Payout',
                              value: farmer.payoutMethod.isEmpty
                                  ? 'Not provided'
                                  : farmer.payoutMethod),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Approve'),
                                onPressed: () =>
                                    setStatus(context, farmer, 'approved'),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.pause_circle_outline),
                                label: const Text('Pending'),
                                onPressed: () =>
                                    setStatus(context, farmer, 'pending'),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Reject'),
                                onPressed: () =>
                                    setStatus(context, farmer, 'rejected'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class AdminPayoutsTab extends StatelessWidget {
  final int refreshKey;
  final VoidCallback onChanged;
  const AdminPayoutsTab(
      {super.key, required this.refreshKey, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FarmerPayout>>(
      key: ValueKey('admin-payouts-$refreshKey'),
      future: fetchFarmerPayouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.expand(child: SkeletonList(count: 3));
        }
        final payouts = snapshot.data ?? [];
        final pending = payouts
            .where((p) => p.payoutStatus == 'pending')
            .fold<double>(0, (sum, p) => sum + p.netAmount);
        final released = payouts
            .where((p) => p.payoutStatus == 'released')
            .fold<double>(0, (sum, p) => sum + p.netAmount);
        final held = payouts
            .where((p) => p.payoutStatus == 'held')
            .fold<double>(0, (sum, p) => sum + p.netAmount);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            const Header(
                title: 'Farmer Payouts',
                subtitle: 'Admin releases farmer earnings'),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              MarketplaceStatCard(
                  icon: Icons.pending_actions,
                  label: 'Pending',
                  value: 'J\$${pending.toStringAsFixed(2)}'),
              MarketplaceStatCard(
                  icon: Icons.verified_outlined,
                  label: 'Released',
                  value: 'J\$${released.toStringAsFixed(2)}'),
              MarketplaceStatCard(
                  icon: Icons.pause_circle_outline,
                  label: 'Held',
                  value: 'J\$${held.toStringAsFixed(2)}'),
            ]),
            const SizedBox(height: 16),
            if (payouts.isEmpty)
              const FarmEmptyState(
                icon: Icons.payments_outlined,
                title: 'No farmer payouts yet',
                message:
                    'Payout records will appear here after marketplace order item payout rows are created.',
              )
            else
              ...payouts.map((payout) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PayoutCard(payout: payout, onChanged: onChanged),
                  )),
          ],
        );
      },
    );
  }
}

class FarmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const FarmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FarmCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: FarmColors.green),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: FarmColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
