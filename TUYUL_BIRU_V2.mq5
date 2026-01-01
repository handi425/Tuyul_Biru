//+------------------------------------------------------------------+
//|                                                 SETAN_EA_V2.mq5 |
//|         Manual Trading Panel with HTF Signals (SnR, RSI)       |
//+------------------------------------------------------------------+
#property copyright "TUYUL BIRU"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//--- Enums
enum ENUM_SLTP_MODE
{
   SLTP_MODE_FIXED,        // Fixed Points
   SLTP_MODE_AUTO_ATR_SNR, // Auto (SL=ATR, TP=SnR)
   SLTP_MODE_MARTINGALE      // Martingale Logic (Reserved)
};

struct SnRData
{
   double pivots[];
   double levels[];
   ENUM_TIMEFRAMES tf;
   datetime lastBar;
   string name;
};

//--- Magic Number
#define EA_MAGIC_NUMBER 666777

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== HTF Signal Settings ==="
input ENUM_TIMEFRAMES HTF_Timeframe  = PERIOD_H1;   // HTF for Signals (SnR, RSI)
input int      RSI_Period          = 14;            // RSI Period
input int      RSI_Overbought      = 70;            // RSI Overbought Level
input int      RSI_Oversold        = 30;            // RSI Oversold Level
input int      RSI_Div_Lookback    = 30;            // RSI Divergence Lookback
input bool     InpDrawDivLines     = true;          // Draw Divergence Lines
input color    InpDivBullColor     = clrLime;       // Bullish Div Color
input color    InpDivBearColor     = clrRed;        // Bearish Div Color

input group "=== SnR Settings ==="
input int      SnR_Pivot_Period    = 10;            // Pivot Period (bars left/right)
input int      SnR_Max_Levels      = 10;            // Max S/R Levels
input double   SnR_Proximity       = 50;            // Proximity to S/R (points)
input int      SnR_Look_Back       = 500;
input color    SnR_Support_Color   = clrLime;       // Support Color
input color    SnR_Resistance_Color= clrRed;        // Resistance Color

input group "=== Entry Settings ==="
input double   InpDefaultLot       = 0.01;          // Default Lot Size
input double   InpLotIncrement     = 0.01;          // Martingale Lot Increment
input int      InpGridStep         = 200;           // Default Grid Step (points)
input int      InpGridLayers       = 5;             // Grid Layers Count

input group "=== Risk & Management ==="
input ENUM_SLTP_MODE InpSLTPMode = SLTP_MODE_AUTO_ATR_SNR; // SL/TP Mode
input int      InpFixedSL          = 500;           // Fixed SL (Points)
input int      InpFixedTP          = 1000;          // Fixed TP (Points)
input int      InpATR_Period       = 14;            // ATR Period (for SL)
input double   InpATR_Multiplier   = 1.5;           // ATR Multiplier (for SL)
input double   InpPartialPercent   = 50.0;          // Partial Close %
input int      InpBE_Lock          = 50;            // Break Even Lock (Points)

input group "=== Trend MA Settings ==="
input bool     InpShowTrendMA      = true;          // Show Trend MA Lines
input int      InpTrendMA_Slow     = 200;           // Slow MA Period (200)
input int      InpTrendMA_Fast     = 10;            // Fast MA Period (10)
input color    InpTrendBullColor   = clrLime;       // Bullish Trend Color
input color    InpTrendBearColor   = clrRed;        // Bearish Trend Color
input int      InpTrendMA_Width    = 2;             // MA Line Width

input group "=== Signal Generator Settings ==="
input bool     InpEnableSignal     = true;          // Enable Signal Generator
input int      InpADX_Period       = 14;            // ADX Period
input int      InpADX_Level        = 20;            // ADX Minimum Level
input int      InpRSI_NearLevel    = 5;             // RSI Near OB/OS Tolerance
input bool     InpShowSignalArrow  = true;          // Show Signal Arrows
input bool     InpSignalAlert      = true;          // Enable Signal Alert

input group "=== News Filter Settings ==="
input bool     InpEnableNews       = true;          // Enable News Detection
input bool     InpNewsAlert        = true;          // Alert Before High Impact News
input int      InpNewsAlertMinutes = 30;            // Alert Minutes Before News
input int      InpNewsLookAhead    = 24;            // Look Ahead Hours
input int      InpNewsLookBack     = 2;             // Look Back Hours (Recent News)
input bool     InpShowLowImpact    = false;         // Show Low Impact News
input bool     InpShowMediumImpact = true;          // Show Medium Impact News
input bool     InpShowHighImpact   = true;          // Show High Impact News
input color    InpNewsHighColor    = clrRed;        // High Impact Color
input color    InpNewsMediumColor  = clrOrange;     // Medium Impact Color
input color    InpNewsLowColor     = clrYellow;     // Low Impact Color

input group "=== Appearance ==="
input color    TextColor           = clrWhite;      // Text Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;

// Panel Position
int panelX = 10;
int panelY = 35;
int btnWidth = 95;
int btnHeight = 28;
int gapY = 32;

// Indicator Handles
int hRSI_M15 = INVALID_HANDLE;
int hRSI_M30 = INVALID_HANDLE;
int hRSI_H1 = INVALID_HANDLE;
int hRSI_H4 = INVALID_HANDLE;
int hRSI_D1 = INVALID_HANDLE;
int hATR = INVALID_HANDLE;

// Trend MA Handles (MA200 and MA10 with HLC/3 only - optimized)
int hMA200_HLC = INVALID_HANDLE;
int hMA10_HLC = INVALID_HANDLE;

// ADX Handle for Signal Generation
int hADX = INVALID_HANDLE;
int hRSI_Current = INVALID_HANDLE;  // RSI for current TF

// Trend State: 1 = Bullish (Green), -1 = Bearish (Red), 0 = Neutral
int TrendState = 0;
int PrevTrendState = 0;  // For detecting trend change

// Signal Structure
struct SignalConditions
{
   bool maCrossUp;        // MA10 crossed above MA200
   bool maCrossDown;      // MA10 crossed below MA200
   bool trendChanged;     // Trend line color changed
   bool adxBullish;       // DI+ > DI-
   bool adxBearish;       // DI- > DI+
   bool adxStrong;        // ADX > level
   bool diCrossUp;        // DI+ crossed above DI-
   bool diCrossDown;      // DI- crossed above DI+
   bool atSupport;        // Price at support
   bool atResistance;     // Price at resistance
   bool breakSupport;     // Price broke support
   bool breakResistance;  // Price broke resistance
   bool rsiOversold;      // RSI <= 30 or near
   bool rsiOverbought;    // RSI >= 70 or near
   bool bullishEngulf;    // Bullish engulfing
   bool bearishEngulf;    // Bearish engulfing
   bool atSwingHigh;      // At recent high
   bool atSwingLow;       // At recent low
};

SignalConditions sigCond;
int LastSignal = 0;  // 1=Buy, -1=Sell, 0=None
datetime LastSignalTime = 0;

// S/R Arrays
// S/R Data
SnRData snrList[5];

// --- DIVERGENCE STRUCTURES ---
struct RSIPivotData
{
   int      bar;
   datetime time;
   double   price;
   double   rsi;
   bool     isHigh;
};

struct DrawnDivergence
{
   datetime time1;       // First pivot time
   datetime time2;       // Second pivot time (where signal appears)
   bool     isBullish;
};

// Global Divergence Storage (Per Timeframe is better, but for now we focus on HTF or Current?)
// The user request implies "show feature", usually on the current chart. 
// BUT the EA monitors 5 TFs. Drawing on M1 chart for H1 signals is tricky.
// We will DRAW ONLY on the CURRENT CHART (Active TF) matching existing pattern of monitoring.
// Or should we draw for the specific HTF? The user said "tampilkan juga signal".
// Given it's an EA running on one chart, we usually visualize only for the *Chart Timeframe* or the *HTF*.
// Let's implement for the *HTF_Timeframe* defined in inputs, as that's what controls the signals.

RSIPivotData rsiPipsHigh[];
RSIPivotData rsiPipsLow[];
DrawnDivergence drawnDivs[];
int rsi_pivot_right = 5; // SnR_MT5 default
int rsi_pivot_left = 5;  // SnR_MT5 default

