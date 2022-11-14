.DEFAULT_GOAL := help
PROJECTNAME=$(shell basename "$(PWD)")

# Menu (visible if you type `make` or `make help`)
.PHONY: help
help: Makefile
	@echo
	@echo " Available actions in "$(PROJECTNAME)":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo

## lint: Lint all the code (both Rust and Flutter)
lint: clippy lint-flutter

## all: Re-generate bindings, compile Rust lib, and run the Flutter project
all: FORCE gen native run

## deps: Install missing dependencies.
deps: deps-gen deps-android deps-ios

deps-gen:
	cargo install flutter_rust_bridge_codegen

# deps-android: Install dependencies for Android (build targets and cargo-ndk)
deps-android:
	cargo install cargo-ndk
	rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# deps-ios: Install dependencies for iOS
deps-ios:
	cargo install cargo-lipo
	rustup target add aarch64-apple-ios x86_64-apple-ios

## format: Format all files in the project
format: dprint flutter-format

fmt: format

dprint:
	dprint fmt

# Flutter lacks a dprint plugin, use its own formatter
flutter-format:
	flutter format . --fix --line-length 100

## clean: Clean all build artifacts
clean:
	flutter clean
	cargo clean
	# mobile targets don't build whole workspace, but just ten_ten_one crate 
	cd rust && cargo clean

## native: Build Rust library for native target (to run on your desktop)
native: FORCE
	cargo build

# Build Rust library for Android native targets
android-native: FORCE
	cd rust && cargo ndk -o ../android/app/src/main/jniLibs build

# NOTE Android simulator needs target to be x86_64.
android-sim: FORCE
	cd rust && cargo ndk -t x86_64 -o ../android/app/src/main/jniLibs build

## android: Build Rust library for Android
# By default, Android is an alias for the simulator target
android: android-native

## ios: Build Rust library for iOS
ios: FORCE
	cd rust && cargo lipo
	cp target/universal/debug/libten_ten_one.a ios/Runner

## gen: Run codegen (needs to run before `flutter run`)
gen: FORCE
	flutter pub get
	flutter_rust_bridge_codegen \
		--rust-input rust/src/api.rs \
		--rust-output rust/src/bridge_generated/bridge_generated.rs \
		--dart-output lib/bridge_generated/bridge_generated.dart \
		--dart-format-line-length 100 \
		--c-output ios/Runner/bridge_generated.h \
		--c-output macos/Runner/bridge_generated.h \
		--dart-decl-output lib/bridge_generated/bridge_definitions.dart \
		--wasm

## run: Run the app (need to pick the target, if no mobile emulator is running)
run:
	flutter run

clippy: FORCE
	cargo clippy --all-targets -- -D warnings

lint-flutter:
	flutter analyze --fatal-infos .

## test: Run tests
test: FORCE
	cargo test

FORCE: ;
