-- AlterTable
ALTER TABLE "Supplier" ADD COLUMN     "creditBalance" DECIMAL(12,2) NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "FlightFlyer" ADD COLUMN     "contribution" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "paidAmount" DECIMAL(12,2) NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "ShipmentMedia" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "shipmentId" TEXT NOT NULL,
    "stagingKey" TEXT NOT NULL,
    "objectKey" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "contentType" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "shared" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShipmentMedia_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomerCredit" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "kind" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "shipmentCode" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CustomerCredit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomerRefund" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "reason" TEXT NOT NULL,
    "accountName" TEXT NOT NULL,
    "accountCurrency" "Currency" NOT NULL,
    "accountAmount" DECIMAL(14,2) NOT NULL,
    "fxRate" DECIMAL(12,6) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CustomerRefund_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InvoiceRevision" (
    "id" TEXT NOT NULL,
    "invoiceId" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "snapshot" JSONB NOT NULL,
    "reason" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InvoiceRevision_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CreditNote" (
    "id" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "shipmentId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "reason" TEXT NOT NULL,
    "previousTotal" DECIMAL(12,2) NOT NULL,
    "revisedTotal" DECIMAL(12,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CreditNote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StatementLink" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "month" TEXT NOT NULL,
    "requestedAmount" DECIMAL(12,2),
    "paidAtIssue" DECIMAL(12,2) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StatementLink_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StatementReceipt" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "linkId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "method" TEXT NOT NULL,
    "txnRef" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StatementReceipt_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ShipmentMedia_reference_key" ON "ShipmentMedia"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "ShipmentMedia_stagingKey_key" ON "ShipmentMedia"("stagingKey");

-- CreateIndex
CREATE UNIQUE INDEX "ShipmentMedia_objectKey_key" ON "ShipmentMedia"("objectKey");

-- CreateIndex
CREATE INDEX "ShipmentMedia_shipmentId_status_idx" ON "ShipmentMedia"("shipmentId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "CustomerCredit_reference_key" ON "CustomerCredit"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "CustomerRefund_reference_key" ON "CustomerRefund"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "InvoiceRevision_invoiceId_version_key" ON "InvoiceRevision"("invoiceId", "version");

-- CreateIndex
CREATE UNIQUE INDEX "CreditNote_number_key" ON "CreditNote"("number");

-- CreateIndex
CREATE UNIQUE INDEX "StatementLink_tokenHash_key" ON "StatementLink"("tokenHash");

-- CreateIndex
CREATE UNIQUE INDEX "StatementReceipt_reference_key" ON "StatementReceipt"("reference");

-- AddForeignKey
ALTER TABLE "ShipmentMedia" ADD CONSTRAINT "ShipmentMedia_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CustomerCredit" ADD CONSTRAINT "CustomerCredit_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CustomerRefund" ADD CONSTRAINT "CustomerRefund_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InvoiceRevision" ADD CONSTRAINT "InvoiceRevision_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CreditNote" ADD CONSTRAINT "CreditNote_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StatementLink" ADD CONSTRAINT "StatementLink_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StatementReceipt" ADD CONSTRAINT "StatementReceipt_linkId_fkey" FOREIGN KEY ("linkId") REFERENCES "StatementLink"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Preserve the pre-upgrade invoice as revision 1; do not fabricate older history.
INSERT INTO "InvoiceRevision" ("id","invoiceId","version","snapshot","reason","createdAt")
SELECT 'baseline-' || "id", "id", 1, jsonb_build_object('number',"number",'lines',"lines",'discount',"discount",'total',"total",'note',"note"), 'Imported current invoice at upgrade', CURRENT_TIMESTAMP FROM "Invoice";
-- Only a single-flyer booking has unambiguous historical attribution.
UPDATE "FlightFlyer" ff SET "contribution" = GREATEST(0,f."actualCost"-f."agencyShare"), "paidAmount"=f."flyerPaidAmount"
FROM "Flight" f WHERE ff."flightId"=f."id" AND (SELECT COUNT(*) FROM "FlightFlyer" x WHERE x."flightId"=f."id")=1;
ALTER TABLE "Supplier" ADD CONSTRAINT "Supplier_credit_nonnegative" CHECK ("creditBalance">=0);
ALTER TABLE "FlightFlyer" ADD CONSTRAINT "Flyer_settlement_valid" CHECK ("paidAmount">=0 AND "contribution">="paidAmount");
ALTER TABLE "ShipmentMedia" ADD CONSTRAINT "Media_size_positive" CHECK ("size">0 AND "size"<=104857600);
