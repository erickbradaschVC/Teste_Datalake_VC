-- Databricks notebook source
-- MAGIC %md
-- MAGIC # MB51 - Analise Exploratoria do Datalake - PROD (SQL corrigido completo)
-- MAGIC **Objeto:** `prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material`
-- MAGIC
-- MAGIC Notebook consolidado com consultas executaveis diretamente, sem etapas de copiar SQL gerado para outras celulas.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Criacao da base

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW base AS
SELECT * FROM prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. Estrutura e metadados

-- COMMAND ----------

DESCRIBE EXTENDED prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material;

-- COMMAND ----------

SELECT ordinal_position, column_name, full_data_type, is_nullable, comment
FROM prd_procurement.information_schema.columns
WHERE table_schema = 'corp_curated' AND table_name = 'vw_ds_log_mb51_movimentacao_material'
ORDER BY ordinal_position;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Volumetria e amostra

-- COMMAND ----------

SELECT COUNT(*) AS total_linhas FROM base;

-- COMMAND ----------

SELECT * FROM base LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Preenchimento de todas as colunas
-- MAGIC Nulos, vazios/defaults, zeros e valores uteis para todas as 24 colunas.

-- COMMAND ----------

SELECT * FROM (
SELECT 'cod_centro' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`cod_centro` IS NULL) AS nulos, COUNT_IF(`cod_centro` IS NOT NULL AND LOWER(TRIM(CAST(`cod_centro` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`cod_centro` IS NOT NULL AND TRIM(CAST(`cod_centro` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`cod_centro` IS NULL) - COUNT_IF(`cod_centro` IS NOT NULL AND LOWER(TRIM(CAST(`cod_centro` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_centro` IS NOT NULL AND TRIM(CAST(`cod_centro` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`cod_centro` IS NULL) - COUNT_IF(`cod_centro` IS NOT NULL AND LOWER(TRIM(CAST(`cod_centro` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_centro` IS NOT NULL AND TRIM(CAST(`cod_centro` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'cod_material' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`cod_material` IS NULL) AS nulos, COUNT_IF(`cod_material` IS NOT NULL AND LOWER(TRIM(CAST(`cod_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`cod_material` IS NOT NULL AND TRIM(CAST(`cod_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`cod_material` IS NULL) - COUNT_IF(`cod_material` IS NOT NULL AND LOWER(TRIM(CAST(`cod_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_material` IS NOT NULL AND TRIM(CAST(`cod_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`cod_material` IS NULL) - COUNT_IF(`cod_material` IS NOT NULL AND LOWER(TRIM(CAST(`cod_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_material` IS NOT NULL AND TRIM(CAST(`cod_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'desc_material' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`desc_material` IS NULL) AS nulos, COUNT_IF(`desc_material` IS NOT NULL AND LOWER(TRIM(CAST(`desc_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`desc_material` IS NOT NULL AND TRIM(CAST(`desc_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`desc_material` IS NULL) - COUNT_IF(`desc_material` IS NOT NULL AND LOWER(TRIM(CAST(`desc_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`desc_material` IS NOT NULL AND TRIM(CAST(`desc_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`desc_material` IS NULL) - COUNT_IF(`desc_material` IS NOT NULL AND LOWER(TRIM(CAST(`desc_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`desc_material` IS NOT NULL AND TRIM(CAST(`desc_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'qt_movimento' AS coluna, 'double' AS tipo, COUNT(*) AS total, COUNT_IF(`qt_movimento` IS NULL) AS nulos, CAST(0 AS BIGINT) AS vazios_default, COUNT_IF(`qt_movimento` = 0) AS zeros, (COUNT(*) - COUNT_IF(`qt_movimento` IS NULL) - CAST(0 AS BIGINT) - COUNT_IF(`qt_movimento` = 0)) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`qt_movimento` IS NULL) - CAST(0 AS BIGINT) - COUNT_IF(`qt_movimento` = 0)) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'sg_unidade_medida' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`sg_unidade_medida` IS NULL) AS nulos, COUNT_IF(`sg_unidade_medida` IS NOT NULL AND LOWER(TRIM(CAST(`sg_unidade_medida` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`sg_unidade_medida` IS NOT NULL AND TRIM(CAST(`sg_unidade_medida` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`sg_unidade_medida` IS NULL) - COUNT_IF(`sg_unidade_medida` IS NOT NULL AND LOWER(TRIM(CAST(`sg_unidade_medida` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`sg_unidade_medida` IS NOT NULL AND TRIM(CAST(`sg_unidade_medida` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`sg_unidade_medida` IS NULL) - COUNT_IF(`sg_unidade_medida` IS NOT NULL AND LOWER(TRIM(CAST(`sg_unidade_medida` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`sg_unidade_medida` IS NOT NULL AND TRIM(CAST(`sg_unidade_medida` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'cod_deposito' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`cod_deposito` IS NULL) AS nulos, COUNT_IF(`cod_deposito` IS NOT NULL AND LOWER(TRIM(CAST(`cod_deposito` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`cod_deposito` IS NOT NULL AND TRIM(CAST(`cod_deposito` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`cod_deposito` IS NULL) - COUNT_IF(`cod_deposito` IS NOT NULL AND LOWER(TRIM(CAST(`cod_deposito` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_deposito` IS NOT NULL AND TRIM(CAST(`cod_deposito` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`cod_deposito` IS NULL) - COUNT_IF(`cod_deposito` IS NOT NULL AND LOWER(TRIM(CAST(`cod_deposito` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_deposito` IS NOT NULL AND TRIM(CAST(`cod_deposito` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'tp_movimento' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`tp_movimento` IS NULL) AS nulos, COUNT_IF(`tp_movimento` IS NOT NULL AND LOWER(TRIM(CAST(`tp_movimento` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`tp_movimento` IS NOT NULL AND TRIM(CAST(`tp_movimento` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`tp_movimento` IS NULL) - COUNT_IF(`tp_movimento` IS NOT NULL AND LOWER(TRIM(CAST(`tp_movimento` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`tp_movimento` IS NOT NULL AND TRIM(CAST(`tp_movimento` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`tp_movimento` IS NULL) - COUNT_IF(`tp_movimento` IS NOT NULL AND LOWER(TRIM(CAST(`tp_movimento` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`tp_movimento` IS NOT NULL AND TRIM(CAST(`tp_movimento` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'desc_tp_movimento' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`desc_tp_movimento` IS NULL) AS nulos, COUNT_IF(`desc_tp_movimento` IS NOT NULL AND LOWER(TRIM(CAST(`desc_tp_movimento` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`desc_tp_movimento` IS NOT NULL AND TRIM(CAST(`desc_tp_movimento` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`desc_tp_movimento` IS NULL) - COUNT_IF(`desc_tp_movimento` IS NOT NULL AND LOWER(TRIM(CAST(`desc_tp_movimento` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`desc_tp_movimento` IS NOT NULL AND TRIM(CAST(`desc_tp_movimento` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`desc_tp_movimento` IS NULL) - COUNT_IF(`desc_tp_movimento` IS NOT NULL AND LOWER(TRIM(CAST(`desc_tp_movimento` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`desc_tp_movimento` IS NOT NULL AND TRIM(CAST(`desc_tp_movimento` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'vl_modificacao_estoque' AS coluna, 'double' AS tipo, COUNT(*) AS total, COUNT_IF(`vl_modificacao_estoque` IS NULL) AS nulos, CAST(0 AS BIGINT) AS vazios_default, COUNT_IF(`vl_modificacao_estoque` = 0) AS zeros, (COUNT(*) - COUNT_IF(`vl_modificacao_estoque` IS NULL) - CAST(0 AS BIGINT) - COUNT_IF(`vl_modificacao_estoque` = 0)) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`vl_modificacao_estoque` IS NULL) - CAST(0 AS BIGINT) - COUNT_IF(`vl_modificacao_estoque` = 0)) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'dt_lancamento' AS coluna, 'date' AS tipo, COUNT(*) AS total, COUNT_IF(`dt_lancamento` IS NULL) AS nulos, CAST(0 AS BIGINT) AS vazios_default, CAST(0 AS BIGINT) AS zeros, (COUNT(*) - COUNT_IF(`dt_lancamento` IS NULL) - CAST(0 AS BIGINT) - CAST(0 AS BIGINT)) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`dt_lancamento` IS NULL) - CAST(0 AS BIGINT) - CAST(0 AS BIGINT)) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'dt_documento' AS coluna, 'date' AS tipo, COUNT(*) AS total, COUNT_IF(`dt_documento` IS NULL) AS nulos, CAST(0 AS BIGINT) AS vazios_default, CAST(0 AS BIGINT) AS zeros, (COUNT(*) - COUNT_IF(`dt_documento` IS NULL) - CAST(0 AS BIGINT) - CAST(0 AS BIGINT)) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`dt_documento` IS NULL) - CAST(0 AS BIGINT) - CAST(0 AS BIGINT)) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'tp_estoque_especial' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`tp_estoque_especial` IS NULL) AS nulos, COUNT_IF(`tp_estoque_especial` IS NOT NULL AND LOWER(TRIM(CAST(`tp_estoque_especial` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`tp_estoque_especial` IS NOT NULL AND TRIM(CAST(`tp_estoque_especial` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`tp_estoque_especial` IS NULL) - COUNT_IF(`tp_estoque_especial` IS NOT NULL AND LOWER(TRIM(CAST(`tp_estoque_especial` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`tp_estoque_especial` IS NOT NULL AND TRIM(CAST(`tp_estoque_especial` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`tp_estoque_especial` IS NULL) - COUNT_IF(`tp_estoque_especial` IS NOT NULL AND LOWER(TRIM(CAST(`tp_estoque_especial` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`tp_estoque_especial` IS NOT NULL AND TRIM(CAST(`tp_estoque_especial` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'num_material' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`num_material` IS NULL) AS nulos, COUNT_IF(`num_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`num_material` IS NOT NULL AND TRIM(CAST(`num_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`num_material` IS NULL) - COUNT_IF(`num_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_material` IS NOT NULL AND TRIM(CAST(`num_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`num_material` IS NULL) - COUNT_IF(`num_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_material` IS NOT NULL AND TRIM(CAST(`num_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'num_item_material' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`num_item_material` IS NULL) AS nulos, COUNT_IF(`num_item_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_item_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`num_item_material` IS NOT NULL AND TRIM(CAST(`num_item_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`num_item_material` IS NULL) - COUNT_IF(`num_item_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_item_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_item_material` IS NOT NULL AND TRIM(CAST(`num_item_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`num_item_material` IS NULL) - COUNT_IF(`num_item_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_item_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_item_material` IS NOT NULL AND TRIM(CAST(`num_item_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'num_ano_material' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`num_ano_material` IS NULL) AS nulos, COUNT_IF(`num_ano_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_ano_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`num_ano_material` IS NOT NULL AND TRIM(CAST(`num_ano_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`num_ano_material` IS NULL) - COUNT_IF(`num_ano_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_ano_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_ano_material` IS NOT NULL AND TRIM(CAST(`num_ano_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`num_ano_material` IS NULL) - COUNT_IF(`num_ano_material` IS NOT NULL AND LOWER(TRIM(CAST(`num_ano_material` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_ano_material` IS NOT NULL AND TRIM(CAST(`num_ano_material` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'num_lote' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`num_lote` IS NULL) AS nulos, COUNT_IF(`num_lote` IS NOT NULL AND LOWER(TRIM(CAST(`num_lote` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`num_lote` IS NOT NULL AND TRIM(CAST(`num_lote` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`num_lote` IS NULL) - COUNT_IF(`num_lote` IS NOT NULL AND LOWER(TRIM(CAST(`num_lote` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_lote` IS NOT NULL AND TRIM(CAST(`num_lote` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`num_lote` IS NULL) - COUNT_IF(`num_lote` IS NOT NULL AND LOWER(TRIM(CAST(`num_lote` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_lote` IS NOT NULL AND TRIM(CAST(`num_lote` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'nm_usuario' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`nm_usuario` IS NULL) AS nulos, COUNT_IF(`nm_usuario` IS NOT NULL AND LOWER(TRIM(CAST(`nm_usuario` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`nm_usuario` IS NOT NULL AND TRIM(CAST(`nm_usuario` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`nm_usuario` IS NULL) - COUNT_IF(`nm_usuario` IS NOT NULL AND LOWER(TRIM(CAST(`nm_usuario` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`nm_usuario` IS NOT NULL AND TRIM(CAST(`nm_usuario` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`nm_usuario` IS NULL) - COUNT_IF(`nm_usuario` IS NOT NULL AND LOWER(TRIM(CAST(`nm_usuario` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`nm_usuario` IS NOT NULL AND TRIM(CAST(`nm_usuario` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'num_pedido_compra' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`num_pedido_compra` IS NULL) AS nulos, COUNT_IF(`num_pedido_compra` IS NOT NULL AND LOWER(TRIM(CAST(`num_pedido_compra` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`num_pedido_compra` IS NOT NULL AND TRIM(CAST(`num_pedido_compra` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`num_pedido_compra` IS NULL) - COUNT_IF(`num_pedido_compra` IS NOT NULL AND LOWER(TRIM(CAST(`num_pedido_compra` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_pedido_compra` IS NOT NULL AND TRIM(CAST(`num_pedido_compra` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`num_pedido_compra` IS NULL) - COUNT_IF(`num_pedido_compra` IS NOT NULL AND LOWER(TRIM(CAST(`num_pedido_compra` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_pedido_compra` IS NOT NULL AND TRIM(CAST(`num_pedido_compra` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'num_item_pedido_compra' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`num_item_pedido_compra` IS NULL) AS nulos, COUNT_IF(`num_item_pedido_compra` IS NOT NULL AND LOWER(TRIM(CAST(`num_item_pedido_compra` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`num_item_pedido_compra` IS NOT NULL AND TRIM(CAST(`num_item_pedido_compra` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`num_item_pedido_compra` IS NULL) - COUNT_IF(`num_item_pedido_compra` IS NOT NULL AND LOWER(TRIM(CAST(`num_item_pedido_compra` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_item_pedido_compra` IS NOT NULL AND TRIM(CAST(`num_item_pedido_compra` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`num_item_pedido_compra` IS NULL) - COUNT_IF(`num_item_pedido_compra` IS NOT NULL AND LOWER(TRIM(CAST(`num_item_pedido_compra` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`num_item_pedido_compra` IS NOT NULL AND TRIM(CAST(`num_item_pedido_compra` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'cod_ordem_producao' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`cod_ordem_producao` IS NULL) AS nulos, COUNT_IF(`cod_ordem_producao` IS NOT NULL AND LOWER(TRIM(CAST(`cod_ordem_producao` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`cod_ordem_producao` IS NOT NULL AND TRIM(CAST(`cod_ordem_producao` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`cod_ordem_producao` IS NULL) - COUNT_IF(`cod_ordem_producao` IS NOT NULL AND LOWER(TRIM(CAST(`cod_ordem_producao` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_ordem_producao` IS NOT NULL AND TRIM(CAST(`cod_ordem_producao` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`cod_ordem_producao` IS NULL) - COUNT_IF(`cod_ordem_producao` IS NOT NULL AND LOWER(TRIM(CAST(`cod_ordem_producao` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`cod_ordem_producao` IS NOT NULL AND TRIM(CAST(`cod_ordem_producao` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'tp_classificacao_contabil' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`tp_classificacao_contabil` IS NULL) AS nulos, COUNT_IF(`tp_classificacao_contabil` IS NOT NULL AND LOWER(TRIM(CAST(`tp_classificacao_contabil` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`tp_classificacao_contabil` IS NOT NULL AND TRIM(CAST(`tp_classificacao_contabil` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`tp_classificacao_contabil` IS NULL) - COUNT_IF(`tp_classificacao_contabil` IS NOT NULL AND LOWER(TRIM(CAST(`tp_classificacao_contabil` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`tp_classificacao_contabil` IS NOT NULL AND TRIM(CAST(`tp_classificacao_contabil` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`tp_classificacao_contabil` IS NULL) - COUNT_IF(`tp_classificacao_contabil` IS NOT NULL AND LOWER(TRIM(CAST(`tp_classificacao_contabil` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`tp_classificacao_contabil` IS NOT NULL AND TRIM(CAST(`tp_classificacao_contabil` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'dateingest' AS coluna, 'date' AS tipo, COUNT(*) AS total, COUNT_IF(`dateingest` IS NULL) AS nulos, CAST(0 AS BIGINT) AS vazios_default, CAST(0 AS BIGINT) AS zeros, (COUNT(*) - COUNT_IF(`dateingest` IS NULL) - CAST(0 AS BIGINT) - CAST(0 AS BIGINT)) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`dateingest` IS NULL) - CAST(0 AS BIGINT) - CAST(0 AS BIGINT)) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'yearingest' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`yearingest` IS NULL) AS nulos, COUNT_IF(`yearingest` IS NOT NULL AND LOWER(TRIM(CAST(`yearingest` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`yearingest` IS NOT NULL AND TRIM(CAST(`yearingest` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`yearingest` IS NULL) - COUNT_IF(`yearingest` IS NOT NULL AND LOWER(TRIM(CAST(`yearingest` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`yearingest` IS NOT NULL AND TRIM(CAST(`yearingest` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`yearingest` IS NULL) - COUNT_IF(`yearingest` IS NOT NULL AND LOWER(TRIM(CAST(`yearingest` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`yearingest` IS NOT NULL AND TRIM(CAST(`yearingest` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
UNION ALL
SELECT 'monthingest' AS coluna, 'string' AS tipo, COUNT(*) AS total, COUNT_IF(`monthingest` IS NULL) AS nulos, COUNT_IF(`monthingest` IS NOT NULL AND LOWER(TRIM(CAST(`monthingest` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) AS vazios_default, COUNT_IF(`monthingest` IS NOT NULL AND TRIM(CAST(`monthingest` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$') AS zeros, (COUNT(*) - COUNT_IF(`monthingest` IS NULL) - COUNT_IF(`monthingest` IS NOT NULL AND LOWER(TRIM(CAST(`monthingest` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`monthingest` IS NOT NULL AND TRIM(CAST(`monthingest` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) AS uteis, ROUND(100.0 * (COUNT(*) - COUNT_IF(`monthingest` IS NULL) - COUNT_IF(`monthingest` IS NOT NULL AND LOWER(TRIM(CAST(`monthingest` AS STRING))) IN ('','null','nan','none','#','-','na','n/a')) - COUNT_IF(`monthingest` IS NOT NULL AND TRIM(CAST(`monthingest` AS STRING)) RLIKE '^[+-]?0+([.,]0+)?$')) / NULLIF(COUNT(*),0),2) AS pct_util FROM base
) preenchimento ORDER BY pct_util ASC, coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Cardinalidade de todas as colunas

-- COMMAND ----------

SELECT * FROM (
SELECT 'cod_centro' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`cod_centro`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`cod_centro`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'cod_material' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`cod_material`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`cod_material`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'desc_material' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`desc_material`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`desc_material`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'qt_movimento' AS coluna, 'double' AS tipo, APPROX_COUNT_DISTINCT(`qt_movimento`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`qt_movimento`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'sg_unidade_medida' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`sg_unidade_medida`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`sg_unidade_medida`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'cod_deposito' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`cod_deposito`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`cod_deposito`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'tp_movimento' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`tp_movimento`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`tp_movimento`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'desc_tp_movimento' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`desc_tp_movimento`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`desc_tp_movimento`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'vl_modificacao_estoque' AS coluna, 'double' AS tipo, APPROX_COUNT_DISTINCT(`vl_modificacao_estoque`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`vl_modificacao_estoque`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'dt_lancamento' AS coluna, 'date' AS tipo, APPROX_COUNT_DISTINCT(`dt_lancamento`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`dt_lancamento`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'dt_documento' AS coluna, 'date' AS tipo, APPROX_COUNT_DISTINCT(`dt_documento`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`dt_documento`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'tp_estoque_especial' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`tp_estoque_especial`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`tp_estoque_especial`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'num_material' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`num_material`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`num_material`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'num_item_material' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`num_item_material`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`num_item_material`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'num_ano_material' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`num_ano_material`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`num_ano_material`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'num_lote' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`num_lote`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`num_lote`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'nm_usuario' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`nm_usuario`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`nm_usuario`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'num_pedido_compra' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`num_pedido_compra`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`num_pedido_compra`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'num_item_pedido_compra' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`num_item_pedido_compra`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`num_item_pedido_compra`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'cod_ordem_producao' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`cod_ordem_producao`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`cod_ordem_producao`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'tp_classificacao_contabil' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`tp_classificacao_contabil`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`tp_classificacao_contabil`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'dateingest' AS coluna, 'date' AS tipo, APPROX_COUNT_DISTINCT(`dateingest`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`dateingest`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'yearingest' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`yearingest`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`yearingest`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
UNION ALL
SELECT 'monthingest' AS coluna, 'string' AS tipo, APPROX_COUNT_DISTINCT(`monthingest`) AS distintos_aprox, ROUND(100.0 * APPROX_COUNT_DISTINCT(`monthingest`) / NULLIF(COUNT(*),0),4) AS pct_distintos FROM base
) cardinalidade ORDER BY distintos_aprox ASC, coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Chave candidata e granularidade
-- MAGIC Chave documental testada: `num_material + num_ano_material + num_item_material`.

-- COMMAND ----------

SELECT COUNT(*) AS total_linhas,
       COUNT(DISTINCT STRUCT(num_material, num_ano_material, num_item_material)) AS chaves_distintas,
       COUNT(*) - COUNT(DISTINCT STRUCT(num_material, num_ano_material, num_item_material)) AS excedente,
       ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT STRUCT(num_material, num_ano_material, num_item_material)),0),6) AS linhas_por_chave
FROM base;

-- COMMAND ----------

SELECT num_material, num_ano_material, num_item_material, COUNT(*) AS quantidade
FROM base
GROUP BY num_material, num_ano_material, num_item_material
HAVING COUNT(*) > 1
ORDER BY quantidade DESC
LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 07. Duplicata identica versus granularidade adicional

-- COMMAND ----------

WITH linhas AS (SELECT *, SHA2(CONCAT_WS('||', COALESCE(CAST(`cod_centro` AS STRING),'∅'), COALESCE(CAST(`cod_material` AS STRING),'∅'), COALESCE(CAST(`desc_material` AS STRING),'∅'), COALESCE(CAST(`qt_movimento` AS STRING),'∅'), COALESCE(CAST(`sg_unidade_medida` AS STRING),'∅'), COALESCE(CAST(`cod_deposito` AS STRING),'∅'), COALESCE(CAST(`tp_movimento` AS STRING),'∅'), COALESCE(CAST(`desc_tp_movimento` AS STRING),'∅'), COALESCE(CAST(`vl_modificacao_estoque` AS STRING),'∅'), COALESCE(CAST(`dt_lancamento` AS STRING),'∅'), COALESCE(CAST(`dt_documento` AS STRING),'∅'), COALESCE(CAST(`tp_estoque_especial` AS STRING),'∅'), COALESCE(CAST(`num_material` AS STRING),'∅'), COALESCE(CAST(`num_item_material` AS STRING),'∅'), COALESCE(CAST(`num_ano_material` AS STRING),'∅'), COALESCE(CAST(`num_lote` AS STRING),'∅'), COALESCE(CAST(`nm_usuario` AS STRING),'∅'), COALESCE(CAST(`num_pedido_compra` AS STRING),'∅'), COALESCE(CAST(`num_item_pedido_compra` AS STRING),'∅'), COALESCE(CAST(`cod_ordem_producao` AS STRING),'∅'), COALESCE(CAST(`tp_classificacao_contabil` AS STRING),'∅'), COALESCE(CAST(`dateingest` AS STRING),'∅'), COALESCE(CAST(`yearingest` AS STRING),'∅'), COALESCE(CAST(`monthingest` AS STRING),'∅')),256) AS hash_linha FROM base),
chaves AS (
  SELECT num_material, num_ano_material, num_item_material, COUNT(*) AS linhas, COUNT(DISTINCT hash_linha) AS linhas_distintas
  FROM linhas GROUP BY num_material, num_ano_material, num_item_material HAVING COUNT(*) > 1
)
SELECT CASE WHEN linhas_distintas = 1 THEN 'DUPLICATA IDENTICA' ELSE 'GRANULARIDADE ADICIONAL OU DADOS DIFERENTES' END AS classificacao,
       COUNT(*) AS chaves, SUM(linhas) AS linhas
FROM chaves GROUP BY 1 ORDER BY 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 08. Perfil numerico

-- COMMAND ----------

SELECT 'qt_movimento' AS coluna, COUNT(`qt_movimento`) AS preenchidos, CAST(MIN(`qt_movimento`) AS DOUBLE) AS minimo, CAST(MAX(`qt_movimento`) AS DOUBLE) AS maximo, CAST(AVG(`qt_movimento`) AS DOUBLE) AS media, CAST(PERCENTILE_APPROX(`qt_movimento`,0.5) AS DOUBLE) AS mediana, CAST(PERCENTILE_APPROX(`qt_movimento`,0.95) AS DOUBLE) AS p95, COUNT_IF(`qt_movimento` < 0) AS negativos, COUNT_IF(`qt_movimento` = 0) AS zeros FROM base
UNION ALL
SELECT 'vl_modificacao_estoque' AS coluna, COUNT(`vl_modificacao_estoque`) AS preenchidos, CAST(MIN(`vl_modificacao_estoque`) AS DOUBLE) AS minimo, CAST(MAX(`vl_modificacao_estoque`) AS DOUBLE) AS maximo, CAST(AVG(`vl_modificacao_estoque`) AS DOUBLE) AS media, CAST(PERCENTILE_APPROX(`vl_modificacao_estoque`,0.5) AS DOUBLE) AS mediana, CAST(PERCENTILE_APPROX(`vl_modificacao_estoque`,0.95) AS DOUBLE) AS p95, COUNT_IF(`vl_modificacao_estoque` < 0) AS negativos, COUNT_IF(`vl_modificacao_estoque` = 0) AS zeros FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 09. Range e consistencia das datas

-- COMMAND ----------

SELECT 'dt_lancamento' AS coluna, CAST(MIN(`dt_lancamento`) AS STRING) AS minimo, CAST(MAX(`dt_lancamento`) AS STRING) AS maximo, APPROX_COUNT_DISTINCT(`dt_lancamento`) AS datas_distintas_aprox, COUNT_IF(TO_DATE(`dt_lancamento`) > CURRENT_DATE()) AS datas_futuras, COUNT_IF(TO_DATE(`dt_lancamento`) < TO_DATE('1990-01-01')) AS datas_antes_1990 FROM base
UNION ALL
SELECT 'dt_documento' AS coluna, CAST(MIN(`dt_documento`) AS STRING) AS minimo, CAST(MAX(`dt_documento`) AS STRING) AS maximo, APPROX_COUNT_DISTINCT(`dt_documento`) AS datas_distintas_aprox, COUNT_IF(TO_DATE(`dt_documento`) > CURRENT_DATE()) AS datas_futuras, COUNT_IF(TO_DATE(`dt_documento`) < TO_DATE('1990-01-01')) AS datas_antes_1990 FROM base
UNION ALL
SELECT 'dateingest' AS coluna, CAST(MIN(`dateingest`) AS STRING) AS minimo, CAST(MAX(`dateingest`) AS STRING) AS maximo, APPROX_COUNT_DISTINCT(`dateingest`) AS datas_distintas_aprox, COUNT_IF(TO_DATE(`dateingest`) > CURRENT_DATE()) AS datas_futuras, COUNT_IF(TO_DATE(`dateingest`) < TO_DATE('1990-01-01')) AS datas_antes_1990 FROM base ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Coerencia dos campos de ingestao

-- COMMAND ----------

SELECT COUNT(*) AS total, COUNT_IF(CAST(YEAR(dateingest) AS STRING) <> yearingest) AS ano_incoerente, COUNT_IF(DATE_FORMAT(dateingest,'yyyyMM') <> monthingest) AS mes_incoerente FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Formato dos codigos principais

-- COMMAND ----------

SELECT 'cod_material' AS coluna, COUNT_IF(`cod_material` IS NULL OR TRIM(CAST(`cod_material` AS STRING))='') AS vazios, MIN(LENGTH(TRIM(CAST(`cod_material` AS STRING)))) AS len_min, MAX(LENGTH(TRIM(CAST(`cod_material` AS STRING)))) AS len_max, COUNT_IF(TRIM(CAST(`cod_material` AS STRING)) RLIKE '^0[0-9]') AS com_zeros_esquerda, COUNT_IF(CAST(`cod_material` AS STRING) <> TRIM(CAST(`cod_material` AS STRING))) AS com_espacos, APPROX_COUNT_DISTINCT(TRIM(CAST(`cod_material` AS STRING))) AS distintos_bruto, APPROX_COUNT_DISTINCT(REGEXP_REPLACE(TRIM(CAST(`cod_material` AS STRING)),'^0+','')) AS distintos_sem_zeros FROM base
UNION ALL
SELECT 'cod_centro' AS coluna, COUNT_IF(`cod_centro` IS NULL OR TRIM(CAST(`cod_centro` AS STRING))='') AS vazios, MIN(LENGTH(TRIM(CAST(`cod_centro` AS STRING)))) AS len_min, MAX(LENGTH(TRIM(CAST(`cod_centro` AS STRING)))) AS len_max, COUNT_IF(TRIM(CAST(`cod_centro` AS STRING)) RLIKE '^0[0-9]') AS com_zeros_esquerda, COUNT_IF(CAST(`cod_centro` AS STRING) <> TRIM(CAST(`cod_centro` AS STRING))) AS com_espacos, APPROX_COUNT_DISTINCT(TRIM(CAST(`cod_centro` AS STRING))) AS distintos_bruto, APPROX_COUNT_DISTINCT(REGEXP_REPLACE(TRIM(CAST(`cod_centro` AS STRING)),'^0+','')) AS distintos_sem_zeros FROM base
UNION ALL
SELECT 'cod_deposito' AS coluna, COUNT_IF(`cod_deposito` IS NULL OR TRIM(CAST(`cod_deposito` AS STRING))='') AS vazios, MIN(LENGTH(TRIM(CAST(`cod_deposito` AS STRING)))) AS len_min, MAX(LENGTH(TRIM(CAST(`cod_deposito` AS STRING)))) AS len_max, COUNT_IF(TRIM(CAST(`cod_deposito` AS STRING)) RLIKE '^0[0-9]') AS com_zeros_esquerda, COUNT_IF(CAST(`cod_deposito` AS STRING) <> TRIM(CAST(`cod_deposito` AS STRING))) AS com_espacos, APPROX_COUNT_DISTINCT(TRIM(CAST(`cod_deposito` AS STRING))) AS distintos_bruto, APPROX_COUNT_DISTINCT(REGEXP_REPLACE(TRIM(CAST(`cod_deposito` AS STRING)),'^0+','')) AS distintos_sem_zeros FROM base
UNION ALL
SELECT 'num_material' AS coluna, COUNT_IF(`num_material` IS NULL OR TRIM(CAST(`num_material` AS STRING))='') AS vazios, MIN(LENGTH(TRIM(CAST(`num_material` AS STRING)))) AS len_min, MAX(LENGTH(TRIM(CAST(`num_material` AS STRING)))) AS len_max, COUNT_IF(TRIM(CAST(`num_material` AS STRING)) RLIKE '^0[0-9]') AS com_zeros_esquerda, COUNT_IF(CAST(`num_material` AS STRING) <> TRIM(CAST(`num_material` AS STRING))) AS com_espacos, APPROX_COUNT_DISTINCT(TRIM(CAST(`num_material` AS STRING))) AS distintos_bruto, APPROX_COUNT_DISTINCT(REGEXP_REPLACE(TRIM(CAST(`num_material` AS STRING)),'^0+','')) AS distintos_sem_zeros FROM base
UNION ALL
SELECT 'num_item_material' AS coluna, COUNT_IF(`num_item_material` IS NULL OR TRIM(CAST(`num_item_material` AS STRING))='') AS vazios, MIN(LENGTH(TRIM(CAST(`num_item_material` AS STRING)))) AS len_min, MAX(LENGTH(TRIM(CAST(`num_item_material` AS STRING)))) AS len_max, COUNT_IF(TRIM(CAST(`num_item_material` AS STRING)) RLIKE '^0[0-9]') AS com_zeros_esquerda, COUNT_IF(CAST(`num_item_material` AS STRING) <> TRIM(CAST(`num_item_material` AS STRING))) AS com_espacos, APPROX_COUNT_DISTINCT(TRIM(CAST(`num_item_material` AS STRING))) AS distintos_bruto, APPROX_COUNT_DISTINCT(REGEXP_REPLACE(TRIM(CAST(`num_item_material` AS STRING)),'^0+','')) AS distintos_sem_zeros FROM base
UNION ALL
SELECT 'num_ano_material' AS coluna, COUNT_IF(`num_ano_material` IS NULL OR TRIM(CAST(`num_ano_material` AS STRING))='') AS vazios, MIN(LENGTH(TRIM(CAST(`num_ano_material` AS STRING)))) AS len_min, MAX(LENGTH(TRIM(CAST(`num_ano_material` AS STRING)))) AS len_max, COUNT_IF(TRIM(CAST(`num_ano_material` AS STRING)) RLIKE '^0[0-9]') AS com_zeros_esquerda, COUNT_IF(CAST(`num_ano_material` AS STRING) <> TRIM(CAST(`num_ano_material` AS STRING))) AS com_espacos, APPROX_COUNT_DISTINCT(TRIM(CAST(`num_ano_material` AS STRING))) AS distintos_bruto, APPROX_COUNT_DISTINCT(REGEXP_REPLACE(TRIM(CAST(`num_ano_material` AS STRING)),'^0+','')) AS distintos_sem_zeros FROM base ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Distribuicao por centro

-- COMMAND ----------

SELECT cod_centro, COUNT(*) AS linhas, APPROX_COUNT_DISTINCT(cod_material) AS materiais_aprox, APPROX_COUNT_DISTINCT(cod_deposito) AS depositos_aprox, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY cod_centro ORDER BY linhas DESC LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Distribuicao por tipo de movimento

-- COMMAND ----------

SELECT tp_movimento, desc_tp_movimento, COUNT(*) AS linhas, APPROX_COUNT_DISTINCT(cod_material) AS materiais_aprox, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY tp_movimento, desc_tp_movimento ORDER BY linhas DESC LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Distribuicao por data de lancamento

-- COMMAND ----------

SELECT dt_lancamento, COUNT(*) AS linhas, APPROX_COUNT_DISTINCT(num_material) AS documentos_aprox FROM base GROUP BY dt_lancamento ORDER BY dt_lancamento DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 15. Dominios categoricos principais

-- COMMAND ----------

SELECT 'tp_movimento' AS coluna, CAST(`tp_movimento` AS STRING) AS valor, COUNT(*) AS quantidade, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY `tp_movimento` ORDER BY quantidade DESC LIMIT 20;

-- COMMAND ----------

SELECT 'tp_estoque_especial' AS coluna, CAST(`tp_estoque_especial` AS STRING) AS valor, COUNT(*) AS quantidade, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY `tp_estoque_especial` ORDER BY quantidade DESC LIMIT 20;

-- COMMAND ----------

SELECT 'tp_classificacao_contabil' AS coluna, CAST(`tp_classificacao_contabil` AS STRING) AS valor, COUNT(*) AS quantidade, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY `tp_classificacao_contabil` ORDER BY quantidade DESC LIMIT 20;

-- COMMAND ----------

SELECT 'sg_unidade_medida' AS coluna, CAST(`sg_unidade_medida` AS STRING) AS valor, COUNT(*) AS quantidade, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY `sg_unidade_medida` ORDER BY quantidade DESC LIMIT 20;

-- COMMAND ----------

SELECT 'cod_deposito' AS coluna, CAST(`cod_deposito` AS STRING) AS valor, COUNT(*) AS quantidade, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS pct FROM base GROUP BY `cod_deposito` ORDER BY quantidade DESC LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 16. Integridade de relacionamento entre codigo e descricao do movimento

-- COMMAND ----------

SELECT tp_movimento, COUNT(DISTINCT desc_tp_movimento) AS descricoes_distintas, COLLECT_SET(desc_tp_movimento) AS descricoes FROM base GROUP BY tp_movimento HAVING COUNT(DISTINCT desc_tp_movimento) > 1 ORDER BY descricoes_distintas DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 17. Resumo operacional

-- COMMAND ----------

SELECT 'VOLUMETRIA' AS bloco, 'total_linhas' AS indicador, CAST(COUNT(*) AS STRING) AS valor FROM base
UNION ALL SELECT 'CHAVE', 'duplicidades_documentais', CAST(COUNT(*) AS STRING) FROM (SELECT 1 FROM base GROUP BY num_material,num_ano_material,num_item_material HAVING COUNT(*)>1)
UNION ALL SELECT 'DATAS', 'dt_documento_antes_1990', CAST(COUNT_IF(dt_documento < TO_DATE('1990-01-01')) AS STRING) FROM base
UNION ALL SELECT 'DATAS', 'dt_lancamento_futuras', CAST(COUNT_IF(dt_lancamento > CURRENT_DATE()) AS STRING) FROM base
UNION ALL SELECT 'INGESTAO', 'ano_incoerente', CAST(COUNT_IF(CAST(YEAR(dateingest) AS STRING) <> yearingest) AS STRING) FROM base
UNION ALL SELECT 'INGESTAO', 'mes_incoerente', CAST(COUNT_IF(DATE_FORMAT(dateingest,'yyyyMM') <> monthingest) AS STRING) FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Portao da Fase 1
-- MAGIC Validar granularidade, chave, colunas suspeitas, formatos, defaults e periodo antes de escolher o cenario SAP.