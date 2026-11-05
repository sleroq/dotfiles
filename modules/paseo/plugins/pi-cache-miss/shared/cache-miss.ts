import { z } from "zod";

export const cacheMissSchema = z.object({
  model: z.string(),
  cacheRead: z.number().nonnegative(),
  previousCached: z.number().positive(),
  promptTokens: z.number().positive(),
});

export type CacheMiss = z.infer<typeof cacheMissSchema>;
