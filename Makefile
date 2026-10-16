# Common entry points. Everything here is also documented in README.md.
IMAGE_BACKEND  ?= ghcr.io/prateek-singhwy/lostfound-backend
IMAGE_FRONTEND ?= ghcr.io/prateek-singhwy/lostfound-frontend
TAG            ?= local
NS             ?= lostfound

.PHONY: test lint build up down k8s-up k8s-deploy k8s-smoke monitoring tf-plan

lint:
	cd app/backend && flake8 app tests
	docker run --rm -i hadolint/hadolint:latest-debian hadolint --ignore DL3008 - < app/backend/Dockerfile
	docker run --rm -i hadolint/hadolint:latest-debian hadolint - < app/frontend/Dockerfile

test:
	cd app/backend && pytest

build:
	docker build -t $(IMAGE_BACKEND):$(TAG) --build-arg GIT_SHA=$(TAG) app/backend
	docker build -t $(IMAGE_FRONTEND):$(TAG) app/frontend

up:            ## local three-tier stack
	docker compose up -d --build

down:
	docker compose down -v

k8s-up:        ## single-node cluster with ingress + metrics-server
	./scripts/cluster-up.sh

k8s-deploy:    ## build images into minikube and helm upgrade --install
	./scripts/deploy.sh $(TAG)

k8s-smoke:
	./scripts/smoke-test.sh

monitoring:    ## kube-prometheus-stack + app dashboard + alert rules
	./scripts/monitoring-up.sh

tf-plan:
	cd terraform && terraform init -input=false && terraform plan -input=false
