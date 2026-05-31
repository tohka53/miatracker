-- ============================================================================
-- SCRIPT PARA CORREGIR Y OPTIMIZAR LAS FUNCIONES RPC DE INVENTORY
-- Ejecutar cada bloque por separado en Supabase SQL Editor
-- ============================================================================

-- 1. ELIMINAR LA FUNCIÓN EXISTENTE SI EXISTE
DROP FUNCTION IF EXISTS get_inventory_paginated(INTEGER, INTEGER, INTEGER, TEXT);

-- 2. CREAR LA FUNCIÓN OPTIMIZADA
CREATE OR REPLACE FUNCTION get_inventory_paginated(
    p_company_id INTEGER,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0,
    p_filter TEXT DEFAULT 'all'
)
RETURNS TABLE(
    id_inventario INTEGER,
    nombre_producto VARCHAR,
    imagen TEXT,
    cantidad INTEGER,
    alerta_cantidad INTEGER,
    precio NUMERIC,
    fecha_modificacion TIMESTAMP,
    id_locat INTEGER,
    lugar_fisico VARCHAR,
    stock_status TEXT,
    total_count BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_count BIGINT;
BEGIN
    -- Calcular el total para paginación
    SELECT COUNT(*) INTO v_total_count
    FROM inventario i
    WHERE i.id_company = p_company_id
      AND i.status = 1
      AND (
        p_filter = 'all' OR
        (p_filter = 'low_stock' AND i.cantidad <= i.alerta_cantidad AND i.cantidad > 0) OR
        (p_filter = 'out_of_stock' AND i.cantidad = 0) OR
        (p_filter = 'normal' AND i.cantidad > i.alerta_cantidad)
      );

    RETURN QUERY
    SELECT 
        i.id_inventario,
        i.nombre_producto,
        i.imagen,
        i.cantidad,
        i.alerta_cantidad,
        i.precio,
        i.fecha_modificacion,
        l.id_locat,
        l.lugar_fisico,
        CASE 
            WHEN i.cantidad = 0 THEN 'out_of_stock'::TEXT
            WHEN i.cantidad <= i.alerta_cantidad THEN 'low_stock'::TEXT
            ELSE 'normal'::TEXT
        END AS stock_status,
        v_total_count
    FROM inventario i
    LEFT JOIN locat l ON i.id_location = l.id_locat
    WHERE i.id_company = p_company_id
      AND i.status = 1
      AND (
        p_filter = 'all' OR
        (p_filter = 'low_stock' AND i.cantidad <= i.alerta_cantidad AND i.cantidad > 0) OR
        (p_filter = 'out_of_stock' AND i.cantidad = 0) OR
        (p_filter = 'normal' AND i.cantidad > i.alerta_cantidad)
      )
    ORDER BY i.fecha_creacion DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- 3. DAR PERMISOS
GRANT EXECUTE ON FUNCTION get_inventory_paginated TO authenticated;

-- ============================================================================
-- FUNCIÓN PARA OBTENER CONTADORES DE FILTROS
-- ============================================================================

-- Eliminar si existe
DROP FUNCTION IF EXISTS get_filter_counts(INTEGER);

-- Crear función
CREATE OR REPLACE FUNCTION get_filter_counts(p_company_id INTEGER)
RETURNS TABLE(
    all_count BIGINT,
    normal_count BIGINT,
    low_stock_count BIGINT,
    out_of_stock_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS all_count,
        COUNT(*) FILTER (WHERE cantidad > alerta_cantidad) AS normal_count,
        COUNT(*) FILTER (WHERE cantidad <= alerta_cantidad AND cantidad > 0) AS low_stock_count,
        COUNT(*) FILTER (WHERE cantidad = 0) AS out_of_stock_count
    FROM inventario
    WHERE id_company = p_company_id
      AND status = 1;
END;
$$;

-- Dar permisos
GRANT EXECUTE ON FUNCTION get_filter_counts TO authenticated;

-- ============================================================================
-- FUNCIÓN PARA BÚSQUEDA RÁPIDA
-- ============================================================================

-- Eliminar si existe
DROP FUNCTION IF EXISTS search_inventory_fast(INTEGER, TEXT, INTEGER, INTEGER);

-- Crear función
CREATE OR REPLACE FUNCTION search_inventory_fast(
    p_company_id INTEGER,
    p_search_text TEXT,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id_inventario INTEGER,
    nombre_producto VARCHAR,
    imagen TEXT,
    cantidad INTEGER,
    alerta_cantidad INTEGER,
    precio NUMERIC,
    fecha_modificacion TIMESTAMP,
    id_locat INTEGER,
    lugar_fisico VARCHAR,
    stock_status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id_inventario,
        i.nombre_producto,
        i.imagen,
        i.cantidad,
        i.alerta_cantidad,
        i.precio,
        i.fecha_modificacion,
        l.id_locat,
        l.lugar_fisico,
        CASE 
            WHEN i.cantidad = 0 THEN 'out_of_stock'::TEXT
            WHEN i.cantidad <= i.alerta_cantidad THEN 'low_stock'::TEXT
            ELSE 'normal'::TEXT
        END AS stock_status
    FROM inventario i
    LEFT JOIN locat l ON i.id_location = l.id_locat
    WHERE i.id_company = p_company_id
      AND i.status = 1
      AND (
        i.nombre_producto ILIKE '%' || p_search_text || '%' OR
        CAST(i.descripcion AS TEXT) ILIKE '%' || p_search_text || '%' OR
        l.lugar_fisico ILIKE '%' || p_search_text || '%'
      )
    ORDER BY i.fecha_creacion DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- Dar permisos
GRANT EXECUTE ON FUNCTION search_inventory_fast TO authenticated;