# Medicita · Cliente y administración

Aplicación web responsive para gestionar horas médicas, reasignaciones y estado de boxes. Conserva la mascota Con Tigo. Frontend HTML/CSS/JavaScript, API y autenticación Supabase, backend transaccional PostgreSQL. No requiere instalar una app móvil.

## Estado de entrega

- Implementados: ingreso con Google mediante Supabase, creación automática del perfil, cliente, administrador, QR, agenda, lista de espera, ofertas, métricas, historial y boxes.
- Base de datos creada: proyecto `Medicita`, referencia `dzkpnmqqadujexkalqrt`, región São Paulo (`sa-east-1`). Migración inicial aplicada y comprobada.
- Google OAuth está activado: el endpoint de configuración confirma `google: true` y se verificó el primer ingreso real con Google, con identidad confirmada y perfil creado.
- Repositorio: [Nemito27/medicita](https://github.com/Nemito27/medicita). El workflow publica en GitHub Pages después de aprobar las pruebas; consultar su resultado en Actions.
- La primera cuenta real tiene rol administrador, asignado explícitamente después de verificar su identidad de Google y sesión activa. El rol no se puede elegir desde la app. Todavía no hay horas médicas ni citas reales registradas.
- Esta versión elimina la demostración: todas las consultas y cambios usan Supabase y exigen una sesión real.

## Ejecutar

Requiere Node.js 22 o superior.

```sh
npm ci
cp .env.example .env
# Configurar las dos variables públicas de Supabase en .env.
npm run dev
```

La configuración pública del proyecto creado está en `docs/CONFIGURACION.md`. No incluye claves secretas. `npm run build` genera `dist/index.html`, CSS y JavaScript. La aplicación completa se sirve mediante HTTP/HTTPS; abrir el código fuente por `file://` no ejecuta correctamente módulos ni OAuth.

```sh
npm test
npm run build
npm run preview
```

## Organización

| Ruta | Función |
|---|---|
| `web/index.html` | Entrada HTML y metadatos |
| `web/src/main.js` | Vistas cliente/admin, formularios y navegación |
| `web/src/styles.css` | Diseño responsive para computador, tablet y móvil |
| `web/src/api.js` | Supabase Auth, consultas con RLS y llamadas RPC |
| `web/src/domain.js` | Métricas, etiquetas y compatibilidad |
| `web/assets/con-tigo.png` | Mascota entregada por el autor |
| `supabase/migrations/001_medicita.sql` | Tablas, políticas, permisos y operaciones transaccionales |
| `tests/` | Pruebas de lógica y PostgreSQL con PGlite |
| `.github/workflows/pages.yml` | Pruebas, build y publicación en GitHub Pages |
| `docs/CONFIGURACION.md` | Configuración de Google, Supabase y GitHub |
| `docs/ARQUITECTURA.md` | Diseño, seguridad y alcance |

## Flujo de reasignación

1. El cliente cancela su cita o recepción la libera.
2. Administración selecciona un cupo y una solicitud compatible.
3. El servidor verifica especialidad, disponibilidad y ausencia de cruces. Crea una oferta reservada por un máximo de 24 horas, sin superar la hora de atención.
4. El cliente ve la oferta en Avisos. Mantiene su cita anterior mientras no acepte.
5. Al aceptar, una transacción cancela la cita anterior, reserva la nueva, elimina la solicitud en espera y registra la reasignación.
6. El cupo anterior vuelve a estar disponible. Las métricas se calculan desde la agenda y el historial.

Las ofertas son avisos dentro de la aplicación. No se envían correos ni WhatsApp. Los datos se consultan automáticamente cada 20 segundos con la página visible; no es una suscripción Realtime.

## Funcionalidad cliente

- Google OAuth; perfil privado asociado a la cuenta.
- Reservar, confirmar, cambiar o cancelar citas futuras.
- Solicitar cupos en un rango de disponibilidad, con o sin cita a adelantar.
- Aceptar o rechazar ofertas.
- QR con token aleatorio de llegada; sin nombre ni diagnóstico en el código.
- Estado de boxes sin identidad de otros pacientes.
- Editar nombre y teléfono, insignia de bienvenida y cerrar sesión.

## Funcionalidad administrador

- Agenda por fecha; creación de horas de 30 minutos.
- Liberación de citas y ofertas a personas compatibles.
- Registro de llegada mediante código UUID de una credencial. Se puede usar lector externo o pegar el código; no incluye lector por cámara.
- Finalización de atención y actualización de boxes: libre, en atención, en transición, no disponible.
- Métricas por fecha y registro de actividad.
- El rol no se puede elegir en el acceso real. No hay entradas de demostración ni selección pública de roles.

## Validación

Las 13 pruebas de `npm test` y la compilación de producción están aprobadas. Las pruebas usan PostgreSQL embebido (PGlite), roles `anon`/`authenticated` y `auth.uid()` simulado. Verifican aislamiento entre pacientes, imposibilidad de elevar roles, acceso restringido a helpers, reserva duplicada, oferta reservada, aceptación por el propietario, liberación de cita anterior y validación de llegada por fecha. Incluyen métricas, escape HTML y regresiones de cambios de cuenta, respuestas tardías y QR pendientes.

El primer inicio de sesión real con Google se verificó en Supabase mediante la identidad confirmada, la sesión y el perfil creado; también se comprobó el rol administrador. En la base instalada se verificaron reservas, aislamiento entre pacientes, permisos, ofertas, aceptación, cancelación, validación de fecha de llegada, boxes e historial mediante una prueba transaccional con roles `authenticated`; todas las filas de prueba se revirtieron. Esta prueba simula los identificadores de sesión en SQL y no sustituye un recorrido completo desde dos navegadores con cuentas Google reales, que sigue pendiente. No se realizaron pruebas en dispositivos físicos iOS/Android ni se afirma certificación clínica o validación de producción.

## Fuentes oficiales consultadas

- [Google con Supabase](https://supabase.com/docs/guides/auth/social-sign-in/auth-google)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [Cambios de Supabase](https://supabase.com/changelog)

Implementación propia basada en la documentación oficial; no se copió un proyecto clínico ajeno.
