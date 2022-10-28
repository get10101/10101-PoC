deps: deps-gen deps-android deps-ios

deps-gen:
	cargo install flutter_rust_bridge_codegen

# Install dependencies for Android (build targets and cargo-ndk)
deps-android:
	cargo install cargo-ndk
	rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# Install dependencies for iOS
deps-ios:
	cargo install cargo-lipo
	rustup target add aarch64-apple-ios x86_64-apple-ios

# Format all files in the project
format: dprint flutter-format

dprint:
	dprint fmt

# Flutter lacks a dprint plugin, use its own formatter
flutter-format:
	flutter format . --fix --line-length 100

# Clean all build artifacts
clean:
	flutter clean
	cd rust && cargo clean

# Build Rust library for native target
native:rust
	cd rust && cargo build

# Build Rust library for Android native targets
android-native:rust
	cd rust && cargo ndk -o ../android/app/src/main/jniLibs build

# NOTE Android simulator needs target to be x86_64.
android-sim:rust
	cd rust && cargo ndk -t x86_64 -o ../android/app/src/main/jniLibs build

# By default, Android is an alias for the simulator target
android: android-native

# Build Rust library for iOS
ios:rust
	cd rust && cargo lipo
	cp rust/target/universal/debug/libten_ten_one.a ios/Runner

# Ensure flutter is up-to-date & generate bindings
gen:rust
	flutter pub get
	flutter_rust_bridge_codegen \
		--rust-input rust/src/api.rs \
		--dart-output lib/bridge_generated.dart \
		--dart-format-line-length 100 \
		--c-output ios/Runner/bridge_generated.h \
		--c-output macos/Runner/bridge_generated.h \
		--dart-decl-output lib/bridge_definitions.dart \
		--wasm

# Run the app (need to pick the target, if no mobile emulator is running)
run:
	flutter run

clippy:rust
	cd rust && cargo clippy --all-targets -- -D warnings

lint-flutter:
	flutter analyze --fatal-infos .

lint: clippy lint-flutter
