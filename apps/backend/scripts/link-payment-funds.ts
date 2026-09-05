import { atomicMutation, prisma, closeDb } from '../src/core/db'
try {
 const count=await atomicMutation(async()=>{
   const {linkBankFund}=await import('../src/shared/bankAccounts')
   const methods=await prisma.payMethod.findMany({where:{accountId:null},orderBy:{createdAt:'asc'}})
   for(const method of methods) await linkBankFund(method)
   return methods.length
 })
 console.log(`Linked ${count} existing payment method(s) to funds; existing balances preserved.`)
}finally{await closeDb()}
