import 'package:flutter/material.dart';

/// Design tokens beyond what [ColorScheme] covers.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.panel,
    required this.border,
    required this.borderStrong,
    required this.hover,
    required this.textMuted,
    required this.textFaint,
    required this.sourceLink,
    required this.success,
    required this.warning,
    required this.danger,
    required this.codeBackground,
  });

  /// Background behind the PDF pages.
  final Color canvas;

  /// Sidebar / agent panel surface.
  final Color panel;
  final Color border;
  final Color borderStrong;
  final Color hover;
  final Color textMuted;
  final Color textFaint;
  final Color sourceLink;
  final Color success;
  final Color warning;
  final Color danger;

  /// Behind code blocks.
  final Color codeBackground;

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  static const light = AppTokens(
    canvas: Color(0xFFF3F3F3),
    panel: Color(0xFFF7F7F7),
    border: Color(0xFFDEDEDE),
    borderStrong: Color(0xFFC4C4C4),
    hover: Color(0xFFE9E9E9),
    textMuted: Color(0xFF595959),
    textFaint: Color(0xFF666666),
    sourceLink: Color(0xFF087E82),
    success: Color(0xFF15803D),
    warning: Color(0xFF9B5B08),
    danger: Color(0xFFDC2626),
    codeBackground: Color(0xFFF3F3F3),
  );

  static const dark = AppTokens(
    canvas: Color(0xFF000000),
    panel: Color(0xFF0C0C0C),
    border: Color(0xFF242424),
    borderStrong: Color(0xFF3C3C3C),
    hover: Color(0xFF171717),
    textMuted: Color(0xFFB5B5B5),
    textFaint: Color(0xFF8D8D8D),
    sourceLink: Color(0xFF00AEB3),
    success: Color(0xFFDFF4E2),
    warning: Color(0xFFE7A94B),
    danger: Color(0xFFF87171),
    codeBackground: Color(0xFF171717),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      canvas: l(canvas, other.canvas),
      panel: l(panel, other.panel),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      hover: l(hover, other.hover),
      textMuted: l(textMuted, other.textMuted),
      textFaint: l(textFaint, other.textFaint),
      sourceLink: l(sourceLink, other.sourceLink),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      codeBackground: l(codeBackground, other.codeBackground),
    );
  }
}

/// Text styles the [TextTheme] has no slot for.
@immutable
class AppText extends ThemeExtension<AppText> {
  const AppText({
    required this.chat,
    required this.nav,
    required this.code,
    required this.codeSmall,
    required this.keycap,
    required this.badge,
    required this.math,
  });

  /// The conversation: the lawyer's messages, the agent's replies, the composer.
  final TextStyle chat;

  /// Sidebar rows: projects, chats, commands.
  final TextStyle nav;

  /// Monospace: code blocks, the agent log, raw diffs.
  final TextStyle code;

  /// Monospace detail under a tool step.
  final TextStyle codeSmall;

  /// The key hint next to a command.
  final TextStyle keycap;

  /// A tiny badge on a card.
  final TextStyle badge;

  /// Display math.
  final TextStyle math;

  static AppText of(BuildContext context) =>
      Theme.of(context).extension<AppText>()!;

  @override
  AppText copyWith() => this;

  @override
  AppText lerp(AppText? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppText(
      chat: l(chat, other.chat),
      nav: l(nav, other.nav),
      code: l(code, other.code),
      codeSmall: l(codeSmall, other.codeSmall),
      keycap: l(keycap, other.keycap),
      badge: l(badge, other.badge),
      math: l(math, other.math),
    );
  }
}

class AppTheme {
  AppTheme._();

  /// Theme accents. Document accents remain independently user-selectable.
  static const _lightAccent = Color(0xFF15803D);
  static const _darkAccent = Color(0xFF00AEB3);
  static const actionGreen = Color(0xFF15803D);
  static const mint = Color(0xFFDFF4E2);
  static const cyan = Color(0xFF00AEB3);

