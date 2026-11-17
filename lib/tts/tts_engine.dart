/// Un motor de voz que lee una frase cada vez (sin generar el libro entero).
abstract class TtsEngine {
  /// Habla [text]; completa al terminar o cuando se llama a [stop].
  /// [next] es la frase siguiente: permite prepararla mientras suena esta.
  Future<void> speak(String text, {String? next});
  Future<void> stop();

  /// Velocidad como multiplicador (1.0 = normal).
  Future<void> setRate(double rate);
  Future<void> dispose();
}

class TtsVoice {
  final String id; // «sys:nombre|es-ES» o «piper:es_MX-claude-high»
  final String name;
  final String detail;
  const TtsVoice(this.id, this.name, this.detail);
}
