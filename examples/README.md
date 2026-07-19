# LiteLLM Deployment Examples

This directory contains example values files for deploying LiteLLM on OpenShift.

## Available Examples

### 1. Basic Deployment (`basic-deployment.yaml`)

Minimal configuration with bundled PostgreSQL and OpenAI integration.

**Features:**
- Bundled PostgreSQL database
- OpenAI GPT-4 model configuration
- OpenShift Route enabled

**Before deploying:**
- Replace `sk-your-openai-key-here` with your actual OpenAI API key in the values file

**Deploy:**
```bash
cd helm/litellm-openshift
helm dependency update

helm install litellm . \
  -f ../../examples/basic-deployment.yaml \
  --namespace litellm \
  --create-namespace \
  --set masterKey="demo123" \
  --set postgresql.auth.password="demo123" \
  --set litellm.db.endpoint="litellm-postgresql.litellm.svc.cluster.local" \
  --set litellm.db.secret.name="litellm-db" \
  --set litellm.masterkeySecretName="litellm-masterkey" \
  --set "litellm.environmentSecrets[0]=litellm-env"

# Create OpenShift Route
oc create route edge litellm --service=litellm -n litellm
```

---

### 2. External Database (`external-database.yaml`)

Use an existing external PostgreSQL database instead of the bundled one.

**Features:**
- External PostgreSQL connection
- OpenAI GPT-4 model configuration
- OpenShift Route enabled

**Before deploying:**
1. Update the endpoint in the values file to match your PostgreSQL host
2. Replace `sk-your-openai-key-here` with your actual OpenAI API key in the values file

**Deploy:**
```bash
cd helm/litellm-openshift
helm dependency update

# Create namespace
oc create namespace litellm

# Create database secret (for external database credentials)
kubectl create secret generic litellm-db \
  --from-literal=username=litellm \
  --from-literal=password=your-db-password \
  -n litellm

# Install chart
helm install litellm . \
  -f ../../examples/external-database.yaml \
  --namespace litellm \
  --set masterKey="demo123" \
  --set litellm.db.endpoint="your-postgresql-host.example.com" \
  --set litellm.db.secret.name="litellm-db" \
  --set litellm.masterkeySecretName="litellm-masterkey" \
  --set "litellm.environmentSecrets[0]=litellm-env"

# Create OpenShift Route
oc create route edge litellm --service=litellm -n litellm
```

---

### 3. Internal Model Deployment (`internal-model-deployment.yaml`)

Connect LiteLLM to a model deployed within your OpenShift cluster.

**Features:**
- Bundled PostgreSQL database
- Internal model service connection
- OpenShift Route enabled

**Before deploying:**
1. Verify your model service is running:
   ```bash
   oc get svc -n <model-namespace>
   ```

2. Find the correct port (check container ports):
   ```bash
   oc get pod <model-pod-name> -n <model-namespace> -o jsonpath='{.spec.containers[*].ports}'
   ```

3. Update the `api_base` in the values file to match your model service:
   ```yaml
   api_base: http://<service-name>.<namespace>.svc.cluster.local:<port>/v1
   ```

**Deploy:**
```bash
cd helm/litellm-openshift
helm dependency update

helm install litellm . \
  -f ../../examples/internal-model-deployment.yaml \
  --namespace litellm \
  --create-namespace \
  --set masterKey="demo123" \
  --set postgresql.auth.password="demo123" \
  --set litellm.db.endpoint="litellm-postgresql.litellm.svc.cluster.local" \
  --set litellm.db.secret.name="litellm-db" \
  --set litellm.masterkeySecretName="litellm-masterkey" \
  --set "litellm.environmentSecrets[0]=litellm-env"

# Create OpenShift Route
oc create route edge litellm --service=litellm -n litellm
```

