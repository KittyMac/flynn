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
	
test:
	swift test --configuration debug

xcode:
	swift package generate-xcodeproj
	meta/addBuildPhase ClusterArchiver.xcodeproj/project.pbxproj 'ClusterArchiver::ClusterArchiverFramework' 'cd $${SRCROOT}; ./meta/CombinedBuildPhases.sh'

root: build
	./.build/release/server root

node: build
	./.build/release/server node

rocco: build
	./.build/release/server node 192.168.1.72

