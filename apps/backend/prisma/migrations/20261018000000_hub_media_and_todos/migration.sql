-- AlterTable
ALTER TABLE "ShipmentMedia" ADD COLUMN "purpose" TEXT NOT NULL DEFAULT 'general';
ALTER TABLE "ShipmentMedia" ADD COLUMN "deviceKey" TEXT;

-- AlterTable
ALTER TABLE "Todo" ADD COLUMN "triggerKey" TEXT;
ALTER TABLE "Todo" ADD COLUMN "shipmentCode" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Todo_triggerKey_key" ON "Todo"("triggerKey");
