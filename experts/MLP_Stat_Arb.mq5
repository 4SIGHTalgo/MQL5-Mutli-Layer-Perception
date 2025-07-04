//+------------------------------------------------------------------+|
//|  © 2025 FSA Quant Labs                                            |
//+------------------------------------------------------------------+|
#property strict
#property copyright "© 2025 FSA Quant Labs"
#property version   "3.10"

#include <Trade\Trade.mqh>
#include <Math\Stat\Stat.mqh>

CTrade trade;

//--- EA SETTINGS ---
input group "Pair Scanning & Selection"
input double InpMinCorrelationForTrading = 0.7; // Min abs correlation to consider a pair tradeable
input int    InpScannerUpdateHours       = 4;    // How often to re-scan all pairs (in hours)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Calculation Settings (Multi-Lookback)"
input int    InpLookbackShort     = 20;       // Short-term analysis window
input int    InpLookbackMid       = 50;       // Medium-term analysis window
input int    InpLookbackLong      = 100;      // Long-term analysis window
input int    InpLagPeriod         = 4;        // Lag for the time-lagged correlation
input int    InpScalingLookback   = 200;      // Bars to look back for Min/Max feature scaling

input group "Trade & Exit Settings"
input double InpLotSize           = 0.1;      // Lot size for each trade
input int    InpMagicNumber       = 3007;     // Magic number for trades
input double InpTakeProfitUSD     = 1000;     // Take Profit for the spread in account currency (e.g., USD)
input double InpStopLossUSD       = 1000;     // Stop Loss for the spread in account currency (e.g., USD)
input int    InpMaxHoldBars       = 24000;       // Max number of bars to hold a trade
input double InpCorrelationExitThreshold = 0.3; // Exit if long-term Pearson correlation drops below this

input group "MLP Settings"
input double InpMLPSignalThreshold = 1.2; // Confidence level to open a trade


//  Updated Neural-Net Weights & Biases  •  6 → 8 → 5 → 3 topology
//───────────────────────────────────────────────────────────────────

input group "Weights: Input (6) → Hidden-1 (8)"
input double inp_W1_11=0.0, inp_W1_12=0.0, inp_W1_13=0.0, inp_W1_14=0.0, inp_W1_15=0.0, inp_W1_16=0.0, inp_W1_17=0.0, inp_W1_18=0.0;
input double inp_W1_21=0.0, inp_W1_22=0.0, inp_W1_23=0.0, inp_W1_24=0.0, inp_W1_25=0.0, inp_W1_26=0.0, inp_W1_27=0.0, inp_W1_28=0.0;
input double inp_W1_31=0.0, inp_W1_32=0.0, inp_W1_33=0.0, inp_W1_34=0.0, inp_W1_35=0.0, inp_W1_36=0.0, inp_W1_37=0.0, inp_W1_38=0.0;
input double inp_W1_41=0.0, inp_W1_42=0.0, inp_W1_43=0.0, inp_W1_44=0.0, inp_W1_45=0.0, inp_W1_46=0.0, inp_W1_47=0.0, inp_W1_48=0.0;
input double inp_W1_51=0.0, inp_W1_52=0.0, inp_W1_53=0.0, inp_W1_54=0.0, inp_W1_55=0.0, inp_W1_56=0.0, inp_W1_57=0.0, inp_W1_58=0.0;
input double inp_W1_61=0.0, inp_W1_62=0.0, inp_W1_63=0.0, inp_W1_64=0.0, inp_W1_65=0.0, inp_W1_66=0.0, inp_W1_67=0.0, inp_W1_68=0.0;

input group "Biases: Hidden-1 (8)"
input double inp_b1_1=-0.4, inp_b1_2= 0.7, inp_b1_3=-0.9, inp_b1_4= 0.6, inp_b1_5=-0.4, inp_b1_6=-0.8, inp_b1_7=-0.9, inp_b1_8=-1.0;

