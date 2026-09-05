-- AlterTable
ALTER TABLE "Expense" ADD COLUMN     "accountAmount" DECIMAL(14,2),
ADD COLUMN     "accountCurrency" "Currency",
ADD COLUMN     "accountName" TEXT,
ADD COLUMN     "fxRate" DECIMAL(12,6);

-- AlterTable
ALTER TABLE "Payment" ADD COLUMN     "accountAmount" DECIMAL(14,2),
ADD COLUMN     "accountCurrency" "Currency",
ADD COLUMN     "accountName" TEXT,
ADD COLUMN     "fxRate" DECIMAL(12,6);
