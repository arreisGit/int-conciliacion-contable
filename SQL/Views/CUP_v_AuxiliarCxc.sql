SET ANSI_NULLS, ANSI_WARNINGS ON;

GO 

/*=============================================
 Created by:    Enrique Sierra Gtez
 Creation Date: 2016-11-10

 Description: Regresa el auxiliar de 
 Saldos Cxc.

 Example: SELECT * 
          FROM  CUP_v_AuxiliarCxc
          WHERE 
            Ejercicio = 2016
          AND Periodo = 10
            
-- ============================================*/


IF EXISTS(SELECT * FROM sysobjects WHERE name='CUP_v_AuxiliarCxc')
	DROP VIEW CUP_v_AuxiliarCxc
GO
CREATE VIEW CUP_v_AuxiliarCxc
AS
SELECT
  a.Rama,
  AuxID = a.ID,
  a.Empresa,
  a.Sucursal,
  a.Cuenta,
  calc.Mov,
  calc.MovId,
  calc.Modulo,
  calc.ModuloID,
  MovClave = t.Clave,
  a.Moneda,
  a.TipoCambio,
  a.Ejercicio,
  a.Periodo,
  a.Fecha,
  Cargo = ISNULL(a.Cargo,0),
  Abono = ISNULL(a.Abono,0),
  calc.Neto,
  CargoMN = ROUND(ISNULL(a.Cargo,0) * a.TipoCambio,4,1),
  AbonoMN = ROUND(ISNULL(a.Abono,0) * a.TipoCambio,4,1),
  NetoMN =  ROUND(ISNULL(calc.Neto,0) * a.TipoCambio,4,1),
  a.EsCancelacion,
  calc.Aplica,
  calc.AplicaID,
  AplicaClave = at.Clave,
  OrigenModulo = ISNULL(c.OrigenTipo,''),
  OrigenMov = ISNULL(c.Origen,''),
  OrigenMovID = ISNULL(c.OrigenID,''),
  IVAFiscal = ISNULL(calc.IVAFiscal,0),
  FactorRetencion = CASE
                      WHEN ISNULL(doc.IVAFiscal,0) = 0 
                        OR ISNULL(doc.Impuestos,0) = 0 THEN
                        0
                      ELSE
                        ISNULL(doc.Retencion,0) / ISNULL(doc.Impuestos,0)
                    END
FROM 
	Auxiliar a
JOIN Rama r on r.Rama = a.Rama
JOIN Movtipo t ON t.Modulo = a.Modulo
              AND t.Mov  = a.Mov  
LEFT JOIN Cxc c ON c.ID = a.ModuloID
-- Documento
LEFT JOIN Cxc doc ON doc.Mov = a.Aplica
                 AND doc.Movid = a.AplicaID
LEFT JOIN Movtipo at ON at.Modulo = 'CXC'
                    AND at.Mov = a.Aplica
--Origen doc
OUTER APPLY(
            SELECT TOP 1 
              o_doc.ID 
            FROM
              cxc o_doc
            WHERE
              'CXC' = doc.OrigenTipo
            AND o_doc.Mov = doc.Origen
            AND o_doc.MovId = doc.OrigenID    
            ) origen_doc         
-- Campos Calculados
CROSS APPLY ( SELECT
                Mov = CASE 
                      WHEN ISNULL(t.Clave,'') = 'CXC.NC'
                        AND a.Mov = 'Saldos Cte' THEN
                        ISNULL(NULLIF(c.Origen,''),a.Mov)
                      ELSE
                        a.Mov
                    END,
                MovId = CASE
                          WHEN ISNULL(t.Clave,'') = 'CXC.NC'
                            AND a.Mov = 'Saldos Cte' THEN
                            ISNULL(NULLIF(c.OrigenID,''),a.MovID)
                          ELSE
                            a.MovID
                        END, 
                Modulo = CASE
                            WHEN ISNULL(t.Clave,'') = 'CXC.NC'
                            AND a.Mov = 'Saldos Cte' THEN
                              'CXC'
                            ELSE
                              a.Modulo
                          END,
                ModuloID = CASE 
                              WHEN ISNULL(t.Clave,'') = 'CXC.NC'
                            AND a.Mov = 'Saldos Cte' THEN
                               ISNULL(origen_doc.ID, doc.ID)
                              ELSE
                                a.ModuloID
                            END,
                Aplica =  CASE
                            WHEN ISNULL(t.Clave,'') = 'CXC.NC'
                            AND a.Mov = 'Saldos Cte' THEN
                                a.Mov
                            ELSE
                                a.Aplica
                          END,
                AplicaId = CASE
                              WHEN ISNULL(t.Clave,'') = 'CXC.NC'
                                AND a.Mov = 'Saldos Cte' THEN
                                  a.MovID
                                ELSE
                                  a.AplicaID
                              END, 
                IVAFiscal = CASE
                              WHEN ISNULL(at.Clave,'') = 'CXC.NC'
                                AND a.Aplica = 'Saldos Cte' THEN
                                  0.137931034482759 -- Factor de 16/116
                              ELSE
                                ISNULL(doc.IVAFiscal,0)
                            END,
                Neto = ISNULL(a.Cargo,0) - ISNULL( a.Abono,0)
            ) Calc