input group "Weights: Hidden-1 (8) → Hidden-2 (5)"
input double inp_W2_11=0.0, inp_W2_12=0.0, inp_W2_13=0.0, inp_W2_14=0.0, inp_W2_15=0.0;
input double inp_W2_21=0.0, inp_W2_22=0.0, inp_W2_23=0.0, inp_W2_24=0.0, inp_W2_25=0.0;
input double inp_W2_31=0.0, inp_W2_32=0.0, inp_W2_33=0.0, inp_W2_34=0.0, inp_W2_35=0.0;
input double inp_W2_41=0.0, inp_W2_42=0.0, inp_W2_43=0.0, inp_W2_44=0.0, inp_W2_45=0.0;
input double inp_W2_51=0.0, inp_W2_52=0.0, inp_W2_53=0.0, inp_W2_54=0.0, inp_W2_55=0.0;
input double inp_W2_61=0.0, inp_W2_62=0.0, inp_W2_63=0.0, inp_W2_64=0.0, inp_W2_65=0.0;
input double inp_W2_71=0.0, inp_W2_72=0.0, inp_W2_73=0.0, inp_W2_74=0.0, inp_W2_75=0.0;
input double inp_W2_81=0.0, inp_W2_82=0.0, inp_W2_83=0.0, inp_W2_84=0.0, inp_W2_85=0.0;

input group "Biases: Hidden-2 (5)"
input double inp_b2_1=-1.0, inp_b2_2= 0.2, inp_b2_3= 0.9, inp_b2_4=-0.7, inp_b2_5=-0.7;

input group "Weights: Hidden-2 (5) → Output (3)"
input double inp_W3_11=0.0, inp_W3_12=0.0, inp_W3_13=0.0;
input double inp_W3_21=0.0, inp_W3_22=0.0, inp_W3_23=0.0;
input double inp_W3_31=0.0, inp_W3_32=0.0, inp_W3_33=0.0;
input double inp_W3_41=0.0, inp_W3_42=0.0, inp_W3_43=0.0;
input double inp_W3_51=0.0, inp_W3_52=0.0, inp_W3_53=0.0;

input group "Biases: Output-Layer (3)"
input double inp_b3_1= 0.8, inp_b3_2=-0.6, inp_b3_3= 0.8;
//───────────────────────────────────────────────────────────────────

//--- GLOBAL VARS ---
struct CTradeablePair
  {
   string            symbol1;
   string            symbol2;
   bool              is_tradeable;
   int               open_bar_index;
   double            feature_min[6];
   double            feature_max[6];
  };
CTradeablePair g_tradeable_pairs[];
int g_total_possible_pairs = 0;
string g_major_pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCAD", "USDCHF", "AUDUSD", "NZDUSD"};

