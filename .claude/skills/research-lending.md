# Skill: Research Lending Protocol

## Purpose
Gather all information needed to build a yield adapter for lending protocols (Compound-style, Aave-style, and variants).

## Input
- Protocol slug (e.g., "aave-v3", "compound-v3", "venus-core-pool")
- Chain(s) to support

## Lending Protocol Fundamentals

Lending protocols have two sides:
1. **Supply Side** - Users deposit assets to earn interest (apyBase)
2. **Borrow Side** - Users borrow assets and pay interest (apyBaseBorrow)

**Required Adapter Fields for Lending:**
- `apyBase` - Supply APY
- `apyBaseBorrow` - Borrow APY (negative for borrowers)
- `totalSupplyUsd` - Total supplied
- `totalBorrowUsd` - Total borrowed
- `ltv` - Loan-to-value ratio (optional but recommended)

## Research Phases

### Phase 1: DefiLlama Protocol Info

```bash
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{
  name,
  slug,
  category,
  chains,
  url,
  twitter,
  github,
  module
}'
```

**Verify category is "Lending" or "CDP"**

### Phase 2: Identify Protocol Architecture

**Two Main Patterns:**

| Style | Key Contracts | Rate Format | Examples |
|-------|--------------|-------------|----------|
| Compound | Comptroller + cTokens | Per Block | Compound, Venus, Cream |
| Aave | Pool + DataProvider | RAY (27 decimals) | Aave v2/v3, Spark |

**Detection via Contract Functions:**
```bash
# Check for Compound-style (Comptroller)
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}" | jq -r '.result' | grep -i "supplyRatePerBlock\|borrowRatePerBlock\|getAllMarkets"

# Check for Aave-style (Pool)
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}" | jq -r '.result' | grep -i "liquidityRate\|getReserveData\|ADDRESSES_PROVIDER"
```

### Phase 3: Documentation Discovery

**3a. Find Documentation via Sitemap:**
```bash
# Get sitemap and filter for relevant pages
curl -s "https://docs.{protocol}.com/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+' | grep -iE 'contract|address|deploy|rate|interest|api|developer'

# Alternative sitemap locations
curl -s "https://{protocol}.gitbook.io/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+'
curl -s "https://docs.{protocol}.fi/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+'
```

**3b. Key Documentation Sections:**
- Contract addresses / deployments
- Interest rate model
- Reserve factors
- Liquidation parameters
- API endpoints (if available)

### Phase 4: Existing TVL Adapter

```bash
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{slug}/index.js"
```

**Extract:**
- Comptroller/Pool addresses
- Market/Reserve addresses
- Chain configurations

### Phase 5: Compound-Style Research

**Key Contracts:**
- **Comptroller**: Central registry, lists all markets
- **cToken/vToken**: Individual market contracts

**Key Functions:**
```solidity
// Comptroller
function getAllMarkets() external view returns (address[]);
function markets(address) external view returns (bool isListed, uint collateralFactorMantissa);

// cToken/Market
function supplyRatePerBlock() external view returns (uint);
function borrowRatePerBlock() external view returns (uint);
function exchangeRateCurrent() external returns (uint);
function totalSupply() external view returns (uint);
function totalBorrows() external view returns (uint);
function underlying() external view returns (address);
function getCash() external view returns (uint);
function reserveFactorMantissa() external view returns (uint);
```

**APY Calculation (Compound-style):**
```javascript
// Blocks per year varies by chain
const blocksPerYear = {
  ethereum: 2628000,  // ~12 sec blocks
  bsc: 10512000,      // ~3 sec blocks
  polygon: 15768000,  // ~2 sec blocks
  arbitrum: 2628000,  // ~12 sec blocks (L1 based)
  base: 15768000,     // ~2 sec blocks
};

// Supply APY
const supplyRatePerBlock = await cToken.supplyRatePerBlock();
const supplyApy = (Math.pow(1 + supplyRatePerBlock / 1e18, blocksPerYear) - 1) * 100;

// Borrow APY
const borrowRatePerBlock = await cToken.borrowRatePerBlock();
const borrowApy = (Math.pow(1 + borrowRatePerBlock / 1e18, blocksPerYear) - 1) * 100;
```

