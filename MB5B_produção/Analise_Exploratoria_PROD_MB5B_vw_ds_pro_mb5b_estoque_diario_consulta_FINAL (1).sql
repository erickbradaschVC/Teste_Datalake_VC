-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Analise Exploratoria PROD MB5B
-- MAGIC
-- MAGIC Objeto: `dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta`
-- MAGIC
-- MAGIC Versao final revisada para Databricks SQL. As consultas de dominio, distribuicao por centro,
-- MAGIC distribuicao por empresa e equacao contabil usam CTEs intermediarias para evitar erros de parser.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Parametros de recorte
-- MAGIC Preencha os valores abaixo ou mantenha string vazia para analisar toda a view.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW parametros_mb5b AS
SELECT
  CAST('' AS STRING) AS f_cod_centro,
  CAST('' AS STRING) AS f_cod_empresa;

SELECT * FROM parametros_mb5b;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. Base filtrada

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW base AS
SELECT v.*
FROM dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta v
CROSS JOIN parametros_mb5b p
WHERE (p.f_cod_centro = '' OR v.cod_centro = p.f_cod_centro)
  AND (p.f_cod_empresa = '' OR v.cod_empresa = p.f_cod_empresa);

SELECT COUNT(*) AS linhas_na_base
FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Metadados

-- COMMAND ----------

DESCRIBE EXTENDED dev_procurement.corp_curated.vw_ds_pro_mb5b_estoque_diario_consulta;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Amostra inicial

-- COMMAND ----------

SELECT *
FROM base
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Volumetria e dimensoes principais

-- COMMAND ----------

SELECT
  COUNT(*) AS linhas,
  COUNT(DISTINCT cod_empresa) AS empresas,
  COUNT(DISTINCT cod_centro) AS centros,
  COUNT(DISTINCT desc_centro) AS descricoes_centro,
  COUNT(DISTINCT cod_material) AS materiais,
  COUNT(DISTINCT dt_estoque) AS datas_estoque,
  COUNT(DISTINCT sg_unidade_medida) AS unidades_medida
FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Granularidade candidata

-- COMMAND ----------

WITH total AS (
  SELECT COUNT(*) AS linhas
  FROM base
),
chaves AS (
  SELECT
    'cod_empresa + cod_centro + cod_material + dt_estoque' AS chave,
    COUNT(*) AS combinacoes_distintas
  FROM (
    SELECT DISTINCT cod_empresa, cod_centro, cod_material, dt_estoque
    FROM base
  ) x
  UNION ALL
  SELECT
    'cod_centro + cod_material + dt_estoque' AS chave,
    COUNT(*) AS combinacoes_distintas
  FROM (
    SELECT DISTINCT cod_centro, cod_material, dt_estoque
    FROM base
  ) x
  UNION ALL
  SELECT
    'cod_empresa + cod_centro + cod_material + dt_estoque + sg_unidade_medida' AS chave,
    COUNT(*) AS combinacoes_distintas
  FROM (
    SELECT DISTINCT cod_empresa, cod_centro, cod_material, dt_estoque, sg_unidade_medida
    FROM base
  ) x
)
SELECT
  c.chave,
  t.linhas,
  c.combinacoes_distintas,
  ROUND(t.linhas / NULLIF(c.combinacoes_distintas, 0), 4) AS linhas_por_chave,
  CASE
    WHEN t.linhas = c.combinacoes_distintas THEN 'CHAVE UNICA'
    ELSE 'NAO UNICA'
  END AS veredito
FROM chaves c
CROSS JOIN total t
ORDER BY linhas_por_chave;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 07. Duplicidades

-- COMMAND ----------

WITH duplicidades AS (
  SELECT
    cod_empresa,
    cod_centro,
    cod_material,
    dt_estoque,
    COUNT(*) AS qtd
  FROM base
  GROUP BY cod_empresa, cod_centro, cod_material, dt_estoque
  HAVING COUNT(*) > 1
)
SELECT
  COUNT(*) AS chaves_repetidas,
  COALESCE(SUM(qtd - 1), 0) AS linhas_excedentes,
  COALESCE(MAX(qtd), 0) AS pior_caso
FROM duplicidades;