// Map TFs for easy loop
ENUM_TIMEFRAMES tfList[5] = {PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
string tfNames[5] = {"M15", "M30", "H1", "H4", "D1"};

// Current Settings (editable on panel)
double CurrentLot = 0.01;
int CurrentGridStep = 200;
double LotStep = 0.01;
double MinLot = 0.01;
double MaxLot = 100.0;

// Object Names
string ObjSignalBG = "SignalBG";
string ObjSignalTitle = "SignalTitle";
string ObjSignalSnR_M15 = "SignalSnR_M15";
string ObjSignalSnR_M30 = "SignalSnR_M30";
string ObjSignalSnR_H1 = "SignalSnR_H1";
string ObjSignalSnR_H4 = "SignalSnR_H4";
string ObjSignalSnR_D1 = "SignalSnR_D1";
string ObjSignalRSI_M15 = "SignalRSI_M15";
string ObjSignalRSI_M30 = "SignalRSI_M30";
string ObjSignalRSI_H1 = "SignalRSI_H1";
string ObjSignalRSI_H4 = "SignalRSI_H4";
string ObjSignalRSI_D1 = "SignalRSI_D1";
string ObjSignalDiv_M15 = "SignalDiv_M15";
string ObjSignalDiv_M30 = "SignalDiv_M30";
string ObjSignalDiv_H1 = "SignalDiv_H1";
string ObjSignalDiv_H4 = "SignalDiv_H4";
string ObjSignalDiv_D1 = "SignalDiv_D1";

// Signal Generator Display
string ObjMainSignal = "MainSignal";
string ObjSignalScore = "SignalScore";
string ObjLotLabel = "LotLabel";
string ObjLotEdit = "LotEdit";
string ObjLotMinus = "LotMinus";
string ObjLotPlus = "LotPlus";
string ObjGridLabel = "GridLabel";
string ObjGridEdit = "GridEdit";
string ObjGridMinus = "GridMinus";
string ObjGridPlus = "GridPlus";
string ObjWatermark = "Watermark";
string ObjCandleTimer = "CandleTimer";

// New Buttons
string ObjBtnPartialProf = "BtnPartialProf";
string ObjBtnPartialLoss = "BtnPartialLoss";
string ObjBtnApplySL = "BtnApplySL";
string ObjBtnApplyTP = "BtnApplyTP";
string ObjBtnReset = "BtnReset";
string ObjBtnBE = "BtnBE";

//+------------------------------------------------------------------+
//| NEWS DATA STRUCTURES                                              |
//+------------------------------------------------------------------+
enum ENUM_NEWS_IMPACT
{
   NEWS_IMPACT_NONE = 0,
   NEWS_IMPACT_LOW = 1,
   NEWS_IMPACT_MEDIUM = 2,
   NEWS_IMPACT_HIGH = 3
};

struct NewsEvent
{
   datetime          time;
   string            currency;
   string            name;
   ENUM_NEWS_IMPACT  impact;
   string            actual;
   string            forecast;
   string            previous;
   bool              isPast;
};

// News Global Variables
NewsEvent g_NewsEvents[];
string    g_FilterCurrencies[];
datetime  g_LastNewsUpdate = 0;
int       g_NewsUpdateInterval = 300;  // Update every 5 minutes
string    ObjNewsBG = "NewsBG";
string    ObjNewsTitle = "NewsTitle";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetDeviationInPoints(30);
   
   // Initialize settings
   CurrentLot = InpDefaultLot;
   CurrentGridStep = InpGridStep;
   LotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   MinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   MaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   // Initialize indicators (on HTF)
   hRSI_M15 = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   hRSI_M30 = iRSI(_Symbol, PERIOD_M30, RSI_Period, PRICE_CLOSE);
   hRSI_H1  = iRSI(_Symbol, PERIOD_H1,  RSI_Period, PRICE_CLOSE);
   hRSI_H4  = iRSI(_Symbol, PERIOD_H4,  RSI_Period, PRICE_CLOSE);
   hRSI_D1  = iRSI(_Symbol, PERIOD_D1,  RSI_Period, PRICE_CLOSE);
   
   if(hRSI_M15 == INVALID_HANDLE || hRSI_M30 == INVALID_HANDLE) return INIT_FAILED;

   hATR = iATR(_Symbol, HTF_Timeframe, InpATR_Period);
   
   // Initialize Trend MA handles (HLC/3 only - optimized for performance)
   if(InpShowTrendMA || InpEnableSignal)
   {
      // MA 200 & MA 10: HLC/3 only
      hMA200_HLC = iMA(_Symbol, PERIOD_CURRENT, InpTrendMA_Slow, 0, MODE_EMA, PRICE_TYPICAL);
      hMA10_HLC  = iMA(_Symbol, PERIOD_CURRENT, InpTrendMA_Fast, 0, MODE_EMA, PRICE_TYPICAL);
      
      if(hMA200_HLC == INVALID_HANDLE || hMA10_HLC == INVALID_HANDLE)
      {
         Print("Error creating Trend MA handles");
         return INIT_FAILED;
      }
   }
   
   // Initialize Signal Generator indicators
   if(InpEnableSignal)
   {
      hADX = iADX(_Symbol, PERIOD_CURRENT, InpADX_Period);
      hRSI_Current = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
      
      if(hADX == INVALID_HANDLE || hRSI_Current == INVALID_HANDLE)
      {
         Print("Error creating Signal indicators (ADX/RSI)");
         return INIT_FAILED;
      }
   }
   
   // Initialize S/R arrays
   for(int i=0; i<5; i++)
   {
      ArrayResize(snrList[i].pivots, 0);
      ArrayResize(snrList[i].levels, 0);
      snrList[i].tf = tfList[i];
      snrList[i].name = tfNames[i];
      snrList[i].lastBar = 0;
      
      // Preload
      PreloadPivots(snrList[i]);
   }
   
   // Create UI Panel
   CreatePanel();
   
   // Initialize News System
   InitializeNews();
   
   // Setup Chart Appearance
   SetupChartAppearance();
   
   Print("TUYUL BIRU initialized. HTF: ", EnumToString(HTF_Timeframe));
   
   // Initial Scan for Divergence on HTF
   ScanDivergence(HTF_Timeframe, 300);
   
   // Scan Historical Signals (on init)
   if(InpEnableSignal && InpShowSignalArrow)
   {
      ScanHistoricalSignals(500);  // Scan last 100 bars
   }
   
   ChartRedraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(hRSI_M15 != INVALID_HANDLE) IndicatorRelease(hRSI_M15);
   if(hRSI_M30 != INVALID_HANDLE) IndicatorRelease(hRSI_M30);
   if(hRSI_H1 != INVALID_HANDLE)  IndicatorRelease(hRSI_H1);
   if(hRSI_H4 != INVALID_HANDLE)  IndicatorRelease(hRSI_H4);
   if(hRSI_D1 != INVALID_HANDLE)  IndicatorRelease(hRSI_D1);

   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   
   // Release Trend MA handles
   if(hMA200_HLC != INVALID_HANDLE) IndicatorRelease(hMA200_HLC);
   if(hMA10_HLC != INVALID_HANDLE) IndicatorRelease(hMA10_HLC);
   
   // Release Signal Generator handles
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hRSI_Current != INVALID_HANDLE) IndicatorRelease(hRSI_Current);
   
   // Delete Signal objects
   ObjectsDeleteAll(0, "SigArrow_");
   ObjectsDeleteAll(0, "SigLbl_");
   ObjectDelete(0, ObjMainSignal);
   ObjectDelete(0, ObjSignalScore);
   
   // Delete Trend MA lines
   ObjectsDeleteAll(0, "TrendMA_");
   
   // Delete all panel objects
   ObjectsDeleteAll(0, "Signal");
   ObjectsDeleteAll(0, "Btn");
   ObjectsDeleteAll(0, "Lot");
   ObjectsDeleteAll(0, "Grid");
   ObjectsDeleteAll(0, "SR_");
   ObjectsDeleteAll(0, "Row_");
   ObjectsDeleteAll(0, "Head_");
   ObjectDelete(0, "SignalBG_Shadow");
   ObjectDelete(0, "SignalBG_Accent");
   ObjectDelete(0, "SignalBG_Inner");
   
   // Release SnR if handles were used? No handles for pivoting.
   ObjectDelete(0, ObjWatermark);
   ObjectDelete(0, ObjCandleTimer);
   
   // Cleanup News objects
   CleanupNews();
   
   // Delete Div Objects
   ObjectsDeleteAll(0, "DIV_");
   ObjectsDeleteAll(0, "DIVLBL_");
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Static variables for optimization
   static datetime lastBarTime = 0;
   static datetime lastMAUpdateTime = 0;
   static bool maInitialized = false;
   static ENUM_TIMEFRAMES lastTF = PERIOD_CURRENT;
   
   // Detect timeframe change - reset initialization
   ENUM_TIMEFRAMES currentTF = Period();
   if(currentTF != lastTF)
   {
      lastTF = currentTF;
      lastBarTime = 0;
      maInitialized = false;  // Force full redraw of MA
      
      // Update HTF label on panel (for PERIOD_CURRENT mode)
      if(HTF_Timeframe == PERIOD_CURRENT)
      {
         ObjectSetString(0, "HTF_Selected", OBJPROP_TEXT, "[" + GetHTFName() + "]");
      }
   }
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   // Update candle timer on every tick (lightweight)
   UpdateCandleTimer();
   
   // === NEWS UPDATE (Every 5 minutes) ===
   if(InpEnableNews)
   {
      static datetime lastNewsCheck = 0;
      if(TimeCurrent() - lastNewsCheck >= g_NewsUpdateInterval)
      {
         lastNewsCheck = TimeCurrent();
         FetchNewsEvents();
         UpdateNewsDisplay();
         CheckNewsAlerts();
      }
   }
   
   // === HEAVY OPERATIONS: Only on NEW BAR ===
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
      
      // Update signals (on new bar only)
      UpdateSignals();
      
      // Draw Trend MA Lines (on new bar only)
      if(InpShowTrendMA)
      {
         if(!maInitialized)
         {
            DrawTrendMALines(true);  // Full redraw on first run
            maInitialized = true;
         }
         else
         {
            DrawTrendMALines(false); // Incremental update
         }
      }
      
      // Update S/R levels on new bar for each HTF
      for(int i=0; i<5; i++)
      {
         datetime htfBar = iTime(_Symbol, snrList[i].tf, 0);
         if(htfBar != snrList[i].lastBar)
         {
            snrList[i].lastBar = htfBar;
            UpdateSRLevels(snrList[i]);
         }
      }
      
      // Check for Buy/Sell Signal (on new bar)
      if(InpEnableSignal)
      {
         CheckSignalConditions();
         int signal = GenerateSignal();
         UpdateSignalDisplay(signal);
      }
      
      // Scan Divergence on New Bar (Main HTF)
      static datetime lastDivTime = 0;
      static bool firstRunComplete = false;
      
      if(!firstRunComplete) {
         ScanDivergence(HTF_Timeframe, 1000); 
         if(Bars(_Symbol, HTF_Timeframe) > 500) firstRunComplete = true;
      }
      
      datetime currHTFTime = iTime(_Symbol, HTF_Timeframe, 0);
      if(currHTFTime != lastDivTime)
      {
         lastDivTime = currHTFTime;
         ScanDivergence(HTF_Timeframe, 25);
      }
      
      // Single ChartRedraw at the end of new bar processing
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // BUY Buttons
      if(sparam == "BtnBuy1x") { PlaySound("ok.wav"); OpenSingleOrder(ORDER_TYPE_BUY); }
      else if(sparam == "BtnBuyGrid") { PlaySound("ok.wav"); OpenGridOrders(ORDER_TYPE_BUY, false); }
      else if(sparam == "BtnBuyMart") { PlaySound("ok.wav"); OpenGridOrders(ORDER_TYPE_BUY, true); }
      
      // SELL Buttons
      else if(sparam == "BtnSell1x") { PlaySound("ok.wav"); OpenSingleOrder(ORDER_TYPE_SELL); }
      else if(sparam == "BtnSellGrid") { PlaySound("ok.wav"); OpenGridOrders(ORDER_TYPE_SELL, false); }
      else if(sparam == "BtnSellMart") { PlaySound("ok.wav"); OpenGridOrders(ORDER_TYPE_SELL, true); }
      
      // Close Buttons
      else if(sparam == "BtnCloseAll") { PlaySound("alert.wav"); CloseAllPositions(); }
      else if(sparam == "BtnCloseBuy") { PlaySound("alert.wav"); ClosePositionsByType(POSITION_TYPE_BUY); }
      else if(sparam == "BtnCloseSell") { PlaySound("alert.wav"); ClosePositionsByType(POSITION_TYPE_SELL); }
      else if(sparam == "BtnDeletePending") { PlaySound("alert.wav"); DeleteAllPendingOrders(); }
      
      // Advanced Buttons
      else if(sparam == ObjBtnPartialProf) { PlaySound("tick.wav"); PartialClose(true); }
      else if(sparam == ObjBtnPartialLoss) { PlaySound("tick.wav"); PartialClose(false); }
      else if(sparam == ObjBtnApplySL) { PlaySound("tick.wav"); ApplySL(); }
      else if(sparam == ObjBtnApplyTP) { PlaySound("tick.wav"); ApplyTP(); }
      else if(sparam == ObjBtnReset) { PlaySound("tick.wav"); ResetSLTP(); }
      else if(sparam == ObjBtnBE) { PlaySound("tick.wav"); SetBreakEven(); }
      
      // Lot Control
      else if(sparam == ObjLotPlus) { PlaySound("tick.wav"); AdjustLot(LotStep); }
      else if(sparam == ObjLotMinus) { PlaySound("tick.wav"); AdjustLot(-LotStep); }
      
      // Grid Control
      else if(sparam == ObjGridPlus) { PlaySound("tick.wav"); AdjustGrid(5); } // Step 5 pips
      else if(sparam == ObjGridMinus) { PlaySound("tick.wav"); AdjustGrid(-5); }
      
      // Reset button state
      if(StringFind(sparam, "Btn") >= 0)
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
   }
   
   // Handle Edit box input
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == ObjLotEdit)
      {
         string inputText = ObjectGetString(0, ObjLotEdit, OBJPROP_TEXT);
         double newLot = StringToDouble(inputText);
         if(newLot >= MinLot && newLot <= MaxLot)
            CurrentLot = NormalizeDouble(newLot, 2);
         UpdateLotDisplay();
      }
      else if(sparam == ObjGridEdit)
      {
         string inputText = ObjectGetString(0, ObjGridEdit, OBJPROP_TEXT);
         int newGridPips = (int)StringToInteger(inputText);
         if(newGridPips >= 1 && newGridPips <= 1000)
            CurrentGridStep = newGridPips * 10; // Convert Pips to Points (assuming 1 pip = 10 pts)
         UpdateGridDisplay();
      }
   }
}

//+------------------------------------------------------------------+
//| CREATE PANEL UI                                                   |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int row = 0;
   
   // --- SIGNAL DISPLAY SECTION ---
   // Signal panel needs to be higher due to more rows, or positioned absolutely
   CreateSignalPanel();
   
   // --- LEFT COLUMN (Execution) ---
   // Row 0: Del Pending & Close All (Bottom)
   CreateButton("BtnDeletePending", "Del Pending", 0, row, clrChocolate);
   CreateButton("BtnCloseAll", "CLOSE ALL", 1, row, clrRed);
   row++;
   
   // Row 1: Close Buy & Close Sell
   CreateButton("BtnCloseBuy", "Close BUY", 0, row, clrForestGreen);
   CreateButton("BtnCloseSell", "Close SELL", 1, row, clrFireBrick);
   row++;
   
   // Row 2: Martingale Entry
   CreateButton("BtnBuyMart", "BUY MART", 0, row, clrNavy);
   CreateButton("BtnSellMart", "SELL MART", 1, row, clrMaroon);
   row++;
   
   // Row 3: Grid Entry
   CreateButton("BtnBuyGrid", "BUY GRID", 0, row, clrDarkBlue);
   CreateButton("BtnSellGrid", "SELL GRID", 1, row, clrDarkRed);
   row++;
   
   // Row 4: Single Entry
   CreateButton("BtnBuy1x", "BUY 1x", 0, row, clrDodgerBlue);
   CreateButton("BtnSell1x", "SELL 1x", 1, row, clrOrangeRed);
   
   // --- RIGHT COLUMN (Controls & Advanced) ---
   // Reset row counter for Right Side? No, use explicit rows or offset.
   // We'll use columns 2 and 3.
   
   row = 0; // Reset row for alignment with Left Side bottom? 
   // User wants Reset/BE at bottom right? 
   // Usually alignment is better if bottom rows match.
   
   // Row 0: Reset & BE
   CreateButton(ObjBtnReset, "Reset SL/TP", 2, row, clrDimGray);
   CreateButton(ObjBtnBE, "Break Even", 3, row, clrGoldenrod);
   row++;
   
   // Row 1: Apply SL & TP
   CreateButton(ObjBtnApplySL, "Apply SL", 2, row, clrSteelBlue);
   CreateButton(ObjBtnApplyTP, "Apply TP", 3, row, clrSteelBlue);
   row++;
   
   // Row 2: Partial Close
   CreateButton(ObjBtnPartialProf, "Partial Profit", 2, row, clrTeal);
   CreateButton(ObjBtnPartialLoss, "Partial Loss", 3, row, clrSienna);
   row++;
   
   // Row 3: LOT & GRID CONTROL (Above advanced buttons)
   CreateLotGridControl(row);
   
   // Watermark
   CreateWatermark(row + 3); 
}

