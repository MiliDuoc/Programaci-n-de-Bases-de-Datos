------------------------------------------------------------
--SECCION 1 PREPARACION DEL AMBIENTE
------------------------------------------------------------

SET SERVEROUTPUT ON;

SELECT COUNT(*) FROM CONSUMO;
SELECT COUNT(*) FROM TOTAL_CONSUMOS;
SELECT COUNT(*) FROM REG_ERRORES;
SELECT COUNT(*) FROM DETALLE_DIARIO_HUESPEDES;

DESC CONSUMO;
DESC TOTAL_CONSUMOS;
DESC REG_ERRORES;
DESC DETALLE_DIARIO_HUESPEDES;


------------------------------------------------------------
--SECCION 3 CASO 1 BLOQUE DE PRUEBA
------------------------------------------------------------

--ANTES valores de los consumos involucrados
SELECT *
FROM CONSUMO
WHERE ID_CONSUMO IN (11473, 10688)
   OR (ID_HUESPED = 340006 AND ID_RESERVA = 1587)
ORDER BY ID_CONSUMO;

--ANTES total de consumos del huesped involucrado
SELECT *
FROM TOTAL_CONSUMOS
WHERE ID_HUESPED = 340006;

BEGIN
  --Inserta un nuevo consumo con la id siguiente
  INSERT INTO CONSUMO (ID_CONSUMO, ID_RESERVA, ID_HUESPED, MONTO)
  VALUES ((SELECT NVL(MAX(ID_CONSUMO),0) + 1 FROM CONSUMO), 1587, 340006, 150);

  --Elimina el consumo con ID 11473
  DELETE FROM CONSUMO
  WHERE ID_CONSUMO = 11473;

  --Actualiza a US 95 el consumo con ID 10688
  UPDATE CONSUMO
     SET MONTO = 95
   WHERE ID_CONSUMO = 10688;

  COMMIT;
END;
/

--DESPUES valores de los consumos involucrados
SELECT *
FROM CONSUMO
WHERE ID_CONSUMO IN (11473, 10688)
   OR (ID_HUESPED = 340006 AND ID_RESERVA = 1587)
ORDER BY ID_CONSUMO;

--DESPUES total de consumos del huesped involucrado
SELECT *
FROM TOTAL_CONSUMOS
WHERE ID_HUESPED = 340006;

--VALIDACION suma directa vs total
SELECT 340006 AS id_huesped,
       (SELECT NVL(SUM(monto),0) FROM CONSUMO WHERE id_huesped = 340006) AS suma_consumo,
       (SELECT monto_consumos FROM TOTAL_CONSUMOS WHERE id_huesped = 340006) AS total_consumos
FROM dual;


------------------
-- CASO 2
------------------
SELECT table_name
FROM user_tables
ORDER BY table_name;

DESC HUESPED;
DESC RESERVA;
DESC DETALLE_RESERVA;
DESC AGENCIA;
DESC HUESPED_TOUR;
DESC TOUR;
DESC TRAMOS_CONSUMOS;
------------------------------------------------------------
--SECCION 4 CASO 2 LEVANTAMIENTO DE ESTRUCTURA
------------------------------------------------------------
--Tablas y columnas confirmadas por DESC:
--HUESPED(ID_HUESPED, NOM_HUESPED, APPAT_HUESPED, APMAT_HUESPED, ID_AGENCIA)
--AGENCIA(ID_AGENCIA, NOM_AGENCIA, PCT_AGENCIA)
--RESERVA(ID_RESERVA, ID_HUESPED, INGRESO, ESTADIA)
--HUESPED_TOUR(ID_HUESPED, ID_TOUR, NUM_PERSONAS)
--TOUR(ID_TOUR, VALOR_TOUR)
--TRAMOS_CONSUMOS(VMIN_TRAMO, VMAX_TRAMO, PCT)
--TOTAL_CONSUMOS(ID_HUESPED, MONTO_CONSUMOS)
--DETALLE_DIARIO_HUESPEDES columnas ya vistas

------------------------------------------------------------
--SECCION 5 CASO 2 PACKAGE TOURS
------------------------------------------------------------

CREATE OR REPLACE PACKAGE PKG_TOURS AS
  FUNCTION FN_TOURS_USD(p_id_huesped NUMBER) RETURN NUMBER;
END PKG_TOURS;
/

