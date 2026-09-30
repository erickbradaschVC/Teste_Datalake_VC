# Databricks notebook source
# MAGIC %md
# MAGIC # MB51 - Analise Exploratoria do Datalake - Producao
# MAGIC **Transacao SAP:** MB51  
# MAGIC **Objeto PROD:** `prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material`
# MAGIC
# MAGIC Objetivo: avaliar volumetria, estrutura, granularidade, preenchimento, cardinalidade, formatos, datas, campos numericos e dimensoes antes da comparacao com o SAP.
# MAGIC
# MAGIC **Aviso metodologico:** igualdade de contagem de linhas nao comprova qualidade. Erros de granularidade, campos nulos, defaults e divergencias de valor podem preservar a volumetria.

# COMMAND ----------

# MAGIC %md
# MAGIC ## 01. Parametros de recorte
# MAGIC Os filtros sao opcionais. O notebook detecta as colunas existentes antes de aplicar cada filtro.

# COMMAND ----------

# MAGIC %sql
# MAGIC dbutils.widgets.text("f_cod_centro", "", "Centro")
# MAGIC dbutils.widgets.text("f_cod_material", "", "Material")
# MAGIC dbutils.widgets.text("f_cod_deposito", "", "Deposito")
# MAGIC dbutils.widgets.text("f_dt_inicio", "", "Data inicial (AAAA-MM-DD)")
# MAGIC dbutils.widgets.text("f_dt_fim", "", "Data final (AAAA-MM-DD)")
# MAGIC dbutils.widgets.text("f_coluna_data", "", "Coluna de data do movimento")

# COMMAND ----------

from pyspark.sql import functions as F, types as T
from functools import reduce
import re

TABELA = "prd_procurement.corp_curated.vw_ds_log_mb51_movimentacao_material"
df_raw = spark.table(TABELA)
colunas = df_raw.columns
colunas_lower = {c.lower(): c for c in colunas}

def localizar(*candidatas):
    for nome in candidatas:
        if nome.lower() in colunas_lower:
            return colunas_lower[nome.lower()]
    return None

col_centro = localizar("cod_centro", "centro", "werks")
col_material = localizar("cod_material", "material", "matnr")
col_deposito = localizar("cod_deposito", "deposito", "lgort")
col_data_widget = dbutils.widgets.get("f_coluna_data").strip()
col_data = col_data_widget if col_data_widget in colunas else localizar(
    "dt_lancamento", "data_lancamento", "dt_documento", "data_documento",
    "posting_date", "document_date", "budat", "bldat", "dateingest"
)

filtros = []
for coluna, widget in [
    (col_centro, "f_cod_centro"),
    (col_material, "f_cod_material"),
    (col_deposito, "f_cod_deposito")
]:
    valor = dbutils.widgets.get(widget).strip()
    if coluna and valor:
        filtros.append(F.col(coluna).cast("string") == F.lit(valor))

inicio = dbutils.widgets.get("f_dt_inicio").strip()
fim = dbutils.widgets.get("f_dt_fim").strip()
if col_data and inicio:
    filtros.append(F.to_date(F.col(col_data)) >= F.to_date(F.lit(inicio)))
if col_data and fim:
    filtros.append(F.to_date(F.col(col_data)) <= F.to_date(F.lit(fim)))

df = df_raw
for condicao in filtros:
    df = df.filter(condicao)

df.createOrReplaceTempView("base")

