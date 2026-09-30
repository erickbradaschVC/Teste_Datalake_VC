-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Investigação de cobertura MB5B PROD - Empresa 4014 / Centro 4128
-- MAGIC
-- MAGIC Objetivo: identificar em qual camada materiais deixam de aparecer entre a tabela física e a view de consulta, avaliar filtros de período/escopo e gerar evidências para investigar os 2.792 materiais SAP sem correspondência no Datalake.
-- MAGIC
-- MAGIC Este notebook não exige carregar o arquivo SAP no Databricks. Ele investiga integralmente as camadas disponíveis no Datalake.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Parâmetros

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW parametros_mb5b AS
SELECT
  '4014' AS cod_empresa,
  '4128' AS cod_centro,
  CAST(0.005 AS DOUBLE) AS tolerancia;

SELECT * FROM parametros_mb5b;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. SQL da view e metadados da tabela física
-- MAGIC Verifique no resultado se a view contém filtros, joins ou condições adicionais.

-- COMMAND ----------

SHOW CREATE TABLE dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta;

-- COMMAND ----------

DESCRIBE EXTENDED dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta;

-- COMMAND ----------

DESCRIBE EXTENDED dev_logistics.corp_curated.tbl_ds_pro_mb5b_estoque_diario;

-- COMMAND ----------

DESCRIBE HISTORY dev_logistics.corp_curated.tbl_ds_pro_mb5b_estoque_diario;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Bases normalizadas

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW mb5b_view_norm AS
SELECT
  cod_empresa,
  cod_centro,
  REGEXP_REPLACE(TRIM(cod_material), '^0+', '') AS material,
  TRIM(desc_material) AS desc_material,
  UPPER(TRIM(sg_unidade_medida)) AS unidade,
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

CREATE OR REPLACE TEMP VIEW mb5b_fisica_norm AS
SELECT
  cod_empresa,
  cod_centro,
  REGEXP_REPLACE(TRIM(cod_material), '^0+', '') AS material,
  TRIM(desc_material) AS desc_material,
  UPPER(TRIM(sg_unidade_medida)) AS unidade,
  dt_estoque,
  estoque_inicial,
  entrada,
  saida,
  estoque_final,
  dh_carga,
  dh_atualizacao
FROM dev_logistics.corp_curated.tbl_ds_pro_mb5b_estoque_diario
WHERE cod_empresa = '4014'
  AND cod_centro = '4128';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Volumetria comparativa por camada

-- COMMAND ----------

SELECT
  'VIEW_CONSULTA' AS camada,
  COUNT(*) AS linhas,
  COUNT(DISTINCT material) AS materiais,
  MIN(dt_estoque) AS primeira_data,
  MAX(dt_estoque) AS ultima_data,
  MAX(dh_carga) AS ultima_carga,
  MAX(dh_atualizacao) AS ultima_atualizacao
FROM mb5b_view_norm

UNION ALL

SELECT
  'TABELA_FISICA',
  COUNT(*),
  COUNT(DISTINCT material),
  MIN(dt_estoque),
  MAX(dt_estoque),
  MAX(dh_carga),
  MAX(dh_atualizacao)
FROM mb5b_fisica_norm;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Materiais da tabela física que não aparecem na view
-- MAGIC Se o resultado for maior que zero, há diferença entre a camada física e a view.

-- COMMAND ----------

WITH fisica AS (
  SELECT DISTINCT material FROM mb5b_fisica_norm
),
view_consulta AS (
  SELECT DISTINCT material FROM mb5b_view_norm
)
SELECT
  COUNT(*) AS materiais_fisica_sem_view
FROM fisica f
LEFT ANTI JOIN view_consulta v
  ON f.material = v.material;

-- COMMAND ----------

WITH fisica_consolidada AS (
  SELECT
    material,
    MAX_BY(desc_material, dt_estoque) AS desc_material,
    MAX_BY(unidade, dt_estoque) AS unidade,
    MIN(dt_estoque) AS primeira_data,
    MAX(dt_estoque) AS ultima_data,
    COUNT(*) AS dias_registrados,
    MIN_BY(estoque_inicial, dt_estoque) AS estoque_inicial,
    SUM(entrada) AS entrada,
    SUM(saida) AS saida,
    MAX_BY(estoque_final, dt_estoque) AS estoque_final
  FROM mb5b_fisica_norm
  GROUP BY material
),
view_materiais AS (
  SELECT DISTINCT material FROM mb5b_view_norm
)
SELECT f.*
FROM fisica_consolidada f
LEFT ANTI JOIN view_materiais v
  ON f.material = v.material
ORDER BY
  ABS(f.estoque_final) DESC,
  ABS(f.entrada) + ABS(f.saida) DESC,
  f.material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Materiais da view que não aparecem na tabela física
