SWIFT_BUILD_FLAGS=--configuration release

all: build

build:
	swift build $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

xcode:
	swift package generate-xcodeproj