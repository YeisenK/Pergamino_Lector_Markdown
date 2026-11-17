# Pergamino

Lector de libros en Markdown para Android, hecho con Flutter. Pensado para leer sin distracciones.

## Características
- Biblioteca local: importa archivos `.md` (uno por libro), portadas tipográficas, progreso y búsqueda.
- Lector de scroll continuo con modo inmersivo y pantalla siempre encendida.
- Toque en el centro: muestra u oculta controles (y la barra de progreso). Gesto vertical en el borde izquierdo: brillo.
- Capítulos por `#`/`##`, índice, búsqueda dentro del libro (sin distinguir acentos) y marcadores.
- Tipografía ajustable en vivo: tamaño, interlineado, márgenes, ancho, fuente (Literata, Source Serif, Inter, Atkinson) y justificado.
- Temas: Papel, Blanco, Sepia, Gris, Negro OLED y automático.
- «Abrir con» desde el gestor de archivos para `.md`.

## Desarrollo
```
flutter pub get
flutter test
flutter run --release
```

## Firmar una versión de distribución
```
keytool -genkey -v -keystore android/pergamino.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pergamino
```
Crea `android/key.properties` (ignorado por git):
```
storeFile=pergamino.jks
storePassword=...
keyAlias=pergamino
keyPassword=...
```
Y compila con `flutter build appbundle` o `flutter build apk --release`.
