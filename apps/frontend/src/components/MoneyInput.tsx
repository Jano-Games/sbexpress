import { useState } from "react";
import { useFetch } from "@/state/useFetch";
import { Input } from "@/components/beui/input";
export type Currency = "BDT" | "CNY";
export function nativeMoney(amount: number, currency: string = "BDT") {
  return `${currency} ${Number(amount || 0).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}
export function useMoneyEntry(
  publicRates?: Record<string, number>,
  publicMode = false,
  enabled = true,
) {
  const { data } = useFetch<{ rates: Record<string, number> }>(
    !enabled || publicMode || publicRates ? null : "/settings/currencies",
  );
  const rates = publicRates ?? data?.rates ?? { BDT: 1 };
  const [currency, setCode] = useState<Currency>("BDT");
  const [customRate, setRate] = useState("");
  const exchangeRate =
    currency === "BDT" ? 1 : Number(customRate || rates.CNY || 0);
  function setCurrency(code: Currency) {
    setCode(code);
    setRate("");
  }
  function restore(code: Currency = "BDT", rate = 1) {
    setCode(code);
    setRate(code === "BDT" ? "" : String(rate));
  }
  return {
    currency,
    setCurrency,
    exchangeRate,
    setRate,
    rateText: customRate || (rates.CNY ? String(rates.CNY) : ""),
    valid: exchangeRate > 0 && Number.isFinite(exchangeRate),
    restore,
    meta: { money: { currency, exchangeRate } },
    toBdt: (amount: number) => Math.round(amount * exchangeRate * 100) / 100,
    fromBdt: (amount: number) =>
      exchangeRate > 0 ? Math.round((amount / exchangeRate) * 100) / 100 : 0,
    publicMode,
  };
}
export type MoneyEntry = ReturnType<typeof useMoneyEntry>;
export function CurrencyFields({
  entry,
  disabled = false,
}: {
  entry: MoneyEntry;
  disabled?: boolean;
}) {
  return (
    <div className="currency-fields">
      <label className="text-sm font-semibold text-muted-foreground">
        Currency
        <select
          aria-label="Entry currency"
          disabled={disabled || entry.publicMode}
          value={entry.currency}
          onChange={(e) => entry.setCurrency(e.target.value as Currency)}
          className="form-control mt-1"
        >
          <option value="BDT">BDT · Taka</option>
          <option value="CNY">CNY · Yuan</option>
        </select>
      </label>
      {entry.currency === "CNY" && (
        <label className="min-w-0 flex-1 text-sm font-semibold text-muted-foreground">
          BDT per 1 CNY
          <input
            aria-label="BDT per 1 CNY"
            inputMode="decimal"
            readOnly={entry.publicMode || disabled}
            value={entry.rateText}
            onChange={(e) => entry.setRate(e.target.value)}
            className="form-control mt-1"
            placeholder="Exchange rate"
          />
        </label>
      )}
    </div>
  );
}
export function MoneyInput({
  entry,
  label,
  value,
  onChange,
  placeholder,
  disabled = false,
}: {
  entry: MoneyEntry;
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
}) {
  return (
    <div className="money-input">
      <CurrencyFields entry={entry} disabled={disabled} />
      <Input
        label={`${label} (${entry.currency})`}
        inputMode="decimal"
        value={value}
        onChange={onChange}
        placeholder={placeholder ?? "0.00"}
        disabled={disabled}
      />
      {entry.currency === "CNY" && (
        <p className="text-sm text-muted-foreground">
          {entry.valid
            ? `${nativeMoney(entry.toBdt(Number(value) || 0))} · rate saved with this entry`
            : "Set a valid exchange rate to continue."}
        </p>
      )}
    </div>
  );
}