CREATE OR REPLACE PACKAGE BODY PKG_TOURS AS
  FUNCTION FN_TOURS_USD(p_id_huesped NUMBER) RETURN NUMBER IS
    v_total NUMBER := 0;
  BEGIN
    SELECT NVL(SUM(t.valor_tour * NVL(ht.num_personas,1)), 0)
      INTO v_total
      FROM HUESPED_TOUR ht
      JOIN TOUR t
        ON t.id_tour = ht.id_tour
     WHERE ht.id_huesped = p_id_huesped;

    RETURN NVL(v_total,0);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
    WHEN OTHERS THEN
      RETURN 0;
  END FN_TOURS_USD;
END PKG_TOURS;
/

------------------------------------------------------------
--SECCION 6 CASO 2 FUNCION AGENCIA HUESPED
------------------------------------------------------------
SELECT sequence_name
FROM user_sequences
ORDER BY sequence_name;

--Requiere secuencia SQ_ERROR 

CREATE OR REPLACE FUNCTION FN_AGENCIA_HUESPED(p_id_huesped NUMBER)
RETURN VARCHAR2
IS
  v_nom_agencia AGENCIA.nom_agencia%TYPE;
BEGIN
  SELECT a.nom_agencia
    INTO v_nom_agencia
    FROM HUESPED h
    JOIN AGENCIA a
      ON a.id_agencia = h.id_agencia
   WHERE h.id_huesped = p_id_huesped;

  RETURN NVL(v_nom_agencia, 'NO REGISTRA AGENCIA');

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    INSERT INTO REG_ERRORES (ID_ERROR, NOMSUBPROGRAMA, MSG_ERROR)
    VALUES (SQ_ERROR.NEXTVAL,
            'Error en la funcion FN_AGENCIA',
            'ORA-01403: No se ha encontrado ningun dato');
    RETURN 'NO REGISTRA AGENCIA';

  WHEN OTHERS THEN
    INSERT INTO REG_ERRORES (ID_ERROR, NOMSUBPROGRAMA, MSG_ERROR)
    VALUES (SQ_ERROR.NEXTVAL,
            'Error en la funcion FN_AGENCIA',
            SUBSTR(SQLERRM,1,300));
    RETURN 'NO REGISTRA AGENCIA';
END;
/
SHOW ERRORS;

------------------------------------------------------------
--SECCION 7 CASO 2 FUNCION CONSUMOS HUESPED
------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_CONSUMOS_USD(p_id_huesped NUMBER)
RETURN NUMBER
IS
  v_monto TOTAL_CONSUMOS.monto_consumos%TYPE;
BEGIN
  SELECT monto_consumos
    INTO v_monto
    FROM TOTAL_CONSUMOS
   WHERE id_huesped = p_id_huesped;

  RETURN NVL(v_monto,0);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    INSERT INTO REG_ERRORES (ID_ERROR, NOMSUBPROGRAMA, MSG_ERROR)
    VALUES (SQ_ERROR.NEXTVAL,
            'Error en la funcion FN_CONSUMOS',
            'ORA-01403: No se ha encontrado ningun dato');
    RETURN 0;

  WHEN OTHERS THEN
    INSERT INTO REG_ERRORES (ID_ERROR, NOMSUBPROGRAMA, MSG_ERROR)
    VALUES (SQ_ERROR.NEXTVAL,
            'Error en la funcion FN_CONSUMOS',
            SUBSTR(SQLERRM,1,300));
    RETURN 0;
END;
/
SHOW ERRORS;

------------------------------------------------------------
--SECCION 8 CASO 2 PROCEDIMIENTO PRINCIPAL
------------------------------------------------------------
DESC HABITACION;
DESC CATEGORIA;
DESC DETALLE_RESERVA;
DESC RESERVA;
DESC CATEGORIA;


CREATE OR REPLACE PROCEDURE SP_DETALLE_DIARIO_HUESPEDES(
  p_fecha_proceso IN DATE,
  p_valor_dolar   IN NUMBER
)
IS
  v_nombre            VARCHAR2(60);
  v_agencia           VARCHAR2(40);
  v_pct_agencia       NUMBER(4,2);

  v_alojamiento_usd   NUMBER := 0;
  v_consumos_usd      NUMBER := 0;
  v_tours_usd         NUMBER := 0;

  v_alojamiento_clp   NUMBER := 0;
  v_consumos_clp      NUMBER := 0;
  v_tours_clp         NUMBER := 0;

  v_subtotal_clp      NUMBER := 0;
  v_pct_tramo         NUMBER(4,2) := 0;
  v_desc_consumos     NUMBER := 0;
  v_desc_agencia      NUMBER := 0;
  v_total             NUMBER := 0;

