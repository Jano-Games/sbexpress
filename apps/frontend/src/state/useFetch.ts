import { useCallback, useEffect, useRef, useState } from "react";
import { api, cachedRead, getToken, onReadsInvalidated } from "@/api/client";

interface ReadState<T> {
  path: string | null;
  token: string | null;
  data: T | null;
  error: string | null;
  refreshing: boolean;
}

/** Show a recent snapshot while revalidating. Writes refresh all mounted readers. */
export function useFetch<T>(path: string | null) {
  const token = getToken();
  const [state, setState] = useState<ReadState<T>>(() => ({
    path, token, data: path ? cachedRead<T>(path) : null,
    error: null, refreshing: Boolean(path),
  }));
  const generation = useRef(0);

  const load = useCallback(async () => {
    const mine = ++generation.current;
    if (!path || getToken() !== token) {
      setState({ path, token, data: null, error: null, refreshing: false });
      return;
    }
    setState((previous) => ({
      path, token,
      data: previous.path === path && previous.token === token
        ? previous.data : cachedRead<T>(path),
      error: null, refreshing: true,
    }));
    try {
      const result = await api.get<T>(path);
      if (generation.current === mine && getToken() === token)
        setState({ path, token, data: result, error: null, refreshing: false });
    } catch (error) {
      if (generation.current === mine && getToken() === token)
        setState((previous) => ({
          ...previous, error: error instanceof Error ? error.message : "Request failed",
          refreshing: false,
        }));
    }
  }, [path, token]);

  useEffect(() => {
    const unsubscribe = onReadsInvalidated(() => { void load(); });
    void load();
    return () => { generation.current++; unsubscribe(); };
  }, [load]);

  // Never show the previous record or account during a path/session transition.
  const current = state.path === path && state.token === token;
  const data = current ? state.data : path ? cachedRead<T>(path) : null;
  const error = current ? state.error : null;
  const refreshing = current ? state.refreshing : Boolean(path);
  return {
    data, error,
    loading: Boolean(path) && data === null && !error,
    refreshing,
    reload: load,
  };
}
