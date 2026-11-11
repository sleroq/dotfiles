import { ModelRuntime } from '@earendil-works/pi-coding-agent';
import { createFumoProvider } from './index.js';

const runtime = await ModelRuntime.create({ refreshOnCreate: false });
runtime.registerNativeProvider(createFumoProvider({ baseUrl: process.env.FUMO_BASE_URL }));
const result = await runtime.refresh({ providers: ['fumo'], allowNetwork: true, force: true });
if (result.aborted || result.errors.size > 0) {
  throw new AggregateError(result.errors.values(), 'Fumo model catalog refresh failed');
}
