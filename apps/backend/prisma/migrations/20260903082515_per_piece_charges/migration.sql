-- AlterTable
ALTER TABLE "Shipment" ADD COLUMN     "pcsItems" JSONB NOT NULL DEFAULT '[]';
