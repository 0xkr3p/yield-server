const sdk = require('@defillama/sdk');
const { keepFinite, getPrices } = require('../utils');

const VAULT = '0x0F54097295E97cE61736bb9a0a1066cDf3e31C8F';
const TQGOLD_TOKEN = '0x9dac3d8ac9b84f329f5756daab6767ea0157bfe5';
const XAUT = '0x68749665ff8d2d112fa859aa293f07a622782f38';

const apy = async () => {
  const [totalSupplyRes, pricesRes] = await Promise.all([
    sdk.api.abi.call({
      target: TQGOLD_TOKEN,
      abi: 'uint256:totalSupply',
      chain: 'ethereum',
    }),
    getPrices([XAUT], 'ethereum'),
  ]);

  const totalSupply = Number(totalSupplyRes.output);
  const xautPrice = pricesRes.pricesByAddress[XAUT.toLowerCase()];

  // tqGOLD is ~1:1 with XAUt; totalSupply has 6 decimals
  const tvlUsd = (totalSupply / 1e6) * xautPrice;

  return [
    {
      pool: `${VAULT.toLowerCase()}-ethereum`,
      chain: 'Ethereum',
      project: 'theoriq-gold-vault',
      symbol: 'tqGOLD',
      tvlUsd,
      apyBase: 0, // not tracking APY yet?
      underlyingTokens: [XAUT],
      url: 'https://infinity.theoriq.ai/gold',
    },
  ].filter((p) => keepFinite(p));
};

module.exports = {
  timetravel: false,
  apy,
  url: 'https://infinity.theoriq.ai/gold',
};
