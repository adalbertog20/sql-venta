CREATE DATABASE IF NOT EXISTS PuntoVenta;
		  -- DROP DATABASE puntoventa;
		  USE PuntoVenta;

		  CREATE TABLE IF NOT EXISTS cliente(
		    idCliente INT AUTO_INCREMENT PRIMARY KEY,
		    nombre VARCHAR(80) NOT NULL,
		    apellidoPaterno VARCHAR(40) NOT NULL,
		    apellidoMaterno VARCHAR(40) NOT NULL,
		    fechaNacimiento DATE,
		    rfc VARCHAR(14) UNIQUE,
		    curp VARCHAR(18) UNIQUE,
		    domicilio VARCHAR(100),
		    cp CHAR(5),
		    ciudad VARCHAR(58),
		    estado ENUM('BC', 'BCS', 'CHIH', 'DGO', 'SIN', 'SON', 'COAH', 'NL', 'TAMPS', 'COL', 'JAL',
				'MICH', 'NAY', 'HGO', 'PUE', 'TLAX', 'VER', 'AGS', 'GTO', 'QRO', 'SLP' ,'ZAC', 'CDMX', 'EDOMEX',
				'MOR', 'CHIS', 'GRO', 'OAX', 'CAMP', 'QROO', 'TAB', 'YUC', 'OTRO') NOT NULL DEFAULT 'OTRO',
				pais VARCHAR(60),
				region ENUM('NOROESTE', 'NORESTE', 'OCCIDENTE', 'ORIENTE', 'CENTRONORTE', 'CENTROSUR', 'SUROESTE',
					    'SURESTE', 'SIN ASIGNAR') NOT NULL DEFAULT 'SIN ASIGNAR',
					    telefono CHAR(10),
					    celular CHAR(10) NOT NULL UNIQUE,
					    email VARCHAR(60) NOT NULL UNIQUE,
					    fechaRegistro DATETIME NOT NULL
		  );

		  CREATE TABLE IF NOT EXISTS venta(
		    idVenta INT AUTO_INCREMENT PRIMARY KEY,
		    IdCliente INT,
		    montoTotal DECIMAL(11, 2) NOT NULL,
		    fechaVenta DATE NOT NULL,
		    FOREIGN KEY(idCliente) REFERENCES cliente(idCliente)
		    ON UPDATE CASCADE
		    ON DELETE SET NULL
		  );
		  ALTER TABLE venta ADD fechaEstimada DATE;

		  CREATE TABLE IF NOT EXISTS producto(
		    idProducto INT AUTO_INCREMENT PRIMARY KEY,
		    nombre VARCHAR(100) NOT NULL,
		    precio DECIMAL(11, 2) NOT NULL,
		    existencias INT NOT NULL,
		    codigoBarra VARCHAR(20) NOT NULL UNIQUE
		  );

		  CREATE TABLE IF NOT EXISTS detalleVenta(
		    idVenta INT,
		    idProducto INT,
		    cantidadProducto INT NOT NULL,
		    importe DECIMAL(11, 2) NOT NULL,
		    FOREIGN KEY(idVenta) REFERENCES venta(idVenta)
		    ON UPDATE CASCADE
		    ON DELETE CASCADE,
		    FOREIGN KEY(idProducto) REFERENCES producto(idProducto)
		    ON UPDATE CASCADE
		    ON DELETE CASCADE
		  );

		  CREATE TABLE IF NOT EXISTS detalleFechaEntrega(
		    idCliente INT NOT NULL,
		    region VARCHAR(20),
		    mensaje VARCHAR(100)
		  );

		  DROP PROCEDURE IF EXISTS spInsertarCliente;
		  DROP PROCEDURE IF EXISTS spVenderProducto;
		  DROP PROCEDURE IF EXISTS spActualizarMontoVenta;

		  DELIMITER $$
		    CREATE PROCEDURE spInsertarCliente(nombre VARCHAR(80), apellidoPaterno VARCHAR(40),
						       apellidoMaterno VARCHAR(40), fechaNacimiento DATE, rfc VARCHAR(14), curp VARCHAR(18),
						       domicilio VARCHAR(100), cp CHAR(5), ciudad VARCHAR(58), estado CHAR(6), pais VARCHAR(60),
						       telefono CHAR(10), celular CHAR(10), email VARCHAR(60), fechaRegistro DATETIME)
		    BEGIN
		      DECLARE region VARCHAR(12);
		      IF ISNULL(estado) OR estado = '' THEN
			SELECT 'Error. Estado de residencia no definido' Mensaje;
		      ELSE
			CASE
			WHEN estado IN('BC', 'BCS', 'CHIH', 'DGO', 'SIN', 'SON') THEN
			  SET region = 'NOROESTE';
			WHEN estado IN('COAH', 'NL', 'TAMPS') THEN
			  SET region = 'NORESTE';
			WHEN estado IN('COL', 'JAL', 'MICH', 'NAY') THEN
			  SET region = 'OCCIDENTE';
			WHEN estado IN('HGO', 'PUE', 'TLAX', 'VER') THEN
			  SET region = 'ORIENTE';
			WHEN estado IN('AGS', 'GTO', 'QRO', 'SLP' ,'ZAC') THEN
			  SET region = 'CENTRONORTE';
			WHEN estado IN('CDMX', 'EDOMEX', 'MOR') THEN
			  SET region = 'CENTROSUR';
			WHEN estado IN('CHIS', 'GRO', 'OAX') THEN
			  SET region = 'SUROESTE';
			WHEN estado IN('CAMP', 'QROO', 'TAB', 'YUC') THEN
			  SET region = 'SURESTE';
			WHEN estado = 'OTRO' THEN
			  SET region = 'SIN ASIGNAR';
			  END CASE;

			INSERT INTO cliente(nombre, apellidoPaterno, apellidoMaterno, fechaNacimiento, rfc, curp,
					    domicilio, cp, ciudad, estado, pais, region, telefono, celular, email, fechaRegistro)
			VALUES(nombre, apellidoPaterno, apellidoMaterno, fechaNacimiento, rfc, curp, domicilio,
			       cp, ciudad, estado, pais, region, telefono, celular, email, fechaRegistro);
		      END IF;
		    END$$

		      DELIMITER $$
		      /*
			Creación de un procedimiento para registrar las ventas de productos a los clientes y actualizar
			los datos de dichos productos vendidos.
		       */
		      CREATE PROCEDURE spVenderProducto(idCliente INT, idProducto INT, cantidadProducto INT, fechaVenta DATE)
		      BEGIN
			DECLARE montoTotal DECIMAL(11, 2);
			/* Variable utilizada para almacenar el id de la venta actual realizada y
			   posteriormente ingresarlo en  la tabla detalleVenta */
			DECLARE idVentaActual INT;

			IF (SELECT COUNT(*) FROM cliente cli WHERE cli.idCliente = idCliente) = 0 THEN
			  SELECT 'Error. Cliente no existente.' Advertencia;
			ELSEIF (SELECT COUNT(*) FROM producto prod WHERE prod.idProducto = idProducto) = 0 THEN
			  SELECT 'Error. Producto no existente.' Advertencia;
			  ELSEIF (SELECT existencias FROM producto prod WHERE prod.idProducto = idProducto) < cantidadProducto THEN
			    SELECT 'Error. Existencias del producto insuficientes.' Advertencia;
			    ELSE
			      SET montoTotal = (SELECT precio FROM producto prod WHERE prod.idProducto = idProducto) * cantidadProducto;

			      UPDATE producto prod SET existencias = existencias - cantidadProducto
			       WHERE prod.idProducto = idProducto;
			      INSERT INTO venta(idCliente, montoTotal, fechaVenta)
			      VALUES(idCliente, montoTotal, fechaVenta);

			      SET idVentaActual = (SELECT MAX(idVenta) FROM venta);
			      INSERT INTO detalleVenta(idVenta, idProducto, cantidadProducto, importe)
			      VALUES(idVentaActual, idProducto, cantidadProducto, montoTotal);
