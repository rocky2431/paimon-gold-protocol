"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import {
  createChart,
  ColorType,
  CrosshairMode,
  LineStyle,
  CandlestickSeries,
  HistogramSeries,
  LineSeries,
  type IChartApi,
  type ISeriesApi,
  type CandlestickData,
  type HistogramData,
  type LineData,
  type Time,
} from "lightweight-charts";

// Types
interface OHLCVData {
  time: Time;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

type TimeframeType = "1m" | "5m" | "15m" | "1h" | "4h" | "1d";

interface PriceChartProps {
  symbol?: string;
  currentPrice?: number;
  onPriceUpdate?: (price: number) => void;
}

// Generate mock historical data
function generateMockData(
  basePrice: number,
  days: number,
  timeframe: TimeframeType
): OHLCVData[] {
  const data: OHLCVData[] = [];
  const now = Math.floor(Date.now() / 1000);

  // Calculate interval in seconds based on timeframe
  const intervals: Record<TimeframeType, number> = {
    "1m": 60,
    "5m": 300,
    "15m": 900,
    "1h": 3600,
    "4h": 14400,
    "1d": 86400,
  };

  const interval = intervals[timeframe];
  const totalBars = Math.floor((days * 86400) / interval);

  let price = basePrice * 0.95; // Start slightly lower

  for (let i = totalBars; i > 0; i--) {
    const time = (now - i * interval) as Time;

    // Generate realistic price movement
    const volatility = 0.002; // 0.2% per bar
    const trend = 0.0001; // Slight upward trend
    const change = (Math.random() - 0.5) * 2 * volatility + trend;

    const open = price;
    const close = open * (1 + change);
    const high = Math.max(open, close) * (1 + Math.random() * volatility);
    const low = Math.min(open, close) * (1 - Math.random() * volatility);

    // Volume based on price movement
    const priceMove = Math.abs(close - open) / open;
    const baseVolume = 1000000 + Math.random() * 500000;
    const volume = baseVolume * (1 + priceMove * 10);

    data.push({
      time,
      open: parseFloat(open.toFixed(2)),
      high: parseFloat(high.toFixed(2)),
      low: parseFloat(low.toFixed(2)),
      close: parseFloat(close.toFixed(2)),
      volume: parseFloat(volume.toFixed(0)),
    });

    price = close;
  }

  return data;
}

// Calculate Simple Moving Average
function calculateSMA(data: OHLCVData[], period: number): LineData[] {
  const sma: LineData[] = [];

  for (let i = period - 1; i < data.length; i++) {
    let sum = 0;
    for (let j = 0; j < period; j++) {
      sum += data[i - j].close;
    }
    sma.push({
      time: data[i].time,
      value: parseFloat((sum / period).toFixed(2)),
    });
  }

  return sma;
}

// Timeframe selector component
function TimeframeSelector({
  selected,
  onSelect,
}: {
  selected: TimeframeType;
  onSelect: (tf: TimeframeType) => void;
}) {
  const timeframes: TimeframeType[] = ["1m", "5m", "15m", "1h", "4h", "1d"];

  return (
    <div className="flex gap-1">
      {timeframes.map((tf) => (
        <button
          key={tf}
          onClick={() => onSelect(tf)}
          className={`rounded px-2 py-1 text-xs font-medium transition-colors ${
            selected === tf
              ? "bg-amber-500 text-black"
              : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700 hover:text-white"
          }`}
        >
          {tf}
        </button>
      ))}
    </div>
  );
}

// Format price for display
function formatPrice(price: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(price);
}

export function PriceChart({
  symbol = "XAU/USD",
  currentPrice = 2650,
  onPriceUpdate,
}: PriceChartProps) {
  const chartContainerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const candlestickSeriesRef = useRef<ISeriesApi<"Candlestick"> | null>(null);
  const volumeSeriesRef = useRef<ISeriesApi<"Histogram"> | null>(null);
  const smaSeriesRef = useRef<ISeriesApi<"Line"> | null>(null);

  const [timeframe, setTimeframe] = useState<TimeframeType>("1h");
  const [data, setData] = useState<OHLCVData[]>([]);
  const [latestPrice, setLatestPrice] = useState(currentPrice);
  const [priceChange, setPriceChange] = useState({ value: 0, percent: 0 });
  const [showMA, setShowMA] = useState(true);

  // Initialize chart
  useEffect(() => {
    if (!chartContainerRef.current) return;

    // Create chart
    const chart = createChart(chartContainerRef.current, {
      layout: {
        background: { type: ColorType.Solid, color: "transparent" },
        textColor: "#9ca3af",
      },
      grid: {
        vertLines: { color: "#27272a" },
        horzLines: { color: "#27272a" },
      },
      crosshair: {
        mode: CrosshairMode.Normal,
        vertLine: {
          color: "#f59e0b",
          width: 1,
          style: LineStyle.Dashed,
          labelBackgroundColor: "#f59e0b",
        },
        horzLine: {
          color: "#f59e0b",
          width: 1,
          style: LineStyle.Dashed,
          labelBackgroundColor: "#f59e0b",
        },
      },
      rightPriceScale: {
        borderColor: "#27272a",
        scaleMargins: {
          top: 0.1,
          bottom: 0.2,
        },
      },
      timeScale: {
        borderColor: "#27272a",
        timeVisible: true,
        secondsVisible: false,
      },
    });

    chartRef.current = chart;

    // Create candlestick series
    const candlestickSeries = chart.addSeries(CandlestickSeries, {
      upColor: "#22c55e",
      downColor: "#ef4444",
      borderUpColor: "#22c55e",
      borderDownColor: "#ef4444",
      wickUpColor: "#22c55e",
      wickDownColor: "#ef4444",
    });
    candlestickSeriesRef.current = candlestickSeries;

    // Create volume series
    const volumeSeries = chart.addSeries(HistogramSeries, {
      color: "#f59e0b",
      priceFormat: {
        type: "volume",
      },
      priceScaleId: "",
    });
    volumeSeries.priceScale().applyOptions({
      scaleMargins: {
        top: 0.85,
        bottom: 0,
      },
    });
    volumeSeriesRef.current = volumeSeries;

    // Create SMA series
    const smaSeries = chart.addSeries(LineSeries, {
      color: "#3b82f6",
      lineWidth: 2,
      crosshairMarkerVisible: false,
      priceLineVisible: false,
    });
    smaSeriesRef.current = smaSeries;

    // Handle resize
    const handleResize = () => {
      if (chartContainerRef.current && chartRef.current) {
        chartRef.current.applyOptions({
          width: chartContainerRef.current.clientWidth,
          height: chartContainerRef.current.clientHeight,
        });
      }
    };

    window.addEventListener("resize", handleResize);
    handleResize();

    return () => {
      window.removeEventListener("resize", handleResize);
      chart.remove();
    };
  }, []);

  // Generate data based on timeframe
  useEffect(() => {
    const days = timeframe === "1d" ? 90 : timeframe === "4h" ? 30 : 7;
    const newData = generateMockData(currentPrice, days, timeframe);
    setData(newData);

    // Calculate price change
    if (newData.length > 1) {
      const firstPrice = newData[0].open;
      const lastPrice = newData[newData.length - 1].close;
      const change = lastPrice - firstPrice;
      const percent = (change / firstPrice) * 100;
      setPriceChange({ value: change, percent });
      setLatestPrice(lastPrice);
    }
  }, [timeframe, currentPrice]);

  // Update chart data
  useEffect(() => {
    if (!candlestickSeriesRef.current || !volumeSeriesRef.current || data.length === 0) return;

    // Update candlestick data
    const candleData: CandlestickData[] = data.map((d) => ({
      time: d.time,
      open: d.open,
      high: d.high,
      low: d.low,
      close: d.close,
    }));
    candlestickSeriesRef.current.setData(candleData);

    // Update volume data with colors based on price direction
    const volumeData: HistogramData[] = data.map((d) => ({
      time: d.time,
      value: d.volume,
      color: d.close >= d.open ? "rgba(34, 197, 94, 0.5)" : "rgba(239, 68, 68, 0.5)",
    }));
    volumeSeriesRef.current.setData(volumeData);

    // Update SMA data
    if (smaSeriesRef.current && showMA) {
      const smaData = calculateSMA(data, 20);
      smaSeriesRef.current.setData(smaData);
    }

    // Fit content
    if (chartRef.current) {
      chartRef.current.timeScale().fitContent();
    }
  }, [data, showMA]);

  // Toggle MA visibility
  useEffect(() => {
    if (smaSeriesRef.current) {
      smaSeriesRef.current.applyOptions({
        visible: showMA,
      });
    }
  }, [showMA]);

  // Real-time price simulation
  useEffect(() => {
    const interval = setInterval(() => {
      setData((prevData) => {
        if (prevData.length === 0) return prevData;

        const lastBar = prevData[prevData.length - 1];
        const volatility = 0.0005;
        const change = (Math.random() - 0.5) * 2 * volatility;
        const newClose = lastBar.close * (1 + change);
        const newHigh = Math.max(lastBar.high, newClose);
        const newLow = Math.min(lastBar.low, newClose);

        const updatedData = [...prevData];
        updatedData[updatedData.length - 1] = {
          ...lastBar,
          close: parseFloat(newClose.toFixed(2)),
          high: parseFloat(newHigh.toFixed(2)),
          low: parseFloat(newLow.toFixed(2)),
        };

        setLatestPrice(newClose);
        onPriceUpdate?.(newClose);

        return updatedData;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [onPriceUpdate]);

  return (
    <div className="flex h-full flex-col rounded-xl border border-zinc-800 bg-zinc-900/50">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-zinc-800 p-4">
        <div className="flex items-center gap-4">
          <div>
            <div className="flex items-center gap-2">
              <span className="text-lg font-bold">{symbol}</span>
              <span className="rounded bg-amber-500/20 px-2 py-0.5 text-xs text-amber-500">
                Gold
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-2xl font-bold">{formatPrice(latestPrice)}</span>
              <span
                className={`text-sm font-medium ${
                  priceChange.value >= 0 ? "text-green-500" : "text-red-500"
                }`}
              >
                {priceChange.value >= 0 ? "+" : ""}
                {formatPrice(priceChange.value)} ({priceChange.percent >= 0 ? "+" : ""}
                {priceChange.percent.toFixed(2)}%)
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-4">
          {/* MA Toggle */}
          <label className="flex cursor-pointer items-center gap-2">
            <span className="text-xs text-zinc-500">MA(20)</span>
            <div
              onClick={() => setShowMA(!showMA)}
              className={`relative h-5 w-9 rounded-full transition-colors ${
                showMA ? "bg-blue-500" : "bg-zinc-700"
              }`}
            >
              <div
                className={`absolute top-0.5 h-4 w-4 rounded-full bg-white transition-transform ${
                  showMA ? "left-[18px]" : "left-0.5"
                }`}
              />
            </div>
          </label>

          {/* Timeframe Selector */}
          <TimeframeSelector selected={timeframe} onSelect={setTimeframe} />
        </div>
      </div>

      {/* Chart Container */}
      <div ref={chartContainerRef} className="min-h-[300px] flex-1 sm:min-h-[400px]" />

      {/* Footer */}
      <div className="flex items-center justify-between border-t border-zinc-800 px-4 py-2 text-xs text-zinc-500">
        <div className="flex items-center gap-4">
          <span className="flex items-center gap-1">
            <span className="h-2 w-2 rounded-full bg-green-500" />
            Bullish
          </span>
          <span className="flex items-center gap-1">
            <span className="h-2 w-2 rounded-full bg-red-500" />
            Bearish
          </span>
          <span className="flex items-center gap-1">
            <span className="h-2 w-3 rounded bg-blue-500" />
            MA(20)
          </span>
        </div>
        <span>Powered by TradingView Lightweight Charts</span>
      </div>
    </div>
  );
}
