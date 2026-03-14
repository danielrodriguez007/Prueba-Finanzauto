USE finanzautos;


--KPI DASHBOARD

SELECT
	COUNT(*) [Total Servicios], --cantidad de servicios
	AVG(A.tiempo_respuesta_min) [Tiempo Promedio Respuesta],
	SUM(IIF(A.estado_servicio = 'Cancelado', 1, 0)) * 100.0 / COUNT(*) [% Cancelados],--porcentaje de los servicios cancelado
	FORMAT(SUM(CAST(A.costo_servicio AS decimal)),'C') [Costo Total],
	    CONVERT(DECIMAL(5,2), 
        SUM(CASE WHEN A.tiempo_respuesta_min <= B.sla_minutos THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(*), 0)) [% Cumplimiento SLA global]
FROM Servicios A
LEFT JOIN (
		SELECT
			cliente,
			sla_minutos
		FROM [clientes]) B ON B.cliente = A.cliente --Join con la tabla cliente para obtener sla

--Análisis por Servicio

WITH TipoServico AS(
	SELECT		
		tipo_servicio [Tipo Servicio],
		COUNT(*) [Volumen],
		AVG(tiempo_respuesta_min) [Tiempo Promedio],
		FORMAT(AVG(COSTO_SERVICIO),'C') [Costo Promedio], --aplicado el formato de moneda
		SUM(IIF(estado_servicio = 'Completado', 1, 0)) * 100.0 / COUNT(*) [% Completados]
	FROM Servicios
	GROUP BY tipo_servicio
) --cte
SELECT
	[Tipo Servicio],
	[Volumen],
	[Tiempo Promedio],
	[Costo Promedio],
	[% Completados]
FROM TipoServico
ORDER BY [Tipo Servicio]

-- Ranking Proveedores

-- TOP 10 DE PROVEEDORES CON MEJORES TIEMPOS DE RESPUESTA

SELECT	TOP 10 --solo mostrar 10 registros
	RANK() OVER(ORDER BY T.[Tiempo Respuesta]) Ranking, --funcion aplicada sobre tiempo de respuesta
	T.[Nombre Proveedor],
	T.[Tiempo Respuesta],
	T.calificacion,
	T.Volumen
FROM(
	SELECT
		B.proveedor_nombre [Nombre Proveedor],
		B.calificacion,
		COUNT(A.servicio_id) [Volumen],
		SUM(A.tiempo_respuesta_min) [Tiempo Respuesta]	
	FROM Servicios A
	LEFT JOIN (
			SELECT
				proveedor_id,
				proveedor_nombre,
				calificacion
			FROM [proveedores])B ON B.proveedor_id = A.proveedor_id
	GROUP BY B.proveedor_nombre, B.calificacion
)T -- tabla creada para obtener mas el ranking
ORDER BY T.[Tiempo Respuesta] ASC

-- TOP 10 DE PROVEEDORES CON PEORES TIEMPOS DE RESPUESTA

SELECT	TOP 10 --solo mostrar 10 registros
	RANK() OVER(ORDER BY T.[Tiempo Respuesta]) Ranking,--funcion aplicada sobre tiempo de respuesta
	T.[Nombre Proveedor],
	T.[Tiempo Respuesta],
	T.calificacion,
	T.Volumen
FROM(
	SELECT
		B.proveedor_nombre [Nombre Proveedor],
		B.calificacion,
		COUNT(A.servicio_id) [Volumen],
		SUM(A.tiempo_respuesta_min) [Tiempo Respuesta]	
	FROM Servicios A
	LEFT JOIN (
			SELECT
				proveedor_id,
				proveedor_nombre,
				calificacion
			FROM [proveedores])B ON B.proveedor_id = A.proveedor_id
	GROUP BY B.proveedor_nombre, B.calificacion
)T -- tabla creada para obtener mas el ranking
ORDER BY T.[Tiempo Respuesta] DESC

--Evolucion temporal

WITH Evolucion AS(--CTE
	SELECT 
		MONTH(fecha_servicio) Mes,-- obtener el mes
		tipo_servicio [Tipo Servicio], -- cantidad de servicios
		COUNT(*) [Total Servicios],
		LAG(COUNT(*),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio)) [V Servicio],--funcion aplicada para obtener la diferencia entre meses
		CASE --en este case se valida que la funcion LAG primero sea mayoor que cero y despues se obtiene el porcentaje con la funcion requerida
		WHEN LAG(COUNT(*),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio)) > 0
		THEN (COUNT(*)-LAG(COUNT(*),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))) * 100.0 /
			LAG(COUNT(*),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))
			ELSE NULL
		END [% Cambio Servicio],
		FORMAT(AVG(costo_servicio),'C') [Costo Promedio],
		LAG(AVG(costo_servicio),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio)) [V Costo],
		CASE--en este case se valida que la funcion LAG primero sea mayoor que cero y despues se obtiene el porcentaje con la funcion requerida
		WHEN LAG(AVG(costo_servicio),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio)) > 0
		THEN (AVG(costo_servicio)-LAG(AVG(costo_servicio),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))) * 100.0 /
			LAG(AVG(costo_servicio),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))
			ELSE NULL
		END [% Cambio Costo],
		AVG(tiempo_respuesta_min) [Tiempo Promedio],
		LAG(AVG(tiempo_respuesta_min),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))[V Tiempo],
		CASE--en este case se valida que la funcion LAG primero sea mayoor que cero y despues se obtiene el porcentaje con la funcion requerida
		WHEN LAG(AVG(tiempo_respuesta_min),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio)) > 0
		THEN (AVG(tiempo_respuesta_min)-LAG(AVG(tiempo_respuesta_min),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))) * 100.0 /
			LAG(AVG(tiempo_respuesta_min),1) OVER(PARTITION BY tipo_servicio ORDER BY MONTH(fecha_servicio))
			ELSE NULL
		END [% Cambio Tiempo],		
		SUM(IIF(estado_servicio = 'Completado', 1, 0)) * 100.0 / COUNT(*) [% SLA] --SLA global
	FROM [servicios]
	GROUP BY MONTH(fecha_servicio),tipo_servicio
)
SELECT
	Mes,
	[Tipo Servicio],
	[Total Servicios],
	[% Cambio Servicio],
	[Costo Promedio],
	[% Cambio Costo],
	[Tiempo Promedio],
	[% Cambio Tiempo],
	[% SLA]
FROM Evolucion
ORDER BY Mes, [Tipo Servicio]

-- Cumplimiento SLA por Cliente

WITH SLA AS(--CTE
SELECT
	B.cliente,
	CONVERT(DECIMAL(5,2), 
	SUM(CASE
		WHEN A.tiempo_respuesta_min <= B.sla_minutos
		THEN 1 ELSE 0 END) * 100.0 / 
	NULLIF(COUNT(*), 0)) [% SLA]
FROM [servicios] A
LEFT JOIN (
		SELECT cliente,	sla_minutos FROM [clientes]) B ON B.cliente = A.cliente--Join con la tabla cliente para obtener sla
GROUP BY B.cliente
)
SELECT
	*
FROM SLA 
ORDER BY [% SLA] ASC










