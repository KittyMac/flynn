SWIFT_BUILD_FLAGS=--configuration release

all: fix_bad_header_files build
	
fix_bad_header_files:
	-@find  . -name '._*.h' -exec rm {} \;

build:
	swift build -v $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

test:
	swift test -v

xcode:
	swift package generate-xcodeproj
	meta/addBuildPhase Flynn.xcodeproj/project.pbxproj "Flynn::Flynn" 'cd $${SRCROOT}; ./meta/CombinedBuildPhases.sh'