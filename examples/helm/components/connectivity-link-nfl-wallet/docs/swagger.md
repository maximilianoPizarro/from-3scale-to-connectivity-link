# Swagger UI

## Acceso

La API de NFL Wallet expone una interfaz Swagger UI para explorar y probar los endpoints.

**URL**: [https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/q/swagger-ui](https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/q/swagger-ui)

## Configuración de autenticación en Swagger

1. Acceder a la URL de Swagger UI
2. En la esquina superior derecha, hacer click en **Authorize**
3. En el campo **ApiKeyAuth (apiKey)**, ingresar:
   ```
   nfl-wallet-demo-key-2024
   ```
4. Click en **Authorize**, luego **Close**
5. Los endpoints ahora enviarán automáticamente el header `X-API-Key`

## Endpoints disponibles

### Billeteras

| Método | Path | Descripción |
|--------|------|-------------|
| `GET` | `/api/wallets` | Listar todas las billeteras |
| `POST` | `/api/wallets` | Crear nueva billetera |
| `GET` | `/api/wallets/{id}` | Obtener billetera por ID |

### Transacciones

| Método | Path | Descripción |
|--------|------|-------------|
| `GET` | `/api/wallets/{id}/transactions` | Listar transacciones |
| `POST` | `/api/wallets/{id}/transactions` | Crear transacción |

### Saldo

| Método | Path | Descripción |
|--------|------|-------------|
| `GET` | `/api/wallets/{id}/balance` | Consultar saldo actual |

## OpenAPI Spec

El spec OpenAPI se puede descargar en formato JSON/YAML:

```bash
curl -H "X-API-Key: nfl-wallet-demo-key-2024" \
  https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/q/openapi
```

## Kuadrant Auth Flow

```
Cliente                    Gateway Istio              Kuadrant/Authorino         nfl-wallet-api
  │                           │                            │                        │
  │  GET /api/wallets         │                            │                        │
  │  X-API-Key: demo-key      │                            │                        │
  │──────────────────────────▶│                            │                        │
  │                           │  Validate API Key          │                        │
  │                           │───────────────────────────▶│                        │
  │                           │                            │  Check Secret labels   │
  │                           │                            │  kuadrant.io/apikey     │
  │                           │  ✓ Authorized              │                        │
  │                           │◀───────────────────────────│                        │
  │                           │  Check Rate Limit          │                        │
  │                           │  (Limitador: 120/min)      │                        │
  │                           │  ✓ Within limit            │                        │
  │                           │                            │                        │
  │                           │  Forward request           │                        │
  │                           │───────────────────────────────────────────────────▶│
  │                           │                            │                        │
  │  200 OK (wallets list)    │                            │                        │
  │◀──────────────────────────│◀───────────────────────────────────────────────────│
```
