import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { Text, View } from "react-native";
import type { CacheMiss } from "../shared/cache-miss.ts";

export function CacheMissWarning({ item, theme, layout }: PluginTimelineItemProps<CacheMiss>) {
  const { model, cacheRead, previousCached, promptTokens } = item.data;
  const retained = Math.round(cacheRead / previousCached * 100);
  const hitRate = Math.round(cacheRead / promptTokens * 100);
  return (
    <View style={{ padding: layout.compact ? 8 : 12, gap: 4, borderLeftWidth: 2, borderLeftColor: theme.colors.statusWarning }}>
      <Text style={{ color: theme.colors.statusWarning }}>Likely Pi prompt cache miss</Text>
      <Text style={{ color: theme.colors.foreground }}>
        {cacheRead.toLocaleString()} cached tokens read, down from {previousCached.toLocaleString()} previously cached ({retained}% retained).
      </Text>
      <Text style={{ color: theme.colors.foregroundMuted }}>
        {hitRate}% of this request's {promptTokens.toLocaleString()} prompt tokens were cache hits · {model}
      </Text>
    </View>
  );
}
