# Análise de Desempenho e Sustentabilidade

Este projeto consiste na análise exploratório e estratégicas de dados de uma empresa de acomodações e experiências sustentáveis, utilizando SQL no Google BigQuery, com foco em desempenho financeiro, comportamento dos clientes, popularidade das ofertas e adoção de práticas sustentáveis

## Objetivos do Projeto

- Monitorar o desempenho financeiro da plataforma ao longo do tempo;
- Identificar padrões de crescimento e sazonalidade da receita;
- Avaliar comportamento de consumo (ticket médio, fidelização);
- Analisar popularidade e qualidade das ofertas;
- Medir a adoção e a demanda por práticas sustentáveis;
- Gerar insights acionáveis para estratégias de marketing, engajamento e promoção de ofertas.



## Base de Dados

Os dados são em formato .xlsx, contendo as seguintes tabelas principais:

- `reservas`: registros de reservas realizadas na plataforma;
- `ofertas`: catálogo de experiências e hospedagens;
- `avaliacoes`: notas atribuídas pelos clientes;
- `operadores`: empresas responsáveis pelas ofertas;
- `praticas\\\_sustentaveis` e `oferta\\\_pratica`: relacionamento entre ofertas e práticas sustentáveis.



## Análises Desenvolvidas

## 1. Receita Total por Mês e Sazonalidade
- Cálculo da receita mensal considerando preço da oferta × quantidade de pessoas;
- Identificação de picos e quedas de desempenho ao longo do tempo;

```sql

SELECT
  extract(year from r.data_reserva) as ano,
format_date('%B', date(r.data_reserva)) as nome_mes,
round(sum(o.preco * r.qtd_pessoas), 2) as receita_total
from `ecoviagens-477223.plataforma.reservas` r
inner join `ecoviagens-477223.plataforma.ofertas` o 
on r.id_oferta = o.id_oferta
where upper(r.status) = 'CONCLUÍDA'
group by ano, nome_mes, extract(month from r.data_reserva)
order by ano desc, extract(month from r.data_reserva) desc;

```

- Análise da variação percentual mês a mês utilizando `LAG()` e `SAFE\\\_DIVIDE()`.

Outubro apresentou o maior crescimento percentual (43,68%), indicando possível influência de sazonalidade, feriados ou campanhas promocionais. Os meses com maior variação negativa foram jul/24 e abr/25, o que comprovam a necessidade de implementar estratégias de marketing e oferta para minimizar a queda de performance.

```sql

with receita_mensal as (
  select
  date_trunc(data_reserva, MONTH) AS mes,
  round(sum (o.preco * r.qtd_pessoas), 2) as receita_total
  from `ecoviagens-477223.plataforma.reservas` r
  inner join `ecoviagens-477223.plataforma.ofertas` o on r.id_oferta = o.id_oferta
  where upper (r.status) = 'CONCLUÍDA'
  group by mes
)

select
  mes,
  receita_total,
  round(lag (receita_total) over (order by mes), 2) as receita_anterior,
  round(
    safe_divide(receita_total - lag(receita_total) over (order by mes),
    lag(receita_total) over (order by mes)) * 100, 2
  ) as variacao_percentual
  from receita_mensal
  order by mes;

```


# 2. Ticket Médio e Perfil de Consumo
- Entender se os clientes estão investindo mais em experiências premium ou optando por ofertas mais econômicas
- Comparação entre média e mediana para avaliar influência de outliers.

- Média dos gastos com acomodação (R$ 276,88)

```sql
select
  round(sum(o.preco * r.qtd_pessoas)/sum(r.qtd_pessoas), 2) as media_gastos
    from `ecoviagens-477223.plataforma.reservas` r
  inner join `ecoviagens-477223.plataforma.ofertas` o 
on r.id_oferta = o.id_oferta
where upper(r.status) = 'CONCLUÍDA'

```

Mesmo se houver a presença de outliers, eles não afetaram significativamente ao comparar a diferença mínima entre a média e a mediana. A proximidade entre média e mediana indica preferência por ofertas de preço acessível, sem forte concentração em experiências premium.



## 3. Popularidade dos Tipos de Oferta
- Análise da distribuição de reservas e viajantes por tipo de oferta (Hospedagem × Atividade).

```sql

select
o.tipo_oferta as tipo_oferta,
count(r.id_reserva) as total_reserva,-- contagem da quantidade de reservas
sum(r.qtd_pessoas) as total_viajantes -- soma da quantidade de pessoas por tipo de oferta
from `ecoviagens-477223.plataforma.reservas` r
inner join `ecoviagens-477223.plataforma.ofertas` o 
on r.id_oferta = o.id_oferta
group by 1;

```

Houve um total de 1053 reservas de hospedagem e 947 reservas de atividade. Já na quantidade de viajantes foram 3043 para hospedagem contra 2801 para atividade. Em ambos os casos a hospedagem foi superior



## 4. Taxa de Fidelização de Clientes
- Identificação de clientes com mais de uma reserva concluída;
- Cálculo da taxa de fidelização sobre a base total de clientes ativos.

```sql
select
  ROUND(count(*) / (
    select
      count(distinct id_cliente)
    from `ecoviagens-477223.plataforma.reservas`
    where upper(status) = 'CONCLUÍDA'-- contagem de clientes com reserva concluída = 614
  ), 2)*100 as porcentagem_fidelizacao    

from(
  select
  id_cliente
  from `ecoviagens-477223.plataforma.reservas`
  where upper(status) = 'CONCLUÍDA'
  group by id_cliente
  having count(id_reserva) > 1 -- clientes com mais de uma reserva
) clientes_fieis;

```