WHERE 
	r.Mayor = 'CXC'
AND ISNULL(t.Clave,'') NOT IN ('CXC.SCH','CXC.SD')
AND a.Modulo = 'CXC'

UNION  -- Saldo al corte facturas anticipo

SELECT
  a.Rama,
  a.AuxID,
  a.Empresa,
  a.Sucursal,
  a.Cuenta,
  Mov      = a.Mov,
  MovID    = a.MovID,
  Modulo   = a.Modulo,
  ModuloID = a.ModuloID,
  MovClave = a.MovClave,
  a.Moneda,
  a.TipoCambio,
  a.Ejercicio,
  a.Periodo,
  a.Fecha,
  Cargo = ISNULL(a.Cargo,0),
  Abono = ISNULL(a.Abono,0),
  calc.Neto,
  CargoMN = ROUND(ISNULL(a.Cargo,0) * a.TipoCambio,4,1),
  AbonoMN = ROUND(ISNULL(a.Abono,0) * a.TipoCambio,4,1),
  NetoMN =  ROUND(ISNULL(calc.Neto,0) * a.TipoCambio,4,1),
  a.EsCancelacion,
  Aplica = a.AplicaMov,
  AplicaID = a.AplicaMovID,
  a.AplicaClave,
  OrigenModulo = '',
  OrigenMov = '',
  OrigenMovID = '',
  IVAFiscal = ISNULL(a.IVAFiscal,0),
  FactorRetencion =  ISNULL(a.FactorRetencion,0)
FROM 
  CUP_v_CxcAuxiliarAnticipos a
-- Campos Calculados
CROSS APPLY ( SELECT   
                Neto = ISNULL(a.Cargo,0) - ISNULL( a.Abono,0)
            ) Calc

UNION -- Reevaluaciones del Mes
  
SELECT
  Rama = 'REV',
  AuxID = NULL,
  c.Empresa,
  c.Sucursal,
  Cuenta = c.Cliente,
  c.Mov,
  c.MovID,
  Modulo = 'CXC',
  ModuloID = c.ID,
  MovClave = t.Clave,
  Moneda = c.ClienteMoneda,
  TipoCambio = c.ClienteTipoCambio,
  c.Ejercicio,
  c.Periodo,
  Fecha = CAST(c.FechaEmision AS DATE),
  Cargo = 0,
  Abono = 0,
  Neto = 0,
  CargoMN = ISNULL(impCargoAbono.Cargo,0),
  AbonoMN = ISNULL(impCargoAbono.Abono,0),
  NetoMN = ISNULL(impCargoAbono.Cargo,0) -ISNULL( impCargoAbono.Abono,0),
  EsCancelacion = 0,
  d.Aplica,
  d.AplicaID,
  AplicaClave = at.Clave,
  OrigenModulo =  '',
  OrigenMov = '',
  OrigenMovID = '',
  IVAFiscal = ISNULL(doc.IVAFiscal,0),
  FactorRetencion = CASE
                      WHEN ISNULL(doc.IVAFiscal,0) = 0 
                        OR ISNULL(doc.Impuestos,0) = 0 THEN
                        0
                      ELSE
                        ISNULL(doc.Retencion,0) / ISNULL(doc.Impuestos,0)
                    END
FROM 
  Cxc c
JOIN Cte ON Cte.Cliente = c.Cliente
JOIN CxcD d ON d.Id = c.ID
JOIN movtipo t ON t.Modulo = 'CXC'
              AND t.Mov  = c.Mov 
-- Documento
LEFT JOIN Cxc doc ON doc.Mov = d.Aplica
                  AND doc.MovID = d.AplicaID    
LEFT JOIN movtipo at ON at.Modulo = 'CXC'
                    AND at.Mov = d.Aplica
-- Cargos Abonos ( para mantener el formato del auxiliar )
CROSS APPLY (
              SELECT 
                Cargo = CASE
                          WHEN ISNULL(d.Importe,0) >= 0 THEN
                            ISNULL(d.Importe,0)
                          ELSE 
                            0
                        END,
                Abono = CASE
                          WHEN ISNULL(d.Importe,0) < 0 THEN
                            ABS(ISNULL(d.Importe,0))
                          ELSE 
                            0
                        END
              ) impCargoAbono
WHERE 
  t.Clave = 'CXC.RE'
AND c.Estatus = 'CONCLUIDO'