SET ANSI_NULLS, ANSI_WARNINGS ON;

GO

IF EXISTS (SELECT * 
		   FROM SYSOBJECTS 
		   WHERE ID = OBJECT_ID('dbo.CUP_SPI_ConciliacionCont_SaldosEsperados') AND 
				 TYPE = 'P')
BEGIN
  DROP PROCEDURE dbo.CUP_SPI_ConciliacionCont_SaldosEsperados 
END	

GO

/* =============================================
  Created by:    Enrique Sierra Gtez
  Creation Date: 2016-10-27

  Description: Obtiene los Saldos Iniciales y Finales
  que se usaran para la conciliacion Cotable
 
  Example: EXEC CUP_SPQ_ConciliacionCont_SaldosEsperados 63527, 3, 2016, 10
 ============================================= */

CREATE PROCEDURE dbo.CUP_SPI_ConciliacionCont_SaldosEsperados
  @Empleado   INT,
  @Tipo      INT,
  @Ejercicio INT,
  @Periodo   INT
AS BEGIN 

  SET NOCOUNT ON;

  DECLARE
    @TC_Inicial FLOAT,
    @TC_Final FLOAT,
    @FechaFin DATE,
    @FechaInicio DATE = CAST(CAST(@Ejercicio AS VARCHAR)
                                    + '-' 
                                    + CAST(@Periodo AS VARCHAR)
                                    + '-01' AS DATE)

  SET @FechaFin = DATEADD(DAY,-1,DATEADD(MONTH,1,@FechaInicio))

  SELECT TOP 1
    @TC_Inicial = TipoCambio 
  FROM
    MonHist
  WHERE 
    CAST(Fecha AS DATE) < @FechaInicio
  AND Moneda = 'Dlls'
  ORDER BY
    ID DESC

  SELECT TOP 1
    @TC_Final = TipoCambio 
  FROM
    MonHist
  WHERE 
    CAST(Fecha As DATE) <= @FechaFin
  AND Moneda = 'Dlls'
  ORDER BY
    ID DESC
  
  DECLARE @AntSaldosCxCorte TABLE
  (
    Mov CHAR(20) NOT NULL,
    MovID VARCHAR(20) NOT NULL,
    Moneda CHAR(10) NOT NULL,
    SaldoInicial DECIMAL(18,4) NOT NULL,
    SaldoFinal DECIMAL(18,4) NOT NULL
    PRIMARY KEY ( 
                    Mov,
                    MovID,
                    Moneda
                )
  )

  DECLARE @SaldosEsperados TABLE
  ( 
    Orden INT NOT NULL,
    Concepto VARCHAR(50) NOT NULL,
    ImporteDlls DECIMAL(18,4) NOT NULL,
    ImporteConversionMN DECIMAL(18,4) NOT NULL,
    ImporteMN   DECIMAL(18,4) NOT NULL,
    TotalMN DECIMAL(18,4) NOT NULL,
    Contabilidad DECIMAL(18,4) NOT NULL,
    Variacion DECIMAL(18,4) NOT NULL,
    PRIMARY KEY ( 
                  Orden,
                  Concepto
                )
  )
  
  -- Vacia los saldos AuxCx en un Consolidado.
  DECLARE @SaldosCx TABLE
  (
    Ejercicio INT NOT NULL, 
    Periodo INT NOT NULL,
    ImporteInicialDlls DECIMAL(18,4) NOT NULL,
    ImporteInicialConversionMN DECIMAL(18,4) NOT NULL,
    ImporteInicialMN DECIMAL(18,4) NOT NULL,
    ImporteInicialTotalMN DECIMAL(18,4) NOT NULL,
    ImporteFinalDlls DECIMAL(18,4) NOT NULL,
    ImporteFinalConversionMN DECIMAL(18,4) NOT NULL,
    ImporteFinalMN DECIMAL(18,4) NOT NULL,
    ImporteFinalTotalMN DECIMAL(18,4) NOT NULL
    PRIMARY KEY (
                  Ejercicio,
                  Periodo
                )
  )
  -- 1 ) Obtenemos AntigŁedad Corte Cx

  -- Saldo Proveedores
  IF @Tipo = 1 
  BEGIN
    INSERT INTO @SaldosCx
    (
      Ejercicio,
      Periodo,
      ImporteInicialDlls,
      ImporteInicialConversionMN,
      ImporteInicialMN,
      ImporteInicialTotalMN,
      ImporteFinalDlls,
      ImporteFinalConversionMN,
      ImporteFinalMN,
      ImporteFinalTotalMN
    )
    EXEC CUP_SPQ_ConciliacionCont_SaldosEsperados_AuxCxp @Ejercicio, @Periodo
  END

  -- IVA Por Acreeditar
  IF @Tipo = 2
  BEGIN
    INSERT INTO @SaldosCx
    (
      Ejercicio,
      Periodo,
      ImporteInicialDlls,
      ImporteInicialConversionMN,
      ImporteInicialMN,
      ImporteInicialTotalMN,
      ImporteFinalDlls,
      ImporteFinalConversionMN,
      ImporteFinalMN,
      ImporteFinalTotalMN
    )
    EXEC CUP_SPQ_ConciliacionCont_SaldosEsperados_IVAPorAcreditar @Ejercicio, @Periodo
  END

  -- Saldo Clientes
  ELSE IF @Tipo = 3 
  BEGIN  
    INSERT INTO @SaldosCx
    (
      Ejercicio,
      Periodo,
      ImporteInicialDlls,
      ImporteInicialConversionMN,
      ImporteInicialMN,
      ImporteInicialTotalMN,
      ImporteFinalDlls,
      ImporteFinalConversionMN,
      ImporteFinalMN,
      ImporteFinalTotalMN
    )
    EXEC CUP_SPQ_ConciliacionCont_SaldosEsperados_AuxCxc @Ejercicio, @Periodo
  END

  -- IVA Trasladado
  IF @Tipo = 4
  BEGIN
    INSERT INTO @SaldosCx
    (
      Ejercicio,
      Periodo,
      ImporteInicialDlls,
      ImporteInicialConversionMN,
      ImporteInicialMN,
      ImporteInicialTotalMN,
      ImporteFinalDlls,
      ImporteFinalConversionMN,
      ImporteFinalMN,
      ImporteFinalTotalMN
    )
    EXEC CUP_SPQ_ConciliacionCont_SaldosEsperados_IVATrasladado @Ejercicio, @Periodo
  END

 
  -- 2) Obtenemos los saldos Iniciales  y Finales de Cont.
  DECLARE @AuxCont TABLE
  (
    Ejercicio INT NOT NULL,
    Periodo INT NOT NULL,
    SaldoInicial DECIMAL(18,4) NOT NULL,
    SaldoFinal   DECIMAL(18,4) NOT NULL
    PRIMARY KEY (
                  Ejercicio,
                  Periodo
                )
  )
  
  INSERT INTO @AuxCont
  (
    Ejercicio,
    Periodo,
    SaldoInicial,
    SaldoFinal
  )
  SELECT 
    @Ejercicio,
    @Periodo,
    SaldoInicial = ISNULL
                   (
                     SUM(CASE 
                          WHEN CAST(d.FechaContable AS DATE) < @FechaInicio THEN 
                            (ISNULL(d.Debe,0) - ISNULL(d.Haber,0)) * f.Factor
                          ELSE
                            0
                        END)
                     , 0 
                   ),
    SaldoFinal =  ISNULL
                  (
                     SUM((ISNULL(d.Debe,0) - ISNULL(d.Haber,0)) * f.Factor)
                    , 0
                  )
  FROM 
    CUP_ConciliacionCont_Tipo_CuentasContables cL
  JOIN Cta ON Cta.Cuenta = cl.Cuenta
  JOIN ContD d ON cl.Cuenta = d.Cuenta
  JOIN Cont c ON d.ID = c.ID 
  OUTER APPLY( SELECT 
                Factor = CASE
                            WHEN  ISNULL(Cta.EsAcreedora,0) = 1 
                            AND  @Tipo <> 3  THEN 
                                -1
                            ELSE 
                                1
                          END,
                PolizaManual = CASE 
                                  WHEN ISNULL(c.OrigenTipo,'') = '' THEN
                                    1
                                  ELSE 
                                    0
                                END
            ) f
  WHERE
    cl.Tipo = @Tipo   
  AND c.Estatus = 'CONCLUIDO'
  AND CAST(d.FechaContable AS DATE) <= @FechaFin

  -- 3 ) Integra los Saldos de Cx y Cont en el formato
  -- adecuado para su retorno.
  INSERT INTO #tmp_CUP_ConciliacionCont_Caratula
  (
    Orden,
    Concepto,
    ImporteDlls,
    ImporteConversionMN,
    ImporteMN,
    TotalMN,
    Contabilidad,
    Variacion
  )
  SELECT 
    Orden = 1,
    Concepto = 'Saldo Inicial Intelisis',
    ImporteDlls = ISNULL(cx.ImporteInicialDlls,0),
    ImporteConversionMN = ISNULL(cx.ImporteInicialConversionMN,0),
    ImporteMN = ISNULL(cx.ImporteInicialMN,0),
    TotalMN = ISNULL(cx.ImporteInicialTotalMN,0),
    Contabilidad = ISNULL(cont.SaldoInicial,0),
    Variacion = ISNULL(cx.ImporteInicialTotalMN,0) - ISNULL(cont.SaldoInicial,0)
  FROM 
    @SaldosCx cx
  FULL OUTER JOIN @AuxCont cont ON cont.Ejercicio = cx.Ejercicio
                               AND cont.Periodo = cx.Periodo 
  UNION
  SELECT 
    Orden = 5,
    Concepto = 'Saldo Final Intelisis',
    ImporteDlls = ISNULL(cx.ImporteFinalDlls,0),
    ImporteConversionMN = ISNULL(cx.ImporteFinalConversionMN,0),
    ImporteMN = ISNULL(cx.ImporteFinalMN,0),
    TotalMN = ISNULL(cx.ImporteFinalTotalMN,0),
    Contabilidad = ISNULL(cont.SaldoFinal,0),
    Variacion = ISNULL(cx.ImporteFinalTotalMN,0) - ISNULL(cont.SaldoFinal,0)
  FROM 
    @SaldosCx cx
  FULL OUTER JOIN @AuxCont cont ON cont.Ejercicio = cx.Ejercicio
                               AND cont.Periodo = cx.Periodo 

  
END