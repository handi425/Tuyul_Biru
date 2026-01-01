# ◆ TUYUL BIRU V2.0 ◆

[![Version](https://img.shields.io/badge/Version-2.00-blue.svg)](https://github.com)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-orange.svg)](https://www.metatrader5.com)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

> **Expert Advisor untuk MetaTrader 5 dengan Panel Trading Manual, Signal Generator, dan News Filter**

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Input Parameters](#️-input-parameters)
- [Data Structures](#-data-structures)
- [Indicator Handles](#-indicator-handles)
- [Trading Panel UI](#️-trading-panel-ui)
- [Trading Functions](#-trading-functions)
- [Signal Generator](#-signal-generator)
- [Support & Resistance](#-support--resistance)
- [RSI Divergence Detection](#-rsi-divergence-detection)
- [News Filter System](#-news-filter-system)
- [Functions Reference](#-functions-reference)

---

## 📋 Overview

**TUYUL BIRU V2.0** adalah Expert Advisor (EA) untuk MetaTrader 5 yang menyediakan panel trading manual dengan fitur-fitur canggih:

- 🖥️ **Panel Trading Manual** - Tombol Buy/Sell dengan opsi Grid dan Martingale
- 📊 **Multi-Timeframe Signals** - Monitor RSI, SnR, dan Divergence di 5 timeframe (M15, M30, H1, H4, D1)
- 📈 **Trend MA Visualization** - Garis MA dengan warna dinamis berdasarkan trend
- 📡 **Signal Generator** - Scoring system untuk menghasilkan sinyal Buy/Sell
- 📰 **News Filter** - Deteksi dan tampilan berita ekonomi dari MQL5 Calendar
- 🔀 **RSI Divergence Detection** - Deteksi divergence bullish/bearish

### Informasi Teknis

| Property | Value |
|----------|-------|
| Copyright | TUYUL BIRU |
| Version | 2.00 |
| Magic Number | `666777` |
| Order Filling | ORDER_FILLING_IOC |
| Slippage | 30 points |
| Include Files | `Trade\Trade.mqh` |

---

## ⚙️ Input Parameters

### 🔔 HTF Signal Settings

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `HTF_Timeframe` | ENUM_TIMEFRAMES | PERIOD_H1 | Timeframe untuk sinyal HTF |
| `RSI_Period` | int | 14 | Periode RSI |
| `RSI_Overbought` | int | 70 | Level overbought RSI |
| `RSI_Oversold` | int | 30 | Level oversold RSI |
| `RSI_Div_Lookback` | int | 30 | Lookback untuk deteksi divergence |
| `InpDrawDivLines` | bool | true | Gambar garis divergence |
| `InpDivBullColor` | color | clrLime | Warna divergence bullish |
| `InpDivBearColor` | color | clrRed | Warna divergence bearish |

### 📍 SnR Settings

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `SnR_Pivot_Period` | int | 10 | Periode pivot (bars kiri/kanan) |
| `SnR_Max_Levels` | int | 10 | Maksimal level S/R |
| `SnR_Proximity` | double | 50 | Jarak proximity ke S/R (points) |
| `SnR_Look_Back` | int | 500 | Lookback untuk pencarian pivot |
| `SnR_Support_Color` | color | clrLime | Warna garis support |
| `SnR_Resistance_Color` | color | clrRed | Warna garis resistance |

### 📥 Entry Settings

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `InpDefaultLot` | double | 0.01 | Ukuran lot default |
| `InpLotIncrement` | double | 0.01 | Increment lot untuk martingale |
| `InpGridStep` | int | 200 | Jarak grid default (points) |
| `InpGridLayers` | int | 5 | Jumlah layer grid |

### 🛡️ Risk & Management

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `InpSLTPMode` | ENUM_SLTP_MODE | SLTP_MODE_AUTO_ATR_SNR | Mode SL/TP |
| `InpFixedSL` | int | 500 | Fixed SL (Points) |
| `InpFixedTP` | int | 1000 | Fixed TP (Points) |
| `InpATR_Period` | int | 14 | Periode ATR untuk SL |
| `InpATR_Multiplier` | double | 1.5 | Multiplier ATR untuk SL |
| `InpPartialPercent` | double | 50.0 | Persentase partial close |
| `InpBE_Lock` | int | 50 | Lock profit Break Even (Points) |

### 📈 Trend MA Settings

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `InpShowTrendMA` | bool | true | Tampilkan garis Trend MA |
| `InpTrendMA_Slow` | int | 200 | Periode MA lambat |
| `InpTrendMA_Fast` | int | 10 | Periode MA cepat |
| `InpTrendBullColor` | color | clrLime | Warna trend bullish |
| `InpTrendBearColor` | color | clrRed | Warna trend bearish |
| `InpTrendMA_Width` | int | 2 | Ketebalan garis MA |

### 📡 Signal Generator Settings

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `InpEnableSignal` | bool | true | Aktifkan Signal Generator |
| `InpADX_Period` | int | 14 | Periode ADX |
| `InpADX_Level` | int | 20 | Level minimum ADX |
| `InpRSI_NearLevel` | int | 5 | Toleransi RSI near OB/OS |
| `InpShowSignalArrow` | bool | true | Tampilkan panah sinyal |
| `InpSignalAlert` | bool | true | Aktifkan alert sinyal |

### 📰 News Filter Settings

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `InpEnableNews` | bool | true | Aktifkan deteksi berita |
| `InpNewsAlert` | bool | true | Alert sebelum berita high impact |
| `InpNewsAlertMinutes` | int | 30 | Menit sebelum berita untuk alert |
| `InpNewsLookAhead` | int | 24 | Jam look ahead |
| `InpNewsLookBack` | int | 2 | Jam look back (berita terbaru) |
| `InpShowLowImpact` | bool | false | Tampilkan berita low impact |
| `InpShowMediumImpact` | bool | true | Tampilkan berita medium impact |
| `InpShowHighImpact` | bool | true | Tampilkan berita high impact |
| `InpNewsHighColor` | color | clrRed | Warna high impact |
| `InpNewsMediumColor` | color | clrOrange | Warna medium impact |
| `InpNewsLowColor` | color | clrYellow | Warna low impact |

---

## 📦 Data Structures

### ENUM_SLTP_MODE

Mode penghitungan SL/TP:

- `SLTP_MODE_FIXED` - Fixed Points
- `SLTP_MODE_AUTO_ATR_SNR` - SL=ATR, TP=SnR
- `SLTP_MODE_MARTINGALE` - Reserved

### ENUM_NEWS_IMPACT

Level dampak berita:

- `NEWS_IMPACT_NONE` = 0
- `NEWS_IMPACT_LOW` = 1 🟡
- `NEWS_IMPACT_MEDIUM` = 2 🟠
- `NEWS_IMPACT_HIGH` = 3 🔴

### SnRData

Struktur data Support/Resistance:

```mql5
struct SnRData {
    double pivots[];      // Array pivot points
    double levels[];      // Calculated S/R levels
    ENUM_TIMEFRAMES tf;   // Timeframe
    datetime lastBar;     // Last processed bar
    string name;          // TF name (M15/M30/etc)
};
```

### SignalConditions

Struktur kondisi sinyal:

```mql5
struct SignalConditions {
    bool maCrossUp;       // MA10 cross above MA200
    bool maCrossDown;     // MA10 cross below MA200
    bool trendChanged;    // Trend color changed
    bool adxBullish;      // DI+ > DI-
    bool adxBearish;      // DI- > DI+
    bool adxStrong;       // ADX > level
    bool diCrossUp;       // DI+ crossed above DI-
    bool diCrossDown;     // DI- crossed above DI+
    bool atSupport;       // Price at support
    bool atResistance;    // Price at resistance
    bool breakSupport;    // Price broke support
    bool breakResistance; // Price broke resistance
    bool rsiOversold;     // RSI <= 30 or near
    bool rsiOverbought;   // RSI >= 70 or near
    bool bullishEngulf;   // Bullish engulfing
    bool bearishEngulf;   // Bearish engulfing
    bool atSwingHigh;     // At recent high
    bool atSwingLow;      // At recent low
};
```

### RSIPivotData

Data pivot RSI untuk divergence:

```mql5
struct RSIPivotData {
    int bar;          // Bar index
    datetime time;    // Time
    double price;     // Price value
    double rsi;       // RSI value
    bool isHigh;      // Is pivot high?
};
```

### NewsEvent

Data event berita ekonomi:

```mql5
struct NewsEvent {
    datetime time;           // Event time
    string currency;         // Currency (USD, EUR, etc)
    string name;             // Event name
    ENUM_NEWS_IMPACT impact; // Impact level
    string actual;           // Actual value
    string forecast;         // Forecast value
    string previous;         // Previous value
    bool isPast;             // Already passed?
};
```

---

## 📊 Indicator Handles

### RSI Handles (Multi-Timeframe)

| Handle | Timeframe | Deskripsi |
|--------|-----------|-----------|
| `hRSI_M15` | M15 | RSI untuk timeframe M15 |
| `hRSI_M30` | M30 | RSI untuk timeframe M30 |
| `hRSI_H1` | H1 | RSI untuk timeframe H1 |
| `hRSI_H4` | H4 | RSI untuk timeframe H4 |
| `hRSI_D1` | D1 | RSI untuk timeframe D1 |
| `hRSI_Current` | Current | RSI untuk signal generator |

### Trend MA Handles

| Handle | Type | Period | Price |
|--------|------|--------|-------|
| `hMA200_HLC` | EMA | 200 | PRICE_TYPICAL (HLC/3) |
| `hMA10_HLC` | EMA | 10 | PRICE_TYPICAL (HLC/3) |

### Other Indicators

| Handle | Indicator | Usage |
|--------|-----------|-------|
| `hATR` | ATR | Untuk kalkulasi SL dinamis |
| `hADX` | ADX | Signal generator - trend strength & DI+/DI- |

---

## 🖥️ Trading Panel UI

### Layout 4-Column

Panel menggunakan layout 4 kolom dengan posisi di pojok kiri bawah chart:

| Col 0 | Col 1 | Col 2 | Col 3 |
|-------|-------|-------|-------|
| 🔵 Del Pending | 🔴 CLOSE ALL | Reset SL/TP | Break Even |
| 🟢 Close BUY | 🔴 Close SELL | Apply SL | Apply TP |
| BUY MART | SELL MART | Partial Profit | Partial Loss |
| BUY GRID | SELL GRID | LOT / GRID Controls | |
| 🟢 BUY 1x | 🔴 SELL 1x | | |

### Signal Panel

Panel sinyal HTF menampilkan data dari 5 timeframe dalam bentuk tabel:

|  | M15 | M30 | H1 | H4 | D1 |
|--|-----|-----|----|----|-----|
| **SnR** | Buy/Sell/Net/Break/Ret | Status posisi relatif terhadap S/R level |
| **RSI** | 0-100 | Nilai RSI dengan warna (Lime=Oversold, Red=Overbought) |
| **Div** | Bull/Bear/Net | Status divergence |

### Lot & Grid Controls

- **Lot Control:** [-] [Edit Box] [+] - Adjust lot size dengan step sesuai broker
- **Grid Control:** [-] [Edit Box] [+] pips - Adjust grid step (dalam Pips, dikonversi ke Points)

---

## 💹 Trading Functions

### OpenSingleOrder()

Membuka order market tunggal:

- Menggunakan `CurrentLot`
- Comment: "SETAN V2"
- Tanpa SL/TP awal

### OpenGridOrders()

Membuka grid orders dengan pending:

- Layer pertama: Market order
- Layer berikutnya: BuyLimit/SellLimit atau BuyStop/SellStop
- Jarak: `CurrentGridStep` (points)
- Martingale: Lot += `InpLotIncrement` per layer

### PartialClose()

Partial close posisi:

- `profitOnly=true`: Close hanya posisi profit
- `profitOnly=false`: Close hanya posisi loss
- Close volume: `InpPartialPercent`% dari volume

### ApplySL() / ApplyTP()

Aplikasi SL/TP ke semua posisi:

- **AUTO_ATR_SNR:** SL = Open ± (ATR × Multiplier), TP = SnR level terdekat
- **FIXED:** SL/TP = Fixed points dari input

### SetBreakEven()

Set break even untuk posisi profit:

- NewSL = OpenPrice + `InpBE_Lock` (Buy)
- NewSL = OpenPrice - `InpBE_Lock` (Sell)
- Hanya update jika SL baru lebih baik

### Close Functions

- `CloseAllPositions()` - Close semua posisi symbol
- `ClosePositionsByType()` - Close by position type
- `DeleteAllPendingOrders()` - Delete semua pending

---

## 📡 Signal Generator

### Scoring System

Signal dihasilkan berdasarkan akumulasi skor dari berbagai kondisi. **Minimum score: 5**

| Kondisi | Buy Score | Sell Score |
|---------|-----------|------------|
| MA Crossover / Trend Change | +2 | +2 |
| DI Crossover (dengan ADX Strong) | +2 | +2 |
| ADX Direction (DI+>DI- atau sebaliknya) | +1 | +1 |
| At Support / Break Resistance | +2 | - |
| At Resistance / Break Support | - | +2 |
| RSI Oversold | +1 | - |
| RSI Overbought | - | +1 |
| Bullish Engulfing | +2 | - |
| Bearish Engulfing | - | +2 |
| At Swing Low | +1 | - |
| At Swing High | - | +1 |

### Signal Output

- Jika `buyScore >= 5` dan `buyScore > sellScore` → 🟢 **BUY SIGNAL**
- Jika `sellScore >= 5` dan `sellScore > buyScore` → 🔴 **SELL SIGNAL**
- Arrow digambar di chart dengan label score
- Alert popup jika `InpSignalAlert=true`

### Historical Signal Scan

`ScanHistoricalSignals()` memindai 500 bar terakhir saat init untuk menampilkan sinyal historis (non-repainting).

---

## 📍 Support & Resistance

### Pivot Detection

- **Pivot High:** Bar dengan High tertinggi dalam range ±`SnR_Pivot_Period`
- **Pivot Low:** Bar dengan Low terendah dalam range ±`SnR_Pivot_Period`
- Preload dari `SnR_Look_Back` bar saat init

### S/R Zone Calculation

`CalculateSRZones()` mengelompokkan pivot points yang berdekatan:

1. Hitung `cwidth` = 10% dari range high-low 300 bar
2. Groupkan pivots dengan jarak < cwidth
3. Hitung rata-rata weighted untuk level zone
4. Sort by strength (jumlah pivots dalam zone)
5. Ambil top N level (max: `SnR_Max_Levels`)

### SnR Status

| Status | Kondisi | Return |
|--------|---------|--------|
| Breakout | Body candle cross level | 3 |
| Retest | Wick cross, body safe | 4 |
| At Support (Buy) | Close > level, jarak <= proximity | 1 |
| At Resistance (Sell) | Close < level, jarak <= proximity | 2 |
| Neutral | Tidak ada kondisi terpenuhi | 0 |

### S/R Line Display

Garis S/R ditampilkan dengan label yang menunjukkan:

- Price level
- Persentase jarak dari harga saat ini
- Jumlah Breakouts (B) dan Retests (R)

Format: `1.2345 (+0.5%) [B:3|R:5]`

---

## 🔀 RSI Divergence Detection

### Detection Logic

| Type | Price | RSI | Signal |
|------|-------|-----|--------|
| 🟢 **Bullish Divergence** | Lower Low | Higher Low | Potential reversal UP |
| 🔴 **Bearish Divergence** | Higher High | Lower High | Potential reversal DOWN |

### Implementation

1. `ScanDivergence()` memindai RSI pivots pada HTF yang dipilih
2. Pivot RSI dideteksi dengan left/right period = 5 bars
3. Price pivot dicari dalam range ±3 bar dari RSI pivot
4. Jika kondisi divergence terpenuhi, garis dan label digambar
5. Duplicate detection mencegah divergence yang sama digambar ulang

### Visual Elements

- **Trend Line:** Menghubungkan dua pivot points
- **Label:** "Bull" atau "Bear" di ujung garis
- Warna sesuai `InpDivBullColor` / `InpDivBearColor`

---

## 📰 News Filter System

### Currency Detection

`GetCurrenciesFromSymbol()` mengekstrak mata uang dari symbol:

- **Forex:** EURUSD → EUR, USD
- **Gold:** XAUUSD → XAU, USD, EUR
- **Silver:** XAGUSD → XAG, USD
- **Oil:** USOIL → USD, CAD
- **Crypto:** BTCUSD → USD

### MQL5 Calendar Integration

`FetchNewsEvents()` menggunakan MQL5 Calendar API:

- `CalendarValueHistory()` - Fetch events dalam range waktu
- `CalendarEventById()` - Get event details
- `CalendarCountryById()` - Get country/currency info
- Update interval: 5 menit

### News Panel Display

Menampilkan hingga 8 event berita dengan:

- 🔴🟠🟡 Impact icon berdasarkan level
- Time remaining (in Xm / -Xm ago)
- Currency code
- Event name (truncated 35 chars)

### News Alert

Alert popup untuk berita High Impact:

- Trigger: `InpNewsAlertMinutes` sebelum event
- Cooldown: 5 menit antara alerts
- Format: "⚠️ HIGH IMPACT NEWS in X minutes!"

---

## 🔧 Functions Reference

### Core Event Handlers

| Function | Deskripsi |
|----------|-----------|
| `OnInit()` | Inisialisasi EA, create indicators, panel, news system |
| `OnDeinit()` | Cleanup semua handles dan objects |
| `OnTick()` | Update timer, signals (on new bar), news (every 5 min) |
| `OnChartEvent()` | Handle button clicks dan edit box input |

### UI Functions

| Function | Deskripsi |
|----------|-----------|
| `CreatePanel()` | Create main trading panel |
| `CreateSignalPanel()` | Create HTF signal display panel |
| `CreateButton()` | Helper: Create styled button |
| `CreateLabel()` | Helper: Create styled label |
| `CreateLotGridControl()` | Create lot/grid input controls |
| `CreateWatermark()` | Create EA watermark label |
| `DarkenColor()` | Helper: Darken color by percentage |

### Signal Functions

| Function | Deskripsi |
|----------|-----------|
| `UpdateSignals()` | Update semua HTF signal displays |
| `CheckSignalConditions()` | Evaluate semua kondisi sinyal |
| `GenerateSignal()` | Calculate score dan generate signal |
| `DrawSignalArrow()` | Draw arrow dan label di chart |
| `UpdateSignalDisplay()` | Update panel signal display |
| `ScanHistoricalSignals()` | Scan dan draw historical signals |
| `CheckEngulfingPattern()` | Check bullish/bearish engulfing |
| `CheckSwingHL()` | Check if at swing high/low |

### S/R Functions

| Function | Deskripsi |
|----------|-----------|
| `UpdateSRLevels()` | Update S/R levels untuk SnRData |
| `DetectPivotHigh()` | Detect pivot high at timeframe |
| `DetectPivotLow()` | Detect pivot low at timeframe |
| `PreloadPivots()` | Preload historical pivots |
| `CalculateSRZones()` | Calculate S/R zones from pivots |
| `GetLevelCounts()` | Count breakouts dan retests |
| `DrawSRLines()` | Draw S/R lines dan labels |
| `GetSnRStatus()` | Get current SnR status |
| `UpdateSingleSnR()` | Update single SnR label |

### Trend MA Functions

| Function | Deskripsi |
|----------|-----------|
| `DrawTrendMALines()` | Draw MA lines dengan warna dinamis |
| `DrawMASegmentAtBar()` | Draw single MA segment |
| `DrawTrendSegment()` | Create/update trend line object |

### Divergence Functions

| Function | Deskripsi |
|----------|-----------|
| `ScanDivergence()` | Main divergence scan function |
| `DetectRSIPivotsAndDiv()` | Detect RSI pivots dan check divergence |
| `StoreAndCheckDiv()` | Store pivot dan check for divergence |
| `DrawDivOnChart()` | Draw divergence line dan label |
| `IsDivDrawn()` | Check if divergence already drawn |
| `RecordDiv()` | Record drawn divergence |
| `TimeDifferenceBars()` | Calculate bar difference between times |
| `GetDivergenceStatus()` | Get divergence status for panel |
| `UpdateSingleDivergence()` | Update single divergence label |

### News Functions

| Function | Deskripsi |
|----------|-----------|
| `InitializeNews()` | Initialize news system |
| `GetCurrenciesFromSymbol()` | Extract currencies from symbol |
| `IsRelatedCurrency()` | Check if currency is relevant |
| `FetchNewsEvents()` | Fetch from MQL5 Calendar |
| `SortNewsByTime()` | Sort events by time |
| `ConvertImpact()` | Convert calendar importance to enum |
| `CreateNewsPanel()` | Create news panel UI |
| `UpdateNewsDisplay()` | Update news items display |
| `CheckNewsAlerts()` | Check and trigger news alerts |
| `CleanupNews()` | Delete news objects |
| `GetImpactColor()` | Get color by impact level |
| `GetImpactIcon()` | Get emoji icon by impact |
| `FormatTimeRemaining()` | Format time until/since event |

### Utility Functions

| Function | Deskripsi |
|----------|-----------|
| `GetATR()` | Get current ATR value |
| `GetStrongestSnRLevel()` | Get nearest S/R for TP |
| `GetTFIndex()` | Get index dari tfList array |
| `GetActualHTF()` | Resolve PERIOD_CURRENT |
| `GetHTFName()` | Get HTF name string |
| `UpdateCandleTimer()` | Update candle countdown timer |
| `UpdateLotDisplay()` | Update lot edit box |
| `UpdateGridDisplay()` | Update grid edit box |
| `AdjustLot()` | Adjust lot by step |
| `AdjustGrid()` | Adjust grid by pips |
| `SetupChartAppearance()` | Configure chart colors/appearance |

---

## 📄 License

This Expert Advisor is proprietary software. Unauthorized copying, distribution, or modification is prohibited.

---

## 📞 Support

For support and inquiries, please contact the developer.

---

<div align="center">

**◆ TUYUL BIRU V2.0 Documentation ◆**

*Generated: 2026-01-01 | Total Lines: 3408 | File Size: ~126KB*

</div>
