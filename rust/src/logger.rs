use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use state::Storage;
use time::macros::format_description;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::fmt::time::UtcTime;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::EnvFilter;
use tracing_subscriber::Layer;

pub fn init_tracing(level: LevelFilter, json_format: bool) -> Result<()> {
    if level == LevelFilter::OFF {
        return Ok(());
    }

    let is_terminal = atty::is(atty::Stream::Stderr);

    let filter = EnvFilter::from_default_env()
        .add_directive(level.to_string().parse()?)
        .add_directive("bdk=warn".parse()?); // bdk is quite spamy on debug

    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_writer(std::io::stderr)
        .with_ansi(is_terminal);

    let fmt_layer = if json_format {
        fmt_layer.json().with_timer(UtcTime::rfc_3339()).boxed()
    } else {
        fmt_layer
            .with_timer(UtcTime::new(format_description!(
                "[year]-[month]-[day] [hour]:[minute]:[second]"
            )))
            .boxed()
    };

    tracing_subscriber::registry()
        .with(filter)
        .with(DartSendLayer)
        .with(fmt_layer)
        .try_init()
        .context("Failed to init tracing")?;

    tracing::info!("Initialized logger");

    Ok(())
}

/// Wallet has to be managed by Rust as generics are not support by frb
static LOG_STREAM_SINK: Storage<StreamSink<LogEntry>> = Storage::new();

/// Struct to expose logs from Rust to Flutter
pub struct LogEntry {
    pub msg: String,
    pub target: String,
    // TODO: Use Level enum
    pub level: String,
}

pub fn create_log_stream(sink: StreamSink<LogEntry>) {
    // TODO: Move in a different spot
    LOG_STREAM_SINK.set(sink);
    init_tracing(LevelFilter::DEBUG, false).expect("Logger to initialise");
}

/// Tracing layer responsible for sending tracing events into
struct DartSendLayer;

impl<S> Layer<S> for DartSendLayer
where
    S: tracing::Subscriber,
{
    fn on_event(
        &self,
        event: &tracing::Event<'_>,
        _ctx: tracing_subscriber::layer::Context<'_, S>,
    ) {
        let metadata = event.metadata();

        let msg = format!("{}: {}", metadata.name(), metadata.fields());

        LOG_STREAM_SINK
            .try_get()
            .expect("StreamSink from Flutter to be initialised")
            .add(LogEntry {
                msg,
                target: metadata.target().to_string(),
                level: metadata.level().to_string(),
            });
    }
}
