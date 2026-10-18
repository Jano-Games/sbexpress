ALTER TABLE "FlightLeg" ADD COLUMN "source" TEXT NOT NULL DEFAULT 'legacy';
ALTER TABLE "User" ADD COLUMN "sessionVersion" INTEGER NOT NULL DEFAULT 0;
INSERT INTO "Todo" (id,role,text,done,auto,"statementReceiptId") SELECT 'review-statement-'||r.id,'admin','Review monthly receipt — '||s.code||' / '||l.month,false,true,r.id FROM "StatementReceipt" r JOIN "StatementLink" l ON l.id=r."linkId" JOIN "Supplier" s ON s.id=l."supplierId" WHERE r.status='pending' AND NOT EXISTS (SELECT 1 FROM "Todo" t WHERE t."statementReceiptId"=r.id);
