
all: provision-vm setup-cluster deploy-demo-app


provision-vm:
	./scripts/vm_provisioning.sh

setup-cluster:
	ssh debian-iot "bash -s" < ./scripts/cluster_setup.sh

deploy-demo-app:
	ssh debian-iot "bash -c" 'kubectl apply -f -' < ./manifests/argocd.yaml

get-argocd-admin-password:
	ssh debian-iot "bash -c" 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo'
