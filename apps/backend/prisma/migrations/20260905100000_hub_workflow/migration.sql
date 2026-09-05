-- AlterTable
ALTER TABLE "Shipment" ADD COLUMN     "flyerId" TEXT,
ADD COLUMN     "packageCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "packedAt" TIMESTAMP(3);

-- AddForeignKey
ALTER TABLE "Shipment" ADD CONSTRAINT "Shipment_flyerId_fkey" FOREIGN KEY ("flyerId") REFERENCES "Flyer"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
