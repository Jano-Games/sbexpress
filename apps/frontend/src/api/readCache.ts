/** Short-lived, memory-only snapshots. Every fetch still revalidates with the server. */
interface Entry {
  data?: unknown;
  updatedAt?: number;
  promise?: Promise<unknown>;
}

export class ReadCache {
  private entries = new Map<string, Entry>();
  private listeners = new Set<() => void>();
  private revision = 0;

  peek<T>(key: string): T | null {
    const entry = this.entries.get(key);
    if (!entry?.updatedAt || Date.now() - entry.updatedAt > 60_000) return null;
    return (entry.data as T) ?? null;
  }

  fetch<T>(key: string, loader: () => Promise<T>): Promise<T> {
    const existing = this.entries.get(key);
    if (existing?.promise) return existing.promise as Promise<T>;
    const entry: Entry = existing ?? {};
    const revision = this.revision;
    const promise = Promise.resolve().then(loader).then(
      (data) => {
        // A read that began before a write/session change cannot restore an old snapshot.
        if (revision === this.revision && this.entries.get(key) === entry) {
          entry.data = data;
          entry.updatedAt = Date.now();
        }
        return data;
      },
      (error: unknown) => {
        if (this.entries.get(key) === entry) this.entries.delete(key);
        throw error;
      },
    ).finally(() => {
      if (entry.promise === promise) delete entry.promise;
      // Bound memory when many detail screens have been visited.
      for (const [oldKey, oldEntry] of this.entries) {
        if (this.entries.size <= 100) break;
        if (!oldEntry.promise) this.entries.delete(oldKey);
      }
    });
    entry.promise = promise;
    this.entries.set(key, entry);
    return promise;
  }

  invalidate(): void {
    this.revision++;
    this.entries.clear();
    for (const listener of this.listeners) listener();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }
}
