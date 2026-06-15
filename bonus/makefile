

all: provision-vm setup-cluster bonus


provision-vm:
	./scripts/vm_provisioning.sh

open-bonus-ports:
	vboxmanage controlvm debian-iot natpf1 "gitea-http,tcp,,8068,,8068"
	vboxmanage controlvm debian-iot natpf1 "gitea-ssh,tcp,,8069,,8069"
	ssh debian-iot "bash -c" 'k3d cluster edit main --port-add "8068:8068@loadbalancer" --port-add "8069:8069@loadbalancer"'

setup-cluster:
	ssh debian-iot "bash -s" < ./scripts/cluster_setup.sh

deploy-gitea:
	ssh debian-iot "bash -c"  'kubectl apply -f -' < ./manifests/gitea-argocd.yaml
	ssh debian-iot "bash -s" < ./scripts/generate_gitea_admin_secret.sh

demoapp-to-gitea:
	bash ./scripts/demoapp_to_gitea.sh

demoapp-to-argocd:
	ssh debian-iot "bash -c" 'kubectl apply -f -' < ./manifests/application/argocd.yaml

get-argocd-admin-password:
	ssh debian-iot "bash -c" 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo'


bonus: open-bonus-ports deploy-gitea demoapp-to-gitea demoapp-to-argocd


