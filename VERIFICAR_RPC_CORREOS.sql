-- ========================================================================
-- MIA Tracker · Verificación y reparación de los RPC que usan los correos
-- Ejecutar en: Supabase > SQL Editor
-- ========================================================================

-- ────────────────────────────────────────────────────────────────────────
-- PASO 1 (DIAGNÓSTICO): ¿cuáles de estos RPC existen realmente?
-- Los correos de "Low Stock Alert" SÍ llegan, así que
-- get_company_admins_and_supervisors existe. La sospecha es que
-- get_company_admins y/o get_user_email NO existen, y por eso los correos
-- de restock nunca llegaron a Resend.
-- ────────────────────────────────────────────────────────────────────────
SELECT
    r.rpc_name,
    CASE WHEN p.proname IS NULL THEN '❌ NO EXISTE' ELSE '✅ existe' END AS estado
FROM (VALUES
    ('get_company_admins_and_supervisors'),  -- usado por alertas de stock bajo (funciona)
    ('get_company_admins'),                  -- usado por correos de restock
    ('get_user_email'),                      -- usado por correos de restock
    ('get_pending_stock_alerts'),
    ('mark_alert_email_sent')
) AS r(rpc_name)
LEFT JOIN pg_proc p
       ON p.proname = r.rpc_name
      AND p.pronamespace = 'public'::regnamespace
ORDER BY estado, r.rpc_name;


-- ────────────────────────────────────────────────────────────────────────
-- PASO 2: get_user_email  — devuelve el correo de auth.users
-- (auth.users no es accesible desde el cliente; por eso hace falta el RPC)
-- ────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_email(user_uuid UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
BEGIN
    SELECT u.email INTO v_email
    FROM auth.users u
    WHERE u.id = user_uuid;

    RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_email(UUID) TO authenticated;


-- ────────────────────────────────────────────────────────────────────────
-- PASO 3: get_company_admins — admins de una compañía, CON el email incluido
-- Se devuelve el email en la fila (igual que get_company_admins_and_supervisors)
-- para que la app no tenga que hacer un RPC extra por cada admin.
-- ────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_company_admins(p_company_id INTEGER)
RETURNS TABLE (
    id        UUID,
    full_name TEXT,
    username  TEXT,
    role      TEXT,
    email     TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        pr.id,
        pr.full_name,
        pr.username,
        pr.role,
        u.email::TEXT
    FROM public.profiles pr
    JOIN auth.users u ON u.id = pr.id
    WHERE pr.id_company = p_company_id
      AND LOWER(COALESCE(pr.role, '')) IN ('admin', 'owner', 'administrador')
      AND u.email IS NOT NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_company_admins(INTEGER) TO authenticated;


-- ────────────────────────────────────────────────────────────────────────
-- PASO 4 (COMPROBACIÓN): sustituye 1 por tu id_company real y confirma
-- que devuelve filas CON email. Si sale vacío, el problema no es el RPC:
-- es que ningún perfil de esa compañía tiene role admin/owner.
-- ────────────────────────────────────────────────────────────────────────
-- ¿Cuál es tu id_company?
SELECT id, full_name, role, id_company
FROM public.profiles
WHERE id = auth.uid();

-- Reemplaza el 1 por tu id_company:
-- SELECT * FROM public.get_company_admins(1);
-- SELECT * FROM public.get_company_admins_and_supervisors(1);

-- Ver todos los roles registrados por compañía (para detectar roles mal escritos)
SELECT id_company, role, COUNT(*) AS usuarios
FROM public.profiles
GROUP BY id_company, role
ORDER BY id_company, role;


-- ────────────────────────────────────────────────────────────────────────
-- PASO 5: El OTRO camino — correos de APROBACIÓN al proveedor
-- Este flujo (sendApprovalEmailWithQR) NO usa admins: manda a
-- supply_company.email. Si ese campo está vacío, el envío lanza excepción
-- y el correo nunca sale, aunque los RPC de admins estén perfectos.
-- ────────────────────────────────────────────────────────────────────────
SELECT
    sc.id,
    sc.name,
    COALESCE(NULLIF(TRIM(sc.email), ''), '❌ SIN EMAIL') AS email,
    sc.id_company,
    sc.status
FROM public.supply_company sc
ORDER BY (NULLIF(TRIM(sc.email), '') IS NULL) DESC, sc.name;

-- Solicitudes de restock cuyo proveedor no tiene email
-- (estas NUNCA podrán notificar la aprobación)
SELECT
    rr.id            AS request_id,
    rr.nombre_producto,
    rr.status,
    sc.name          AS proveedor,
    COALESCE(NULLIF(TRIM(sc.email), ''), '❌ SIN EMAIL') AS email_proveedor
FROM public.restock_requests rr
LEFT JOIN public.supply_company sc ON sc.id = rr.id_supply_company
WHERE sc.id IS NULL OR NULLIF(TRIM(sc.email), '') IS NULL
ORDER BY rr.id DESC
LIMIT 50;
