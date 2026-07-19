#!/bin/bash

# Deployment script for LiteLLM on OpenShift
# This script deploys LiteLLM with bundled PostgreSQL

set -e

# Configuration
NAMESPACE=${NAMESPACE:-litellm}
RELEASE_NAME=${RELEASE_NAME:-litellm}
MASTER_KEY=${MASTER_KEY:-demo123}
DB_PASSWORD=${DB_PASSWORD:-demo123}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       LiteLLM OpenShift Deployment                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Namespace:     $NAMESPACE"
echo "  Release Name:  $RELEASE_NAME"
echo "  Master Key:    $MASTER_KEY"
echo "  DB Password:   $DB_PASSWORD"
echo ""

# Check if namespace exists
if ! oc get namespace $NAMESPACE &>/dev/null; then
  echo "Creating namespace $NAMESPACE..."
  oc create namespace $NAMESPACE
fi

# Update Helm dependencies
echo "Updating Helm dependencies..."
cd helm/litellm-openshift
helm dependency update

# Deploy the chart
echo ""
echo "Deploying LiteLLM..."
helm upgrade --install $RELEASE_NAME . \
  --namespace $NAMESPACE \
  --set masterKey="$MASTER_KEY" \
  --set postgresql.auth.password="$DB_PASSWORD" \
  --set litellm.db.endpoint="${RELEASE_NAME}-postgresql.${NAMESPACE}.svc.cluster.local" \
  --set litellm.db.secret.name="${RELEASE_NAME}-db" \
  --set litellm.masterkeySecretName="${RELEASE_NAME}-masterkey" \
  --set "litellm.environmentSecrets[0]=${RELEASE_NAME}-env" \
  --set "litellm.proxy_config.model_list[0].model_name=llama-32-3b-instruct" \
  --set "litellm.proxy_config.model_list[0].litellm_params.model=openai/llama-32-3b-instruct" \
  --set "litellm.proxy_config.model_list[0].litellm_params.api_base=http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local:8080/v1" \
  --set "litellm.proxy_config.model_list[0].litellm_params.api_key=dummy" \
  --wait --timeout=10m

echo ""
echo "✅ Deployment complete!"
echo ""

# Wait for PostgreSQL
echo "Waiting for PostgreSQL to be ready..."
oc wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n $NAMESPACE --timeout=300s || true

# Wait for LiteLLM
echo "Waiting for LiteLLM to be ready..."
oc wait --for=condition=ready pod -l app.kubernetes.io/name=litellm -n $NAMESPACE --timeout=300s || true

# Get Route URL
echo ""
echo "Getting access information..."
ROUTE_URL=$(oc get route ${RELEASE_NAME}-litellm -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "Route not found")

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Deployment Summary                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "LiteLLM URL:    https://$ROUTE_URL"
echo "Master Key:     $MASTER_KEY"
echo "Namespace:      $NAMESPACE"
echo ""
echo "Test the deployment:"
echo "  curl -k https://$ROUTE_URL/health/readiness"
echo ""
echo "Test the API:"
echo "  curl -k https://$ROUTE_URL/v1/chat/completions \\"
echo "    -H \"Authorization: Bearer $MASTER_KEY\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"model\": \"llama-32-3b-instruct\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
echo ""
echo "View pods:"
echo "  oc get pods -n $NAMESPACE"
echo ""
echo "View logs:"
echo "  oc logs -l app.kubernetes.io/name=litellm -n $NAMESPACE -f"
echo ""
