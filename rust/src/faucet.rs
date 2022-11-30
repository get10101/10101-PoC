use crate::config::maker_endpoint;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use reqwest::StatusCode;

pub async fn call_faucet(address: String) -> Result<String> {
    let client = reqwest::Client::builder()
        .timeout(crate::config::TCP_TIMEOUT)
        .build()?;
    let response = client
        .get(maker_endpoint() + "/api/faucet/" + address.as_str())
        .send()
        .await
        .context("Could not call faucet")?;

    if response.status() == StatusCode::NOT_FOUND
        || response.status() == StatusCode::INTERNAL_SERVER_ERROR
    {
        let response = response.text().await?;
        bail!("Failed to call faucet: {response}")
    }

    let result = response
        .json::<String>()
        .await
        .map_err(|e| anyhow!("Failed to call faucet {e:?}"))?;
    Ok(result)
}
