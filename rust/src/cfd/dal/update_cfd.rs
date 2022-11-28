use crate::db::SqliteConnection;
use anyhow::bail;
use anyhow::Result;

pub async fn update_cfd(
    custom_output_id: &str,
    closing_price: f64,
    connection: &mut SqliteConnection,
) -> Result<()> {
    let updated = time::OffsetDateTime::now_utc().unix_timestamp();
    let query_result = sqlx::query!(
        r#"
        UPDATE cfd
        SET
            state_id = $1, updated = $2, close_price = $3
        WHERE
            cfd.custom_output_id = $4
        "#,
        2,
        updated,
        closing_price,
        custom_output_id,
    )
    .execute(connection)
    .await?;

    if query_result.rows_affected() != 1 {
        bail!(
            "Failed to mark CFD as settled in DB. Custom output ID: {}",
            custom_output_id
        );
    }
    Ok(())
}
