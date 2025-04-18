# Signal Proximity API Implementation Guide

For the Trading Advisor server developers, this document outlines the required endpoints to support the new signal proximity feature in the client application.

## Required Endpoints

### 1. Get All Tickers with Signal Proximity Details

**Endpoint:** `GET /api/v1/tickers/details`

**Response Format:**

```json
[
  {
    "ticker": "AAPL",
    "proximity_value": 85,
    "description": "Approaching RSI signal zone",
    "model_type": "RSI_MODEL"
  },
  {
    "ticker": "MSFT",
    "proximity_value": 32,
    "description": "Initial signs of price movement toward band",
    "model_type": "BOLLINGER_MODEL"
  }
]
```

### 2. Get Signal Proximity for Specific Ticker

**Endpoint:** `GET /api/v1/tickers/{ticker}/signal_proximity`

**Response Format:**

```json
{
  "ticker": "AAPL",
  "proximity_value": 85,
  "description": "Approaching RSI signal zone",
  "model_type": "RSI_MODEL"
}
```

## Implementation Details

### Proximity Value Calculation

The proximity value should be calculated based on the analysis model for each ticker:

#### For RSI Model:

- Calculate proximity to oversold (below 30) or overbought (above 70) zones
- Formula: `100 - (abs(currentRSI - thresholdRSI) / 30) * 100`
- Example: If RSI is at 35, and threshold is 30: `100 - (abs(35 - 30) / 30) * 100 = 83.3%`

#### For Bollinger Bands Model:

- Calculate proximity to upper or lower bands
- Formula: `100 - (distance from price to nearest band / band width) * 100`
- Example: If price is close to lower band, value will be high (80-100%)

### Description Generation

Generate descriptions based on the proximity value and the model type:

1. **Very High (76-100%):**

   - RSI: "Very close to RSI signal zone" or "Price in RSI oversold/overbought zone"
   - Bollinger: "Price near Bollinger Band boundary" or "Price touching Bollinger Band"

2. **High (51-75%):**

   - RSI: "Approaching RSI signal zone"
   - Bollinger: "Price moving toward Bollinger Band boundary"

3. **Medium (26-50%):**

   - RSI: "Moderate RSI movement detected"
   - Bollinger: "Moderate price movement toward band"

4. **Low (0-25%):**
   - RSI: "Neutral RSI state"
   - Bollinger: "Price in neutral zone"

## Data Update Frequency

The signal proximity data should be updated:

- Every time the price data is updated
- At least every 5 minutes for active trading sessions
- Store the last calculated values for each ticker in the database

## Error Handling

If the calculation cannot be performed (e.g., insufficient data):

- Return a proximity value of 0
- Set description to "Insufficient data for signal proximity calculation"
