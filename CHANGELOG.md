# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2022-12-07

### Fixed

- Action button that enables simple navigation to the wallet dashboard from all screens that show the balance.
- Don't auto open the keyboard in the CFD trading screen.
- Default invoice description keyboard to text.
- Persist feed backup state over restarts.

### Added

- Settings screen that shows some useful app information but does not allow changes yet.
- Show connection status to `10101` in the app.

### Changed

- Form validation for the open channel screen providing the user with more information.
- Detect expired lightning payments and show them.
- Show the `confirmed` balance as `on-chain` balance instead of the `total` balance to avoid confusion when opening a channel.

## [0.3.1] - 2022-12-02

### Fixed

- Update on-chain balance immediately after channel closure.
- Set log level to debug so the attached logs on the feedback emails are more helpful.

## [0.3.0] - 2022-12-02

### Fixes

- Heaps of bugfixes and UX improvements

## [0.2.1] - 2022-11-25

### Added

- The taker can collaboratively close the channel with the 10101 maker.

### Fixed

- Opening CFDs works again.
  We had introduced a regression with patch 38c09b25c8903e2aeb6831c637493f88e5731ff1 which prevented the taker from noticing that the channel was ready.
- Stopped hanging on the splash screen if the 10101 maker is unreachable.

### Changed

- Improve UI error message after opening a channel fails.

## [0.2.0] - 2022-11-24

### Added

- A mobile Lightning node that can be used to send and receive payments.
  The backend code is based on our fork of [`ldk-bdk-sample`](https://github.com/klochowicz/ldk-bdk-sample).
- Support for CFD trading on Lightning.
  This is made possible by depending on our [our `rust-lightning` fork](https://github.com/itchysats/rust-lightning/tree/dlcs).
- A combined view of all incoming and outgoing payments and transactions to the dashboard.
- The ability to send and receive on-chain transactions.
- A history for on-chain transactions and off-chain payments.
- Added CFD trading screens: offer screen; order confirmation screen; `My CFDs` screen; and a CFD details screen that allows settlement.
- Support for CFD trading against the `10101` node on Bitcoin `testnet`.
- Placeholder cards and screens for additional services that showcase our vision to add sports betting, a Taro exchange and savings products.

### Changed

- Overhauled the app's look and feel. We are using blue as the main color and have aligned the theme throughout the application elements.

## [0.1.0] - 2022-11-09

### Added

- Initial flutter and flutter rust bridge project setup
- BIP84 wallet derived from a BIP39 seed phrase
- Dashboard view
- Backup seed view
- Mocked CFD trading view

[Unreleased]: https://github.com/itchysats/10101/compare/0.3.2...HEAD
[0.3.2]: https://github.com/itchysats/10101/compare/0.3.1...0.3.2
[0.3.1]: https://github.com/itchysats/10101/compare/0.3.0...0.3.1
[0.3.0]: https://github.com/itchysats/10101/compare/0.2.1...0.3.0
[0.2.1]: https://github.com/itchysats/10101/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/itchysats/10101/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/itchysats/10101/compare/fe2edaf79caea892b10d61b4f23a4e76fec808d2...0.1.0
