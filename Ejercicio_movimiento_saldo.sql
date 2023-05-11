--Crear dos tablas la de cuentas con id, saldo, la otra de movimientos con id, tipo de movimiento y monto

CREATE TABLE cuentas (id_cuenta SERIAL PRIMARY KEY,saldo NUMERIC);

CREATE TABLE movimientos (id_movimientos SERIAL PRIMARY KEY,tipo_movimiento VARCHAR(25),monto NUMERIC,idcuenta numeric);
CREATE TABLE auditoria_movimientos (id_aud SERIAL PRIMARY KEY, description VARCHAR);

INSERT INTO cuentas VALUES (1,5000);
INSERT INTO cuentas VALUES (2,90000);

--Realizar un pa que: inserte en la tabla de movimientos y actualice el saldo en una transacción
CREATE OR REPLACE PROCEDURE insertar_movimiento( idcuenta INTEGER, 
tipoMovimiento VARCHAR, monto NUMERIC) 
AS $$
BEGIN  
	CASE
	WHEN tipoMovimiento = 'ingreso' THEN
		UPDATE cuentas SET saldo = saldo + monto WHERE id_cuenta = idcuenta;
		
	WHEN tipoMovimiento = 'retirada' THEN
			IF (SELECT saldo FROM cuentas WHERE id_cuenta = idcuenta) < monto THEN
				RAISE SQLSTATE '50001';
				ELSE
				UPDATE cuentas SET saldo = saldo - monto WHERE id_cuenta = idcuenta;
			END IF;
	ELSE 
	RAISE SQLSTATE '50002';
	END CASE;			
		
		INSERT INTO movimientos(tipo_movimiento,monto) values (tipoMovimiento,monto);		
	
  EXCEPTION    
    WHEN SQLSTATE '50001' THEN
	Rollback;
	RAISE NOTICE 'No hay saldo suficiente';
	
	WHEN SQLSTATE '50002' THEN
	ROLLBACK;
	RAISE NOTICE 'Introduce un tipo de movimiento válido: "ingreso" o "retirada"';
      
COMMIT;
  
END
$$ LANGUAGE plpgsql;

CALL insertar_saldo_movimiento(2,'ingreso',225);

select * from cuentas;
select * from movimientos;

-- Crear una funcion y un trigger cuando insertes movimientos usando el ejemplo anterior

CREATE OR REPLACE FUNCTION insertar_movimiento()
RETURNS TRIGGER
AS $$
BEGIN
CASE
	WHEN new.tipo_movimiento = 'ingreso' THEN
		UPDATE cuentas SET saldo = saldo + new.monto WHERE id_cuenta = new.idcuenta;
		
	WHEN new.tipo_movimiento = 'retirada' THEN
			IF (SELECT saldo FROM cuentas WHERE id_cuenta = new.idcuenta) < new.monto THEN
				RAISE EXCEPTION 'No hay suficiente saldo';
				ELSE
				UPDATE cuentas SET saldo = saldo - new.monto WHERE id_cuenta = new.idcuenta;
			END IF;
	ELSE 
	RAISE EXCEPTION 'Introduce un tipo de movimiento válido: "ingreso" o "retirada"';
	END CASE;	
	
	INSERT INTO auditoria_movimientos (description) 
	VALUES (CONCAT('Se ha realizado en la cuenta: ', new.idcuenta, ' un movimiento de tipo ', 
		new.tipo_movimiento, ' con monto de ',new.monto, '€ correctamente'));
		RETURN NEW; 
  
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_insertar_movimiento
BEFORE INSERT
ON movimientos
FOR EACH ROW
EXECUTE FUNCTION insertar_movimiento();

INSERT INTO movimientos(tipo_movimiento,monto,idcuenta) values ('ingreso',701,1);

SELECT * FROM cuentas;
SELECT * FROM auditoria_movimientos;


-- Ahora a la inversa, cuando se actualice el saldo se inserta el movimiento
CREATE OR REPLACE FUNCTION actualizar_saldo()
RETURNS TRIGGER
AS $$
BEGIN	
		IF NEW.saldo > OLD.saldo THEN
			INSERT INTO movimientos(tipo_movimiento,monto,idcuenta) values ('ingreso',(NEW.saldo - OLD.saldo),new.id_cuenta);
		ELSIF NEW.saldo < OLD.saldo THEN
			INSERT INTO movimientos(tipo_movimiento,monto,idcuenta) values ('retirada',(OLD.saldo - NEW.saldo),new.id_cuenta);
		END IF; 
		RETURN NEW;	
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER tg_actualizar_saldo
AFTER UPDATE
ON cuentas
FOR EACH ROW
EXECUTE FUNCTION actualizar_saldo();

UPDATE cuentas set saldo = 200 where id_cuenta = 2;

SELECT * FROM movimientos;