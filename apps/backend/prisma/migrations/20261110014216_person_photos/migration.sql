-- CreateTable
CREATE TABLE "PersonPhoto" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "ownerType" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "contentType" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "stagingKey" TEXT NOT NULL,
    "objectKey" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "uploadedById" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PersonPhoto_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PersonPhoto_reference_key" ON "PersonPhoto"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "PersonPhoto_stagingKey_key" ON "PersonPhoto"("stagingKey");

-- CreateIndex
CREATE UNIQUE INDEX "PersonPhoto_objectKey_key" ON "PersonPhoto"("objectKey");

-- CreateIndex
CREATE INDEX "PersonPhoto_ownerType_ownerId_status_idx" ON "PersonPhoto"("ownerType", "ownerId", "status");
