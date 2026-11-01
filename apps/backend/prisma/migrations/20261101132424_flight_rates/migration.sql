-- AlterTable
ALTER TABLE "Flight" ADD COLUMN     "kgRate" DECIMAL(12,2),
ADD COLUMN     "kgRateCurrency" "Currency",
ADD COLUMN     "pcsRates" JSONB;
