import { closeDb } from '../src/core/db'
import { cleanupMedia } from '../src/shared/mediaCleanup'
try { console.log(JSON.stringify(await cleanupMedia(process.argv.includes('--execute')))) }
finally { await closeDb() }
