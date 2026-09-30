-- Databricks notebook source
-- MAGIC %md
-- MAGIC # MB52 - Analise Exploratoria do Datalake - Producao
-- MAGIC
-- MAGIC **Transacao SAP:** MB52  
-- MAGIC **Objeto PROD:** `prd_procurement.corp_curated.vw_ds_log_mb52_estoque_por_deposito`
-- MAGIC
-- MAGIC Objetivo: entender volumetria, estrutura, granularidade, preenchimento, dominios, formatos, ranges, freshness e riscos especificos da MB52 antes da comparacao com o SAP.
-- MAGIC
-- MAGIC Aviso metodologico: igualdade de contagem de linhas nao comprova qualidade. Erros de granularidade, campos nulos, defaults e divergencias de valor podem preservar a volumetria.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Parametros de recorte
-- MAGIC Deixe os widgets vazios para analisar a base completa. Use filtros para recortes por centro, tipo de material ou deposito.

-- COMMAND ----------

-- PARAMETROS OPCIONAIS

CREATE OR REPLACE TEMP VIEW parametros AS
SELECT
    '' AS f_cod_centro,
    '' AS f_tp_material,
    '' AS f_cod_deposito;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. View base em PROD
-- MAGIC Todas as consultas posteriores usam a view temporaria `base`.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW base AS
SELECT *
FROM prd_procurement.corp_curated.vw_ds_log_mb52_estoque_por_deposito;

-- COMMAND ----------

SELECT COUNT(*) AS linhas_na_base FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Estrutura e metadados
-- MAGIC Confirma colunas, tipos e propriedades do objeto de producao antes da analise.

-- COMMAND ----------

DESCRIBE EXTENDED prd_procurement.corp_curated.vw_ds_log_mb52_estoque_por_deposito;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Volumetria e granularidade real
-- MAGIC Compara linhas com combinacoes distintas de chaves candidatas. A MB52 deve preservar material, centro e deposito. O tipo de estoque especial pode representar dimensao adicional.

-- COMMAND ----------

WITH t AS (SELECT COUNT(*) AS total FROM base),
g AS (
  SELECT 'cod_material + cod_centro' AS chave, COUNT(*) AS combinacoes_distintas
  FROM (SELECT DISTINCT cod_material, cod_centro FROM base)
  UNION ALL
  SELECT 'cod_material + cod_centro + cod_deposito', COUNT(*)
  FROM (SELECT DISTINCT cod_material, cod_centro, cod_deposito FROM base)
  UNION ALL
  SELECT 'cod_material + cod_centro + cod_deposito + tp_estoque_especial', COUNT(*)
  FROM (SELECT DISTINCT cod_material, cod_centro, cod_deposito, tp_estoque_especial FROM base)
  UNION ALL
  SELECT 'cod_material + cod_centro + cod_deposito + tp_estoque_especial + dateingest', COUNT(*)
  FROM (SELECT DISTINCT cod_material, cod_centro, cod_deposito, tp_estoque_especial, dateingest FROM base)
)
SELECT g.chave, t.total AS linhas, g.combinacoes_distintas,
       ROUND(t.total / NULLIF(g.combinacoes_distintas, 0), 4) AS linhas_por_chave,
       CASE WHEN g.combinacoes_distintas = t.total THEN 'CHAVE UNICA'
            ELSE 'NAO UNICA - ha dimensao adicional ou duplicidade' END AS veredito
FROM g CROSS JOIN t
ORDER BY linhas_por_chave;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Duplicidade por chave candidata
-- MAGIC Quantifica chaves repetidas e o pior caso em cada nivel.

-- COMMAND ----------

SELECT 'cod_material + cod_centro' AS chave,
       COUNT(*) AS chaves_repetidas,
       SUM(qtd - 1) AS linhas_excedentes,
       MAX(qtd) AS pior_caso
