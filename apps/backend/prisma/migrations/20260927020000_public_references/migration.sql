ALTER TABLE "Receipt" ADD COLUMN "reference" TEXT;
UPDATE "Receipt" SET "reference" = gen_random_uuid()::text;
ALTER TABLE "Receipt" ALTER COLUMN "reference" SET NOT NULL;
CREATE UNIQUE INDEX "Receipt_reference_key" ON "Receipt"("reference");

ALTER TABLE "PayMethod" ADD COLUMN "publicReference" TEXT;
UPDATE "PayMethod" SET "publicReference" = gen_random_uuid()::text;
ALTER TABLE "PayMethod" ALTER COLUMN "publicReference" SET NOT NULL;
CREATE UNIQUE INDEX "PayMethod_publicReference_key" ON "PayMethod"("publicReference");
