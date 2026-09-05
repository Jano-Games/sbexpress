-- AlterEnum
ALTER TYPE "PayStatus" ADD VALUE 'partial';

-- AlterTable
ALTER TABLE "Payment" ADD COLUMN     "shipmentId" TEXT;

-- AlterTable
ALTER TABLE "Shipment" ADD COLUMN     "paidAmount" DECIMAL(12,2) NOT NULL DEFAULT 0;

-- CreateIndex
CREATE INDEX "Payment_shipmentId_idx" ON "Payment"("shipmentId");

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE SET NULL ON UPDATE CASCADE;
