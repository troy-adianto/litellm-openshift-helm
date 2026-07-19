# LiteLLM Helm Chart for OpenShift

A production-ready Helm chart for deploying [LiteLLM](https://github.com/BerriAI/litellm) AI Gateway on Red Hat OpenShift Container Platform 4.20+.

## What is LiteLLM?

LiteLLM is a unified API gateway for 100+ LLM providers including:
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- Azure OpenAI
- AWS Bedrock
- Google Vertex AI
- And many more...

**Key Features:**
- Unified OpenAI-compatible API for all providers
- Built-in cost tracking and budget management
- Load balancing across multiple deployments
- Request logging and analytics
- Virtual keys and team management
- Admin UI for configuration

## Prerequisites

- Red Hat OpenShift Container Platform 4.20+
- Helm 3.8+
- `kubectl` or `oc` CLI
- At least one LLM provider API key (OpenAI, Anthropic, etc.)

## Quick Start

### 1. Add the Repository (if published)

```bash
# If the chart is published to a registry
helm repo add litellm-openshift <REPO_URL>
helm repo update
```

Or use the chart directly from the filesystem:

```bash
cd helm/litellm-openshift
```

### 2. Create a values file

```bash
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
      value: "YOUR_OPENAI_API_KEY_HERE"

postgresql:
  enabled: true
  auth:
    password: "$(openssl rand -base64 32)"

route:
  enabled: true
EOF
```

### 3. Install the Chart

```bash
helm install litellm . -f my-values.yaml -n litellm --create-namespace
```

### 4. Run Database Migrations

**IMPORTANT:** You must run database migrations before first use:

```bash
kubectl run litellm-migration --rm -it \
  --image=ghcr.io/berriai/litellm-database:1.90.0 \
  --env="DATABASE_URL=$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d)" \
  --restart=Never \
  -n litellm \
  -- prisma migrate deploy
```

### 5. Access LiteLLM

```bash
# Get the Route URL
export ROUTE_URL=$(oc get route litellm-litellm-openshift -n litellm -o jsonpath='{.spec.host}')
echo "LiteLLM URL: https://$ROUTE_URL"

# Get your master key
export MASTER_KEY=$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.master-key}' | base64 -d)

# Test the API
curl https://$ROUTE_URL/health/readiness

# Open Admin UI in browser
open https://$ROUTE_URL
```

## Configuration

### Chart Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of LiteLLM replicas | `1` |
| `image.repository` | LiteLLM container image repository | `ghcr.io/berriai/litellm-database` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag (overrides appVersion) | `""` |
| `serviceAccount.create` | Create service account | `true` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `4000` |
| **LiteLLM Configuration** | | |
| `litellm.masterKey` | Master authentication key (**REQUIRED**) | `""` |
| `litellm.saltKey` | Salt key for encrypting credentials (auto-generated) | `""` |
| `litellm.config.model_list` | List of LLM models to configure | `[]` |
| `litellm.config.litellm_settings` | LiteLLM proxy settings | See values.yaml |
| `litellm.env` | Additional environment variables | `[]` |
| **Route Configuration** | | |
| `route.enabled` | Enable OpenShift Route | `true` |
| `route.host` | Hostname for Route (auto-generated if empty) | `""` |
| `route.tls.termination` | TLS termination type | `edge` |
| `route.tls.insecureEdgeTerminationPolicy` | HTTP redirect policy | `Redirect` |
| **Ingress Configuration** | | |
| `ingress.enabled` | Enable Kubernetes Ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.host` | Hostname for Ingress | `""` |
| `ingress.tls` | Enable TLS for Ingress | `false` |
| `ingress.tlsSecret` | TLS secret name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| **PostgreSQL Configuration** | | |
| `postgresql.enabled` | Enable bundled PostgreSQL | `true` |
| `postgresql.auth.username` | PostgreSQL username | `litellm` |
| `postgresql.auth.password` | PostgreSQL password (auto-generated if empty) | `""` |
| `postgresql.auth.database` | PostgreSQL database name | `litellm` |
| `postgresql.primary.persistence.enabled` | Enable persistence | `true` |
| `postgresql.primary.persistence.size` | Volume size | `8Gi` |
| **External Database Configuration** | | |
| `externalDatabase.enabled` | Use external PostgreSQL | `false` |
| `externalDatabase.host` | Database host | `""` |
| `externalDatabase.port` | Database port | `5432` |
| `externalDatabase.database` | Database name | `litellm` |
| `externalDatabase.username` | Database username | `litellm` |
| `externalDatabase.password` | Database password | `""` |
| `externalDatabase.connectionString` | Full connection string (takes precedence) | `""` |
| **Resources** | | |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `256Mi` |
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `1Gi` |

For complete configuration options, see [values.yaml](values.yaml).

### LiteLLM Model Configuration

Configure LLM providers in `litellm.config.model_list`:

```yaml
litellm:
  config:
    model_list:
      # OpenAI
      - model_name: gpt-4
        litellm_params:
          model: openai/gpt-4
          api_key: os.environ/OPENAI_API_KEY

      # Anthropic
      - model_name: claude-3-opus
        litellm_params:
          model: anthropic/claude-3-opus-20240229
          api_key: os.environ/ANTHROPIC_API_KEY

      # Azure OpenAI
      - model_name: azure-gpt-4
        litellm_params:
          model: azure/gpt-4
          api_base: os.environ/AZURE_API_BASE
          api_key: os.environ/AZURE_API_KEY
          api_version: "2024-02-15-preview"
```

Provide API keys via environment variables:

```yaml
litellm:
  env:
    - name: OPENAI_API_KEY
      valueFrom:
        secretKeyRef:
          name: llm-api-keys
          key: openai
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: llm-api-keys
          key: anthropic
```

## Examples

See the [examples/](../../examples/) directory for complete configuration examples:

- **[basic-deployment.yaml](../../examples/basic-deployment.yaml)** - Minimal working configuration
- **[external-database.yaml](../../examples/external-database.yaml)** - Using external PostgreSQL
- **[multi-provider.yaml](../../examples/multi-provider.yaml)** - Multiple LLM providers
- **[ingress-deployment.yaml](../../examples/ingress-deployment.yaml)** - Using Ingress instead of Route

## Upgrading

### Upgrade the Deployment

```bash
# Update your values file if needed
vim my-values.yaml

# Upgrade the release
helm upgrade litellm . -f my-values.yaml -n litellm
```

### Database Schema Upgrades

Run migrations after upgrading if the LiteLLM version changed:

```bash
kubectl run litellm-migration --rm -it \
  --image=ghcr.io/berriai/litellm-database:<NEW_VERSION> \
  --env="DATABASE_URL=$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d)" \
  --restart=Never \
  -n litellm \
  -- prisma migrate deploy
```

## Uninstalling

```bash
# Delete the Helm release
helm uninstall litellm -n litellm

# Delete the namespace (optional)
kubectl delete namespace litellm
```

**Note:** This will delete all data including the PostgreSQL database if using the bundled instance.

## Troubleshooting

### Pods not starting

**Check pod status:**
```bash
kubectl get pods -n litellm
kubectl describe pod <pod-name> -n litellm
```

**Common issues:**
- Missing master key: Ensure `litellm.masterKey` is set
- PVC binding issues: Check storage class availability
- Image pull errors: Verify network connectivity to ghcr.io

### Database connection errors

**Check database URL:**
```bash
kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d
```

**Test PostgreSQL connectivity:**
```bash
kubectl run -it --rm psql-test \
  --image=postgres:15 \
  --restart=Never \
  -n litellm \
  -- psql "$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d)" -c '\dt'
```

### Migration failures

**View migration logs:**
```bash
# If the migration pod is still running
kubectl logs litellm-migration -n litellm

# Check for existing migrations
kubectl run -it --rm psql-check \
  --image=postgres:15 \
  --restart=Never \
  -n litellm \
  -- psql "$(kubectl get secret litellm-litellm-openshift -n litellm -o jsonpath='{.data.database-url}' | base64 -d)" \
  -c "SELECT * FROM _prisma_migrations;"
```

### Route not accessible

**Check Route status:**
```bash
oc get route litellm-litellm-openshift -n litellm
oc describe route litellm-litellm-openshift -n litellm
```

**Test internal service:**
```bash
kubectl run -it --rm curl-test \
  --image=curlimages/curl \
  --restart=Never \
  -n litellm \
  -- curl -v http://litellm-litellm-openshift:4000/health/readiness
```

### API requests failing

**Check logs:**
```bash
kubectl logs -f deployment/litellm-litellm-openshift -n litellm
```

**Common issues:**
- Invalid API keys: Verify environment variables are set correctly
- Model not configured: Check `litellm.config.model_list`
- Rate limiting: Check LLM provider quotas

## Security Considerations

### Secrets Management

**Never commit secrets to version control.** Use one of these approaches:

1. **Kubernetes Secrets (recommended):**
   ```bash
   kubectl create secret generic llm-api-keys \
     --from-literal=openai=sk-your-key \
     --from-literal=anthropic=sk-ant-your-key \
     -n litellm
   ```

2. **External Secrets Operator:**
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: llm-api-keys
   spec:
     secretStoreRef:
       name: vault-backend
       kind: SecretStore
     target:
       name: llm-api-keys
     data:
       - secretKey: openai
         remoteRef:
           key: llm/openai
   ```

3. **Sealed Secrets:**
   ```bash
   kubeseal --format yaml < secret.yaml > sealed-secret.yaml
   ```

### Master Key

Generate a strong master key:

```bash
openssl rand -hex 32
```

Store it securely and never expose it in logs or error messages.

### Salt Key

The salt key encrypts LLM API credentials in the database. **Warning:** Changing the salt key after configuration will make existing encrypted credentials unreadable.

### Network Security

- Use TLS for external access (enabled by default)
- Consider NetworkPolicies to restrict pod-to-pod communication
- Use OpenShift SCC (Security Context Constraints) for pod security

## Performance Tuning

### Scaling

Increase replicas for higher throughput:

```yaml
replicaCount: 3
```

**Note:** Multiple replicas require proper PostgreSQL connection pooling configuration.

### Resource Limits

Adjust based on your workload:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

### Database Performance

For high-traffic deployments, consider:

- External PostgreSQL with connection pooling (PgBouncer)
- Increased PostgreSQL resources
- SSD storage for database

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This Helm chart is licensed under the MIT License.

LiteLLM is licensed under its own terms. See [LiteLLM License](https://github.com/BerriAI/litellm/blob/main/LICENSE).

## Resources

- **LiteLLM Documentation:** https://docs.litellm.ai/
- **LiteLLM GitHub:** https://github.com/BerriAI/litellm
- **OpenShift Documentation:** https://docs.openshift.com/
- **Helm Documentation:** https://helm.sh/docs/

## Support

For issues specific to this Helm chart, please open an issue in this repository.

For LiteLLM-specific questions, refer to:
- LiteLLM Discord: https://discord.com/invite/wuPM9dRgDw
- LiteLLM GitHub Issues: https://github.com/BerriAI/litellm/issues
