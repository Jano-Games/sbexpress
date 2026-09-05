import { AsyncLocalStorage } from 'node:async_hooks'
import { PrismaClient, type Prisma } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { config } from './config'
const client = new PrismaClient({ adapter: new PrismaPg({ connectionString: config.databaseUrl }), log: ['warn', 'error'] })
const context = new AsyncLocalStorage<Prisma.TransactionClient>()
export const prisma = new Proxy(client, {
  get(target, key) {
    const tx = context.getStore()
    if (tx && key === '$transaction') {
      return (work: ((db: Prisma.TransactionClient) => Promise<unknown>) | Promise<unknown>[]) => typeof work === 'function' ? work(tx) : Promise.all(work)
    }
    const db = tx ?? target
    const value = Reflect.get(db, key)
    return typeof value === 'function' ? value.bind(db) : value
  },
})
/** Serialize agency writes across server processes, before reading balances.
 * Payment, receipt, account, audit log and supplier allocations commit together.
 */
export async function atomicMutation<T>(work: () => Promise<T>): Promise<T> {
  if (context.getStore()) return work()
  return client.$transaction(async (tx) => {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(739215084)`
    return context.run(tx, work)
  }, { maxWait: 10000, timeout: 30000 })
}
export async function closeDb() { await client.$disconnect() }
