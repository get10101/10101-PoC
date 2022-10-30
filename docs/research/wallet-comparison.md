## Existing Wallets

List of Lightning wallet to be analysed:

- Wallets to connect to your existing node
  - [BlueWallet](https://bluewallet.io/)
    - Needs LNDHub (hosted, or self-hosted)
  - [Zeus](https://zeusln.app/)
    - Can connect to LND or C-Lightning
  - [FullyNoded](https://fullynoded.app/)
    - Can connect to LND or C-Lightning
- Full nodes
  - [Breez](https://breez.technology/)
    - Uses a forked LND version
  - [Phoenix](https://github.com/ACINQ/phoenix)
    - Uses a custom lighting implementation

Below we have a look at these wallets and their feature set.
If a wallet is not mentioned below it has not been analysed (yet).

### Phoenix Wallet

In a nutshell: Non-custodial setup and a great UX that comes with some (minimal) trust for certain features.

Setup:

- Non-custodial setup
  - Run own LND node on Phone ([Eclair](https://github.com/ACINQ/eclair), ACINQ in-house lightning implementation)
  - Channel management through ACINQ nodes
  - Can configure own Electrum Server
  - Cannot configure own Lightning node (outside the phone setup)
- Where is trust involved?
  - Initial channel opening
  - Onboarding with BTC

Pro:

- Good looking and efficient UI and UX
- One of the best onboarding UX out there
  - One-click wallet setup
  - Onboarding using BTC
- BIP39 (+BIP84) 12-word wallet backup

Pro/Con:

- Channels management by ACINQ
  - Slightly higher costs for more convenience
- Channel backup managed by ACINQ
  - "Minimal" trust for more convenience

Con:

- Hard to understand the underlying constraints for the Lightning setup
- Costs for transactions are not transparent (retrospectively)
  - Example
    - Initially funded the wallet via BTC, had BTC worth `50.3` USD incoming.
    - Once they were actually confirmed it changed to `49.95` USD because the fees were deducted.
    - These fees are never visible again, when going to the details I cannot see how much fee was actually deducted and what for.
    - A better cost breakdown would be nice to have.

For details check these links:

- https://medium.com/@ACINQ/introducing-phoenix-5c5cc76c7f9e
- https://phoenix.acinq.co/faq

### Blue Wallet

In a nutshell: Semi- or Non-custodial (when using own LND) setup and a good UX that includes multiple wallet, but overall not as good as Phoenix.

Setup:

- Plug in own LND node, or use [LndHub](https://github.com/BlueWallet/LndHub)
  - LndHub is a semi-custodial setup ("minimum trust for endusers")
- Where is trust involved?
  - LndHub

Pro:

- Multiple wallet support
- Vaults (Not tried out, feels like a different feature unrelated to Lightning Wallet)
- LApp Marketplace
  - [Lapps standard](https://www.lapps.co/wallets) marketplace that is a great way to get an overview of what is out there to use your sats
  - Does not integrate as deep as Breez, e.g. for LN Markets one can see the app within the app, but one has to register/login separately and cannot just start trading.
  - Similar to Breez it is unclear what happens when clicking on one of the app icons in the marketplace.
- One-click wallet create for setup, but onboarding not as straight-forward as Phoenix
- Cross-platform: you can use BlueWallet on Desktop and Mobile.

Con:

- Cannot "empty the wallet", always have to keep at least some sats in for "paying fees"
  - This is super annoying, it is literally impossible to empty this wallet.
- Multi-wallet management
  - The wallets are completely independent; sending money from one to the other is quite cumbersome.
  - I would have expected that I can easily move funds from one wallet to another, but this is quite cumbersome.
  - Not sure what the use cases behind multiple wallets is; it does not feel like you average "bank account" app where you divide your money into different accounts for different purpose.
- Send / Receive are not as intuitive as for Phoenix
  - When using Phoenix it becomes clear how Lightning works, even when one is new to send/receive and creating/paying invoices.
  - The Blue wallet interface can be confusing, because it is not clear what one has to do to send/receive.
- When using LndHub the backup is an lndhub link or a QR code. There is not 12-word seed available that can just be copied.
  - How would I scan a QR code for backup with only one phone?
  - Unclear what the "backup link" represents.

For details check these links:

- https://bluewallet.io/features/

### Breez

In a nutshell: Non-custodial setup similar to Phoenix and a good UX; includes features that go beyond just a wallet.

I think Breez is currently the biggest competitor to what we have planned, because they already include "trading services".

Setup:

- Non-custodial setup similar to Phoenix but with more control options
  - Run own LND node on Phone (forked version of LND + Neutrion Bitcoin node)
    - Looks like they are the only one running both LND and Neutrino on the phone
  - Channel management through Async nodes
  - Can configure own Electrum Server
  - Cannot configure own Lightning node (outside the phone setup)
- Where is trust involved?
  - Channel management
  - Note: Backup is independent of Breez (different than Phoenix)

Pro:

- Fund wallet with BTC
- Fund wallet with Fiat: Buy BTC feature enabled through MoonPay integration
- Channel management
  - Default
  - Possibility to interact with Lightning node through basic interface for devs in Preferences
- [Lapps standard](https://www.lapps.co/wallets) marketplace integration, but integration somewhat different to Blue Wallet
  - e.g.: LN Markets: Can directly creates and account and one can just start trading, while on Blue Wallet I see a login page
  - App integrations are not native to the app, some work nice, some work less nice. The overall UX is not very good because it's mostly an integration of web-apps into breez.
  - It would help to know what happens when clicking on the app icon
    - This is more of an app-store experience similar to e.g. Umbrel; it might be better to have an overview of what an app is and what happens when opening (installing?) it.

Pro / Con:

- Back up google/apple account
  - Backup of the complete channel state + wallet (manually triggered backup)
  - Backup can be encrypted
  - Can specify private cloud in preferences instead of google/apple

Con:

- Look and feel not always consistent
  - It is not clear that there is a menu to the left
- Initial funding my fail because of "not enough inbound capacity"
  - This is likely related to sending small amounts and fee management (Failed for me with initial `10000` sats). The app should not allow that if it does not work.
- Similar to Phoenix the fees incurred are not transparent.
  - I see the balance changing and all the incoming/outgoing payments but I don't see any fees related to these payments.
  - The only fee related indicator is a disclaimer that tells me that fees will include when initially receiving a payment; but it is super hard to know what fee was actually charged.
- Unable to "empty" wallet / buggy send-payment experience!
  - This is pretty stupid, because when I try to send more than I can it tells me the maximum I can send - if it can know that, why not allow to specify it in the first place?
  - The amount displayed as "max amount that can be paid" was actually off by a tiny fraction.
  - Buggy when sending payments that are supposed to empty the wallet
    - Keeps saying "Processing Payment" and the balance flickers between the new and old balance.
    - Eventually the payment fails and the balance is reset
    - Example was: Balance of `0.00018`, wanted to send `0.00017996` (as displayed as max amount sendable), payment failed
      - Failed to send `0.0001799`
      - Eventually managed to send `0.000179` leaving a few cents in the wallet :/
      - Note: The problem is likely that they don't calculate the fee in properly.

For details check these links:

- https://doc.breez.technology/Introducing-Breez.html
