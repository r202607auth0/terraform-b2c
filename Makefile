# Thin wrapper so nobody has to remember which backend config pairs with which
# tfvars. Every target re-runs init with -reconfigure, which is what stops a
# stale .terraform/ from pointing dev commands at prod state.

SHELL := /bin/bash
ENV   ?= dev
STACK ?= b2c

TF        := terraform -chdir=stacks/$(STACK)
BACKEND   := ../../environments/$(ENV)/$(STACK).backend.hcl
TFVARS    := ../../environments/$(ENV)/$(STACK).tfvars

.PHONY: help init fmt validate plan apply destroy output drift check-env

help:
	@echo "usage: make <target> ENV=dev|qa|staging|prod STACK=b2c|tenant"
	@echo ""
	@echo "  init      terraform init with the environment backend"
	@echo "  fmt       terraform fmt -recursive"
	@echo "  validate  init -backend=false + validate for every stack"
	@echo "  plan      plan against ENV"
	@echo "  apply     apply against ENV"
	@echo "  output    show stack outputs"
	@echo "  drift     plan -detailed-exitcode (2 == drift)"
	@echo ""
	@echo "order matters on a first run: STACK=b2c before STACK=tenant"

check-env:
	@test -n "$$AUTH0_DOMAIN"        || { echo "AUTH0_DOMAIN is not set"; exit 1; }
	@test -n "$$AUTH0_CLIENT_ID"     || { echo "AUTH0_CLIENT_ID is not set"; exit 1; }
	@test -n "$$AUTH0_CLIENT_SECRET" || { echo "AUTH0_CLIENT_SECRET is not set"; exit 1; }

init: check-env
	$(TF) init -reconfigure -backend-config=$(BACKEND)

fmt:
	terraform fmt -recursive

validate:
	@for s in stacks/b2c stacks/tenant; do \
		echo "--- $$s"; \
		terraform -chdir=$$s init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$s validate; \
	done

plan: init
	$(TF) plan -var-file=$(TFVARS) -out=tfplan.$(ENV).$(STACK)

apply: init
	$(TF) apply -var-file=$(TFVARS) -auto-approve

output: init
	$(TF) output -json

drift: init
	$(TF) plan -var-file=$(TFVARS) -detailed-exitcode

destroy: init
	@test "$(ENV)" != "prod" || { echo "refusing to destroy prod"; exit 1; }
	$(TF) destroy -var-file=$(TFVARS)
