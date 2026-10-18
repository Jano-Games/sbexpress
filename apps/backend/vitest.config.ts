import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Run the browser client's pure tests with this workspace's shared Vitest runner.
    include: ['test/**/*.test.ts', '../frontend/test/**/*.test.ts'],
  },
})