//+------------------------------------------------------------------+
//| CREATE SIGNAL PANEL - MODERN DESIGN                               |
//+------------------------------------------------------------------+
void CreateSignalPanel()
{
   double signalRow = 7;  // Above buttons
   
   // Base Y position (Top of the signal area)
   int topY = panelY + (int)(signalRow * gapY) + 30; 
   int panelWidth = btnWidth * 4 + 15;
   int panelHeight = 175;
   int panelYPos = panelY + (int)(signalRow * gapY) + 85;
   
   // === OUTER GLOW / SHADOW EFFECT ===
   string objShadow = "SignalBG_Shadow";
   if(ObjectFind(0, objShadow) < 0)
   {
      ObjectCreate(0, objShadow, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objShadow, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objShadow, OBJPROP_XDISTANCE, panelX + 3);
      ObjectSetInteger(0, objShadow, OBJPROP_YDISTANCE, panelYPos - 3);
      ObjectSetInteger(0, objShadow, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, objShadow, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, objShadow, OBJPROP_BGCOLOR, C'10,10,15');
      ObjectSetInteger(0, objShadow, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objShadow, OBJPROP_BORDER_COLOR, C'10,10,15');
      ObjectSetInteger(0, objShadow, OBJPROP_ZORDER, -2);
   }
   
   // === MAIN BACKGROUND (Semi-transparent dark) ===
   if(ObjectFind(0, ObjSignalBG) < 0)
   {
      ObjectCreate(0, ObjSignalBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_YDISTANCE, panelYPos);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_BGCOLOR, C'15,20,30');  // Dark blue-gray
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_BORDER_COLOR, C'60,80,120');  // Blue-ish border
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, ObjSignalBG, OBJPROP_ZORDER, -1);
   }
   
   // === TOP ACCENT LINE (Gradient effect) ===
   string objAccent = "SignalBG_Accent";
   if(ObjectFind(0, objAccent) < 0)
   {
      ObjectCreate(0, objAccent, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objAccent, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objAccent, OBJPROP_XDISTANCE, panelX + 1);
      ObjectSetInteger(0, objAccent, OBJPROP_YDISTANCE, panelYPos - 1);
      ObjectSetInteger(0, objAccent, OBJPROP_XSIZE, panelWidth - 2);
      ObjectSetInteger(0, objAccent, OBJPROP_YSIZE, 3);
      ObjectSetInteger(0, objAccent, OBJPROP_BGCOLOR, C'0,150,255');  // Cyan accent
      ObjectSetInteger(0, objAccent, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objAccent, OBJPROP_BORDER_COLOR, C'0,150,255');
      ObjectSetInteger(0, objAccent, OBJPROP_ZORDER, 1);
   }
   
   // === INNER HIGHLIGHT (subtle) ===
   string objInner = "SignalBG_Inner";
   if(ObjectFind(0, objInner) < 0)
   {
      ObjectCreate(0, objInner, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objInner, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objInner, OBJPROP_XDISTANCE, panelX + 2);
      ObjectSetInteger(0, objInner, OBJPROP_YDISTANCE, panelYPos - 5);
      ObjectSetInteger(0, objInner, OBJPROP_XSIZE, panelWidth - 4);
      ObjectSetInteger(0, objInner, OBJPROP_YSIZE, panelHeight - 8);
      ObjectSetInteger(0, objInner, OBJPROP_BGCOLOR, C'20,28,42');  // Slightly lighter
      ObjectSetInteger(0, objInner, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objInner, OBJPROP_BORDER_COLOR, C'35,45,65');
      ObjectSetInteger(0, objInner, OBJPROP_ZORDER, 0);
   }
   
   int yPos = topY;
   
   // 1. Title with icon-like prefix
   CreateLabel(ObjSignalTitle, "⚡ HTF SIGNALS", panelX + 10, yPos, C'0,200,255', 10);
   ObjectSetInteger(0, ObjSignalTitle, OBJPROP_ZORDER, 20);  // Ensure on top
   
   // Show selected HTF beside title
   string htfName = GetHTFName();
   string htfLblName = "HTF_Selected";
   if(ObjectFind(0, htfLblName) < 0)
   {
      ObjectCreate(0, htfLblName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, htfLblName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   }
   ObjectSetInteger(0, htfLblName, OBJPROP_XDISTANCE, panelX + 125);
   ObjectSetInteger(0, htfLblName, OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, htfLblName, OBJPROP_TEXT, "[" + htfName + "]");
   ObjectSetInteger(0, htfLblName, OBJPROP_COLOR, C'255,200,0');
   ObjectSetInteger(0, htfLblName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, htfLblName, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, htfLblName, OBJPROP_ZORDER, 20);  // Higher z-order to be on top
   ObjectSetInteger(0, htfLblName, OBJPROP_BACK, false);  // Ensure not background
   yPos -= 25;
   
   // 2. TABLE HEADERS
   int colHeaderX = panelX + 60; 
   int colStep = 65;
   
   string headers[] = {"M15", "M30", "H1", "H4", "D1"};
   for(int i=0; i<5; i++)
   {
      string hName = "Head_" + headers[i];
      CreateLabel(hName, headers[i], colHeaderX + (i*colStep), yPos, clrWhite, 8);
   }
   yPos -= 20;
   
   // 3. SnR ROW
   CreateLabel("Row_SnR", "SnR:", panelX + 10, yPos, clrSilver, 8);
   CreateLabel(ObjSignalSnR_M15, "--", colHeaderX + (0*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalSnR_M30, "--", colHeaderX + (1*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalSnR_H1,  "--", colHeaderX + (2*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalSnR_H4,  "--", colHeaderX + (3*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalSnR_D1,  "--", colHeaderX + (4*colStep), yPos, clrGray, 8);
   yPos -= 20;
   
   // 5. RSI ROW
   CreateLabel("Row_RSI", "RSI:", panelX + 10, yPos, clrSilver, 8);
   CreateLabel(ObjSignalRSI_M15, "--", colHeaderX + (0*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalRSI_M30, "--", colHeaderX + (1*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalRSI_H1,  "--", colHeaderX + (2*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalRSI_H4,  "--", colHeaderX + (3*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalRSI_D1,  "--", colHeaderX + (4*colStep), yPos, clrGray, 8);
   yPos -= 20;

   // 6. DIVERGENCE ROW
   CreateLabel("Row_Div", "Div:", panelX + 10, yPos, clrSilver, 8);
   CreateLabel(ObjSignalDiv_M15, "--", colHeaderX + (0*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalDiv_M30, "--", colHeaderX + (1*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalDiv_H1,  "--", colHeaderX + (2*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalDiv_H4,  "--", colHeaderX + (3*colStep), yPos, clrGray, 8);
   CreateLabel(ObjSignalDiv_D1,  "--", colHeaderX + (4*colStep), yPos, clrGray, 8);
}

//+------------------------------------------------------------------+
//| CREATE LOT & GRID CONTROL                                         |
//+------------------------------------------------------------------+
void CreateLotGridControl(int row)
{
   int yPos = panelY + (row * gapY);
   int colLOT = 2; // Column 2 for Lot
   int colGRID = 3; // Column 3 for Grid
   
   int xLot = panelX + (colLOT * (btnWidth + 5));
   int xGrid = panelX + (colGRID * (btnWidth + 5));
   
   int btnSmall = 20;
   
   // --- LOT CONTROL (Column 2) ---
   // Label "LOT"
   // CreateLabel(ObjLotLabel, "LOT:", xLot, yPos+15, clrYellow, 8); // Offset Y? Label logic uses simple y.
   // Buttons take full row height. Label might need to be small or overlay.
   // Let's put Edit Box centrally, with +/- on sides.
   // Or Label above? "di atasnya ada isian lot dan grid"
   // Maybe user means Lot/Grid inputs are ABOVE the partial buttons. Yes, that's what I did (Row 3).
   // Layout: [-] [ 0.01 ] [+]
   
   ObjectDelete(0, ObjLotLabel); // Remove label if exists, replacing with intuitive controls
   
   // Minus
   if(ObjectFind(0, ObjLotMinus) < 0) {
      ObjectCreate(0, ObjLotMinus, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_XDISTANCE, xLot);
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_XSIZE, btnSmall);
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_YSIZE, btnHeight);
      ObjectSetString(0, ObjLotMinus, OBJPROP_TEXT, "-");
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, ObjLotMinus, OBJPROP_COLOR, clrWhite);
   }
   
   // Edit
   if(ObjectFind(0, ObjLotEdit) < 0) {
      ObjectCreate(0, ObjLotEdit, OBJ_EDIT, 0, 0, 0);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_XDISTANCE, xLot + btnSmall + 1);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_XSIZE, 50);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_YSIZE, btnHeight);
      ObjectSetString(0, ObjLotEdit, OBJPROP_TEXT, DoubleToString(CurrentLot, 2));
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, ObjLotEdit, OBJPROP_ALIGN, ALIGN_CENTER);
   }
   
   // Plus
   if(ObjectFind(0, ObjLotPlus) < 0) {
      ObjectCreate(0, ObjLotPlus, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_XDISTANCE, xLot + btnSmall + 50 + 2);
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_XSIZE, btnSmall);
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_YSIZE, btnHeight);
      ObjectSetString(0, ObjLotPlus, OBJPROP_TEXT, "+");
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, ObjLotPlus, OBJPROP_COLOR, clrWhite);
   }
   
   // --- GRID CONTROL (Column 3) ---
   // Layout: [-] [ Edit ] [+] (Pips)
   
   ObjectDelete(0, ObjGridLabel); 
   
   // Minus
   if(ObjectFind(0, ObjGridMinus) < 0) {
      ObjectCreate(0, ObjGridMinus, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_XDISTANCE, xGrid);
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_XSIZE, btnSmall);
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_YSIZE, btnHeight);
      ObjectSetString(0, ObjGridMinus, OBJPROP_TEXT, "-");
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, ObjGridMinus, OBJPROP_COLOR, clrWhite);
   }

   // Edit
   if(ObjectFind(0, ObjGridEdit) < 0) {
      ObjectCreate(0, ObjGridEdit, OBJ_EDIT, 0, 0, 0);
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_XDISTANCE, xGrid + btnSmall + 1);
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_XSIZE, 45); // S slightly smaller
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_YSIZE, btnHeight);
      int pips = CurrentGridStep / 10;
      ObjectSetString(0, ObjGridEdit, OBJPROP_TEXT, IntegerToString(pips));
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, ObjGridEdit, OBJPROP_ALIGN, ALIGN_CENTER);
   }
   
   // Plus
   if(ObjectFind(0, ObjGridPlus) < 0) {
      ObjectCreate(0, ObjGridPlus, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_XDISTANCE, xGrid + btnSmall + 45 + 2);
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_XSIZE, btnSmall);
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_YSIZE, btnHeight);
      ObjectSetString(0, ObjGridPlus, OBJPROP_TEXT, "+");
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, ObjGridPlus, OBJPROP_COLOR, clrWhite);
   }
   
   // Pips Label
   CreateLabel(ObjGridLabel, "pips", xGrid + 60 + 25, yPos + 5, clrGray, 8);
}

//+------------------------------------------------------------------+
//| HELPER: Create Button - MODERN STYLE                              |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int col, int row, color bgColor, int widthOverride=0)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      int w = (widthOverride > 0) ? widthOverride : btnWidth;
      int x = panelX + (col * (btnWidth + 5));
      
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, panelY + (row * gapY));
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, btnHeight);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, DarkenColor(bgColor, 30));
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   }
}

//+------------------------------------------------------------------+
//| HELPER: Darken Color                                              |
//+------------------------------------------------------------------+
color DarkenColor(color c, int amount)
{
   int r = (int)((c & 0xFF) * (100 - amount) / 100);
   int g = (int)(((c >> 8) & 0xFF) * (100 - amount) / 100);
   int b = (int)(((c >> 16) & 0xFF) * (100 - amount) / 100);
   return (color)((b << 16) | (g << 8) | r);
}

//+------------------------------------------------------------------+
//| HELPER: Create Label - MODERN STYLE                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10); // Text on top
}

//+------------------------------------------------------------------+
//| CREATE WATERMARK - MODERN STYLE                                   |
//+------------------------------------------------------------------+
void CreateWatermark(int row)
{
   if(ObjectFind(0, ObjWatermark) < 0)
   {
      ObjectCreate(0, ObjWatermark, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ObjWatermark, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjWatermark, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, ObjWatermark, OBJPROP_YDISTANCE, panelY + ((row + 3) * gapY));
      ObjectSetString(0, ObjWatermark, OBJPROP_TEXT, "◆ TUYUL BIRU v2.0 ◆");
      ObjectSetInteger(0, ObjWatermark, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, ObjWatermark, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, ObjWatermark, OBJPROP_COLOR, C'0,180,220');  // Cyan color
   }
}

//+------------------------------------------------------------------+
//| HELPER: Update Single RSI Label                                   |
//+------------------------------------------------------------------+
void UpdateSingleRSI(int handle, string objName, string label)
{
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   if(CopyBuffer(handle, 0, 0, 1, rsiBuffer) > 0)
   {
      double val = rsiBuffer[0];
      string text = StringFormat("%.0f", val);
      color clr = clrGray;
      
      if(val >= RSI_Overbought) clr = clrOrangeRed;
      else if(val <= RSI_Oversold) clr = clrLime;
      
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   }
   else
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, "--");
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGray);
   }
}

//+------------------------------------------------------------------+
//| HELPER: Update Single SnR Label                                   |
//+------------------------------------------------------------------+
void UpdateSingleSnR(SnRData &data, string objName, string label)
{
   int status = GetSnRStatus(data);
   string text = "Net";
   color clr = clrGray;
   
   if(status == 1) // Buy (At Support)
   {
      text = "Buy";
      clr = clrLime;
   }
   else if(status == 2) // Sell (At Resistance)
   {
      text = "Sell";
      clr = clrOrangeRed;
   }
   else if(status == 3) // Breakout
   {
      text = "Break";
      clr = clrYellow;
   }
   else if(status == 4) // Retest
   {
      text = "Ret";
      clr = clrDeepSkyBlue;
   }
   
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
}

