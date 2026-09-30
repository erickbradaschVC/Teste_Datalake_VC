-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Investigacao de cobertura MB5B - PRD - Empresa 4014 / Centro 4128
-- MAGIC
-- MAGIC **Ambiente:** PRD
-- MAGIC
-- MAGIC **Objeto acessivel:** `prd_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta`
-- MAGIC
-- MAGIC Esta versao nao consulta `dev_logistics` nem qualquer catalogo DEV. Ela investiga estrutura, cobertura, periodo, elegibilidade e comportamento da view de producao.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Parametros

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW parametros_mb5b AS
SELECT
  '4014' AS cod_empresa,
  '4128' AS cod_centro,
  CAST(0.005 AS DOUBLE) AS tolerancia;

SELECT * FROM parametros_mb5b;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. Definicao da view PRD
-- MAGIC A saida desta celula deve ser preservada no HTML. Ela mostra se a view possui filtros ou qual objeto e consultado por baixo.

-- COMMAND ----------

SHOW CREATE TABLE prd_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta;

-- COMMAND ----------

DESCRIBE EXTENDED prd_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Base PRD normalizada

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW mb5b_prd_norm AS
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
FROM prd_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta
WHERE cod_empresa = '4014'
  AND cod_centro = '4128';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Volumetria e periodo PRD

-- COMMAND ----------

SELECT
  COUNT(*) AS linhas,
  COUNT(DISTINCT material) AS materiais,
  MIN(dt_estoque) AS primeira_data,
  MAX(dt_estoque) AS ultima_data,
  MAX(dh_carga) AS ultima_carga,
  MAX(dh_atualizacao) AS ultima_atualizacao
FROM mb5b_prd_norm;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Granularidade por material

-- COMMAND ----------

WITH g AS (
  SELECT material, COUNT(*) AS linhas
  FROM mb5b_prd_norm
  GROUP BY material
)
SELECT
  COUNT(*) AS materiais,
  SUM(linhas) AS linhas,
  ROUND(SUM(linhas) * 1.0 / NULLIF(COUNT(*), 0), 4) AS linhas_por_material,
  MIN(linhas) AS minimo_linhas_material,
  MAX(linhas) AS maximo_linhas_material
FROM g;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Distribuicao temporal

-- COMMAND ----------

SELECT
  SUBSTRING(CAST(dt_estoque AS STRING), 1, 4) AS ano,
  COUNT(*) AS linhas,
  COUNT(DISTINCT material) AS materiais,
  COUNT_IF(ABS(entrada) > 0.005 OR ABS(saida) > 0.005) AS linhas_com_movimento
FROM mb5b_prd_norm
GROUP BY SUBSTRING(CAST(dt_estoque AS STRING), 1, 4)
ORDER BY ano;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 07. Primeira e ultima data por material

-- COMMAND ----------

WITH periodo AS (
  SELECT
    material,
    MIN(dt_estoque) AS primeira_data,
    MAX(dt_estoque) AS ultima_data,
    COUNT(*) AS dias_registrados
  FROM mb5b_prd_norm
  GROUP BY material
)
SELECT
  SUBSTRING(CAST(primeira_data AS STRING), 1, 4) AS ano_primeira_data,
  SUBSTRING(CAST(ultima_data AS STRING), 1, 4) AS ano_ultima_data,
  COUNT(*) AS materiais,
  MIN(dias_registrados) AS minimo_dias,
  MAX(dias_registrados) AS maximo_dias
FROM periodo
GROUP BY
  SUBSTRING(CAST(primeira_data AS STRING), 1, 4),
  SUBSTRING(CAST(ultima_data AS STRING), 1, 4)
ORDER BY ano_primeira_data, ano_ultima_data;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 08. Consolidacao correta por material

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW mb5b_prd_consolidada AS
SELECT
  cod_empresa,
  cod_centro,
  material,
  MAX_BY(desc_material, dt_estoque) AS desc_material,
  MAX_BY(unidade, dt_estoque) AS unidade,
  MIN_BY(estoque_inicial, dt_estoque) AS estoque_inicial,
  SUM(entrada) AS entrada,
  SUM(saida) AS saida,
  MAX_BY(estoque_final, dt_estoque) AS estoque_final,
  MIN(dt_estoque) AS primeira_data,
  MAX(dt_estoque) AS ultima_data,
  COUNT(*) AS dias_registrados
FROM mb5b_prd_norm
GROUP BY cod_empresa, cod_centro, material;

