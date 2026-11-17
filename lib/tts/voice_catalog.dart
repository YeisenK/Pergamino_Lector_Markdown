/// Voces Piper en español ya convertidas para sherpa-onnx (versión int8:
/// ligera y rápida). Se descargan desde la app y funcionan sin conexión.
class PiperVoice {
  final String id; // p. ej. es_MX-claude-high
  final String name;
  final String detail;
  final int approxMb;
  const PiperVoice(this.id, this.name, this.detail, this.approxMb);

  String get url =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-$id-int8.tar.bz2';
  String get voiceId => 'piper:$id';
}

const piperCatalog = <PiperVoice>[
  PiperVoice('es_MX-claude-high', 'Claude', 'México · calidad alta', 21),
  PiperVoice('es_MX-ald-medium', 'Ald', 'México · media', 21),
  PiperVoice('es_ES-davefx-medium', 'Davefx', 'España · media', 21),
  PiperVoice('es_ES-miro-high', 'Miro', 'España · calidad alta', 21),
  PiperVoice('es_AR-daniela-high', 'Daniela', 'Argentina · calidad alta', 35),
];
