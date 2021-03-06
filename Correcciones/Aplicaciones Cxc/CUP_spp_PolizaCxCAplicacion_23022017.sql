USE [Cuprum]
GO
/****** Object:  StoredProcedure [dbo].[CUP_SPP_PolizaCxCAplicacion]    Script Date: 23/02/2017 11:20:47 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Alejandra Camarena Barrón
-- Create date: 18/01/2016
-- Description:	Póliza de 
-- =============================================
ALTER PROCEDURE [dbo].[CUP_SPP_PolizaCxCAplicacion] 
	  @ID       int,
	  @Modulo		char(10)
AS
BEGIN
DECLARE 
	@ImporteIVA FLOAT 

	Select 
	SUM(Diferencia_cambiaria_tcorigen_mn * dc.ivafiscal)
	From CUP_v_CxDiferenciasCambiarias dc 
	Where dc.moduloid = @ID
	AND dc.modulo = @Modulo
	
END