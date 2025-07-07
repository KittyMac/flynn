define DOCKER_BUILD_TOOL
	docker buildx build --file Dockerfile-$(1) --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-$(1) .
	
	# Getting plugin for $(1)
	docker pull kittymac/flynn-$(1):latest
	mkdir -p ./dist/FlynnPluginTool-$(1).artifactbundle/FlynnPluginTool-arm64/bin/
	mkdir -p ./dist/FlynnPluginTool-$(1).artifactbundle/FlynnPluginTool-amd64/bin/
	mkdir -p ./dist/FlynnPluginTool-$(1).artifactbundle/FlynnPluginTool-macos/bin/
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-$(1) /bin/bash -lc 'cp FlynnPluginTool /outTemp/FlynnPluginTool-$(1).artifactbundle/FlynnPluginTool-arm64/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-$(1) /bin/bash -lc 'cp FlynnPluginTool /outTemp/FlynnPluginTool-$(1).artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool'
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool-$(1).artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	
	rm -f ./dist/FlynnPluginTool-$(1).zip
	cd ./dist && zip -r ./FlynnPluginTool-$(1).zip ./FlynnPluginTool-$(1).artifactbundle
endef

DIST:=$(shell cd dist && pwd)
SWIFT_BUILD_FLAGS=--configuration release

build-library:
	swift build -Xswiftc -enable-library-evolution -v $(SWIFT_BUILD_FLAGS)

build:
	swift build --triple arm64-apple-macosx $(SWIFT_BUILD_FLAGS)
	swift build --triple x86_64-apple-macosx $(SWIFT_BUILD_FLAGS)
	-rm .build/FlynnPluginTool
	lipo -create -output .build/FlynnPluginTool .build/arm64-apple-macosx/release/FlynnPluginTool .build/x86_64-apple-macosx/release/FlynnPluginTool
	cp .build/FlynnPluginTool ./dist/FlynnPluginTool

build-windows:
	# note: you probably don't have make on windows, so you need to run these manually
	Stop-Process -Name "FlynnPackageTests.xctest"
	rm -Recurse -Force .build
	swift test
	swift build --configuration release
	cp .build/release/FlynnPluginTool.exe ./dist/FlynnPluginTool-windows-592.artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool.exe
	rm ./dist/FlynnPluginTool-windows-592.zip
	Compress-Archive -Path ./dist/FlynnPluginTool-windows-592.artifactbundle -DestinationPath ./dist/FlynnPluginTool-windows-592.zip

clean:
	rm -rf .build

.PHONY: clean-repo
clean-repo:
	rm -rf /tmp/clean-repo/
	mkdir -p /tmp/clean-repo/
	cd /tmp/clean-repo/ && git clone https://github.com/KittyMac/flynn.git/
	cd /tmp/clean-repo/flynn && cp -r dist ../dist.tmp && cp .git/config ../config
	cd /tmp/clean-repo/flynn && git filter-repo --invert-paths --path dist
	cd /tmp/clean-repo/flynn && mv ../dist.tmp dist && mv ../config .git/config
	cd /tmp/clean-repo/flynn && git add dist
	cd /tmp/clean-repo/flynn && git commit -a -m "clean-repo"
	open /tmp/clean-repo/flynn
	# clean complete; manual push required
	# git push origin --force --all
	# git push origin --force --tags

test:
	swift test -v

update:
	swift package update

profile: clean
	mkdir -p /tmp/flynn.stats
	swift build \
		--configuration release \
		-Xswiftc -stats-output-dir \
		-Xswiftc /tmp/flynn.stats \
		-Xswiftc -trace-stats-events \
		-Xswiftc -driver-time-compilation \
		-Xswiftc -debug-time-function-bodies

release: build docker focal-571 fedora38-573 focal-580 focal-592 jammy-592

focal-571:
	@$(call DOCKER_BUILD_TOOL,focal-571)

focal-580:
	@$(call DOCKER_BUILD_TOOL,focal-580)
	
focal-592:
	@$(call DOCKER_BUILD_TOOL,focal-592)
	
jammy-592:
	@$(call DOCKER_BUILD_TOOL,jammy-592)

fedora38-573:
	@$(call DOCKER_BUILD_TOOL,fedora38-573)
	

docker:
	-DOCKER_HOST=ssh://rjbowli@192.168.111.203 docker buildx create --name cluster_builder203 --platform linux/amd64
	-docker buildx create --name cluster_builder203 --platform linux/arm64 --append
	-docker buildx use cluster_builder203
	-docker buildx inspect --bootstrap
	-docker login
	
	

docker-shell:
	docker buildx build --file Dockerfile-fedora --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-jammy-592 .
	docker pull kittymac/flynn-jammy-592
	docker run --rm -it --entrypoint bash kittymac/flynn-jammy-592