int GetSnRStatus(SnRData &data)
{
   if(ArraySize(data.levels) == 0) return 0;
   
   double O = iOpen(_Symbol, data.tf, 0);
   double C = iClose(_Symbol, data.tf, 0);
   double H = iHigh(_Symbol, data.tf, 0);
   double L = iLow(_Symbol, data.tf, 0);
   double prox = SnR_Proximity * _Point;
   
   for(int i = 0; i < ArraySize(data.levels); i++)
   {
      double lvl = data.levels[i];
      
      // 1. Breakout (Body Cross)
      if((O < lvl && C > lvl) || (O > lvl && C < lvl)) return 3;
      
      // 2. Retest (Wick Cross, Body Safe)
      if(O > lvl && C > lvl && L < lvl) return 4; // Bullish Retest (Support)
      if(O < lvl && C < lvl && H > lvl) return 4; // Bearish Retest (Resistance)
      
      // 3. At Support (Buy)
      if(C > lvl && (C - lvl) <= prox) return 1;
      
      // 4. At Resistance (Sell)
      if(C < lvl && (lvl - C) <= prox) return 2;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| UPDATE SIGNALS FROM HTF                                           |
//+------------------------------------------------------------------+
void UpdateSignals()
{
   // Get RSI for all timeframes
   UpdateSingleRSI(hRSI_M15, ObjSignalRSI_M15, "M15");
   UpdateSingleRSI(hRSI_M30, ObjSignalRSI_M30, "M30");
   UpdateSingleRSI(hRSI_H1,  ObjSignalRSI_H1,  "H1");
   UpdateSingleRSI(hRSI_H4,  ObjSignalRSI_H4,  "H4");
   UpdateSingleRSI(hRSI_D1,  ObjSignalRSI_D1,  "D1");
   
   // Get Divergence
   UpdateSingleDivergence(hRSI_M15, PERIOD_M15, ObjSignalDiv_M15);
   UpdateSingleDivergence(hRSI_M30, PERIOD_M30, ObjSignalDiv_M30);
   UpdateSingleDivergence(hRSI_H1,  PERIOD_H1,  ObjSignalDiv_H1);
   UpdateSingleDivergence(hRSI_H4,  PERIOD_H4,  ObjSignalDiv_H4);
   UpdateSingleDivergence(hRSI_D1,  PERIOD_D1,  ObjSignalDiv_D1);
   
   // Get SnR (Loop through all TFs)
   UpdateSingleSnR(snrList[0], ObjSignalSnR_M15, "M15");
   UpdateSingleSnR(snrList[1], ObjSignalSnR_M30, "M30");
   UpdateSingleSnR(snrList[2], ObjSignalSnR_H1,  "H1");
   UpdateSingleSnR(snrList[3], ObjSignalSnR_H4,  "H4");
   UpdateSingleSnR(snrList[4], ObjSignalSnR_D1,  "D1");
}

//+------------------------------------------------------------------+
//| DRAW TREND MA LINES (SuperTrend Style) - SINGLE LINE OPTIMIZED    |
//+------------------------------------------------------------------+
void DrawTrendMALines(bool fullRedraw = false)
{
   // Static cache for trend states (persist between calls)
   static int cachedTrendStates[];
   static int lastCachedBars = 0;
   static ENUM_TIMEFRAMES lastTimeframe = PERIOD_CURRENT;
   
   // Detect timeframe change - force full redraw
   ENUM_TIMEFRAMES currentTF = Period();
   if(currentTF != lastTimeframe)
   {
      lastTimeframe = currentTF;
      lastCachedBars = 0;  // Reset cache
      ArrayFree(cachedTrendStates);
      ObjectsDeleteAll(0, "TrendMA_");  // Delete old objects
      fullRedraw = true;
   }
   
   // Get available bars
   int availableBars = Bars(_Symbol, PERIOD_CURRENT);
   int maBars = MathMin(availableBars, 5000);
   
   if(maBars < InpTrendMA_Slow + 10) return;
   
   // Determine how many bars to process
   int barsToProcess = fullRedraw ? maBars : MathMin(50, maBars);
   
   // Buffers for MA (HLC/3 only - single line)
   double ma200HLC[], ma10HLC[];
   ArraySetAsSeries(ma200HLC, true);
   ArraySetAsSeries(ma10HLC, true);
   
   // Copy buffers (only what we need)
   int copyBars = fullRedraw ? maBars : barsToProcess + 10;
   
   int copied200 = CopyBuffer(hMA200_HLC, 0, 0, copyBars, ma200HLC);
   int copied10 = CopyBuffer(hMA10_HLC, 0, 0, copyBars, ma10HLC);
   
   int actualBars = MathMin(copied200, copied10);
   
   if(actualBars < 10) return;
   
   // === FULL REDRAW: Calculate all trend states ===
   if(fullRedraw || lastCachedBars == 0)
   {
      ArrayResize(cachedTrendStates, actualBars);
      
      int prevState = 0;
      for(int i = actualBars - 1; i >= 0; i--)
      {
         // Simple crossover: MA10 vs MA200
         if(ma10HLC[i] > ma200HLC[i]) 
            prevState = 1;  // Bullish
         else if(ma10HLC[i] < ma200HLC[i]) 
            prevState = -1; // Bearish
         
         cachedTrendStates[i] = prevState;
      }
      lastCachedBars = actualBars;
      
      // Draw all bars on full redraw
      for(int i = 0; i < actualBars - 1; i++)
      {
         DrawMASegmentAtBar(i, ma200HLC, cachedTrendStates);
      }
   }
   // === INCREMENTAL UPDATE: Only update recent bars ===
   else
   {
      if(ArraySize(cachedTrendStates) > 0)
      {
         int prevState = (ArraySize(cachedTrendStates) > barsToProcess) ? cachedTrendStates[barsToProcess] : TrendState;
         
         for(int i = MathMin(barsToProcess, actualBars - 1); i >= 0; i--)
         {
            if(ma10HLC[i] > ma200HLC[i]) 
               prevState = 1;
            else if(ma10HLC[i] < ma200HLC[i]) 
               prevState = -1;
            
            if(i < ArraySize(cachedTrendStates))
               cachedTrendStates[i] = prevState;
         }
         
         // Only draw recent bars
         for(int i = 0; i < MathMin(barsToProcess, actualBars - 1); i++)
         {
            DrawMASegmentAtBar(i, ma200HLC, cachedTrendStates);
         }
      }
   }
   
   // Update global state
   if(ArraySize(cachedTrendStates) > 0)
      TrendState = cachedTrendStates[0];
}

//+------------------------------------------------------------------+
//| DRAW MA SEGMENT AT SPECIFIC BAR (Helper) - SINGLE LINE            |
//+------------------------------------------------------------------+
void DrawMASegmentAtBar(int i, const double &ma200HLC[], const int &trendStates[])
{
   if(i >= ArraySize(ma200HLC) - 1 || i >= ArraySize(trendStates)) return;
   
   datetime time1 = iTime(_Symbol, PERIOD_CURRENT, i);
   datetime time2 = iTime(_Symbol, PERIOD_CURRENT, i + 1);
   
   if(time1 == 0 || time2 == 0) return;
   
   color trendColor = (trendStates[i] == 1) ? InpTrendBullColor : 
                      (trendStates[i] == -1) ? InpTrendBearColor : clrYellow;
   
   // Draw single MA line (HLC/3)
   DrawTrendSegment("TrendMA_" + IntegerToString(i), time1, ma200HLC[i], time2, ma200HLC[i + 1], trendColor);
}

//+------------------------------------------------------------------+
//| DRAW SINGLE TREND SEGMENT                                         |
//+------------------------------------------------------------------+
void DrawTrendSegment(string objName, datetime time1, double price1, datetime time2, double price2, color lineColor)
{
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_TREND, 0, time1, price1, time2, price2);
   else
   {
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
   }
   
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpTrendMA_Width);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| UPDATE LOT DISPLAY                                                |
//+------------------------------------------------------------------+
void UpdateLotDisplay()
{
   ObjectSetString(0, ObjLotEdit, OBJPROP_TEXT, DoubleToString(CurrentLot, 2));
   ChartRedraw();
}

void UpdateGridDisplay()
{
   ObjectSetString(0, ObjGridEdit, OBJPROP_TEXT, IntegerToString(CurrentGridStep));
   ChartRedraw();
}

void AdjustLot(double step)
{
   double newLot = CurrentLot + step;
   if(newLot >= MinLot && newLot <= MaxLot)
   {
      CurrentLot = NormalizeDouble(newLot, 2);
      UpdateLotDisplay();
   }
}

//+------------------------------------------------------------------+
//| TRADE FUNCTIONS                                                   |
//+------------------------------------------------------------------+
void OpenSingleOrder(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string comment = "SETAN V2";
   
   bool result = false;
   if(type == ORDER_TYPE_BUY)
      result = trade.Buy(CurrentLot, _Symbol, price, 0, 0, comment);
   else
      result = trade.Sell(CurrentLot, _Symbol, price, 0, 0, comment);
      
   if(!result)
      Print("Order failed: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| OPEN GRID ORDERS (with pending orders)                            |
//+------------------------------------------------------------------+
void OpenGridOrders(ENUM_ORDER_TYPE type, bool isMartingale)
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * pt;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentPrice = (type == ORDER_TYPE_BUY) ? ask : bid;
   
   for(int i = 0; i < InpGridLayers; i++)
   {
      double entryPrice = 0;
      double lotSize = CurrentLot;
      
      // Martingale lot calculation
      if(isMartingale)
         lotSize = CurrentLot + (i * InpLotIncrement);
      
      lotSize = NormalizeDouble(lotSize, 2);
      if(lotSize < MinLot) lotSize = MinLot;
      if(lotSize > MaxLot) lotSize = MaxLot;
      
      // Calculate entry price
      if(type == ORDER_TYPE_BUY)
         entryPrice = currentPrice - (i * CurrentGridStep * pt);
      else
         entryPrice = currentPrice + (i * CurrentGridStep * pt);
         
      entryPrice = NormalizeDouble(entryPrice, _Digits);
      
      // Refresh prices
      ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      bool res = false;
      string comment = StringFormat("SETAN V2 L%d", i+1);
      
      if(i == 0)
      {
         // First layer: market order
         if(type == ORDER_TYPE_BUY)
            res = trade.Buy(lotSize, _Symbol, ask, 0, 0, comment);
         else
            res = trade.Sell(lotSize, _Symbol, bid, 0, 0, comment);
      }
      else
      {
         // Other layers: pending orders
         if(type == ORDER_TYPE_BUY)
         {
            if(entryPrice < bid - stopsLevel)
               res = trade.BuyLimit(lotSize, entryPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            else if(entryPrice > ask + stopsLevel)
               res = trade.BuyStop(lotSize, entryPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
         }
         else
         {
            if(entryPrice > ask + stopsLevel)
               res = trade.SellLimit(lotSize, entryPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            else if(entryPrice < bid - stopsLevel)
               res = trade.SellStop(lotSize, entryPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
         }
      }
      
      if(!res) Print("Layer ", i+1, " failed: ", trade.ResultRetcodeDescription());
      Sleep(100);
   }
   
   Print("Grid orders placed: ", InpGridLayers, " layers, ", (isMartingale ? "Martingale" : "Fixed Lot"));
}

//+------------------------------------------------------------------+
//| CLOSE FUNCTIONS                                                   |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            trade.PositionClose(PositionGetTicket(i));
      }
   }
}

void ClosePositionsByType(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_TYPE) == posType)
            trade.PositionClose(PositionGetTicket(i));
      }
   }
}

void DeleteAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol)
            trade.OrderDelete(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| S/R LEVEL FUNCTIONS                                               |
//+------------------------------------------------------------------+
void UpdateSRLevels(SnRData &data)
{
   // Detect pivots
   double ph = DetectPivotHigh(data.tf);
   double pl = DetectPivotLow(data.tf);
   
   if(ph > 0 || pl > 0)
   {
      double pivotValue = (ph > 0) ? ph : pl;
      
      int size = ArraySize(data.pivots);
      ArrayResize(data.pivots, size + 1);
      
      for(int i = size; i > 0; i--)
         data.pivots[i] = data.pivots[i-1];
      data.pivots[0] = pivotValue;
      
      if(ArraySize(data.pivots) > 20)
         ArrayResize(data.pivots, 20);
      
      CalculateSRZones(data);
   }
   
   // Only draw lines if this is the "Main" HTF
   if(data.tf == GetActualHTF())
      DrawSRLines(data);
}

double DetectPivotHigh(ENUM_TIMEFRAMES tf)
{
   int shift = SnR_Pivot_Period;
   if(Bars(_Symbol, tf) < shift * 2 + 1) return 0;
   
   double highVal = iHigh(_Symbol, tf, shift);
   
   for(int i = 1; i <= SnR_Pivot_Period; i++)
   {
      if(iHigh(_Symbol, tf, shift + i) > highVal) return 0;
   }
   
   for(int i = 1; i < SnR_Pivot_Period; i++)
   {
      if(iHigh(_Symbol, tf, shift - i) > highVal) return 0;
   }
   
   return highVal;
}

double DetectPivotLow(ENUM_TIMEFRAMES tf)
{
   int shift = SnR_Pivot_Period;
   if(Bars(_Symbol, tf) < shift * 2 + 1) return 0;
   
   double lowVal = iLow(_Symbol, tf, shift);
   
   for(int i = 1; i <= SnR_Pivot_Period; i++)
   {
      if(iLow(_Symbol, tf, shift + i) < lowVal) return 0;
   }
   
   for(int i = 1; i < SnR_Pivot_Period; i++)
   {
      if(iLow(_Symbol, tf, shift - i) < lowVal) return 0;
   }
   
   return lowVal;
}

//+------------------------------------------------------------------+
//| PRELOAD HISTORICAL PIVOTS ON INIT                                 |
//+------------------------------------------------------------------+
void PreloadPivots(SnRData &data)
{
   int lookback = SnR_Look_Back;  // Scan last 500 HTF bars
   int prd = SnR_Pivot_Period;
   
   // Print("Preloading pivots for ", EnumToString(data.tf));
   
   for(int bar = prd; bar < lookback; bar++)
   {
      // Check for pivot high
      double highVal = iHigh(_Symbol, data.tf, bar);
      bool isPivotHigh = true;
      
      for(int i = 1; i <= prd && isPivotHigh; i++)
      {
         if(iHigh(_Symbol, data.tf, bar - i) > highVal) isPivotHigh = false;
         if(iHigh(_Symbol, data.tf, bar + i) > highVal) isPivotHigh = false;
      }
      
      if(isPivotHigh)
      {
         int size = ArraySize(data.pivots);
         ArrayResize(data.pivots, size + 1);
         data.pivots[size] = highVal;
      }
      
      // Check for pivot low
      double lowVal = iLow(_Symbol, data.tf, bar);
      bool isPivotLow = true;
      
      for(int i = 1; i <= prd && isPivotLow; i++)
      {
         if(iLow(_Symbol, data.tf, bar - i) < lowVal) isPivotLow = false;
         if(iLow(_Symbol, data.tf, bar + i) < lowVal) isPivotLow = false;
      }
      
      if(isPivotLow)
      {
         int size = ArraySize(data.pivots);
         ArrayResize(data.pivots, size + 1);
         data.pivots[size] = lowVal;
      }
   }
   
   // Limit to max pivots
   if(ArraySize(data.pivots) > 20)
      ArrayResize(data.pivots, 20);
   
   // Calculate S/R zones and draw
   CalculateSRZones(data);
   
   if(data.tf == HTF_Timeframe)
      DrawSRLines(data);
}

void CalculateSRZones(SnRData &data)
{
   if(ArraySize(data.pivots) == 0) return;
   
   double prdhighest = iHigh(_Symbol, data.tf, iHighest(_Symbol, data.tf, MODE_HIGH, 300, 0));
   double prdlowest = iLow(_Symbol, data.tf, iLowest(_Symbol, data.tf, MODE_LOW, 300, 0));
   double cwidth = (prdhighest - prdlowest) * 10.0 / 100;
   
   double tempMid[];
   int tempStrength[];
   
   for(int i = 0; i < ArraySize(data.pivots); i++)
   {
      bool found = false;
      for(int j = 0; j < ArraySize(tempMid); j++)
      {
         if(MathAbs(data.pivots[i] - tempMid[j]) <= cwidth)
         {
            tempMid[j] = (tempMid[j] * tempStrength[j] + data.pivots[i]) / (tempStrength[j] + 1);
            tempStrength[j]++;
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         int idx = ArraySize(tempMid);
         ArrayResize(tempMid, idx + 1);
         ArrayResize(tempStrength, idx + 1);
         tempMid[idx] = data.pivots[i];
         tempStrength[idx] = 1;
      }
   }
   
   // Sort by strength
   for(int i = 0; i < ArraySize(tempStrength) - 1; i++)
   {
      for(int j = 0; j < ArraySize(tempStrength) - i - 1; j++)
      {
         if(tempStrength[j] < tempStrength[j+1])
         {
            double tMid = tempMid[j]; tempMid[j] = tempMid[j+1]; tempMid[j+1] = tMid;
            int tSt = tempStrength[j]; tempStrength[j] = tempStrength[j+1]; tempStrength[j+1] = tSt;
         }
      }
   }
   
   int levelCount = MathMin(SnR_Max_Levels, ArraySize(tempMid));
   ArrayResize(data.levels, levelCount);
   
   for(int i = 0; i < levelCount; i++)
      data.levels[i] = tempMid[i];
}

void GetLevelCounts(double level, ENUM_TIMEFRAMES tf, int &breakouts, int &retests)
{
   breakouts = 0;
   retests = 0;
   
   int lookback = SnR_Look_Back; // Check last 500 candles
   double prox = SnR_Proximity * _Point;
   
   for(int k=1; k<=lookback; k++)
   {
      double O = iOpen(_Symbol, tf, k);
      double C = iClose(_Symbol, tf, k);
      double H = iHigh(_Symbol, tf, k);
      double L = iLow(_Symbol, tf, k);
      
      // 1. Breakout
      if((O < level && C > level) || (O > level && C < level)) 
         breakouts++;
      // 2. Retest
      else if((O > level && C > level && L < level) || (O < level && C < level && H > level))
         retests++;
   }
}

void DrawSRLines(SnRData &data)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = 0; i < ArraySize(data.levels); i++)
   {
      string lineName = "SR_Line_" + IntegerToString(i);
      string labelName = "SR_Label_" + IntegerToString(i);
      
      bool isResistance = (data.levels[i] > currentPrice);
      color lineColor = isResistance ? SnR_Resistance_Color : SnR_Support_Color;
      
      // Update or Create Line
      if(ObjectFind(0, lineName) < 0)
         ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, data.levels[i]);
      else
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, data.levels[i]);
         
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      
      // Update or Create Label
      datetime labelTime = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 5;
      
      int breakouts=0, retests=0;
      GetLevelCounts(data.levels[i], data.tf, breakouts, retests);
      
      double rate = 100 * (data.levels[i] - currentPrice) / currentPrice;
      string labelText = DoubleToString(data.levels[i], _Digits) + " (" + DoubleToString(rate, 2) + "%) [B:" + IntegerToString(breakouts) + "|R:" + IntegerToString(retests) + "]";
      
      if(ObjectFind(0, labelName) < 0)
         ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, data.levels[i]);
      else
      {
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, data.levels[i]);
         ObjectSetInteger(0, labelName, OBJPROP_TIME, labelTime);
      }
      
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }
   
   // Cleanup extra lines
   for(int i = ArraySize(data.levels); i < 20; i++) 
   {
      ObjectDelete(0, "SR_Line_" + IntegerToString(i));
      ObjectDelete(0, "SR_Label_" + IntegerToString(i));
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| HELPER: Update Single Divergence Label                            |
//+------------------------------------------------------------------+
void UpdateSingleDivergence(int handle, ENUM_TIMEFRAMES tf, string objName)
{
   int status = GetDivergenceStatus(handle, tf);
   string text = "Net";
   color clr = clrGray;
   
   if(status == 1) // Bullish
   {
      text = "Bull";
      clr = clrLime;
   }
   else if(status == 2) // Bearish
   {
      text = "Bear";
      clr = clrOrangeRed;
   }
   
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
}

int GetDivergenceStatus(int rsiHandle, ENUM_TIMEFRAMES tf)
{
   if(rsiHandle == INVALID_HANDLE) return 0;
   
   // Get RSI Data
   double rsiVal[];
   ArraySetAsSeries(rsiVal, true);
   if(CopyBuffer(rsiHandle, 0, 0, RSI_Div_Lookback, rsiVal) < RSI_Div_Lookback) return 0;
   
   // Arrays for Price
   // We need High and Low arrays, but copying whole series every tick is heavy?
   // Copying 30 bars is negligible.
   
   // Find Peaks/Troughs
   int peak1 = -1, peak2 = -1;
   int trough1 = -1, trough2 = -1;
   
   // Loop checking middle bar 'i'
   // Start i=2 (needs i-1 and i-2, and i+1 to verify peak at 'i' relative to neighbors)
   // Usually peak at 'i' means Val[i] > Val[i+1] and Val[i] > Val[i-1].
   // Since we look back, index 1 is completed bar. 
   // We check i from 1 up to Lookback-2
   
   for(int i = 1; i < RSI_Div_Lookback - 1; i++)
   {
      // --- CHECK PEAK (High) ---
      double h = iHigh(_Symbol, tf, i);
      double h_prev = iHigh(_Symbol, tf, i+1);
      double h_next = iHigh(_Symbol, tf, i-1); // 'next' in time is lower index
      
      bool isPricePeak = (h > h_prev && h > h_next);
      
      if(isPricePeak)
      {
         if(peak1 == -1) peak1 = i;
         else if(peak2 == -1) { peak2 = i; } // Found 2nd peak
      }
      
      // --- CHECK TROUGH (Low) ---
      double l = iLow(_Symbol, tf, i);
      double l_prev = iLow(_Symbol, tf, i+1);
      double l_next = iLow(_Symbol, tf, i-1);
      
      bool isPriceTrough = (l < l_prev && l < l_next);
      
      if(isPriceTrough)
      {
         if(trough1 == -1) trough1 = i;
         else if(trough2 == -1) { trough2 = i; }
      }
   }
   
   // --- BULLISH DIVERGENCE ---
   // Price Lower Low, RSI Higher Low
   if(trough1 != -1 && trough2 != -1)
   {
      double p1 = iLow(_Symbol, tf, trough1);
      double p2 = iLow(_Symbol, tf, trough2);
      double r1 = rsiVal[trough1];
      double r2 = rsiVal[trough2];
      
      // Check RSI Trough validity (roughly)
      // Strictly we should also check if RSI was a trough at these indices, 
      // but comparing values at Price Troughs is a common simplification.
      // However, better accuracy: Is RSI[trough1] actually a local low?
      // For simplicity and robustness, we just compare the values at the Price Troughs.
      
      // Regular Bullish: Price(Recent) < Price(Old) AND RSI(Recent) > RSI(Old)
      if(p1 < p2 && r1 > r2 && r1 < 50) return 1; // Added < 50 filter for validity
   }
   
   // --- BEARISH DIVERGENCE ---
   // Price Higher High, RSI Lower High
   if(peak1 != -1 && peak2 != -1)
   {
      double p1 = iHigh(_Symbol, tf, peak1);
      double p2 = iHigh(_Symbol, tf, peak2);
      double r1 = rsiVal[peak1];
      double r2 = rsiVal[peak2];
      
      // Regular Bearish: Price(Recent) > Price(Old) AND RSI(Recent) < RSI(Old)
      if(p1 > p2 && r1 < r2 && r1 > 50) return 2; // Added > 50 filter
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| ADVANCED TRADING FUNCTIONS                                        |
//+------------------------------------------------------------------+

// Helper: Get ATR Value
double GetATR()
{
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(hATR, 0, 0, 1, atrBuffer) <= 0) return 0;
   return atrBuffer[0];
}

// Helper: Get Strongest SnR Level for TP
double GetStrongestSnRLevel(ENUM_ORDER_TYPE type, double openPrice)
{
   // Find the SnR data for the current Main HTF
   int idx = -1;
   ENUM_TIMEFRAMES actualHTF = GetActualHTF();
   for(int i=0; i<5; i++)
   {
      if(snrList[i].tf == actualHTF)
      {
         idx = i;
         break;
      }
   }
   
   if(idx == -1) return 0;
   
   for(int i = 0; i < ArraySize(snrList[idx].levels); i++)
   {
      double level = snrList[idx].levels[i];
      if(type == ORDER_TYPE_BUY && level > openPrice) return level;
      if(type == ORDER_TYPE_SELL && level < openPrice) return level;
   }
   return 0;
}

// Partial Close
void PartialClose(bool profitOnly)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER) continue;
         
         double profit = PositionGetDouble(POSITION_PROFIT);
         bool shouldClose = (profitOnly && profit > 0) || (!profitOnly && profit < 0);
         
         if(shouldClose)
         {
            double vol = PositionGetDouble(POSITION_VOLUME);
            double closeVol = NormalizeDouble(vol * InpPartialPercent / 100.0, 2);
            double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            
            // Round to step
            closeVol = MathFloor(closeVol / stepVol) * stepVol;
            
            if(closeVol < minVol) closeVol = minVol;
            if(closeVol >= vol) closeVol = vol; // If calc results in full close
            
            if(closeVol > 0)
               trade.PositionClosePartial(ticket, closeVol);
         }
      }
   }
}

