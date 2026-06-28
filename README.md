# Control Asistencia

App Android offline para control de asistencia con foto, entrada/salida, turnos, capacitaciones y modulo administrador protegido con PIN.

**Repositorio:** [github.com/Nany1993/control-asistencia](https://github.com/Nany1993/control-asistencia)

**Version actual:** 1.8.6

## Funciones

### Presentacion

- Toda la **informacion visible** en pantallas y exportes **CSV** se muestra en **MAYUSCULAS**.
- El **informe PDF de capacitaciones** usa formato titulo (primera letra de cada palabra en mayuscula) y diseno mejorado.

### Asistencia laboral (pestaña Turno)

- Flujo kiosco: empresa → **buscar** persona → tipo (entrada/salida) → foto → guardar.
- No se muestra la lista completa ni marcaciones anteriores; solo resultados de busqueda.
- Pestañas **Internos** y **Externos** con busqueda por nombre, cargo o documento.
- Alternancia entrada/salida el mismo dia.
- Si quedo una **entrada sin salida** de un dia anterior, al marcar entrada hoy el sistema registra automaticamente una salida con observacion **"No registro salida"** (hora de cierre del turno o fin de dia).
- **Llegada tarde** solo en la **primera entrada del dia** (reingresos el mismo dia no generan retraso).

### Internos y turnos

- **Turnos** globales: hora entrada/salida, tolerancia, dias de la semana.
- Horario de **almuerzo** opcional: **solo informativo** en la app (no afecta marcaciones).
- Asignacion de **uno o varios turnos** a cada empleado interno.
- **Salida anticipada** con motivo y radicado cuando aplica.

### Capacitaciones (pestaña Capacitacion)

- Personas activas de **empresas activas** (internos y externos).
- Flujo kiosco: capacitacion → **buscar** persona → foto → registrar (sin listar asistencias previas).
- Busqueda por nombre, empresa, cargo o documento.
- Marcacion con foto obligatoria solo el dia programado.
- Cierre automatico o manual; export PDF/CSV.
- El **informe PDF** (diseno con encabezado, tabla y evidencia fotografica) solo se exporta si la capacitacion esta **cerrada** (si esta abierta, la app ofrece cerrarla antes).

### Personas (internos y externos)

- Campos: empresa, **NIT** (empresas), nombre, **cargo**, documento, turnos (internos).
- **Documento unico por empresa** (no permite duplicados).
- Al editar, los registros historicos conservan empresa, turno, cargo, nombre y documento del momento de la marcacion.

### Administracion (PIN)

Menu: Empresas → Turnos → Empleados → Externos → Capacitaciones → Asistencia capacitaciones → Registros → Exportar → Respaldo → Modificar PIN.

- Exportar asistencia laboral en **CSV o PDF**.
- **Respaldo:** generar ZIP o **restaurar** desde un ZIP previo (valida version compatible).
- Capacitaciones cerradas **no se pueden editar** (solo cerrar o eliminar si no tienen asistencias)

## Generar APK

```powershell
cd "c:\Users\ACER NITRO\Downloads\Control asistencia"
powershell -ExecutionPolicy Bypass -File .\build-apk.ps1
```

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
