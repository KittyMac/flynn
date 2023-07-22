DIST:=$(shell cd dist && pwd)
SWIFT_BUILD_FLAGS=--configuration release

build-library:
	swift build -Xswiftc -enable-library-evolution -v $(SWIFT_BUILD_FLAGS)

build:
	swift build --triple arm64-apple-macosx $(SWIFT_BUILD_FLAGS)
	swift build --triple x86_64-apple-macosx $(SWIFT_BUILD_FLAGS)
	-rm .build/FlynnPluginTool
	lipo -create -output .build/FlynnPluginTool-focal .build/arm64-apple-macosx/release/FlynnPluginTool-focal .build/x86_64-apple-macosx/release/FlynnPluginTool-focal
	cp .build/FlynnPluginTool-focal ./dist/FlynnPluginTool

clean:
	rm -rf .build

.PHONY: clean-repo
clean-repo:
	rm -rf /tmp/clean-repo/
	mkdir -p /tmp/clean-repo/
	cd /tmp/clean-repo/ && git clone https://github.com/KittyMac/flynn.git/
	cd /tmp/clean-repo/flynn && cp -r dist ../dist.tmp
	cd /tmp/clean-repo/flynn && git filter-repo --invert-paths --path dist
	cd /tmp/clean-repo/flynn && mv ../dist.tmp dist
	cd /tmp/clean-repo/flynn && git commit -a -m "clean-repo"
	open /tmp/clean-repo/flynn
	echo "clean complete; manual push required"

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

release: build docker
	
	# Getting plugin for focal
	docker pull kittymac/flynn-focal:latest
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-focal /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-focal.artifactbundle/FlynnPluginTool-arm64/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-focal /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-focal.artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool'
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool-focal.artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	
	rm -f ./dist/FlynnPluginTool-focal.zip
	cd ./dist && zip -r ./FlynnPluginTool-focal.zip ./FlynnPluginTool-focal.artifactbundle
	
	# Getting plugin for amazonlinux2
	docker pull kittymac/flynn-amazonlinux2:latest
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-amazonlinux2 /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-amazonlinux2.artifactbundle/FlynnPluginTool-arm64/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-amazonlinux2 /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-amazonlinux2.artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool'
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool-amazonlinux2.artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	
	rm -f ./dist/FlynnPluginTool-amazonlinux2.zip
	cd ./dist && zip -r ./FlynnPluginTool-amazonlinux2.zip ./FlynnPluginTool-amazonlinux2.artifactbundle
	
	# Getting plugin for fedora
	docker pull kittymac/flynn-fedora:latest
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-fedora /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-fedora.artifactbundle/FlynnPluginTool-arm64/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-fedora /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-fedora.artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool'
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool-fedora.artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	
	rm -f ./dist/FlynnPluginTool-fedora.zip
	cd ./dist && zip -r ./FlynnPluginTool-fedora.zip ./FlynnPluginTool-fedora.artifactbundle
	
	# Getting plugin for fedora38
	docker pull kittymac/flynn-fedora38:latest
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-fedora38 /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-fedora38.artifactbundle/FlynnPluginTool-arm64/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-fedora38 /bin/bash -lc 'cp FlynnPluginTool-focal /outTemp/FlynnPluginTool-fedora38.artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool'
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool-fedora38.artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	
	rm -f ./dist/FlynnPluginTool-fedora38.zip
	cd ./dist && zip -r ./FlynnPluginTool-fedora38.zip ./FlynnPluginTool-fedora38.artifactbundle
	
	

docker:
	-docker buildx create --name cluster_builder203
	-DOCKER_HOST=ssh://rjbowli@192.168.111.203 docker buildx create --name cluster_builder203 --platform linux/amd64 --append
	-docker buildx use cluster_builder203
	-docker buildx inspect --bootstrap
	-docker login
	docker buildx build --file Dockerfile-focal --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-focal .
	docker buildx build --file Dockerfile-amazonlinux2 --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-amazonlinux2 .
	docker buildx build --file Dockerfile-fedora --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-fedora .
	docker buildx build --file Dockerfile-fedora38 --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-fedora38 .

docker-shell:
	docker buildx build --file Dockerfile-fedora --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-fedora .
	docker pull kittymac/flynn-fedora
	docker run --rm -it --entrypoint bash kittymac/flynn-fedora
