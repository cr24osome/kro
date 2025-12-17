#!/bin/bash
# Setup script for local ArgoCD testing with kro

set -e

# ArgoCD Server Configuration
ARGOCD_SERVER="localhost:8221"
ARGOCD_OPTS="--insecure"  # For self-signed certs on localhost

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ArgoCD + kro Local Testing Setup ===${NC}"
echo -e "ArgoCD Server: https://${ARGOCD_SERVER}"
echo ""

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    echo -e "${RED}argocd CLI not found. Install it with: brew install argocd${NC}"
    exit 1
fi

# Login to ArgoCD
echo -e "${YELLOW}Step 0: Login to ArgoCD${NC}"
echo "Run: argocd login ${ARGOCD_SERVER} ${ARGOCD_OPTS}"
echo "(You'll be prompted for username and password)"
echo ""

read -p "Press Enter after you've logged in (or 's' to skip): " skip_login
if [ "$skip_login" != "s" ]; then
    argocd login ${ARGOCD_SERVER} ${ARGOCD_OPTS}
fi

# Check if git repo exists, if not initialize it
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Initializing git repository...${NC}"
    git init
    git add rgd.yml rgd-sidecar.yml instance.yaml
    git commit -m "Initial commit: kro resources"
fi

echo ""
echo -e "${GREEN}=== Option 1: Use Local Git Repo ===${NC}"
echo "This method mounts the local repo directly into ArgoCD"
echo ""

# Get the current directory
REPO_PATH=$(pwd)

echo -e "${YELLOW}Step 1: Add local repo to ArgoCD${NC}"
echo "Run: argocd repo add ${REPO_PATH} --type git --name kro-local --server ${ARGOCD_SERVER} ${ARGOCD_OPTS}"
echo ""

echo -e "${YELLOW}Step 2: Create the Application${NC}"
echo "Run: kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kro-local-test
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_PATH}
    targetRevision: HEAD
    path: .
    directory:
      recurse: false
      include: '*.yaml'
      exclude: 'argocd-*.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
EOF"

echo ""
echo -e "${GREEN}=== Option 2: Push to GitHub and Use Remote ===${NC}"
echo "This is the recommended approach for proper GitOps testing"
echo ""
echo "1. Create a GitHub repo"
echo "2. Push your code: git remote add origin <your-repo-url> && git push -u origin main"
echo "3. Apply the ApplicationSet: kubectl apply -f argocd-applicationset.yaml"
echo ""

echo -e "${GREEN}=== Useful Commands ===${NC}"
echo "Check ArgoCD apps:    argocd app list --server ${ARGOCD_SERVER} ${ARGOCD_OPTS}"
echo "Sync manually:        argocd app sync kro-local-test --server ${ARGOCD_SERVER} ${ARGOCD_OPTS}"
echo "Get app status:       argocd app get kro-local-test --server ${ARGOCD_SERVER} ${ARGOCD_OPTS}"
echo "Watch app:            argocd app get kro-local-test --watch --server ${ARGOCD_SERVER} ${ARGOCD_OPTS}"
echo "Check kro resources:  kubectl get resourcegraphdefinitions"
echo "Check kro instance:   kubectl get applications.kro.run"
echo ""

echo -e "${GREEN}=== Verify kro is working ===${NC}"
echo "After sync, check:"
echo "  kubectl get deployment my-app"
echo "  kubectl get service my-app-svc"
echo "  kubectl get applications.kro.run my-application -o yaml"

