-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Pesquisa Datalake MB5B - Empresa 4014 / Centro 4128
-- MAGIC
-- MAGIC Objetivo: gerar novamente a base do Datalake na mesma granularidade usada para comparação com a exportação SAP MB5B.
-- MAGIC
-- MAGIC Origem: `dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Parâmetros do cenário

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW parametros_mb5b AS
SELECT
    '4014' AS cod_empresa,
    '4128' AS cod_centro;

SELECT * FROM parametros_mb5b;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. Base histórica do cenário

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW base_mb5b_4014_4128 AS
SELECT
    v.cod_empresa,
    v.cod_centro,
    v.cod_material,
    v.desc_material,
    v.sg_unidade_medida,
    v.dt_estoque,
    v.estoque_inicial,
    v.entrada,
    v.saida,
    v.estoque_final,
    v.dh_carga,
    v.dh_atualizacao
FROM dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta v
INNER JOIN parametros_mb5b p
    ON v.cod_empresa = p.cod_empresa
   AND v.cod_centro = p.cod_centro;

SELECT
    COUNT(*) AS linhas_historicas,
    COUNT(DISTINCT REGEXP_REPLACE(TRIM(cod_material), '^0+', '')) AS materiais_distintos,
    MIN(dt_estoque) AS primeira_data,
    MAX(dt_estoque) AS ultima_data,
    MAX(dh_carga) AS ultima_carga,
    MAX(dh_atualizacao) AS ultima_atualizacao
FROM base_mb5b_4014_4128;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Consistência cadastral antes da consolidação
-- MAGIC Um mesmo material não deveria possuir mais de uma descrição ou unidade de medida no recorte.

-- COMMAND ----------

SELECT
    REGEXP_REPLACE(TRIM(cod_material), '^0+', '') AS material,
    COUNT(DISTINCT TRIM(desc_material)) AS descricoes_distintas,
    COUNT(DISTINCT UPPER(TRIM(sg_unidade_medida))) AS unidades_distintas,
    COLLECT_SET(TRIM(desc_material)) AS descricoes,
    COLLECT_SET(UPPER(TRIM(sg_unidade_medida))) AS unidades
FROM base_mb5b_4014_4128
GROUP BY REGEXP_REPLACE(TRIM(cod_material), '^0+', '')
HAVING COUNT(DISTINCT TRIM(desc_material)) > 1
    OR COUNT(DISTINCT UPPER(TRIM(sg_unidade_medida))) > 1
ORDER BY material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Consolidação por material
-- MAGIC Esta é a base a exportar para a comparação SAP x Datalake.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW dl_mb5b_4014_4128 AS
SELECT
    cod_empresa,
    cod_centro,
    REGEXP_REPLACE(TRIM(cod_material), '^0+', '') AS material,
    MAX(TRIM(desc_material)) AS desc_material,
    MAX(UPPER(TRIM(sg_unidade_medida))) AS sg_unidade_medida,
    SUM(estoque_inicial) AS estoque_inicial,
    SUM(entrada) AS entrada,
    SUM(saida) AS saida,
    SUM(estoque_final) AS estoque_final
FROM base_mb5b_4014_4128
GROUP BY
    cod_empresa,
    cod_centro,
    REGEXP_REPLACE(TRIM(cod_material), '^0+', '');

SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT material) AS materiais_distintos,
    ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT material), 0), 4) AS linhas_por_material
FROM dl_mb5b_4014_4128;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Equação contábil da base consolidada

-- COMMAND ----------

SELECT
    COUNT(*) AS materiais,
    COUNT_IF(ABS((estoque_inicial + entrada + saida) - estoque_final) <= 0.005) AS equacao_ok,
    COUNT_IF(ABS((estoque_inicial + entrada + saida) - estoque_final) > 0.005) AS divergentes,
    MAX(ABS((estoque_inicial + entrada + saida) - estoque_final)) AS maior_diferenca
FROM dl_mb5b_4014_4128;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Saída final para exportação
-- MAGIC No resultado desta célula, use o menu de download da grade e exporte em CSV.
-- MAGIC Nome sugerido: `DL_MB5B_4014_4128_20260924.csv`.

-- COMMAND ----------

SELECT
    cod_empresa,
    cod_centro,
    material,
    desc_material,
    sg_unidade_medida,
    estoque_inicial,
    entrada,
    saida,
    estoque_final
FROM dl_mb5b_4014_4128
ORDER BY TRY_CAST(material AS BIGINT), material;