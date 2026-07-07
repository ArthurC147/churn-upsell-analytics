-- ============================================================================
-- 01_sql_exploration.sql
-- Projeto: churn-upsell-analytics
-- Objetivo: Explorar o dataset de clientes bancários com SQL avançado para identificar padrões de churn
--           e oportunidades de upsell.

-- ============================================================================
-- QUERY 1 — Segmentação de risco de churn (CTE + CASE WHEN)
-- ============================================================================
-- O QUE FAZ:
--   Cria uma CTE (Common Table Expression) chamada 'customer_segments' que
--   categoriza cada cliente por faixa etária e faixa de saldo bancário.
--   Depois agrupa por essas duas categorias e calcula a taxa de churn.
--
-- POR QUE UMA CTE:
--   Uma CTE é uma "tabela temporária" que existe só durante a execução
--   dessa query. Ela permite quebrar uma lógica complexa em passos —
--   primeiro categorizamos (CASE WHEN), depois agregamos (GROUP BY).
--   Sem CTE, teríamos que repetir os CASE WHEN em cada cálculo.
--
-- O QUE O RESULTADO SIGNIFICA:
--   Mostra QUAIS combinações de idade + saldo têm a maior taxa de churn.
--   Isso direciona onde o time de retenção deve focar esforço.
-- ============================================================================

WITH customer_segments AS (
    SELECT
        CustomerId,
        Geography,
        Age,
        Balance,
        NumOfProducts,
        IsActiveMember,
        Exited,
        -- CASE WHEN funciona como um "se/senão" dentro do SQL
        -- Cada linha é avaliada de cima para baixo; a primeira condição
        -- verdadeira decide o rótulo daquela linha
        CASE
            WHEN Age >= 50 THEN 'Senior (50+)'
            WHEN Age >= 35 THEN 'Adult (35-49)'
            ELSE 'Young (18-34)'
        END AS age_segment,
        CASE
            WHEN Balance = 0 THEN 'Zero Balance'
            WHEN Balance < 50000 THEN 'Low Balance'
            WHEN Balance < 150000 THEN 'Mid Balance'
            ELSE 'High Balance'
        END AS balance_segment
    FROM customers
)
SELECT
    age_segment,
    balance_segment,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned,                                  -- Exited é 0 ou 1, então SUM conta os churns
    ROUND(100.0 * SUM(Exited) / COUNT(*), 1) AS churn_rate_pct
FROM customer_segments
GROUP BY age_segment, balance_segment
ORDER BY churn_rate_pct DESC
LIMIT 10;


-- ============================================================================
-- QUERY 2 — Ranking de clientes por saldo dentro de cada país (Window Functions)
-- ============================================================================
-- O QUE FAZ:
--   Para cada país (Geography), classifica os clientes do maior para o
--   menor saldo bancário, e calcula a média de saldo do país e o quanto
--   cada cliente está acima/abaixo dessa média.
--
-- POR QUE WINDOW FUNCTIONS:
--   RANK() OVER (PARTITION BY ...) é diferente de um GROUP BY normal:
--   GROUP BY colapsa as linhas em uma linha por grupo (perde o detalhe).
--   Window Function mantém TODAS as linhas originais, mas adiciona uma
--   coluna calculada "olhando" para o grupo (nesse caso, o país).
--
--   PARTITION BY Geography = "calcule isso separadamente para cada país"
--   ORDER BY Balance DESC   = "dentro de cada país, ordene do maior saldo"
--
-- O QUE O RESULTADO SIGNIFICA:
--   Identifica os clientes de maior valor em cada mercado — geralmente
--   os primeiros candidatos a programas de relacionamento VIP ou
--   consultoria financeira personalizada (upsell de produtos premium).
-- ============================================================================

WITH ranked_customers AS (
    SELECT
        CustomerId,
        Geography,
        Balance,
        EstimatedSalary,
        Exited,
        -- RANK() numera as linhas dentro de cada partição (país)
        -- Empates recebem o mesmo rank (ex: dois primeiros lugares = rank 1, 1, 3)
        RANK() OVER (PARTITION BY Geography ORDER BY Balance DESC) AS balance_rank,
        -- AVG() OVER faz a média de TODO o grupo, mas mantém uma linha por cliente
        AVG(Balance) OVER (PARTITION BY Geography) AS avg_balance_geo,
        -- Subtração simples: quanto esse cliente está acima/abaixo da média do país
        Balance - AVG(Balance) OVER (PARTITION BY Geography) AS balance_vs_avg
    FROM customers
)
SELECT
    Geography,
    CustomerId,
    Balance,
    balance_rank,
    ROUND(avg_balance_geo, 2)  AS avg_balance_geo,
    ROUND(balance_vs_avg, 2)   AS balance_vs_avg
