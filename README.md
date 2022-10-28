# 10101 (a.k.a TenTenOne)

## Dependencies

This project requires [Flutter](https://flutter.dev) and [Rust](https://www.rust-lang.org).
Rust toolchain can be installed via [Rustup](https://rustup.rs/).
In order to setup Flutter (as well as mobile simulators etc), please see the excellent Flutter guide [here](https://docs.flutter.dev/get-started/install)

A lot of complexity for building the app has been encapsulated in a [Makefile](./Makefile).

To install necessary project dependencies for all targets, run the following:

```sh
make deps
```

## Documentation

This project uses [flutter-rust-bridge](https://github.com/fzyzcjy/flutter_rust_bridge).
It is strongly encouraged to read its [documentation](https://cjycode.com/flutter_rust_bridge/index.html) before jumping into the project in order to understand the project's structure, conventions and ways of integrating between Rust and Flutter.

## Building

The instructions below allow building the Rust backend for 10101 application.

### Bindings to Flutter

Bindings for Flutter can be generated with the following command:

```sh
make gen
```

### Native (desktop)

```sh
make native
```

### iOS

```sh
make ios
```

### Android

#### Native

For building for target devices, run:

```sh
make android
```

#### Simulator

```sh
make android-sim
```

## Running

After compiling the relevant Rust backend in the previous section, invoke Flutter:

```sh
flutter run
```

note: Flutter might ask you which target you'd like to run.

Running 10101 for `web` target is currently unsupported.
