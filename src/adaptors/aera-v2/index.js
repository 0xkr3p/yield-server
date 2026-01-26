const utils = require('../utils');
const sdk = require('@defillama/sdk');
const axios = require('axios');

const AERA_API = 'https://app.aera.finance/api/vaults';

// Chain ID to chain name mapping
const CHAIN_MAP = {
  1: 'ethereum',
  10: 'optimism',
  137: 'polygon',
  8453: 'base',
  42161: 'arbitrum',
};

// Testnet chain IDs to skip
const TESTNET_CHAINS = [17000]; // Holesky

// ABI for vault functions
const VAULT_ABI = {
  value: 'function value() view returns (uint256)',
  assetRegistry: 'function assetRegistry() view returns (address)',
  holdings: 'function holdings() view returns (tuple(address asset, uint256 balance)[])',
};

const ASSET_REGISTRY_ABI = {
  numeraireToken: 'function numeraireToken() view returns (address)',
};

const ERC20_ABI = {
  symbol: 'function symbol() view returns (string)',
  decimals: 'function decimals() view returns (uint8)',
};

// Fetch all vaults from Aera API
const fetchVaults = async () => {
  try {
    const response = await axios.get(AERA_API);
    return response.data.filter(
      (vault) =>
        !TESTNET_CHAINS.includes(vault.chain_id) &&
        CHAIN_MAP[vault.chain_id] !== undefined &&
        // Skip v3 vaults (MultiDepositorVault) as they have a different interface
        vault.aera_version !== 'v3'
    );
  } catch (error) {
    console.error('Error fetching Aera vaults:', error.message);
    return [];
  }
};

// Get vault TVL in USD
const getVaultTvl = async (vaultAddress, chain) => {
  try {
    // Get vault value in numeraire token
    const valueResult = await sdk.api.abi.call({
      target: vaultAddress,
      abi: VAULT_ABI.value,
      chain,
    });

    const value = valueResult.output;
    if (!value || value === '0') {
      return { tvlUsd: 0, numeraireToken: null };
    }

    // Get asset registry address
    const assetRegistryResult = await sdk.api.abi.call({
      target: vaultAddress,
      abi: VAULT_ABI.assetRegistry,
      chain,
    });

    // Get numeraire token from asset registry
    const numeraireResult = await sdk.api.abi.call({
      target: assetRegistryResult.output,
      abi: ASSET_REGISTRY_ABI.numeraireToken,
      chain,
    });

    const numeraireToken = numeraireResult.output;

    // Get numeraire token decimals
    const decimalsResult = await sdk.api.abi.call({
      target: numeraireToken,
      abi: ERC20_ABI.decimals,
      chain,
    });

    const decimals = Number(decimalsResult.output);

    // Get numeraire token price from DefiLlama
    const priceKey = `${chain}:${numeraireToken}`;
    const priceResponse = await axios.get(
      `https://coins.llama.fi/prices/current/${priceKey}`
    );

    const price = priceResponse.data?.coins?.[priceKey]?.price;
    if (!price) {
      console.warn(`No price found for ${priceKey}`);
      return { tvlUsd: 0, numeraireToken };
    }

    const tvlUsd = (Number(value) / 10 ** decimals) * price;
    return { tvlUsd, numeraireToken };
  } catch (error) {
    console.error(`Error getting TVL for vault ${vaultAddress}:`, error.message);
    return { tvlUsd: 0, numeraireToken: null };
  }
};

// Get vault holdings to determine symbol
const getVaultSymbol = async (vaultAddress, chain) => {
  try {
    const holdingsResult = await sdk.api.abi.call({
      target: vaultAddress,
      abi: VAULT_ABI.holdings,
      chain,
    });

    const holdings = holdingsResult.output;
    if (!holdings || holdings.length === 0) {
      return 'MULTI';
    }

    // Get symbols for holdings with non-zero balances
    const nonZeroHoldings = holdings.filter(
      (h) => h.balance && h.balance !== '0'
    );

    if (nonZeroHoldings.length === 0) {
      return 'MULTI';
    }

    // Get symbols for up to 3 assets
    const assetsToQuery = nonZeroHoldings.slice(0, 3);
    const symbolResults = await sdk.api.abi.multiCall({
      abi: ERC20_ABI.symbol,
      calls: assetsToQuery.map((h) => ({ target: h.asset })),
      chain,
      permitFailure: true,
    });

    const symbols = symbolResults.output
      .map((r) => r.output)
      .filter((s) => s);

    if (symbols.length === 0) {
      return 'MULTI';
    }

    // If more than 3 assets, append "..."
    if (nonZeroHoldings.length > 3) {
      return symbols.join('-') + '-...';
    }

    return symbols.join('-');
  } catch (error) {
    console.error(`Error getting symbol for vault ${vaultAddress}:`, error.message);
    return 'MULTI';
  }
};

// Get underlying token addresses from holdings
const getUnderlyingTokens = async (vaultAddress, chain) => {
  try {
    const holdingsResult = await sdk.api.abi.call({
      target: vaultAddress,
      abi: VAULT_ABI.holdings,
      chain,
    });

    const holdings = holdingsResult.output;
    if (!holdings || holdings.length === 0) {
      return [];
    }

    return holdings
      .filter((h) => h.balance && h.balance !== '0')
      .map((h) => h.asset);
  } catch (error) {
    console.error(`Error getting underlying tokens for vault ${vaultAddress}:`, error.message);
    return [];
  }
};

const main = async () => {
  const vaults = await fetchVaults();
  console.log(`Found ${vaults.length} Aera vaults`);

  const pools = [];

  // Group vaults by chain for efficient processing
  const vaultsByChain = {};
  for (const vault of vaults) {
    const chain = CHAIN_MAP[vault.chain_id];
    if (!vaultsByChain[chain]) {
      vaultsByChain[chain] = [];
    }
    vaultsByChain[chain].push(vault);
  }

  // Process each chain
  for (const [chain, chainVaults] of Object.entries(vaultsByChain)) {
    console.log(`Processing ${chainVaults.length} vaults on ${chain}`);

    for (const vault of chainVaults) {
      try {
        const vaultAddress = vault.vault_address;

        // Get TVL and symbol in parallel
        const [{ tvlUsd, numeraireToken }, symbol, underlyingTokens] =
          await Promise.all([
            getVaultTvl(vaultAddress, chain),
            getVaultSymbol(vaultAddress, chain),
            getUnderlyingTokens(vaultAddress, chain),
          ]);

        // Skip vaults with no TVL
        if (tvlUsd <= 0) {
          continue;
        }

        const poolMeta = vault.vault_type
          ? vault.vault_type.replace('_', ' ')
          : undefined;

        pools.push({
          pool: `${vaultAddress}-${chain}`.toLowerCase(),
          chain: utils.formatChain(chain),
          project: 'aera-v2',
          symbol: utils.formatSymbol(symbol),
          tvlUsd,
          apyBase: 0, // Aera vaults are treasury management, no defined yield
          underlyingTokens:
            underlyingTokens.length > 0 ? underlyingTokens : undefined,
          poolMeta,
          url: `https://app.aera.finance/vault/${vault.chain_id}/${vaultAddress}`,
        });
      } catch (error) {
        console.error(
          `Error processing vault ${vault.vault_address}:`,
          error.message
        );
      }
    }
  }

  return pools.filter((p) => utils.keepFinite(p));
};

module.exports = {
  timetravel: false,
  apy: main,
  url: 'https://app.aera.finance',
};
