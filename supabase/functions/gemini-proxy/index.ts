import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://app.inksyncnote.com",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Authenticate user
    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse request
    const { text, tone } = await req.json();
    if (!text || !tone) {
      return new Response(JSON.stringify({ error: "Missing text or tone" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check AI credits
    const adminSupabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: profile } = await adminSupabase
      .from("profiles")
      .select("ai_credits_used, account_type")
      .eq("id", user.id)
      .single();

    // Build the prompt based on tone
    let prompt: string;
    switch (tone) {
      case 'proofread':
        prompt = `Proofread and correct the following text. Fix any spelling, grammar, and punctuation errors. Keep the same tone and style. Return ONLY the corrected text without any explanations or comments.\n\nText: "${text}"`;
        break;
      case 'rephrase':
        prompt = `Rephrase the following text while keeping the same meaning. Make it clearer and more natural. Return ONLY the rephrased text without any explanations or comments.\n\nText: "${text}"`;
        break;
      case 'emojify':
        prompt = `Add relevant emojis to the following text to make it more expressive and fun. Keep the original text and just add emojis. Return ONLY the text with emojis without any explanations or comments.\n\nText: "${text}"`;
        break;
      case 'elaborate':
        prompt = `Expand and elaborate on the following text. Add more details and explanation while keeping the same meaning. Return ONLY the elaborated text without any explanations or comments.\n\nText: "${text}"`;
        break;
      case 'shorten':
        prompt = `Make the following text more concise and brief while keeping the key points. Return ONLY the shortened text without any explanations or comments.\n\nText: "${text}"`;
        break;
      default:
        prompt = `Rewrite the following text in a ${tone} tone. Adjust the style and wording to match the tone while keeping the same meaning. Return ONLY the rewritten text without any explanations or comments.\n\nText: "${text}"`;
    }

    // Get Gemini API key from Vault
    const { data: secretData } = await adminSupabase
      .from('vault.decrypted_secrets')
      .select('decrypted_secret')
      .eq('name', 'gemini_api_key')
      .limit(1)
      .single();

    // Fallback to env var if vault is not set up
    const geminiApiKey = secretData?.decrypted_secret || Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      return new Response(JSON.stringify({ error: "Gemini API key not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;

    // Call Gemini API
    const geminiResponse = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        ],
      }),
    });

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      console.error('Gemini API error:', errorBody);
      return new Response(JSON.stringify({ error: "AI service temporarily unavailable" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const geminiData = await geminiResponse.json();
    const resultText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!resultText) {
      return new Response(JSON.stringify({ error: "No response generated" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Increment AI credits used and track token usage
    if (profile) {
      const currentCredits = profile.ai_credits_used ?? 0;
      const currentInputTokens = profile.ai_input_tokens ?? 0;
      const currentOutputTokens = profile.ai_output_tokens ?? 0;

      // Extract actual token usage from Gemini response
      const usage = geminiData?.usageMetadata;
      const inputTokens = usage?.promptTokenCount ?? 0;
      const outputTokens = usage?.candidatesTokenCount ?? 0;

      await adminSupabase
        .from('profiles')
        .update({
          ai_credits_used: currentCredits + 1,
          ai_input_tokens: currentInputTokens + inputTokens,
          ai_output_tokens: currentOutputTokens + outputTokens,
        })
        .eq('id', user.id);
    }

    return new Response(JSON.stringify({ result: resultText.trim() }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error('gemini-proxy error:', err);
    return new Response(JSON.stringify({ error: "An unexpected error occurred" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
