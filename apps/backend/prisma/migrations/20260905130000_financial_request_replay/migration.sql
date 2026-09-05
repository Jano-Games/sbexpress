-- CreateTable
CREATE TABLE "FinancialRequest" (
    "key" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "requestHash" TEXT NOT NULL,
    "response" JSONB NOT NULL,
    "status" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FinancialRequest_pkey" PRIMARY KEY ("key")
);