//+------------------------------------------------------------------+
//| MLP Functions (Dynamically populates weights from inputs)        |
//+------------------------------------------------------------------+
double ReLU(double x) { return MathMax(0, x); }
void MLP_ForwardPass(double &features[], double &output[])   /* Unchanged */
  {
   double mlp_W1[6][8], mlp_b1[8], mlp_W2[8][5], mlp_b2[5], mlp_W3[5][3], mlp_b3[3];
   mlp_W1[0][0]=inp_W1_11;
   mlp_W1[0][1]=inp_W1_12;
   mlp_W1[0][2]=inp_W1_13;
   mlp_W1[0][3]=inp_W1_14;
   mlp_W1[0][4]=inp_W1_15;
   mlp_W1[0][5]=inp_W1_16;
   mlp_W1[0][6]=inp_W1_17;
   mlp_W1[0][7]=inp_W1_18;
   mlp_W1[1][0]=inp_W1_21;
   mlp_W1[1][1]=inp_W1_22;
   mlp_W1[1][2]=inp_W1_23;
   mlp_W1[1][3]=inp_W1_24;
   mlp_W1[1][4]=inp_W1_25;
   mlp_W1[1][5]=inp_W1_26;
   mlp_W1[1][6]=inp_W1_27;
   mlp_W1[1][7]=inp_W1_28;
   mlp_W1[2][0]=inp_W1_31;
   mlp_W1[2][1]=inp_W1_32;
   mlp_W1[2][2]=inp_W1_33;
   mlp_W1[2][3]=inp_W1_34;
   mlp_W1[2][4]=inp_W1_35;
   mlp_W1[2][5]=inp_W1_36;
   mlp_W1[2][6]=inp_W1_37;
   mlp_W1[2][7]=inp_W1_38;
   mlp_W1[3][0]=inp_W1_41;
   mlp_W1[3][1]=inp_W1_42;
   mlp_W1[3][2]=inp_W1_43;
   mlp_W1[3][3]=inp_W1_44;
   mlp_W1[3][4]=inp_W1_45;
   mlp_W1[3][5]=inp_W1_46;
   mlp_W1[3][6]=inp_W1_47;
   mlp_W1[3][7]=inp_W1_48;
   mlp_W1[4][0]=inp_W1_51;
   mlp_W1[4][1]=inp_W1_52;
   mlp_W1[4][2]=inp_W1_53;
   mlp_W1[4][3]=inp_W1_54;
   mlp_W1[4][4]=inp_W1_55;
   mlp_W1[4][5]=inp_W1_56;
   mlp_W1[4][6]=inp_W1_57;
   mlp_W1[4][7]=inp_W1_58;
   mlp_W1[5][0]=inp_W1_61;
   mlp_W1[5][1]=inp_W1_62;
   mlp_W1[5][2]=inp_W1_63;
   mlp_W1[5][3]=inp_W1_64;
   mlp_W1[5][4]=inp_W1_65;
   mlp_W1[5][5]=inp_W1_66;
   mlp_W1[5][6]=inp_W1_67;
   mlp_W1[5][7]=inp_W1_68;
   mlp_b1[0]=inp_b1_1;
   mlp_b1[1]=inp_b1_2;
   mlp_b1[2]=inp_b1_3;
   mlp_b1[3]=inp_b1_4;
   mlp_b1[4]=inp_b1_5;
   mlp_b1[5]=inp_b1_6;
   mlp_b1[6]=inp_b1_7;
   mlp_b1[7]=inp_b1_8;
   mlp_W2[0][0]=inp_W2_11;
   mlp_W2[0][1]=inp_W2_12;
   mlp_W2[0][2]=inp_W2_13;
   mlp_W2[0][3]=inp_W2_14;
   mlp_W2[0][4]=inp_W2_15;
   mlp_W2[1][0]=inp_W2_21;
   mlp_W2[1][1]=inp_W2_22;
   mlp_W2[1][2]=inp_W2_23;
   mlp_W2[1][3]=inp_W2_24;
   mlp_W2[1][4]=inp_W2_25;
   mlp_W2[2][0]=inp_W2_31;
   mlp_W2[2][1]=inp_W2_32;
   mlp_W2[2][2]=inp_W2_33;
   mlp_W2[2][3]=inp_W2_34;
   mlp_W2[2][4]=inp_W2_35;
   mlp_W2[3][0]=inp_W2_41;
   mlp_W2[3][1]=inp_W2_42;
   mlp_W2[3][2]=inp_W2_43;
   mlp_W2[3][3]=inp_W2_44;
   mlp_W2[3][4]=inp_W2_45;
   mlp_W2[4][0]=inp_W2_51;
   mlp_W2[4][1]=inp_W2_52;
   mlp_W2[4][2]=inp_W2_53;
   mlp_W2[4][3]=inp_W2_54;
   mlp_W2[4][4]=inp_W2_55;
   mlp_W2[5][0]=inp_W2_61;
   mlp_W2[5][1]=inp_W2_62;
   mlp_W2[5][2]=inp_W2_63;
   mlp_W2[5][3]=inp_W2_64;
   mlp_W2[5][4]=inp_W2_65;
   mlp_W2[6][0]=inp_W2_71;
   mlp_W2[6][1]=inp_W2_72;
   mlp_W2[6][2]=inp_W2_73;
   mlp_W2[6][3]=inp_W2_74;
   mlp_W2[6][4]=inp_W2_75;
   mlp_W2[7][0]=inp_W2_81;
   mlp_W2[7][1]=inp_W2_82;
   mlp_W2[7][2]=inp_W2_83;
   mlp_W2[7][3]=inp_W2_84;
   mlp_W2[7][4]=inp_W2_85;
   mlp_b2[0]=inp_b2_1;
   mlp_b2[1]=inp_b2_2;
   mlp_b2[2]=inp_b2_3;
   mlp_b2[3]=inp_b2_4;
   mlp_b2[4]=inp_b2_5;
   mlp_W3[0][0]=inp_W3_11;
   mlp_W3[0][1]=inp_W3_12;
   mlp_W3[0][2]=inp_W3_13;
   mlp_W3[1][0]=inp_W3_21;
   mlp_W3[1][1]=inp_W3_22;
   mlp_W3[1][2]=inp_W3_23;
   mlp_W3[2][0]=inp_W3_31;
   mlp_W3[2][1]=inp_W3_32;
   mlp_W3[2][2]=inp_W3_33;
   mlp_W3[3][0]=inp_W3_41;
   mlp_W3[3][1]=inp_W3_42;
   mlp_W3[3][2]=inp_W3_43;
   mlp_W3[4][0]=inp_W3_51;
   mlp_W3[4][1]=inp_W3_52;
   mlp_W3[4][2]=inp_W3_53;
   mlp_b3[0]=inp_b3_1;
   mlp_b3[1]=inp_b3_2;
   mlp_b3[2]=inp_b3_3;
   double h1[8],h2[5];
   for(int j=0;j<8;j++)
     {
      h1[j]=0;
      for(int i=0;i<6;i++)
         h1[j]+=features[i]*mlp_W1[i][j];
      h1[j]=ReLU(h1[j]+mlp_b1[j]);
     }
   for(int j=0;j<5;j++)
     {
      h2[j]=0;
      for(int i=0;i<8;i++)
         h2[j]+=h1[i]*mlp_W2[i][j];
      h2[j]=ReLU(h2[j]+mlp_b2[j]);
     }
   for(int j=0;j<3;j++)
     {
      output[j]=0;
      for(int i=0;i<5;i++)
         output[j]+=h2[i]*mlp_W3[i][j];
      output[j]+=mlp_b3[j];
     }
  }