**TVL Calculation:**
```javascript
const exchangeRate = await cToken.exchangeRateCurrent();
const totalSupply = await cToken.totalSupply();
const totalBorrows = await cToken.totalBorrows();
const underlyingDecimals = await underlying.decimals();

// Total supplied in underlying
const totalSupplied = (totalSupply * exchangeRate) / (10 ** (18 + underlyingDecimals - 8));

// Or use getCash + totalBorrows
const totalSupplied = getCash + totalBorrows;
```

### Phase 6: Aave-Style Research

**Key Contracts:**
- **PoolAddressesProvider**: Registry for all Aave contracts
- **Pool**: Main lending pool
- **PoolDataProvider**: Read-only data access (preferred)
- **AToken**: Receipt tokens for deposits

**Key Functions:**
```solidity
// PoolAddressesProvider
function getPool() external view returns (address);
function getPoolDataProvider() external view returns (address);

// Pool
function getReserveData(address asset) external view returns (ReserveData memory);

// PoolDataProvider (AaveProtocolDataProvider)
function getAllReservesTokens() external view returns (TokenData[] memory);
function getReserveData(address asset) external view returns (
  uint256 unbacked,
  uint256 accruedToTreasuryScaled,
  uint256 totalAToken,
  uint256 totalStableDebt,
  uint256 totalVariableDebt,
  uint256 liquidityRate,      // Supply APY in RAY
  uint256 variableBorrowRate, // Variable borrow APY in RAY
  uint256 stableBorrowRate,   // Stable borrow APY in RAY
  ...
);
function getReserveConfigurationData(address asset) external view returns (
  uint256 decimals,
  uint256 ltv,
  uint256 liquidationThreshold,
  ...
);
```

**APY Calculation (Aave-style):**
```javascript
// RAY = 10^27
const RAY = 10n ** 27n;

// Rates are already annualized in RAY format
const liquidityRate = reserveData.liquidityRate;
const variableBorrowRate = reserveData.variableBorrowRate;

// Convert to percentage
const supplyApy = Number(liquidityRate) / 1e25; // RAY to percentage
const borrowApy = Number(variableBorrowRate) / 1e25;
```

**TVL Calculation:**
```javascript
const totalAToken = reserveData.totalAToken; // Scaled
const totalVariableDebt = reserveData.totalVariableDebt;
const totalStableDebt = reserveData.totalStableDebt;

// Get asset price
const price = await getPriceFromOracle(asset);

const totalSupplyUsd = (totalAToken / 10**decimals) * price;
const totalBorrowUsd = ((totalVariableDebt + totalStableDebt) / 10**decimals) * price;
```

### Phase 7: Interest Rate Model Research

**Find interest rate parameters:**
```bash
# Search docs for interest rate model
curl -s "https://docs.{protocol}.com/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' | xargs -I {} sh -c 'curl -s "{}" 2>/dev/null | grep -i "interest\|rate\|model\|utilization"' | head -20

# Check contract for rate model
curl -s "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={interestRateModel}" | jq -r '.result[0].SourceCode' | grep -i "baseRate\|slope\|kink"
```

**Common Parameters:**
- `baseRate` - Rate at 0% utilization
- `slope1` - Rate increase below kink
- `slope2` - Rate increase above kink (usually steeper)
- `kink` - Utilization rate where slope changes (e.g., 80%)
- `reserveFactor` - Protocol's cut of interest (e.g., 10-20%)

### Phase 8: Reward Token Research (apyReward)

Many lending protocols have additional token rewards:

```bash
# Check for incentives controller
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}" | jq -r '.result' | grep -i "incentive\|reward\|emission"

# Common reward contracts
# - Aave: IncentivesController
# - Compound: Comptroller.compSpeeds
# - Venus: VAIController, XVS rewards
```

**If rewards exist:**
```javascript
// Include in adapter output
{
  apyBase: supplyApy,
  apyReward: rewardApy,
  rewardTokens: ['0x...reward_token_address'],
}
```

### Phase 9: Liquidation Parameters (LTV)

