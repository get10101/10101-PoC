use flutter_rust_bridge::StreamSink;
use state::Storage;

/// Wallet has to be managed by Rust as generics are not support by frb
static LOG_STREAM_SINK: Storage<StreamSink<LogEntry>> = Storage::new();

/// Struct to expose logs from Rust to Flutter
pub struct LogEntry {
    // TODO: Add more fields, including time and level
    pub msg: String,
}

pub fn create_log_stream(sink: StreamSink<LogEntry>) {
    LOG_STREAM_SINK.set(sink);
}

pub fn log(msg: &str) {
    LOG_STREAM_SINK
        .try_get()
        .expect("logging to be initialised")
        .add(LogEntry {
            msg: msg.to_string(),
        });
}
