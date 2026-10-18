CREATE TABLE "FlyerDocument" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "flyerId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "contentType" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "stagingKey" TEXT NOT NULL,
    "objectKey" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "uploadedById" TEXT NOT NULL,
    "uploadedByName" TEXT NOT NULL,
    "verifiedAt" TIMESTAMP(3),
    "verifiedById" TEXT,
    "verifiedByName" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "FlyerDocument_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "FlyerDocument_flyerId_fkey" FOREIGN KEY ("flyerId") REFERENCES "Flyer"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "FlyerDocument_reference_key" ON "FlyerDocument"("reference");
CREATE UNIQUE INDEX "FlyerDocument_stagingKey_key" ON "FlyerDocument"("stagingKey");
CREATE UNIQUE INDEX "FlyerDocument_objectKey_key" ON "FlyerDocument"("objectKey");
CREATE INDEX "FlyerDocument_flyerId_status_idx" ON "FlyerDocument"("flyerId", "status");