// Apply SL
void ApplySL()
{
   double atr = GetATR();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER) continue;
         
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currTP = PositionGetDouble(POSITION_TP);
         double newSL = 0;
         
         if(InpSLTPMode == SLTP_MODE_AUTO_ATR_SNR)
         {
            if(atr == 0) continue;
            double slDist = atr * InpATR_Multiplier;
            if(type == POSITION_TYPE_BUY) newSL = openPrice - slDist;
            else newSL = openPrice + slDist;
         }
         else // FIXED based on InpFixedSL (Points)
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double slDist = InpFixedSL * point;
            if(type == POSITION_TYPE_BUY) newSL = openPrice - slDist;
            else newSL = openPrice + slDist;
         }
         
         newSL = NormalizeDouble(newSL, _Digits);
         trade.PositionModify(ticket, newSL, currTP);
      }
   }
}

// Apply TP
void ApplyTP()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER) continue;
         
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currSL = PositionGetDouble(POSITION_SL);
         double newTP = 0;
         
         if(InpSLTPMode == SLTP_MODE_AUTO_ATR_SNR)
         {
            double snrLevel = GetStrongestSnRLevel((type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), openPrice);
            if(snrLevel > 0) newTP = snrLevel;
            else 
            {
               // Fallback to fixed if no SnR found
               double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if(type == POSITION_TYPE_BUY) newTP = openPrice + (InpFixedTP * point);
               else newTP = openPrice - (InpFixedTP * point);
            }
         }
         else // FIXED
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tpDist = InpFixedTP * point;
            if(type == POSITION_TYPE_BUY) newTP = openPrice + tpDist;
            else newTP = openPrice - tpDist;
         }
         
         newTP = NormalizeDouble(newTP, _Digits);
         trade.PositionModify(ticket, currSL, newTP);
      }
   }
}

// Reset SL/TP
void ResetSLTP()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER) continue;
         trade.PositionModify(ticket, 0, 0);
      }
   }
}

// Set Break Even
void SetBreakEven()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double lockDist = InpBE_Lock * point;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER) continue;
         
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(profit <= 0) continue; // Only for profitable positions
         
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currTP = PositionGetDouble(POSITION_TP);
         double newSL = 0;
         
         if(type == POSITION_TYPE_BUY) newSL = openPrice + lockDist;
         else newSL = openPrice - lockDist;
         
         newSL = NormalizeDouble(newSL, _Digits);
         
         // Only modify if new SL is better (higher for buy, lower for sell) or if SL is 0
         double currSL = PositionGetDouble(POSITION_SL);
         bool update = false;
         
         if(currSL == 0) update = true;
         else if(type == POSITION_TYPE_BUY && newSL > currSL) update = true;
         else if(type == POSITION_TYPE_SELL && newSL < currSL) update = true;
         
         if(update) trade.PositionModify(ticket, newSL, currTP);
      }
   }
}


// Helper: Adjust Grid (Pips)
void AdjustGrid(int pips)
{
   int currentPips = CurrentGridStep / 10;
   currentPips += pips;
   if(currentPips < 1) currentPips = 1;
   if(currentPips > 1000) currentPips = 1000;
   CurrentGridStep = currentPips * 10;
   UpdateGridDisplay();
}