FROM (SELECT cod_material, cod_centro, COUNT(*) qtd FROM base GROUP BY cod_material, cod_centro HAVING COUNT(*) > 1)
UNION ALL
SELECT 'cod_material + cod_centro + cod_deposito', COUNT(*), SUM(qtd - 1), MAX(qtd)
FROM (SELECT cod_material, cod_centro, cod_deposito, COUNT(*) qtd FROM base GROUP BY cod_material, cod_centro, cod_deposito HAVING COUNT(*) > 1)
UNION ALL
SELECT 'cod_material + cod_centro + cod_deposito + tp_estoque_especial', COUNT(*), SUM(qtd - 1), MAX(qtd)
FROM (SELECT cod_material, cod_centro, cod_deposito, tp_estoque_especial, COUNT(*) qtd FROM base GROUP BY cod_material, cod_centro, cod_deposito, tp_estoque_especial HAVING COUNT(*) > 1)
ORDER BY chaves_repetidas DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Exemplos de chaves duplicadas

-- COMMAND ----------

SELECT cod_material, cod_centro, cod_deposito, tp_estoque_especial, COUNT(*) AS qtd
FROM base
GROUP BY cod_material, cod_centro, cod_deposito, tp_estoque_especial
HAVING COUNT(*) > 1
ORDER BY qtd DESC
LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 07. Preenchimento de todas as 23 colunas
-- MAGIC Classifica nulos, vazios, zeros e valores uteis. Esta varredura nao usa amostragem.

-- COMMAND ----------

