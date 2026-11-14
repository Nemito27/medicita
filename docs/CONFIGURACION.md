# Configuración y publicación

## 1. Supabase ya creado

Proyecto: `Medicita` · referencia `dzkpnmqqadujexkalqrt` · región `sa-east-1`.

Variables **públicas**, aptas para la aplicación web:

```dotenv
VITE_SUPABASE_URL=https://dzkpnmqqadujexkalqrt.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_5nJVVRngYpOlNFnEBnsC-w_d2pWgo07
```

Estas variables van en `.env` local y en las variables de Actions del repositorio. La clave publicable identifica el proyecto: los permisos efectivos se controlan con la sesión y RLS. Nunca colocar una clave `service_role`, `sb_secret_...` ni el secreto de Google en el frontend, GitHub o mensajes de chat.

La migración inicial ya está aplicada en este proyecto. **No ejecutarla nuevamente allí.** En un proyecto nuevo y vacío se puede aplicar el SQL incluido. Antes de futuras migraciones, inspeccionar tablas y conservar el historial.

## 2. Configurar Google OAuth

Se necesita acceso administrativo al proyecto de Google Cloud y a Supabase. Esta parte no quedó configurada.

1. En Google Cloud configurar la pantalla de consentimiento OAuth con el nombre Medicita.
2. Crear un cliente OAuth de tipo **Aplicación web**.
3. Registrar como URI de redirección autorizada:

   `https://dzkpnmqqadujexkalqrt.supabase.co/auth/v1/callback`

4. En Supabase, Authentication → Sign In / Providers → Google, activar el proveedor y guardar el Client ID y Client Secret del cliente Google. **El secreto se ingresa únicamente allí.**
5. En Authentication → URL Configuration establecer la URL pública real de Medicita como Site URL y agregar la misma URL con su ruta completa a Redirect URLs. En desarrollo agregar `http://localhost:5173/`.
6. La app usa PKCE y `redirectTo` igual al directorio donde se aloja `index.html`. Si Pages usa una subruta de repositorio, debe incluirse esa subruta en Redirect URLs.
7. Si Google está en modo Testing, agregar las cuentas de prueba en la consola Google. Para el público general, configurar la audiencia externa y el estado de publicación que corresponda.
8. Probar ingreso, cierre de sesión y un segundo usuario. La aplicación pide únicamente `openid email profile`; no accede a Gmail.

## 3. Primer administrador

Cada usuario nuevo empieza como paciente. Después de que el propietario ingrese con Google, verificar su identidad en Supabase Authentication → Users. Copiar su UUID, no adivinarlo.

Desde SQL Editor, como propietario del proyecto:

```sql
-- Sustituir solo después de verificar la cuenta destinataria.
update public.profiles
set role = 'admin'
where id = 'UUID_VERIFICADO_DEL_ADMINISTRADOR';
```

Comprobar que se modificó exactamente un perfil. No existe una función de autoascenso accesible desde la app.

## 4. GitHub y Pages

1. Repositorio creado: `Nemito27/medicita`.
2. Subir el contenido de esta carpeta a la rama `main`, incluyendo `package-lock.json`, SQL y `.github/workflows/pages.yml`; excluir `.env`, `node_modules` y `dist`.
3. El workflow incluye la configuración pública de Medicita como valor predeterminado. Para otro proyecto, agregar las dos variables en Settings → Secrets and variables → Actions → Variables.
4. En Settings → Pages elegir **GitHub Actions** como origen.
5. Ejecutar el workflow de publicación o subir un cambio a `main`.
6. Tomar la URL exacta mostrada por el despliegue y registrarla en Supabase URL Configuration.
7. Verificar por separado: carga pública, Google OAuth, creación del perfil, acceso admin y ausencia de acceso a citas ajenas.

GitHub Pages aloja HTML/CSS/JS. Supabase ejecuta la base de datos, autenticación y operaciones del servidor. Publicar solo `index.html` sin sus recursos no basta: debe publicarse todo `dist/`.

## 5. Uso inicial

No hay horas reales ni pacientes de prueba insertados en Supabase. El administrador crea las horas desde Agenda → Crear hora. Los tres boxes iniciales son datos de configuración. Sus estados no representan ocupación clínica real hasta que el personal los actualice.

## Costos

No se aceptó una cotización de pago ni se contrataron planes adicionales durante la creación. Revisar el plan y consumo en la organización Supabase; los límites y precios dependen del proveedor y pueden cambiar. No se promete disponibilidad o costo cero ilimitado.
