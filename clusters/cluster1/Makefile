make init:
	kind create cluster --name cluster0-kind --config kind-config.yaml
	make apply
make delete:
	kind delete cluster --name cluster0-kind

make apply:
	kubectl create namespace monitoring || true
	kustomize build monitoring --enable-helm | kubectl apply --server-side -f - || true
	kubectl create namespace argocd
	kustomize build argocd --enable-helm | kubectl apply --server-side -f -
	kubectl apply -f argocd/apps
	kubectl apply -f ../../secret.yaml
	make secrets

make local:
	kubectl create namespace monitoring || true
	kustomize build kube-system --enable-helm | kubectl apply --server-side -f - || true
	kustomize build tailscale --enable-helm | kubectl apply --server-side -f - || true
	kustomize build default --enable-helm | kubectl apply --server-side -f - || true
	kubectl apply -f ../../secret.yaml
	make secrets

make secrets:
	@if [ -z "$$CLIENT_ID" ] || [ -z "$$CLIENT_SECRET" ]; then \
		echo "Error: CLIENT_ID and CLIENT_SECRET environment variables must be set"; \
		echo "Set them with: export CLIENT_ID=your-client-id export CLIENT_SECRET=your-client-secret"; \
		exit 1; \
	fi
	kubectl create namespace tailscale --dry-run=client -o yaml | kubectl apply -f -
	kubectl delete secret operator-oauth --namespace tailscale || true
	kubectl create secret generic operator-oauth --namespace tailscale \
		--from-literal=client_id="$$CLIENT_ID" \
		--from-literal=client_secret="$$CLIENT_SECRET"

make restart:
	make delete && make init