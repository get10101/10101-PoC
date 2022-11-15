use anyhow::Result;
use futures::TryStreamExt;
use rust_decimal::Decimal;
use std::str::FromStr;
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

        while let Some(text) = stream.try_next().await.expect("message from bitmex") {
            tracing::trace!(%text, "Received message from bitmex");
            let quote = Quote::from_str(&text).expect("quote from bitmex");
            if let Some(quote) = quote {
                tracing::debug!(
                    "Received quote update for {:?}, bid: {}, ask: {}, index: {}, timestamp: {}",
                    quote.symbol,
                    quote.bid,
                    quote.ask,
                    quote.index,
                    quote.timestamp
                );
                let _ = quote_sender.send(Some(quote));
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
    fn from_str(text: &str) -> Result<Option<Self>> {
        let table_message = match serde_json::from_str::<wire::TableMessage>(text) {
            Ok(table_message) => table_message,
            Err(e) => {
                tracing::trace!(%text, %e, "Not a 'table' message, skipping...");
                return Ok(None);
            }
        };

        let [quote] = table_message.data;

        let symbol = ContractSymbol::from_str(quote.symbol.as_str())?;
        Ok(Some(Self {
            timestamp: quote.timestamp,
            bid: quote.bid_price,
            ask: quote.ask_price,
            index: quote.mark_price,
            symbol,
        }))
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
        #[serde(with = "rust_decimal::serde::float")]
        pub bid_price: Decimal,
        #[serde(with = "rust_decimal::serde::float")]
        pub ask_price: Decimal,
        #[serde(with = "rust_decimal::serde::float")]
        pub mark_price: Decimal,
        pub symbol: String,
        #[serde(with = "time::serde::rfc3339")]
        pub timestamp: OffsetDateTime,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;
    use time::ext::NumericalDuration;

    #[test]
    fn can_deserialize_quote_message() {
        let quote = Quote::from_str(r#"{"table":"quoteBin1m","action":"insert","data":[{"timestamp":"2021-09-21T02:40:00.000Z","symbol":"XBTUSD","bidSize":50200,"bidPrice":42640.5,"askPrice":42641,"markPrice":42641,"askSize":363600}]}"#).unwrap().unwrap();

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
