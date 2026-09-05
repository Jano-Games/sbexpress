-- CreateTable
CREATE TABLE "PayMethod" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "accountName" TEXT NOT NULL DEFAULT '',
    "line1" TEXT NOT NULL DEFAULT '',
    "line2" TEXT NOT NULL DEFAULT '',
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "order" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PayMethod_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PayMethod_name_key" ON "PayMethod"("name");