print(f"Tabela: {TABELA}")
print(f"Colunas: {len(colunas)}")
print(f"Centro detectado: {col_centro}")
print(f"Material detectado: {col_material}")
print(f"Deposito detectado: {col_deposito}")
print(f"Data detectada: {col_data}")
print(f"Filtros ativos: {len(filtros)}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 02. Estrutura e metadados
# MAGIC Confirma nomes, tipos e propriedades do objeto antes de formular hipoteses de chave.

# COMMAND ----------

display(spark.sql(f"DESCRIBE EXTENDED {TABELA}"))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 03. Volumetria
# MAGIC Estabelece a linha de base do recorte analisado. Nao deve ser interpretada isoladamente como evidencia de qualidade.

# COMMAND ----------

total = df.count()
display(spark.createDataFrame([(TABELA, total, len(colunas), len(filtros))],
                              ["tabela", "linhas_na_base", "quantidade_colunas", "filtros_ativos"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 04. Amostra completa
# MAGIC Permite inspecionar formatos reais, zeros a esquerda, datas, sinais e casas decimais.

# COMMAND ----------

display(df.limit(20))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 05. Inventario de tipos
# MAGIC Separa campos string, numericos, datas e demais tipos para aplicar testes coerentes.

# COMMAND ----------

esquema = [(f.name, f.dataType.simpleString(), f.nullable) for f in df.schema.fields]
display(spark.createDataFrame(esquema, ["coluna", "tipo", "aceita_nulo"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 06. Preenchimento de todas as colunas
# MAGIC Varredura integral, sem amostragem. Classifica nulos, vazios/defaults textuais, zeros numericos e valores uteis.

# COMMAND ----------

exprs = []
for field in df.schema.fields:
    c = F.col(field.name)
    tipo = field.dataType
    nulos = F.sum(F.when(c.isNull(), 1).otherwise(0)).cast("long")
    if isinstance(tipo, T.StringType):
        norm = F.lower(F.trim(c))
        vazios = F.sum(F.when(c.isNotNull() & norm.isin("", "null", "nan", "none", "#", "-", "na", "n/a"), 1).otherwise(0)).cast("long")
        zeros = F.sum(F.when(c.isNotNull() & norm.rlike(r"^[+-]?0+([.,]0+)?$"), 1).otherwise(0)).cast("long")
    elif isinstance(tipo, T.NumericType):
        vazios = F.lit(0).cast("long")
        zeros = F.sum(F.when(c == 0, 1).otherwise(0)).cast("long")
    else:
        vazios = F.lit(0).cast("long")
        zeros = F.lit(0).cast("long")
    exprs.append(F.struct(
        F.lit(field.name).alias("coluna"), F.lit(tipo.simpleString()).alias("tipo"),
        nulos.alias("nulos"), vazios.alias("vazios_default"), zeros.alias("zeros")
    ))

perfil = (df.agg(F.array(*exprs).alias("p"))
            .select(F.explode("p").alias("x")).select("x.*")
            .withColumn("total", F.lit(total))
            .withColumn("uteis", F.col("total") - F.col("nulos") - F.col("vazios_default") - F.col("zeros"))
            .withColumn("pct_util", F.round(F.col("uteis") * 100.0 / F.when(F.col("total") == 0, None).otherwise(F.col("total")), 2))
            .withColumn("veredito", F.when(F.col("nulos") == F.col("total"), "1. 100% NULO")
                .when(F.col("uteis") <= 0, "2. SEM VALOR UTIL")
                .when(F.col("uteis") < F.col("total") * 0.01, "3. QUASE VAZIO (<1%)")
                .otherwise("9. OK")))
display(perfil.orderBy("veredito", "pct_util", "coluna"))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 07. Cardinalidade de todas as colunas
# MAGIC Colunas constantes ou de baixa cardinalidade podem indicar defaults. Valores aproximados sao usados para manter a execucao viavel em bases grandes.

# COMMAND ----------

card_exprs = [F.approx_count_distinct(F.col(c)).alias(c) for c in colunas]
card_row = df.agg(*card_exprs).first().asDict()
card = [(c, df.schema[c].dataType.simpleString(), int(card_row[c])) for c in colunas]
card_df = (spark.createDataFrame(card, ["coluna", "tipo", "distintos_aprox"])
    .withColumn("pct_distintos", F.round(F.col("distintos_aprox") * 100.0 / F.when(F.lit(total) == 0, None).otherwise(F.lit(total)), 4))
    .withColumn("classificacao", F.when(F.col("distintos_aprox") <= 1, "1. CONSTANTE")
        .when(F.col("distintos_aprox") <= 5, "2. CARDINALIDADE MUITO BAIXA")
        .when(F.col("distintos_aprox") > F.lit(total) * .95, "3. CANDIDATA A IDENTIFICADOR")
        .otherwise("9. NORMAL")))
display(card_df.orderBy("classificacao", "distintos_aprox", "coluna"))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 08. Chaves candidatas e granularidade
# MAGIC A MB51 normalmente exige uma chave de movimento mais detalhada que material e centro. O bloco abaixo testa combinacoes somente quando as respectivas colunas existem.

# COMMAND ----------

def primeira_coluna(*cands):
    return localizar(*cands)

candidatos_semanticos = {
    "documento": primeira_coluna("num_documento_material", "num_documento", "documento_material", "mblnr"),
    "ano_documento": primeira_coluna("ano_documento_material", "ano_documento", "mjahr"),
    "item_documento": primeira_coluna("num_item_documento", "item_documento", "zeile"),
    "material": col_material,
    "centro": col_centro,
    "deposito": col_deposito,
    "data_movimento": col_data,
    "tipo_movimento": primeira_coluna("tp_movimento", "cod_tipo_movimento", "tipo_movimento", "bwart")
}
candidatos_semanticos = {k:v for k,v in candidatos_semanticos.items() if v}
display(spark.createDataFrame(list(candidatos_semanticos.items()), ["papel_semantico", "coluna_detectada"]))

# COMMAND ----------

combos = []
def adicionar_combo(nome, papeis):
    cols = [candidatos_semanticos.get(p) for p in papeis]
    if all(cols) and len(set(cols)) == len(cols):
        combos.append((nome, cols))

adicionar_combo("documento + ano + item", ["documento", "ano_documento", "item_documento"])
adicionar_combo("documento + item", ["documento", "item_documento"])
adicionar_combo("material + centro + data + tipo movimento", ["material", "centro", "data_movimento", "tipo_movimento"])
adicionar_combo("material + centro + deposito + data + tipo movimento", ["material", "centro", "deposito", "data_movimento", "tipo_movimento"])

resultados_chave = []
for nome, cols in combos:
    distintos = df.select(*cols).distinct().count()
    resultados_chave.append((nome, " + ".join(cols), total, distintos,
                              round(total / distintos, 6) if distintos else None,
                              "CHAVE UNICA" if distintos == total else "NAO UNICA"))

if resultados_chave:
    display(spark.createDataFrame(resultados_chave,
        ["chave_candidata", "colunas", "linhas", "combinacoes_distintas", "linhas_por_chave", "veredito"]))
else:
    print("Nenhuma combinacao candidata completa foi detectada. Use o inventario de colunas para definir a chave manualmente.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 09. Duplicidades da melhor chave documental
# MAGIC Exibe os casos repetidos para diferenciar duplicata real de dimensao adicional.

# COMMAND ----------

chave_doc = next((cols for nome, cols in combos if nome == "documento + ano + item"), None)
if not chave_doc:
    chave_doc = next((cols for nome, cols in combos if nome == "documento + item"), None)
if chave_doc:
    display(df.groupBy(*chave_doc).count().filter(F.col("count") > 1).orderBy(F.desc("count")).limit(100))
else:
    print("Chave documental nao detectada automaticamente.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 10. Perfil numerico
# MAGIC Avalia preenchimento, minimo, maximo, media, mediana, percentil 95, negativos e zeros em todos os campos numericos.

# COMMAND ----------

num_cols = [f.name for f in df.schema.fields if isinstance(f.dataType, T.NumericType)]
num_result = []
for c in num_cols:
    r = df.agg(
        F.count(F.col(c)).alias("preenchidos"), F.min(c).cast("double").alias("minimo"),
        F.max(c).cast("double").alias("maximo"), F.avg(c).alias("media"),
        F.expr(f"percentile_approx(`{c}`, 0.5)").cast("double").alias("mediana"),
        F.expr(f"percentile_approx(`{c}`, 0.95)").cast("double").alias("p95"),
        F.count_if(F.col(c) < 0).alias("negativos"), F.count_if(F.col(c) == 0).alias("zeros")
    ).first()
    num_result.append((c, *r))
if num_result:
    display(spark.createDataFrame(num_result, ["coluna", "preenchidos", "minimo", "maximo", "media", "mediana", "p95", "negativos", "zeros"]).orderBy("coluna"))
else:
    print("Nenhuma coluna numerica detectada.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 11. Datas e freshness
# MAGIC Identifica ranges, quantidade de datas e ocorrencias futuras ou anteriores a 1990 em todas as colunas date/timestamp.

# COMMAND ----------

date_cols = [f.name for f in df.schema.fields if isinstance(f.dataType, (T.DateType, T.TimestampType))]
datas = []
for c in date_cols:
    r = df.agg(F.min(c).cast("string"), F.max(c).cast("string"), F.approx_count_distinct(c),
               F.count_if(F.to_date(F.col(c)) > F.current_date()),
               F.count_if(F.to_date(F.col(c)) < F.lit("1990-01-01").cast("date"))).first()
    datas.append((c, *r))
if datas:
    display(spark.createDataFrame(datas, ["coluna", "minimo", "maximo", "datas_distintas_aprox", "datas_futuras", "datas_antes_1990"]).orderBy("coluna"))
else:
    print("Nenhuma coluna date/timestamp detectada. Verifique se datas estao armazenadas como string.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 12. Formato dos campos-chave
# MAGIC Detecta comprimento variavel, zeros a esquerda, espacos e colisoes potenciais apos remover zeros iniciais.

# COMMAND ----------

key_format_cols = [c for c in [col_material, col_centro, col_deposito] if c]
fmt = []
for c in key_format_cols:
    s = F.col(c).cast("string")
    r = df.agg(
        F.count_if(s.isNull() | (F.trim(s) == "")), F.min(F.length(F.trim(s))), F.max(F.length(F.trim(s))),
        F.count_if(F.trim(s).rlike(r"^0[0-9]")), F.count_if(s != F.trim(s)),
        F.approx_count_distinct(F.trim(s)), F.approx_count_distinct(F.regexp_replace(F.trim(s), r"^0+", ""))
    ).first()
    fmt.append((c, *r, int(r[5] - r[6])))
if fmt:
    display(spark.createDataFrame(fmt, ["coluna", "vazios", "len_min", "len_max", "com_zeros_esquerda", "com_espacos", "distintos_bruto_aprox", "distintos_sem_zeros_aprox", "colisoes_aprox_ao_remover_zeros"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 13. Dominios das colunas categoricas
# MAGIC Lista os valores mais frequentes das colunas de baixa cardinalidade para localizar defaults e dominios suspeitos.

# COMMAND ----------

low_card = [r["coluna"] for r in card_df.filter((F.col("distintos_aprox") <= 50) & (F.col("distintos_aprox") > 0)).select("coluna").collect()]
for c in low_card:
    print(f"DOMINIO: {c}")
    display(df.groupBy(F.col(c).cast("string").alias("valor")).count().orderBy(F.desc("count")).limit(20))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 14. Distribuicoes para escolha do cenario SAP
# MAGIC Apoia a selecao de recortes viaveis por centro, tipo de movimento e data, sem assumir que qualquer dimensao exista.

# COMMAND ----------

dimensoes = [
    ("centro", col_centro),
    ("tipo_movimento", candidatos_semanticos.get("tipo_movimento")),
    ("deposito", col_deposito),
    ("data_movimento", col_data)
]
for nome, c in dimensoes:
    if c:
        print(f"DISTRIBUICAO: {nome} ({c})")
        aggs = [F.count("*").alias("linhas")]
        if col_material:
            aggs.append(F.approx_count_distinct(col_material).alias("materiais_aprox"))
        display(df.groupBy(c).agg(*aggs).orderBy(F.desc("linhas")).limit(100))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 15. Linhas identicas versus granularidade adicional
# MAGIC Compara repeticoes da chave candidata com hashes da linha completa.

# COMMAND ----------

if chave_doc:
    hash_expr = F.sha2(F.concat_ws("||", *[F.coalesce(F.col(c).cast("string"), F.lit("∅")) for c in colunas]), 256)
    d = df.withColumn("_hash_linha", hash_expr)
    resumo_dup = (d.groupBy(*chave_doc).agg(F.count("*").alias("linhas"), F.countDistinct("_hash_linha").alias("linhas_distintas"))
        .filter(F.col("linhas") > 1)
        .withColumn("classificacao", F.when(F.col("linhas_distintas") == 1, "DUPLICATA IDENTICA").otherwise("GRANULARIDADE ADICIONAL OU DADOS DIFERENTES")))
    display(resumo_dup.groupBy("classificacao").agg(F.count("*").alias("chaves"), F.sum("linhas").alias("linhas")).orderBy("classificacao"))
else:
    print("Analise depende da definicao da chave documental.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 16. Resumo consolidado
# MAGIC Resultado operacional da exploratoria. O diagnostico deve ser validado antes da selecao do cenario SAP.

# COMMAND ----------

alertas_nulos = perfil.filter(F.col("veredito") != "9. OK").count()
constantes = card_df.filter(F.col("distintos_aprox") <= 1).count()
resumo = [
    ("VOLUMETRIA", "linhas na base", str(total), "nao comprova qualidade isoladamente"),
    ("ESTRUTURA", "colunas detectadas", str(len(colunas)), "validar contra documentacao/de-para"),
    ("PREENCHIMENTO", "colunas suspeitas", str(alertas_nulos), "investigar no SAP antes de classificar como perda"),
    ("CARDINALIDADE", "colunas constantes", str(constantes), "avaliar defaults de carga"),
    ("CHAVE", "combinacoes testadas", str(len(combos)), "confirmar granularidade com o processo MB51"),
    ("FRESHNESS", "coluna principal de data", str(col_data or "NAO DETECTADA"), "comparar com a data da extracao SAP")
]
display(spark.createDataFrame(resumo, ["bloco", "item", "valor", "observacao"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Checklist para encerrar a Fase 1
# MAGIC - Confirmar a chave real e a granularidade da MB51.
# MAGIC - Investigar todas as colunas 100% nulas ou sem valor util, sempre verificando o preenchimento no SAP.
# MAGIC - Registrar defaults dominantes e formatos dos codigos.
# MAGIC - Confirmar se a view e snapshot ou historica.
# MAGIC - Escolher o recorte SAP somente depois de validar o diagnostico.
# MAGIC
# MAGIC **Portao:** algum comportamento identificado contraria o esperado para a MB51 em producao?