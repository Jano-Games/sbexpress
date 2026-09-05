-- CreateEnum
CREATE TYPE "SupplierTerms" AS ENUM ('instant', 'monthly');

-- CreateEnum
CREATE TYPE "FlightStatus" AS ENUM ('upcoming', 'departed', 'completed');

-- CreateEnum
CREATE TYPE "ShipmentStatus" AS ENUM ('pending', 'received_cn_hub', 'ready_for_shipment', 'in_transit', 'customs_cleared', 'received_bd_hub', 'ready_for_last_mile', 'out_for_delivery', 'delivered');

-- CreateEnum
CREATE TYPE "PayStatus" AS ENUM ('paid', 'unpaid', 'cod', 'monthly');

-- CreateEnum
CREATE TYPE "ReceiptStatus" AS ENUM ('pending', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "AccountKind" AS ENUM ('cash', 'mobile', 'bank', 'wallet', 'fund');

-- CreateEnum
CREATE TYPE "Currency" AS ENUM ('BDT', 'CNY');

-- CreateEnum
CREATE TYPE "ExpenseCategory" AS ENUM ('ticket', 'packaging', 'courier', 'salary', 'transport', 'customs', 'others');

-- CreateEnum
CREATE TYPE "TodoRole" AS ENUM ('admin', 'hub');

-- CreateTable
CREATE TABLE "Supplier" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL DEFAULT '—',
    "address" TEXT NOT NULL DEFAULT '—',
    "terms" "SupplierTerms" NOT NULL DEFAULT 'instant',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Supplier_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Flyer" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "cnPhone" TEXT NOT NULL DEFAULT '—',
    "bdPhone" TEXT NOT NULL DEFAULT '—',
    "whatsapp" BOOLEAN NOT NULL DEFAULT false,
    "university" TEXT NOT NULL DEFAULT '—',
    "batch" TEXT NOT NULL DEFAULT '—',
    "program" TEXT NOT NULL DEFAULT '—',
    "wechat" TEXT NOT NULL DEFAULT '—',
    "homeAddress" TEXT NOT NULL DEFAULT '—',
    "emergencyContact" TEXT NOT NULL DEFAULT '—',
    "docStudentId" BOOLEAN NOT NULL DEFAULT false,
    "docVisa" BOOLEAN NOT NULL DEFAULT false,
    "docAdmission" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Flyer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Flight" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "depTime" TEXT NOT NULL DEFAULT '—',
    "arrTime" TEXT NOT NULL DEFAULT '—',
    "via" TEXT NOT NULL DEFAULT 'Direct',
    "fare" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "actualCost" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "spaceKg" INTEGER NOT NULL DEFAULT 44,
    "status" "FlightStatus" NOT NULL DEFAULT 'upcoming',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Flight_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FlightFlyer" (
    "flightId" TEXT NOT NULL,
    "flyerId" TEXT NOT NULL,

    CONSTRAINT "FlightFlyer_pkey" PRIMARY KEY ("flightId","flyerId")
);

-- CreateTable
CREATE TABLE "Shipment" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "flightId" TEXT,
    "bookedKg" DECIMAL(10,1) NOT NULL DEFAULT 0,
    "weighedKg" DECIMAL(10,1),
    "description" TEXT NOT NULL DEFAULT '—',
    "categories" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "serials" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "charge" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "status" "ShipmentStatus" NOT NULL DEFAULT 'pending',
    "payStatus" "PayStatus" NOT NULL DEFAULT 'unpaid',
    "payMethod" TEXT,
    "cnFare" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "bdFare" DECIMAL(12,2),
    "customsTax" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "afterSalesFee" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "lastMileCourier" TEXT,
    "lastMileRef" TEXT,
    "photosCount" INTEGER NOT NULL DEFAULT 0,
    "hasVideo" BOOLEAN NOT NULL DEFAULT false,
    "trackToken" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Shipment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShipmentLog" (
    "id" TEXT NOT NULL,
    "shipmentId" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShipmentLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Receipt" (
    "id" TEXT NOT NULL,
    "shipmentId" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "status" "ReceiptStatus" NOT NULL DEFAULT 'pending',
    "txnRef" TEXT NOT NULL DEFAULT '',
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Receipt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Account" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "kind" "AccountKind" NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'BDT',
    "balance" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Account_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Expense" (
    "id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "category" "ExpenseCategory" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "reason" TEXT NOT NULL,
    "shipmentId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Expense_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Payment" (
    "id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "method" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "reference" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Payment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Todo" (
    "id" TEXT NOT NULL,
    "role" "TodoRole" NOT NULL,
    "text" TEXT NOT NULL,
    "auto" BOOLEAN NOT NULL DEFAULT false,
    "done" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Todo_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Category" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "Category_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Setting" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,

    CONSTRAINT "Setting_pkey" PRIMARY KEY ("key")
);

-- CreateIndex
CREATE UNIQUE INDEX "Supplier_code_key" ON "Supplier"("code");

-- CreateIndex
CREATE UNIQUE INDEX "Flyer_name_key" ON "Flyer"("name");

-- CreateIndex
CREATE UNIQUE INDEX "Flight_code_key" ON "Flight"("code");

-- CreateIndex
CREATE UNIQUE INDEX "Shipment_code_key" ON "Shipment"("code");

-- CreateIndex
CREATE UNIQUE INDEX "Shipment_trackToken_key" ON "Shipment"("trackToken");

-- CreateIndex
CREATE INDEX "Shipment_supplierId_idx" ON "Shipment"("supplierId");

-- CreateIndex
CREATE INDEX "Shipment_flightId_idx" ON "Shipment"("flightId");

-- CreateIndex
CREATE INDEX "Shipment_status_idx" ON "Shipment"("status");

-- CreateIndex
CREATE INDEX "ShipmentLog_shipmentId_at_idx" ON "ShipmentLog"("shipmentId", "at");

-- CreateIndex
CREATE UNIQUE INDEX "Receipt_shipmentId_key" ON "Receipt"("shipmentId");

-- CreateIndex
CREATE INDEX "Expense_date_idx" ON "Expense"("date");

-- CreateIndex
CREATE INDEX "Payment_date_idx" ON "Payment"("date");

-- CreateIndex
CREATE UNIQUE INDEX "Category_name_key" ON "Category"("name");

-- AddForeignKey
ALTER TABLE "FlightFlyer" ADD CONSTRAINT "FlightFlyer_flightId_fkey" FOREIGN KEY ("flightId") REFERENCES "Flight"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FlightFlyer" ADD CONSTRAINT "FlightFlyer_flyerId_fkey" FOREIGN KEY ("flyerId") REFERENCES "Flyer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shipment" ADD CONSTRAINT "Shipment_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shipment" ADD CONSTRAINT "Shipment_flightId_fkey" FOREIGN KEY ("flightId") REFERENCES "Flight"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShipmentLog" ADD CONSTRAINT "ShipmentLog_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Receipt" ADD CONSTRAINT "Receipt_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Expense" ADD CONSTRAINT "Expense_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "Shipment"("id") ON DELETE SET NULL ON UPDATE CASCADE;
