import {
  forwardRef,
  useId,
  type InputHTMLAttributes,
  type ReactNode,
} from "react";
import { cn } from "@/lib/utils";
export interface InputProps
  extends Omit<
    InputHTMLAttributes<HTMLInputElement>,
    "value" | "defaultValue" | "onChange"
  > {
  label?: string;
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  error?: string | boolean;
  leftIcon?: ReactNode;
  fieldClassName?: string;
  inputClassName?: string;
}
export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  {
    label,
    value,
    defaultValue,
    onChange,
    error,
    leftIcon,
    fieldClassName,
    inputClassName,
    className,
    id,
    ...props
  },
  ref,
) {
  const generated = useId(),
    inputId = id ?? generated,
    errorId = inputId + "-error";
  return (
    <div className={cn("input-field", fieldClassName, className)}>
      {label && <label htmlFor={inputId}>{label}</label>}
      <div className={cn("input-wrap", leftIcon && "input-with-icon")}>
        {leftIcon && <span className="input-icon">{leftIcon}</span>}
        <input
          {...props}
          ref={ref}
          id={inputId}
          value={value}
          defaultValue={defaultValue}
          onChange={(event) => onChange?.(event.target.value)}
          aria-invalid={error ? true : undefined}
          aria-describedby={
            typeof error === "string" ? errorId : props["aria-describedby"]
          }
          className={cn("form-control", inputClassName)}
        />
      </div>
      {typeof error === "string" && (
        <p id={errorId} className="field-error">
          {error}
        </p>
      )}
    </div>
  );
});
