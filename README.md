# 10101 (a.k.a TenTenOne)

## Dependencies

This project requires `flutter` and `Rust`.
A lot of complexity for building the app has been encapsulated in a [Makefile](./Makefile).

To install necessary project dependencies for all targets, run the following:

```sh
make deps
```

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

Running 10101 for `web` target in currently unsupported.