//+------------------------------------------------------------------+
//| CANDLE TIMER                                                      |
//+------------------------------------------------------------------+
void UpdateCandleTimer()
{
   long elapsed = TimeCurrent() - iTime(_Symbol, PERIOD_CURRENT, 0);
   long remaining = PeriodSeconds(PERIOD_CURRENT) - elapsed;
   
   if(remaining < 0) remaining = 0;
   
   string text = StringFormat("%02d:%02d", remaining / 60, remaining % 60);
   
   // Position: At Bid price, slightly to the right
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime time = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 2;
   
   if(ObjectFind(0, ObjCandleTimer) < 0)
   {
      ObjectCreate(0, ObjCandleTimer, OBJ_TEXT, 0, time, price);
      ObjectSetInteger(0, ObjCandleTimer, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, ObjCandleTimer, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, ObjCandleTimer, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   ObjectSetString(0, ObjCandleTimer, OBJPROP_TEXT, text);
   ObjectSetDouble(0, ObjCandleTimer, OBJPROP_PRICE, price);
   ObjectSetInteger(0, ObjCandleTimer, OBJPROP_TIME, time);
}

//+------------------------------------------------------------------+
//| ROBUST DIVERGENCE IMPLEMENTATION                                  |
//+------------------------------------------------------------------+
// 1. ScanDivergence: Main entry point
// 2. Detects pivots in RSI and Price
// 3. Matches them for divergence
// 4. Draws lines

void ScanDivergence(ENUM_TIMEFRAMES tf, int limit)
{
   if(!InpDrawDivLines) return;
   
   int handle = -1;
   // Find handle for this TF
   if(tf == PERIOD_M15) handle = hRSI_M15;
   else if(tf == PERIOD_M30) handle = hRSI_M30;
   else if(tf == PERIOD_H1) handle = hRSI_H1;
   else if(tf == PERIOD_H4) handle = hRSI_H4;
   else if(tf == PERIOD_D1) handle = hRSI_D1;
   
   if(handle == INVALID_HANDLE) return;
   
   // Copy Buffers
   double rsiBuff[]; ArraySetAsSeries(rsiBuff, true);
   double hBuff[]; ArraySetAsSeries(hBuff, true);
   double lBuff[]; ArraySetAsSeries(lBuff, true);
   datetime tBuff[]; ArraySetAsSeries(tBuff, true);
   
   int bars = Bars(_Symbol, tf);
   if(bars < limit) limit = bars;
   if(limit < 50) return; // Not enough data
   
   if(CopyBuffer(handle, 0, 0, limit, rsiBuff) < limit) return;
   if(CopyHigh(_Symbol, tf, 0, limit, hBuff) < limit) return;
   if(CopyLow(_Symbol, tf, 0, limit, lBuff) < limit) return;
   if(CopyTime(_Symbol, tf, 0, limit, tBuff) < limit) return;
   
   // Iterate
   // Start from 'limit - 10' (safe buffer) down to 'rsi_pivot_right'
   // Ensure i+k and i-k do not exceed array bounds [0..limit-1]
   // Max index needed: i + rsi_pivot_left.  So i must be < limit - rsi_pivot_left
   
   int startIdx = limit - (rsi_pivot_left + 5); 
   if(startIdx < rsi_pivot_right) return;
   
   for(int i = startIdx; i >= rsi_pivot_right; i--)
   {
      DetectRSIPivotsAndDiv(i, rsiBuff, hBuff, lBuff, tBuff, tf);
   }
}

void DetectRSIPivotsAndDiv(int i, const double &rsi[], const double &high[], const double &low[], const datetime &time[], ENUM_TIMEFRAMES tf)
{
   // 1. Is RSI Pivot High?
   bool isPivotHigh = true;
   double rVal = rsi[i];
   
   // Bounds check just in case
   if(i + rsi_pivot_left >= ArraySize(rsi) || i - rsi_pivot_right < 0) return;

   for(int k=1; k<=rsi_pivot_left; k++) if(rsi[i+k] > rVal) isPivotHigh = false;
   for(int k=1; k<=rsi_pivot_right; k++) if(rsi[i-k] >= rVal) isPivotHigh = false; // Look ahead check (>= to match SnR)
   
   if(isPivotHigh)
   {
      // Find matching Price Pivot High (nearby)
      int pBar = i;
      double pMsg = high[i];
      // Tolerance search (increased to 3 matching SnR)
      for(int k=1; k<=3; k++) {
         if((i+k < ArraySize(high)) && high[i+k] > pMsg) { pMsg = high[i+k]; pBar = i+k; }
         if((i-k >= 0) && high[i-k] > pMsg) { pMsg = high[i-k]; pBar = i-k; }
      }
      
      StoreAndCheckDiv(pBar, pMsg, rVal, true, time[pBar], tf);
   }
   
   // 2. Is RSI Pivot Low?
   bool isPivotLow = true;
   rVal = rsi[i];
   for(int k=1; k<=rsi_pivot_left; k++) if(rsi[i+k] < rVal) isPivotLow = false;
   for(int k=1; k<=rsi_pivot_right; k++) if(rsi[i-k] <= rVal) isPivotLow = false; // <= to match SnR
   
   if(isPivotLow)
   {
      int pBar = i;
      double pMsg = low[i];
      for(int k=1; k<=3; k++) {
         if((i+k < ArraySize(low)) && low[i+k] < pMsg) { pMsg = low[i+k]; pBar = i+k; }
         if((i-k >= 0) && low[i-k] < pMsg) { pMsg = low[i-k]; pBar = i-k; }
      }
      
      StoreAndCheckDiv(pBar, pMsg, rVal, false, time[pBar], tf);
   }
}

void StoreAndCheckDiv(int bar, double price, double rsiVal, bool isHigh, datetime t, ENUM_TIMEFRAMES tf)
{
   // Store
   if(isHigh)
   {
      // Add to array
      int sz = ArraySize(rsiPipsHigh);
      ArrayResize(rsiPipsHigh, sz+1);
      rsiPipsHigh[sz].bar = bar; // Relative bar index not reliable if called multiple times, relying on Time is better. 
      // But for drawing we need time defined.
      rsiPipsHigh[sz].time = t;
      rsiPipsHigh[sz].price = price;
      rsiPipsHigh[sz].rsi = rsiVal;
      rsiPipsHigh[sz].isHigh = true;
      
      // Cleanup old
      if(sz > 20) {
         for(int k=0; k<sz; k++) rsiPipsHigh[k] = rsiPipsHigh[k+1];
         ArrayResize(rsiPipsHigh, sz);
         sz--;
      }
      
      // CHECK BEARISH DIV
      // Iterate backwards
      for(int k = sz-1; k >= 0; k--)
      {
         // Needs loopback
         if(TimeDifferenceBars(t, rsiPipsHigh[k].time, tf) < 5) continue;
         if(TimeDifferenceBars(t, rsiPipsHigh[k].time, tf) > RSI_Div_Lookback) break; // Optimization?
         
         double p1 = rsiPipsHigh[k].price;
         double r1 = rsiPipsHigh[k].rsi;
         
         // Bearish: Price HH, RSI LH
         if(price > p1 && rsiVal < r1) // Removed > 50 filter
         {
            if(!IsDivDrawn(rsiPipsHigh[k].time, t, false))
            {
               DrawDivOnChart(rsiPipsHigh[k].time, p1, t, price, false);
               RecordDiv(rsiPipsHigh[k].time, t, false);
            }
         }
      }
   }
   else
   {
      // Add to Lows
      int sz = ArraySize(rsiPipsLow);
      ArrayResize(rsiPipsLow, sz+1);
      rsiPipsLow[sz].time = t;
      rsiPipsLow[sz].price = price;
      rsiPipsLow[sz].rsi = rsiVal;
      rsiPipsLow[sz].isHigh = false;
      
      if(sz > 20) {
         for(int k=0; k<sz; k++) rsiPipsLow[k] = rsiPipsLow[k+1];
         ArrayResize(rsiPipsLow, sz);
         sz--;
      }
      
      // CHECK BULLISH DIV
      // Bullish: Price LL, RSI HL
      for(int k = sz-1; k >= 0; k--)
      {
         if(TimeDifferenceBars(t, rsiPipsLow[k].time, tf) < 5) continue;
         if(TimeDifferenceBars(t, rsiPipsLow[k].time, tf) > RSI_Div_Lookback) break;
         
         double p1 = rsiPipsLow[k].price;
         double r1 = rsiPipsLow[k].rsi;
         
         if(price < p1 && rsiVal > r1) // Removed < 50 filter
         {
            if(!IsDivDrawn(rsiPipsLow[k].time, t, true))
            {
               DrawDivOnChart(rsiPipsLow[k].time, p1, t, price, true);
               RecordDiv(rsiPipsLow[k].time, t, true);
            }
         }
      }
   }
}

int TimeDifferenceBars(datetime t1, datetime t2, ENUM_TIMEFRAMES tf)
{
   return (int)MathAbs((t1 - t2) / PeriodSeconds(tf));
}

bool IsDivDrawn(datetime t1, datetime t2, bool isBull)
{
   for(int i=0; i<ArraySize(drawnDivs); i++) {
      if(drawnDivs[i].time1 == t1 && drawnDivs[i].time2 == t2 && drawnDivs[i].isBullish == isBull) return true;
      if(drawnDivs[i].time2 == t2 && drawnDivs[i].isBullish == isBull) return true; // Avoid multiple divs to same point
   }
   return false;
}

void RecordDiv(datetime t1, datetime t2, bool isBull)
{
   int s = ArraySize(drawnDivs);
   ArrayResize(drawnDivs, s+1);
   drawnDivs[s].time1 = t1;
   drawnDivs[s].time2 = t2;
   drawnDivs[s].isBullish = isBull;
   
   if(s > 50) {
      for(int k=0; k<s; k++) drawnDivs[k] = drawnDivs[k+1];
      ArrayResize(drawnDivs, s);
   }
}

void DrawDivOnChart(datetime t1, double p1, datetime t2, double p2, bool isBull)
{
   if(GetActualHTF() != Period()) return; // Only draw if chart matches HTF setting (optional, but cleaner)
   
   string name = "DIV_" + (isBull ? "Bull" : "Bear") + "_" + IntegerToString((long)t2);
   color c = isBull ? InpDivBullColor : InpDivBearColor;
   
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   }
   
   string lbl = "DIVLBL_" + (isBull ? "Bull" : "Bear") + "_" + IntegerToString((long)t2);
   if(ObjectFind(0, lbl) < 0)
   {
      ObjectCreate(0, lbl, OBJ_TEXT, 0, t2, p2);
      ObjectSetString(0, lbl, OBJPROP_TEXT, (isBull ? "Bull" : "Bear"));
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, (isBull ? ANCHOR_UPPER : ANCHOR_LOWER));
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
//| SIGNAL GENERATOR - CHECK ALL CONDITIONS                           |
//+------------------------------------------------------------------+
void CheckSignalConditions()
{
   // Reset all conditions
   ZeroMemory(sigCond);
   
   // === 1. MA CROSSOVER & TREND CHANGE ===
   double ma10[], ma200[];
   ArraySetAsSeries(ma10, true);
   ArraySetAsSeries(ma200, true);
   
   if(CopyBuffer(hMA10_HLC, 0, 0, 3, ma10) >= 3 && CopyBuffer(hMA200_HLC, 0, 0, 3, ma200) >= 3)
   {
      // Check MA Cross on bar 1 (completed bar)
      bool ma10AboveNow = (ma10[1] > ma200[1]);
      bool ma10AbovePrev = (ma10[2] > ma200[2]);
      
      sigCond.maCrossUp = (ma10AboveNow && !ma10AbovePrev);   // MA10 crossed above MA200
      sigCond.maCrossDown = (!ma10AboveNow && ma10AbovePrev); // MA10 crossed below MA200
   }
   
   // Trend change detection
   PrevTrendState = TrendState;  // Store previous
   sigCond.trendChanged = (TrendState != PrevTrendState && PrevTrendState != 0);
   
   // === 2. ADX DI+ / DI- CROSSOVER ===
   double adxMain[], diPlus[], diMinus[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(diPlus, true);
   ArraySetAsSeries(diMinus, true);
   
   if(CopyBuffer(hADX, 0, 0, 3, adxMain) >= 3 &&
      CopyBuffer(hADX, 1, 0, 3, diPlus) >= 3 &&
      CopyBuffer(hADX, 2, 0, 3, diMinus) >= 3)
   {
      // ADX strength
      sigCond.adxStrong = (adxMain[1] >= InpADX_Level);
      
      // DI conditions on bar 1
      sigCond.adxBullish = (diPlus[1] > diMinus[1]);
      sigCond.adxBearish = (diMinus[1] > diPlus[1]);
      
      // DI Crossover
      bool diPlusAboveNow = (diPlus[1] > diMinus[1]);
      bool diPlusAbovePrev = (diPlus[2] > diMinus[2]);
      
      sigCond.diCrossUp = (diPlusAboveNow && !diPlusAbovePrev);
      sigCond.diCrossDown = (!diPlusAboveNow && diPlusAbovePrev);
   }
   
   // === 3. SUPPORT/RESISTANCE CHECK ===
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double prox = SnR_Proximity * _Point;
   
   // Find nearest S/R (use current TF or HTF)
   int tfIdx = GetTFIndex(PERIOD_CURRENT);
   if(tfIdx == -1) tfIdx = GetTFIndex(GetActualHTF());
   
   if(tfIdx >= 0 && ArraySize(snrList[tfIdx].levels) > 0)
   {
      for(int i = 0; i < ArraySize(snrList[tfIdx].levels); i++)
      {
         double lvl = snrList[tfIdx].levels[i];
         
         // At Support (price near and above level)
         if(close1 > lvl && (close1 - lvl) <= prox)
            sigCond.atSupport = true;
         
         // At Resistance (price near and below level)
         if(close1 < lvl && (lvl - close1) <= prox)
            sigCond.atResistance = true;
         
         // Break Support (body cross down)
         if(open1 > lvl && close1 < lvl)
            sigCond.breakSupport = true;
         
         // Break Resistance (body cross up)
         if(open1 < lvl && close1 > lvl)
            sigCond.breakResistance = true;
      }
   }
   
   // === 4. RSI OVERSOLD/OVERBOUGHT ===
   double rsiVal[];
   ArraySetAsSeries(rsiVal, true);
   
   if(CopyBuffer(hRSI_Current, 0, 0, 2, rsiVal) >= 2)
   {
      sigCond.rsiOversold = (rsiVal[1] <= RSI_Oversold + InpRSI_NearLevel);
      sigCond.rsiOverbought = (rsiVal[1] >= RSI_Overbought - InpRSI_NearLevel);
   }
   
   // === 5. ENGULFING/REVERSAL PATTERN ===
   CheckEngulfingPattern(sigCond.bullishEngulf, sigCond.bearishEngulf);
   
   // === 6. SWING HIGH/LOW (Recent H&L) ===
   CheckSwingHL(sigCond.atSwingHigh, sigCond.atSwingLow);
}

//+------------------------------------------------------------------+
//| CHECK ENGULFING PATTERN                                           |
//+------------------------------------------------------------------+
void CheckEngulfingPattern(bool &bullEngulf, bool &bearEngulf)
{
   bullEngulf = false;
   bearEngulf = false;
   
   // Bar 1 = last completed candle, Bar 2 = previous
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double h1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double l1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double h2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double l2 = iLow(_Symbol, PERIOD_CURRENT, 2);
   
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   
   // Bullish Engulfing: Bar2 bearish, Bar1 bullish, Bar1 body engulfs Bar2 body
   bool bar2Bearish = (c2 < o2);
   bool bar1Bullish = (c1 > o1);
   
   if(bar2Bearish && bar1Bullish)
   {
      if(o1 <= c2 && c1 >= o2 && body1 > body2)
         bullEngulf = true;
   }
   
   // Bearish Engulfing: Bar2 bullish, Bar1 bearish, Bar1 body engulfs Bar2 body
   bool bar2Bullish = (c2 > o2);
   bool bar1Bearish = (c1 < o1);
   
   if(bar2Bullish && bar1Bearish)
   {
      if(o1 >= c2 && c1 <= o2 && body1 > body2)
         bearEngulf = true;
   }
}

//+------------------------------------------------------------------+
//| CHECK SWING HIGH/LOW POSITION                                     |
//+------------------------------------------------------------------+
void CheckSwingHL(bool &atHigh, bool &atLow)
{
   atHigh = false;
   atLow = false;
   
   int lookback = 20;  // Look back 20 bars
   
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, lookback, highs) < lookback) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, lookback, lows) < lookback) return;
   
   double highestHigh = highs[ArrayMaximum(highs)];
   double lowestLow = lows[ArrayMinimum(lows)];
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double tolerance = 10 * _Point;
   
   // At swing high area
   if(high1 >= highestHigh - tolerance)
      atHigh = true;
   
   // At swing low area
   if(low1 <= lowestLow + tolerance)
      atLow = true;
}

