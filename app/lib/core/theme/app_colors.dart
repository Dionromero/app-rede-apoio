import 'package:flutter/material.dart';

/// Paleta "acolhedora e editorial": vinho, areia e musgo, em vez do
/// rosa/azul de template. Os nomes antigos (pink, primary...) foram mantidos
/// e apontam para os novos tons, para as telas existentes mudarem juntas.
abstract final class AppColors {
  // ── Tons da marca ─────────────────────────────────────────────────────────
  /// Vinho: cor principal (botões, marca, seleção).
  static const wine = Color(0xFF7A2E3A);
  static const wineDeep = Color(0xFF5C1F2A);
  static const wineSoft = Color(0xFFF2E3E0);

  /// Azul-petróleo: links, foco, informação.
  static const ink = Color(0xFF2F5D62);
  static const inkSoft = Color(0xFFE2ECEA);

  /// Musgo: acolhimento, "aberto", confirmação.
  static const moss = Color(0xFF4F6B4A);
  static const mossSoft = Color(0xFFE7EDE2);

  /// Areia: fundos.
  static const sand = Color(0xFFF6F1E9);
  static const sandDeep = Color(0xFFEDE5D8);
  static const paper = Color(0xFFFFFCF7);

  // ── Nomes usados pelas telas (compatibilidade) ────────────────────────────
  static const pink = wine;
  static const primary = ink;
  static const pinkSoft = wineSoft;
  static const blueSoft = inkSoft;

  // Fundo e superfície
  static const background = sand;
  static const surface = paper;

  // Texto
  static const textPrimary = Color(0xFF231C19);
  static const textSecondary = Color(0xFF5F5650);
  static const textHint = Color(0xFF9A8F86);

  // Borda
  static const border = Color(0xFFE4DACD);
  static const hairline = Color(0xFFEAE1D6);

  // Emergência: vermelho profundo, reconhecível, mas sem gritar.
  static const emergency = Color(0xFFA8272B);
  static const emergencyDeep = Color(0xFF7F1C20);

  // Sombra (quente, bem suave)
  static const shadow = Color(0x14301A12);
  static const shadowMedium = Color(0x22301A12);

  // Legado (compatibilidade)
  static const primaryDark = wineDeep;
}
