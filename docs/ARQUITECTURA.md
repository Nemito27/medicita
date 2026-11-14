# Arquitectura, seguridad y límites

## Componentes

- Cliente estático: HTML, CSS y JavaScript, empaquetado con Vite.
- Supabase Auth: proveedor Google, sesión PKCE y renovación de token.
- API: Supabase Data API, lecturas con RLS y llamadas RPC.
- Backend: funciones PostgreSQL que validan permisos y realizan cambios atómicos.
- Persistencia: PostgreSQL con siete tablas.

| Tabla | Propósito | Lectura desde la app |
|---|---|---|
| profiles | Nombre, teléfono y rol | Propietario y administradores |
| rooms | Estado de box y especialidad | Usuarios autenticados |
| slots | Disponibilidad y profesional | Usuarios autenticados, sin nombres de pacientes |
| appointments | Cita, estado y token QR | Paciente propietario y administradores |
| waiting | Solicitudes de espera | Paciente propietario y administradores |
| offers | Ofertas de cupos | Paciente propietario y administradores |
| audit_log | Registro de operaciones | Administradores |

## Reglas

- El navegador no escribe directamente en tablas ni puede cambiar roles.
- Los RPC públicos son una lista explícita de funciones permitidas. Se revocó EXECUTE a PUBLIC y anon; los helpers de reserva, bloqueo y expiración tampoco son ejecutables por authenticated.
- Las funciones SECURITY DEFINER usan `search_path=''`, nombres cualificados, y verificaciones de `auth.uid()` y/o rol. Son necesarias para efectuar operaciones sobre varias filas sin conceder escritura indiscriminada a clientes.
- El asesor Supabase informa advertencias por las 12 funciones SECURITY DEFINER expuestas a authenticated. Esa exposición es intencional para los RPC y está cubierta por controles de autorización y pruebas; no se presenta el proyecto como libre de advertencias ni como auditado externamente. Referencia: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Una restricción parcial impide dos citas activas para un mismo cupo. Un bloqueo transaccional serializa los cambios de agenda y la aceptación de ofertas. Se verifican cruces de citas del paciente y de horarios del profesional/box al crear cupos.
- El rol está en profiles y no proviene de metadata editable por el usuario.
- Los nombres se escapan antes de construir HTML.
- El QR contiene un token aleatorio por cita. Solo recepción autenticada puede marcar la llegada y solo el día de la cita en America/Santiago.
- El estado del box no expone quién está siendo atendido.

## Límites actuales

Este es un MVP para una institución. No incluye multi-CESFAM, expedientes clínicos, recetas, integración con agendas oficiales, correos, WhatsApp, notificaciones push, lector QR por cámara, gestión de vacaciones ni duración variable de citas.

La asignación al paciente la confirma el propio paciente aceptando la oferta. El administrador no puede simular su aceptación en producción. La prioridad se ordena por antigüedad y compatibilidad administrativa, no por diagnóstico ni decisiones clínicas automatizadas.

Las tablas de lectura se paginan en bloques de 1000. La interfaz consulta cada 20 segundos; para más volumen conviene consultar por jornada, calcular agregados en servidor y añadir índices según la carga observada.

La demo usa localStorage para datos ficticios. No es seguridad, no sincroniza entre dispositivos y no autoriza operaciones reales. El modo real utiliza Supabase.

## Pruebas pendientes antes de uso real

- Google OAuth con usuarios reales y URLs finales.
- Sesiones en Safari/iOS y Chrome/Android físicos.
- Ensayo con recepción y pacientes, accesibilidad y procedimientos de recuperación.
- Revisar retención, respaldo, observabilidad y controles institucionales antes de cargar datos reales de pacientes.
