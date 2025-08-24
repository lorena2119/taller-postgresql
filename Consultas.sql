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

-- 11. Devuelve los 2 productos más vendidos por categoría usando una subconsulta y luego filtrando `ROW_NUMBER` <= 2.
    -- - `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY SUM(...) DESC)`
    SELECT DISTINCT ON(c.id_cliente) c.id_cliente, cp.total as total_compra
    FROM miscompras.compras as c
    JOIN miscompras.compras_productos as cp USING(id_compra)
    ORDER BY c.id_cliente, c.fecha DESC;

-- 12. Calcula ventas mensuales: agrupa por mes truncando la fecha, cuenta compras distintas y suma ventas, ordenando cronológicamente.
    -- - `DATE_TRUNC('month', fecha)`
    -- - `COUNT(DISTINCT ...)`
    -- - `SUM`
    SELECT DATE_TRUNC('month', c.fecha) as mes, COUNT(DISTINCT c.id_compra) as compras_distintas, SUM(cp.total) as total_ventas
    FROM miscompras.compras as c
    JOIN miscompras.compras_productos as cp USING(id_compra)
    GROUP BY mes
    ORDER BY mes ASC;

-- 13. Lista productos que nunca se han vendido mediante un anti-join, comparando por id_producto
    -- - `NOT EXISTS`
    SELECT p.id_producto, p.nombre
    FROM miscompras.productos p
    WHERE NOT EXISTS (
        SELECT 1
        FROM miscompras.compras_productos as cp
        WHERE cp.id_producto = p.id_producto
    );

-- 14. Identifica clientes que, al comprar “café”, también compran “pan” en la misma compra, usando un filtro con `ILIKE` y una subconsulta correlacionada con `EXISTS`.
    -- - `EXISTS`
    -- - `ILIKE`
    SELECT DISTINCT c.id, c.nombre, c.apellidos
    FROM clientes c
    JOIN miscompras.compras co ON c.id = co.id_cliente
    WHERE EXISTS (
        SELECT 1
        FROM miscompras.compras_productos cp
        JOIN miscompras.productos p1 ON cp.id_producto = p1.id_producto
        WHERE cp.id_compra = co.id_compra
        AND p1.nombre ILIKE '%café%'
    )
    AND EXISTS (
        SELECT 1
        FROM miscompras.compras_productos cp
        JOIN miscompras.productos p2 ON cp.id_producto = p2.id_producto
        WHERE cp.id_compra = co.id_compra
        AND p2.nombre ILIKE '%pan%'
    );

-- 15. Estima el margen porcentual “simulado” de un producto aplicando operadores aritméticos sobre precio_venta y formateo con `ROUND()` a un decimal.
    -- - `ROUND`
    -- Supuesto: costo_simulado = 65% del precio_venta
    SELECT p.id_producto, p.nombre, p.precio_venta,
    ROUND( ((p.precio_venta - (p.precio_venta * 0.65)) / NULLIF(p.precio_venta, 0)) * 100, 1 ) AS margen_simulado,
    ROUND(p.precio_venta * 0.65, 2) AS costo_simulado
    FROM miscompras.productos p;

-- 16. Filtra clientes de un dominio dado usando expresiones regulares con el operador `~*` (case-insensitive) y limpieza con `TRIM()` sobre el correo electrónico.
    -- - `TRIM`
    -- - `~*`
    SELECT id, nombre, apellidos, correo_electronico
    FROM miscompras.clientes
    WHERE TRIM(correo_electronico) ~* '@example\.com$';
    
-- 17. Normaliza nombres y apellidos de clientes con `TRIM()` e `INITCAP()` para capitalizar, retornando columnas formateadas.
    -- - `TRIM`
    -- - `INITCAP`
    SELECT INITCAP(TRIM(nombre)) as nombre_cliente, INITCAP(TRIM(apellidos)) as apellidos
    FROM miscompras.clientes;

-- 18. Selecciona los productos cuyo `id_producto` es par usando el operador módulo `%` en la cláusula `WHERE`.
    -- - `%`
    SELECT id_producto, nombre
    FROM miscompras.productos
    WHERE id_producto % 2 = 0;

-- 19. Crea una vista ventas_por_compra que consolide `id_compra`,` id_cliente`, `fecha` y el `SUM(total)` por compra, usando `CREATE OR REPLACE VIEW` y `JOIN ... USING`.
    -- - `VIEW`
    -- - `JOIN`
    -- - `USING`
    CREATE OR REPLACE VIEW miscompras.ventas_por_compra AS
    SELECT c.id_compra, c.id_cliente, c.fecha, SUM(cp.total) AS total_compra
    FROM miscompras.compras c
    JOIN miscompras.compras_productos cp
    USING (id_compra)
    GROUP BY c.id_compra, c.id_cliente, c.fecha;
    SELECT * FROM miscompras.ventas_por_compra;

-- 20. Crea una vista materializada mensual mv_ventas_mensuales que agregue ventas por `DATE_TRUNC('month', fecha);` recuerda refrescarla con `REFRESH MATERIALIZED VIEW` cuando corresponda.
    -- - `DATE_TRUNC()`
    -- - `REFRESH MATERIALIZED VIEW`
    CREATE MATERIALIZED VIEW miscompras.mv_ventas_mensuales AS
    SELECT DATE_TRUNC('month', c.fecha) AS mes, SUM(cp.total) AS total_mensual
    FROM miscompras.compras c
    JOIN miscompras.compras_productos cp
    USING (id_compra)
    GROUP BY DATE_TRUNC('month', c.fecha)
    ORDER BY mes;
    SELECT * FROM miscompras.mv_ventas_mensuales;

