import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm'],
  target: 'node20',
  platform: 'node',
  clean: true,
  // Native and generated modules must never be bundled: @node-rs/argon2 ships
  // platform binaries and @prisma/client is generated at install time. Both
  // are resolved from node_modules at runtime instead.
  deps: {
    neverBundle: ['@prisma/client', '.prisma/client', '@node-rs/argon2'],
  },
})
