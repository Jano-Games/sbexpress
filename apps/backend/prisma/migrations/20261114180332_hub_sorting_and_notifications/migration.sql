-- AlterTable
ALTER TABLE "Shipment" ADD COLUMN     "approvedAt" TIMESTAMP(3),
ADD COLUMN     "approvedBy" TEXT,
ADD COLUMN     "arrivedNote" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "hubNote" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "sentBackAt" TIMESTAMP(3),
ADD COLUMN     "sentBackBy" TEXT,
ADD COLUMN     "sentBackNote" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "sortedAt" TIMESTAMP(3),
ADD COLUMN     "sortedBy" TEXT;

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "event" TEXT NOT NULL,
    "roles" "UserRole"[],
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "params" JSONB NOT NULL DEFAULT '{}',
    "flightCode" TEXT,
    "shipmentCode" TEXT,
    "customerCode" TEXT,
    "dedupeKey" TEXT,
    "readBy" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "pushSentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Notification_dedupeKey_key" ON "Notification"("dedupeKey");

-- CreateIndex
CREATE INDEX "Notification_createdAt_idx" ON "Notification"("createdAt");
