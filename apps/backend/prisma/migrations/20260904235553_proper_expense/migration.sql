-- AlterTable
ALTER TABLE "Expense" ADD COLUMN     "flightId" TEXT;

-- CreateIndex
CREATE INDEX "Expense_flightId_idx" ON "Expense"("flightId");

-- AddForeignKey
ALTER TABLE "Expense" ADD CONSTRAINT "Expense_flightId_fkey" FOREIGN KEY ("flightId") REFERENCES "Flight"("id") ON DELETE SET NULL ON UPDATE CASCADE;
