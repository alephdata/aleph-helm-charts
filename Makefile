ENV="staging"
PREFIX="aleph"

create-cluster:
	@echo "🔴 Creating a k8s cluster ..."
	kind create cluster --name alephlocal --config kind-config.yml

setup-kubectl:
	@echo "🔴 Setting kubectl context to the local k8s cluster"
	kubectl config use-context kind-alephlocal

delete-cluster:
	@echo "🔴 Deleteing the k8s cluster ..."
	kind delete cluster --name alephlocal

add-helm-repo:
	@echo "🔴 Adding helm repos ..."
	helm repo add --force-update bitnami https://charts.bitnami.com/bitnami
	helm repo add --force-update elastic https://helm.elastic.co
	helm repo add --force-update k8s-dashboard https://kubernetes.github.io/dashboard

update-helm:
	@echo "🔴 Updating the helm repos ..."
	helm repo update

install-postgres: update-helm
	@echo "🔴 Installing Postgres database ..."
	helm install $(PREFIX)-postgres bitnami/postgresql -f charts/values/postgres.yml -n $(ENV)

install-elasticsearch: update-helm
	@echo "🔴 Installing Elasticsearch cluster ..."
	helm install $(PREFIX)-index-master elastic/elasticsearch -f charts/values/elasticsearch-master.yml --set masterService="$(PREFIX)-index-master" --set clusterName="$(PREFIX)-index" -n $(ENV)
	helm install $(PREFIX)-index-data elastic/elasticsearch -f charts/values/elasticsearch-data.yml --set masterService="$(PREFIX)-index-master" --set clusterName="$(PREFIX)-index" -n $(ENV)

install-k8s-dashboard: update-helm
	helm install k8s-dashboard k8s-dashboard/kubernetes-dashboard

install-redis: update-helm
	@echo "🔴 Installing Redis ..."
	helm install $(PREFIX)-redis bitnami/redis -f charts/values/redis.yml -n $(ENV)


install-ingress:
	@echo "🔴 Installing Nginx Ingress  ..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx \
	--for=condition=ready pod \
	--selector=app.kubernetes.io/component=controller \
	--timeout=90s


create-secrets:
	kubectl delete --ignore-not-found=true secret aleph-secrets
	kubectl create secret generic aleph-secrets --from-file=secrets/$(ENV)/aleph

create-service-accounts:
	kubectl delete --ignore-not-found=true secret service-account-aleph
	kubectl create secret generic service-account-aleph --from-file=service-account.json=secrets/$(ENV)/service-accounts/service-account-aleph.json


create-infra: create-cluster setup-kubectl add-helm-repo update-helm

create-services: install-postgres install-elasticsearch install-redis

install-aleph:
	@echo "🔴 Installing Aleph  ..."
	helm install aleph ./charts/aleph -f ./charts/values/$(ENV).yaml -n $(ENV) --timeout 10m0s