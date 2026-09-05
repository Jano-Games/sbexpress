/*
  Warnings:

  - You are about to drop the column `whatsapp` on the `Flyer` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Flyer" DROP COLUMN "whatsapp",
ADD COLUMN     "bdWhatsapp" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "cnAddress" TEXT NOT NULL DEFAULT '—',
ADD COLUMN     "cnWhatsapp" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "firstName" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "lastName" TEXT NOT NULL DEFAULT '';
