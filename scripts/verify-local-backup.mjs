import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'
import {execFileSync} from 'node:child_process'
import {randomBytes} from 'node:crypto'
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..')
const dir=path.join(root,'.local-backups/automatic')
const filename=fs.readdirSync(dir).filter(n=>/^mamun-local-\d{8}T\d{6}Z\.dump$/.test(n)).sort().at(-1)
if(!filename)throw Error('No completed automatic backup exists')
const container='sichuan-bangla-postgres', database='mamun_restore_check_'+randomBytes(8).toString('hex')
const docker=(args,options={})=>execFileSync('docker',args,{encoding:'utf8',stdio:['pipe','pipe','pipe'],...options})
if(!/^mamun_restore_check_[a-f0-9]{16}$/.test(database))throw Error('Unsafe restore target')
let created=false
try {
  docker(['exec',container,'createdb','-U','postgres',database]);created=true
  docker(['exec','-i',container,'pg_restore','-U','postgres','--dbname='+database,'--no-owner','--no-acl','--exit-on-error'],{input:fs.readFileSync(path.join(dir,filename))})
  const tables=Number(docker(['exec',container,'psql','-U','postgres','-d',database,'-tAc',"SELECT count(*) FROM pg_tables WHERE schemaname='public'"]).trim())
  const users=Number(docker(['exec',container,'psql','-U','postgres','-d',database,'-tAc','SELECT count(*) FROM "User"']).trim())
  const migrations=Number(docker(['exec',container,'psql','-U','postgres','-d',database,'-tAc','SELECT count(*) FROM _prisma_migrations WHERE finished_at IS NOT NULL']).trim())
  if(tables<30||users<1||migrations<1)throw Error('Restored database is incomplete')
  const report={verifiedAt:new Date().toISOString(),backup:filename,tables,users,migrations,isolatedRestore:true}
  fs.writeFileSync(path.join(dir,'restore-verification.json'),JSON.stringify(report,null,2))
  console.log(JSON.stringify(report))
} finally {if(created)docker(['exec',container,'dropdb','-U','postgres',database])}
