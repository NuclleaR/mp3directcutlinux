import 'package:flutter/material.dart';

/// Colours of the original "MP3 Ножиці" page, plus [split] for split markers.
@immutable
class CutPalette extends ThemeExtension<CutPalette> {
  const CutPalette({
    required this.bg,
    required this.panel,
    required this.line,
    required this.fg,
    required this.muted,
    required this.wave,
    required this.waveBg,
    required this.sel,
    required this.selFill,
    required this.cut,
    required this.cutFill,
    required this.playhead,
    required this.split,
    required this.btn,
    required this.btnHover,
    required this.primary,
    required this.primaryFg,
  });

  final Color bg, panel, line, fg, muted, wave, waveBg, sel, selFill, cut, cutFill;
  final Color playhead, split, btn, btnHover, primary, primaryFg;

  static const light = CutPalette(
    bg: Color(0xFFF3F5F7),
    panel: Color(0xFFFFFFFF),
    line: Color(0xFFD7DDE3),
    fg: Color(0xFF1C2530),
    muted: Color(0xFF5D6B79),
    wave: Color(0xFF3C5A78),
    waveBg: Color(0xFFFBFCFD),
    sel: Color(0xFF1D8A9E),
    selFill: Color(0x521D8A9E),
    cut: Color(0xFFC8423B),
    cutFill: Color(0x61C8423B),
    playhead: Color(0xFFE08A1E),
    split: Color(0xFF7A4FC4),
    btn: Color(0xFFE8EDF2),
    btnHover: Color(0xFFDCE3EA),
    primary: Color(0xFF1D6F9E),
    primaryFg: Color(0xFFFFFFFF),
  );

  static const dark = CutPalette(
    bg: Color(0xFF12171D),
    panel: Color(0xFF1A2129),
    line: Color(0xFF2C3743),
    fg: Color(0xFFE3E9EF),
    muted: Color(0xFF93A2B1),
    wave: Color(0xFF8FB4D6),
    waveBg: Color(0xFF151B22),
    sel: Color(0xFF45BDD1),
    selFill: Color(0x5C45BDD1),
    cut: Color(0xFFEF6A62),
    cutFill: Color(0x6BEF6A62),
    playhead: Color(0xFFF2A93B),
    split: Color(0xFFA98AE8),
    btn: Color(0xFF25303B),
    btnHover: Color(0xFF2F3C49),
    primary: Color(0xFF3E9BD0),
    primaryFg: Color(0xFF0D1218),
  );

  static CutPalette of(BuildContext context) => Theme.of(context).extension<CutPalette>()!;

  ThemeData toTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: primaryFg,
      surface: panel,
      onSurface: fg,
      outline: line,
      error: cut,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      dividerColor: line,
      extensions: [this],
    );
  }

  @override
  CutPalette copyWith() => this;

  @override
  CutPalette lerp(CutPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CutPalette(
      bg: l(bg, other.bg),
      panel: l(panel, other.panel),
      line: l(line, other.line),
      fg: l(fg, other.fg),
      muted: l(muted, other.muted),
      wave: l(wave, other.wave),
      waveBg: l(waveBg, other.waveBg),
      sel: l(sel, other.sel),
      selFill: l(selFill, other.selFill),
      cut: l(cut, other.cut),
      cutFill: l(cutFill, other.cutFill),
      playhead: l(playhead, other.playhead),
      split: l(split, other.split),
      btn: l(btn, other.btn),
      btnHover: l(btnHover, other.btnHover),
      primary: l(primary, other.primary),
      primaryFg: l(primaryFg, other.primaryFg),
    );
  }
}
