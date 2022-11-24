use anyhow::Context;
use anyhow::Result;
use time::macros::format_description;
use tracing::metadata::LevelFilter;
use tracing_subscriber::filter::Directive;
use tracing_subscriber::fmt::time::UtcTime;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::EnvFilter;
use tracing_subscriber::Layer;

// TODO: Share the logging infrastructure (it's just a copy for now for expedience)

const RUST_LOG_ENV: &str = "RUST_LOG";

// Tracing log directives config
fn log_base_directives(env: EnvFilter, level: LevelFilter) -> Result<EnvFilter> {
    let filter = env
        .add_directive(Directive::from(level))
        .add_directive("hyper=warn".parse()?)
        .add_directive("rustls=warn".parse()?)
        // set to debug to show ldk logs (they're also in logs.txt)
        .add_directive("ldk=warn".parse()?)
        .add_directive("bdk=warn".parse()?); // bdk is quite spamy on debug
    Ok(filter)
}

// Configure and initalise tracing subsystem
pub fn init_tracing(level: LevelFilter, json_format: bool) -> Result<()> {
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
        .with(fmt_layer)
        .try_init()
        .context("Failed to init tracing")?;

    tracing::info!("Initialized logger");

    Ok(())
}
