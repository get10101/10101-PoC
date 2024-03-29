# 10101 Demo

We decided to publish a separate demo post so [the pitch](https://makers.bolt.fun/story/10101-pitch--441) can stay concise and focus on being a pitch 😉
This demo post showcases what we have built and how we got there.

## We did it! - The demo

`10101` is a mobile Lightning wallet, that offers non-custodial trading services.
The app-demo showcases how we integrate multiple services, with CFD trading being the first service that we fully implement.\
We did a public demo where we showcase the app, [here's the recording](https://rumble.com/v1wr04i-10101-demo.html).
Below are the most important steps showcased one more time.

As with every self-sovereign Lightning wallet upon startup the wallet will prompt the user to make sure to create a backup of their seed phrase:

![](../assets/2022-11-24-01_seed_backup.gif)

In order to start using the wallet the user must be in possession of Bitcoin.\
The users needs to deposit Bitcoin into the wallet and open an initial channel to be part of the network.\
We step the user through this process one action at the time.

First the user is prompted to deposit Bitcoin:

![](../assets/2022-11-24-02_deposit_bitcoin.gif)

The user sends funds to the wallet's Bitcoin address.
The on-chain balances changes once the funds a picked up on chain.

Once the wallet picked up the transaction the user is prompted to open a channel with `10101` :

![](../assets/2022-11-24-03_open_channel.gif)

The user's Lightning node, running on the mobile phone, opens a channel with our `10101` Lightning node.\
We doubles the amount the user puts in, so that both sides are funded in preparation for using non-custodial trading protocols.\
In the future we see a P2P marketplace here, where `10101` acts as an enabler to connect users to trade P2P.

Once a channel was established the user can open a CFD position over the channel with the `10101` node:

![](../assets/2022-11-24-04_open_cfd.gif)

The user sees the opened CFD and can navigate to a detail view.

The user can settle the position into the channel distributing the fund according to the profit/loss of the CFD position:

![](../assets/2022-11-24-05_close_cfd.gif)

## How did we get there? - A bit of history

A bit more than a year ago we started working on [ItchySats](https://www.itchysats.network/), a non-custodial CFD trading solution built using DLCs for the self-sovereign Bitcoiner.
ItchySats is available on Umberl, raspiblitz, Citadel, MyNode and Start9 - but we never had the feeling that we were driving adoption enough.

Feedback we got was "this has to be more accessible" and "this is too expensive" - partly due to the on-chain fees because ItchySats was unable to re-use channels for trading.
We agreed that these were problems that had to be solved, and we knew that we can solve them.
So, we decided to take the Ledgends of Lightning Tournament as an opportunity to go wild and _just do it_.

When we started 6 weeks ago we had a plan:

1. Make the ItchySats protocol work over the Lightning Network
2. Build a mobile wallet that shows a vision beyond just CFD trading

For the Lightning part we set ourselves the constraints that we want to stay self-sovereign - we want the lightning node to run on the phone.
For the app we set ourselves the goal, that it should be _as least as good_ as the wallets currently out there and on as many platforms as possible.

The only pre-work we did before the tournament started was:

- A very rough protocol design for the ItchySats CFD protocol over a Lightning channel
- Decision to use [LDK](https://github.com/lightningdevkit/)'s [rust-lightning](https://github.com/lightningdevkit/rust-lightning) - we know rust, anything else would potentially slow us down
- Decision to use [Flutter](https://flutter.dev/) as mobile stack - a simple POC using [flutter-rust-bridge](https://github.com/fzyzcjy/flutter_rust_bridge) proved that we could use rust code in Flutter, which looked like the framework that gets the fastest cross-platform results

We knew that the scope we set for ourselves was not little for six weeks. We decided to split the team in half:

- One half of the team working on extending the LDK / rust-lightning code to make the protocol work over lightning.
- The other half of the team working on designing and implementing a Lightning wallet using Flutter.

We reserved the last two weeks of the tournament to bring the two sides together, i.e. integrate the CFD trading protocol into the app.

What can I say: It worked.

## What's next? - Soon to be MVP

This is the demo of a POC. We did take some shortcuts - here's a glimpse on our roadmap from POC to MVP:

1. The demo only implements a collaborative close of CFDs into the channel
   1. We did extend rust-lightning to be capable to force-close a position, but the app does not depict it yet.
   2. This can be easily added by storing the CETs and allowing the user to close the channel and spend from the multisig on chain distributing the money according to the price attested by the oracle (as in ItchySats).
2. Going back on-chain (i.e.closing the channel collaboratively) is not depicted in the app yet.
   1. This will be solved by exposing closing the channel (collaboratively) in the app settings.

These shortcuts are not blockers, we will add the missing features in the upcoming weeks to complete the MVP.
Then it's time to bring it to the people and scale. 🚀🌕
