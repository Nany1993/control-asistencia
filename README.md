# Control Asistencia

App Android offline para control de asistencia con foto, entrada/salida y modulo administrador protegido con PIN.

## Funciones

- **Asistencia (pantalla principal):** empresa → empleado → tipo (entrada/salida) → foto → guardar.
- **Administracion (PIN):** CRUD de empresas y empleados, ver registros, exportar CSV y cambiar PIN.
- **Offline:** datos en SQLite local; fotos en almacenamiento del dispositivo.
- **Varias marcaciones por dia:** permite salir y volver a entrar.

## PIN inicial

- **1957** (puede cambiarlo en **Modificar PIN** desde la pantalla de administrador o en Admin → Modificar PIN)

## Requisitos para generar el APK

1. **Flutter** instalado ([flutter.dev](https://flutter.dev))
2. **Android Studio** con Android SDK
3. En Windows: activar **Modo de desarrollador** (Configuracion → Privacidad y seguridad → Para desarrolladores) para soporte de symlinks de Flutter

## Generar APK

```powershell
cd "c:\Users\ACER NITRO\Downloads\Control asistencia"
flutter pub get
flutter build apk --release
```

El APK queda en:

```
build\app\outputs\flutter-apk\app-release.apk
```

## Instalar en un Android

1. Copie `app-release.apk` al celular o tablet.
2. Abra el archivo y permita **instalar apps desconocidas** si el sistema lo pide.
3. Instale y abra **Control Asistencia**.

## Uso rapido

1. Toque el icono de administrador (esquina superior derecha en Asistencia).
2. Ingrese PIN `1957` (o el PIN que haya configurado).
3. Cree una **empresa** y sus **empleados**.
4. Vuelva a Asistencia y registre marcaciones.

## Exportar reportes

Admin → Exportar → Generar CSV o Generar y compartir (WhatsApp, Drive, etc.).

Los archivos CSV se guardan en la carpeta interna `exportes` de la app.

## Notas

- La hora de marcacion usa el reloj del dispositivo.
- Al eliminar una empresa se borran sus empleados y registros.
- Sugiere alternar entrada/salida segun la ultima marcacion del empleado.