//+------------------------------------------------------------------+
//| Feature Calculation & Scaling (Now Pair-Specific)                |
//+------------------------------------------------------------------+
bool GetPriceData(string symbol, int lookback, double &prices[])
  {
   ArrayResize(prices,lookback);
   int copied=CopyClose(symbol,PERIOD_CURRENT,1,lookback,prices);
   ArrayReverse(prices);
   return(copied==lookback);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateLaggedCorrelation(double &arr1[], double &arr2[], int lookback, int lag)
  {
   if(ArraySize(arr1)!=lookback||ArraySize(arr2)!=lookback||lag>=lookback)
      return 0;
   double lagged_arr1[],main_arr2[];
   int data_size=lookback-lag;
   ArrayResize(lagged_arr1,data_size);
   ArrayResize(main_arr2,data_size);
   ArrayCopy(lagged_arr1,arr1,0,0,data_size);
   ArrayCopy(main_arr2,arr2,0,lag,data_size);
   double correlation;
   if(!MathCorrelationPearson(lagged_arr1,main_arr2,correlation))
      return 0;
   return correlation;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateFeatureScalingParameters(CTradeablePair &pair)
  {
   for(int i=0; i<6; i++)
     {
      pair.feature_min[i]=DBL_MAX;
      pair.feature_max[i]=-DBL_MAX;
     }
   for(int bar=1; bar<InpScalingLookback; bar++)
     {
      double s1_s[],s2_s[],s1_m[],s2_m[],s1_l[],s2_l[];
      int c_s = CopyClose(pair.symbol1,PERIOD_CURRENT,bar,InpLookbackShort,s1_s)+CopyClose(pair.symbol2,PERIOD_CURRENT,bar,InpLookbackShort,s2_s);
      int c_m = CopyClose(pair.symbol1,PERIOD_CURRENT,bar,InpLookbackMid,s1_m)+CopyClose(pair.symbol2,PERIOD_CURRENT,bar,InpLookbackMid,s2_m);
      int c_l = CopyClose(pair.symbol1,PERIOD_CURRENT,bar,InpLookbackLong,s1_l)+CopyClose(pair.symbol2,PERIOD_CURRENT,bar,InpLookbackLong,s2_l);
      if(c_s<InpLookbackShort*2||c_m<InpLookbackMid*2||c_l<InpLookbackLong*2)
         continue;
      ArrayReverse(s1_s);
      ArrayReverse(s2_s);
      ArrayReverse(s1_m);
      ArrayReverse(s2_m);
      ArrayReverse(s1_l);
      ArrayReverse(s2_l);
      double p_s,p_m,p_l,features[6];
      MathCorrelationPearson(s1_s,s2_s,p_s);
      MathCorrelationPearson(s1_m,s2_m,p_m);
      MathCorrelationPearson(s1_l,s2_l,p_l);
      features[0]=p_s;
      features[1]=CalculateLaggedCorrelation(s1_s,s2_s,InpLookbackShort,InpLagPeriod);
      features[2]=p_m;
      features[3]=CalculateLaggedCorrelation(s1_m,s2_m,InpLookbackMid,InpLagPeriod);
      features[4]=p_l;
      features[5]=CalculateLaggedCorrelation(s1_l,s2_l,InpLookbackLong,InpLagPeriod);
      for(int i=0;i<6;i++)
        {
         if(features[i]<pair.feature_min[i])
            pair.feature_min[i]=features[i];
         if(features[i]>pair.feature_max[i])
            pair.feature_max[i]=features[i];
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NormalizeFeatures(double &raw_features[], double &scaled_features[], CTradeablePair &pair)
  {
   for(int i=0;i<6;i++)
     {
      double range=pair.feature_max[i]-pair.feature_min[i];
      scaled_features[i]=(range>1e-10)?(raw_features[i]-pair.feature_min[i])/range:0.5;
     }
  }

//+------------------------------------------------------------------+
//| Trade & Exit Logic                                               |
//+------------------------------------------------------------------+
int GetOpenPositions(ulong &tickets[], string &symbols[])
  {
   int count=0;
   ArrayResize(tickets,0);
   ArrayResize(symbols,0);
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
        {
         ArrayResize(tickets,count+1);
         ArrayResize(symbols,count+1);
         tickets[count]=ticket;
         symbols[count]=PositionGetString(POSITION_SYMBOL);
         count++;
        }
     }
   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsLegInUse(string symbol_to_check, string &open_symbols[], int total_open)
  {
// FIX: Changed loop variable to int to fix sign mismatch
   for(int i=0; i<total_open; i++)
     {
      if(open_symbols[i] == symbol_to_check)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseSpreadTrades(string s1, string s2, string reason)
  {
   ulong open_tickets[];
   string open_symbols[];
   int total_open = GetOpenPositions(open_tickets, open_symbols);
// FIX: Changed loop variable to int to fix sign mismatch
   for(int i=0; i<total_open; i++)
     {
      if(open_symbols[i] == s1 || open_symbols[i] == s2)
        {
         trade.PositionClose(open_tickets[i]);
        }
     }
   PrintFormat("Closing Spread %s/%s: %s", s1, s2, reason);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenSpreadTrade(CTradeablePair &pair, ENUM_ORDER_TYPE dir_s1, ENUM_ORDER_TYPE dir_s2)
  {
   PrintFormat("MLP Signal: Opening %s/%s spread.", pair.symbol1, pair.symbol2);
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action=TRADE_ACTION_DEAL;
   request.magic=InpMagicNumber;
   request.deviation=10;
   request.volume=InpLotSize;
   request.symbol=pair.symbol1;
   request.type=dir_s1;
   request.price=(dir_s1==ORDER_TYPE_BUY)?SymbolInfoDouble(pair.symbol1,SYMBOL_ASK):SymbolInfoDouble(pair.symbol1,SYMBOL_BID);
   trade.OrderSend(request, result);
   request.symbol=pair.symbol2;
   request.type=dir_s2;
   request.price=(dir_s2==ORDER_TYPE_BUY)?SymbolInfoDouble(pair.symbol2,SYMBOL_ASK):SymbolInfoDouble(pair.symbol2,SYMBOL_BID);
   trade.OrderSend(request, result);
   pair.open_bar_index=(int)SeriesInfoInteger(pair.symbol1,PERIOD_CURRENT,SERIES_BARS_COUNT)-1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckExitConditions()
  {
   ulong open_tickets[];
   string open_symbols[];
   int total_open = GetOpenPositions(open_tickets, open_symbols);
   if(total_open == 0)
      return;

   for(int i=0; i<g_total_possible_pairs; i++)
     {
      bool s1_open=false, s2_open=false;
      double pair_profit = 0;
      ulong p1_ticket = 0, p2_ticket = 0;
      // FIX: Changed loop variable to int to fix sign mismatch
      for(int p=0; p<total_open; p++)
        {
         if(open_symbols[p] == g_tradeable_pairs[i].symbol1)
           {
            s1_open=true;
            if(PositionSelectByTicket(open_tickets[p]))
               pair_profit+=PositionGetDouble(POSITION_PROFIT);
           }
         if(open_symbols[p] == g_tradeable_pairs[i].symbol2)
           {
            s2_open=true;
            if(PositionSelectByTicket(open_tickets[p]))
               pair_profit+=PositionGetDouble(POSITION_PROFIT);
           }
        }
      if(s1_open && s2_open)
        {
         if(InpTakeProfitUSD>0 && pair_profit>=InpTakeProfitUSD)
           {
            CloseSpreadTrades(g_tradeable_pairs[i].symbol1,g_tradeable_pairs[i].symbol2,"Take Profit");
            return;
           }
         if(InpStopLossUSD>0 && pair_profit<=-InpStopLossUSD)
           {
            CloseSpreadTrades(g_tradeable_pairs[i].symbol1,g_tradeable_pairs[i].symbol2,"Stop Loss");
            return;
           }
         static datetime last_bar_check[];
         ArrayResize(last_bar_check, g_total_possible_pairs);
         datetime current_bar_time=(datetime)SeriesInfoInteger(g_tradeable_pairs[i].symbol1,PERIOD_CURRENT,SERIES_LASTBAR_DATE);
         if(current_bar_time==last_bar_check[i])
            continue;
         last_bar_check[i]=current_bar_time;
         int current_bar_index=(int)SeriesInfoInteger(g_tradeable_pairs[i].symbol1,PERIOD_CURRENT,SERIES_BARS_COUNT)-1;
         if(InpMaxHoldBars>0 && g_tradeable_pairs[i].open_bar_index>0 && (current_bar_index-g_tradeable_pairs[i].open_bar_index)>=InpMaxHoldBars)
           {
            // FIX: Corrected typo from g_trade_pairs to g_tradeable_pairs
            CloseSpreadTrades(g_tradeable_pairs[i].symbol1,g_tradeable_pairs[i].symbol2,"Max Hold");
            return;
           }
         double prices1[],prices2[];
         double long_term_pearson;
         if(GetPriceData(g_tradeable_pairs[i].symbol1,InpLookbackLong,prices1)&&GetPriceData(g_tradeable_pairs[i].symbol2,InpLookbackLong,prices2) &&
            MathCorrelationPearson(prices1,prices2,long_term_pearson) && long_term_pearson<InpCorrelationExitThreshold)
           {
            // FIX: Corrected typo from g_trade_pairs to g_tradeable_pairs
            CloseSpreadTrades(g_tradeable_pairs[i].symbol1,g_tradeable_pairs[i].symbol2,"Correlation Breakdown");
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTradeablePairs()
  {
   Print("--- Starting Correlation Scan ---");
   int tradeable_count = 0;
   for(int i=0; i<g_total_possible_pairs; i++)
     {
      double prices1[], prices2[];
      if(!GetPriceData(g_tradeable_pairs[i].symbol1, InpLookbackLong, prices1) || !GetPriceData(g_tradeable_pairs[i].symbol2, InpLookbackLong, prices2))
        {
         g_tradeable_pairs[i].is_tradeable = false;
         continue;
        }
      double correlation;
      if(MathCorrelationPearson(prices1, prices2, correlation))
        {
         if(MathAbs(correlation) >= InpMinCorrelationForTrading)
           {
            g_tradeable_pairs[i].is_tradeable = true;
            UpdateFeatureScalingParameters(g_tradeable_pairs[i]);
            PrintFormat("%s/%s is tradeable (Corr: %.4f). Scaling parameters updated.", g_tradeable_pairs[i].symbol1, g_tradeable_pairs[i].symbol2, correlation);
            tradeable_count++;
           }
         else
           {
            g_tradeable_pairs[i].is_tradeable = false;
           }
        }
     }
   PrintFormat("--- Scan Complete. Found %d tradeable pairs. ---", tradeable_count);
  }

//+------------------------------------------------------------------+
//| Main EA Event Handlers                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckExitConditions();

   static datetime last_scanner_update = 0;
   if(TimeCurrent() - last_scanner_update > InpScannerUpdateHours * 3600)
     {
      UpdateTradeablePairs();
      last_scanner_update = TimeCurrent();
     }

   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(g_major_pairs[0], PERIOD_CURRENT, SERIES_LASTBAR_DATE);
   if(current_bar_time == last_bar_time)
      return;
   last_bar_time = current_bar_time;

   ulong open_tickets[];
   string open_symbols[];
   int total_open = GetOpenPositions(open_tickets, open_symbols);

   for(int i=0; i<g_total_possible_pairs; i++)
     {
      if(!g_tradeable_pairs[i].is_tradeable)
         continue;
      if(IsLegInUse(g_tradeable_pairs[i].symbol1, open_symbols, total_open) || IsLegInUse(g_tradeable_pairs[i].symbol2, open_symbols, total_open))
         continue;

      double s1_s[],s2_s[],s1_m[],s2_m[],s1_l[],s2_l[];
      if(!GetPriceData(g_tradeable_pairs[i].symbol1,InpLookbackShort,s1_s)||!GetPriceData(g_tradeable_pairs[i].symbol2,InpLookbackShort,s2_s)||
         !GetPriceData(g_tradeable_pairs[i].symbol1,InpLookbackMid,s1_m)||!GetPriceData(g_tradeable_pairs[i].symbol2,InpLookbackMid,s2_m)||
         !GetPriceData(g_tradeable_pairs[i].symbol1,InpLookbackLong,s1_l)||!GetPriceData(g_tradeable_pairs[i].symbol2,InpLookbackLong,s2_l))
         continue;

      double raw_f[6],p_s,p_m,p_l;
      MathCorrelationPearson(s1_s,s2_s,p_s);
      MathCorrelationPearson(s1_m,s2_m,p_m);
      MathCorrelationPearson(s1_l,s2_l,p_l);
      raw_f[0]=p_s;
      raw_f[1]=CalculateLaggedCorrelation(s1_s,s2_s,InpLookbackShort,InpLagPeriod);
      raw_f[2]=p_m;
      raw_f[3]=CalculateLaggedCorrelation(s1_m,s2_m,InpLookbackMid,InpLagPeriod);
      raw_f[4]=p_l;
      raw_f[5]=CalculateLaggedCorrelation(s1_l,s2_l,InpLookbackLong,InpLagPeriod);

      double scaled_f[6];
      NormalizeFeatures(raw_f, scaled_f, g_tradeable_pairs[i]);

      double mlp_output[3];
      MLP_ForwardPass(scaled_f, mlp_output);

      int best_signal=-1;
      double max_output=-DBL_MAX;
      for(int s=0;s<3;s++)
         if(mlp_output[s]>max_output)
           {
            max_output=mlp_output[s];
            best_signal=s;
           }
      if(max_output<InpMLPSignalThreshold)
         continue;

      switch(best_signal)
        {
         case 0:
            OpenSpreadTrade(g_tradeable_pairs[i],ORDER_TYPE_BUY,ORDER_TYPE_SELL);
            return;
         case 1:
            OpenSpreadTrade(g_tradeable_pairs[i],ORDER_TYPE_SELL,ORDER_TYPE_BUY);
            return;
         case 2:
            break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   int majors_count = ArraySize(g_major_pairs);
   g_total_possible_pairs = majors_count * (majors_count-1) / 2;
   ArrayResize(g_tradeable_pairs, g_total_possible_pairs);
   int pair_idx=0;
   for(int i=0; i<majors_count; i++)
     {
      for(int j=i+1; j<majors_count; j++)
        {
         g_tradeable_pairs[pair_idx].symbol1 = g_major_pairs[i];
         g_tradeable_pairs[pair_idx].symbol2 = g_major_pairs[j];
         g_tradeable_pairs[pair_idx].is_tradeable = false;
         g_tradeable_pairs[pair_idx].open_bar_index = -1;
         pair_idx++;
        }
     }
   Print("Initialized. EA will now scan for initial correlations...");
   UpdateTradeablePairs();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+