# Control Asistencia

App Android offline para control de asistencia con foto, entrada/salida, turnos, capacitaciones y modulo administrador protegido con PIN.

**Repositorio:** [github.com/Nany1993/control-asistencia](https://github.com/Nany1993/control-asistencia)

**Version actual:** 1.8.9

## Funciones

### Presentacion

- Toda la **informacion visible** en pantallas y exportes **CSV** se muestra en **MAYUSCULAS**.
- El **informe PDF de capacitaciones** usa formato titulo (primera letra de cada palabra en mayuscula) y diseno mejorado.

### Asistencia laboral (pestaña Turno)

- Flujo kiosco: empresa → **buscar** persona → tipo (entrada/salida) → foto → guardar.
- No se muestra la lista completa ni marcaciones anteriores; solo resultados de busqueda.
- Pestañas **Internos** y **Externos** con busqueda por nombre, cargo o documento.
- Alternancia entrada/salida el mismo dia.
- **Turnos nocturnos** (vigilancia, porteria): entrada un dia y salida al dia siguiente. No se cierra el turno a medianoche; el cierre automatico ocurre solo despues de la hora de salida del turno.
- Si quedo una **entrada sin salida** de un dia anterior (turno diurno), al marcar entrada hoy el sistema registra automaticamente una salida con observacion **"No registro salida"** (hora de cierre del turno o fin de dia).
- **Llegada tarde** solo en la **primera entrada del dia** (reingresos el mismo dia no generan retraso).

### Internos y turnos

- **Turnos** globales: hora entrada/salida, tolerancia, dias de la semana.
- Opcion **turno nocturno** cuando la salida es al dia siguiente (ej. 17:00 a 10:00).
- Horario de **almuerzo** opcional: **solo informativo** en la app (no afecta marcaciones).
- Asignacion de **uno o varios turnos** a cada empleado interno.
- **Salida anticipada** con motivo y radicado cuando aplica.

### Capacitaciones (pestaña Capacitacion)

- Personas activas de **empresas activas** (internos y externos).
- Flujo kiosco: capacitacion → **buscar** persona → foto → registrar (sin listar asistencias previas).
- Busqueda por nombre, empresa, cargo o documento.
- Marcacion con foto obligatoria solo el dia programado.
- **Temas generales** (resumen breve) y **descripcion amplia** (detalle opcional) al crear la capacitacion.
- Cierre automatico o manual; export PDF/CSV.
- El **informe PDF** (diseno con encabezado, tabla y evidencia fotografica) solo se exporta si la capacitacion esta **cerrada** (si esta abierta, la app ofrece cerrarla antes).

### Personas (internos y externos)

- Campos: empresa, **NIT** (empresas), nombre, **cargo**, documento, turnos (internos).
- **Documento unico por empresa** (no permite duplicados).
- Al editar, los registros historicos conservan empresa, turno, cargo, nombre y documento del momento de la marcacion.

### Administracion (PIN)

Menu: Empresas → Turnos → Empleados → Externos → Capacitaciones → Asistencia capacitaciones → Registros → Exportar → Respaldo → Modificar PIN.

- Exportar asistencia laboral en **CSV o PDF**.
- **Registros:** consultar marcaciones y agregar **nota admin** por registro (aclaraciones del administrador; aparece en exportes).
- **Respaldo:** generar ZIP o **restaurar** desde un ZIP previo (valida version compatible).
- Capacitaciones cerradas **no se pueden editar** (solo cerrar o eliminar si no tienen asistencias)

## Generar APK para uso

El APK no se sube a GitHub; hay que generarlo en el PC y copiarlo al tablet o celular.

### Requisitos en el PC (Windows)

- **Flutter** instalado (el script usa `C:\flutter` o lo copia desde tu perfil la primera vez).
- **Android SDK** (Android Studio o solo el SDK). El script usa `%LOCALAPPDATA%\Android\Sdk`.
- Verificar entorno: `flutter doctor` (debe marcar Android toolchain sin errores graves).

### Compilar

Desde la carpeta del proyecto, en **PowerShell**:

```powershell
cd "c:\Users\ACER NITRO\Downloads\Control asistencia"
powershell -ExecutionPolicy Bypass -File .\build-apk.ps1
```

El script `build-apk.ps1`:

1. Sincroniza el codigo a `C:\control_asistencia` (evita problemas por espacios en la ruta del usuario).
2. Ejecuta `flutter pub get` y `flutter build apk --release`.
3. Copia el APK final a la carpeta del proyecto como **`Control-Asistencia.apk`**.

La primera compilacion puede tardar varios minutos.

### Instalar en el tablet

1. Copia **`Control-Asistencia.apk`** al dispositivo (USB, correo, Drive, etc.).
2. En Android: permitir **instalar apps de origenes desconocidos** para el navegador o gestor de archivos que uses.
3. Abre el APK en el tablet y confirma **Instalar**.
4. Si ya tenias una version anterior, la instalacion **actualiza** la app; los datos locales se conservan salvo que desinstales antes.

### Alternativa manual (sin script)

Si ya tienes Flutter en una ruta sin espacios:

```powershell
cd ruta\al\proyecto
flutter pub get
flutter build apk --release
```

El APK queda en `build\app\outputs\flutter-apk\app-release.apk`.

## Exportar reportes

Admin → Exportar:

- **Asistencia laboral:** CSV o PDF
- **Capacitaciones:** informe PDF o CSV

## Respaldo de datos

Admin → **Respaldo de datos**:

- **Generar** o **compartir** un `.zip` (base de datos, fotos, exportes)
- **Restaurar** seleccionando un ZIP generado por la app (reemplaza los datos del dispositivo)

## Notas

- La hora de marcacion usa el reloj del dispositivo.
- Los **turnos** son compartidos entre todas las empresas.
- Integridad referencial al eliminar empresas, personas, turnos o capacitaciones con historial.
