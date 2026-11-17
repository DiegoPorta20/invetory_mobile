# Inventario · app móvil

Cliente Flutter del sistema de inventario (`../inventory`). Usa el mismo backend NestJS que la web, con la misma lógica de negocio y el mismo lenguaje visual (marca navy, bordes redondeados, sombras suaves, curva de movimiento `cubic-bezier(.2,.8,.2,1)`).

## Requisitos

- Flutter 3.47+ (Dart 3.13+)
- El API en marcha (`pnpm dev` en `../inventory`, puerto 3000)

## Ejecutar

```powershell
flutter pub get
flutter run                                   # emulador Android: usa http://10.0.2.2:3000 por defecto
flutter run --dart-define=API_BASE_URL=http://192.168.1.2:3000   # teléfono físico (IP de tu PC)
```

La dirección del servidor también se puede cambiar dentro de la app: ícono de red en la pantalla de login, o *Más → Configuración → Cambiar servidor*. Incluye un botón para probar la conexión.

El API debe escuchar en la red local para un teléfono físico (mismo Wi‑Fi que la PC). El tráfico HTTP está permitido en Android (`usesCleartextTraffic`) e iOS (ATS) para desarrollo; en producción usa HTTPS.

## Autenticación

El API entrega los tokens como cookies `httpOnly`. La app los lee del `Set-Cookie` del login/refresh, los guarda en el keystore del sistema (`flutter_secure_storage`) y los reenvía: access token como `Authorization: Bearer`, refresh token como cookie solo a `/api/auth/refresh`. Un 401 dispara un único refresh compartido y reintenta la petición; si el refresh falla se cierra la sesión.

## Estructura

```
lib/
  core/       theme, red (ApiClient), auth, router (go_router), formato (es‑PE, S/), datos de referencia
  shared/     modelos (espejo de models.ts), widgets del sistema de diseño
  features/   dashboard, products, movements, counts, reorder, imports, admin, account, more
```

- Estado: Riverpod. Listas paginadas con `PagedController` (scroll infinito + pull to refresh).
- Tras cualquier escritura se incrementa `dataRevisionProvider` y las pantallas se recargan solas.
- Código e identificadores en inglés; textos de la UI en español (Perú).

## Paridad con la web

| Web | Móvil |
| --- | --- |
| Panel | Pestaña Panel: métricas, alertas, reposición, stock por categoría, gráfico de 30 días, más vendidos, últimos movimientos |
| Productos | Lista con búsqueda, filtros, orden, selección múltiple y acciones en lote; detalle; alta y edición con precios con/sin IGV; **importación desde Excel** (plantilla, vista previa por fila y confirmación) |
| Movimientos | Pestaña Movimientos con filtros; registrar entrada, salida o ajuste desde cualquier producto |
| Conteos físicos | Crear, contar por producto, confirmar pendientes, completar, cancelar |
| Reposición | Sugerencias con filtros y creación de importación con la selección |
| Importaciones | Lista, detalle, alta y edición, cambio de estado y recepción por línea |
| Proveedores, Equipos, Categorías, Centros de costo | CRUD en hojas inferiores |
| Usuarios, Configuración (IGV), Mi cuenta | Incluidos |

## Importar productos desde Excel

*Productos → ícono Excel → Importar desde Excel* (o *Más → Importar desde Excel*), mismo flujo que la web:

1. **Descargar plantilla**: `GET /api/products/import/template`; se abre la hoja para compartir/guardar.
2. **Elegir archivo**: solo `.xlsx`, máximo 5 MB (se valida en el teléfono antes de subir). Se envía a `POST /api/products/import/preview` (multipart, campo `file`).
3. **Revisar**: resumen (nuevos, actualizados, errores, avisos) y detalle por fila con filtros.
4. **Importar**: `POST /api/products/import`. Es todo o nada y solo se habilita si no hay errores.

## Exportar a Excel

Cada exportación usa los filtros activos de la pantalla y abre la hoja de compartir del sistema (guardar en Archivos o Drive, abrir en Excel, enviar por WhatsApp o correo). El archivo sale con la fecha: `inventario-2026-11-08.xlsx`.

| Dónde | Endpoint |
| --- | --- |
| Productos → ícono Excel → *Exportar inventario* | `GET /api/products/export` |
| Productos → ícono Excel → *Exportar lista de precios* | `GET /api/products/price-list/export` |
| Movimientos → ícono de descarga | `GET /api/stock-movements/export` |
| Reposición → ícono de descarga | `GET /api/reorder/export` |

## Multiempresa

Un solo APK sirve a todas las empresas. La configuración (nombre, logo, colores, módulos, permisos y límites) la define `../config_inventory`; la app solo la consume.

- El login pide **código de empresa**, correo y contraseña. Al escribir el código se muestra la marca de esa empresa (`GET /api/public/companies/:slug/branding`).
- Tras iniciar sesión se lee `GET /api/config`: rol, módulos habilitados, permisos y marca. Se guarda en caché para arrancar sin conexión.
- `core/config/client_config.dart`: `clientConfigProvider`, `canProvider`, `canSeeCostsProvider`, `canSeePricesProvider` y el widget `Can`. Toda pantalla que muestre un botón o dato sensible debe consultarlos.
- Menú, pestañas y rutas se filtran por módulo (`core/router/module_access.dart`). Sin permiso de costos o precios, la app no muestra esos campos ni los envía al guardar (el API los rechaza).
- `AppColors` toma sus tonos de `BrandPalette`; cuando cambia la paleta se repinta toda la app. El nombre y el ícono del lanzador de Android no cambian por empresa (es un único APK).
