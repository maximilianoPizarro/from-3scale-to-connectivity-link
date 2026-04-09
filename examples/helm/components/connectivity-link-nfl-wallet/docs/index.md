# NFL Wallet API

API REST de billetera digital desplegada en OpenShift con protección de Kuadrant AuthPolicy (API Key) y RateLimitPolicy.

## Acceso rápido

| Recurso | URL |
|---------|-----|
| **Swagger UI** | [nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/q/swagger-ui](https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/q/swagger-ui) |
| **API Base** | `https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/api` |
| **Grafana** | [grafana-observability.apps.cluster-l9nhj.dynamic.redhatworkshops.io](https://grafana-observability.apps.cluster-l9nhj.dynamic.redhatworkshops.io) |

## Credenciales

### API Keys

| Nombre | Clave | Permisos |
|--------|-------|----------|
| Admin | `nfl-wallet-demo-key-2024` | Lectura y escritura completa |
| Readonly | `nfl-wallet-readonly-key-2024` | Solo lectura |

### Base de datos

| Campo | Valor |
|-------|-------|
| **Host** | `nfl-wallet-db.nfl-wallet-prod.svc.cluster.local` |
| **Puerto** | `5432` |
| **Base de datos** | `nflwallet` |
| **Usuario** | `nflwallet` |
| **Contraseña** | `nflwallet123!` |

### Grafana

| Campo | Valor |
|-------|-------|
| **Usuario** | `admin` |
| **Contraseña** | `openshift` |

## Uso con curl

```bash
# Listar billeteras
curl -H "X-API-Key: nfl-wallet-demo-key-2024" \
  https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/api/wallets

# Crear billetera
curl -X POST -H "X-API-Key: nfl-wallet-demo-key-2024" \
  -H "Content-Type: application/json" \
  -d '{"owner": "user1", "currency": "ARS"}' \
  https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/api/wallets

# Consultar saldo
curl -H "X-API-Key: nfl-wallet-demo-key-2024" \
  https://nfl-wallet.apps.cluster-l9nhj.dynamic.redhatworkshops.io/api/wallets/1/balance
```

## Namespaces

| Namespace | Propósito |
|-----------|-----------|
| `nfl-wallet-prod` | Ambiente de producción |
| `nfl-wallet-test` | Ambiente de testing |
