ARCH ?=amd64
ALL_ARCH = amd64 arm64

IMAGE ?= docker.io/oats87/hyperkube-base
TAG ?= v0.0.1

BASEIMAGE ?= ubuntu:22.04

CNI_VERSION ?= v1.3.0
FLANNEL_CNI_VERSION ?= v1.2.0
IPTWI_VERSION ?= v2

TEMP_DIR:=$(shell mktemp -d)

CNI_TARBALL=cni-plugins-linux-$(ARCH)-$(CNI_VERSION).tgz

all: all-push

sub-build-%:
	$(MAKE) ARCH=$* build

all-build: $(addprefix sub-build-,$(ALL_ARCH))

sub-push-image-%:
	$(MAKE) ARCH=$* push

all-push-images: $(addprefix sub-push-image-,$(ALL_ARCH))

all-push: all-push-images push-manifest

cni-tars/$(CNI_TARBALL):
	mkdir -p cni-tars/
	cd cni-tars/ && curl -sSLO --retry 5 https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/${CNI_TARBALL}

cni-bin/bin: cni-tars/$(CNI_TARBALL)
	mkdir -p cni-bin/bin
	tar -xz -C cni-bin/bin -f "cni-tars/${CNI_TARBALL}"
	curl -sSL --retry 5 -o cni-bin/bin/flannel https://github.com/flannel-io/cni-plugin/releases/download/${FLANNEL_CNI_VERSION}/flannel-$(ARCH)
	chmod +x cni-bin/bin/flannel

scripts/iptables-wrapper-installer.sh:
	mkdir -p scripts/
	cd scripts/ && curl -sSLO --retry 5 https://raw.githubusercontent.com/kubernetes-sigs/iptables-wrappers/${IPTWI_VERSION}/iptables-wrapper-installer.sh && chmod +x iptables-wrapper-installer.sh

clean:
	rm -rf cni-tars/
	rm -rf cni-bin/
	rm -f scripts/iptables-wrapper-installer.sh

build: clean cni-bin/bin scripts/iptables-wrapper-installer.sh
	docker build --pull --build-arg ARCH=${ARCH} -t $(IMAGE):$(TAG)-linux-$(ARCH) .

push: build
	docker push $(IMAGE):$(TAG)-$(ARCH)

.PHONY: all build push clean all-build all-push-images all-push

.DEFAULT_GOAL := build
