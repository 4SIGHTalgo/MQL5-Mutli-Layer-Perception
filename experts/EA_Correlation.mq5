//+------------------------------------------------------------------+
//|                                               EA Correlation.mq5 |
//|                                                      Aleksej1966 |
//|                        https://www.mql5.com/en/users/aleksej1966 |
//+------------------------------------------------------------------+
#property copyright "Aleksej1966"
#property link      "https://www.mql5.com/en/users/aleksej1966"
#property version   "1.00"

enum type_cor {Pearson,Spearman};

input type_cor Correlation=Pearson;
input string SecSymbol="USDCHF";
input ushort iPeriod=80;
input uchar SignalOpen=25;
input double Lot=0;

ushort period=5;
int cnt=0,perc=33;
double correlation[],arr1[][2],arr2[][2],denom,point1,point2,lot1,lot2;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   period=MathMax(period,iPeriod);

   ArrayResize(correlation,cnt,10000);

   perc=MathMin(perc,SignalOpen);

   ArrayResize(arr1,period);
   ArrayResize(arr2,period);

   denom=period*(period*period-1);

   point1=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   point2=SymbolInfoDouble(SecSymbol,SYMBOL_POINT);

   double lot_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
          lot_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
          pv1=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE)*point1/SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),
          pv2=SymbolInfoDouble(SecSymbol,SYMBOL_TRADE_TICK_VALUE)*point2/SymbolInfoDouble(SecSymbol,SYMBOL_TRADE_TICK_SIZE);

   lot1=lot_min+MathMax(0,(int)MathRound((Lot-lot_min)/lot_step))*lot_step;
   lot1=MathMin(lot1,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));

   lot_min=SymbolInfoDouble(SecSymbol,SYMBOL_VOLUME_MIN);
   lot_step=SymbolInfoDouble(SecSymbol,SYMBOL_VOLUME_STEP);

   lot2=lot1*pv1/pv2;
   lot2=lot_min+MathMax(0,(int)MathRound((lot2-lot_min)/lot_step))*lot_step;
   lot2=MathMin(lot2,SymbolInfoDouble(SecSymbol,SYMBOL_VOLUME_MAX));

   int bars=MathMin(iBars(_Symbol,PERIOD_CURRENT),iBars(SecSymbol,PERIOD_CURRENT))-period-1;
   for(int i=bars; i>=0; i--)
      CalcSignal(i);

   NewBar();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(NewBar()==true)
     {
      int signal=CalcSignal(0);
      if(signal>=0)
         PutPosition(signal);

      if(signal==-1)
         BreakEven();

      if(signal==-2)
         ClosePosition();
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CalcSignal(int bar)
  {
//---
   static double last_r;
   int signal=-3;
   double sum0=0,sum1=0,sum2=0,sum3=0,sum4=0,r=0;

//calculate current correlation
   if(Correlation==Pearson)
     {
      for(int i=0; i<period; i++)
        {
         int pos=bar+i;
         double p1=MathRound(iOpen(_Symbol,PERIOD_CURRENT,pos)/point1),
                p2=MathRound(iOpen(SecSymbol,PERIOD_CURRENT,pos)/point2);

         sum0=sum0+p1*p2;
         sum1=sum1+p1;
         sum2=sum2+p2;
         sum3=sum3+p1*p1;
         sum4=sum4+p2*p2;
        }

      r=(period*sum0-sum1*sum2)/MathSqrt((period*sum3-sum1*sum1)*(period*sum4-sum2*sum2));
      r=r*(2*period-r*r-5)/(2*period-6);
     }
   else
     {
      for(int i=0; i<period; i++)
        {
         int pos=bar+i;
         arr1[i][0]=MathRound(iOpen(_Symbol,PERIOD_CURRENT,pos)/point1);
         arr1[i][1]=i;
         arr2[i][0]=MathRound(iOpen(SecSymbol,PERIOD_CURRENT,pos)/point2);
         arr2[i][1]=i;
         sum1=sum1+arr1[i][0];
         sum2=sum2+arr2[i][0];
        }

      ArraySort(arr1);
      ArraySort(arr2);

      for(int i=0; i<period; i++)
         for(int j=0; j<period; j++)
            if(arr1[i][1]==arr2[j][1])
              {
               int d=i-j;
               sum0=sum0+d*d;
               break;
              }

      r=(denom-6*sum0)/denom;
     }

//gather statistics
   ArrayResize(correlation,cnt+1);
   correlation[cnt]=r;
   cnt++;

//calculate levels and signals
   if(bar==0)
     {
      ArraySort(correlation);

      double lvl0=correlation[perc*cnt/100],//position open level
             lvl1=correlation[cnt/3],//breakeven level
             lvl2=MathMin(correlation[2*cnt/3],0);//position close level

      if(r<lvl0 && r>=last_r)
        {
         if(sum1*point1>period*iOpen(_Symbol,PERIOD_CURRENT,0) && sum2*point2<period*iOpen(SecSymbol,PERIOD_CURRENT,0))
            signal=0;
         if(sum1*point1<period*iOpen(_Symbol,PERIOD_CURRENT,0) && sum2*point2>period*iOpen(SecSymbol,PERIOD_CURRENT,0))
            signal=1;
        }

      if(r>lvl1)
         signal=-1;

      if(r>lvl2)
         signal=-2;
     }

   last_r=r;
   return(signal);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition()
  {
//---
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      if(symbol==_Symbol || symbol==SecSymbol)
        {
         ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         MqlTradeRequest request;
         MqlTradeResult result;
         request.action=TRADE_ACTION_DEAL;
         request.position=PositionGetInteger(POSITION_TICKET);
         request.symbol=symbol;
         request.volume=PositionGetDouble(POSITION_VOLUME);
         request.deviation=MathMax(5,SymbolInfoInteger(symbol,SYMBOL_SPREAD)/2);
         if(type==POSITION_TYPE_BUY)
           {
            request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
            request.type =ORDER_TYPE_SELL;
           }
         else
           {
            request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
           }
         if(OrderSend(request,result)==false)
            PrintFormat("OrderSend error #",GetLastError());
        }
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BreakEven()
  {
//---
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      if(symbol==_Symbol || symbol==SecSymbol)
        {
         MqlTradeRequest request= {};
         MqlTradeResult result= {};
         request.action=TRADE_ACTION_SLTP;
         request.position=PositionGetInteger(POSITION_TICKET);
         request.symbol=symbol;

         double point=SymbolInfoDouble(symbol,SYMBOL_POINT),
                lvl=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)*point,
                cur_sl=PositionGetDouble(POSITION_SL);

         if(lvl==0)
            lvl=MathMax(5,SymbolInfoInteger(symbol,SYMBOL_SPREAD))*point;
         if(cur_sl==0)
            cur_sl=PositionGetDouble(POSITION_PRICE_OPEN);

         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            double sl=PositionGetDouble(POSITION_PRICE_CURRENT)-lvl;
            if(sl>cur_sl)
              {
               request.sl=sl;
               if(OrderSend(request,result)==false)
                  Print("OrderSend error #",GetLastError());
              }
           }
         else
           {
            double sl=PositionGetDouble(POSITION_PRICE_CURRENT)+lvl;
            if(sl<cur_sl)
              {
               request.sl=sl;
               if(OrderSend(request,result)==false)
                  Print("OrderSend error #",GetLastError());
              }
           }
        }
     }
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PutPosition(int t)
  {
//---
   ENUM_ORDER_TYPE type1= t==0? ORDER_TYPE_BUY:ORDER_TYPE_SELL,
                   type2= t==0? ORDER_TYPE_SELL:ORDER_TYPE_BUY;

   double price1= t==0? SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID),
          price2= t==0? SymbolInfoDouble(SecSymbol,SYMBOL_BID):SymbolInfoDouble(SecSymbol,SYMBOL_ASK),
          margin1,margin2;

   if(OrderCalcMargin(type1,_Symbol,lot1,price1,margin1)==false || OrderCalcMargin(type2,SecSymbol,lot2,price2,margin2)==false)
      return;

   if(margin1+margin2>=AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      Print("Not enough money");
      return;
     }

   MqlTradeRequest request= {};
   MqlTradeResult result= {};
   request.action=TRADE_ACTION_DEAL;
   request.symbol=_Symbol;
   request.volume=lot1;
   request.type=type1;
   request.price=price1;
   request.deviation=MathMax(5,SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)/2);
   if(OrderSend(request,result)==false)
     {
      Print("OrderSend error #",GetLastError());
      return;
     }

   ZeroMemory(request);
   ZeroMemory(result);
   request.action=TRADE_ACTION_DEAL;
   request.symbol=SecSymbol;
   request.volume=lot2;
   request.type=type2;
   request.price=price2;
   request.deviation=MathMax(5,SymbolInfoInteger(SecSymbol,SYMBOL_SPREAD)/2);
   if(OrderSend(request,result)==false)
      Print("OrderSend error #",GetLastError());
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewBar()
  {
//---
   static long last_bar1,last_bar2;
   long cur_bar1=SeriesInfoInteger(_Symbol,PERIOD_CURRENT,SERIES_LASTBAR_DATE),
        cur_bar2=SeriesInfoInteger(SecSymbol,PERIOD_CURRENT,SERIES_LASTBAR_DATE);

   if(last_bar1<cur_bar1 && last_bar2<cur_bar2)
     {
      last_bar1=cur_bar1;
      last_bar2=cur_bar2;
      return(true);
     }

   return(false);
//---
  }
//+------------------------------------------------------------------+
