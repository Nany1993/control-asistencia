# Control Asistencia

App Android offline para control de asistencia con foto, entrada/salida, turnos, capacitaciones y modulo administrador protegido con PIN.

**Repositorio:** [github.com/Nany1993/control-asistencia](https://github.com/Nany1993/control-asistencia)

**Version actual:** 1.8.2

## Funciones

### Asistencia laboral (pestaña Turno)

- Flujo kiosco: empresa → **buscar** persona → tipo (entrada/salida) → foto → guardar.
- No se muestra la lista completa ni marcaciones anteriores; solo resultados de busqueda.
- Pestañas **Internos** y **Externos** con busqueda por nombre, cargo o documento.
- Alternancia entrada/salida el mismo dia; si quedo una entrada sin salida de un dia anterior, permite **nueva entrada** al dia siguiente.

### Internos y turnos

- **Turnos** globales: hora entrada/salida, tolerancia, dias de la semana.
- Horario de **almuerzo** opcional en el turno (inicio y fin).
- Asignacion de **uno o varios turnos** a cada empleado interno.
- **Llegada tarde**, **salida anticipada** (con motivo y radicado), **almuerzo** y reingreso.

### Capacitaciones (pestaña Capacitacion)

- Cualquier persona activa (internos y externos de todas las empresas) puede asistir.
- Flujo kiosco: capacitacion → **buscar** persona → foto → registrar (sin listar asistencias previas).
- Busqueda por nombre, empresa, cargo o documento.
- Marcacion con foto obligatoria solo el dia programado.
- Cierre automatico o manual; export PDF/CSV.

### Personas (internos y externos)

- Campos: empresa, **NIT** (empresas), nombre, **cargo**, documento, turnos (internos).
- **Documento unico por empresa** (no permite duplicados).
- Al editar, los registros historicos conservan empresa, turno, cargo, nombre y documento del momento de la marcacion.

### Administracion (PIN)

Menu: Empresas → Turnos → Empleados → Externos → Capacitaciones → Asistencia capacitaciones → Registros → Exportar → Respaldo → Modificar PIN.

- Exportar asistencia laboral en **CSV o PDF**.
- **Respaldo:** generar ZIP o **restaurar** desde un ZIP previo.
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