END IF;
		      END$$
			DELIMITER ;

			DELIMITER $$
			  CREATE PROCEDURE spActualizarMontoVenta(IN paramIdVenta INT, IN paramIdProducto INT, IN paramCantidadProducto INT)
			  BEGIN
			    DECLARE varExisteProducto, varCantidadProd INT;
			    SET varExisteProducto=(SELECT COUNT(*) FROM producto WHERE idProducto=paramIdProducto);
			    IF varExisteProducto = 1 THEN
			      SET varCantidadProd=(SELECT COUNT(*) FROM detalleVenta WHERE cantidadProducto>=paramCantidadProducto);
			      IF varCantidadProd = 1 THEN
				START TRANSACTION;
				UPDATE detalleVenta SET cantidadProducto = paramCantidadProducto WHERE idVenta=paramIdVenta;
				UPDATE producto SET existencias = existencias - paramCantidadProducto WHERE idProducto=paramIdProducto;
				COMMIT;
			      END IF;
			    END IF;
			  END$$
			    DELIMITER ;

			    DROP PROCEDURE IF EXISTS spAsignarFechaEntrega;
			    DELIMITER $$;
			    CREATE PROCEDURE spAsignarFechaEntrega(IN paramIdVenta INT)
			    BEGIN
			      DECLARE varIdVentaExists INT DEFAULT 0;
			      DECLARE varIdUsuario INT DEFAULT 0;
			      DECLARE varRegion VARCHAR(20);
			      DECLARE varMensaje VARCHAR(100);
			      SET varIdUsuario = (SELECT IdCliente FROM venta where paramIdVenta=idVenta);
			      SET varIdVentaExists = (SELECT COUNT(*) FROM venta WHERE paramIdVenta=idVenta);
			      SET varRegion = (SELECT region FROM cliente WHERE varIdUsuario=idCliente);
			      CASE
			      WHEN varRegion = 'NOROESTE' THEN
				SET varMensaje = '1 DIAS HABILES';
			      WHEN varRegion = 'NORESTE' THEN
				SET varMensaje = '2 DIAS HABILES';
			      WHEN varRegion = 'OCCIDENTE' THEN
				SET varMensaje =  '3 DIAS HABILES';
			      WHEN varRegion = 'ORIENTE' THEN
				SET varMensaje =  '4 DIAS HABILES';
			      WHEN varRegion = 'CENTROSUR' THEN
				SET varMensaje =  '5 DIAS HABILES';
			      WHEN varRegion = 'SUROESTE' THEN
				SET varMensaje =  '6 DIAS HABILES';
			      WHEN varRegion = 'SURESTE' THEN
				SET varMensaje =  '7 DIAS HABILES';
				END CASE;
			      call spInsertarDFE(varIdUsuario, varRegion, varMensaje);
			      SELECT * FROM detalleFechaEntrega;
			    END $$;
			    DELIMITER ;


			    DROP PROCEDURE IF EXISTS spInsertarDFE;
			    DELIMITER $$;
			    CREATE PROCEDURE spInsertarDFE(IN paramIdCliente INT, IN paramRegion VARCHAR(20), IN paramMensaje VARCHAR(100))
			    BEGIN
			      START TRANSACTION;
			      SET AUTOCOMMIT = 0;
			      INSERT INTO detalleFechaEntrega (idCliente, region, mensaje) VALUES (paramIdCliente, paramRegion, paramMensaje);
			      COMMIT;
			    END $$;
			    DELIMITER ;

			    /*
			      Crear procedimiento para calcular la fecha estimada de entrega
			      de todas las ventas registradas, con base en la región a la que
			      pertenece el cliente y la inserte en una nueva columna ‘FechaEstimada’ de la tabla Venta.
			     */

			    DROP PROCEDURE IF EXISTS spCalcularFechaEntrega;
			    DELIMITER  $$;
			    CREATE PROCEDURE spCalcularFechaEntrega()
			    BEGIN
			      DECLARE registros INT DEFAULT 0;
			      DECLARE i INT DEFAULT 0;
			      DECLARE intervalo INT DEFAULT 0;
			      DECLARE varFechaVenta DATE;
			      DECLARE varRegionCliente VARCHAR(15);
			      SET i = 1;
			      SET registros = (SELECT COUNT(*) FROM venta);
			      WHILE i <= registros DO
				SET varRegionCliente=(SELECT region FROM cliente WHERE i=idCliente);
			      SET varFechaVenta=(SELECT fechaVenta FROM venta WHERE idVenta=i);
			      CASE
			      WHEN varRegionCliente = 'NOROESTE' THEN
				SET intervalo = 1;
			      WHEN varRegionCliente = 'NORESTE' THEN
				SET intervalo = 2;
			      WHEN varRegionCliente = 'OCCIDENTE' THEN
				SET intervalo = 3;
			      WHEN varRegionCliente = 'ORIENTE' THEN
				SET intervalo = 4;
			      WHEN varRegionCliente = 'CENTRONORTE' THEN
				SET intervalo = 5;
			      WHEN varRegionCliente = 'CENTROSUR' THEN
				SET intervalo = 5;
			      WHEN varRegionCliente = 'SUROESTE' THEN
				SET intervalo = 6;
			      WHEN varRegionCliente = 'SURESTE' THEN
				SET intervalo = 7;
				END CASE;
			      UPDATE venta SET fechaEstimada = (DATE_ADD(varFechaVenta,  INTERVAL intervalo DAY)) WHERE idVenta=i;
			      SET i=i+1;
