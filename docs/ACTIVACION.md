# Activación de cuentas reales

La versión de cuentas reales retira los accesos y datos simulados. Google OAuth está activado, el primer ingreso con Google se verificó y el primer administrador fue asignado después de comprobar su identidad y sesión.

Se aprobaron 13 pruebas automatizadas y la compilación. Las operaciones del backend instalado y el aislamiento entre pacientes se comprobaron con roles simulados en SQL y filas temporales que se revirtieron. El recorrido completo desde dos navegadores con cuentas Google reales y las pruebas en dispositivos físicos siguen pendientes.

## Configuración exacta

### Crear el cliente de Google desde cero

1. Abrir [Google Auth Platform](https://console.cloud.google.com/auth/overview) con la cuenta propietaria. Crear o seleccionar el proyecto **Medicita**.
2. Si aparece **Comenzar / Get started**, registrar el nombre **Medicita**, el correo de asistencia y el correo de contacto. Elegir audiencia **Externa**.
3. En **Acceso a los datos / Data Access**, usar solamente `openid`, `userinfo.email` y `userinfo.profile`.
4. En **Público / Audience**, si la app está en modo de prueba, agregar el correo del propietario y la segunda cuenta que realizará las pruebas como usuarios de prueba. El acceso para cualquier persona se habilita después desde esta sección, según los requisitos de Google.
5. Abrir **Clientes / Clients → Crear cliente**. Elegir **Aplicación web** y nombre **Medicita web**.
6. Copiar exactamente estos valores:

- Origen JavaScript: `https://nemito27.github.io`
- URI de redirección: `https://dzkpnmqqadujexkalqrt.supabase.co/auth/v1/callback`

7. Crear el cliente y conservar de forma privada su **Client ID** y **Client Secret**. Google puede mostrar el secreto solamente al crearlo.

### Guardar la configuración en Supabase

Abrir [proveedores de Medicita](https://supabase.com/dashboard/project/dzkpnmqqadujexkalqrt/auth/providers). En **Google**, introducir **Client ID** y **Client Secret**, activar el proveedor y guardar. El secreto permanece exclusivamente en Supabase, nunca en GitHub o en el chat.

En [Authentication → URL Configuration](https://supabase.com/dashboard/project/dzkpnmqqadujexkalqrt/auth/url-configuration):

- Site URL: `https://nemito27.github.io/medicita/`
- Redirect URLs: `https://nemito27.github.io/medicita/`

El callback de Google termina en `/auth/v1/callback`; la URL de regreso de la app termina en `/medicita/`. Cada uno va en el campo indicado arriba.

Referencias oficiales: [Supabase: acceso con Google](https://supabase.com/docs/guides/auth/social-sign-in/auth-google) y [Google: crear credenciales OAuth](https://developers.google.com/identity/protocols/oauth2/web-server#creatingcred).

## Recorrido de aceptación con cuentas reales

Los dos primeros pasos están verificados. Los pasos de agenda, reserva y reasignación siguientes permiten completar la comprobación desde dos navegadores usando horarios que el centro realmente quiera ofrecer.

1. Ingresar con la cuenta Google del propietario y comprobar que se crea un perfil paciente.
2. Verificar el UUID y correo autenticado antes de asignar explícitamente el rol administrador. No asignar por datos editables del perfil.
3. Crear un cupo con profesional y horario reales desde el administrador. No se precargan profesionales ni agendas ficticias.
4. Ingresar con otra cuenta y reservar; recargar y verificar la persistencia.
5. Confirmar que ese paciente no puede consultar ni modificar citas de otro usuario.
6. Cancelar, generar una oferta desde espera y aceptarla desde su cuenta propietaria.
7. Verificar los boxes y las métricas desde ambas cuentas; cerrar sesión y confirmar que no quedan citas visibles.
8. Integrar esta rama en `main` y verificar el despliegue público.

Las pruebas automatizadas de PostgreSQL y compilación no sustituyen estas comprobaciones con Google real. La conexión del propietario a Supabase Dashboard tampoco activa por sí sola Google OAuth de Medicita.