-- COMMAND ----------

SELECT
  cod_empresa,
  cod_centro,
  cod_material,
  dt_estoque,
  COUNT(*) AS qtd
FROM base
GROUP BY cod_empresa, cod_centro, cod_material, dt_estoque
HAVING COUNT(*) > 1
ORDER BY qtd DESC
LIMIT 50;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 08. Preenchimento das 13 colunas

-- COMMAND ----------

WITH total AS (
  SELECT COUNT(*) AS linhas
  FROM base
),
perfil AS (
  SELECT stack(
    13,
    'cod_empresa',       COUNT_IF(cod_empresa IS NULL),       COUNT_IF(cod_empresa IS NOT NULL AND TRIM(cod_empresa) = ''),
    'cod_centro',        COUNT_IF(cod_centro IS NULL),        COUNT_IF(cod_centro IS NOT NULL AND TRIM(cod_centro) = ''),
    'desc_centro',       COUNT_IF(desc_centro IS NULL),       COUNT_IF(desc_centro IS NOT NULL AND TRIM(desc_centro) = ''),
    'cod_material',      COUNT_IF(cod_material IS NULL),      COUNT_IF(cod_material IS NOT NULL AND TRIM(cod_material) = ''),
    'desc_material',     COUNT_IF(desc_material IS NULL),     COUNT_IF(desc_material IS NOT NULL AND TRIM(desc_material) = ''),
    'sg_unidade_medida', COUNT_IF(sg_unidade_medida IS NULL), COUNT_IF(sg_unidade_medida IS NOT NULL AND TRIM(sg_unidade_medida) = ''),
    'dt_estoque',        COUNT_IF(dt_estoque IS NULL),        COUNT_IF(dt_estoque IS NOT NULL AND TRIM(dt_estoque) = ''),
    'estoque_inicial',   COUNT_IF(estoque_inicial IS NULL),   CAST(0 AS BIGINT),
    'entrada',           COUNT_IF(entrada IS NULL),           CAST(0 AS BIGINT),
    'saida',             COUNT_IF(saida IS NULL),             CAST(0 AS BIGINT),
    'estoque_final',     COUNT_IF(estoque_final IS NULL),     CAST(0 AS BIGINT),
    'dh_carga',          COUNT_IF(dh_carga IS NULL),          CAST(0 AS BIGINT),
    'dh_atualizacao',    COUNT_IF(dh_atualizacao IS NULL),    CAST(0 AS BIGINT)
  ) AS (coluna, nulos, vazios)
  FROM base
)
SELECT
  p.coluna,
  p.nulos,
  p.vazios,
  t.linhas - p.nulos - p.vazios AS preenchidos,
  ROUND(100.0 * (t.linhas - p.nulos - p.vazios) / NULLIF(t.linhas, 0), 2) AS pct_preenchido,
  CASE
    WHEN p.nulos = t.linhas THEN '100% NULO'
    WHEN t.linhas - p.nulos - p.vazios = 0 THEN 'SEM VALOR UTIL'
    WHEN t.linhas - p.nulos - p.vazios < t.linhas * 0.01 THEN 'QUASE VAZIO'
    ELSE 'OK'
  END AS veredito
FROM perfil p
CROSS JOIN total t
ORDER BY pct_preenchido, p.coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 09. Cardinalidade

-- COMMAND ----------