END WHILE;
END $$;
DELIMITER ;

/* Crear procedimiento que permita incrementar un 10 % el precio de todos los productos
   que se encuentren por debajo del promedio y mostrarlos en una cadena concatenada. Fecha de entrega: 21 sept, 10:00 */

DROP PROCEDURE IF EXISTS spIncrementarPrecio;
DELIMITER $$;
CREATE PROCEDURE spIncrementarPrecio()
BEGIN
  DECLARE contador, varRegistros, varPrecio INT DEFAULT 0;
  DECLARE i INT DEFAULT 1;
  DECLARE cadena VARCHAR(100);
  DECLARE title VARCHAR(50);
  SET title='ID -- NOMBRE PRODUCTO -- PRECIO';
  SET varRegistros = (SELECT COUNT(*) FROM venta);
  WHILE i <= varRegistros DO
    IF (SELECT precio FROM producto WHERE idProducto=i) < (SELECT AVG(precio) FROM producto) THEN
      SET contador=contador+1;
      SET varPrecio = ((SELECT precio FROM producto WHERE idProducto=i)*(1.10));
      UPDATE PuntoVenta.producto SET precio=varPrecio WHERE idProducto=i;
      SELECT CONCAT(
	i,
	' ',
	(SELECT nombre FROM producto WHERE idProducto=i),
	' ',
	((SELECT precio FROM producto WHERE idProducto=i)*(1.10))) 'id -- nombre producto -- precio';
    END IF;
  SET i=i+1;
