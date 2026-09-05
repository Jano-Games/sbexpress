/**
 * Create or update a staff account:
 *   pnpm --filter backend create-user <email> "<name>" <admin|hub> <password>
 *
 * An existing email gets its name/role/password updated — so this doubles as
 * a password reset.
 */

import { hash } from '@node-rs/argon2'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL ?? '' })
const prisma = new PrismaClient({ adapter })

async function main() {
  const [email, name, role, password] = process.argv.slice(2)
  if (!email || !name || (role !== 'admin' && role !== 'hub') || !password) {
    console.error('Usage: pnpm --filter backend create-user <email> "<name>" <admin|hub> <password>')
    process.exitCode = 1
    return
  }

  const passwordHash = await hash(password)
  const user = await prisma.user.upsert({
    where: { email: email.toLowerCase() },
    update: { name, role, passwordHash },
    create: { email: email.toLowerCase(), name, role, passwordHash },
  })
  console.log(`[create-user] ${user.email} (${user.role}) ready`)
}

main()
  .catch((error) => {
    console.error('[create-user] failed:', error)
    process.exitCode = 1
  })
  .finally(() => prisma.$disconnect())
