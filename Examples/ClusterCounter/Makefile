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
	meta/addBuildPhase ClusterCounter.xcodeproj/project.pbxproj 'ClusterCounter::ClusterCounterFramework' 'cd $${SRCROOT}; ./meta/CombinedBuildPhases.sh'

master: build
	./.build/release/server master

slave: build
	./.build/release/server slave

rocco: build
	./.build/release/server slave 192.168.1.72

