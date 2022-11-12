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

clean:
	rm -rf .build

test:
	swift test -v

update:
	swift package update

release: build docker
	# Getting plugin for focal
	docker pull kittymac/flynn-focal:latest
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-focal /bin/bash -lc 'cp /root/Flynn/.build/aarch64-unknown-linux-gnu/release/FlynnPluginTool /outTemp/FlynnPluginTool.artifactbundle/FlynnPluginTool-arm64-focal/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-focal /bin/bash -lc 'cp /root/Flynn/.build/x86_64-unknown-linux-gnu/release/FlynnPluginTool /outTemp/FlynnPluginTool.artifactbundle/FlynnPluginTool-amd64-focal/bin/FlynnPluginTool'
	
	# Getting plugin for amazonlinux2
	docker pull kittymac/flynn-amazonlinux2:latest
	docker run --platform linux/arm64 --rm -v $(DIST):/outTemp kittymac/flynn-amazonlinux2 /bin/bash -lc 'cp /root/Flynn/.build/aarch64-unknown-linux-gnu/release/FlynnPluginTool /outTemp/FlynnPluginTool.artifactbundle/FlynnPluginTool-arm64-amazonlinux2/bin/FlynnPluginTool'
	docker run --platform linux/amd64 --rm -v $(DIST):/outTemp kittymac/flynn-amazonlinux2 /bin/bash -lc 'cp /root/Flynn/.build/x86_64-unknown-linux-gnu/release/FlynnPluginTool /outTemp/FlynnPluginTool.artifactbundle/FlynnPluginTool-amd64-amazonlinux2/bin/FlynnPluginTool'
	
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool.artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	rm -f ./dist/FlynnPluginTool.zip
	cd ./dist && zip -r ./FlynnPluginTool.zip ./FlynnPluginTool.artifactbundle

docker:
	-docker buildx create --name local_builder
	-DOCKER_HOST=tcp://192.168.1.198:2376 docker buildx create --name local_builder --platform linux/amd64 --append
	-docker buildx use local_builder
	-docker buildx inspect --bootstrap
	-docker login
	docker buildx build --file Dockerfile-focal --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-focal .
	docker buildx build --file Dockerfile-amazonlinux2 --platform linux/amd64,linux/arm64 --push -t kittymac/flynn-amazonlinux2 .

docker-shell:
	docker pull kittymac/flynn
	docker run --platform linux/arm64 --rm -it --entrypoint bash kittymac/flynn
