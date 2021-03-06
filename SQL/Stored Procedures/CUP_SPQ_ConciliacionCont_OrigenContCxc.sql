SET ANSI_NULLS, ANSI_WARNINGS ON;

GO

IF EXISTS (SELECT * 
		   FROM SYSOBJECTS 
		   WHERE ID = OBJECT_ID('dbo.CUP_SPQ_ConciliacionCont_OrigenContCxc') AND 
				 TYPE = 'P')
BEGIN
  DROP PROCEDURE dbo.CUP_SPQ_ConciliacionCont_OrigenContCxc
END	

GO

/* =============================================
  Created by:    Enrique Sierra Gtez
  Creation Date: 2016-11-15

  Description: Obtiene los movimientos que componen
  el auxiliar Cxc desde el modulo de  cxc y con la 
  suficiente iformacion para poderlos cruzar 
  "lado a lado" con su p�liza  contable.
 
  Example: EXEC CUP_SPQ_ConciliacionCont_OrigenContCxc 63527, 3, 2016, 10
 ============================================= */

CREATE PROCEDURE dbo.CUP_SPQ_ConciliacionCont_OrigenContCxc
  @Empleado INT,
  @Tipo INT,
  @Ejercicio INT,
  @Periodo INT
AS BEGIN 

  SET NOCOUNT ON;

  -- Tabla utilizada a modo de "workaround" 
  -- para poder simular el efecto de "EsCancelacion"
  -- directo en el modulo.
  DECLARE @EstatusValidos TABlE
  (
    Estatus VARCHAR(15) NOT NULL,
    EsCancelacion BIT NOT NULL ,
    Factor SMALLINT NOT NULL,
    PRIMARY KEY (
                  Estatus,
                  EsCancelacion
                )
  )
  

  IF @Tipo = 3 
  BEGIN
    INSERT INTO @EstatusValidos
    ( 
      Estatus,
      EsCancelacion,
      Factor 
    )
    VALUES 
      ( 'CONCLUIDO', 0,  1 ),
      ( 'PENDIENTE', 0,  1 ),
      ( 'CANCELADO', 0,  1 ), 
      ( 'CANCELADO', 1, -1 )
  END

  SELECT
    Empleado = @Empleado,
    origenCont.Modulo,
    m.ID,
    m.Mov,
    m.MovId,
    m.Sucursal,
    m.FechaEmision,
    Cuenta = m.Cliente,
    Nombre =  REPLACE(REPLACE(REPLACE(Cte.Nombre,CHAR(13),''),CHAR(10),''),CHAR(9),''),
    m.Estatus,
    eV.EsCancelacion,
    Moneda = m.ClienteMoneda,
    TipoCambio  = m.ClienteTipoCambio,
    ImporteTotal = conversion_doc.ImporteTotal 
                 * ISNULL(origenCont.Factor,1) 
                 * eV.Factor,
    FluctuacionCambiariaMN = ROUND(
                              ISNULL(fc.DiferenciaCambiaria,0)
                            * eV.Factor 
                        , 4, 1),
    ImporteTotalMN = ROUND(
                            (
                               ( conversion_doc.ImporteTotal * m.ClienteTipoCambio )
                             + ISNULL(fc.DiferenciaCambiaria,0) 
                            )
                            * ISNULL(origenCont.Factor,1)
                            * eV.Factor 
                     , 4, 1),
    AuxiliarModulo = origenCont.AuxModulo,
    AuxiliaMov = origenCont.AuxMov,
    PolizaID =  pf.DID
  FROM 
    CUP_ConciliacionCont_Tipo_OrigenContable origenCont 
  JOIN Cxc m ON origenCont.Mov = m.Mov
  JOIN Cte ON Cte.Cliente = m.Cliente
  JOIN @EstatusValidos eV ON eV.Estatus = m.Estatus
  -- Factor Moneda Documento
  CROSS APPLY( SELECT   
                  FactorTC =   m.TipoCambio / m.ClienteTipoCambio,
                  ImporteTotal =  ROUND(  ( ISNULL(m.Importe,0) + ISNULL(m.Impuestos,0) - ISNULL(m.Retencion,0) )
                                        * (m.TipoCambio / m.ClienteTipoCambio), 4, 1)
              ) conversion_doc 
  -- Fluctuacion Cambiaria
  OUTER APPLY(SELECT
                DiferenciaCambiaria = SUM( ISNULL( dc.Diferencia_Cambiaria_MN, 0 ) )
                                    * ISNULL( origenCont.Factor, 1 )
              FROM 
                CUP_v_CxDiferenciasCambiarias dc
              WHERE
                dc.Modulo = origenCont.Modulo
              AND dc.ModuloID = m.ID) fc
  -- Excepciones Cuentas
  LEFT JOIN CUP_ConciliacionCont_Excepciones eX ON ex.TipoConciliacion = @Tipo
                                               AND ex.TipoExcepcion = 1
                                               AND ex.Valor = m.Cliente
  -- Poliza Contable
  OUTER APPLY( 
               SELECT 
                 mf.DID
               FROM 
                MovFlujo mf
               WHERE 
                 mf.DModulo = 'CONT'
               AND mf.OModulo = origenCont.Modulo
               AND mf.OID = m.ID               
               AND ( 
                      (   
                          m.Estatus = 'CANCELADO'
                      AND (
                             (
                                eV.EsCancelacion = 1 
                             AND mf.DID = m.ContID
                             )
                          OR (
                                eV.EsCancelacion = 0
                             AND mf.DID < m.ContID
                             )
                          )
                      )
                  OR  (
                        m.Estatus <> 'CANCELADO'
                      AND mf.DID = m.ContID
                      )
                  )
              ) pf
  WHERE
    OrigenCont.Tipo = @Tipo 
  AND OrigenCont.UsarAuxiliarNeto = 0
  AND origenCont.Modulo = 'CXC'
  AND (  origenCont.ValidarOrigen = 0
      OR (  
            origenCont.ValidarOrigen = 1 
          AND ISNULL(origenCont.OrigenTipo,'') = ISNULL(m.OrigenTipo,'')
          AND ISNULL(origenCont.Origen,'') = ISNULL(m.Origen,'')
        )
      )
  AND m.Ejercicio = @Ejercicio
  AND m.Periodo = @Periodo
  AND m.Estatus IN ('PENDIENTE','CANCELADO','CONCLUIDO')
  -- Filtro Excepciones cuenta
  AND eX.ID IS NULL

  UNION 

  --  Une los movimientos que por su naturaleza es mas facil detectar el impacto 
  --  a Clientes desde los auxiliares de CxC. Como es el caso 
  --  de la Aplicaciones y Endosos donde se puede considerar su Neto.

  SELECT 
    Empleado = @Empleado,
    origenCont.Modulo,
    aux.ModuloID,
    aux.Mov,
    aux.MovId,
    aux.Sucursal,
    m.FechaEmision,
    Cuenta = m.Cliente,
    Nombre = cf.Nombre,
    m.Estatus,
    aux.EsCancelacion,
    aux.Moneda,
    aux.TipoCambio,
    ImporteTotal = SUM(ISNULL(aux.Cargo,0) - ISNULL(aux.Abono,0)),
    FluctuacionCambiariaMN = ROUND(
                                  SUM( ISNULL(fc.Diferencia_Cambiaria_MN,0) * ISNULL(fctorCanc.Factor,1))
                                  ,4,1),
    ImporteTotalMN = ROUND(
                       SUM( 
                            ( ( ISNULL(aux.Cargo,0) - ISNULL(aux.Abono,0) )  * aux.TipoCambio )
                          + ( ISNULL(fc.Diferencia_Cambiaria_MN,0) * ISNULL(fctorCanc.Factor,1) ) 
                          )
                     , 4, 1),
    AuxiliarModulo = origenCont.AuxModulo,
    AuxiliaMov = origenCont.AuxMov,
    PolizaID  = pf.DID
  FROM 
    CUP_ConciliacionCont_Tipo_OrigenContable origenCont
  JOIN CUP_v_AuxiliarCxc aux ON aux.Modulo = origenCont.Modulo
                            AND aux.Mov    = origenCont.Mov
  JOIN Cte ON Cte.Cliente = aux.Cuenta
  JOIN Cxc m ON m.ID = aux.ModuloID
  -- Factor Canceclacion
  CROSS APPLY(SELECT
               Factor  = CASE ISNULL(aux.EsCancelacion,0) 
                           WHEN 1 THEN
                             -1
                           ELSE 
                              1
                          END) fctorCanc 
  -- Fluctuacion Cambiaria
  LEFT JOIN CUP_v_CxDiferenciasCambiarias fc ON fc.Modulo = aux.Modulo
                                            AND fc.ModuloID = aux.ModuloId
                                            AND fc.Documento = aux.Aplica
                                            AND fc.DocumentoID = aux.AplicaID
  -- Clean Fields
  OUTER APPLY (  
                SELECT
                  Nombre = ISNULL(REPLACE(REPLACE(REPLACE(Cte.Nombre,CHAR(13),''),CHAR(10),''),CHAR(9),''),'')
              ) cf
  -- Excepciones Cuentas
  LEFT JOIN CUP_ConciliacionCont_Excepciones eX ON ex.TipoConciliacion = @Tipo
                                               AND ex.TipoExcepcion = 1
                                               AND ex.Valor = aux.Cuenta
  -- Poliza Contable
  OUTER APPLY( 
               SELECT TOP 1
                 mf.DID
               FROM 
                MovFlujo mf
               WHERE 
                 mf.DModulo = 'CONT'
               AND mf.OModulo = origenCont.Modulo
               AND mf.OID = m.ID               
               AND ( 
                      (   
                          m.Estatus = 'CANCELADO'
                      AND (
                             (
                                aux.EsCancelacion = 1 
                             AND mf.DID = m.ContID
                             )
                          OR (
                                aux.EsCancelacion = 0
                             AND mf.DID < m.ContID
                             )
                          )
                      )
                  OR  (
                        m.Estatus <> 'CANCELADO'
                      AND mf.DID = m.ContID
                      )
                  )
              ) pf
  WHERE
      origenCont.Tipo = @Tipo 
  AND origenCont.UsarAuxiliarNeto = 1 
  AND origenCont.Modulo = 'CXC'
  AND aux.Ejercicio = @Ejercicio
  AND aux.Periodo = @Periodo
  AND (  origenCont.ValidarOrigen = 0
      OR (  
            origenCont.ValidarOrigen = 1 
          AND ISNULL(origenCont.OrigenTipo,'') = ISNULL(m.OrigenTipo,'')
          AND ISNULL(origenCont.Origen,'') = ISNULL(m.Origen,'')
        )
      )
  -- Filtro Excepciones cuenta
  AND eX.ID IS NULL
  GROUP BY 
    origenCont.Modulo,
    aux.ModuloID,
    aux.Mov,
    aux.MovId,
    aux.Sucursal,
    m.FechaEmision,
    m.Cliente,
    cf.Nombre,
    m.Estatus,
    aux.EsCancelacion,
    aux.Moneda,
    aux.TipoCambio,
    origenCont.AuxModulo,
    origenCont.AuxMov,
    pf.DID
END