# Copyright IBM Corp All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		 http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# -------------------------------------------------------------
# This makefile defines the following targets
#
#   - all (default) - builds all targets and runs all tests
#   - license - check all go files for license headers
#   - fabric-ca - builds the fabric-ca executable
#   - unit-tests - Performs checks first and runs the go-test based unit tests
#   - checks - runs all check conditions (license, format, imports, lint and vet)
#   - ldap-tests - runs the LDAP tests
#   - docker[-clean] - ensures all docker images are available[/cleaned]
#   - clean - cleans the build area

PROJECT_NAME   = fabric-ca
BASE_VERSION   = 0.7.0
IS_RELEASE     = false

ifneq ($(IS_RELEASE),true)
EXTRA_VERSION ?= snapshot-$(shell git rev-parse --short HEAD)
PROJECT_VERSION=$(BASE_VERSION)-$(EXTRA_VERSION)
else
PROJECT_VERSION=$(BASE_VERSION)
endif

# Check that all dependencies are installed
EXECUTABLES = go docker git curl
K := $(foreach exec,$(EXECUTABLES),\
	$(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH: Check dependencies")))

ARCH=$(shell uname -m)
BASEIMAGE_RELEASE = 0.3.0
PKGNAME = github.com/hyperledger/$(PROJECT_NAME)
SAMPLECONFIG = $(shell git ls-files images/fabric-ca/config)

DOCKER_ORG = hyperledger
IMAGES = $(PROJECT_NAME)

image-path-map.fabric-ca := fabric-ca

include docker-env.mk

all: rename docker unit-tests

rename: .FORCE
	@scripts/rename-repo

docker: $(patsubst %,build/image/%/$(DUMMY), $(IMAGES))

checks: license vet lint format imports

license: .FORCE
	@scripts/check_license

format: .FORCE
	@scripts/check_format

imports: .FORCE
	@scripts/check_imports

lint: .FORCE
	@scripts/check_lint

vet: .FORCE
	@scripts/check_vet

fabric-ca:
	@echo "Building fabric-ca in bin directory ..."
	@mkdir -p bin && go build -o bin/fabric-ca
	@echo "Built bin/fabric-ca"

# We (re)build a package within a docker context but persist the $GOPATH/pkg
# directory so that subsequent builds are faster
build/docker/bin/fabric-ca:
	@echo "Building $@"
	@mkdir -p $(@D) build/docker/$(@F)/pkg
	@$(DRUN) \
		-v $(abspath build/docker/bin):/opt/gopath/bin \
		-v $(abspath build/docker/$(@F)/pkg):/opt/gopath/pkg \
		hyperledger/fabric-baseimage:$(BASE_DOCKER_TAG) \
		go install -ldflags "$(DOCKER_GO_LDFLAGS)" $(PKGNAME)
	@touch $@

build/docker/busybox:
	@echo "Building $@"
	@$(DRUN) \
		hyperledger/fabric-baseimage:$(BASE_DOCKER_TAG) \
		make -f busybox/Makefile install BINDIR=$(@D)

# payload definitions
build/image/$(PROJECT_NAME)/payload:	build/docker/bin/fabric-ca \
					build/sampleconfig.tar.bz2

build/image/%/payload:
	mkdir -p $@
	cp images/fabric-ca/root.pem $@/root.pem
	cp images/fabric-ca/tls_client-cert.pem $@/tls_client-cert.pem
	cp images/fabric-ca/tls_client-key.pem $@/tls_client-key.pem
	cp images/fabric-ca/ec.pem $@/ec.pem
	cp images/fabric-ca/ec-key.pem $@/ec-key.pem
	cp $^ $@

build/image/%/$(DUMMY): Makefile build/image/%/payload
	$(eval TARGET = ${patsubst build/image/%/$(DUMMY),%,${@}})
	$(eval DOCKER_NAME = $(DOCKER_ORG)/$(TARGET))
	@echo "Building docker $(TARGET) image"
	@cat images/$(image-path-map.$(TARGET))/Dockerfile.in \
		| sed -e 's/_BASE_TAG_/$(BASE_DOCKER_TAG)/g' \
		| sed -e 's/_TAG_/$(DOCKER_TAG)/g' \
		> $(@D)/Dockerfile
	$(DBUILD) -t $(DOCKER_NAME) $(@D)
	docker tag $(DOCKER_NAME) $(DOCKER_NAME):$(DOCKER_TAG)
	@touch $@

build/sampleconfig.tar.bz2: $(SAMPLECONFIG)
	tar -jc -C images/fabric-ca/config $(patsubst images/fabric-ca/config/%,%,$(SAMPLECONFIG)) > $@

unit-tests: checks fabric-ca
	@scripts/run_tests

container-tests: ldap-tests

ldap-tests:
	@scripts/run_ldap_tests

fvt-tests: fabric-ca
	@scripts/run_fvt_tests

%-docker-clean:
	$(eval TARGET = ${patsubst %-docker-clean,%,${@}})
	-docker images -q $(DOCKER_ORG)/$(TARGET):latest | xargs -I '{}' docker rmi -f '{}'
	-@rm -rf build/image/$(TARGET) ||:

docker-clean: $(patsubst %,%-docker-clean, $(IMAGES))

.PHONY: clean
clean: docker-clean
	-@rm -rf build bin ||:

.FORCE:
