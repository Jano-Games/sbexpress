-- CreateTable
CREATE TABLE "FlightLeg" (
    "id" TEXT NOT NULL,
    "flightId" TEXT NOT NULL,
    "order" INTEGER NOT NULL,
    "code" TEXT NOT NULL,
    "fromIata" TEXT NOT NULL DEFAULT '',
    "fromCity" TEXT NOT NULL DEFAULT '',
    "toIata" TEXT NOT NULL DEFAULT '',
    "toCity" TEXT NOT NULL DEFAULT '',
    "depTime" TEXT NOT NULL DEFAULT '—',
    "arrTime" TEXT NOT NULL DEFAULT '—',

    CONSTRAINT "FlightLeg_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FlightLeg_flightId_order_idx" ON "FlightLeg"("flightId", "order");

-- AddForeignKey
ALTER TABLE "FlightLeg" ADD CONSTRAINT "FlightLeg_flightId_fkey" FOREIGN KEY ("flightId") REFERENCES "Flight"("id") ON DELETE CASCADE ON UPDATE CASCADE;
