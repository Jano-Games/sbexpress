import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL ?? '' }) })
try {
  for (const [key, value] of Object.entries({rate:'17.05',threshold:'1',investBdt:'0',investCny:'0'})) {
    await prisma.setting.upsert({where:{key},update:{},create:{key,value}})
  }
  console.log('Missing default settings initialized. Existing data and staff accounts preserved.')
} finally { await prisma.$disconnect() }
