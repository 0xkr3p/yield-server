const utils = require('../utils');

const SCREENER_URL = 'https://api.aggregator.superlend.xyz/vault/screener';

const CHAIN_MAP = {
  1: 'ethereum',
  42793: 'hyperliquid',
};

const getApy = async () => {
  const response = await utils.getData(SCREENER_URL, {});

  const vaults = (response?.data || response || []).filter(
    (v) => v?.vault?.type === 'LOOP' && CHAIN_MAP[v.chainId]
  );

  return vaults.map((v) => {
    const chain = CHAIN_MAP[v.chainId];
    const vaultAddress = v.vault.vaultAddress.toLowerCase();
    const tokenAddress = v.token.address.toLowerCase();

    return {
      pool: `${vaultAddress}-${chain}`,
      chain: utils.formatChain(chain),
      project: 'superloop',
      symbol: v.token.symbol,
      tvlUsd: v.tvmUsd || 0,
      apyBase: v.apy?.net || 0,
      underlyingTokens: [tokenAddress],
      url: `https://app.superlend.xyz/vaults/${v.chainId}-${vaultAddress}`,
      poolMeta: v.vault.name,
    };
  });
};

const apy = async () => {
  const pools = await getApy();
  return pools.filter(
    (p) => Number.isFinite(p.tvlUsd) && Number.isFinite(p.apyBase)
  );
};

module.exports = {
  apy,
};
