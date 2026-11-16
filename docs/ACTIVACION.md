# Activación de cuentas reales

La rama `real-accounts` retira los accesos y datos simulados. Todavía no es una activación completada: Google OAuth y el primer administrador deben verificarse antes de desplegarla.

## Configuración exacta

En Google Cloud, crear un cliente OAuth de tipo Aplicación web para Medicita:

- Origen JavaScript: `https://nemito27.github.io`
- URI de redirección: `https://dzkpnmqqadujexkalqrt.supabase.co/auth/v1/callback`
- Alcances: `openid`, `email`, `profile`.

En Supabase → Authentication → Sign In / Providers → Google, introducir Client ID y Client Secret y activar Google. El secreto permanece exclusivamente en Supabase, nunca en GitHub o en el chat.

En Authentication → URL Configuration:

- Site URL: `https://nemito27.github.io/medicita/`
- Redirect URLs: `https://nemito27.github.io/medicita/`

## Prueba de aceptación antes de publicar

1. Ingresar con la cuenta Google del propietario y comprobar que se crea un perfil paciente.
2. Verificar el UUID y correo autenticado antes de asignar explícitamente el rol administrador. No asignar por datos editables del perfil.
3. Crear un cupo con profesional y horario reales desde el administrador. No se precargan profesionales ni agendas ficticias.
4. Ingresar con otra cuenta y reservar; recargar y verificar la persistencia.
5. Confirmar que ese paciente no puede consultar ni modificar citas de otro usuario.
6. Cancelar, generar una oferta desde espera y aceptarla desde su cuenta propietaria.
7. Verificar los boxes y las métricas desde ambas cuentas; cerrar sesión y confirmar que no quedan citas visibles.
8. Integrar esta rama en `main` y verificar el despliegue público.

Las pruebas automatizadas de PostgreSQL y compilación no sustituyen estas comprobaciones con Google real. La conexión del propietario a Supabase Dashboard tampoco activa por sí sola Google OAuth de Medicita.
