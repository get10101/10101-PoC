use anyhow::Result;
use futures::TryStreamExt;
use rust_decimal::Decimal;
use time::OffsetDateTime;
use tokio::sync::watch;
use tokio::task::JoinHandle;

pub const QUOTE_INTERVAL_MINUTES: i64 = 1;

pub fn subscribe() -> Result<(JoinHandle<()>, watch::Receiver<Option<Quote>>)> {
    let (quote_sender, quote_receiver) = watch::channel(None);

    let handle = tokio::spawn(async move {
        let mut stream = bitmex_stream::subscribe(
            ["instrument:XBTUSD".to_string()],
            bitmex_stream::Network::Testnet,
        );

        // We keep track of the latest quote because not every quote
        // update references every field. TODO: Manage each field as a
        // separate resource
        let mut latest_quote = Quote::new();

        while let Some(wire_update) = stream.try_next().await.expect("message from bitmex") {
            tracing::trace!(%wire_update, "Received message from bitmex");
            if latest_quote.update(&wire_update) {
                let _ = quote_sender.send(Some(latest_quote));
            }
        }
    });
    Ok((handle, quote_receiver))
}

#[derive(Clone, Copy)]
pub struct Quote {
    pub timestamp: OffsetDateTime,
    pub bid: Decimal,
    pub ask: Decimal,
    pub index: Decimal,
    pub symbol: ContractSymbol,
}

#[derive(
    Debug, Clone, Copy, strum_macros::EnumString, strum_macros::Display, PartialEq, Eq, Hash,
)]
pub enum ContractSymbol {
    #[strum(serialize = "XBTUSD")]
    BtcUsd,
}

impl Quote {
    fn new() -> Self {
        Self {
            timestamp: OffsetDateTime::now_utc(),
            bid: Decimal::ZERO,
            ask: Decimal::ZERO,
            index: Decimal::ZERO,
            symbol: ContractSymbol::BtcUsd,
        }
    }

    fn update(&mut self, wire_update: &str) -> bool {
        let table_message = match serde_json::from_str::<wire::TableMessage>(wire_update) {
            Ok(table_message) => table_message,
            Err(e) => {
                tracing::trace!(%wire_update, %e, "Irrelevant fields in wire update, skipping...");
                return false;
            }
        };
        let [quote] = table_message.data;

        self.timestamp = quote.timestamp;

        if let Some(bid) = quote.bid_price {
            self.bid = bid.0;
        }

        if let Some(ask) = quote.ask_price {
            self.ask = ask.0;
        }

        if let Some(index) = quote.mark_price {
            self.index = index.0;
        }

        true
    }

    pub fn bid(&self) -> Decimal {
        self.bid
    }

    pub fn ask(&self) -> Decimal {
        self.ask
    }

    pub fn is_older_than(&self, duration: time::Duration) -> bool {
        let required_quote_timestamp = (OffsetDateTime::now_utc() - duration).unix_timestamp();

        self.timestamp.unix_timestamp() < required_quote_timestamp
    }
}

impl Default for Quote {
    fn default() -> Self {
        Self::new()
    }
}

mod wire {
    use super::*;
    use serde::Deserialize;

    #[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
    pub struct TableMessage {
        pub table: String,
        // we always just expect a single quote, hence the use of an array instead of a vec
        pub data: [QuoteData; 1],
    }

    #[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
    #[serde(rename_all = "camelCase")]
    pub struct QuoteData {
        pub bid_price: Option<DecimalWrapper>,
        pub ask_price: Option<DecimalWrapper>,
        pub mark_price: Option<DecimalWrapper>,
        pub symbol: String,
        #[serde(with = "time::serde::rfc3339")]
        pub timestamp: OffsetDateTime,
    }

    /// Wrapper struct for decimal to allow us to wrap it in an option one layer up.
    #[derive(Debug, Clone, Copy, Deserialize, PartialEq, Eq)]
    #[serde(transparent)]
    pub struct DecimalWrapper(#[serde(with = "rust_decimal::serde::float")] pub Decimal);
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;
    use time::ext::NumericalDuration;

    #[test]
    fn can_update_quote() {
        let mut quote = Quote::new();

        let was_updated = quote.update(r#"{"table":"quoteBin1m","action":"insert","data":[{"timestamp":"2021-09-21T02:40:00.000Z","symbol":"XBTUSD","bidSize":50200,"bidPrice":42640.5,"askPrice":42641,"askSize":363600}]}"#);

        assert!(was_updated);

        assert_eq!(quote.bid, dec!(42640.5));
        assert_eq!(quote.ask, dec!(42641));
        assert_eq!(quote.timestamp.unix_timestamp(), 1632192000);
        assert_eq!(quote.symbol, ContractSymbol::BtcUsd)
    }

    #[test]
    fn quote_from_now_is_not_old() {
        let quote = dummy_quote_at(OffsetDateTime::now_utc());

        let is_older = quote.is_older_than(1.minutes());

        assert!(!is_older)
    }

    #[test]
    fn quote_from_one_hour_ago_is_old() {
        let quote = dummy_quote_at(OffsetDateTime::now_utc() - 1.hours());

        let is_older = quote.is_older_than(1.minutes());

        assert!(is_older)
    }

    fn dummy_quote_at(timestamp: OffsetDateTime) -> Quote {
        Quote {
            timestamp,
            bid: dec!(10),
            ask: dec!(10),
            symbol: ContractSymbol::BtcUsd,
            index: dec!(10),
        }
    }
}
