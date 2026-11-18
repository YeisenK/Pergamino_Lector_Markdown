import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/features.dart';
import '../../data/settings.dart';
import '../../tts/piper_engine.dart';
import '../../tts/read_aloud.dart';
import '../../tts/system_engine.dart';
import '../../tts/tts_engine.dart';
import '../../tts/voice_catalog.dart';
import '../../tts/voice_store.dart';

final _systemVoicesProvider = FutureProvider<List<TtsVoice>>((ref) async {
  try {
    return await SystemEngine.listVoices();
  } catch (_) {
    return [];
  }
});

const _sample =
    'Había una vez, en un reino muy lejano, una luna que guardaba secretos antiguos. '
    'Nadie recordaba cuándo había comenzado el invierno.';

class VoicesPage extends ConsumerStatefulWidget {
  const VoicesPage({super.key});

  @override
  ConsumerState<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends ConsumerState<VoicesPage> {
  TtsEngine? _engine;
  String? _testing; // id de la voz en prueba
  String? _stats;
  String? _error;
  int _token = 0;

  @override
  void dispose() {
    _token++;
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _test(String voiceId) async {
    final token = ++_token;
    await _engine?.stop();
    await _engine?.dispose();
    _engine = null;
    setState(() {
      _testing = voiceId;
      _stats = null;
      _error = null;
    });
    try {
      final e = await ref.read(engineFactoryProvider)(voiceId == 'sys:|es-ES' ? null : voiceId);
      _engine = e;
      await e.setRate(ref.read(ttsRateProvider));
      final parts = _sample.split('. ');
      final first = '${parts[0]}.';
      final second = parts[1];
      final sw = Stopwatch()..start();
      await e.speak(first, next: second);
      if (token != _token) return;
      if (e is PiperEngine && e.lastAudioMs > 0) {
        final x = e.lastAudioMs / (e.lastSynthMs == 0 ? 1 : e.lastSynthMs);
        _stats =
            'Generó ${(e.lastAudioMs / 1000).toStringAsFixed(1)} s de audio en ${(e.lastSynthMs / 1000).toStringAsFixed(2)} s (${x.toStringAsFixed(1)}× más rápido que el tiempo real)';
      } else {
        _stats = 'Primera frase terminada en ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s';
      }
      if (mounted) setState(() {});
      await e.speak(second);
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    } finally {
      if (mounted && token == _token) setState(() => _testing = null);
    }
  }

  Future<void> _stopTest() async {
    _token++;
    await _engine?.stop();
    if (mounted) setState(() => _testing = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = ref.watch(ttsVoiceProvider);
    final rate = ref.watch(ttsRateProvider);
    final store = ref.watch(voiceStoreProvider);
    final system = ref.watch(_systemVoicesProvider);

    void select(String? id) => ref.read(ttsVoiceProvider.notifier).set(id);

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
          child: Text(t, style: theme.textTheme.titleSmall),
        );

    Widget playButton(String id) => _testing == id
        ? IconButton(
            tooltip: 'Detener',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _stopTest)
        : IconButton(
            tooltip: 'Probar',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => _test(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Voces')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
              'Elige la voz con la que se lee el libro, frase a frase. Todo se sintetiza en tu teléfono, sin generar archivos de audio del libro.',
              style: theme.textTheme.bodyMedium),
        ),
        header('Velocidad'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: Slider(
                value: rate.clamp(0.6, 2.0),
                min: 0.6,
                max: 2.0,
                divisions: 14,
                label: '${rate.toStringAsFixed(1)}×',
                onChanged: (v) =>
                    ref.read(ttsRateProvider.notifier).set((v * 10).round() / 10),
              ),
            ),
            SizedBox(width: 48, child: Text('${rate.toStringAsFixed(1)}×')),
          ]),
        ),
        if (_stats != null || _error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(_error ?? _stats!,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: _error != null ? theme.colorScheme.error : null)),
          ),
        if (ref.watch(featuresProvider).contains(Feature.voiceSkip)) ...[
          header('Qué leer'),
          Builder(builder: (context) {
            final st = ref.watch(settingsProvider);
            final n = ref.read(settingsProvider.notifier);
            return Column(children: [
              SwitchListTile(
                title: const Text('Tablas'),
                subtitle: const Text('Desactivado: las tablas se saltan'),
                value: st.voiceTables,
                onChanged: (v) => n.update(st.copyWith(voiceTables: v)),
              ),
              SwitchListTile(
                title: const Text('Bloques de código'),
                subtitle: const Text('Desactivado: el código se salta'),
                value: st.voiceCode,
                onChanged: (v) => n.update(st.copyWith(voiceCode: v)),
              ),
              SwitchListTile(
                title: const Text('Notas al pie'),
                subtitle: const Text('Líneas que empiezan por [^'),
                value: st.voiceFootnotes,
                onChanged: (v) => n.update(st.copyWith(voiceFootnotes: v)),
              ),
            ]);
          }),
        ],
        header('Piper · sin conexión, rápidas'),
        for (final v in piperCatalog)
          Builder(builder: (context) {
            final st = store[v.id] ?? const VoiceStatus();
            final isSel = selected == v.voiceId;
            return ListTile(
              leading: Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off),
              title: Text(v.name),
              subtitle: Text(st.error ??
                  (st.extracting
                      ? 'Descomprimiendo…'
                      : st.progress != null
                          ? 'Descargando ${(st.progress! * 100).round()} %'
                          : '${v.detail}${st.installed ? '' : ' · ${v.approxMb} MB'}')),
              onTap: st.installed ? () => select(v.voiceId) : null,
              trailing: st.progress != null
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, value: st.extracting ? null : st.progress))
                  : st.installed
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          playButton(v.voiceId),
                          IconButton(
                            tooltip: 'Eliminar voz',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              if (isSel) select(null);
                              ref.read(voiceStoreProvider.notifier).remove(v.id);
                            },
                          ),
                        ])
                      : IconButton(
                          tooltip: 'Descargar',
                          icon: const Icon(Icons.download),
                          onPressed: () =>
                              ref.read(voiceStoreProvider.notifier).download(v)),
            );
          }),
        header('Voces del sistema'),
        ListTile(
          leading: Icon(selected == null ? Icons.radio_button_checked : Icons.radio_button_off),
          title: const Text('Predeterminada del sistema'),
          subtitle: const Text('es-ES'),
          trailing: playButton('sys:|es-ES'),
          onTap: () => select(null),
        ),
        system.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => Column(children: [
            for (final v in list)
              ListTile(
                leading: Icon(selected == v.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(v.detail),
                trailing: playButton(v.id),
                onTap: () => select(v.id),
              ),
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
