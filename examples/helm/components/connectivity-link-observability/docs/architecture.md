# Arquitectura de Observabilidad

## Diagrama de componentes

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  openshift-cluster-observability-operator             │   │
│  │                                                       │   │
│  │  ┌──────────┐  ┌────────────┐  ┌──────────────────┐  │   │
│  │  │ Grafana  │  │ Prometheus │  │ Thanos Querier   │  │   │
│  │  │ (v5)     │←─│ (RHOBS)    │←─│ (federation)     │  │   │
│  │  └──────────┘  └─────┬──────┘  └──────────────────┘  │   │
│  │                      │                                │   │
│  │  ┌──────────┐  ┌─────┴──────┐                        │   │
│  │  │ Kiali    │  │Alertmanager│                        │   │
│  │  │ (mesh)   │  │            │                        │   │
│  │  └──────────┘  └────────────┘                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                           ▲                                  │
│              scrape metrics│                                  │
│  ┌────────────┬────────────┼────────────┬──────────────┐    │
│  │            │            │            │              │    │
│  │ nfl-wallet │ neuralbank │  litemaas  │  kuadrant    │    │
│  │ gateways   │ gateway    │  gateway   │  controller  │    │
│  └────────────┴────────────┴────────────┴──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Flujo de datos

1. **Prometheus** (MonitoringStack RHOBS) recolecta métricas via `ServiceMonitor` y `PodMonitor`
2. **Thanos Querier** federa queries entre réplicas de Prometheus
3. **Grafana** consulta Thanos/Prometheus para dashboards
4. **Alertmanager** evalúa reglas de alerta y envía notificaciones
5. **Kiali** consulta Prometheus para visualización de service mesh

## Operadores requeridos

| Operador | Canal | Source |
|----------|-------|--------|
| `cluster-observability-operator` | `stable` | `redhat-operators` |
| `grafana-operator` | `v5` | `community-operators` |
| `servicemeshoperator3` | `stable` | `redhat-operators` |
| `opentelemetry-product` | `stable` | `redhat-operators` |

## Namespaces monitoreados

Los `PodMonitor` y `ServiceMonitor` configurados recolectan métricas de:

- `nfl-wallet-prod` — Gateway e Istio waypoints de producción
- `nfl-wallet-test` — Gateway e Istio waypoints de testing
- `neuralbank-stack` — Gateway de la aplicación Neuralbank
- `litemaas` — Gateway de LiteLLM/MaaS
- `istio-system` — Kuadrant controller y Authorino

## Retención de datos

- **Prometheus**: 7 días (`retention: 7d`)
- **Alertmanager**: configuración por defecto RHOBS
