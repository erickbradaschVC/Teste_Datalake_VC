-- Databricks notebook source
-- MAGIC %md
-- MAGIC # MB51 - Analise Exploratoria do Datalake - PROD (SQL)
-- MAGIC **Transacao SAP:** MB51  
-- MAGIC **Objeto:** `prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material`
-- MAGIC
-- MAGIC Objetivo: entender volumetria, estrutura, preenchimento, cardinalidade, formatos, datas, valores e granularidade antes da comparacao com o SAP.
-- MAGIC
-- MAGIC **Aviso metodologico:** contagem de linhas igual nao comprova qualidade. Problemas de preenchimento, granularidade ou valor podem preservar a volumetria.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 01. Parametros centrais
-- MAGIC Altere somente a variavel `tabela_fonte` se o objeto mudar.

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE tabela_fonte STRING DEFAULT 'prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 02. Criacao da base
-- MAGIC A view temporaria evita repetir o caminho da tabela em todas as consultas.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW base AS
SELECT *
FROM prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 03. Metadados e estrutura
-- MAGIC Confirma nomes e tipos antes de formular hipoteses sobre filtros e chaves.

-- COMMAND ----------

DESCRIBE EXTENDED prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material;

-- COMMAND ----------

SELECT
  ordinal_position,
  column_name,
  full_data_type,
  is_nullable,
  comment
FROM prd_procurement.information_schema.columns
WHERE table_schema = 'corp_curated'
  AND table_name = 'vw_ds_log_mb51_movimentacao_material'
ORDER BY ordinal_position;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 04. Volumetria
-- MAGIC Estabelece a linha de base. O resultado nao deve ser usado isoladamente como criterio de aprovacao.

-- COMMAND ----------

SELECT COUNT(*) AS total_linhas
FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 05. Amostra completa
-- MAGIC Permite verificar formatos reais, zeros a esquerda, casas decimais, datas e campos vazios.

-- COMMAND ----------

SELECT *
FROM base
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 06. Preenchimento de todas as colunas
-- MAGIC O bloco gera e executa uma varredura integral de nulos, vazios, defaults textuais e zeros. Nenhuma coluna e amostrada.

-- COMMAND ----------

-- Celula 14 corrigida - perfil de preenchimento de todas as colunas
DECLARE OR REPLACE VARIABLE sql_perfil STRING;