-- MAGIC O esperado é zero se a view deriva exclusivamente da tabela física indicada.

-- COMMAND ----------

WITH fisica AS (
  SELECT DISTINCT material FROM mb5b_fisica_norm
),
view_consulta AS (
  SELECT DISTINCT material FROM mb5b_view_norm
)
SELECT
  COUNT(*) AS materiais_view_sem_fisica
FROM view_consulta v
LEFT ANTI JOIN fisica f
  ON v.material = f.material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 07. Diferenças linha a linha entre tabela física e view
-- MAGIC Detecta transformação de valores, não apenas exclusão de materiais.

-- COMMAND ----------

WITH f AS (
  SELECT
    material,
    dt_estoque,
    MAX_BY(desc_material, dh_carga) AS desc_material,
    MAX_BY(unidade, dh_carga) AS unidade,
    SUM(estoque_inicial) AS estoque_inicial,
    SUM(entrada) AS entrada,
    SUM(saida) AS saida,
    SUM(estoque_final) AS estoque_final
  FROM mb5b_fisica_norm
  GROUP BY material, dt_estoque
),
v AS (
  SELECT
    material,
    dt_estoque,
    MAX_BY(desc_material, dh_carga) AS desc_material,
    MAX_BY(unidade, dh_carga) AS unidade,
    SUM(estoque_inicial) AS estoque_inicial,
    SUM(entrada) AS entrada,
    SUM(saida) AS saida,
    SUM(estoque_final) AS estoque_final
  FROM mb5b_view_norm
  GROUP BY material, dt_estoque
)
SELECT
  COUNT(*) AS linhas_com_alguma_diferenca,
  COUNT_IF(v.material IS NULL) AS linhas_ausentes_na_view,
  COUNT_IF(v.material IS NOT NULL AND ABS(f.estoque_inicial - v.estoque_inicial) > 0.005) AS diverg_estoque_inicial,
  COUNT_IF(v.material IS NOT NULL AND ABS(f.entrada - v.entrada) > 0.005) AS diverg_entrada,
  COUNT_IF(v.material IS NOT NULL AND ABS(f.saida - v.saida) > 0.005) AS diverg_saida,
  COUNT_IF(v.material IS NOT NULL AND ABS(f.estoque_final - v.estoque_final) > 0.005) AS diverg_estoque_final
FROM f
LEFT JOIN v
  ON f.material = v.material
 AND f.dt_estoque = v.dt_estoque
WHERE v.material IS NULL
   OR ABS(f.estoque_inicial - v.estoque_inicial) > 0.005
   OR ABS(f.entrada - v.entrada) > 0.005
   OR ABS(f.saida - v.saida) > 0.005
   OR ABS(f.estoque_final - v.estoque_final) > 0.005;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 08. Distribuição temporal da tabela física
-- MAGIC Ajuda a verificar se a cobertura começa somente em 2024 e se existem materiais restritos a períodos anteriores.

-- COMMAND ----------

SELECT
  SUBSTRING(CAST(dt_estoque AS STRING), 1, 4) AS ano,
  COUNT(*) AS linhas,
  COUNT(DISTINCT material) AS materiais,
  SUM(CASE WHEN ABS(entrada) > 0.005 OR ABS(saida) > 0.005 THEN 1 ELSE 0 END) AS linhas_com_movimento
FROM mb5b_fisica_norm
GROUP BY SUBSTRING(CAST(dt_estoque AS STRING), 1, 4)
ORDER BY ano;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 09. Materiais por primeira e última data disponível

-- COMMAND ----------

WITH periodo AS (
  SELECT
    material,
    MIN(dt_estoque) AS primeira_data,
    MAX(dt_estoque) AS ultima_data,
    COUNT(*) AS dias_registrados
  FROM mb5b_fisica_norm
  GROUP BY material
)
SELECT
  SUBSTRING(CAST(primeira_data AS STRING), 1, 4) AS ano_primeira_data,
  SUBSTRING(CAST(ultima_data AS STRING), 1, 4) AS ano_ultima_data,
  COUNT(*) AS materiais
FROM periodo
GROUP BY
  SUBSTRING(CAST(primeira_data AS STRING), 1, 4),
  SUBSTRING(CAST(ultima_data AS STRING), 1, 4)
ORDER BY ano_primeira_data, ano_ultima_data;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Materiais existentes em outros escopos
-- MAGIC Mostra a distribuição global da tabela física, útil para investigar associação incorreta de empresa ou centro.

-- COMMAND ----------

SELECT
  cod_empresa,
  cod_centro,
  COUNT(*) AS linhas,
  COUNT(DISTINCT REGEXP_REPLACE(TRIM(cod_material), '^0+', '')) AS materiais,
  MIN(dt_estoque) AS primeira_data,
  MAX(dt_estoque) AS ultima_data
