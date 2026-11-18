import OpenAI from 'openai';
import { env } from './env.js';

/**
 * Single shared OpenAI vision client (GPT-4o Vision). The API key lives ONLY
 * here on the server and must never reach the Flutter app.
 */
const cfg = env.ai.openai;

export const openai = new OpenAI({
  apiKey: cfg.apiKey || 'MISSING_API_KEY',
});

export const VISION_MODEL = cfg.visionModel;
