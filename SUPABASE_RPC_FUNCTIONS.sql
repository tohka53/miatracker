-- ============================================================================
-- FUNCIONES RPC OPTIMIZADAS PARA INVENTORY
-- ============================================================================
-- Estas funciones deben ejecutarse en Supabase SQL Editor
-- Son críticas para el rendimiento de la aplicación

-- 1. FUNCIÓN PARA OBTENER INVENTARIO PAGINADO (ULTRA OPTIMIZADA)
-- ============================================================================
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
            WHEN i.cantidad = 0 THEN 'out_of_stock'
            WHEN i.cantidad <= i.alerta_cantidad THEN 'low_stock'
            ELSE 'normal'
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

-- 2. FUNCIÓN PARA BÚSQUEDA RÁPIDA DE INVENTARIO
-- ============================================================================
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
            WHEN i.cantidad = 0 THEN 'out_of_stock'
            WHEN i.cantidad <= i.alerta_cantidad THEN 'low_stock'
            ELSE 'normal'
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

-- 3. FUNCIÓN PARA OBTENER CONTADORES DE FILTROS (OPTIMIZADO)
-- ============================================================================
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

-- 4. FUNCIÓN PARA OBTENER DISTRIBUCIÓN DE PRODUCTOS
-- ============================================================================
CREATE OR REPLACE FUNCTION get_product_distribution(
    p_product_id INTEGER,
    p_company_id INTEGER
)
RETURNS TABLE(
    id_inventario INTEGER,
    cantidad INTEGER,
    id_location INTEGER,
    id_locat INTEGER,
    lugar_fisico VARCHAR,
    coordenadas VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ils.id_inventario,
        ils.cantidad,
        ils.id_location,
        l.id_locat,
        l.lugar_fisico,
        l.coordenadas
    FROM inventory_location_stock ils
    INNER JOIN locat l ON ils.id_location = l.id_locat
    WHERE ils.id_inventario = p_product_id
      AND ils.id_company = p_company_id
      AND ils.status = 1
      AND ils.cantidad > 0
    ORDER BY ils.cantidad DESC;
END;
$$;

-- 5. FUNCIÓN PARA ESTADÍSTICAS RÁPIDAS
-- ============================================================================
CREATE OR REPLACE FUNCTION get_inventory_stats_fast(p_company_id INTEGER)
RETURNS TABLE(
    total_productos BIGINT,
    productos_activos BIGINT,
    productos_sin_stock BIGINT,
    productos_stock_bajo BIGINT,
    valor_total_inventario NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS total_productos,
        COUNT(*) FILTER (WHERE cantidad > 0) AS productos_activos,
        COUNT(*) FILTER (WHERE cantidad = 0) AS productos_sin_stock,
        COUNT(*) FILTER (WHERE cantidad <= alerta_cantidad AND cantidad > 0) AS productos_stock_bajo,
        COALESCE(SUM(cantidad::NUMERIC * precio), 0) AS valor_total_inventario
    FROM inventario
    WHERE id_company = p_company_id
      AND status = 1;
END;
$$;

-- 6. CREAR ÍNDICES PARA OPTIMIZACIÓN
-- ============================================================================
-- Índice para búsquedas por company_id y status
CREATE INDEX IF NOT EXISTS idx_inventario_company_status 
ON inventario(id_company, status);

-- Índice para ordenamiento por fecha_creacion
CREATE INDEX IF NOT EXISTS idx_inventario_fecha_creacion 
ON inventario(fecha_creacion DESC);

-- Índice para búsqueda de texto
CREATE INDEX IF NOT EXISTS idx_inventario_nombre_producto 
ON inventario USING gin(to_tsvector('spanish', nombre_producto));

-- Índice para la tabla inventory_location_stock
CREATE INDEX IF NOT EXISTS idx_inventory_location_stock_product 
ON inventory_location_stock(id_inventario, id_company, status);

-- Índice para locat
CREATE INDEX IF NOT EXISTS idx_locat_company_status 
ON locat(id_company, status);

-- 7. PERMISOS (AJUSTAR SEGÚN TUS POLÍTICAS RLS)
-- ============================================================================
GRANT EXECUTE ON FUNCTION get_inventory_paginated TO authenticated;
GRANT EXECUTE ON FUNCTION search_inventory_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_filter_counts TO authenticated;
GRANT EXECUTE ON FUNCTION get_product_distribution TO authenticated;
GRANT EXECUTE ON FUNCTION get_inventory_stats_fast TO authenticated;