WITH total AS (
  SELECT COUNT(*) AS linhas
  FROM base
),
cardinalidade AS (
  SELECT stack(
    13,
    'cod_empresa',       APPROX_COUNT_DISTINCT(cod_empresa),
    'cod_centro',        APPROX_COUNT_DISTINCT(cod_centro),
    'desc_centro',       APPROX_COUNT_DISTINCT(desc_centro),
    'cod_material',      APPROX_COUNT_DISTINCT(cod_material),
    'desc_material',     APPROX_COUNT_DISTINCT(desc_material),
    'sg_unidade_medida', APPROX_COUNT_DISTINCT(sg_unidade_medida),
    'dt_estoque',        APPROX_COUNT_DISTINCT(dt_estoque),
    'estoque_inicial',   APPROX_COUNT_DISTINCT(estoque_inicial),
    'entrada',           APPROX_COUNT_DISTINCT(entrada),
    'saida',             APPROX_COUNT_DISTINCT(saida),
    'estoque_final',     APPROX_COUNT_DISTINCT(estoque_final),
    'dh_carga',          APPROX_COUNT_DISTINCT(dh_carga),
    'dh_atualizacao',    APPROX_COUNT_DISTINCT(dh_atualizacao)
  ) AS (coluna, distintos)
  FROM base
)
SELECT
  c.coluna,
  c.distintos,
  ROUND(100.0 * c.distintos / NULLIF(t.linhas, 0), 4) AS pct_distintos,
  CASE
    WHEN c.distintos <= 1 THEN 'CONSTANTE'
    WHEN c.distintos <= 3 THEN 'CARDINALIDADE MUITO BAIXA'
    WHEN c.distintos > t.linhas * 0.95 THEN 'CANDIDATA A IDENTIFICADOR'
    ELSE 'NORMAL'
  END AS classificacao
FROM cardinalidade c
CROSS JOIN total t
ORDER BY c.distintos;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Formato de dt_estoque

-- COMMAND ----------

