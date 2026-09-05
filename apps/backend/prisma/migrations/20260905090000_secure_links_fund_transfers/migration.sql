-- AlterTable
ALTER TABLE "Flight" ADD COLUMN     "agencyShare" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "flyerPaidAmount" DECIMAL(12,2) NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "Payment" ADD COLUMN     "flightId" TEXT,
ADD COLUMN     "kind" TEXT NOT NULL DEFAULT 'customer';

-- CreateTable
CREATE TABLE "PublicLink" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "shipmentId" TEXT NOT NULL,
    "scope" TEXT NOT NULL,
    "requestedAmount" DECIMAL(12,2),
    "paidAtIssue" DECIMAL(12,2) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PublicLink_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FundTransfer" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "fromName" TEXT NOT NULL,
    "toName" TEXT NOT NULL,
    "fromCurrency" "Currency" NOT NULL,
    "toCurrency" "Currency" NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "receivedAmount" DECIMAL(14,2) NOT NULL,
    "note" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FundTransfer_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PublicLink_tokenHash_key" ON "PublicLink"("tokenHash");

-- CreateIndex
CREATE INDEX "PublicLink_shipmentId_idx" ON "PublicLink"("shipmentId");

-- CreateIndex
CREATE UNIQUE INDEX "FundTransfer_reference_key" ON "FundTransfer"("reference");

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_flightId_fkey" FOREIGN KEY ("flightId") REFERENCES "Flight"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PublicLink" ADD CONSTRAINT "PublicLink_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
-- Preserve the old fare field's meaning: it previously represented flyer contribution.
UPDATE "Flight" SET "agencyShare" = GREATEST(0, "actualCost" - "fare");
UPDATE "Payment" SET "kind" = 'income' WHERE "shipmentId" IS NULL;