SET VAR sql_perfil = (
  WITH metadados AS (
    SELECT
      ordinal_position,
      column_name,
      full_data_type,
      CONCAT('`', REPLACE(column_name, '`', '``'), '`') AS coluna_sql,
      CONCAT(CHR(39), REPLACE(column_name, CHR(39), CONCAT(CHR(39), CHR(39))), CHR(39)) AS coluna_literal,
      CONCAT(CHR(39), REPLACE(full_data_type, CHR(39), CONCAT(CHR(39), CHR(39))), CHR(39)) AS tipo_literal,
      CASE
        WHEN LOWER(full_data_type) LIKE 'string%'
          OR LOWER(full_data_type) LIKE 'varchar%'
          OR LOWER(full_data_type) LIKE 'char%'
        THEN 'STRING'
        WHEN LOWER(full_data_type) RLIKE '^(tinyint|smallint|int|bigint|float|double|decimal)'
        THEN 'NUMERICO'
        ELSE 'OUTRO'
      END AS categoria
    FROM prd_procurement.information_schema.columns
    WHERE table_schema = 'corp_curated'
      AND table_name = 'vw_ds_log_mb51_movimentacao_material'
  ),
  expressoes AS (
    SELECT
      ordinal_position,
      coluna_literal,
      tipo_literal,
      CONCAT(
        'SUM(CASE WHEN ', coluna_sql,
        ' IS NULL THEN 1 ELSE 0 END)'
      ) AS expr_nulos,
      CASE
        WHEN categoria = 'STRING' THEN CONCAT(
          'SUM(CASE WHEN ', coluna_sql, ' IS NOT NULL ',
          'AND LOWER(TRIM(CAST(', coluna_sql, ' AS STRING))) ',
          'IN (', CHR(39), CHR(39), ',',
                  CHR(39), 'null', CHR(39), ',',
                  CHR(39), 'nan', CHR(39), ',',
                  CHR(39), 'none', CHR(39), ',',
                  CHR(39), '#', CHR(39), ',',
                  CHR(39), '-', CHR(39), ',',
                  CHR(39), 'na', CHR(39), ',',
                  CHR(39), 'n/a', CHR(39),
          ') THEN 1 ELSE 0 END)'
        )
        ELSE 'CAST(0 AS BIGINT)'
      END AS expr_vazios,
      CASE
        WHEN categoria = 'STRING' THEN CONCAT(
          'SUM(CASE WHEN ', coluna_sql, ' IS NOT NULL ',
          'AND TRIM(CAST(', coluna_sql, ' AS STRING)) RLIKE ',
          CHR(39), '^[+-]?0+([.,]0+)?$', CHR(39),
          ' THEN 1 ELSE 0 END)'
        )
        WHEN categoria = 'NUMERICO' THEN CONCAT(
          'SUM(CASE WHEN ', coluna_sql, ' = 0 THEN 1 ELSE 0 END)'
        )
        ELSE 'CAST(0 AS BIGINT)'
      END AS expr_zeros
    FROM metadados
  ),
  blocos AS (
    SELECT
      ordinal_position,
      CONCAT(
        'SELECT ', coluna_literal, ' AS coluna, ',
        tipo_literal, ' AS tipo, ',
        'COUNT(*) AS total, ',
        expr_nulos, ' AS nulos, ',
        expr_vazios, ' AS vazios_default, ',
        expr_zeros, ' AS zeros, ',
        '(COUNT(*) - ', expr_nulos, ' - ', expr_vazios, ' - ', expr_zeros, ') AS uteis, ',
        'ROUND(100.0 * (COUNT(*) - ', expr_nulos, ' - ', expr_vazios, ' - ', expr_zeros,
        ') / NULLIF(COUNT(*), 0), 2) AS pct_util ',
        'FROM base'
      ) AS bloco
    FROM expressoes
  )
  SELECT CONCAT(
    'SELECT * FROM (',
    CONCAT_WS(
      ' UNION ALL ',
      TRANSFORM(
        ARRAY_SORT(COLLECT_LIST(NAMED_STRUCT('ord', ordinal_position, 'sql', bloco))),
        x -> x.sql
      )
    ),
    ') perfil ORDER BY pct_util ASC, coluna'
  )
  FROM blocos
);

-- Se precisar diagnosticar, execute esta linha antes do EXECUTE IMMEDIATE:
-- SELECT sql_perfil;

EXECUTE IMMEDIATE sql_perfil;


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 07. Cardinalidade de todas as colunas
-- MAGIC Colunas constantes podem indicar defaults; campos quase unicos podem ser candidatos a identificador.

-- COMMAND ----------

-- Celula 16 corrigida - cardinalidade de todas as colunas
DECLARE OR REPLACE VARIABLE sql_cardinalidade STRING;

SET VAR sql_cardinalidade = (
  WITH metadados AS (
    SELECT
      ordinal_position,
      column_name,
      full_data_type,
      CONCAT('`', REPLACE(column_name, '`', '``'), '`') AS coluna_sql,
      CONCAT(
        CHR(39),
        REPLACE(column_name, CHR(39), CONCAT(CHR(39), CHR(39))),
        CHR(39)
      ) AS coluna_literal,
      CONCAT(
        CHR(39),
        REPLACE(full_data_type, CHR(39), CONCAT(CHR(39), CHR(39))),
        CHR(39)
      ) AS tipo_literal
    FROM prd_procurement.information_schema.columns
    WHERE table_schema = 'corp_curated'
      AND table_name = 'vw_ds_log_mb51_movimentacao_material'
  ),
  blocos AS (
    SELECT
      ordinal_position,
      CONCAT(
        'SELECT ', coluna_literal, ' AS coluna, ',
        tipo_literal, ' AS tipo, ',
        'APPROX_COUNT_DISTINCT(', coluna_sql, ') AS distintos_aprox, ',
        'ROUND(100.0 * APPROX_COUNT_DISTINCT(', coluna_sql,
        ') / NULLIF(COUNT(*), 0), 4) AS pct_distintos ',
        'FROM base'
      ) AS bloco
    FROM metadados
  )
  SELECT CONCAT(
    'SELECT * FROM (',
    CONCAT_WS(
      ' UNION ALL ',
      TRANSFORM(
        ARRAY_SORT(
          COLLECT_LIST(
            NAMED_STRUCT('ord', ordinal_position, 'sql', bloco)
          )
        ),
        x -> x.sql
      )
    ),
    ') cardinalidade ORDER BY distintos_aprox ASC, coluna'
  )
  FROM blocos
);

