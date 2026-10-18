CREATE TABLE "ReceiptUpload" (
 "id" TEXT NOT NULL,
 "reference" TEXT NOT NULL,
 "linkHash" TEXT NOT NULL,
 "kind" TEXT NOT NULL,
 "name" TEXT NOT NULL,
 "contentType" TEXT NOT NULL,
 "size" INTEGER NOT NULL,
 "stagingKey" TEXT NOT NULL,
 "objectKey" TEXT NOT NULL,
 "status" TEXT NOT NULL DEFAULT 'pending',
 "expiresAt" TIMESTAMP(3) NOT NULL,
 "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT "ReceiptUpload_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ReceiptUpload_reference_key" ON "ReceiptUpload"("reference");
CREATE UNIQUE INDEX "ReceiptUpload_stagingKey_key" ON "ReceiptUpload"("stagingKey");
CREATE UNIQUE INDEX "ReceiptUpload_objectKey_key" ON "ReceiptUpload"("objectKey");
CREATE INDEX "ReceiptUpload_linkHash_status_idx" ON "ReceiptUpload"("linkHash", "status");
CREATE INDEX "ReceiptUpload_status_expiresAt_idx" ON "ReceiptUpload"("status", "expiresAt");
ALTER TABLE "Receipt" ADD COLUMN "screenshotReference" TEXT;
ALTER TABLE "StatementReceipt" ADD COLUMN "screenshotReference" TEXT;
CREATE UNIQUE INDEX "Receipt_screenshotReference_key" ON "Receipt"("screenshotReference");
CREATE UNIQUE INDEX "StatementReceipt_screenshotReference_key" ON "StatementReceipt"("screenshotReference");
ALTER TABLE "Receipt" ADD CONSTRAINT "Receipt_screenshotReference_fkey" FOREIGN KEY ("screenshotReference") REFERENCES "ReceiptUpload"("reference") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "StatementReceipt" ADD CONSTRAINT "StatementReceipt_screenshotReference_fkey" FOREIGN KEY ("screenshotReference") REFERENCES "ReceiptUpload"("reference") ON DELETE RESTRICT ON UPDATE CASCADE;