-- 21. Realiza un “UPSERT” de un producto referenciado por codigo_barras usando `INSERT ... ON CONFLICT (...) DO UPDATE`, actualizando nombre y precio_venta cuando exista conflicto.
    -- - `UPSERT`
    -- - `INSERT ... ON CONFLICT (...) DO UPDATE`
    INSERT INTO miscompras.productos (codigo_barras, nombre, precio_venta, id_categoria)
    VALUES ('7701234567890', 'Café Premium', 18500, 1)
    ON CONFLICT (codigo_barras) 
    DO UPDATE SET 
    nombre = EXCLUDED.nombre,
    precio_venta = EXCLUDED.precio_venta;

-- 22. Recalcula el stock descontando lo vendido a partir de un `UPDATE ... FROM (SELECT ... GROUP BY ...)`, empleando `COALESCE()` y `GREATEST()` para evitar negativos.
    -- - `GREATEST`
    -- - `COALESCE`
    UPDATE miscompras.productos p
    SET cantidad_stock = GREATEST(0, p.cantidad_stock - COALESCE(v.total_vendido, 0))
    FROM (
        SELECT id_producto, SUM(cantidad) AS total_vendido
        FROM miscompras.compras_productos
        GROUP BY id_producto
    ) v
    WHERE p.id_producto = v.id_producto;

-- 23. Implementa una función PL/pgSQL (`miscompras.fn_total_compra`) que reciba `p_id_compra` y retorne el `total` con `COALESCE(SUM(...), 0);` define el tipo de retorno `NUMERIC(16,2)`.
    -- - `COALESCE`
    -- - `SUM`
    CREATE OR REPLACE FUNCTION miscompras.fn_total_compra(p_id_compra INT)
    RETURNS NUMERIC LANGUAGE plpgsql AS $$
    DECLARE v_total NUMERIC(16, 2);
    BEGIN
        SELECT COALESCE(SUM(total), 0)
        INTO v_total
        FROM miscompras.compras_productos
        WHERE id_compra = p_id_compra;

        RETURN v_total;
    END
    $$;
    SELECT miscompras.fn_total_compra(1) as total_compra;

-- 24. Define un trigger `AFTER INSERT` sobre `compras_productos` que descuente stock mediante una función `RETURNS TRIGGER` y el uso del registro `NEW`, protegiendo con `GREATEST()` para no quedar bajo cero.
    -- - `GREATEST()`
    -- - `NEW`
    CREATE OR REPLACE FUNCTION miscompras.trg_descuenta_stock()
    RETURNS TRIGGER LANGUAGE plpgsql AS
    $$
    BEGIN
        UPDATE miscompras.productos
        SET cantidad_stock = GREATEST(0, cantidad_stock - NEW.cantidad)
        WHERE id_producto = NEW.id_producto;
        RETURN NEW;
    END;
    $$;
    DROP TRIGGER IF EXISTS compras_productos_descuento_stock ON miscompras.compras_productos;
    CREATE TRIGGER compras_productos_descuento_stock
    AFTER INSERT ON miscompras.compras_productos
    FOR EACH ROW EXECUTE FUNCTION miscompras.trg_descuenta_stock();

-- 25. Asigna la “posición por precio” de cada producto dentro de su categoría con `DENSE_RANK() OVER (PARTITION BY ... ORDER BY precio_venta DESC)` y presenta el ranking.
    -- - `DENSE_RANK()`
    -- - `OVER (PARTITION BY ... ORDER BY precio_venta DESC)`
    SELECT p.id_producto, p.nombre, p.precio_venta, p.id_categoria,
    DENSE_RANK() OVER (
        PARTITION BY p.id_categoria 
        ORDER BY p.precio_venta DESC
    ) AS posicion_por_precio
    FROM miscompras.productos p
    ORDER BY p.id_categoria, posicion_por_precio;

-- 26. Para cada cliente, muestra su gasto por compra, el gasto anterior y el delta entre compras usando `LAG(...) OVER (PARTITION BY id_cliente ORDER BY dia)` dentro de un `CTE` que agrega por día.
    -- - `LAG(...) OVER (PARTITION BY id_cliente ORDER BY dia)`
    WITH compras_diarias AS (
    SELECT c.id_cliente, DATE(c.fecha) AS dia, SUM(cp.total) AS gasto_diario
    FROM miscompras.compras c
    JOIN miscompras.compras_productos cp
    USING (id_compra)
    GROUP BY c.id_cliente, DATE(c.fecha)
    )
    SELECT id_cliente, dia, gasto_diario, LAG(gasto_diario) OVER (PARTITION BY id_cliente ORDER BY dia) AS gasto_anterior,
        gasto_diario - COALESCE(
            LAG(gasto_diario) OVER (PARTITION BY id_cliente ORDER BY dia), 
            0
        ) AS delta
    FROM compras_diarias
    ORDER BY id_cliente, dia;