  static const radiusXs = 4.0;
  static const radiusIndicator = 2.0;
  static const radiusSm = 8.0;

  /// Content width of the small confirm and prompt dialogs.
  static const dialogWidth = 360.0;
  static const radius = 12.0;
  static const radiusLg = 14.0;
  static const radiusXl = 16.0;

  /// Fully rounded at the heights pills, chips and round buttons have.
  static const radiusPill = 20.0;

  /// Hover, press and small fades.
  static const fast = Duration(milliseconds: 120);

  /// Panels, tabs and modes switching.
  static const normal = Duration(milliseconds: 160);

  /// Layout: the sidebar and the side panel opening, the theme changing.
  static const slow = Duration(milliseconds: 200);

  /// Every button's minimum size: the width is left to its label.
  static const _buttonMinSize = Size(0, 34);

  /// How long the pointer rests on something before its tooltip shows.
  static const _tooltipWait = Duration(milliseconds: 500);

  /// How much of a colour is left when it tints a surface: a faint wash, a badge's, a stronger one, and the line
  /// around a tinted box.
  static const tintFaint = 0.08;
  static const tintSoft = 0.1;
  static const tintStrong = 0.12;
  static const tintBorder = 0.3;

  /// A hover that fades a colour (a row, a drag handle) rather than switching it off.
  static const hoverFade = 0.6;

  /// A sheet of paper: white in both themes, like the PDF it shows, and the shadow it and the preview cast.
  static const paper = Colors.white;
  static final pageShadow = Colors.black.withValues(alpha: tintFaint);

  /// The bar above the chat, the settings and the sidebar.
  static const headerHeight = 48.0;

  /// The side panel's browser-like tabs.
  static const tabStripHeight = 42.0;

  /// The toolbar on top of a side-panel tab.
  static const toolbarHeight = 44.0;

  /// Rows and buttons in toolbars and menus.
  static const controlHeight = 36.0;

