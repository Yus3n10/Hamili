export default {
  async scheduled(controller, env) {
    const started = Date.now();
    const res = await fetch(env.HEALTH_URL, { signal: AbortSignal.timeout(90_000) });
    const seconds = ((Date.now() - started) / 1000).toFixed(1);
    if (!res.ok) {
      // Throwing marks the invocation as failed in the Cron Events log.
      throw new Error(`health check returned HTTP ${res.status} after ${seconds}s`);
    }
    console.log(`health check returned HTTP ${res.status} in ${seconds}s`);
  },
};
