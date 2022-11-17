use anyhow::anyhow;
use anyhow::Context;
use anyhow::Result;
use sqlx::pool::PoolConnection;
use sqlx::sqlite::SqliteConnectOptions;
use sqlx::Sqlite;
use sqlx::SqlitePool;
use state::Storage;
use std::path::Path;
use std::sync::Mutex;
use std::sync::MutexGuard;

pub type SqliteConnection = PoolConnection<Sqlite>;

/// Wallet has to be managed by Rust as generics are not support by frb
static DB: Storage<Mutex<SqlitePool>> = Storage::new();

pub async fn init_db(sqlite_path: &Path) -> Result<()> {
    tracing::debug!(?sqlite_path, "SQLite database will be stored on disk");

    let pool = SqlitePool::connect_with(
        SqliteConnectOptions::new()
            .create_if_missing(true)
            .filename(sqlite_path),
    )
    .await?;

    DB.set(Mutex::new(pool));
    Ok(())
}

pub async fn acquire() -> Result<SqliteConnection> {
    let pool = get_db()
        .map_err(|e| anyhow!("cannot acquire DB lock: {e:#}"))?
        .clone();

    pool.acquire()
        .await
        .map_err(|e| anyhow!("cannot acquire connection: {e:#}"))
}

fn get_db() -> Result<MutexGuard<'static, SqlitePool>> {
    DB.try_get()
        .context("DB uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire DB lock"))
}
