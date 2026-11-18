import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/data/gestures.dart';
import 'package:pergamino/data/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('el ancho se divide en tres franjas', () {
    expect(zoneAt(100, 900), TapZone.left);
    expect(zoneAt(450, 900), TapZone.center);
    expect(zoneAt(800, 900), TapZone.right);
  });

  test('por defecto el centro muestra controles y los lados no hacen nada', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final z = c.read(gesturesProvider);
    expect(z[TapZone.center], GestureAction.toggleControls);
    expect(z[TapZone.left], GestureAction.none);
    expect(z[TapZone.right], GestureAction.none);
  });

  test('la elección se guarda y se recupera; restablecer vuelve al defecto', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    c.read(gesturesProvider.notifier).set(TapZone.right, GestureAction.scrollDown);
    final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(gesturesProvider)[TapZone.right], GestureAction.scrollDown);
    c2.read(gesturesProvider.notifier).reset();
    expect(c2.read(gesturesProvider)[TapZone.right], GestureAction.none);
  });
}
