-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Pesquisa Datalake MB5B - 4014 / 4128 - Corrigida
-- MAGIC
-- MAGIC Consolidação histórica compatível com relatório MB5B:
-- MAGIC - estoque inicial: valor da primeira data do material
-- MAGIC - entradas: soma do período
-- MAGIC - saídas: soma do período
-- MAGIC - estoque final: valor da última data do material

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW base_mb5b_4014_4128 AS
SELECT
  cod_empresa,
  cod_centro,
  REGEXP_REPLACE(TRIM(cod_material), '^0+', '') AS material,
  TRIM(desc_material) AS desc_material,
  UPPER(TRIM(sg_unidade_medida)) AS sg_unidade_medida,
  dt_estoque,
  estoque_inicial,
  entrada,
  saida,
  estoque_final,
  dh_carga,
  dh_atualizacao
FROM dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta
WHERE cod_empresa = '4014'
  AND cod_centro = '4128';

SELECT
  COUNT(*) AS linhas_historicas,
  COUNT(DISTINCT material) AS materiais_distintos,
  MIN(dt_estoque) AS primeira_data,
  MAX(dt_estoque) AS ultima_data,
  MAX(dh_carga) AS ultima_carga,
  MAX(dh_atualizacao) AS ultima_atualizacao
FROM base_mb5b_4014_4128;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Consistência cadastral

-- COMMAND ----------

SELECT
  material,
  COUNT(DISTINCT desc_material) AS descricoes_distintas,
  COUNT(DISTINCT sg_unidade_medida) AS unidades_distintas,
  COLLECT_SET(desc_material) AS descricoes,
  COLLECT_SET(sg_unidade_medida) AS unidades
FROM base_mb5b_4014_4128
GROUP BY material
HAVING COUNT(DISTINCT desc_material) > 1
    OR COUNT(DISTINCT sg_unidade_medida) > 1
ORDER BY material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Consolidação histórica correta

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW dl_mb5b_4014_4128 AS
SELECT
  cod_empresa,
  cod_centro,
  material,
  MAX_BY(desc_material, dt_estoque) AS desc_material,
  MAX_BY(sg_unidade_medida, dt_estoque) AS sg_unidade_medida,
  MIN_BY(estoque_inicial, dt_estoque) AS estoque_inicial,
  SUM(entrada) AS entrada,
  SUM(saida) AS saida,
  MAX_BY(estoque_final, dt_estoque) AS estoque_final,
  MIN(dt_estoque) AS primeira_data,
  MAX(dt_estoque) AS ultima_data,
  COUNT(*) AS dias_registrados
FROM base_mb5b_4014_4128
GROUP BY cod_empresa, cod_centro, material;

SELECT
  COUNT(*) AS linhas,
  COUNT(DISTINCT material) AS materiais_distintos,
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT material), 0), 4) AS linhas_por_material
FROM dl_mb5b_4014_4128;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validação contábil após consolidação

-- COMMAND ----------

SELECT
  COUNT(*) AS materiais,
  COUNT_IF(ABS((estoque_inicial + entrada + saida) - estoque_final) <= 0.005) AS equacao_ok,
  COUNT_IF(ABS((estoque_inicial + entrada + saida) - estoque_final) > 0.005) AS divergentes,
  MAX(ABS((estoque_inicial + entrada + saida) - estoque_final)) AS maior_diferenca
FROM dl_mb5b_4014_4128;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Amostra para conferência com SAP

-- COMMAND ----------

SELECT *
FROM dl_mb5b_4014_4128
WHERE material IN ('100107','100341','100350')
ORDER BY material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Saída final para exportação CSV

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
  estoque_final,
  primeira_data,
  ultima_data,
  dias_registrados
FROM dl_mb5b_4014_4128
ORDER BY TRY_CAST(material AS BIGINT), material;