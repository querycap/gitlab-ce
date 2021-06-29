VERSION=$(shell cat ./Dockerfile.version | sed -e "s/FROM gitlab\/gitlab-ce://g")
SEMVER=$(word 1,$(subst -, ,$(VERSION)))
GIT_TAG=$(subst -,+,$(VERSION))

DOCKERX_HUB ?= docker.io/querycap
DOCKERX_NAME ?= gitlab-ce
DOCKERX_CONTEXT ?= ./build/$(DOCKERX_NAME)
DOCKERX_PUSH ?= true

DOCKERX_LABELS ?=
DOCKERX_BUILD_ARGS ?=
DOCKERX_TAGS ?= $(VERSION)

TARGET_ARCHS ?= arm64 amd64

ifeq ($(DOCKERX_PUSH),true)
	DOCKERX_ARGS = --push
endif

prepare-gitlab-ce: cleanup-gitlab clone-gitlab copy-gitlab-dockerfiles gen-gitlab-release

buildx-gitlab-ce: prepare-gitlab-ce
	$(MAKE) buildx DOCKERX_NAME=gitlab-ce DOCKERX_TAGS=$(VERSION)

buildx-gitlab-runner-helper:
	$(MAKE) buildx DOCKERX_NAME=gitlab-runner-helper DOCKERX_BUILD_ARGS=VERSION=$(SEMVER) DOCKERX_TAGS=$(SEMVER)

buildx:
	docker buildx build $(DOCKERX_ARGS)\
		$(foreach h,$(DOCKERX_HUB),$(foreach t,$(DOCKERX_TAGS),--tag=$(h)/$(DOCKERX_NAME):$(t))) \
		$(foreach p,$(TARGET_ARCHS),--platform=linux/$(p)) \
		$(foreach a,$(DOCKERX_BUILD_ARGS),--build-arg=$(a)) \
		$(foreach l,$(DOCKERX_LABELS),--label=$(l)) \
		--file $(DOCKERX_CONTEXT)/Dockerfile $(DOCKERX_CONTEXT)


TEMP_GITLAB=.tmp/gitlab

cleanup-gitlab:
	rm -rf $(DOCKERX_CONTEXT)/
	rm -rf $(TEMP_GITLAB)/

clone-gitlab:
	git clone --depth=1 -b $(GIT_TAG) https://gitlab.com/gitlab-org/omnibus-gitlab $(TEMP_GITLAB)

gen-gitlab-release:
	$(foreach arch,$(TARGET_ARCHS),echo "RELEASE_PACKAGE=gitlab-ce\nRELEASE_VERSION=$(VERSION)\nDOWNLOAD_URL=https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/focal/gitlab-ce_$(VERSION)_${arch}.deb/download.deb" > $(DOCKERX_CONTEXT)/RELEASE-${arch};)

copy-gitlab-dockerfiles:
	mkdir -p $(DOCKERX_CONTEXT)/ && cp -r $(TEMP_GITLAB)/docker/* $(DOCKERX_CONTEXT)/
	sed -i -e 's/COPY RELEASE \//ARG TARGETARCH\nCOPY RELEASE-\$$\{TARGETARCH\} \/RELEASE/g' $(DOCKERX_CONTEXT)/Dockerfile
	sed -i -e 's/tzdata/tzdata libatomic1/g' $(DOCKERX_CONTEXT)/Dockerfile
