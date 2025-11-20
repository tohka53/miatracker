// ========================================================================
// EDGE FUNCTION: send-restock-email (VERSIÓN CON MÚLTIPLES DESTINATARIOS)
// Ubicación: supabase/functions/send-restock-email/index.ts
// ========================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// ⚠️ IMPORTANTE: En producción, usar variables de entorno
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || "re_9yLQvBh8_Q4QoaT6ehbc6VzBTQT44re7C";
const DEFAULT_FROM_EMAIL = "mark@miatracker.com";
const DEFAULT_FROM_NAME = "MIA Tracker System";

// CORS headers mejorados
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

serve(async (req) => {
  // 1) Manejar preflight (OPTIONS)
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  // 2) Solo permitir POST
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }

  try {
    // 3) Log de autenticación (debug)
    const authHeader = req.headers.get('Authorization');
    console.log('🔐 Auth header:', authHeader ? 'Present' : 'Missing');

    // 4) Leer body
    const body = await req.json();
    const { to, subject, html } = body;

    console.log('📧 Email request:', {
      to: to,
      subject: subject,
      htmlLength: html?.length || 0
    });

    // 5) Validar campos requeridos
    if (!to || !subject || !html) {
      console.error('❌ Missing fields:', { to: !!to, subject: !!subject, html: !!html });
      return new Response(
        JSON.stringify({
          error: "Missing required fields",
          details: "Required: to, subject, html"
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // 6) 🔥 NUEVO: Preparar destinatarios (soporta ; como separador)
    let recipients: string[];

    if (Array.isArray(to)) {
      // Si ya es array, usarlo directamente
      recipients = to;
    } else if (typeof to === 'string') {
      // Si es string, dividir por ; o por ,
      if (to.includes(';')) {
        recipients = to.split(';').map(email => email.trim()).filter(email => email);
      } else if (to.includes(',')) {
        recipients = to.split(',').map(email => email.trim()).filter(email => email);
      } else {
        recipients = [to.trim()];
      }
    } else {
      recipients = [to];
    }

    console.log('👥 Recipients processed:', recipients);
    console.log('📊 Total recipients:', recipients.length);

    // 7) Llamar a Resend API
    console.log('📤 Calling Resend API...');
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `${DEFAULT_FROM_NAME} <${DEFAULT_FROM_EMAIL}>`,
        to: recipients, // 🔥 Array de destinatarios
        subject,
        html,
      }),
    });

    const responseText = await resendResponse.text();
    console.log('📬 Resend response:', {
      status: resendResponse.status,
      body: responseText
    });

    // 8) Parsear respuesta
    let responseData;
    try {
      responseData = JSON.parse(responseText);
    } catch {
      responseData = { raw: responseText };
    }

    // 9) Responder con CORS
    if (resendResponse.ok) {
      console.log('✅ Email sent successfully to', recipients.length, 'recipients');
      return new Response(
        JSON.stringify({
          success: true,
          recipients: recipients,
          count: recipients.length,
          ...responseData
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } else {
      console.error('❌ Resend API error:', responseData);
      return new Response(
        JSON.stringify({
          success: false,
          error: responseData.message || 'Email send failed',
          details: responseData
        }),
        {
          status: resendResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  } catch (err) {
    console.error('💥 Exception in edge function:', err);
    return new Response(
      JSON.stringify({
        success: false,
        error: String(err),
        message: 'Internal server error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

