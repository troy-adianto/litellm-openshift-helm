# LiteLLM for OpenShift

Production-ready Helm chart for deploying [LiteLLM](https://github.com/BerriAI/litellm) AI Gateway on Red Hat OpenShift Container Platform 4.20+.

## Overview

LiteLLM is a unified API gateway that provides OpenAI-compatible endpoints for 100+ LLM providers including OpenAI, Anthropic, Azure, AWS Bedrock, Google Vertex AI, and more.

**Key Features:**
- ✅ Unified API across all LLM providers
- ✅ Cost tracking and budget management
- ✅ Load balancing and fallback routing
- ✅ Request logging and analytics
- ✅ Virtual keys and team management
- ✅ Admin UI for easy configuration
- ✅ OpenShift-native deployment with Routes
- ✅ PostgreSQL for persistent storage

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd litellm-as-a-service

# Create a values file
cat > my-values.yaml <<EOF
litellm:
  masterKey: "sk-litellm-$(openssl rand -hex 16)"
  config:
    model_list:
      - model_name: gpt-4
        litellm_params:
          model: openai/gpt-4
          api_key: os.environ/OPENAI_API_KEY
  env:
    - name: OPENAI_API_KEY
      value: "YOUR_API_KEY_HERE"

postgresql:
  enabled: true
  auth:
    password: "$(openssl rand -base64 32)"
EOF

# Install the chart
helm install litellm helm/litellm-openshift/ \
  -f my-values.yaml \
  -n litellm --create-namespace

# Run database migrations (required on first install)
kubectl run litellm-migration --rm -it \
  --image=ghcr.io/berriai/litellm-database:1.90.0 \
  --env="DATABASE_URL=$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d)" \
  --restart=Never \
  -n litellm \
  -- prisma migrate deploy

# Get the Route URL
oc get route litellm-litellm-openshift -n litellm
```

## Repository Structure

```
litellm-as-a-service/
├── helm/
│   └── litellm-openshift/        # Main Helm chart
│       ├── Chart.yaml             # Chart metadata
│       ├── values.yaml            # Default configuration
│       ├── README.md              # Chart documentation
│       └── templates/             # Kubernetes manifests
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── route.yaml
│           ├── ingress.yaml
│           ├── configmap.yaml
│           ├── secret.yaml
│           ├── serviceaccount.yaml
│           ├── _helpers.tpl
│           └── NOTES.txt
├── examples/                      # Example configurations
│   ├── basic-deployment.yaml      # Simple setup
│   ├── external-database.yaml     # External PostgreSQL
│   ├── multi-provider.yaml        # Multiple LLM providers
│   └── ingress-deployment.yaml    # Kubernetes Ingress
└── README.md                      # This file
```

## Documentation

- **[Helm Chart README](helm/litellm-openshift/README.md)** - Complete chart documentation
- **[Configuration Guide](helm/litellm-openshift/README.md#configuration)** - All configuration options
- **[Examples](examples/)** - Example deployment configurations

## Examples

### Basic Deployment

Minimal configuration with bundled PostgreSQL:

```yaml
litellm:
  masterKey: "sk-litellm-your-key"
  config:
    model_list:
      - model_name: gpt-4
        litellm_params:
          model: openai/gpt-4
          api_key: os.environ/OPENAI_API_KEY

postgresql:
  enabled: true

route:
  enabled: true
```

See [examples/basic-deployment.yaml](examples/basic-deployment.yaml)

### Multiple Providers

Configure OpenAI, Anthropic, and Azure:

```yaml
litellm:
  config:
    model_list:
      - model_name: gpt-4
        litellm_params:
          model: openai/gpt-4
          api_key: os.environ/OPENAI_API_KEY
      
      - model_name: claude-3-opus
        litellm_params:
          model: anthropic/claude-3-opus-20240229
          api_key: os.environ/ANTHROPIC_API_KEY
```

See [examples/multi-provider.yaml](examples/multi-provider.yaml)

### External Database

Use your existing PostgreSQL:

```yaml
postgresql:
  enabled: false

externalDatabase:
  enabled: true
  connectionString: "postgresql://user:pass@host:5432/litellm"
```

See [examples/external-database.yaml](examples/external-database.yaml)

## Requirements

- Red Hat OpenShift Container Platform 4.20+
- Helm 3.8+
- `kubectl` or `oc` CLI
- At least one LLM provider API key

## Features

### OpenShift Integration

- **Routes** - Native OpenShift routing with TLS edge termination
- **SCC Compliance** - Runs with restricted Security Context Constraints
- **Non-root Containers** - Security-hardened deployment

### Database Options

- **Bundled PostgreSQL** - Bitnami PostgreSQL subchart for quick setup
- **External Database** - Connect to existing PostgreSQL instances
- **Manual Migrations** - Full control over schema updates

### Security

- **Non-root user** (UID 101)
- **Read-only root filesystem** (where possible)
- **No privilege escalation**
- **Secret management** for credentials
- **TLS by default** for external access

## Usage

### Test the API

```bash
# Get credentials
ROUTE_URL=$(oc get route litellm-litellm-openshift -n litellm -o jsonpath='{.spec.host}')
MASTER_KEY=$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.master-key}' | base64 -d)

# Health check
curl https://$ROUTE_URL/health/readiness

# Make an API call
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Access Admin UI

```bash
# Get the URL
echo "https://$(oc get route litellm-litellm-openshift -n litellm -o jsonpath='{.spec.host}')"

# Open in browser and login with your master key
```

## Upgrading

```bash
# Upgrade the release
helm upgrade litellm helm/litellm-openshift/ \
  -f my-values.yaml \
  -n litellm

# Run migrations if version changed
kubectl run litellm-migration --rm -it \
  --image=ghcr.io/berriai/litellm-database:<NEW_VERSION> \
  --env="DATABASE_URL=$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d)" \
  --restart=Never \
  -n litellm \
  -- prisma migrate deploy
```

## Uninstalling

```bash
helm uninstall litellm -n litellm
kubectl delete namespace litellm  # Optional
```

## Troubleshooting

### Common Issues

**Pods not starting:**
- Check if master key is set: `kubectl get secret litellm-litellm-openshift -n litellm`
- Verify PVC binding: `kubectl get pvc -n litellm`
- Check logs: `kubectl logs -f deployment/litellm-litellm-openshift -n litellm`

**Database connection errors:**
- Verify PostgreSQL is running: `kubectl get pods -l app.kubernetes.io/name=postgresql -n litellm`
- Check database URL: `kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d`

**Route not accessible:**
- Check Route status: `oc get route -n litellm`
- Test internal service: `kubectl port-forward svc/litellm-litellm-openshift 4000:4000 -n litellm`

See the [Helm Chart README](helm/litellm-openshift/README.md#troubleshooting) for detailed troubleshooting.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This Helm chart is licensed under the MIT License.

LiteLLM is licensed separately - see [LiteLLM License](https://github.com/BerriAI/litellm/blob/main/LICENSE).

## Resources

- **LiteLLM Documentation:** https://docs.litellm.ai/
- **LiteLLM GitHub:** https://github.com/BerriAI/litellm
- **OpenShift Documentation:** https://docs.openshift.com/
- **Helm Documentation:** https://helm.sh/docs/

## Support

For issues with this Helm chart, please open an issue in this repository.

For LiteLLM-specific questions:
- Discord: https://discord.com/invite/wuPM9dRgDw
- GitHub: https://github.com/BerriAI/litellm/issues