A taxa de fidelização de clientes que fizeram mais de uma reserva com status concluído foi de 23%. Existe oportunidade da taxa de fidelização ser aumentada com descontos progressivos nas reservas.



## 5. Avaliação Média das Ofertas
- Cálculo da nota média por oferta;
- Classificação das ofertas considerando presença de reservas e avaliações.

```sql
select
  o.id_oferta,
  o.titulo,
  round(avg(a.nota), 2) as media_nota,
  case
    when count(distinct r.id_reserva) = 0 then 'Sem Reserva Concluída'
    when count(distinct r.id_reserva) > 0 and count(distinct a.id_avaliacao) = 0 then 'Reserva concluída mas sem avaliação'
    else 'Reserva e avaliação presentes'
  end as status_oferta  
from `ecoviagens-477223.plataforma.ofertas` o
left join `ecoviagens-477223.plataforma.reservas` r on o.id_oferta = r.id_oferta and upper(r.status) = 'CONCLUÍDA'
left join `ecoviagens-477223.plataforma.avaliacoes` a on a.id_oferta = r.id_oferta
group by 1, 2
order by media_nota desc;

```

A análise permite identificar ofertas bem avaliadas, ou seja, as ofertas que mais satisfazem os clientes e e promoverm planos de melhorias nas reservas com baixa avaliação ou nas que não foram avaliadas.



## 6. Índice de Adoção de Práticas Sustentáveis
- Proporção de ofertas com ao menos uma prática sustentável cadastrada.

```sql
select 
  count (distinct id_oferta)
  from `ecoviagens-477223.plataforma.oferta_pratica`; -- 802 ofertas com práticas sustentáveis

select
  round(count(distinct op.id_oferta) / (
    select
      count(distinct id_oferta) -- contagem total de ofertas da tabela de ofertas
  from `ecoviagens-477223.plataforma.ofertas`), 2)*100 as indice_sustentavel_pct
from `ecoviagens-477223.plataforma.oferta_pratica` op

```

67% das ofertas possuem préticas sustentáveis. Esse índice demonstra bom alinhamento com o posicionamento sustentável da plataforma, com margem para evolução, incentivando parceiros que ainda não adotaram um tipo de prática.



## 7. Práticas Sustentáveis Mais Demandadas
- Identificação das práticas sustentáveis mais associadas a reservas concluídas.

```sql
select
  ps.nome,
  count(r.id_reserva) as total_reservas
from `ecoviagens-477223.plataforma.praticas_sustentaveis` ps
inner join `ecoviagens-477223.plataforma.oferta_pratica` op on ps.id_pratica = op.id_pratica
inner join `ecoviagens-477223.plataforma.reservas` r on op.id_oferta = r.id_oferta and upper(r.status) = 'CONCLUÍDA'
group by ps.nome
order by total_reservas desc;

```
 
 Auxilia na priorização de práticas com maior valor percebido pelo cliente.



## 8. Frequência de Reservas de Clientes Fiéis
- Cálculo do intervalo médio entre reservas por cliente fiel;
- Uso de `LAG()` e `DATE\\\_DIFF()` para análise temporal.

```sql
with reservas_filtradas as( -- CTE para filtrar reservas concluídas e clientes com mais de uma reserva 
  select
  id_cliente,
  data_reserva
  from `ecoviagens-477223.plataforma.reservas`
  where upper(status) = 'CONCLUÍDA'
    AND id_cliente in (
      select -- subquery para filtrar contar os clientes com mais de uma reserva concluída
        id_cliente
      from `ecoviagens-477223.plataforma.reservas`
      where upper(status) = 'CONCLUÍDA'
      group by id_cliente
      having count(id_reserva) > 1  
    )
),

diferenca as ( -- diferença dos tempos de reserva
  select
    id_cliente,
    date_diff(
      data_reserva,
      lag(data_reserva) over (partition by id_cliente order by data_reserva), -- lag usado para comparar dados da linha anterior (data)
      DAY
    ) as diff_dias,
    data_reserva
  from reservas_filtradas
)

select
  id_cliente,
  avg(diff_dias) as tempo_medio_reservas, -- media de dias entre reservas
from diferenca
where diff_dias is not null
group by id_cliente
order by tempo_medio_reservas desc;

```
A análise permite planejar campanhas de engajamento baseadas no ciclo médio de recompra.



## 9. Desempenho dos Operadores por Categoria
- Avaliação média dos operadores por tipo de oferta;
- Consideração apenas de ofertas com reservas concluídas.

```sql
with reservas_concluidas as(
  select
    distinct (id_oferta) AS id_oferta
  from `ecoviagens-477223.plataforma.reservas`
  where upper(status) = 'CONCLUÍDA' -- CTE para selecionar apenas reservas concluidas
)

select
  op.nome_fantasia,
  o.tipo_oferta,
  round(AVG(a.nota), 2) as media_avaliacao
from `ecoviagens-477223.plataforma.avaliacoes` a 
inner join `ecoviagens-477223.plataforma.ofertas` o on a.id_oferta = o.id_oferta
inner join reservas_concluidas rs on rs.id_oferta = o.id_oferta
inner join `ecoviagens-477223.plataforma.operadores` op on op.id_operador = o.id_operador
group by 1, 2
order by 2, 3 desc;

```

Apoia decisões sobre curadoria de operadores.



### Próximos Passos

Elaboração de um dashboard em Power BI, com visualização dos dados e apresentação de KPIs estratégicos.
