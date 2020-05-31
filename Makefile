SWIFT_BUILD_FLAGS=--configuration release

all: build

build:
	swift build $(SWIFT_BUILD_FLAGS)
