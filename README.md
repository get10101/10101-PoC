# 10101 (a.k.a TenTenOne) - PoC


> :warning: _The code within this repository was created during the [Legends of Lightning Tournament](https://makers.bolt.fun/project/10101). It is now archived and replaced by https://github.com/get10101/10101_



## Dependencies

This project requires [Flutter](https://flutter.dev) and [Rust](https://www.rust-lang.org).
Rust toolchain can be installed via [Rustup](https://rustup.rs/).
In order to setup Flutter (as well as mobile simulators etc), please see the excellent Flutter guide [here](https://docs.flutter.dev/get-started/install)

A lot of complexity for building the app has been encapsulated in a [Makefile](./Makefile).
To see the available commands, simply run `make help` or `make`.

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

## Formatting

We strive to keep the code consistent, therefore before submitting PRs one should run: `make format` to ensure code is properly formatted.

## Linting

Static analysers (`clippy` and `flutter analyze`) can be run by calling `make lint`.

## Running

After compiling the relevant Rust backend in the previous section, invoke Flutter:

```sh
flutter run
```

note: Flutter might ask you which target you'd like to run.

Running 10101 for `web` target is currently unsupported.

### `regtest`

To run on `regtest` you have to change the default network (`testnet`) to `regtest` by setting the `NETWORK` environment variable.

Example command for maker:

`make maker`

(`make` runs prepend NETWORK=regtest automatically)

Example command for taker:

`NETWORK=regtest flutter run`

Note that the `iOS` simulator will _not_ pick up the environment variable, so make sure you run on a `native` target when testing with regtest!

#### Running a `regtest` setup

For regtest you need to run a local electrs server on `localhost:50000`.
We make use of [nigiri](https://github.com/vulpemventures/nigiri) for this.

Run

```bash
nigiri start
```

To get some money run

```bash
nigiri faucet <address>
```

To generate a block, simply call the faucet again.

### Run maker in docker

```bash
DATA_DIR=$(pwd)
docker run -v$DATA_DIR:/data -p8000 -p9045 ghcr.io/bonomat/10101:main
```
