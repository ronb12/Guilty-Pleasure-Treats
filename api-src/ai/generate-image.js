/**
 * AI image generation for the Cake Designer.
 * POST { "prompt": "..." } → either { "imageUrl": "..." } (OpenAI) or raw image bytes (Pollinations).
 *
 * Free (no key): uses Pollinations.ai — returns image bytes with Content-Type image/png.
 * Optional: set OPENAI_API_KEY in Vercel to use DALL-E 3 instead (faster, higher quality).
 */
import { setCors, handleOptions } from '../../api/lib/cors.js';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_URL = 'https://api.openai.com/v1/images/generations';
const POLLINATIONS_BASE = 'https://gen.pollinations.ai/image';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const prompt = req.body?.prompt != null ? String(req.body.prompt).trim() : '';
  if (!prompt) {
    return res.status(400).json({ error: 'prompt is required' });
  }
  if (prompt.length > 4000) {
    return res.status(400).json({ error: 'prompt too long' });
  }

  // Prefer OpenAI if configured (faster, higher quality)
  if (OPENAI_API_KEY && OPENAI_API_KEY.startsWith('sk-')) {
    return await handleOpenAI(req, res, prompt);
  }

  // Free: Pollinations.ai (no API key)
  return await handlePollinations(res, prompt);
}

async function handleOpenAI(req, res, prompt) {
  try {
    const openaiRes = await fetch(OPENAI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'dall-e-3',
        prompt,
        n: 1,
        size: '1024x1024',
        response_format: 'url',
        quality: 'standard',
      }),
    });

    const data = await openaiRes.json();
    if (!openaiRes.ok) {
      const message = data?.error?.message || data?.message || `OpenAI error ${openaiRes.status}`;
      console.error('OpenAI images/generations error', openaiRes.status, message);
      return res.status(openaiRes.status >= 500 ? 502 : openaiRes.status).json({
        error: message.length > 200 ? 'Image generation failed. Try a different description.' : message,
      });
    }

    const url = data?.data?.[0]?.url;
    if (!url) {
      console.error('OpenAI response missing data[0].url', data);
      return res.status(502).json({ error: 'No image URL in response' });
    }
    return res.status(200).json({ imageUrl: url });
  } catch (err) {
    console.error('ai/generate-image OpenAI', err);
    return res.status(500).json({
      error: err.message || 'Image generation failed. Please try again.',
    });
  }
}

async function handlePollinations(res, prompt) {
  try {
    const path = encodeURIComponent(prompt);
    const url = `${POLLINATIONS_BASE}/${path}?model=flux`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 50_000);
    const genRes = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'image/png,image/*,*/*',
        'User-Agent': 'Mozilla/5.0 (compatible; GuiltyPleasureTreats/1.0)',
      },
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!genRes.ok) {
      const text = await genRes.text();
      console.error('Pollinations error', genRes.status, text.slice(0, 300));
      return res.status(502).json({
        error: 'Image generation is temporarily unavailable. Try again in a moment.',
      });
    }

    const contentType = genRes.headers.get('content-type') || 'image/png';
    const buffer = Buffer.from(await genRes.arrayBuffer());
    res.setHeader('Content-Type', contentType);
    res.setHeader('Cache-Control', 'private, max-age=0');
    return res.status(200).send(buffer);
  } catch (err) {
    if (err.name === 'AbortError') {
      return res.status(504).json({
        error: 'Image took too long. Try a shorter description or try again.',
      });
    }
    console.error('ai/generate-image Pollinations', err);
    return res.status(500).json({
      error: err.message || 'Image generation failed. Please try again.',
    });
  }
}
