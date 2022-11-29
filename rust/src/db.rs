use crate::hex_utils;
use crate::lightning::HTLCStatus;
use crate::lightning::MillisatAmount;
use crate::lightning::PaymentInfo;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::ensure;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin::hashes::hex::FromHex;
use bdk::bitcoin::hashes::hex::ToHex;
use bdk::bitcoin::Txid;
use futures::TryStreamExt;
use lightning::ln::PaymentHash;
use lightning::ln::PaymentPreimage;
use lightning::ln::PaymentSecret;
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

fn into_array(vec: Vec<u8>) -> [u8; 32] {
    vec.as_slice()
        .try_into()
        .unwrap_or_else(|_| panic!("Expected a Vec of length {} but it was {}", 32, vec.len()))
}

pub async fn init_db(sqlite_path: &Path) -> Result<()> {
    tracing::debug!(?sqlite_path, "SQLite database will be stored on disk");

    let pool = SqlitePool::connect_with(
        SqliteConnectOptions::new()
            .create_if_missing(true)
            .filename(sqlite_path),
    )
    .await?;

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .context("Failed to run migrations")?;

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

pub async fn load_ignore_txids() -> Result<Vec<(Txid, u64)>> {
    let mut conn = acquire().await?;

    let mut rows = sqlx::query!(
        r#"
            select
                txid,
                maker_amount
            from
                ignore_txid
            order by id
            "#
    )
    .fetch(&mut *conn);

    let mut ignore_txids = Vec::new();

    while let Some(row) = rows.try_next().await? {
        let txid = Txid::from_hex(row.txid.as_str())?;
        let maker_amount = row.maker_amount as u64;
        ignore_txids.push((txid, maker_amount));
    }

    Ok(ignore_txids)
}

pub async fn insert_ignore_txid(txid: Txid, maker_amount: i64) -> Result<()> {
    let mut conn = acquire().await?;

    let query_result = sqlx::query(
        r#"
        INSERT INTO ignore_txid (txid, maker_amount)
        VALUES ($1, $2)
        "#,
    )
    .bind(txid.to_hex())
    .bind(maker_amount)
    .execute(&mut conn)
    .await?;

    if query_result.rows_affected() != 1 {
        bail!("Failed to insert txid to be ignored");
    }

    tracing::info!("Successfully stored txid to be ignored");

    Ok(())
}

pub async fn insert_payment(payment: &PaymentInfo) -> Result<()> {
    let mut conn = acquire().await?;

    let PaymentInfo {
        hash,
        preimage,
        secret,
        flow,
        status,
        amt_msat,
        created_timestamp,
        updated_timestamp,
    } = payment.clone();

    let query_result = sqlx::query(
        r#"
        INSERT INTO payments (payment_hash, preimage, secret, flow, htlc_status, amount_msat, created, updated)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
    )
    .bind(base64::encode(hash.0))
    .bind(preimage.map(|x| base64::encode(x.0)))
    .bind(secret.map(|x| base64::encode(x.0)))
    .bind(flow)
    .bind(status)
    .bind(amt_msat.0.map(|msat| msat as i64))
    .bind(created_timestamp as i64)
    .bind(updated_timestamp as i64)
    .execute(&mut conn)
    .await?;

    ensure!(
        query_result.rows_affected() == 1,
        format!("Failed to insert payment: {}", hex_utils::hex_str(&hash.0))
    );
    tracing::info!(
        "Successfully stored new payment: {}",
        hex_utils::hex_str(&hash.0)
    );
    Ok(())
}

// HACK: sometimes we add this information to an already existing payment
pub struct PaymentNewInfo {
    pub preimage: Option<PaymentPreimage>,
    pub secret: Option<PaymentSecret>,
}

/// Updates the payment in the database and returns the payment data.
pub async fn update_payment(
    payment_hash: &PaymentHash,
    status: HTLCStatus,
    new_info: Option<PaymentNewInfo>,
) -> Result<PaymentInfo> {
    let mut connection = acquire().await?;
    let updated = time::OffsetDateTime::now_utc().unix_timestamp();
    let hash = base64::encode(payment_hash.0);

    let query_result = if let Some(new_info) = new_info {
        let preimage = new_info.preimage.map(|x| base64::encode(x.0));
        let secret = new_info.secret.map(|x| base64::encode(x.0));

        sqlx::query!(
            r#"
        UPDATE payments
        SET
            htlc_status = $1, updated = $2, preimage = $3, secret = $4
        WHERE
            payments.payment_hash = $5
        "#,
            status,
            updated,
            preimage,
            secret,
            hash,
        )
        .execute(&mut connection)
        .await?
    } else {
        sqlx::query!(
            r#"
        UPDATE payments
        SET
            htlc_status = $1, updated = $2
        WHERE
            payments.payment_hash = $3
        "#,
            status,
            updated,
            hash,
        )
        .execute(&mut connection)
        .await?
    };

    ensure!(
        query_result.rows_affected() == 1,
        "Failed to update payment"
    );

    let payment = load_payment(payment_hash).await?;

    tracing::info!(
        "Successfully updated payment: {}",
        hex_utils::hex_str(&payment_hash.0)
    );

    Ok(payment)
}

pub async fn load_payment(hash: &PaymentHash) -> Result<PaymentInfo> {
    // TODO: Use a dedicated query returning a single payment instead of returning a vector and
    // filtering
    load_payments()
        .await?
        .iter()
        .find(|payment| payment.hash == *hash)
        .context("Unable to find requested hash in DB")
        .cloned()
}

pub async fn load_payments() -> Result<Vec<PaymentInfo>> {
    let mut conn = acquire().await?;

    let mut rows = sqlx::query!(
        r#"
            select
                payment_hash,
                preimage,
                secret,
                flow as "flow: crate::lightning::Flow",
                htlc_status as "status: crate::lightning::HTLCStatus",
                amount_msat,
                updated,
                created
            from
                payments
            "#
    )
    .fetch(&mut *conn);

    let mut payments = Vec::new();

    while let Some(row) = rows.try_next().await? {
        let payment = PaymentInfo {
            hash: PaymentHash(into_array(base64::decode(row.payment_hash).unwrap())),
            preimage: row
                .preimage
                .map(|x| PaymentPreimage(into_array(base64::decode(x).unwrap()))),
            secret: row
                .secret
                .map(|x| PaymentSecret(into_array(base64::decode(x).unwrap()))),
            flow: row.flow,
            status: row.status,
            amt_msat: row
                .amount_msat
                .map(|msats| MillisatAmount(Some(msats as u64)))
                .unwrap_or(MillisatAmount(None)),
            created_timestamp: row.created as u64,
            updated_timestamp: row.updated as u64,
        };
        payments.push(payment);
    }

    Ok(payments)
}

#[cfg(test)]
mod tests {
    use crate::lightning::Flow;
    use crate::lightning::MillisatAmount;
    use std::env::temp_dir;
    use std::time::Duration;
    use tracing::subscriber::DefaultGuard;
    use tracing_subscriber::util::SubscriberInitExt;

    use super::*;

    fn dummy_payment() -> PaymentInfo {
        PaymentInfo::new(
            PaymentHash([0u8; 32]),
            None,
            None,
            Flow::Inbound,
            crate::lightning::HTLCStatus::Pending,
            MillisatAmount(Some(100000)),
        )
    }

    pub fn init_tracing() -> DefaultGuard {
        tracing_subscriber::fmt()
            .with_env_filter("DEBUG")
            .set_default()
    }

    async fn ensure_init_fresh_db() -> Result<()> {
        if get_db().is_err() {
            let sqlite_path = temp_dir().join("test.sqlite");
            if sqlite_path.exists() {
                std::fs::remove_file(sqlite_path.clone()).unwrap();
            };
            init_db(sqlite_path.as_path())
                .await
                .expect("DB to initialise ");
        };
        Ok(())
    }

    #[tokio::test]
    async fn test_payments_db_storage() {
        let _guard = init_tracing();
        ensure_init_fresh_db().await.unwrap();
        let payment = dummy_payment();
        insert_payment(&payment).await.unwrap();

        let payments = load_payments().await.unwrap();

        assert_eq!(payments.len(), 1, "Only one payment got stored");
        assert_eq!(
            payments.first().unwrap(),
            &payment,
            "Stored and loaded payment do not match",
        );

        tokio::time::sleep(Duration::from_secs(1)).await; // so updated time changes

        let updated_payment = update_payment(&payment.hash, HTLCStatus::Succeeded, None)
            .await
            .unwrap();

        assert_eq!(
            updated_payment.status,
            HTLCStatus::Succeeded,
            "Status should have been updated"
        );

        assert_ne!(
            updated_payment.created_timestamp,
            updated_payment.updated_timestamp
        );
    }
}
