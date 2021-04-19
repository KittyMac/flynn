#sudo docker service create --name clusterArchive \
#    --with-registry-auth \
#    --mode global kittymac/clusterarchiver

SWIFT_BUILD_FLAGS=--configuration release

.PHONY: all build clean xcode

all: build

build:
	swift build $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

update:
	swift package update

run:
	swift run $(SWIFT_BUILD_FLAGS)

support: build
	./.build/release/ClusterArchiver support 192.168.1.69
	
test:
	swift test --configuration debug

xcode:
	swift package generate-xcodeproj
	meta/addBuildPhase ClusterArchiver.xcodeproj/project.pbxproj 'ClusterArchiver::ClusterArchiverFramework' 'cd $${SRCROOT}; ./meta/CombinedBuildPhases.sh'

docker:
	-DOCKER_HOST=tcp://192.168.1.209:2376 docker buildx create --name cluster
	-DOCKER_HOST=tcp://192.168.1.170:2376 docker buildx create --name cluster --append
	-docker buildx use cluster
	-docker buildx inspect --bootstrap
	docker buildx build --platform linux/arm/v7,linux/arm64/v8 --push -t kittymac/clusterarchiver .
	#docker buildx build --platform linux/arm/v7 --push -t kittymac/clusterarchiver .

docker-swift:
	swift package update
	swift build -v $(SWIFT_BUILD_FLAGS)

docker-shell-armv7:
	docker run --platform linux/arm/v7 -it kittymac/clusterarchiver:latest sh

docker-shell-arm64:
	docker run --platform linux/arm64/v8 -it kittymac/clusterarchiver:latest sh

docker-update:
	ssh ubuntu@192.168.1.150 "/home/ubuntu/update_service.sh kittymac/clusterarchiver"