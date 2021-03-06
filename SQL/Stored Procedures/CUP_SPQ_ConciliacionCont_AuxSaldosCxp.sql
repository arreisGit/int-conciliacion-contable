SET ANSI_NULLS, ANSI_WARNINGS ON;

GO

IF EXISTS (SELECT * 
		   FROM SYSOBJECTS 
		   WHERE ID = OBJECT_ID('dbo.CUP_SPQ_ConciliacionCont_AuxSaldosCxp') AND 
				 TYPE = 'P')
BEGIN
  DROP PROCEDURE dbo.CUP_SPQ_ConciliacionCont_AuxSaldosCxp
END	

GO

/* =============================================
   Created by:    Enrique Sierra Gtez
   Creation Date: 2016-11-18

   Description: Obtiene los auxiliares de
   los Saldos Cxp 
   Example: EXEC CUP_SPQ_ConciliacionCont_AuxSaldosCxp 63527, 3, 2016, 10
 ============================================= */

CREATE PROCEDURE dbo.CUP_SPQ_ConciliacionCont_AuxSaldosCxp
  @Empleado INT,
  @Tipo INT,
  @Ejercicio INT,
  @Periodo INT
AS BEGIN 

  SET NOCOUNT ON;

  SELECT
    Empleado = @Empleado,
    aux.Rama,
    aux.AuxID,
    aux.Sucursal,
    aux.Cuenta,
    aux.Mov,
    aux.MovId,
    aux.Modulo,
    aux.ModuloID,
    aux.Moneda,
    aux.TipoCambio,
    aux.Ejercicio,
    aux.Periodo,
    aux.Fecha,
    aux.Cargo,
    aux.Abono,
    aux.Neto,
    aux.CargoMN,
    aux.AbonoMN,
    aux.NetoMN,
    calc.FluctuacionMN,
    TotalMN = ROUND(  
                    aux.NetoMN
                  + calc.FluctuacionMN
              ,4,1),
    aux.EsCancelacion,
    aux.Aplica,
    aux.AplicaID,
    aux.OrigenModulo,
    aux.OrigenMov,
    aux.OrigenMovID
  FROM
    CUP_v_AuxiliarCxp aux
  LEFT JOIN CUP_ConciliacionCont_Excepciones ex ON ex.TipoConciliacion = @Tipo 
                                               AND ex.TipoExcepcion = 1 
                                               AND ex.Valor = LTRIM(RTRIM(aux.Cuenta))
  LEFT JOIN CUP_v_CxDiferenciasCambiarias fc ON fc.Modulo = aux.Modulo
                                          AND fc.ModuloID = aux.ModuloId
                                          AND fc.Documento = aux.Aplica
                                          AND fc.DocumentoID = aux.AplicaID
  -- Factores
  CROSS APPLY(SELECT
                FactorCanc  = CASE ISNULL(aux.EsCancelacion,0) 
                                WHEN 1 THEN
                                  -1
                                ELSE 
                                  1
                              END) f 
  -- Campos Calculados
CROSS APPLY ( SELECT
                FluctuacionMN =  ROUND( -ISNULL(fc.Diferencia_Cambiaria_MN,0) * ISNULL(f.FactorCanc,1),4,1)
            ) Calc
  WHERE 
    aux.Ejercicio = @Ejercicio
  AND aux.Periodo = @Periodo
  AND ex.ID IS NULL

END