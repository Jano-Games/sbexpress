-- AlterTable
ALTER TABLE "Shipment" ADD COLUMN     "chargeCurrency" "Currency" NOT NULL DEFAULT 'BDT',
ADD COLUMN     "chargeRate" DECIMAL(12,2) NOT NULL DEFAULT 0;