//+------------------------------------------------------------------+
//| GET TIMEFRAME INDEX                                               |
//+------------------------------------------------------------------+
int GetTFIndex(ENUM_TIMEFRAMES tf)
{
   // Resolve PERIOD_CURRENT to actual timeframe
   ENUM_TIMEFRAMES actualTF = (tf == PERIOD_CURRENT) ? Period() : tf;
   
   for(int i = 0; i < 5; i++)
   {
      if(tfList[i] == actualTF) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| GET ACTUAL HTF (Resolve PERIOD_CURRENT)                           |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetActualHTF()
{
   return (HTF_Timeframe == PERIOD_CURRENT) ? Period() : HTF_Timeframe;
}

//+------------------------------------------------------------------+
//| GET HTF NAME STRING                                                |
//+------------------------------------------------------------------+
string GetHTFName()
{
   ENUM_TIMEFRAMES tf = GetActualHTF();
   
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
//| GENERATE SIGNAL BASED ON CONDITIONS                               |
//+------------------------------------------------------------------+
int GenerateSignal()
{
   int buyScore = 0;
   int sellScore = 0;
   
   // === SCORING SYSTEM ===
   
   // 1. MA Crossover + Trend Change (Weight: 2)
   if(sigCond.maCrossUp || (TrendState == 1 && PrevTrendState == -1))
      buyScore += 2;
   if(sigCond.maCrossDown || (TrendState == -1 && PrevTrendState == 1))
      sellScore += 2;
   
   // 2. ADX DI Crossover (Weight: 2)
   if(sigCond.diCrossUp && sigCond.adxStrong)
      buyScore += 2;
   if(sigCond.diCrossDown && sigCond.adxStrong)
      sellScore += 2;
   
   // ADX Direction confirmation (Weight: 1)
   if(sigCond.adxBullish)
      buyScore += 1;
   if(sigCond.adxBearish)
      sellScore += 1;
   
   // 3. Support/Resistance (Weight: 2)
   if(sigCond.atSupport || sigCond.breakResistance)
      buyScore += 2;
   if(sigCond.atResistance || sigCond.breakSupport)
      sellScore += 2;
   
   // 4. RSI (Weight: 1)
   if(sigCond.rsiOversold)
      buyScore += 1;
   if(sigCond.rsiOverbought)
      sellScore += 1;
   
   // 5. Engulfing Pattern (Weight: 2)
   if(sigCond.bullishEngulf)
      buyScore += 2;
   if(sigCond.bearishEngulf)
      sellScore += 2;
   
   // 6. Swing H/L Position (Weight: 1)
   if(sigCond.atSwingLow)
      buyScore += 1;
   if(sigCond.atSwingHigh)
      sellScore += 1;
   
   // === SIGNAL DECISION ===
   int minScore = 5;  // Minimum score needed for signal
   
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 1);
   
   // BUY Signal
   if(buyScore >= minScore && buyScore > sellScore)
   {
      if(currentBar != LastSignalTime || LastSignal != 1)
      {
         LastSignal = 1;
         LastSignalTime = currentBar;
         
         if(InpShowSignalArrow)
            DrawSignalArrow(1, buyScore);
         
         if(InpSignalAlert)
            Alert("🔔 BUY SIGNAL! Score: ", buyScore, " | ", _Symbol, " ", EnumToString(Period()));
         
         return 1;
      }
   }
   
   // SELL Signal
   if(sellScore >= minScore && sellScore > buyScore)
   {
      if(currentBar != LastSignalTime || LastSignal != -1)
      {
         LastSignal = -1;
         LastSignalTime = currentBar;
         
         if(InpShowSignalArrow)
            DrawSignalArrow(-1, sellScore);
         
         if(InpSignalAlert)
            Alert("🔔 SELL SIGNAL! Score: ", sellScore, " | ", _Symbol, " ", EnumToString(Period()));
         
         return -1;
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| DRAW SIGNAL ARROW ON CHART (Unified function)                     |
//+------------------------------------------------------------------+
void DrawSignalArrow(int direction, int score, int barIndex = 1, bool isHistorical = false)
{
   datetime time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   double price = (direction == 1) ? iLow(_Symbol, PERIOD_CURRENT, barIndex) : iHigh(_Symbol, PERIOD_CURRENT, barIndex);
   
   string name = "SigArrow_" + IntegerToString((long)time);
   
   // Skip if already exists
   if(ObjectFind(0, name) >= 0) return;
   
   int arrowCode = (direction == 1) ? 233 : 234;  // Up/Down arrow
   color arrowColor = (direction == 1) ? clrLime : clrRed;
   ENUM_ARROW_ANCHOR anchor = (direction == 1) ? ANCHOR_TOP : ANCHOR_BOTTOM;
   int arrowWidth = isHistorical ? 2 : 3;
   
   ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, arrowWidth);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   
   // Add score label
   string lblName = "SigLbl_" + IntegerToString((long)time);
   
   // Calculate offset based on ATR for better visibility
   double atr[];
   ArraySetAsSeries(atr, true);
   int hATR_temp = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(CopyBuffer(hATR_temp, 0, 0, 1, atr) > 0)
   {
      double offset = atr[0] * 0.5;
      double lblPrice = (direction == 1) ? price - offset : price + offset;
      ENUM_ANCHOR_POINT lblAnchor = (direction == 1) ? ANCHOR_UPPER : ANCHOR_LOWER;
      
      string lblText = isHistorical ? 
         ((direction == 1 ? "B" : "S") + "(" + IntegerToString(score) + ")") :
         ((direction == 1 ? "BUY" : "SELL") + "(" + IntegerToString(score) + ")");
      int fontSize = isHistorical ? 7 : 8;
      
      ObjectCreate(0, lblName, OBJ_TEXT, 0, time, lblPrice);
      ObjectSetString(0, lblName, OBJPROP_TEXT, lblText);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, lblAnchor);
   }
   IndicatorRelease(hATR_temp);
}

//+------------------------------------------------------------------+
//| UPDATE SIGNAL DISPLAY ON PANEL                                    |
//+------------------------------------------------------------------+
void UpdateSignalDisplay(int signal)
{
   string signalText = "---";
   color signalColor = clrGray;
   
   if(signal == 1)
   {
      signalText = "▲ BUY";
      signalColor = clrLime;
   }
   else if(signal == -1)
   {
      signalText = "▼ SELL";
      signalColor = clrRed;
   }
   else if(TrendState == 1)
   {
      signalText = "↑ BULLISH";
      signalColor = C'0,180,100';
   }
   else if(TrendState == -1)
   {
      signalText = "↓ BEARISH";
      signalColor = C'180,80,80';
   }
   
   // Update or create main signal label (on panel)
   int sigX = panelX + 230;
   int sigY = panelY + (int)(7.5 * gapY) + 15;  // Position in signal panel
   
   if(ObjectFind(0, ObjMainSignal) < 0)
   {
      ObjectCreate(0, ObjMainSignal, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ObjMainSignal, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   }
   
   ObjectSetInteger(0, ObjMainSignal, OBJPROP_XDISTANCE, sigX);
   ObjectSetInteger(0, ObjMainSignal, OBJPROP_YDISTANCE, sigY);
   ObjectSetString(0, ObjMainSignal, OBJPROP_TEXT, "SIGNAL: " + signalText);
   ObjectSetInteger(0, ObjMainSignal, OBJPROP_COLOR, signalColor);
   ObjectSetInteger(0, ObjMainSignal, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, ObjMainSignal, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, ObjMainSignal, OBJPROP_ZORDER, 15);
}

//+------------------------------------------------------------------+
//| SCAN HISTORICAL SIGNALS (Non-Repainting)                          |
//+------------------------------------------------------------------+
void ScanHistoricalSignals(int lookback)
{
   if(lookback < 10) lookback = 10;
   
   // Get buffer data for all indicators
   double ma10[], ma200[], adxMain[], diPlus[], diMinus[], rsiVal[];
   ArraySetAsSeries(ma10, true);
   ArraySetAsSeries(ma200, true);
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(diPlus, true);
   ArraySetAsSeries(diMinus, true);
   ArraySetAsSeries(rsiVal, true);
   
   int copyBars = lookback + 5;
   
   if(CopyBuffer(hMA10_HLC, 0, 0, copyBars, ma10) < copyBars) return;
   if(CopyBuffer(hMA200_HLC, 0, 0, copyBars, ma200) < copyBars) return;
   if(CopyBuffer(hADX, 0, 0, copyBars, adxMain) < copyBars) return;
   if(CopyBuffer(hADX, 1, 0, copyBars, diPlus) < copyBars) return;
   if(CopyBuffer(hADX, 2, 0, copyBars, diMinus) < copyBars) return;
   if(CopyBuffer(hRSI_Current, 0, 0, copyBars, rsiVal) < copyBars) return;
   
   // Track trend state for historical calculation
   int histTrendState = 0;
   
   // Scan from oldest to newest (to track trend changes properly)
   for(int i = lookback; i >= 2; i--)
   {
      int buyScore = 0;
      int sellScore = 0;
      
      // === 1. MA CROSSOVER ===
      bool ma10AboveNow = (ma10[i] > ma200[i]);
      bool ma10AbovePrev = (ma10[i+1] > ma200[i+1]);
      
      bool maCrossUp = (ma10AboveNow && !ma10AbovePrev);
      bool maCrossDown = (!ma10AboveNow && ma10AbovePrev);
      
      // Track trend state
      int prevHistTrend = histTrendState;
      if(ma10[i] > ma200[i]) histTrendState = 1;
      else if(ma10[i] < ma200[i]) histTrendState = -1;
      
      bool trendChangeBull = (histTrendState == 1 && prevHistTrend == -1);
      bool trendChangeBear = (histTrendState == -1 && prevHistTrend == 1);
      
      if(maCrossUp || trendChangeBull) buyScore += 2;
      if(maCrossDown || trendChangeBear) sellScore += 2;
      
      // === 2. ADX ===
      bool adxStrong = (adxMain[i] >= InpADX_Level);
      bool diPlusAboveNow = (diPlus[i] > diMinus[i]);
      bool diPlusAbovePrev = (diPlus[i+1] > diMinus[i+1]);
      
      bool diCrossUp = (diPlusAboveNow && !diPlusAbovePrev);
      bool diCrossDown = (!diPlusAboveNow && diPlusAbovePrev);
      
      if(diCrossUp && adxStrong) buyScore += 2;
      if(diCrossDown && adxStrong) sellScore += 2;
      
      if(diPlusAboveNow) buyScore += 1;
      else sellScore += 1;
      
      // === 3. RSI ===
      if(rsiVal[i] <= RSI_Oversold + InpRSI_NearLevel) buyScore += 1;
      if(rsiVal[i] >= RSI_Overbought - InpRSI_NearLevel) sellScore += 1;
      
      // === 4. ENGULFING ===
      double o1 = iOpen(_Symbol, PERIOD_CURRENT, i);
      double c1 = iClose(_Symbol, PERIOD_CURRENT, i);
      double o2 = iOpen(_Symbol, PERIOD_CURRENT, i+1);
      double c2 = iClose(_Symbol, PERIOD_CURRENT, i+1);
      
      double body1 = MathAbs(c1 - o1);
      double body2 = MathAbs(c2 - o2);
      
      // Bullish Engulfing
      if(c2 < o2 && c1 > o1 && o1 <= c2 && c1 >= o2 && body1 > body2)
         buyScore += 2;
      
      // Bearish Engulfing
      if(c2 > o2 && c1 < o1 && o1 >= c2 && c1 <= o2 && body1 > body2)
         sellScore += 2;
      
      // === 5. SWING H/L ===
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      
      if(CopyHigh(_Symbol, PERIOD_CURRENT, i, 20, highs) >= 20 &&
         CopyLow(_Symbol, PERIOD_CURRENT, i, 20, lows) >= 20)
      {
         double highestH = highs[ArrayMaximum(highs)];
         double lowestL = lows[ArrayMinimum(lows)];
         double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
         double low_i = iLow(_Symbol, PERIOD_CURRENT, i);
         double tolerance = 10 * _Point;
         
         if(low_i <= lowestL + tolerance) buyScore += 1;
         if(high_i >= highestH - tolerance) sellScore += 1;
      }
      
      // === DRAW SIGNAL IF SCORE >= 5 ===
      int minScore = 5;
      
      if(buyScore >= minScore && buyScore > sellScore)
      {
         DrawSignalArrow(1, buyScore, i, true);
      }
      else if(sellScore >= minScore && sellScore > buyScore)
      {
         DrawSignalArrow(-1, sellScore, i, true);
      }
   }
   
   Print("Historical signal scan completed. Bars scanned: ", lookback);
}

//+------------------------------------------------------------------+
//| NEWS FUNCTIONS - Currency Detection                                |
//+------------------------------------------------------------------+
void GetCurrenciesFromSymbol(string symbol, string &currencies[])
{
   ArrayResize(currencies, 0);
   
   // Clean symbol name (remove suffix like .r, m, etc)
   string cleanSymbol = symbol;
   int dotPos = StringFind(cleanSymbol, ".");
   if(dotPos > 0) cleanSymbol = StringSubstr(cleanSymbol, 0, dotPos);
   
   // Remove common suffixes
   StringReplace(cleanSymbol, "m", "");
   StringReplace(cleanSymbol, "M", "");
   StringReplace(cleanSymbol, ".r", "");
   StringReplace(cleanSymbol, "_", "");
   
   // Convert to uppercase
   StringToUpper(cleanSymbol);
   
   // === SPECIAL HANDLING FOR COMMODITIES ===
   // Gold/XAU
   if(StringFind(cleanSymbol, "XAU") >= 0 || StringFind(cleanSymbol, "GOLD") >= 0)
   {
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "XAU";
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "USD";
      // Gold is also affected by these
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "EUR";
      return;
   }
   
   // Silver/XAG
   if(StringFind(cleanSymbol, "XAG") >= 0 || StringFind(cleanSymbol, "SILVER") >= 0)
   {
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "XAG";
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "USD";
      return;
   }
   
   // Oil
   if(StringFind(cleanSymbol, "WTI") >= 0 || StringFind(cleanSymbol, "BRENT") >= 0 || 
      StringFind(cleanSymbol, "OIL") >= 0 || StringFind(cleanSymbol, "USOIL") >= 0)
   {
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "USD";
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "CAD";
      return;
   }
   
   // BTC and Crypto
   if(StringFind(cleanSymbol, "BTC") >= 0)
   {
      ArrayResize(currencies, ArraySize(currencies) + 1);
      currencies[ArraySize(currencies) - 1] = "USD";
      return;
   }
   
   // === STANDARD FOREX PAIRS ===
   // Common currency codes (3 chars)
   string knownCurrencies[] = {"EUR", "USD", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF", 
                               "CNY", "CNH", "HKD", "SGD", "SEK", "NOK", "DKK", "MXN",
                               "ZAR", "TRY", "PLN", "CZK", "HUF", "RUB", "INR", "BRL"};
   
   // Try to extract currencies from symbol (usually 6 chars like EURUSD)
   if(StringLen(cleanSymbol) >= 6)
   {
      string base = StringSubstr(cleanSymbol, 0, 3);
      string quote = StringSubstr(cleanSymbol, 3, 3);
      
      // Check if they are known currencies
      for(int i = 0; i < ArraySize(knownCurrencies); i++)
      {
         if(base == knownCurrencies[i])
         {
            ArrayResize(currencies, ArraySize(currencies) + 1);
            currencies[ArraySize(currencies) - 1] = base;
            break;
         }
      }
      
      for(int i = 0; i < ArraySize(knownCurrencies); i++)
      {
         if(quote == knownCurrencies[i])
         {
            ArrayResize(currencies, ArraySize(currencies) + 1);
            currencies[ArraySize(currencies) - 1] = quote;
            break;
         }
      }
   }
   
   // If nothing found, default to USD
   if(ArraySize(currencies) == 0)
   {
      ArrayResize(currencies, 1);
      currencies[0] = "USD";
   }
}

//+------------------------------------------------------------------+
//| Check if currency is related to our pair                          |
//+------------------------------------------------------------------+
bool IsRelatedCurrency(string eventCurrency)
{
   StringToUpper(eventCurrency);
   
   for(int i = 0; i < ArraySize(g_FilterCurrencies); i++)
   {
      if(g_FilterCurrencies[i] == eventCurrency)
         return true;
   }
   
   // Special case: XAU is affected by USD heavily
   for(int i = 0; i < ArraySize(g_FilterCurrencies); i++)
   {
      if(g_FilterCurrencies[i] == "XAU" && eventCurrency == "USD")
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Convert Calendar Impact to our Enum                                |
//+------------------------------------------------------------------+
ENUM_NEWS_IMPACT ConvertImpact(ENUM_CALENDAR_EVENT_IMPORTANCE importance)
{
   switch(importance)
   {
      case CALENDAR_IMPORTANCE_LOW:    return NEWS_IMPACT_LOW;
      case CALENDAR_IMPORTANCE_MODERATE: return NEWS_IMPACT_MEDIUM;
      case CALENDAR_IMPORTANCE_HIGH:   return NEWS_IMPACT_HIGH;
      default: return NEWS_IMPACT_NONE;
   }
}

//+------------------------------------------------------------------+
//| Fetch News Events from MQL5 Calendar                               |
//+------------------------------------------------------------------+
void FetchNewsEvents()
{
   if(!InpEnableNews) return;
   
   // Check if update needed
   if(TimeCurrent() - g_LastNewsUpdate < g_NewsUpdateInterval && ArraySize(g_NewsEvents) > 0)
      return;
   
   g_LastNewsUpdate = TimeCurrent();
   ArrayResize(g_NewsEvents, 0);
   
   // Time range
   datetime from = TimeCurrent() - InpNewsLookBack * 3600;   // Look back
   datetime to = TimeCurrent() + InpNewsLookAhead * 3600;    // Look ahead
   
   // Get calendar values
   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from, to);
   
   if(count <= 0) return;
   
   for(int i = 0; i < count; i++)
   {
      // Get event info
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;
      
      // Get country info for currency
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;
      
      // Check if currency is related to our pair
      if(!IsRelatedCurrency(country.currency))
         continue;
      
      // Check impact filter
      ENUM_NEWS_IMPACT impact = ConvertImpact(event.importance);
      
      if(impact == NEWS_IMPACT_LOW && !InpShowLowImpact) continue;
      if(impact == NEWS_IMPACT_MEDIUM && !InpShowMediumImpact) continue;
      if(impact == NEWS_IMPACT_HIGH && !InpShowHighImpact) continue;
      if(impact == NEWS_IMPACT_NONE) continue;
      
      // Add to array
      int idx = ArraySize(g_NewsEvents);
      ArrayResize(g_NewsEvents, idx + 1);
      
      g_NewsEvents[idx].time = values[i].time;
      g_NewsEvents[idx].currency = country.currency;
      g_NewsEvents[idx].name = event.name;
      g_NewsEvents[idx].impact = impact;
      g_NewsEvents[idx].isPast = (values[i].time < TimeCurrent());
      
      // Get actual/forecast/previous values
      if(values[i].HasActualValue())
         g_NewsEvents[idx].actual = DoubleToString(values[i].GetActualValue(), 2);
      else
         g_NewsEvents[idx].actual = "-";
      
      if(values[i].HasForecastValue())
         g_NewsEvents[idx].forecast = DoubleToString(values[i].GetForecastValue(), 2);
      else
         g_NewsEvents[idx].forecast = "-";
      
      if(values[i].HasPreviousValue())
         g_NewsEvents[idx].previous = DoubleToString(values[i].GetPreviousValue(), 2);
      else
         g_NewsEvents[idx].previous = "-";
   }
   
   // Sort by time (upcoming first)
   SortNewsByTime();
}

//+------------------------------------------------------------------+
//| Sort News by Time                                                  |
//+------------------------------------------------------------------+
void SortNewsByTime()
{
   int n = ArraySize(g_NewsEvents);
   for(int i = 0; i < n - 1; i++)
   {
      for(int j = 0; j < n - i - 1; j++)
      {
         if(g_NewsEvents[j].time > g_NewsEvents[j + 1].time)
         {
            NewsEvent temp = g_NewsEvents[j];
            g_NewsEvents[j] = g_NewsEvents[j + 1];
            g_NewsEvents[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Impact Color                                                   |
//+------------------------------------------------------------------+
color GetImpactColor(ENUM_NEWS_IMPACT impact)
{
   switch(impact)
   {
      case NEWS_IMPACT_HIGH:   return InpNewsHighColor;
      case NEWS_IMPACT_MEDIUM: return InpNewsMediumColor;
      case NEWS_IMPACT_LOW:    return InpNewsLowColor;
      default: return clrGray;
   }
}

//+------------------------------------------------------------------+
//| Get Impact Icon                                                    |
//+------------------------------------------------------------------+
string GetImpactIcon(ENUM_NEWS_IMPACT impact)
{
   switch(impact)
   {
      case NEWS_IMPACT_HIGH:   return "🔴";
      case NEWS_IMPACT_MEDIUM: return "🟠";
      case NEWS_IMPACT_LOW:    return "🟡";
      default: return "⚪";
   }
}

//+------------------------------------------------------------------+
//| Format Time Remaining                                              |
//+------------------------------------------------------------------+
string FormatTimeRemaining(datetime eventTime)
{
   long diff = (long)(eventTime - TimeCurrent());
   
   if(diff < 0)
   {
      diff = -diff;
      if(diff < 60) return StringFormat("-%ds ago", diff);
      if(diff < 3600) return StringFormat("-%dm ago", diff / 60);
      return StringFormat("-%dh ago", diff / 3600);
   }
   else
   {
      if(diff < 60) return StringFormat("in %ds", diff);
      if(diff < 3600) return StringFormat("in %dm", diff / 60);
      return StringFormat("in %dh%dm", diff / 3600, (diff % 3600) / 60);
   }
}

//+------------------------------------------------------------------+
//| CREATE NEWS PANEL                                                  |
//+------------------------------------------------------------------+
void CreateNewsPanel()
{
   if(!InpEnableNews) return;
   
   // Calculate position (above signal panel)
   int panelWidth = btnWidth * 4 + 15;
   int maxNewsItems = 8;
   int newsRowHeight = 18;
   int panelHeight = 30 + (maxNewsItems * newsRowHeight);
   int panelYPos = panelY + (int)(12 * gapY) + 100;  // Above signal panel
   
   // === SHADOW ===
   string objShadow = "NewsBG_Shadow";
   if(ObjectFind(0, objShadow) < 0)
   {
      ObjectCreate(0, objShadow, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objShadow, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objShadow, OBJPROP_XDISTANCE, panelX + 3);
      ObjectSetInteger(0, objShadow, OBJPROP_YDISTANCE, panelYPos - 3);
      ObjectSetInteger(0, objShadow, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, objShadow, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, objShadow, OBJPROP_BGCOLOR, C'5,5,10');
      ObjectSetInteger(0, objShadow, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objShadow, OBJPROP_BORDER_COLOR, C'5,5,10');
      ObjectSetInteger(0, objShadow, OBJPROP_ZORDER, -2);
   }
   
   // === MAIN BACKGROUND ===
   if(ObjectFind(0, ObjNewsBG) < 0)
   {
      ObjectCreate(0, ObjNewsBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_YDISTANCE, panelYPos);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_BGCOLOR, C'20,15,25');
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_BORDER_COLOR, C'80,60,100');
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, ObjNewsBG, OBJPROP_ZORDER, -1);
   }
   
   // === TOP ACCENT ===
   string objAccent = "NewsBG_Accent";
   if(ObjectFind(0, objAccent) < 0)
   {
      ObjectCreate(0, objAccent, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objAccent, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objAccent, OBJPROP_XDISTANCE, panelX + 1);
      ObjectSetInteger(0, objAccent, OBJPROP_YDISTANCE, panelYPos - 1);
      ObjectSetInteger(0, objAccent, OBJPROP_XSIZE, panelWidth - 2);
      ObjectSetInteger(0, objAccent, OBJPROP_YSIZE, 3);
      ObjectSetInteger(0, objAccent, OBJPROP_BGCOLOR, C'255,100,50');
      ObjectSetInteger(0, objAccent, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objAccent, OBJPROP_BORDER_COLOR, C'255,100,50');
      ObjectSetInteger(0, objAccent, OBJPROP_ZORDER, 1);
   }
   
   // === TITLE ===
   int titleY = panelYPos - 8;
   string currList = "";
   for(int i = 0; i < ArraySize(g_FilterCurrencies); i++)
   {
      if(i > 0) currList += "/";
      currList += g_FilterCurrencies[i];
   }
   
   if(ObjectFind(0, ObjNewsTitle) < 0)
   {
      ObjectCreate(0, ObjNewsTitle, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ObjNewsTitle, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   }
   ObjectSetInteger(0, ObjNewsTitle, OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, ObjNewsTitle, OBJPROP_YDISTANCE, titleY);
   ObjectSetString(0, ObjNewsTitle, OBJPROP_TEXT, "📰 NEWS [" + currList + "]");
   ObjectSetInteger(0, ObjNewsTitle, OBJPROP_COLOR, C'255,180,100');
   ObjectSetInteger(0, ObjNewsTitle, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, ObjNewsTitle, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, ObjNewsTitle, OBJPROP_ZORDER, 20);
}

//+------------------------------------------------------------------+
//| UPDATE NEWS DISPLAY                                                |
//+------------------------------------------------------------------+
void UpdateNewsDisplay()
{
   if(!InpEnableNews) return;
   
   int maxNewsItems = 8;
   int newsRowHeight = 18;
   int panelYPos = panelY + (int)(12 * gapY) + 90;
   int startY = panelYPos - 28;
   
   // Clear old news labels
   ObjectsDeleteAll(0, "NewsRow_");
   
   int displayCount = MathMin(ArraySize(g_NewsEvents), maxNewsItems);
   
   if(displayCount == 0)
   {
      // Show "No News" message
      string objName = "NewsRow_0";
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      }
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, panelX + 15);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, startY);
      ObjectSetString(0, objName, OBJPROP_TEXT, "No upcoming news for " + _Symbol);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 15);
      return;
   }
   
   // Display news items
   for(int i = 0; i < displayCount; i++)
   {
      int yPos = startY - (i * newsRowHeight);
      
      // Impact icon
      string iconObj = "NewsRow_Icon_" + IntegerToString(i);
      if(ObjectFind(0, iconObj) < 0)
      {
         ObjectCreate(0, iconObj, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, iconObj, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      }
      ObjectSetInteger(0, iconObj, OBJPROP_XDISTANCE, panelX + 8);
      ObjectSetInteger(0, iconObj, OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, iconObj, OBJPROP_TEXT, GetImpactIcon(g_NewsEvents[i].impact));
      ObjectSetInteger(0, iconObj, OBJPROP_COLOR, GetImpactColor(g_NewsEvents[i].impact));
      ObjectSetInteger(0, iconObj, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, iconObj, OBJPROP_ZORDER, 15);
      
      // Time remaining
      string timeObj = "NewsRow_Time_" + IntegerToString(i);
      string timeStr = FormatTimeRemaining(g_NewsEvents[i].time);
      color timeColor = g_NewsEvents[i].isPast ? clrGray : clrWhite;
      
      if(ObjectFind(0, timeObj) < 0)
      {
         ObjectCreate(0, timeObj, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, timeObj, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      }
      ObjectSetInteger(0, timeObj, OBJPROP_XDISTANCE, panelX + 25);
      ObjectSetInteger(0, timeObj, OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, timeObj, OBJPROP_TEXT, timeStr);
      ObjectSetInteger(0, timeObj, OBJPROP_COLOR, timeColor);
      ObjectSetInteger(0, timeObj, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, timeObj, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, timeObj, OBJPROP_ZORDER, 15);
      
      // Currency
      string currObj = "NewsRow_Curr_" + IntegerToString(i);
      if(ObjectFind(0, currObj) < 0)
      {
         ObjectCreate(0, currObj, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, currObj, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      }
      ObjectSetInteger(0, currObj, OBJPROP_XDISTANCE, panelX + 100);
      ObjectSetInteger(0, currObj, OBJPROP_YDISTANCE, yPos + 1);
      ObjectSetString(0, currObj, OBJPROP_TEXT, g_NewsEvents[i].currency);
      ObjectSetInteger(0, currObj, OBJPROP_COLOR, C'100,200,255');
      ObjectSetInteger(0, currObj, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, currObj, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, currObj, OBJPROP_ZORDER, 15);
      
      // News name (truncated)
      string nameObj = "NewsRow_Name_" + IntegerToString(i);
      string newsName = g_NewsEvents[i].name;
      if(StringLen(newsName) > 35)
         newsName = StringSubstr(newsName, 0, 35) + "...";
      
      if(ObjectFind(0, nameObj) < 0)
      {
         ObjectCreate(0, nameObj, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, nameObj, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      }
      ObjectSetInteger(0, nameObj, OBJPROP_XDISTANCE, panelX + 135);
      ObjectSetInteger(0, nameObj, OBJPROP_YDISTANCE, yPos + 1);
      ObjectSetString(0, nameObj, OBJPROP_TEXT, newsName);
      ObjectSetInteger(0, nameObj, OBJPROP_COLOR, g_NewsEvents[i].isPast ? clrDimGray : GetImpactColor(g_NewsEvents[i].impact));
      ObjectSetInteger(0, nameObj, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, nameObj, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, nameObj, OBJPROP_ZORDER, 15);
   }
}

//+------------------------------------------------------------------+
//| CHECK NEWS ALERTS                                                  |
//+------------------------------------------------------------------+
void CheckNewsAlerts()
{
   if(!InpEnableNews || !InpNewsAlert) return;
   
   static datetime lastAlertTime = 0;
   datetime now = TimeCurrent();
   
   for(int i = 0; i < ArraySize(g_NewsEvents); i++)
   {
      // Only alert for high impact upcoming news
      if(g_NewsEvents[i].impact != NEWS_IMPACT_HIGH) continue;
      if(g_NewsEvents[i].isPast) continue;
      
      // Calculate time until news
      long minutesUntil = (long)(g_NewsEvents[i].time - now) / 60;
      
      // Alert if within alert window and haven't alerted recently
      if(minutesUntil > 0 && minutesUntil <= InpNewsAlertMinutes)
      {
         // Avoid duplicate alerts (only alert once per news event per 5 minutes)
         if(now - lastAlertTime > 300)
         {
            lastAlertTime = now;
            Alert("⚠️ HIGH IMPACT NEWS in ", minutesUntil, " minutes!\n",
                  g_NewsEvents[i].currency, ": ", g_NewsEvents[i].name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| INITIALIZE NEWS SYSTEM                                             |
//+------------------------------------------------------------------+
void InitializeNews()
{
   if(!InpEnableNews) return;
   
   // Get currencies for current symbol
   GetCurrenciesFromSymbol(_Symbol, g_FilterCurrencies);
   
   // Log detected currencies
   string currList = "";
   for(int i = 0; i < ArraySize(g_FilterCurrencies); i++)
   {
      if(i > 0) currList += ", ";
      currList += g_FilterCurrencies[i];
   }
   Print("News Filter initialized for: ", _Symbol, " -> Currencies: ", currList);
   
   // Create news panel
   CreateNewsPanel();
   
   // Fetch initial news
   FetchNewsEvents();
   UpdateNewsDisplay();
}

//+------------------------------------------------------------------+
//| CLEANUP NEWS OBJECTS                                               |
//+------------------------------------------------------------------+
void CleanupNews()
{
   ObjectsDeleteAll(0, "News");
   ObjectsDeleteAll(0, "NewsRow_");
}

//+------------------------------------------------------------------+
//| CHART APPEARANCE SETUP                                            |
//+------------------------------------------------------------------+
void SetupChartAppearance()
{
   long chartId = ChartID();
   
   // Background color - Black
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, clrBlack);
   
   // Foreground (text) color
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, clrWhite);
   
   // Candle colors
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, clrLime);      // Bullish candle body
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, clrRed);       // Bearish candle body
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP, clrLime);         // Bullish outline/wick
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, clrRed);        // Bearish outline/wick
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE, clrWhite);      // Line chart color
   
   // Grid - Disable
   ChartSetInteger(chartId, CHART_SHOW_GRID, false);
   
   // Period Separators - Disable
   ChartSetInteger(chartId, CHART_SHOW_PERIOD_SEP, false);
   
   // Trade History (arrows) - Disable
   ChartSetInteger(chartId, CHART_SHOW_TRADE_HISTORY, false);
   
   // Additional cleanup
   ChartSetInteger(chartId, CHART_COLOR_GRID, clrBlack);            // Grid color (hidden anyway)
   ChartSetInteger(chartId, CHART_COLOR_VOLUME, clrGreen);          // Volume color
   ChartSetInteger(chartId, CHART_COLOR_ASK, clrRed);               // Ask line
   ChartSetInteger(chartId, CHART_COLOR_BID, clrBlue);              // Bid line (if shown)
   
   // Set chart mode to candlesticks
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   
   // Redraw chart
   ChartRedraw(chartId);
   
   Print("Chart appearance configured: Black background, Green/Red candles, No grid/history/period");
}