```javascript
// Compound-style
const collateralFactor = await comptroller.markets(cToken);
const ltv = collateralFactor.collateralFactorMantissa / 1e18;

// Aave-style
const config = await dataProvider.getReserveConfigurationData(asset);
const ltv = config.ltv / 10000; // Stored as basis points
```

### Phase 10: API Endpoints (Alternative Data Source)

Some protocols provide APIs:
```bash
# Check for API
curl -s "https://api.{protocol}.com/markets"
curl -s "https://{protocol}.com/api/v1/markets"
curl -s "https://api.{protocol}.fi/lending/markets"

# Aave-specific
curl -s "https://aave-api-v2.aave.com/data/markets-data"
```

### Phase 11: Reference Adapters

**Study these existing lending adapters:**

```bash
# Aave v3 (multi-chain, Aave-style)
cat src/adaptors/aave-v3/index.js

# Compound v3 (Comet architecture)
cat src/adaptors/compound-v3/index.js

# Venus (Compound fork on BSC)
cat src/adaptors/venus-core-pool/index.js

# Morpho (aggregator)
cat src/adaptors/morpho-aave-v3/index.js

# Radiant (cross-chain lending)
cat src/adaptors/radiant-v2/index.js
```

### Phase 12: Multi-Chain Configuration

```bash
# Check which chains the protocol supports
curl -s "https://api.llama.fi/protocol/{slug}" | jq '.chainTvls | keys'

# Look for deployment addresses per chain in docs
curl -s "https://docs.{protocol}.com/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' | grep -i "deploy\|address\|contract"
```

**Common Config Pattern:**
```javascript
const config = {
  ethereum: {
    comptroller: '0x...',
    // or
    poolAddressesProvider: '0x...',
  },
  polygon: {
    // ...
  },
};
```

## Output Format

```markdown
## Research Results: {Protocol Name} (Lending)

### Basic Info
- Slug: {slug}
- Architecture: {Compound-style | Aave-style | Other}
- Chains: {chains}
- Website: {url}
- GitHub: {github}

### Protocol Architecture
- Style: {Compound | Aave | Custom}
- Core Contracts:
  - Registry: {Comptroller | PoolAddressesProvider} at {address}
  - Markets: {cToken | aToken} pattern
  - Data Provider: {address if Aave-style}

### Contracts Per Chain
| Chain | Contract Type | Address |
|-------|--------------|---------|
| | Comptroller/Pool | |
| | DataProvider | |
| | Rate Model | |

### Interest Rate Functions
**Supply Rate:**
- Function: `{function signature}`
- Format: {per block | RAY | percentage}
- Conversion: {formula}

**Borrow Rate:**
- Function: `{function signature}`
- Format: {per block | RAY | percentage}
- Conversion: {formula}

### Interest Rate Model
- Base Rate: {X}%
- Slope 1: {X}%
- Slope 2: {X}%
- Kink: {X}%
- Reserve Factor: {X}%

### TVL Calculation
- Total Supply: {method}
- Total Borrow: {method}
- Price Source: {oracle | DefiLlama}

### Reward Tokens (if applicable)
- Token: {symbol} ({address})
- Distribution: {mechanism}
- Include `apyReward` and `rewardTokens` in output

### Liquidation Parameters
- LTV: {how to fetch}
- Liquidation Threshold: {value}
- Liquidation Incentive: {value}

### Data Source Recommendation
- Primary: {on-chain via DataProvider | Subgraph | API}
- Reason: {why}

### API Endpoints (if available)
| Endpoint | Returns |
|----------|---------|
| | |

### Reference Adapter
- `src/adaptors/{name}/` - {similarity reason}

### Notes
- {Any special considerations}
- {Isolated markets vs shared pool}
- {Flash loan availability}
```

## Checklist

Before completing research:
- [ ] Protocol style identified (Compound vs Aave)
- [ ] Core contract addresses found
- [ ] Supply rate function and format understood
- [ ] Borrow rate function and format understood
- [ ] TVL calculation method determined
- [ ] Blocks per year known (if Compound-style)
- [ ] Reserve factor / fees documented
- [ ] Reward tokens identified (if any)
- [ ] LTV retrieval method found
- [ ] Multi-chain config gathered
- [ ] Similar adapter identified
