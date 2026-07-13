SHELL := /bin/bash

TF := terraform

SSH_USER := fedora
ROOT_USER := root
SSH_KEY := $(HOME)/.ssh/id_rsa
BOOTC_IMAGE ?= ghcr.io/lmilbaum/bootc-poc:1.0.0

SSH_OPTIONS := \
	-o BatchMode=yes \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	-o ConnectTimeout=5 \
	-i $(SSH_KEY)

IP = $(shell $(TF) output -raw public_ip 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: \
	help \
	init fmt validate plan \
	provision ready \
	test logs \
	ssh root \
	prefetch bootstrap status switch upgrade \
	destroy clean

###############################################################################
# Help
###############################################################################

help:
	@echo ""
	@echo "bootc-infra"
	@echo ""
	@echo "Terraform"
	@echo "  make init         Initialize Terraform"
	@echo "  make fmt          Format Terraform files"
	@echo "  make validate     Validate Terraform configuration"
	@echo "  make plan         Show Terraform execution plan"
	@echo "  make provision    Create infrastructure"
	@echo "  make destroy      Destroy infrastructure"
	@echo ""
	@echo "Instance"
	@echo "  make ready        Wait until cloud-init completes"
	@echo "  make test         Verify installed software"
	@echo "  make logs         Show provisioning log"
	@echo "  make ssh          SSH as fedora"
	@echo "  make root         SSH as root"
	@echo ""
	@echo "bootc"
	@echo "  make prefetch     Pull BOOTC_IMAGE onto the host before boot operations"
	@echo "  make bootstrap    Convert to a bootc-managed system"
	@echo "  make status       Show bootc status"
	@echo "  make switch       Switch bootc to BOOTC_IMAGE (override with BOOTC_IMAGE=...)"
	@echo "  make upgrade      Run bootc upgrade"
	@echo ""

###############################################################################
# Terraform
###############################################################################

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

plan:
	$(TF) plan

provision:
	$(TF) apply -auto-approve

destroy:
	$(TF) destroy -auto-approve

clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl

###############################################################################
# Instance
###############################################################################

ready:
	@echo "Waiting for cloud-init..."

	@ssh $(SSH_OPTIONS) $(SSH_USER)@$(IP) \
	  "sudo cloud-init status --wait && \
	   bootc --version && \
	   podman --version"

	@echo "Instance is ready."

###############################################################################
# Verification
###############################################################################

test: ready
	@ssh $(SSH_OPTIONS) \
		$(SSH_USER)@$(IP) \
		"bootc --version && \
		 podman --version && \
		 skopeo --version"

logs: ready
	@ssh $(SSH_OPTIONS) \
		$(SSH_USER)@$(IP) \
		"sudo cat /var/log/bootc.log"

###############################################################################
# SSH
###############################################################################

ssh: ready
	@ssh $(SSH_OPTIONS) \
		$(SSH_USER)@$(IP)

root:
	@ssh $(SSH_OPTIONS) \
		$(ROOT_USER)@$(IP)

###############################################################################
# bootc
###############################################################################

prefetch:
	@ssh $(SSH_OPTIONS) \
		$(ROOT_USER)@$(IP) \
		"podman pull $(BOOTC_IMAGE)"

bootstrap: ready
	BOOTC_IMAGE="$(BOOTC_IMAGE)" ./scripts/bootstrap.sh "$(IP)" "$(SSH_KEY)"

status:
	@ssh $(SSH_OPTIONS) \
		$(ROOT_USER)@$(IP) \
		"bootc status"

switch: prefetch
	@ssh $(SSH_OPTIONS) \
		$(ROOT_USER)@$(IP) \
		"bootc switch --transport containers-storage --apply $(BOOTC_IMAGE)"

upgrade:
	@ssh $(SSH_OPTIONS) \
		$(ROOT_USER)@$(IP) \
		"bootc upgrade"