-- Diagnostico opcional. O SQL deve mostrar 'string', com aspas.
-- SELECT sql_cardinalidade;

EXECUTE IMMEDIATE sql_cardinalidade;


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 08. Descoberta de colunas relevantes da MB51
-- MAGIC Localiza por nome campos relacionados a documento, item, material, centro, deposito, movimento e datas. Use o resultado para confirmar a chave real.

-- COMMAND ----------

SELECT
  ordinal_position,
  column_name,
  full_data_type,
  CASE
    WHEN LOWER(column_name) RLIKE 'document|documento|mblnr' THEN 'DOCUMENTO'
    WHEN LOWER(column_name) RLIKE 'item|zeile' THEN 'ITEM'
    WHEN LOWER(column_name) RLIKE 'material|matnr' THEN 'MATERIAL'
    WHEN LOWER(column_name) RLIKE 'centro|werks' THEN 'CENTRO'
    WHEN LOWER(column_name) RLIKE 'deposit|lgort' THEN 'DEPOSITO'
    WHEN LOWER(column_name) RLIKE 'moviment|bwart' THEN 'MOVIMENTO'
    WHEN LOWER(column_name) RLIKE 'data|date|dt_|budat|bldat|ingest' THEN 'DATA'
    WHEN LOWER(column_name) RLIKE 'quant|qtd|qt_|menge' THEN 'QUANTIDADE'
    WHEN LOWER(column_name) RLIKE 'valor|vl_|dmbtr|amount' THEN 'VALOR'
    ELSE 'OUTRO'
  END AS papel_candidato
FROM prd_procurement.information_schema.columns
WHERE table_schema = 'corp_curated'
  AND table_name = 'vw_ds_log_mb51_movimentacao_material'
ORDER BY papel_candidato, ordinal_position;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 09. Testes de chave candidata
-- MAGIC **Importante:** ajuste os nomes abaixo depois de consultar a secao 08. As consultas ficam comentadas para impedir conclusoes com uma chave presumida.

-- COMMAND ----------

-- Exemplo recomendado para MB51, se os campos existirem:
-- SELECT
--   COUNT(*) AS total_linhas,
--   COUNT(DISTINCT STRUCT(num_documento_material, ano_documento_material, num_item_documento)) AS chaves_distintas,
--   COUNT(*) - COUNT(DISTINCT STRUCT(num_documento_material, ano_documento_material, num_item_documento)) AS excedente,
--   ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT STRUCT(num_documento_material, ano_documento_material, num_item_documento)), 0), 6) AS linhas_por_chave
-- FROM base;

-- COMMAND ----------

-- Exemplo para listar duplicidades da chave confirmada:
-- SELECT
--   num_documento_material,
--   ano_documento_material,
--   num_item_documento,
--   COUNT(*) AS quantidade
-- FROM base
-- GROUP BY num_documento_material, ano_documento_material, num_item_documento
-- HAVING COUNT(*) > 1
-- ORDER BY quantidade DESC
-- LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Perfil automatico das colunas numericas
-- MAGIC Calcula preenchimento, minimo, maximo, media, mediana, percentil 95, negativos e zeros.

-- COMMAND ----------

-- Celula 23 corrigida - perfil numerico de todas as colunas numericas
DECLARE OR REPLACE VARIABLE sql_numericos STRING;