SELECT
  COUNT(*) AS linhas,
  COUNT_IF(dt_estoque IS NULL OR TRIM(dt_estoque) = '') AS vazios,
  COUNT_IF(TRIM(dt_estoque) RLIKE '^[0-9]{8}$') AS formato_yyyyMMdd,
  COUNT_IF(TRIM(dt_estoque) RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS formato_iso,
  COUNT_IF(TRIM(dt_estoque) RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$') AS formato_br,
  COUNT_IF(
    dt_estoque IS NOT NULL
    AND TRIM(dt_estoque) <> ''
    AND NOT TRIM(dt_estoque) RLIKE '^[0-9]{8}$'
    AND NOT TRIM(dt_estoque) RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    AND NOT TRIM(dt_estoque) RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
  ) AS nao_reconhecidos,
  MIN(dt_estoque) AS menor_valor,
  MAX(dt_estoque) AS maior_valor
FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Dominio das dimensoes categoricas

-- COMMAND ----------

WITH dominios AS (
  SELECT 'cod_empresa' AS coluna, CAST(cod_empresa AS STRING) AS valor, COUNT(*) AS qtd
  FROM base
  GROUP BY cod_empresa

  UNION ALL

  SELECT 'cod_centro' AS coluna, CAST(cod_centro AS STRING) AS valor, COUNT(*) AS qtd
  FROM base
  GROUP BY cod_centro

  UNION ALL

  SELECT 'desc_centro' AS coluna, CAST(desc_centro AS STRING) AS valor, COUNT(*) AS qtd
  FROM base
  GROUP BY desc_centro

  UNION ALL

  SELECT 'sg_unidade_medida' AS coluna, CAST(sg_unidade_medida AS STRING) AS valor, COUNT(*) AS qtd
  FROM base
  GROUP BY sg_unidade_medida
),
classificado AS (
  SELECT
    coluna,
    valor,
    qtd,
    ROUND(100.0 * qtd / NULLIF(SUM(qtd) OVER (PARTITION BY coluna), 0), 2) AS pct,
    ROW_NUMBER() OVER (PARTITION BY coluna ORDER BY qtd DESC, valor) AS posicao
  FROM dominios
)
SELECT
  coluna,
  valor,
  qtd,
  pct
FROM classificado
WHERE posicao <= 20
ORDER BY coluna, qtd DESC, valor;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Perfil numerico

-- COMMAND ----------

SELECT
  'estoque_inicial' AS coluna,
  COUNT(estoque_inicial) AS preenchidos,
  MIN(estoque_inicial) AS minimo,
  MAX(estoque_inicial) AS maximo,
  AVG(estoque_inicial) AS media,
  PERCENTILE_APPROX(estoque_inicial, 0.5) AS mediana,
  PERCENTILE_APPROX(estoque_inicial, 0.95) AS p95,
  COUNT_IF(estoque_inicial < 0) AS negativos,
  COUNT_IF(estoque_inicial = 0) AS zeros
FROM base

UNION ALL

SELECT
  'entrada', COUNT(entrada), MIN(entrada), MAX(entrada), AVG(entrada),
  PERCENTILE_APPROX(entrada, 0.5), PERCENTILE_APPROX(entrada, 0.95),
  COUNT_IF(entrada < 0), COUNT_IF(entrada = 0)
FROM base

UNION ALL

SELECT
  'saida', COUNT(saida), MIN(saida), MAX(saida), AVG(saida),
  PERCENTILE_APPROX(saida, 0.5), PERCENTILE_APPROX(saida, 0.95),
  COUNT_IF(saida < 0), COUNT_IF(saida = 0)
FROM base

UNION ALL

SELECT
  'estoque_final', COUNT(estoque_final), MIN(estoque_final), MAX(estoque_final), AVG(estoque_final),
  PERCENTILE_APPROX(estoque_final, 0.5), PERCENTILE_APPROX(estoque_final, 0.95),
  COUNT_IF(estoque_final < 0), COUNT_IF(estoque_final = 0)
FROM base
ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Distribuicao por centro

-- COMMAND ----------

WITH centros AS (
  SELECT
    cod_centro,
    MAX(desc_centro) AS desc_centro,
    COUNT(*) AS linhas,
    COUNT(DISTINCT cod_material) AS materiais,
    COUNT(DISTINCT dt_estoque) AS datas
  FROM base
  GROUP BY cod_centro
),
centros_com_percentual AS (
  SELECT
    cod_centro,
    desc_centro,
    linhas,
    materiais,
    datas,
    ROUND(100.0 * linhas / NULLIF(SUM(linhas) OVER (), 0), 2) AS pct_linhas
  FROM centros
)
SELECT
  cod_centro,
  desc_centro,
  linhas,
  materiais,
  datas,
  pct_linhas,
  CASE
    WHEN linhas BETWEEN 10000 AND 300000 THEN 'CANDIDATO A TESTE'
    ELSE ''
  END AS sugestao
FROM centros_com_percentual
ORDER BY linhas DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Distribuicao por empresa

-- COMMAND ----------

WITH empresas AS (
  SELECT
    cod_empresa,
    COUNT(*) AS linhas,
    COUNT(DISTINCT cod_centro) AS centros,
    COUNT(DISTINCT cod_material) AS materiais
  FROM base
  GROUP BY cod_empresa
),
empresas_com_percentual AS (
  SELECT
    cod_empresa,
    linhas,
    centros,
    materiais,
    ROUND(100.0 * linhas / NULLIF(SUM(linhas) OVER (), 0), 2) AS pct_linhas
  FROM empresas
)
SELECT
  cod_empresa,
  linhas,
  centros,
  materiais,
  pct_linhas
FROM empresas_com_percentual
ORDER BY linhas DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 15. Freshness da carga

-- COMMAND ----------

SELECT
  MAX(dh_carga) AS ultima_carga,
  MAX(dh_atualizacao) AS ultima_atualizacao,
  DATEDIFF(CURRENT_TIMESTAMP(), MAX(dh_carga)) AS dias_desde_carga,
  DATEDIFF(CURRENT_TIMESTAMP(), MAX(dh_atualizacao)) AS dias_desde_atualizacao,
  COUNT(DISTINCT DATE(dh_carga)) AS dias_distintos_carga
FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 16. Equacao contabil MB5B
-- MAGIC A coluna `saida` esta armazenada com sinal negativo. A regra avaliada e:
-- MAGIC `estoque_inicial + entrada + saida = estoque_final`.

-- COMMAND ----------

WITH calculo AS (
  SELECT
    estoque_inicial,
    entrada,
    saida,
    estoque_final,
    estoque_inicial + entrada + saida AS estoque_calculado,
    ABS((estoque_inicial + entrada + saida) - estoque_final) AS diferenca
  FROM base
),
resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT_IF(diferenca <= 0.001) AS equacao_ok,
    COUNT_IF(diferenca > 0.001) AS divergentes,
    MAX(diferenca) AS maior_diferenca,
    COUNT_IF(
      estoque_inicial IS NULL
      OR entrada IS NULL
      OR saida IS NULL
      OR estoque_final IS NULL
    ) AS com_campo_nulo
  FROM calculo
)
SELECT
  linhas,
  equacao_ok,
  divergentes,
  ROUND(100.0 * divergentes / NULLIF(linhas, 0), 4) AS pct_divergente,
  maior_diferenca,
  com_campo_nulo,
  CASE
    WHEN divergentes = 0 AND com_campo_nulo = 0 THEN 'OK - EQUACAO FECHA'
    ELSE 'ALERTA - INVESTIGAR ANTES DA COMPARACAO SAP'
  END AS veredito
FROM resumo;

-- COMMAND ----------

WITH divergencias AS (
  SELECT
    cod_empresa,
    cod_centro,
    desc_centro,
    cod_material,
    dt_estoque,
    estoque_inicial,
    entrada,
    saida,
    estoque_final,
    estoque_inicial + entrada + saida AS estoque_calculado,
    ABS((estoque_inicial + entrada + saida) - estoque_final) AS diferenca
  FROM base
)
SELECT *
FROM divergencias
WHERE diferenca > 0.001
ORDER BY diferenca DESC
LIMIT 50;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 17. Continuidade temporal
-- MAGIC A view possui somente dias com movimento. Por isso, a continuidade compara cada registro com o proximo dia disponivel e informa separadamente as lacunas de calendario.

-- COMMAND ----------

WITH datas_convertidas AS (
  SELECT
    cod_empresa,
    cod_centro,
    cod_material,
    TO_DATE(dt_estoque, 'yyyyMMdd') AS dt,
    estoque_inicial,
    estoque_final
  FROM base
  WHERE dt_estoque RLIKE '^[0-9]{8}$'
),
sequencia AS (
  SELECT
    cod_empresa,
    cod_centro,
    cod_material,
    dt,
    estoque_inicial,
    estoque_final,
    LAG(estoque_final) OVER (
      PARTITION BY cod_empresa, cod_centro, cod_material
      ORDER BY dt
    ) AS estoque_final_anterior,
    LAG(dt) OVER (
      PARTITION BY cod_empresa, cod_centro, cod_material
      ORDER BY dt
    ) AS dt_anterior
  FROM datas_convertidas
)
SELECT
  COUNT_IF(estoque_final_anterior IS NOT NULL) AS transicoes,
  COUNT_IF(
    estoque_final_anterior IS NOT NULL
    AND ABS(estoque_inicial - estoque_final_anterior) <= 0.001
  ) AS continuas,
  COUNT_IF(
    estoque_final_anterior IS NOT NULL
    AND ABS(estoque_inicial - estoque_final_anterior) > 0.001
  ) AS quebradas,
  COUNT_IF(
    estoque_final_anterior IS NOT NULL
    AND DATEDIFF(dt, dt_anterior) > 1
  ) AS com_lacuna_de_dias,
  MAX(DATEDIFF(dt, dt_anterior)) AS maior_lacuna_dias
FROM sequencia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 18. Cobertura temporal

-- COMMAND ----------

WITH datas AS (
  SELECT TO_DATE(dt_estoque, 'yyyyMMdd') AS dt
  FROM base
  WHERE dt_estoque RLIKE '^[0-9]{8}$'
)
SELECT
  MIN(dt) AS primeira_data,
  MAX(dt) AS ultima_data,
  COUNT(DISTINCT dt) AS dias_com_dado,
  DATEDIFF(MAX(dt), MIN(dt)) + 1 AS dias_do_periodo,
  DATEDIFF(MAX(dt), MIN(dt)) + 1 - COUNT(DISTINCT dt) AS dias_sem_dado
FROM datas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 19. Consistencia entre codigo e descricao do centro

-- COMMAND ----------

SELECT
  cod_centro,
  COUNT(DISTINCT desc_centro) AS descricoes_distintas,
  COLLECT_SET(desc_centro) AS descricoes
FROM base
GROUP BY cod_centro
HAVING COUNT(DISTINCT desc_centro) > 1
ORDER BY descricoes_distintas DESC, cod_centro;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 20. Formato dos codigos

-- COMMAND ----------

SELECT
  'cod_empresa' AS coluna,
  COUNT_IF(cod_empresa IS NULL OR TRIM(cod_empresa) = '') AS vazios,
  MIN(LENGTH(TRIM(cod_empresa))) AS tamanho_minimo,
  MAX(LENGTH(TRIM(cod_empresa))) AS tamanho_maximo,
  COUNT_IF(TRIM(cod_empresa) RLIKE '^0[0-9]+') AS com_zero_esquerda,
  COUNT_IF(cod_empresa <> TRIM(cod_empresa)) AS com_espacos
FROM base

UNION ALL

SELECT
  'cod_centro',
  COUNT_IF(cod_centro IS NULL OR TRIM(cod_centro) = ''),
  MIN(LENGTH(TRIM(cod_centro))),
  MAX(LENGTH(TRIM(cod_centro))),
  COUNT_IF(TRIM(cod_centro) RLIKE '^0[0-9]+'),
  COUNT_IF(cod_centro <> TRIM(cod_centro))
FROM base

UNION ALL

SELECT
  'cod_material',
  COUNT_IF(cod_material IS NULL OR TRIM(cod_material) = ''),
  MIN(LENGTH(TRIM(cod_material))),
  MAX(LENGTH(TRIM(cod_material))),
  COUNT_IF(TRIM(cod_material) RLIKE '^0[0-9]+'),
  COUNT_IF(cod_material <> TRIM(cod_material))
FROM base
ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 21. Amostras

-- COMMAND ----------

SELECT *
FROM base
LIMIT 50;

-- COMMAND ----------

SELECT *
FROM base
ORDER BY RAND()
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 22. Resumo consolidado

-- COMMAND ----------

WITH volumetria AS (
  SELECT COUNT(*) AS linhas
  FROM base
),
granularidade AS (
  SELECT COUNT(*) AS chaves
  FROM (
    SELECT DISTINCT cod_empresa, cod_centro, cod_material, dt_estoque
    FROM base
  ) x
),
equacao AS (
  SELECT
    COUNT_IF(
      ABS((estoque_inicial + entrada + saida) - estoque_final) > 0.001
    ) AS divergentes
  FROM base
),
cobertura AS (
  SELECT
    MIN(TO_DATE(dt_estoque, 'yyyyMMdd')) AS primeira_data,
    MAX(TO_DATE(dt_estoque, 'yyyyMMdd')) AS ultima_data
  FROM base
  WHERE dt_estoque RLIKE '^[0-9]{8}$'
)
SELECT
  'VOLUMETRIA' AS bloco,
  'linhas na base' AS item,
  CAST(v.linhas AS STRING) AS valor,
  '' AS veredito
FROM volumetria v

UNION ALL

SELECT
  'ESTRUTURA',
  'colunas esperadas',
  '13',
  'cod_empresa a dh_atualizacao'

UNION ALL

SELECT
  'GRANULARIDADE',
  'cod_empresa + cod_centro + cod_material + dt_estoque',
  CAST(ROUND(v.linhas / NULLIF(g.chaves, 0), 4) AS STRING),
  CASE WHEN v.linhas = g.chaves THEN 'CHAVE UNICA' ELSE 'NAO UNICA' END
FROM volumetria v
CROSS JOIN granularidade g

UNION ALL

SELECT
  'QUALIDADE',
  'divergencias na equacao contabil',
  CAST(e.divergentes AS STRING),
  CASE WHEN e.divergentes = 0 THEN 'OK' ELSE 'ALERTA' END
FROM equacao e

UNION ALL

SELECT
  'COBERTURA',
  'primeira data',
  CAST(c.primeira_data AS STRING),
  ''
FROM cobertura c

UNION ALL

SELECT
  'COBERTURA',
  'ultima data',
  CAST(c.ultima_data AS STRING),
  ''
FROM cobertura c

ORDER BY bloco, item;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Proximo passo
-- MAGIC Antes de solicitar a extracao SAP, confirme:
-- MAGIC 1. A distribuicao por centro foi executada sem erro.
-- MAGIC 2. A distribuicao por empresa foi executada sem erro.
-- MAGIC 3. A equacao contabil retornou `divergentes = 0` ou as divergencias foram investigadas.
-- MAGIC 4. O recorte SAP utiliza o mesmo centro, empresa e data de referencia do Datalake.
-- MAGIC 5. Todas as telas ou abas aplicaveis da MB5B serao extraidas.