FROM dev_logistics.corp_curated.tbl_ds_pro_mb5b_estoque_diario
GROUP BY cod_empresa, cod_centro
ORDER BY materiais DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Perfil de materiais com valor útil na tabela física 4014/4128
-- MAGIC Esta saída ajuda a comparar a regra de elegibilidade da tabela com a regra usada no comparativo SAP.

-- COMMAND ----------

WITH consolidada AS (
  SELECT
    material,
    MIN_BY(estoque_inicial, dt_estoque) AS estoque_inicial,
    SUM(entrada) AS entrada,
    SUM(saida) AS saida,
    MAX_BY(estoque_final, dt_estoque) AS estoque_final
  FROM mb5b_fisica_norm
  GROUP BY material
)
SELECT
  CASE
    WHEN ABS(estoque_final) > 0.005 THEN 'COM_ESTOQUE_FINAL'
    WHEN ABS(entrada) > 0.005 OR ABS(saida) > 0.005 THEN 'SEM_SALDO_FINAL_COM_MOVIMENTO'
    WHEN ABS(estoque_inicial) > 0.005 THEN 'APENAS_ESTOQUE_INICIAL'
    ELSE 'TOTALMENTE_ZERADO'
  END AS perfil,
  COUNT(*) AS materiais
FROM consolidada
GROUP BY 1
ORDER BY materiais DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Testes de valores nulos e chaves inválidas

-- COMMAND ----------

SELECT
  'VIEW_CONSULTA' AS camada,
  COUNT_IF(material IS NULL OR TRIM(material) = '') AS material_vazio,
  COUNT_IF(dt_estoque IS NULL OR TRIM(CAST(dt_estoque AS STRING)) = '') AS data_vazia,
  COUNT_IF(estoque_inicial IS NULL) AS estoque_inicial_nulo,
  COUNT_IF(entrada IS NULL) AS entrada_nula,
  COUNT_IF(saida IS NULL) AS saida_nula,
  COUNT_IF(estoque_final IS NULL) AS estoque_final_nulo
FROM mb5b_view_norm

UNION ALL

SELECT
  'TABELA_FISICA',
  COUNT_IF(material IS NULL OR TRIM(material) = ''),
  COUNT_IF(dt_estoque IS NULL OR TRIM(CAST(dt_estoque AS STRING)) = ''),
  COUNT_IF(estoque_inicial IS NULL),
  COUNT_IF(entrada IS NULL),
  COUNT_IF(saida IS NULL),
  COUNT_IF(estoque_final IS NULL)
FROM mb5b_fisica_norm;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Resumo diagnóstico automático

-- COMMAND ----------

WITH f AS (
  SELECT DISTINCT material FROM mb5b_fisica_norm
),
v AS (
  SELECT DISTINCT material FROM mb5b_view_norm
),
metricas AS (
  SELECT
    (SELECT COUNT(*) FROM f) AS materiais_fisica,
    (SELECT COUNT(*) FROM v) AS materiais_view,
    (SELECT COUNT(*) FROM f LEFT ANTI JOIN v ON f.material = v.material) AS fisica_sem_view,
    (SELECT COUNT(*) FROM v LEFT ANTI JOIN f ON v.material = f.material) AS view_sem_fisica
)
SELECT
  materiais_fisica,
  materiais_view,
  fisica_sem_view,
  view_sem_fisica,
  CASE
    WHEN fisica_sem_view > 0 THEN 'INVESTIGAR FILTRO OU TRANSFORMACAO DA VIEW'
    WHEN materiais_fisica = materiais_view AND view_sem_fisica = 0 THEN 'VIEW E TABELA FISICA POSSUEM A MESMA COBERTURA DE MATERIAL'
    ELSE 'INVESTIGAR COBERTURA ENTRE AS CAMADAS'
  END AS diagnostico
FROM metricas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Saídas para exportação
-- MAGIC Exporte as grades abaixo como CSV para anexar à investigação.

-- COMMAND ----------

WITH fisica_consolidada AS (
  SELECT
    material,
    MAX_BY(desc_material, dt_estoque) AS desc_material,
    MAX_BY(unidade, dt_estoque) AS unidade,
    MIN(dt_estoque) AS primeira_data,
    MAX(dt_estoque) AS ultima_data,
    COUNT(*) AS dias_registrados,
    MIN_BY(estoque_inicial, dt_estoque) AS estoque_inicial,
    SUM(entrada) AS entrada,
    SUM(saida) AS saida,
    MAX_BY(estoque_final, dt_estoque) AS estoque_final
  FROM mb5b_fisica_norm
  GROUP BY material
),
view_materiais AS (
  SELECT DISTINCT material FROM mb5b_view_norm
)
SELECT f.*
FROM fisica_consolidada f
LEFT ANTI JOIN view_materiais v ON f.material = v.material
ORDER BY material;