  static const monoFont = 'Consolas';
  static const monoFallback = ['Cascadia Mono', 'Menlo', 'monospace'];

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark ? AppTokens.dark : AppTokens.light;
    final accent = isDark ? _darkAccent : _lightAccent;
    final surface = isDark ? const Color(0xFF000000) : Colors.white;
    final onSurface = isDark
        ? const Color(0xFFF3F3F3)
        : const Color(0xFF0C0C0C);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: isDark ? Colors.black : Colors.white,
          primaryContainer: isDark ? tokens.hover : mint,
          onPrimaryContainer: isDark ? mint : const Color(0xFF0C0C0C),
          secondary: isDark ? mint : actionGreen,
          onSecondary: isDark ? Colors.black : Colors.white,
          secondaryContainer: tokens.hover,
          onSecondaryContainer: onSurface,
          tertiary: accent,
          onTertiary: isDark ? Colors.black : Colors.white,
          tertiaryContainer: tokens.hover,
          onTertiaryContainer: onSurface,
          surfaceTint: Colors.transparent,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: tokens.textMuted,
          outline: tokens.borderStrong,
          outlineVariant: tokens.border,
          surfaceContainerLowest: surface,
          surfaceContainerLow: tokens.panel,
          surfaceContainer: tokens.hover,
          surfaceContainerHigh: isDark
              ? const Color(0xFF242424)
              : const Color(0xFFE9E9E9),
          surfaceContainerHighest: isDark
              ? const Color(0xFF303030)
              : const Color(0xFFDEDEDE),
          inverseSurface: isDark
              ? const Color(0xFFF3F3F3)
              : const Color(0xFF171717),
          onInverseSurface: isDark ? const Color(0xFF0C0C0C) : Colors.white,
          inversePrimary: isDark ? actionGreen : cyan,
          error: tokens.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Archivo',
      visualDensity: VisualDensity.compact,
    );

    TextStyle t(double size, FontWeight weight, {Color? color, double? h}) =>
        TextStyle(
          fontFamily: 'Archivo',
          fontSize: size,
          fontWeight: weight,
          color: color ?? onSurface,
          height: h,
          letterSpacing: size >= 18 ? -0.3 : -0.05,
        );

    final text = base.textTheme.copyWith(
      displaySmall: t(28, FontWeight.w700),
      headlineSmall: t(22, FontWeight.w600),
      titleLarge: t(18, FontWeight.w600),
      titleMedium: t(14, FontWeight.w600),
      titleSmall: t(13, FontWeight.w600),
      bodyLarge: t(14, FontWeight.w400, h: 1.5),
      bodyMedium: t(13, FontWeight.w400, h: 1.45),
      bodySmall: t(12, FontWeight.w400, color: tokens.textMuted, h: 1.4),
      labelLarge: t(13, FontWeight.w500),
      labelMedium: t(12, FontWeight.w500),
      labelSmall: t(11, FontWeight.w500, color: tokens.textMuted),
    );

    TextStyle mono(double size, Color color) => TextStyle(
      fontFamily: monoFont,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      height: 1.5,
      color: color,
    );

    final appText = AppText(
      chat: t(15, FontWeight.w400, h: 1.5),
      nav: t(13.5, FontWeight.w400),
      code: mono(12.5, onSurface),
      codeSmall: mono(10.5, tokens.textFaint),
      keycap: t(10.5, FontWeight.w500, color: tokens.textFaint),
      badge: t(10, FontWeight.w700),
      math: t(16, FontWeight.w400),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: text,
      dividerColor: tokens.border,
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      splashFactory: NoSplash.splashFactory,
      hoverColor: tokens.hover,
      focusColor: accent.withValues(alpha: tintStrong),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .25),
        selectionHandleColor: accent,
      ),
      highlightColor: Colors.transparent,
      extensions: [tokens, appText],
      iconTheme: IconThemeData(size: 16, color: tokens.textMuted),
      tooltipTheme: TooltipThemeData(
        waitDuration: _tooltipWait,
        textStyle: t(
          11.5,
          FontWeight.w500,
          color: isDark ? Colors.black : Colors.white,
        ),
        decoration: BoxDecoration(
          color: onSurface,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              shape: shape,
              padding: buttonPadding,
              textStyle: t(13, FontWeight.w500),
              minimumSize: _buttonMinSize,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? tokens.hover
                    : states.contains(WidgetState.hovered)
                    ? mint
                    : actionGreen,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? tokens.textFaint
                    : states.contains(WidgetState.hovered)
                    ? const Color(0xFF0C0C0C)
                    : Colors.white,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          padding: buttonPadding,
          foregroundColor: onSurface,
          side: BorderSide(color: tokens.borderStrong),
          textStyle: t(13, FontWeight.w500),
          minimumSize: _buttonMinSize,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape,
          padding: buttonPadding,
          foregroundColor: onSurface,
          textStyle: t(13, FontWeight.w500),
          minimumSize: _buttonMinSize,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: shape,
          foregroundColor: tokens.textMuted,
          minimumSize: const Size(32, 32),
          fixedSize: const Size(32, 32),
          padding: EdgeInsets.zero,
          iconSize: 16,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: shape,
          side: BorderSide(color: tokens.border),
          selectedBackgroundColor: tokens.hover,
          selectedForegroundColor: onSurface,
          foregroundColor: tokens.textMuted,
          textStyle: t(12.5, FontWeight.w500),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: t(13, FontWeight.w400, color: tokens.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: accent, width: 1.2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: tokens.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 6,
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: t(13, FontWeight.w400),
        // One style in every state: a hovered item restyled wider than the menu overflowed it.
        labelTextStyle: WidgetStatePropertyAll(t(13, FontWeight.w400)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: tokens.border),
            ),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: onSurface,
        contentTextStyle: t(
          13,
          FontWeight.w500,
          color: isDark ? Colors.black : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        width: 420,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(tokens.borderStrong),
      ),
    );
  }
}
