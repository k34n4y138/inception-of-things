provision-vm:
	./scripts/vm_provisioning.sh

setup-cluster:
	ssh debian-iot "bash -s" < ./scripts/cluster_setup.sh

deploy-demo-app:
	ssh debian-iot "bash -c" 'kubectl apply -f -' < ./manifests/argocd.yaml

all: provision-vm setup-cluster deploy-demo-app
