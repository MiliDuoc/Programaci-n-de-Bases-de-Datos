/* =========================================================
   PASO 0: VERIFICACIÓN DE CARGA DE DATOS
   ========================================================= */

SELECT 'AFP' tabla, COUNT(*) filas FROM afp
UNION ALL SELECT 'TIPO_SALUD', COUNT(*) FROM tipo_salud
UNION ALL SELECT 'COMUNA', COUNT(*) FROM comuna
UNION ALL SELECT 'ESTADO_CIVIL', COUNT(*) FROM estado_civil
UNION ALL SELECT 'EMPLEADO', COUNT(*) FROM empleado
UNION ALL SELECT 'CLIENTE', COUNT(*) FROM cliente
UNION ALL SELECT 'MARCA', COUNT(*) FROM marca
UNION ALL SELECT 'CAMION', COUNT(*) FROM camion
UNION ALL SELECT 'ARRIENDO_CAMION', COUNT(*) FROM arriendo_camion;



/* =========================================================
   PASO 1: LISTADO DE TABLAS DEL ESQUEMA
   ========================================================= */

SELECT table_name
FROM user_tables
ORDER BY table_name;



/* =========================================================
   PASO 2: ESTRUCTURA DE COLUMNAS POR TABLA
   ========================================================= */

SELECT table_name,
       column_id,
       column_name,
       data_type,
       data_length,
       data_precision,
       data_scale,
       nullable
FROM user_tab_columns
ORDER BY table_name, column_id;



/* =========================================================
   PASO 3: ESTRUCTURA DE LA TABLA USUARIO_CLAVE
   ========================================================= */

SELECT column_id,
       column_name,
       data_type,
       data_length,
       data_precision,
       data_scale,
       nullable
FROM user_tab_columns
WHERE table_name = 'USUARIO_CLAVE'
ORDER BY column_id;



/* =========================================================
   PASO 4: REVISIÓN DE CLAVES PRIMARIAS Y FORÁNEAS
   ========================================================= */

SELECT c.table_name,
       c.constraint_name,
       c.constraint_type,
       cc.column_name
FROM user_constraints c
JOIN user_cons_columns cc
  ON c.constraint_name = cc.constraint_name
WHERE c.constraint_type IN ('P','R')
ORDER BY c.table_name, c.constraint_type;



/* =========================================================
   PASO 5: LIMPIEZA DE TABLA DESTINO
   ========================================================= */

TRUNCATE TABLE usuario_clave;



/* =========================================================
   PASO 6: BLOQUE PL/SQL ANÓNIMO – GENERACIÓN DE USUARIOS
   ========================================================= */

DECLARE
   --Fecha de proceso
   v_fecha_proceso DATE := SYSDATE;

   -- Control 
   v_contador        NUMBER := 0;
   v_total_empleados NUMBER;

   -- TYPE
   v_id_emp          empleado.id_emp%TYPE;
   v_run             empleado.numrun_emp%TYPE;
   v_dv              empleado.dvrun_emp%TYPE;
   v_pnombre         empleado.pnombre_emp%TYPE;
   v_snombre         empleado.snombre_emp%TYPE;
   v_appaterno       empleado.appaterno_emp%TYPE;
   v_apmaterno       empleado.apmaterno_emp%TYPE;
   v_sueldo          empleado.sueldo_base%TYPE;
   v_estado_civil    estado_civil.nombre_estado_civil%TYPE;
   v_fecha_nac       empleado.fecha_nac%TYPE;
   v_fecha_cont      empleado.fecha_contrato%TYPE;

   -- proceso
   v_nombre_usuario  usuario_clave.nombre_usuario%TYPE;
   v_clave_usuario   usuario_clave.clave_usuario%TYPE;
   v_letras_apellido VARCHAR2(2);
   v_anios_trabajo   NUMBER;
   v_mes_anio_bd     VARCHAR2(6);

BEGIN
   -- total empleados 
   SELECT COUNT(*) INTO v_total_empleados FROM empleado;

   --procesamiento
   FOR r IN (
      SELECT e.id_emp,
             e.numrun_emp,
             e.dvrun_emp,
             e.pnombre_emp,
             e.snombre_emp,
             e.appaterno_emp,
             e.apmaterno_emp,
             e.sueldo_base,
             e.fecha_nac,
             e.fecha_contrato,
             ec.nombre_estado_civil
      FROM empleado e
      JOIN estado_civil ec
        ON e.id_estado_civil = ec.id_estado_civil
      ORDER BY e.id_emp
   ) LOOP

      --asignaciones 
      v_id_emp       := r.id_emp;
      v_run          := r.numrun_emp;
      v_dv           := r.dvrun_emp;
      v_pnombre      := r.pnombre_emp;
      v_snombre      := r.snombre_emp;
      v_appaterno    := r.appaterno_emp;
      v_apmaterno    := r.apmaterno_emp;
      v_sueldo       := r.sueldo_base;
      v_fecha_nac    := r.fecha_nac;
      v_fecha_cont   := r.fecha_contrato;
      v_estado_civil := r.nombre_estado_civil;

      --años trabajados
      v_anios_trabajo :=
         FLOOR(MONTHS_BETWEEN(v_fecha_proceso, v_fecha_cont) / 12);

      --estado civil
      IF v_estado_civil IN ('CASADO','ACUERDO DE UNION CIVIL') THEN
         v_letras_apellido := LOWER(SUBSTR(v_appaterno,1,2));
      ELSIF v_estado_civil IN ('DIVORCIADO','SOLTERO') THEN
         v_letras_apellido := LOWER(SUBSTR(v_appaterno,1,1) ||
                                    SUBSTR(v_appaterno,LENGTH(v_appaterno),1));
      ELSIF v_estado_civil = 'VIUDO' THEN
         v_letras_apellido := LOWER(SUBSTR(v_appaterno,LENGTH(v_appaterno)-2,2));
      ELSE
         v_letras_apellido := LOWER(SUBSTR(v_appaterno,LENGTH(v_appaterno)-1,2));
      END IF;

      --NOMBRE_USUARIO 
        v_nombre_usuario :=
           LOWER(SUBSTR(v_estado_civil,1,1)) ||
           UPPER(SUBSTR(v_pnombre,1,3)) ||
           LENGTH(v_pnombre) || '*' ||
           MOD(v_sueldo,10) ||
           v_dv ||
           v_anios_trabajo ||
           CASE WHEN v_anios_trabajo < 10 THEN 'X' ELSE '' END;
        


     --CLAVE_USUARIO
      v_mes_anio_bd := TO_CHAR(v_fecha_proceso,'MMYYYY');

      v_clave_usuario :=
         SUBSTR(v_run,3,1) ||
         (EXTRACT(YEAR FROM v_fecha_nac) + 2) ||
         LPAD(MOD(v_sueldo - 1,1000),3,'0') ||
         v_letras_apellido ||
         v_id_emp ||
         v_mes_anio_bd;

      --Inserción
      INSERT INTO usuario_clave
      VALUES (
         v_id_emp,
         v_run,
         v_dv,
         RTRIM(
           v_pnombre || ' ' ||
           NVL(v_snombre || ' ', '') ||
           v_appaterno || ' ' ||
           v_apmaterno
         ),
         v_nombre_usuario,
         v_clave_usuario
      );

      v_contador := v_contador + 1;
   END LOOP;

   --Commit controlado
   IF v_contador = v_total_empleados THEN
      COMMIT;
   ELSE
      ROLLBACK;
   END IF;
END;
/



SELECT COUNT(*) FROM usuario_clave;
SELECT * FROM usuario_clave ORDER BY id_emp;
