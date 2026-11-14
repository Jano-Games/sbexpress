-- AlterTable
ALTER TABLE "Flight" ADD COLUMN     "airlineStatus" TEXT,
ADD COLUMN     "movedOrders" JSONB,
ADD COLUMN     "statusSetAt" TIMESTAMP(3),
ADD COLUMN     "statusSetBy" TEXT,
ADD COLUMN     "trackChecks" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "trackedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "FlightLeg" ADD COLUMN     "tracking" JSONB;