END WHILE;
END $$;
DELIMITER ;

-- call spIncrementarPrecio();

/*
  Crear procedimiento que ingrese el id de un producto y permita mostrar en una lista
  concatenada el ID del cliente, nombre completo y el monto total de venta de dicho producto.

  Resultado Ejemplo:

  CALL spVentasxProd(3);
  Ventas del producto: 1 - MARTILLO ROJO TRUPER MANGO MADERA
  ----------------------------------------------------------------------
  03 – MARCO MENDEZ – $1254.00
  04 – RAÚL LÓPEZ - $625.00

 */

DROP PROCEDURE IF EXISTS spMostrarCadena;
DELIMITER $$;
CREATE PROCEDURE spMostrarCadena(IN paramIdProducto INT)
BEGIN
END $$;
DELIMITER ;

-- call spMostrarCadena(2);

SELECT * FROM cliente;

INSERT INTO producto(nombre, precio, existencias, codigoBarra)
VALUES('Doritos Dinamita', 17, 500, '310447819479');
INSERT INTO producto(nombre, precio, existencias, codigoBarra)
VALUES('Chetos Flaming Hot', 15, 250, '12374912379');

CALL spInsertarCliente('Adalberto', 'Garcia', 'Mancillas', '2003-01-03', 'GAMA030103HS', 'GAMA030103HBSR',
		       'Col Cardenas', '23030', 'La Paz', 'BCS', 'México', '6121442134', '6121231408',
		       'adalbertog_20@alu.uabcs.mx', '2022-08-31 21:32:17');

CALL spInsertarCliente('Diego', 'Negrete', 'Olachea', '2002-01-24', 'DOGO012384', 'DOGO19306JFHG',
		       'Col Los Olivos', '23029', 'La Paz', 'BCS', 'México', '6127124', '182369',
		       'diego_20@alu.uabcs.mx', '2022-08-31 21:32:17');

CALL spInsertarCliente('El', 'Tilin', 'Etesech', '2003-01-03', 'TILINSOADI123', 'TILINSODIJD',
		       'Col Cardenas', '23030', 'La Paz', 'CDMX', 'México', '6121442134', '6123233408',
		       'tilin_2@alu.uabcs.mx', '2022-08-31 21:32:17');


CALL spVenderProducto(1, 2, 20, CURDATE());
CALL spVenderProducto(2, 1, 50, CURDATE());
CALL spVenderProducto(3, 2, 50, CURDATE());

INSERT INTO producto(nombre, precio, existencias, codigoBarra) VALUES
('Pinguino 50 g', 15, 80, 750547899810),
('Tostitos 80 g', 18, 50, 750047898784);

CALL spActualizarMontoVenta(1, 2, 123);
CALL spCalcularFechaEntrega();
