ALTER TABLE "PayMethod" ADD COLUMN "accountId" TEXT;
CREATE UNIQUE INDEX "PayMethod_accountId_key" ON "PayMethod"("accountId");
ALTER TABLE "PayMethod" ADD CONSTRAINT "PayMethod_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "Account"("id") ON DELETE SET NULL ON UPDATE CASCADE;
