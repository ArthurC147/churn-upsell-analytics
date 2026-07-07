# Churn & Upsell Analytics

![SQL](https://img.shields.io/badge/SQL-4479A1?style=flat-square&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-150458?style=flat-square&logo=pandas&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat-square&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)

> Modelagem de risco de churn e scoring de propensão a upsell em base de clientes bancários — usando SQL avançado (CTEs, Window Functions) e Python.

---

## Contexto de negócio

Em qualquer operação com carteira de clientes recorrente — banco, telecom, SaaS —
duas perguntas valem mais que qualquer outra métrica de vaidade:

1. **Quais clientes estão em risco de cancelar?**
2. **Quais clientes ativos têm potencial para comprar mais?**

Este projeto responde as duas com a mesma base de dados, usando a lógica aplicada
no projeto de Churn & Upsell Analytics na Telefônica Vivo, que resultou em
**−2.79% de CAC (Custo de Aquisição de Cliente)** em contas enterprise — ao invés
de gastar em aquisição de clientes novos, o time direcionou esforço comercial
para vender mais aos clientes que já existiam.

---

## Problema → Solução → Resultado

| | |
|---|---|
| **Problema** | Times comerciais tratam toda a base de clientes igual — sem saber quem está em risco de sair nem quem tem potencial de comprar mais |
| **Solução** | SQL com CTEs e Window Functions para segmentar por risco de churn; scoring de upsell baseado em quartil de saldo e status de atividade |
| **Resultado** | Identificação de 1.227 clientes (12,3% da base) como "High Upsell Potential" + descoberta de que clientes com 3-4 produtos têm churn 3x maior que clientes com 1-2 |

---

## Dataset

**Fonte:** [Churn Modelling Dataset — Kaggle](https://www.kaggle.com/datasets/shrutimechlearn/churn-modelling)

10.000 clientes de um banco fictício com dados demográficos (idade, país, gênero),
financeiros (saldo, salário, score de crédito) e comportamentais (produtos contratados,
atividade, tempo de casa).

```
data/
├── raw/
│   └── Churn_Modelling.csv        ← original do Kaggle, não modificado
└── processed/
    ├── customers_clean.csv        ← após feature engineering
    └── churn_kpi_processed.csv    ← tabela agregada para o Power BI
```

> **Privacidade:** dataset público, sintético e anonimizado. Nenhum dado real de cliente é usado.

---

## O que este projeto demonstra: SQL avançado

O arquivo `sql/01_sql_exploration.sql` contém 4 queries progressivas:

| Query | Técnica SQL | O que resolve |
|---|---|---|
| 1 | **CTE + CASE WHEN** | Segmenta clientes por idade e saldo, calcula churn por segmento |
| 2 | **Window Function** — `RANK() OVER (PARTITION BY...)` | Ranking de clientes por saldo dentro de cada país |
| 3 | **NTILE + CTE aninhada** | Score de propensão a upsell em 3 níveis |
| 4 | **GROUP BY com regra de negócio** | Revela que mais produtos ≠ mais fidelidade |

A diferença entre `GROUP BY` e `Window Function`: o primeiro colapsa as linhas
em uma por grupo; a Window Function mantém todas as linhas originais e adiciona
uma coluna calculada olhando para o grupo — essencial para rankings e comparações
"cliente vs média do grupo" sem perder o detalhe individual.

---

## Pipeline de análise (Python)

```
[Churn_Modelling.csv] → [01_coleta.ipynb] → [02_tratamento.ipynb] → [03_analise.ipynb] → [churn_kpi_processed.csv] → [Power BI]
```

| Notebook | O que faz |
|---|---|
| `01_coleta.ipynb` | Carrega o dataset, diagnostica tipos e nulos, primeira visão de churn geral e por país |
| `02_tratamento.ipynb` | Cria segmentos de idade, saldo, quartil e tempo de casa; calcula o `upsell_segment` |
| `03_analise.ipynb` | Gera heatmap de risco, gráficos de churn por produto/país/atividade, exporta KPIs |

---

## Principais achados

**Achado 1 — Produtos demais aumentam o churn, não reduzem**
Clientes com 3-4 produtos têm churn de 38-47%, contra ~12% para clientes com 1-2 produtos.
Isso geralmente indica venda cruzada mal ajustada — produtos empurrados sem fit real
com a necessidade do cliente, ou clientes insatisfeitos testando alternativas antes
de cancelar de vez.

**Achado 2 — Alemanha concentra o maior risco**
A taxa de churn na Alemanha (~26%) é mais que o dobro de França e Espanha (~9-10%).
Combinado com idade avançada, esse segmento chega a 30% de churn — prioridade
máxima para ações de retenção.

**Achado 3 — 12,3% da base é candidata a upsell imediato**
Clientes ativos, com apenas 1 produto e no top 50% de saldo bancário representam
o alvo ideal para oferta de um segundo produto, sem necessidade de descontos
agressivos ou aquisição de clientes novos.

---

## Estrutura do projeto

```
churn-upsell-analytics/
├── data/
│   ├── raw/
│   │   └── Churn_Modelling.csv
│   └── processed/
│       ├── customers_clean.csv
│       └── churn_kpi_processed.csv
├── notebooks/
│   ├── 01_coleta.ipynb
│   ├── 02_tratamento.ipynb
│   └── 03_analise.ipynb
├── sql/
│   └── 01_sql_exploration.sql
├── dashboard/
│   └── churn_dashboard.pbix
├── docs/
│   └── screenshots/
│       ├── 01_churn_distribution.png
│       ├── 01_churn_by_geography.png
│       ├── churn_heatmap_age_balance.png
│       ├── churn_by_num_products.png
│       ├── upsell_segments.png
│       └── churn_geo_activity.png
├── requirements.txt
└── README.md
```

---

## Como executar

### 1. Clonar e instalar dependências
```bash
git clone https://github.com/ArthurC147/churn-upsell-analytics.git
cd churn-upsell-analytics
pip install -r requirements.txt
```

### 2. Baixar o dataset
Baixe `Churn_Modelling.csv` em [kaggle.com/datasets/shrutimechlearn/churn-modelling](https://www.kaggle.com/datasets/shrutimechlearn/churn-modelling)
e coloque em `data/raw/`.

### 3. Rodar os notebooks em ordem
```bash
jupyter notebook
# Execute: 01_coleta.ipynb → 02_tratamento.ipynb → 03_analise.ipynb
```

### 4. Explorar o SQL
Importe `Churn_Modelling.csv` para uma tabela `customers` em qualquer banco SQL
(SQLite, PostgreSQL, MySQL) e rode as queries de `sql/01_sql_exploration.sql`.

### 5. Abrir o dashboard
Abra `dashboard/churn_dashboard.pbix` no Power BI Desktop, apontando para
`data/processed/churn_kpi_processed.csv`.

---

## Dependências

```
pandas>=2.0.0
numpy>=1.24.0
matplotlib>=3.7.0
seaborn>=0.12.0
jupyter>=1.0.0
```

---

## O que eu aprendi

- Window Functions resolvem um problema que `GROUP BY` não resolve: comparar
  cada linha individual contra a média do seu grupo, sem perder o detalhe da linha
- `NTILE()` é mais robusto que limites fixos (`WHERE saldo > 100000`) porque se
  adapta à distribuição real dos dados, não a um número arbitrário
- Métricas de churn "óbvias" (mais produtos = mais fidelidade) podem estar erradas —
  os dados revelaram o oposto, o que só se descobre analisando, não assumindo
- Separar CTEs em camadas (uma CTE usando o resultado de outra) deixa a lógica
  de negócio auditável passo a passo, essencial quando alguém mais sênior revisa o código

---

## Autor

**Arthur Cardoso** — Industrial Engineering @ UFPR · Business & Customer Success Intern @ Telefônica Vivo

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=flat-square&logo=linkedin&logoColor=white)](https://linkedin.com/in/arthur-cardoso-b3b1ba1ab)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/ArthurC147)
