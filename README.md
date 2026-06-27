# Control Asistencia

App Android offline para control de asistencia con foto, entrada/salida, turnos, capacitaciones y modulo administrador protegido con PIN.

**Repositorio:** [github.com/Nany1993/control-asistencia](https://github.com/Nany1993/control-asistencia)

**Version actual:** 1.6.5

## Funciones

### Asistencia laboral (pestaña Turno)

- Flujo: empresa → persona → tipo (entrada/salida) → foto → guardar.
- Pestañas **Internos** y **Externos** con busqueda por nombre o documento.
- Alternancia entrada/salida: no permite dos entradas o dos salidas seguidas.
- Boton seleccionado resaltado en azul.

### Internos y turnos

- **Turnos** por empresa: hora entrada/salida, tolerancia, dias de la semana.
- Horario de **almuerzo** opcional en el turno (inicio y fin).
- Asignacion de **uno o varios turnos** a cada empleado interno (ej. lun-vie y sabado).
- El sistema usa automaticamente el turno que corresponde al dia de la marcacion.
- **Llegada tarde:** solo en la primera entrada del dia (respeta tolerancia del turno).
- **Reingreso:** si ya entro y salio, al volver a entrar no se marca llegada tarde.
- **Salida anticipada:** si sale antes del fin del turno, pide motivo:
  - **Cita medica** → radicado obligatorio
  - **Permiso** → radicado obligatorio
  - **Almuerzo** → sin radicado
  - **Sin permiso** → nota opcional (texto libre)
- Si sale dentro del **horario de almuerzo** del turno, se registra como almuerzo automaticamente.
- Al **volver de almuerzo**, indica cuanto se demoro (y exceso sobre el horario del turno, si aplica).

### Capacitaciones (pestaña Capacitacion)

- CRUD en admin: nombre, temas tratados, expositor, fecha, empresa opcional.
- **Foto general opcional** de la sesion.
- Marcacion de asistencia con **foto obligatoria** por persona (internos/externos).
- Solo se puede marcar el **dia programado** de la capacitacion.
- **Cierre automatico** al pasar la fecha:
  - Con asistentes → **Ejecutada**
  - Sin asistentes → **No ejecutada**
- Cierre manual desde admin.
- Export **informe PDF** (portada, listado, fotos individuales, foto grupal si existe) y CSV opcional.

### Externos

- Personas externas separadas de internos (CRUD propio).
- Una empresa por externo; sin turnos ni evaluacion de horarios.
- Misma alternancia entrada/salida y registro con foto.

### Administracion (PIN)

Menu: Empresas → Turnos → Empleados → Externos → Capacitaciones → Asistencia capacitaciones → Registros → Exportar → Modificar PIN.

- CRUD de empresas, empleados internos, externos, turnos y capacitaciones.
- Ver registros y asistencias a capacitaciones con fotos.
- Exportar CSV de asistencia laboral e informe PDF/CSV de capacitaciones.
- Cambiar PIN de administrador.

### General

- **Offline:** datos en SQLite local; fotos en almacenamiento del dispositivo.
- **Varias marcaciones por dia:** permite salir y volver a entrar (almuerzo, permisos, etc.).

## PIN inicial

- **1957** (cambiable en Admin → Modificar PIN)

## Clonar el proyecto

```powershell
git clone https://github.com/Nany1993/control-asistencia.git
cd control-asistencia
flutter pub get
```

## Requisitos para generar el APK

1. **Flutter** instalado ([flutter.dev](https://flutter.dev))
2. **Android Studio** con Android SDK
3. En Windows: activar **Modo de desarrollador** (Configuracion → Privacidad y seguridad → Para desarrolladores) para soporte de symlinks de Flutter

## Generar APK

### Windows (recomendado si la ruta del usuario tiene espacios)

```powershell
cd "c:\Users\ACER NITRO\Downloads\Control asistencia"
powershell -ExecutionPolicy Bypass -File .\build-apk.ps1
```

El script compila desde `C:\control_asistencia` y copia el APK a `Control-Asistencia.apk` en la carpeta del proyecto.

### Compilacion directa

```powershell
flutter pub get
flutter build apk --release
```

El APK queda en:

```
build\app\outputs\flutter-apk\app-release.apk
```

## Instalar en un Android

1. Copie el APK al celular o tablet.
2. Abra el archivo y permita **instalar apps desconocidas** si el sistema lo pide.
3. Instale y abra **Control Asistencia**.

## Uso rapido

1. Toque el icono de administrador (esquina superior derecha).
2. Ingrese PIN `1957` (o el PIN configurado).
3. Cree una **empresa**, **turnos**, **empleados** o **externos**, y **capacitaciones** si aplica.
4. En la pantalla principal use **Turno** o **Capacitacion** segun corresponda.

## Exportar reportes

Admin → Exportar:

- **Asistencia laboral:** CSV (generar o compartir por Gmail, WhatsApp, etc.)
- **Capacitaciones:** informe PDF (recomendado para SST) o CSV
- **Compartir:** use **Generar y compartir** para elegir la app (correo, WhatsApp, Drive, etc.)

Los archivos se guardan en la carpeta interna `exportes` de la app.

## Respaldo de datos

Admin → **Respaldo de datos**:

- Genera un archivo `.zip` con la base de datos, fotos y exportes
- Use **Generar y compartir respaldo** para guardarlo en Drive, correo o PC

## Contribuir / mejoras

```powershell
git add .
git commit -m "Descripcion del cambio"
git push
```

## Notas

- La hora de marcacion usa el reloj del dispositivo.
- Al eliminar una empresa se borran sus empleados, turnos, registros y capacitaciones asociadas.
- El APK generado localmente no se sube al repositorio (ver `.gitignore`).