WITH t AS (SELECT COUNT(*) AS total FROM base),
perf AS (
  SELECT stack(23,
    'cod_material','string',COUNT_IF(cod_material IS NULL),COUNT_IF(cod_material IS NOT NULL AND lower(trim(cod_material)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(cod_material) RLIKE '^0+([.,]0+)?$'),
    'cod_centro','string',COUNT_IF(cod_centro IS NULL),COUNT_IF(cod_centro IS NOT NULL AND lower(trim(cod_centro)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(cod_centro) RLIKE '^0+([.,]0+)?$'),
    'desc_material','string',COUNT_IF(desc_material IS NULL),COUNT_IF(desc_material IS NOT NULL AND lower(trim(desc_material)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(desc_material) RLIKE '^0+([.,]0+)?$'),
    'cod_deposito','string',COUNT_IF(cod_deposito IS NULL),COUNT_IF(cod_deposito IS NOT NULL AND lower(trim(cod_deposito)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(cod_deposito) RLIKE '^0+([.,]0+)?$'),
    'tp_material','string',COUNT_IF(tp_material IS NULL),COUNT_IF(tp_material IS NOT NULL AND lower(trim(tp_material)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(tp_material) RLIKE '^0+([.,]0+)?$'),
    'tp_grupo_mercadorias','string',COUNT_IF(tp_grupo_mercadorias IS NULL),COUNT_IF(tp_grupo_mercadorias IS NOT NULL AND lower(trim(tp_grupo_mercadorias)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(tp_grupo_mercadorias) RLIKE '^0+([.,]0+)?$'),
    'nm_centro','string',COUNT_IF(nm_centro IS NULL),COUNT_IF(nm_centro IS NOT NULL AND lower(trim(nm_centro)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(nm_centro) RLIKE '^0+([.,]0+)?$'),
    'ind_eliminacao_deposito','string',COUNT_IF(ind_eliminacao_deposito IS NULL),COUNT_IF(ind_eliminacao_deposito IS NOT NULL AND lower(trim(ind_eliminacao_deposito)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(ind_eliminacao_deposito) RLIKE '^0+([.,]0+)?$'),
    'tp_estoque_especial','string',COUNT_IF(tp_estoque_especial IS NULL),COUNT_IF(tp_estoque_especial IS NOT NULL AND lower(trim(tp_estoque_especial)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(tp_estoque_especial) RLIKE '^0+([.,]0+)?$'),
    'qt_utilizacao_livre','decimal(13,3)',COUNT_IF(qt_utilizacao_livre IS NULL),0L,COUNT_IF(qt_utilizacao_livre = 0),
    'sg_unidade_medida_basica','string',COUNT_IF(sg_unidade_medida_basica IS NULL),COUNT_IF(sg_unidade_medida_basica IS NOT NULL AND lower(trim(sg_unidade_medida_basica)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(sg_unidade_medida_basica) RLIKE '^0+([.,]0+)?$'),
    'vl_utilizacao_livre','double',COUNT_IF(vl_utilizacao_livre IS NULL),0L,COUNT_IF(vl_utilizacao_livre = 0),
    'cod_moeda','string',COUNT_IF(cod_moeda IS NULL),COUNT_IF(cod_moeda IS NOT NULL AND lower(trim(cod_moeda)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(cod_moeda) RLIKE '^0+([.,]0+)?$'),
    'qt_transito','decimal(13,3)',COUNT_IF(qt_transito IS NULL),0L,COUNT_IF(qt_transito = 0),
    'vl_transito','double',COUNT_IF(vl_transito IS NULL),0L,COUNT_IF(vl_transito = 0),
    'qt_controle_qualidade','decimal(13,3)',COUNT_IF(qt_controle_qualidade IS NULL),0L,COUNT_IF(qt_controle_qualidade = 0),
    'vl_controle_qualidade','double',COUNT_IF(vl_controle_qualidade IS NULL),0L,COUNT_IF(vl_controle_qualidade = 0),
    'qt_estoque_bloqueado','decimal(13,3)',COUNT_IF(qt_estoque_bloqueado IS NULL),0L,COUNT_IF(qt_estoque_bloqueado = 0),
    'vl_estoque_bloqueado','double',COUNT_IF(vl_estoque_bloqueado IS NULL),0L,COUNT_IF(vl_estoque_bloqueado = 0),
    'cod_estoque_especial','string',COUNT_IF(cod_estoque_especial IS NULL),COUNT_IF(cod_estoque_especial IS NOT NULL AND lower(trim(cod_estoque_especial)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(cod_estoque_especial) RLIKE '^0+([.,]0+)?$'),
    'dateingest','date',COUNT_IF(dateingest IS NULL),0L,0L,
    'yearingest','string',COUNT_IF(yearingest IS NULL),COUNT_IF(yearingest IS NOT NULL AND lower(trim(yearingest)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(yearingest) RLIKE '^0+([.,]0+)?$'),
    'monthingest','string',COUNT_IF(monthingest IS NULL),COUNT_IF(monthingest IS NOT NULL AND lower(trim(monthingest)) IN ('','null','nan','none','#','-','na','n/a')),COUNT_IF(trim(monthingest) RLIKE '^0+([.,]0+)?$')
  ) AS (coluna,tipo,nulos,vazios,zeros)
  FROM base
)
SELECT p.coluna, p.tipo, p.nulos, p.vazios, p.zeros,
       t.total - p.nulos - p.vazios - p.zeros AS uteis,
       ROUND(100.0 * (t.total - p.nulos - p.vazios - p.zeros) / NULLIF(t.total,0), 2) AS pct_util,
       CASE WHEN p.nulos = t.total THEN '1. 100% NULO'
            WHEN t.total - p.nulos - p.vazios - p.zeros <= 0 THEN '2. SEM VALOR UTIL'
            WHEN t.total - p.nulos - p.vazios - p.zeros < t.total * 0.01 THEN '3. QUASE VAZIO (<1%)'
            ELSE '9. OK' END AS veredito
FROM perf p CROSS JOIN t
ORDER BY veredito, pct_util, coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 08. Cardinalidade por coluna
-- MAGIC Colunas constantes ou de cardinalidade muito baixa podem indicar default de carga.

-- COMMAND ----------

WITH t AS (SELECT COUNT(*) total FROM base), card AS (
SELECT stack(23,
 'cod_material','string',approx_count_distinct(cod_material),
 'cod_centro','string',approx_count_distinct(cod_centro),
 'desc_material','string',approx_count_distinct(desc_material),
 'cod_deposito','string',approx_count_distinct(cod_deposito),
 'tp_material','string',approx_count_distinct(tp_material),
 'tp_grupo_mercadorias','string',approx_count_distinct(tp_grupo_mercadorias),
 'nm_centro','string',approx_count_distinct(nm_centro),
 'ind_eliminacao_deposito','string',approx_count_distinct(ind_eliminacao_deposito),
 'tp_estoque_especial','string',approx_count_distinct(tp_estoque_especial),
 'qt_utilizacao_livre','decimal(13,3)',approx_count_distinct(qt_utilizacao_livre),
 'sg_unidade_medida_basica','string',approx_count_distinct(sg_unidade_medida_basica),
 'vl_utilizacao_livre','double',approx_count_distinct(vl_utilizacao_livre),
 'cod_moeda','string',approx_count_distinct(cod_moeda),
 'qt_transito','decimal(13,3)',approx_count_distinct(qt_transito),
 'vl_transito','double',approx_count_distinct(vl_transito),
 'qt_controle_qualidade','decimal(13,3)',approx_count_distinct(qt_controle_qualidade),
 'vl_controle_qualidade','double',approx_count_distinct(vl_controle_qualidade),
 'qt_estoque_bloqueado','decimal(13,3)',approx_count_distinct(qt_estoque_bloqueado),
 'vl_estoque_bloqueado','double',approx_count_distinct(vl_estoque_bloqueado),
 'cod_estoque_especial','string',approx_count_distinct(cod_estoque_especial),
 'dateingest','date',approx_count_distinct(dateingest),
 'yearingest','string',approx_count_distinct(yearingest),
 'monthingest','string',approx_count_distinct(monthingest)
) AS (coluna,tipo,distintos) FROM base)
SELECT coluna,tipo,distintos,ROUND(100.0*distintos/NULLIF(total,0),4) AS pct_distintos,
 CASE WHEN distintos <= 1 THEN '1. CONSTANTE'
      WHEN distintos <= 3 THEN '2. CARDINALIDADE MUITO BAIXA'
      WHEN distintos > total*0.95 THEN '3. CANDIDATA A IDENTIFICADOR'
      ELSE '9. NORMAL' END AS classificacao
FROM card CROSS JOIN t ORDER BY distintos;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 09. Dominios das colunas categoricas
-- MAGIC Exibe os valores mais frequentes e a participacao na base.

-- COMMAND ----------

WITH total AS (SELECT COUNT(*) n FROM base), dominios AS (
SELECT 'cod_centro' coluna, CAST(cod_centro AS STRING) valor, COUNT(*) qtd FROM base GROUP BY cod_centro
UNION ALL SELECT 'tp_material',CAST(tp_material AS STRING),COUNT(*) FROM base GROUP BY tp_material
UNION ALL SELECT 'tp_grupo_mercadorias',CAST(tp_grupo_mercadorias AS STRING),COUNT(*) FROM base GROUP BY tp_grupo_mercadorias
UNION ALL SELECT 'cod_deposito',CAST(cod_deposito AS STRING),COUNT(*) FROM base GROUP BY cod_deposito
UNION ALL SELECT 'tp_estoque_especial',CAST(tp_estoque_especial AS STRING),COUNT(*) FROM base GROUP BY tp_estoque_especial
UNION ALL SELECT 'sg_unidade_medida_basica',CAST(sg_unidade_medida_basica AS STRING),COUNT(*) FROM base GROUP BY sg_unidade_medida_basica
UNION ALL SELECT 'cod_moeda',CAST(cod_moeda AS STRING),COUNT(*) FROM base GROUP BY cod_moeda
UNION ALL SELECT 'ind_eliminacao_deposito',CAST(ind_eliminacao_deposito AS STRING),COUNT(*) FROM base GROUP BY ind_eliminacao_deposito
UNION ALL SELECT 'cod_estoque_especial',CAST(cod_estoque_especial AS STRING),COUNT(*) FROM base GROUP BY cod_estoque_especial
), r AS (SELECT *, ROW_NUMBER() OVER(PARTITION BY coluna ORDER BY qtd DESC) rn FROM dominios)
SELECT coluna, valor, qtd, ROUND(100.0*qtd/NULLIF(n,0),2) pct
FROM r CROSS JOIN total WHERE rn <= 8 ORDER BY coluna,qtd DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Perfil numerico
-- MAGIC Avalia minimos, maximos, media, mediana, percentil 95, negativos e zeros.

-- COMMAND ----------

SELECT * FROM (
SELECT stack(8,
 'qt_utilizacao_livre','decimal(13,3)',COUNT(qt_utilizacao_livre),CAST(MIN(qt_utilizacao_livre) AS DOUBLE),CAST(MAX(qt_utilizacao_livre) AS DOUBLE),CAST(AVG(qt_utilizacao_livre) AS DOUBLE),CAST(percentile_approx(qt_utilizacao_livre,0.5) AS DOUBLE),CAST(percentile_approx(qt_utilizacao_livre,0.95) AS DOUBLE),COUNT_IF(qt_utilizacao_livre<0),COUNT_IF(qt_utilizacao_livre=0),
 'vl_utilizacao_livre','double',COUNT(vl_utilizacao_livre),MIN(vl_utilizacao_livre),MAX(vl_utilizacao_livre),AVG(vl_utilizacao_livre),percentile_approx(vl_utilizacao_livre,0.5),percentile_approx(vl_utilizacao_livre,0.95),COUNT_IF(vl_utilizacao_livre<0),COUNT_IF(vl_utilizacao_livre=0),
 'qt_transito','decimal(13,3)',COUNT(qt_transito),CAST(MIN(qt_transito) AS DOUBLE),CAST(MAX(qt_transito) AS DOUBLE),CAST(AVG(qt_transito) AS DOUBLE),CAST(percentile_approx(qt_transito,0.5) AS DOUBLE),CAST(percentile_approx(qt_transito,0.95) AS DOUBLE),COUNT_IF(qt_transito<0),COUNT_IF(qt_transito=0),
 'vl_transito','double',COUNT(vl_transito),MIN(vl_transito),MAX(vl_transito),AVG(vl_transito),percentile_approx(vl_transito,0.5),percentile_approx(vl_transito,0.95),COUNT_IF(vl_transito<0),COUNT_IF(vl_transito=0),
 'qt_controle_qualidade','decimal(13,3)',COUNT(qt_controle_qualidade),CAST(MIN(qt_controle_qualidade) AS DOUBLE),CAST(MAX(qt_controle_qualidade) AS DOUBLE),CAST(AVG(qt_controle_qualidade) AS DOUBLE),CAST(percentile_approx(qt_controle_qualidade,0.5) AS DOUBLE),CAST(percentile_approx(qt_controle_qualidade,0.95) AS DOUBLE),COUNT_IF(qt_controle_qualidade<0),COUNT_IF(qt_controle_qualidade=0),
 'vl_controle_qualidade','double',COUNT(vl_controle_qualidade),MIN(vl_controle_qualidade),MAX(vl_controle_qualidade),AVG(vl_controle_qualidade),percentile_approx(vl_controle_qualidade,0.5),percentile_approx(vl_controle_qualidade,0.95),COUNT_IF(vl_controle_qualidade<0),COUNT_IF(vl_controle_qualidade=0),
 'qt_estoque_bloqueado','decimal(13,3)',COUNT(qt_estoque_bloqueado),CAST(MIN(qt_estoque_bloqueado) AS DOUBLE),CAST(MAX(qt_estoque_bloqueado) AS DOUBLE),CAST(AVG(qt_estoque_bloqueado) AS DOUBLE),CAST(percentile_approx(qt_estoque_bloqueado,0.5) AS DOUBLE),CAST(percentile_approx(qt_estoque_bloqueado,0.95) AS DOUBLE),COUNT_IF(qt_estoque_bloqueado<0),COUNT_IF(qt_estoque_bloqueado=0),
 'vl_estoque_bloqueado','double',COUNT(vl_estoque_bloqueado),MIN(vl_estoque_bloqueado),MAX(vl_estoque_bloqueado),AVG(vl_estoque_bloqueado),percentile_approx(vl_estoque_bloqueado,0.5),percentile_approx(vl_estoque_bloqueado,0.95),COUNT_IF(vl_estoque_bloqueado<0),COUNT_IF(vl_estoque_bloqueado=0)
) AS (coluna,tipo,preenchidos,minimo,maximo,media,mediana,p95,negativos,zeros)
FROM base) ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Datas e freshness

-- COMMAND ----------

SELECT MIN(dateingest) AS primeira_carga,
       MAX(dateingest) AS ultima_carga,
       COUNT(DISTINCT dateingest) AS cargas_distintas,
       COUNT_IF(dateingest > current_date()) AS datas_futuras,
       COUNT_IF(dateingest < DATE'1990-01-01') AS datas_anteriores_1990,
       CASE WHEN COUNT(DISTINCT dateingest)=1 THEN 'SNAPSHOT - substitui a cada carga'
            ELSE 'HISTORICO OU MULTIPLAS DATAS - avaliar chave com data' END AS classificacao
FROM base;

-- COMMAND ----------

SELECT dateingest AS data_carga, COUNT(*) AS linhas,
       COUNT(DISTINCT cod_material) AS materiais_distintos
FROM base GROUP BY dateingest ORDER BY data_carga DESC LIMIT 30;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Formato dos codigos
-- MAGIC Detecta comprimento variavel, zeros a esquerda, espacos e possiveis colisoes apos normalizacao.

-- COMMAND ----------

SELECT coluna,tipo,vazios,len_min,len_max,com_zeros_esq,com_espacos,
       distintos_bruto,distintos_sem_zeros,
       distintos_bruto-distintos_sem_zeros AS colisoes_ao_remover_zeros,
       CONCAT_WS(' | ',
         CASE WHEN com_zeros_esq>0 THEN 'tem zeros a esquerda' END,
         CASE WHEN len_min<>len_max THEN 'comprimento variavel' END,
         CASE WHEN com_espacos>0 THEN 'tem espacos' END,
         CASE WHEN distintos_bruto-distintos_sem_zeros>0 THEN 'COLISAO ao remover zeros' END
       ) AS alertas
FROM (
 SELECT stack(3,
  'cod_material','string',COUNT_IF(cod_material IS NULL OR trim(CAST(cod_material AS STRING))=''),MIN(length(trim(CAST(cod_material AS STRING)))),MAX(length(trim(CAST(cod_material AS STRING)))),COUNT_IF(trim(CAST(cod_material AS STRING)) RLIKE '^0[0-9]'),COUNT_IF(CAST(cod_material AS STRING)<>trim(CAST(cod_material AS STRING))),COUNT(DISTINCT trim(CAST(cod_material AS STRING))),COUNT(DISTINCT regexp_replace(trim(CAST(cod_material AS STRING)),'^0+','')),
  'cod_centro','string',COUNT_IF(cod_centro IS NULL OR trim(CAST(cod_centro AS STRING))=''),MIN(length(trim(CAST(cod_centro AS STRING)))),MAX(length(trim(CAST(cod_centro AS STRING)))),COUNT_IF(trim(CAST(cod_centro AS STRING)) RLIKE '^0[0-9]'),COUNT_IF(CAST(cod_centro AS STRING)<>trim(CAST(cod_centro AS STRING))),COUNT(DISTINCT trim(CAST(cod_centro AS STRING))),COUNT(DISTINCT regexp_replace(trim(CAST(cod_centro AS STRING)),'^0+','')),
  'cod_deposito','string',COUNT_IF(cod_deposito IS NULL OR trim(CAST(cod_deposito AS STRING))=''),MIN(length(trim(CAST(cod_deposito AS STRING)))),MAX(length(trim(CAST(cod_deposito AS STRING)))),COUNT_IF(trim(CAST(cod_deposito AS STRING)) RLIKE '^0[0-9]'),COUNT_IF(CAST(cod_deposito AS STRING)<>trim(CAST(cod_deposito AS STRING))),COUNT(DISTINCT trim(CAST(cod_deposito AS STRING))),COUNT(DISTINCT regexp_replace(trim(CAST(cod_deposito AS STRING)),'^0+',''))
 ) AS (coluna,tipo,vazios,len_min,len_max,com_zeros_esq,com_espacos,distintos_bruto,distintos_sem_zeros)
 FROM base
) ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Amostras completas

-- COMMAND ----------

SELECT * FROM base LIMIT 20;

-- COMMAND ----------

SELECT * FROM base ORDER BY rand() LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Distribuicao por dimensoes de recorte
-- MAGIC Apoia a escolha de cenarios viaveis para extracao no SAP.

-- COMMAND ----------

SELECT cod_centro, COUNT(*) linhas, COUNT(DISTINCT cod_material) materiais,
       COUNT(DISTINCT cod_deposito) depositos,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM base),2) pct
FROM base GROUP BY cod_centro ORDER BY linhas DESC LIMIT 100;

-- COMMAND ----------

SELECT tp_material, COUNT(*) linhas, COUNT(DISTINCT cod_material) materiais,
       COUNT(DISTINCT cod_centro) centros,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM base),2) pct,
       CASE WHEN COUNT(*) BETWEEN 10000 AND 300000 THEN 'CANDIDATO A CENARIO DE TESTE' ELSE '' END sugestao
FROM base GROUP BY tp_material ORDER BY linhas DESC LIMIT 100;

-- COMMAND ----------

SELECT cod_deposito, COUNT(*) linhas, COUNT(DISTINCT cod_material) materiais,
       COUNT(DISTINCT cod_centro) centros,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM base),2) pct,
       CASE WHEN COUNT(*) BETWEEN 10000 AND 300000 THEN 'CANDIDATO A CENARIO DE TESTE' ELSE '' END sugestao
FROM base GROUP BY cod_deposito ORDER BY linhas DESC LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 15. Analises especificas da MB52
-- MAGIC Verifica colapso de deposito e multiplicidade real por material e centro.

-- COMMAND ----------

WITH g AS (
 SELECT cod_material,cod_centro,COUNT(DISTINCT cod_deposito) qt_depositos,COUNT(*) linhas
 FROM base GROUP BY cod_material,cod_centro
)
SELECT qt_depositos,COUNT(*) materiais_centro,SUM(linhas-1) linhas_excedentes
FROM g GROUP BY qt_depositos ORDER BY qt_depositos;

-- COMMAND ----------

SELECT cod_material,cod_centro,COUNT(DISTINCT cod_deposito) qt_depositos,
       CONCAT_WS(', ',SORT_ARRAY(COLLECT_SET(cod_deposito))) depositos
FROM base GROUP BY cod_material,cod_centro
HAVING COUNT(DISTINCT cod_deposito)>1
ORDER BY qt_depositos DESC LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 16. Coerencia entre quantidade e valor
-- MAGIC Sinaliza casos em que quantidade e valor nao se comportam conjuntamente. Os resultados exigem validacao com a regra de negocio e com o SAP.

-- COMMAND ----------

SELECT 'qt_utilizacao_livre / vl_utilizacao_livre' par,
 COUNT_IF(qt_utilizacao_livre<>0 OR vl_utilizacao_livre<>0) linhas_com_estoque,
 COUNT_IF(qt_utilizacao_livre=0 AND vl_utilizacao_livre<>0) qtd_zero_valor_nao,
 COUNT_IF(qt_utilizacao_livre<>0 AND vl_utilizacao_livre=0) qtd_nao_valor_zero,
 COUNT_IF(qt_utilizacao_livre<0) qtd_negativa,COUNT_IF(vl_utilizacao_livre<0) valor_negativo
FROM base
UNION ALL
SELECT 'qt_transito / vl_transito',COUNT_IF(qt_transito<>0 OR vl_transito<>0),COUNT_IF(qt_transito=0 AND vl_transito<>0),COUNT_IF(qt_transito<>0 AND vl_transito=0),COUNT_IF(qt_transito<0),COUNT_IF(vl_transito<0) FROM base
UNION ALL
SELECT 'qt_controle_qualidade / vl_controle_qualidade',COUNT_IF(qt_controle_qualidade<>0 OR vl_controle_qualidade<>0),COUNT_IF(qt_controle_qualidade=0 AND vl_controle_qualidade<>0),COUNT_IF(qt_controle_qualidade<>0 AND vl_controle_qualidade=0),COUNT_IF(qt_controle_qualidade<0),COUNT_IF(vl_controle_qualidade<0) FROM base
UNION ALL
SELECT 'qt_estoque_bloqueado / vl_estoque_bloqueado',COUNT_IF(qt_estoque_bloqueado<>0 OR vl_estoque_bloqueado<>0),COUNT_IF(qt_estoque_bloqueado=0 AND vl_estoque_bloqueado<>0),COUNT_IF(qt_estoque_bloqueado<>0 AND vl_estoque_bloqueado=0),COUNT_IF(qt_estoque_bloqueado<0),COUNT_IF(vl_estoque_bloqueado<0) FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 17. Linhas identicas versus granularidade adicional
-- MAGIC Diferencia duplicata real de linhas distintas para a mesma chave material + centro.

-- COMMAND ----------

WITH d AS (
 SELECT * FROM base
 QUALIFY COUNT(*) OVER(PARTITION BY cod_material,cod_centro)>1
), a AS (
 SELECT cod_material,cod_centro,COUNT(*) linhas,
        COUNT(DISTINCT sha2(concat_ws('||',coalesce(CAST(cod_material AS STRING),'∅'),coalesce(CAST(cod_centro AS STRING),'∅'),coalesce(CAST(desc_material AS STRING),'∅'),coalesce(CAST(cod_deposito AS STRING),'∅'),coalesce(CAST(tp_material AS STRING),'∅'),coalesce(CAST(tp_grupo_mercadorias AS STRING),'∅'),coalesce(CAST(nm_centro AS STRING),'∅'),coalesce(CAST(ind_eliminacao_deposito AS STRING),'∅'),coalesce(CAST(tp_estoque_especial AS STRING),'∅'),coalesce(CAST(qt_utilizacao_livre AS STRING),'∅'),coalesce(CAST(sg_unidade_medida_basica AS STRING),'∅'),coalesce(CAST(vl_utilizacao_livre AS STRING),'∅'),coalesce(CAST(cod_moeda AS STRING),'∅'),coalesce(CAST(qt_transito AS STRING),'∅'),coalesce(CAST(vl_transito AS STRING),'∅'),coalesce(CAST(qt_controle_qualidade AS STRING),'∅'),coalesce(CAST(vl_controle_qualidade AS STRING),'∅'),coalesce(CAST(qt_estoque_bloqueado AS STRING),'∅'),coalesce(CAST(vl_estoque_bloqueado AS STRING),'∅'),coalesce(CAST(cod_estoque_especial AS STRING),'∅'),coalesce(CAST(dateingest AS STRING),'∅'),coalesce(CAST(yearingest AS STRING),'∅'),coalesce(CAST(monthingest AS STRING),'∅')),256)) linhas_distintas
 FROM d GROUP BY cod_material,cod_centro
)
SELECT CASE WHEN linhas_distintas=1 THEN 'DUPLICATA IDENTICA'
            ELSE 'GRANULARIDADE ADICIONAL OU DADOS DIFERENTES' END classificacao,
       COUNT(*) chaves,SUM(linhas) linhas
FROM a GROUP BY classificacao;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 18. Resumo consolidado
-- MAGIC Resultado operacional para registrar o escopo executado. O diagnostico deve ser validado antes de avancar para a escolha de cenarios SAP.

-- COMMAND ----------

-- Resumo consolidado corrigido
SELECT 'VOLUMETRIA' AS bloco,'linhas na base' AS item,CAST(COUNT(*) AS STRING) AS valor,'' AS observacao FROM base
UNION ALL SELECT 'VOLUMETRIA','colunas esperadas','23','validar no DESCRIBE EXTENDED'
UNION ALL SELECT 'GRANULARIDADE','material + centro + deposito',
 CAST((SELECT COUNT(*) FROM (SELECT DISTINCT cod_material,cod_centro,cod_deposito FROM base)) AS STRING),
 CASE WHEN (SELECT COUNT(*) FROM base)=(SELECT COUNT(*) FROM (SELECT DISTINCT cod_material,cod_centro,cod_deposito FROM base)) THEN 'CHAVE UNICA' ELSE 'NAO UNICA' END
UNION ALL SELECT 'FRESHNESS','ultima dateingest',CAST(MAX(dateingest) AS STRING),'' FROM base
UNION ALL SELECT 'ALERTA','metodo','', 'contagem igual nao comprova qualidade';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Checklist para encerrar a Fase 1
-- MAGIC - Confirmar a chave real e a granularidade.
-- MAGIC - Investigar qualquer coluna 100% nula ou sem valor util.
-- MAGIC - Registrar defaults dominantes e formatos de codigo.
-- MAGIC - Confirmar se a base e snapshot ou historica.
-- MAGIC - Escolher recorte viavel somente depois de validar o diagnostico.
-- MAGIC - Pergunta de portao: **Algum comportamento identificado contraria o esperado para a MB52 em producao?**