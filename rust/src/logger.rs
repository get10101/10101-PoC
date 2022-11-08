use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use state::Storage;
use time::macros::format_description;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::fmt::time::UtcTime;
use tracing_subscriber::{EnvFilter, FmtSubscriber};

pub fn init_tracing(level: LevelFilter, json_format: bool) -> Result<()> {
    if level == LevelFilter::OFF {
        return Ok(());
    }

    let is_terminal = atty::is(atty::Stream::Stderr);

    let filter = EnvFilter::from_default_env().add_directive(level.to_string().parse()?);

    let builder = FmtSubscriber::builder()
        .with_env_filter(filter)
        .with_writer(std::io::stderr)
        .with_ansi(is_terminal);

    if json_format {
        builder.json().with_timer(UtcTime::rfc_3339()).init()
    } else {
        builder
            .compact()
            .with_timer(UtcTime::new(format_description!(
                "[year]-[month]-[day] [hour]:[minute]:[second]"
            )))
            .init()
    };

    tracing::info!("Initialized logger");

    Ok(())
}

/// Wallet has to be managed by Rust as generics are not support by frb
static LOG_STREAM_SINK: Storage<StreamSink<LogEntry>> = Storage::new();

/// Struct to expose logs from Rust to Flutter
pub struct LogEntry {
    // TODO: Add more fields, including time and level
    pub msg: String,
}

pub fn create_log_stream(sink: StreamSink<LogEntry>) {
    // TODO: Move in a different spot
    init_tracing(LevelFilter::DEBUG, false).expect("Logger to initialise");
    LOG_STREAM_SINK.set(sink);
}

pub fn log(msg: &str) {
    tracing::debug!(msg);
    LOG_STREAM_SINK
        .try_get()
        .expect("StreamSink from Flutter to be initialised")
        .add(LogEntry {
            msg: msg.to_string(),
        });
}