FROM ranked_customers
WHERE balance_rank <= 3          -- top 3 clientes por saldo em cada país
ORDER BY Geography, balance_rank;


-- ============================================================================
-- QUERY 3 — Scoring de propensão a upsell (NTILE + CTE aninhada)
-- ============================================================================
-- O QUE FAZ:
--   Identifica clientes ATIVOS (que não cancelaram) com apenas 1 produto
--   bancário e classifica o potencial de upsell (venda de produto adicional)
--   com base em quartil de saldo e status de atividade.
--
-- POR QUE NTILE:
--   NTILE(4) divide os clientes em 4 grupos de tamanho igual (quartis),
--   ordenados por saldo. O quartil 1 = os 25% com maior saldo.
--   Isso é mais robusto que definir limites fixos (ex: "saldo > R$100k")
--   porque se adapta automaticamente à distribuição real dos dados.
--
-- POR QUE CTE ANINHADA (uma CTE usando outra CTE):
--   'upsell_base' prepara os dados (filtra churns, calcula quartil).
--   'scored' usa esse resultado para aplicar a regra de negócio (CASE WHEN).
--   Separar em duas camadas deixa a lógica mais fácil de auditar e testar.
--
-- O QUE O RESULTADO SIGNIFICA:
--   "High Upsell Potential" = clientes ativos, com apenas 1 produto,
--   e no top 50% de saldo — são os candidatos ideais para oferecer um
--   segundo produto (cartão de crédito, investimento, seguro).
--   Esse é o tipo de análise que fundamentou o resultado real de
--   -2.79% em CAC no projeto da Vivo: ao invés de gastar em aquisição
--   de novos clientes, você vende mais para quem já é cliente.
-- ============================================================================

WITH upsell_base AS (
    SELECT
        CustomerId,
        Geography,
        NumOfProducts,
        IsActiveMember,
        Balance,
        EstimatedSalary,
        Exited,
        -- Divide todos os clientes em 4 grupos iguais por saldo (do maior para o menor)
        NTILE(4) OVER (ORDER BY Balance DESC) AS balance_quartile
    FROM customers
    WHERE Exited = 0   -- só faz sentido oferecer upsell para quem ainda é cliente
),
scored AS (
    SELECT
        *,
        CASE
            WHEN NumOfProducts = 1 AND IsActiveMember = 1 AND balance_quartile <= 2
                THEN 'High Upsell Potential'
            WHEN NumOfProducts = 1 AND IsActiveMember = 1
                THEN 'Medium Upsell Potential'
            ELSE 'Low Upsell Potential'
        END AS upsell_segment
    FROM upsell_base
)
SELECT
    upsell_segment,
    COUNT(*)                       AS customers,
    ROUND(AVG(Balance), 2)         AS avg_balance,
    ROUND(AVG(EstimatedSalary), 2) AS avg_salary
FROM scored
GROUP BY upsell_segment
ORDER BY customers DESC;


-- ============================================================================
-- QUERY 4 — Taxa de churn por número de produtos (regra de negócio validada)
-- ============================================================================
-- O QUE FAZ:
--   Calcula a taxa de churn simples por quantidade de produtos contratados.
--
-- POR QUE ESSA QUERY É IMPORTANTE:
--   Ela costuma revelar um padrão contraintuitivo: clientes com 3-4 produtos
--   têm taxa de churn MAIOR que clientes com 1-2. Isso geralmente indica
--   venda cruzada forçada (produtos empurrados, não desejados) ou clientes
--   insatisfeitos testando múltiplos produtos antes de sair do banco.
--   Esse tipo de achado direciona decisões de política comercial.
-- ============================================================================

SELECT
    NumOfProducts,
    COUNT(*)                                       AS total_customers,
    SUM(Exited)                                     AS churned,
    ROUND(100.0 * SUM(Exited) / COUNT(*), 1)        AS churn_rate_pct
FROM customers
GROUP BY NumOfProducts
ORDER BY NumOfProducts;
