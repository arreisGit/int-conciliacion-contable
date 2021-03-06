USE [Cuprum]
GO
/****** Object:  StoredProcedure [dbo].[CUP_SPP_AsignaCuentaPorSucursal]    Script Date: 30/11/2016 05:42:01 p. m. ******/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF
GO
/* =============================================
  Author:		Alejandra Camarena Barrón (Intelisis)
  Create date: 2016/11/30
  Description:	Procedimiento para tomar la cuenta contable de acuerdo a la sucursal.
  EXAMPLE: EXEC CUP_SPP_AsignaCuentaPorSucursal 0
 ============================================= */
CREATE PROCEDURE [dbo].[CUP_SPP_AsignaCuentaPorSucursal]
	@Sucursal int
AS
BEGIN
	DECLARE 
	@Cuenta varchar(20)
	SET NOCOUNT ON;
    SELECT @Cuenta = 
		CASE    @Sucursal
		 WHEN 0 THEN '213-100-000-0000'   
		 WHEN 1 THEN '213-200-000-0000'   
		 WHEN 2 THEN '213-300-000-0000'
		 WHEN 3 THEN '213-400-000-0000'
		 WHEN 4 THEN '213-700-000-0000'
		 WHEN 5 THEN '213-500-000-0000'
		 WHEN 6 THEN '213-600-000-0000'
		 WHEN 7 THEN '213-701-000-0000'
		END

	SELECT  RTRIM(LTRIM(@Cuenta))
END