SET VAR sql_numericos = (
  WITH metadados AS (
    SELECT
      ordinal_position,
      column_name,
      CONCAT('`', REPLACE(column_name, '`', '``'), '`') AS coluna_sql,
      CONCAT(
        CHR(39),
        REPLACE(column_name, CHR(39), CONCAT(CHR(39), CHR(39))),
        CHR(39)
      ) AS coluna_literal
    FROM prd_procurement.information_schema.columns
    WHERE table_schema = 'corp_curated'
      AND table_name = 'vw_ds_log_mb51_movimentacao_material'
      AND LOWER(full_data_type) RLIKE '^(tinyint|smallint|int|bigint|float|double|decimal)'
  ),
  blocos AS (
    SELECT
      ordinal_position,
      CONCAT(
        'SELECT ', coluna_literal, ' AS coluna, ',
        'COUNT(', coluna_sql, ') AS preenchidos, ',
        'CAST(MIN(', coluna_sql, ') AS DOUBLE) AS minimo, ',
        'CAST(MAX(', coluna_sql, ') AS DOUBLE) AS maximo, ',
        'CAST(AVG(', coluna_sql, ') AS DOUBLE) AS media, ',
        'CAST(PERCENTILE_APPROX(', coluna_sql, ', 0.5) AS DOUBLE) AS mediana, ',
        'CAST(PERCENTILE_APPROX(', coluna_sql, ', 0.95) AS DOUBLE) AS p95, ',
        'COUNT_IF(', coluna_sql, ' < 0) AS negativos, ',
        'COUNT_IF(', coluna_sql, ' = 0) AS zeros ',
        'FROM base'
      ) AS bloco
    FROM metadados
  ),
  comando AS (
    SELECT
      COUNT(*) AS qtd_colunas_numericas,
      CONCAT_WS(
        ' UNION ALL ',
        TRANSFORM(
          ARRAY_SORT(
            COLLECT_LIST(
              NAMED_STRUCT('ord', ordinal_position, 'sql', bloco)
            )
          ),
          x -> x.sql
        )
      ) AS corpo_sql
    FROM blocos
  )
  SELECT CASE
    WHEN qtd_colunas_numericas = 0 THEN
      'SELECT ''Nenhuma coluna numerica detectada'' AS aviso'
    ELSE CONCAT(
      'SELECT * FROM (',
      corpo_sql,
      ') perfil_numerico ORDER BY coluna'
    )
  END
  FROM comando
);

-- Diagnostico opcional:
-- SELECT sql_numericos;

EXECUTE IMMEDIATE sql_numericos;


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Range e consistencia das colunas de data/timestamp
-- MAGIC Localiza datas futuras, datas anteriores a 1990 e o intervalo carregado.

-- COMMAND ----------

-- Celula 25 corrigida - ranges de todas as colunas DATE/TIMESTAMP
DECLARE OR REPLACE VARIABLE sql_datas STRING;

SET VAR sql_datas = (
  WITH metadados AS (
    SELECT
      ordinal_position,
      column_name,
      CONCAT('`', REPLACE(column_name, '`', '``'), '`') AS coluna_sql,
      CONCAT(
        CHR(39),
        REPLACE(column_name, CHR(39), CONCAT(CHR(39), CHR(39))),
        CHR(39)
      ) AS coluna_literal
    FROM prd_procurement.information_schema.columns
    WHERE table_schema = 'corp_curated'
      AND table_name = 'vw_ds_log_mb51_movimentacao_material'
      AND LOWER(full_data_type) RLIKE '^(date|timestamp)'
  ),
  blocos AS (
    SELECT
      ordinal_position,
      CONCAT(
        'SELECT ', coluna_literal, ' AS coluna, ',
        'CAST(MIN(', coluna_sql, ') AS STRING) AS minimo, ',
        'CAST(MAX(', coluna_sql, ') AS STRING) AS maximo, ',
        'APPROX_COUNT_DISTINCT(', coluna_sql, ') AS datas_distintas_aprox, ',
        'COUNT_IF(TO_DATE(', coluna_sql, ') > CURRENT_DATE()) AS datas_futuras, ',
        'COUNT_IF(TO_DATE(', coluna_sql, ') < TO_DATE(',
        CHR(39), '1990-01-01', CHR(39),
        ')) AS datas_antes_1990 ',
        'FROM base'
      ) AS bloco
    FROM metadados
  ),
  comando AS (
    SELECT
      COUNT(*) AS qtd_colunas_data,
      CONCAT_WS(
        ' UNION ALL ',
        TRANSFORM(
          ARRAY_SORT(
            COLLECT_LIST(
              NAMED_STRUCT('ord', ordinal_position, 'sql', bloco)
            )
          ),
          x -> x.sql
        )
      ) AS corpo_sql
    FROM blocos
  )
  SELECT CASE
    WHEN qtd_colunas_data = 0 THEN
      'SELECT ''Nenhuma coluna DATE/TIMESTAMP detectada; verifique datas armazenadas como STRING'' AS aviso'
    ELSE CONCAT(
      'SELECT * FROM (',
      corpo_sql,
      ') perfil_datas ORDER BY coluna'
    )
  END
  FROM comando
);

