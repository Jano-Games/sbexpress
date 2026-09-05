-- AlterTable
ALTER TABLE "Expense" ADD COLUMN     "costField" TEXT;

-- Existing bookings with exactly one flyer have an unambiguous carrier.
UPDATE "Shipment" s SET "flyerId" = x."flyerId"
FROM (SELECT "flightId", MIN("flyerId") AS "flyerId" FROM "FlightFlyer" GROUP BY "flightId" HAVING COUNT(*) = 1) x
WHERE s."flightId" = x."flightId" AND s."flyerId" IS NULL;
