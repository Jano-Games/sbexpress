import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/utils";
export type ButtonVariant =
  | "primary"
  | "secondary"
  | "ghost"
  | "outline"
  | "dark"
  | "success"
  | "danger"
  | "danger-outline";
export type ButtonSize = "sm" | "md" | "lg" | "icon";
export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
}
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  function Button(
    { variant = "primary", size = "md", className, type = "button", ...props },
    ref,
  ) {
    return (
      <button
        ref={ref}
        type={type}
        className={cn(
          "control-button",
          "button-" + variant,
          "button-" + size,
          className,
        )}
        {...props}
      />
    );
  },
);
