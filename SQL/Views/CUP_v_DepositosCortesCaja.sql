    SET ANSI_NULLS, ANSI_WARNINGS ON;

GO 

/*=============================================
 Created by:    Enrique Sierra Gtez
 Creation Date: 2016-12-12

 Description: Regresa un listado de los
 depositos que aplicaron a solicitudes
 de deposito disparadas por cortes de caja
 ( chica o tombola ). 

 Example: SELECT * 
          FROM  CUP_v_DepositosCortesCaja
          WHERE 
            Ejercicio = 2016
          AND Periodo = 10
            
-- ============================================*/


IF EXISTS(SELECT * FROM sysobjects WHERE name='CUP_v_DepositosCortesCaja')
	DROP VIEW CUP_v_DepositosCortesCaja
GO
CREATE VIEW CUP_v_DepositosCortesCaja
AS    
SELECT DISTINCT
  dep.ID,
  dep.Empresa,
  dep.Sucursal,
  dep.Mov,
  dep.Movid,
  dep.FechaEmision,
  dep.Ejercicio,
  dep.Periodo,
  dep.Estatus,
  dep.CtaDinero,
  dep.CtaDineroDestino,
  depD.Aplica,
  depD.AplicaID,
  dep.Moneda,
  dep.TipoCambio,
  depD.Importe,
  depD.FormaPago,
  solDev.IVAFiscal,
  CorteID = corte.ID,
  CorteMov = corte.Mov,
  CorteMovID = corte.MoviD
FROM
Dinero dep 
JOIN DineroD depD ON depD.ID = dep.ID
JOIN Movtipo t ON t.Modulo = 'DIN'
            AND t.Mov = dep.Mov
JOIN Movtipo aplicaT ON aplicaT.Modulo = 'DIN'
                  AND aplicaT.Mov = depD.Aplica
JOIN dinero solDev ON solDev.Mov = depD.Aplica
                AND solDev.MovID = depD.AplicaID
-- Corte Origen
CROSS APPLY(SELECT TOP 1 
            ID = mf.OID 
          FROM 
            dbo.fnCMLMovFlujo('DIN', solDev.ID, 1) mf 
          WHERE 
            mf.Indice < 0 
          AND mf.OModulo = 'DIN'
          AND mf.OMovTipo = 'DIN.CP'
          AND mf.OMovSubTipo = 'DIN.CPMULTIMONEDA') corteOrigen
 -- Corte 
 JOIN Dinero corte ON corte.Id =corteOrigen.ID 
WHERE 
t.Clave = 'DIN.D'
AND aplicaT.Clave = 'DIN.SD'
AND dep.Estatus IN ( 'CONCLUIDO', 'CANCELADO' )
AND corteOrigen.ID IS NOT NULL