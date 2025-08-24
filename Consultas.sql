-- 1. Top 10 productos más vendidos (unidades) y su ingreso total
    -- - `SUM()`
    -- - `USING`
    SELECT p.id_producto, p.nombre,
    SUM(cp.cantidad) AS unidades,
    SUM(cp.total) AS ingreso_total
    FROM miscompras.compras_productos cp
    JOIN miscompras.productos p USING(id_producto)
    GROUP BY p.id_producto, p.nombre
    ORDER BY unidades DESC
    LIMIT 10;

-- 2. Venta promedio ppr compra y mediana aproximada
    -- - `PERCENTILE_COUNT(..) WITHIN GROUP `
    -- - `ROUND`
    -- - `USING`
    SELECT ROUND(AVG(t.total_compra), 2) AS promedio_compra,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY t.total_compra) AS mediana
    FROM (
        SELeCT c.id_compra , SUM(cp.total) as total_compra
        FROM miscompras.compras c
        JOIN miscompras.compras_productos cp USING(id_compra)
        GROUP BY c.id_compra
    ) t;

-- 3. Compras por cliente y ranking
    -- - `COUNT`
    -- - `RANK`
    -- - `SUM`
    SELECT cl.id, cl.nombre || ' ' || cl.apellidos AS cliente,
    COUNT(DISTINCT c.id_compra) AS compras, 
    SUM(cp.total) AS gasto_total,
    RANK() OVER(ORDER BY SUM(cp.total) DESC) AS ranking_gasto
    FROM miscompras.clientes cl
    JOIN miscompras.compras c ON cl.id = c.id_cliente
    JOIN miscompras.compras_productos cp USING(id_compra)
    GROUP BY cl.id, cliente
    ORDER BY ranking_gasto;

-- 4. Ticket por compra
    -- - `COUNT`
    -- - `ROUND`
    -- - `SUM`
    -- - `WITH args AS`
    SELECT c.id_compra, c.fecha::date as dia, SUM(cp.total) AS total_compra
    FROM miscompras.compras c
    JOIN miscompras.compras_productos cp USING(id_compra)
    GROUP BY c.id_compra, c.fecha::date;

    WITH t AS(
        SELECT c.id_compra, c.fecha::date as dia, SUM(cp.total) AS total_compra
        FROM miscompras.compras c
        JOIN miscompras.compras_productos cp USING(id_compra)
        GROUP BY c.id_compra, c.fecha::date
    )
    SELECT dia,
        COUNT(*) as numero_compras,
        ROUND(AVG(total_compra), 2) as promedio,
        SUM(total_compra) as total_dia
    FROM t
    GROUP BY dia
    ORDER BY dia;

-- 5. Búsqueda tipo "e-commerce": productos activos, disponibkes y que empiecen por 'Caf'
    -- - `ILIKE`
    SELECT *
    FROM miscompras.productos p
    WHERE p.estado = 1
        ANd p.cantidad_stock > 0
        AND p.nombre ILIKE 'caf%';

-- 6. Devuelve los productos con el precio formateado como texto monetario usando concatenación, ordenando de mayor a menor precio. 
    -- - `TO_CHAR`
    SELECT nombre, '$ ' || TO_CHAR(precio_venta, 'FM999G999G999D00') as precio
    FROM miscompras.productos p
    ORDER BY precio_venta DESC;

-- 7. Arma el “resumen de canasta” por compra: subtotal, `IVA al 19%` y total con IVA, sobre el total por ítem, agrupado por compra.
    -- - `SUM`
    -- - `ROUND`
    SELECT id_compra as id_compra, ROUND(SUM(total)) as subtotal, ROUND(SUM(total)) * 0.19 as iva_producto, ROUND(SUM(total) + SUM(total) * 0.19) as total
    FROM miscompras.compras_productos
    GROUP BY id_compra;

-- 8. Calcula la participación (%) de cada categoría en las ventas usando agregaciones por categoría y una ventana sobre el total.
    -- - `SUM`
    -- - `ROUND`
    -- - `OVER`
    SELECT c.descripcion AS categoria,
    SUM(cp.total) AS total_ventas_por_categoria,
    ROUND((SUM(cp.total) / SUM(SUM(cp.total)) OVER () * 100), 2) AS porcentaje_participacion
    FROM miscompras.compras_productos cp
    JOIN miscompras.productos p ON cp.id_producto = p.id_producto
    JOIN miscompras.categorias c ON p.id_categoria = c.id_categoria
    GROUP BY c.descripcion
    ORDER BY porcentaje_participacion DESC;

-- 9. Clasifica el nivel de stock de productos activos (`CRÍTICO/BAJO/OK`) sobre el campo `cantidad_stock` y ordena por el stock ascendente.
    -- - `CASE`
    SELECT nombre as producto, 
    CASE 
        WHEN cantidad_stock < 50 THEN 'Crítico'
        WHEN cantidad_stock < 150 THEN 'BAJO'
    ELSE
        'OK'
    END AS estado_stock
    FROM miscompras.productos
    ORDER BY cantidad_stock ASC;


-- 10. Obtén la última compra por cliente utilizando`DISTINCT ON (id_cliente)` y una agregación del total de la compra.
    -- - `ORDER BY`
    -- - `DINSTINC ON`
    SELECT DISTINCT ON(c.id_cliente) c.id_cliente, cp.total as total_compra
    FROM miscompras.compras as c
    JOIN miscompras.compras_productos as cp USING(id_compra)
    ORDER BY c.id_cliente, c.fecha DESC;
