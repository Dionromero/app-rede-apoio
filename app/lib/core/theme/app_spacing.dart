/// Espaçamentos do app na grade de 4 pt da Apple (Human Interface Guidelines),
/// com o iPhone 16 Pro Max como referência. Use estes valores em `EdgeInsets`,
/// `SizedBox` e `spacing` em vez de números soltos.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  // Margem lateral das telas: 20 pt, padrão do iOS nos iPhones grandes.
  static const double screen = lg;
}