SELECT
  COUNT(*) AS materiais,
  COUNT(DISTINCT material) AS materiais_distintos,
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT material), 0), 4) AS linhas_por_material
FROM mb5b_prd_consolidada;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 09. Regra contabil da consolidacao

-- COMMAND ----------

SELECT
  COUNT(*) AS materiais,
  COUNT_IF(ABS((estoque_inicial + entrada + saida) - estoque_final) <= 0.005) AS equacao_ok,
  COUNT_IF(ABS((estoque_inicial + entrada + saida) - estoque_final) > 0.005) AS divergentes,
  MAX(ABS((estoque_inicial + entrada + saida) - estoque_final)) AS maior_diferenca
FROM mb5b_prd_consolidada;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Perfil de elegibilidade em PRD
-- MAGIC Mostra quantos materiais possuem saldo final, movimento, somente saldo inicial ou estao totalmente zerados dentro do periodo da view.

-- COMMAND ----------

SELECT
  CASE
    WHEN ABS(estoque_final) > 0.005 THEN 'COM_ESTOQUE_FINAL'
    WHEN ABS(entrada) > 0.005 OR ABS(saida) > 0.005 THEN 'SEM_SALDO_FINAL_COM_MOVIMENTO'
    WHEN ABS(estoque_inicial) > 0.005 THEN 'APENAS_ESTOQUE_INICIAL'
    ELSE 'TOTALMENTE_ZERADO'
  END AS perfil,
  COUNT(*) AS materiais
FROM mb5b_prd_consolidada
GROUP BY 1
ORDER BY materiais DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Consistencia cadastral por material

-- COMMAND ----------

SELECT
  material,
  COUNT(DISTINCT desc_material) AS descricoes_distintas,
  COUNT(DISTINCT unidade) AS unidades_distintas,
  COLLECT_SET(desc_material) AS descricoes,
  COLLECT_SET(unidade) AS unidades
FROM mb5b_prd_norm
GROUP BY material
HAVING COUNT(DISTINCT desc_material) > 1
    OR COUNT(DISTINCT unidade) > 1
ORDER BY material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Nulos e chaves invalidas

-- COMMAND ----------

SELECT
  COUNT_IF(material IS NULL OR TRIM(material) = '') AS material_vazio,
  COUNT_IF(dt_estoque IS NULL OR TRIM(CAST(dt_estoque AS STRING)) = '') AS data_vazia,
  COUNT_IF(estoque_inicial IS NULL) AS estoque_inicial_nulo,
  COUNT_IF(entrada IS NULL) AS entrada_nula,
  COUNT_IF(saida IS NULL) AS saida_nula,
  COUNT_IF(estoque_final IS NULL) AS estoque_final_nulo
FROM mb5b_prd_norm;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Materiais com menor cobertura temporal
-- MAGIC Esses casos ajudam a avaliar se a ausencia em relacao a uma MB5B de periodo aberto decorre da janela temporal da view PRD.

-- COMMAND ----------

SELECT
  material,
  desc_material,
  unidade,
  primeira_data,
  ultima_data,
  dias_registrados,
  estoque_inicial,
  entrada,
  saida,
  estoque_final
FROM mb5b_prd_consolidada
ORDER BY dias_registrados ASC, primeira_data DESC, material
LIMIT 500;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Materiais prioritarios por valor

-- COMMAND ----------

SELECT
  material,
  desc_material,
  unidade,
  primeira_data,
  ultima_data,
  dias_registrados,
  estoque_inicial,
  entrada,
  saida,
  estoque_final
FROM mb5b_prd_consolidada
ORDER BY
  ABS(estoque_final) DESC,
  ABS(entrada) + ABS(saida) DESC
LIMIT 500;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 15. Saida final PRD para novo comparativo SAP
-- MAGIC Exporte esta grade inteira em CSV. Ela deve ser comparada novamente com a MB5B SAP para recalcular os 2.792 materiais ausentes usando somente PRD.

-- COMMAND ----------

SELECT
  cod_empresa,
  cod_centro,
  material,
  desc_material,
  unidade AS sg_unidade_medida,
  estoque_inicial,
  entrada,
  saida,
  estoque_final,
  primeira_data,
  ultima_data,
  dias_registrados
FROM mb5b_prd_consolidada
ORDER BY TRY_CAST(material AS BIGINT), material;
'''

path.write_text(content, encoding='utf-8')
print(path)
print(f'{len(content.splitlines())} linhas; {path.stat().st_size} bytes')
PY
python /mnt/data/make_prd_notebook.py