BEGIN
  --limpieza para re ejecutar
  DELETE FROM DETALLE_DIARIO_HUESPEDES;
  DELETE FROM REG_ERRORES;
  COMMIT;

  --huespedes con salida en la fecha proceso
  FOR r IN (
    SELECT re.id_reserva,
           h.id_huesped,
           h.nom_huesped,
           h.appat_huesped,
           h.apmat_huesped,
           re.estadia
      FROM RESERVA re
      JOIN HUESPED h
        ON h.id_huesped = re.id_huesped
     WHERE (re.ingreso + re.estadia) = p_fecha_proceso
     ORDER BY h.id_huesped
  ) LOOP

    v_nombre := r.nom_huesped || ' ' || r.appat_huesped || ' ' || r.apmat_huesped;

    --agencia (funcion registra error si no hay)
    v_agencia := FN_AGENCIA_HUESPED(r.id_huesped);

    --pct agencia (si no hay queda 0)
    BEGIN
      SELECT NVL(a.pct_agencia,0)
        INTO v_pct_agencia
        FROM HUESPED h
        LEFT JOIN AGENCIA a
          ON a.id_agencia = h.id_agencia
       WHERE h.id_huesped = r.id_huesped;
    EXCEPTION
      WHEN OTHERS THEN
        v_pct_agencia := 0;
    END;

    --consumos usd (funcion registra error si no hay)
    v_consumos_usd := FN_CONSUMOS_USD(r.id_huesped);

    --tours usd (package)
    v_tours_usd := PKG_TOURS.FN_TOURS_USD(r.id_huesped);

    --alojamiento usd: sumatoria por habitacion en la reserva
    BEGIN
      SELECT NVL(SUM(hab.valor_habitacion * r.estadia + hab.valor_minibar),0)
        INTO v_alojamiento_usd
        FROM DETALLE_RESERVA dr
        JOIN HABITACION hab
          ON hab.id_habitacion = dr.id_habitacion
       WHERE dr.id_reserva = r.id_reserva;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_alojamiento_usd := 0;
      WHEN OTHERS THEN
        v_alojamiento_usd := 0;
    END;

    --convertir a clp
    v_alojamiento_clp := ROUND(v_alojamiento_usd * p_valor_dolar);
    v_consumos_clp    := ROUND(v_consumos_usd    * p_valor_dolar);
    v_tours_clp       := ROUND(v_tours_usd       * p_valor_dolar);

    v_subtotal_clp := v_alojamiento_clp + v_consumos_clp + v_tours_clp;

    --descuento consumos segun tramo (se evalua con consumos en usd)
    BEGIN
      SELECT NVL(pct,0)
        INTO v_pct_tramo
        FROM TRAMOS_CONSUMOS
       WHERE v_consumos_usd BETWEEN vmin_tramo AND vmax_tramo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_pct_tramo := 0;
      WHEN OTHERS THEN
        v_pct_tramo := 0;
    END;

    v_desc_consumos := ROUND(v_consumos_clp * (v_pct_tramo / 100));

    --descuento agencia sobre subtotal
    v_desc_agencia := ROUND(v_subtotal_clp * (NVL(v_pct_agencia,0) / 100));

    --total
    v_total := v_subtotal_clp - v_desc_consumos - v_desc_agencia;

    INSERT INTO DETALLE_DIARIO_HUESPEDES
      (id_huesped, nombre, agencia, alojamiento, consumos, tours,
       subtotal_pago, descuento_consumos, descuentos_agencia, total)
    VALUES
      (r.id_huesped, v_nombre, v_agencia, v_alojamiento_clp, v_consumos_clp, v_tours_clp,
       v_subtotal_clp, v_desc_consumos, v_desc_agencia, v_total);

  END LOOP;

  COMMIT;
END;
/
SHOW ERRORS;

------------------------------------------------------------
--SECCION 9 CASO 2 EJECUCION Y EVIDENCIA
------------------------------------------------------------


BEGIN
  SP_DETALLE_DIARIO_HUESPEDES(p_fecha_proceso => DATE '2021-08-18',
                             p_valor_dolar   => 915);
END;
/

SELECT * FROM DETALLE_DIARIO_HUESPEDES ORDER BY id_huesped;
SELECT * FROM REG_ERRORES ORDER BY id_error;