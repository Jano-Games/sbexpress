/*
  Warnings:

  - You are about to drop the column `line1` on the `PayMethod` table. All the data in the column will be lost.
  - You are about to drop the column `line2` on the `PayMethod` table. All the data in the column will be lost.
  - You are about to drop the column `name` on the `PayMethod` table. All the data in the column will be lost.
  - Added the required column `kind` to the `PayMethod` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "PayMethodKind" AS ENUM ('mobile_banking', 'bank_account');

-- DropIndex
DROP INDEX "PayMethod_name_key";

-- AlterTable
ALTER TABLE "PayMethod" DROP COLUMN "line1",
DROP COLUMN "line2",
DROP COLUMN "name",
ADD COLUMN     "accountNumber" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "bankName" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "branch" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "district" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "kind" "PayMethodKind" NOT NULL,
ADD COLUMN     "label" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "note" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "number" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "provider" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "qrImage" TEXT;