-- Diagnostico opcional. Deve aparecer TO_DATE('1990-01-01').
-- SELECT sql_datas;

EXECUTE IMMEDIATE sql_datas;


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Datas armazenadas como texto
-- MAGIC Lista campos string cujo nome sugere data. Para cada campo relevante, valide parsing e range antes da comparacao com o SAP.

-- COMMAND ----------

SELECT ordinal_position, column_name, full_data_type
FROM prd_procurement.information_schema.columns
WHERE table_schema = 'corp_curated'
  AND table_name = 'vw_ds_log_mb51_movimentacao_material'
  AND LOWER(full_data_type) RLIKE '^(string|varchar|char)'
  AND LOWER(column_name) RLIKE 'data|date|dt_|budat|bldat|ingest'
ORDER BY ordinal_position;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Distribuicoes de recorte
-- MAGIC Use os modelos depois de confirmar os nomes das colunas. O objetivo e escolher cenarios SAP representativos, nao apenas os menores.

-- COMMAND ----------

-- Modelo por centro:
-- SELECT cod_centro, COUNT(*) AS linhas, APPROX_COUNT_DISTINCT(cod_material) AS materiais_aprox
-- FROM base
-- GROUP BY cod_centro
-- ORDER BY linhas DESC;

-- COMMAND ----------

-- Modelo por tipo de movimento:
-- SELECT tp_movimento, COUNT(*) AS linhas, APPROX_COUNT_DISTINCT(cod_material) AS materiais_aprox
-- FROM base
-- GROUP BY tp_movimento
-- ORDER BY linhas DESC;

-- COMMAND ----------

-- Modelo por data de lancamento:
-- SELECT TO_DATE(dt_lancamento) AS data_lancamento, COUNT(*) AS linhas
-- FROM base
-- GROUP BY TO_DATE(dt_lancamento)
-- ORDER BY data_lancamento DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Dominios e valores dominantes
-- MAGIC A consulta abaixo gera comandos para analisar as 20 maiores frequencias das colunas de interesse. Copie e execute apenas para campos categoricos relevantes.

-- COMMAND ----------

SELECT
  column_name,
  CONCAT(
    'SELECT ''', REPLACE(column_name, '''', ''''''), ''' AS coluna, ',
    'CAST(`', REPLACE(column_name, '`', '``'), '` AS STRING) AS valor, COUNT(*) AS quantidade ',
    'FROM base GROUP BY `', REPLACE(column_name, '`', '``'), '` ORDER BY quantidade DESC LIMIT 20;'
  ) AS consulta_dominio
FROM prd_procurement.information_schema.columns
WHERE table_schema = 'corp_curated'
  AND table_name = 'vw_ds_log_mb51_movimentacao_material'
ORDER BY ordinal_position;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 15. Checklist de diagnostico
-- MAGIC Antes de seguir para o cenario SAP, registre:
-- MAGIC 1. Granularidade real: uma linha representa o que?
-- MAGIC 2. Chave: qual combinacao e unica?
-- MAGIC 3. Colunas suspeitas: quais estao 100% nulas, sem valor util ou constantes?
-- MAGIC 4. Formato: codigos preservam zeros a esquerda? Datas e decimais estao coerentes?
-- MAGIC 5. Defaults: existe valor dominante sem justificativa?
-- MAGIC 6. Freshness: o periodo da view corresponde ao periodo que sera extraido do SAP?
-- MAGIC 7. Risco residual: que analise adicional reduziria o risco de aprovar uma base incorreta?
-- MAGIC
-- MAGIC **Portao da Fase 1:** algum comportamento identificado contraria o esperado para a MB51 em producao?