use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use state::Storage;
use std::sync::Once;
use time::macros::format_description;
use tracing_subscriber::filter::Directive;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::fmt::time::UtcTime;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::EnvFilter;
use tracing_subscriber::Layer;

const RUST_LOG_ENV: &str = "RUST_LOG";

static INIT_LOGGER_ONCE: Once = Once::new();

/// Wallet has to be managed by Rust as generics are not support by frb
static LOG_STREAM_SINK: Storage<StreamSink<LogEntry>> = Storage::new();

// Tracing log directives config
fn log_base_directives(env: EnvFilter, level: LevelFilter) -> Result<EnvFilter> {
    let filter = env
        .add_directive(Directive::from(level))
        .add_directive("bdk=warn".parse()?); // bdk is quite spamy on debug
    Ok(filter)
}

/// Struct to expose logs from Rust to Flutter
pub struct LogEntry {
    pub msg: String,
    pub target: String,
    // TODO: Use Level enum
    pub level: String,
}

pub fn create_log_stream(sink: StreamSink<LogEntry>) {
    LOG_STREAM_SINK.set(sink);
    INIT_LOGGER_ONCE.call_once(|| {
        init_tracing(LevelFilter::DEBUG, false).expect("Logger to initialise");
    });
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

// Configure and initalise tracing subsystem
fn init_tracing(level: LevelFilter, json_format: bool) -> Result<()> {
    if level == LevelFilter::OFF {
        return Ok(());
    }

    let is_terminal = atty::is(atty::Stream::Stderr);

    // Parse additional log directives from env variable
    let filter = match std::env::var_os(RUST_LOG_ENV).map(|s| s.into_string()) {
        Some(Ok(env)) => {
            let mut filter = log_base_directives(EnvFilter::new(""), level)?;
            for directive in env.split(',') {
                match directive.parse() {
                    Ok(d) => filter = filter.add_directive(d),
                    Err(e) => println!("WARN ignoring log directive: `{directive}`: {e}"),
                };
            }
            filter
        }
        _ => log_base_directives(EnvFilter::from_env(RUST_LOG_ENV), level)?,
    };

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