**Test the deployment:**
```bash
# Get Route URL
export ROUTE_URL=$(oc get route litellm -n litellm -o jsonpath='{.spec.host}')

# Create Route if not exists
oc create route edge litellm --service=litellm -n litellm 2>/dev/null || true

# Test API
curl -k https://$ROUTE_URL/v1/chat/completions \
  -H "Authorization: Bearer demo123" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-32-3b-instruct",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## Common Deployment Steps

### 1. Update Helm Dependencies

Before installing, update the Helm dependencies:

```bash
cd helm/litellm-openshift
helm dependency update
```

### 2. Create Namespace

```bash
oc create namespace litellm
```

### 3. Install the Chart

Choose one of the examples above and deploy using the appropriate command.

### 4. Create OpenShift Route (if needed)

The official LiteLLM chart doesn't automatically create OpenShift Routes. Create one manually:

```bash
oc create route edge litellm --service=litellm -n litellm
```

### 5. Verify Deployment

```bash
# Check pods
oc get pods -n litellm

# Check Route
oc get route -n litellm

# Test health endpoint
export ROUTE_URL=$(oc get route litellm -n litellm -o jsonpath='{.spec.host}')
curl -k https://$ROUTE_URL/health/readiness
```

---

## Configuration Reference

### Required Values

These values must be set via `--set` flags during installation:

- `litellm.db.endpoint` - PostgreSQL endpoint
- `litellm.db.secret.name` - Database credentials secret name
- `litellm.masterkeySecretName` - Master key secret name
- `litellm.environmentSecrets[0]` - Environment secrets name

### Example --set Commands

**For bundled PostgreSQL:**
```bash
--set masterKey="demo123" \
--set postgresql.auth.password="demo123" \
--set litellm.db.endpoint="litellm-postgresql.litellm.svc.cluster.local" \
--set litellm.db.secret.name="litellm-db" \
--set litellm.masterkeySecretName="litellm-masterkey" \
--set "litellm.environmentSecrets[0]=litellm-env"
```

**For external PostgreSQL:**
```bash
--set masterKey="demo123" \
--set litellm.db.endpoint="your-postgresql-host.example.com" \
--set litellm.db.secret.name="litellm-db" \
--set litellm.masterkeySecretName="litellm-masterkey" \
--set "litellm.environmentSecrets[0]=litellm-env"
```

**Note:** The `masterKey` and `postgresql.auth.password` values in the examples use "demo123" for demonstration. In production, use strong randomly generated passwords.

---

## Troubleshooting

### Database Connection Errors

Check if PostgreSQL is running:
```bash
oc get pods -l app.kubernetes.io/name=postgresql -n litellm
```

### Model Connection Errors

**Common issue:** Wrong port number in `api_base` configuration.

Verify the model service endpoint and port:
```bash
# Check if model service exists
oc get svc <model-service-name> -n <model-namespace>

# Find the actual container port
oc get pod <model-pod-name> -n <model-namespace> -o jsonpath='{.spec.containers[*].ports}'

# Test connectivity from within the cluster (use the container port, not service port)
oc run curl-test --rm -i --restart=Never --image=curlimages/curl \
  -- curl -s http://<model-service>.<namespace>.svc.cluster.local:<container-port>/v1/models
```

**Important:** Use the container port (e.g., 8080), not the service port (e.g., 80). The service may define one port but the container listens on another.

### Route Not Found

Create the route manually:
```bash
oc create route edge litellm --service=litellm -n litellm
```

### View Logs

```bash
# LiteLLM logs
oc logs -l app.kubernetes.io/name=litellm -n litellm -f

# PostgreSQL logs
oc logs -l app.kubernetes.io/name=postgresql -n litellm -f
```

---

## Security Notes

**Production Deployments:**

1. Use strong, randomly generated passwords:
   ```bash
   openssl rand -hex 32
   ```

2. Store secrets securely using Kubernetes Secrets or external secret managers

3. Never commit secrets to version control

4. Rotate credentials regularly

5. Enable TLS for database connections in production
