SWIFT_BUILD_FLAGS=--configuration release

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
	docker pull kittymac/flynn:latest
	docker run --platform linux/arm64 --rm -v /tmp/:/outTemp kittymac/flynn /bin/bash -lc 'cp /root/Flynn/.build/aarch64-unknown-linux-gnu/release/FlynnPluginTool /outTemp/FlynnPluginTool'
	cp /tmp/FlynnPluginTool ./dist/FlynnPluginTool.artifactbundle/FlynnPluginTool-arm64/bin/FlynnPluginTool
	docker run --platform linux/amd64 --rm -v /tmp/:/outTemp kittymac/flynn /bin/bash -lc 'cp /root/Flynn/.build/x86_64-unknown-linux-gnu/release/FlynnPluginTool /outTemp/FlynnPluginTool'
	cp /tmp/FlynnPluginTool ./dist/FlynnPluginTool.artifactbundle/FlynnPluginTool-amd64/bin/FlynnPluginTool
	
	cp ./dist/FlynnPluginTool ./dist/FlynnPluginTool.artifactbundle/FlynnPluginTool-macos/bin/FlynnPluginTool
	rm -f ./dist/FlynnPluginTool.zip
	cd ./dist && zip -r ./FlynnPluginTool.zip ./FlynnPluginTool.artifactbundle

docker:
	-docker buildx create --name local_builder
	-DOCKER_HOST=tcp://192.168.1.198:2376 docker buildx create --name local_builder --platform linux/amd64 --append
	-docker buildx use local_builder
	-docker buildx inspect --bootstrap
	-docker login
	docker buildx build --platform linux/amd64,linux/arm64 --push -t kittymac/flynn .

docker-shell:
	docker pull kittymac/flynn
	docker run --platform linux/arm64 --rm -it --entrypoint bash kittymac/flynn
