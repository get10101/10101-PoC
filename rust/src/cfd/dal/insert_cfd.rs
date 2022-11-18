use crate::cfd::models::Order;
use crate::db::SqliteConnection;
use anyhow::bail;
use anyhow::Result;

pub async fn insert_cfd(
    margin_taker: i64,
    custom_output_id: String,
    liquidation_price: f64,
    expiry: i64,
    order: &Order,
    connection: &mut SqliteConnection,
) -> Result<()> {
    let created = time::OffsetDateTime::now_utc().unix_timestamp();
    let updated = time::OffsetDateTime::now_utc().unix_timestamp();
    let query_result = sqlx::query!(
        r#"
        INSERT INTO cfd (custom_output_id, contract_symbol, position, leverage, created, updated, state_id, quantity, expiry, open_price, liquidation_price, margin)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        "#,
        custom_output_id,
        order.contract_symbol,
        order.position,
        order.leverage,
        created,
        updated,
        1,
        order.quantity,
        expiry,
        order.open_price,
        liquidation_price,
        margin_taker
    ).execute(connection).await?;

    if query_result.rows_affected() != 1 {
        bail!("Failed to insert cfd");
    }

    tracing::info!("Successfully stored CFD to database");

    Ok(())
}
